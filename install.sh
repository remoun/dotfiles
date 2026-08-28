#!/usr/bin/env bash
#
# install.sh - set up these dotfiles on a fresh machine.
#
# Default tier touches only $HOME and never uses the network. Pass --full on a
# bare VPS to also install packages, oh-my-zsh and the tools .gitconfig needs.
#
# Run --help for usage.

set -euo pipefail

REPO_URL_HTTPS="https://github.com/remoun/dotfiles.git"
CLONE_DEST="${DOTFILES_DIR:-$HOME/code/dotfiles}"

# Linked into $HOME at the same relative path, so an entry may be nested.
# .gitignore is deliberate, not repo metadata: .gitconfig points
# core.excludesfile at ~/.gitignore.
DOTFILES=(.ackrc .claude/CLAUDE.md .gitconfig .gitignore .vimrc .zshrc)

# .vimrc sets undofile + undodir, but vim silently skips writing undo history
# if the directory is absent, so persistent undo only works once we create it.
# .claude must exist before link_dotfiles runs, because link_file does not
# create the parent directory of its destination.
# The rest are on .zshrc's PATH.
DIRS=(.claude .vim/undodir .vim-tmp bin .local/bin)

# Created 0700. The oh-my-zsh ssh-agent plugin warns on every shell start
# without ~/.ssh, and ssh itself refuses a group- or world-readable one.
PRIVATE_DIRS=(.ssh)

PACKAGES=(zsh vim git curl less ack git-lfs)

GITCONFIG_LOCAL="$HOME/.gitconfig.local"
MARKER_BEGIN="# >>> dotfiles: diffr fallback >>>"
MARKER_END="# <<< dotfiles: diffr fallback <<<"

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

FULL=0
DRY_RUN=0
WARNINGS=0
REPO_DIR=""
backup_dir_ready=0

# --- output -----------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
    C_RESET=""; C_DIM=""; C_BOLD=""
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ok()   { printf '    %sok%s   %s\n' "$C_GREEN" "$C_RESET" "$*"; }
act()  { printf '    %s->%s   %s\n' "$C_BLUE" "$C_RESET" "$*"; }
warn() { printf '    %swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
die()  { printf '%serror%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, or describe it when --dry-run. Only for plain argv commands;
# anything needing a redirect or pipe guards on $DRY_RUN directly.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '    %sdry%s  %s\n' "$C_DIM" "$C_RESET" "$*"
        return 0
    fi
    "$@"
}

usage() {
    cat <<'EOF'
Usage: install.sh [--full] [--dry-run] [--help]

Sets up remoun/dotfiles on this machine.

By default it only creates directories, symlinks the dotfiles into $HOME and
writes ~/.gitconfig.local. It also exports LANG from ~/.zshenv if the current
locale is not UTF-8, because .vimrc's listchars need one. Nothing is downloaded
and nothing outside $HOME is touched.

Options:
  --full       Also install OS packages, oh-my-zsh + the spaceship theme, the
               diffr/git-absorb binaries .gitconfig depends on, generate a
               UTF-8 locale, and set zsh as the login shell. Uses sudo for the
               package steps when not root.
  -n, --dry-run
               Print every action without performing it.
  -h, --help   Show this message.

Bootstrapping a bare VPS (note: bash, not sh):

  curl -fsSL https://raw.githubusercontent.com/remoun/dotfiles/main/install.sh | bash -s -- --full

That clones the repo over HTTPS to ~/code/dotfiles, rewrites origin to the SSH
URL for later pushes, and re-runs itself from there. Override the destination
with DOTFILES_DIR=/path.

On a minimal Alpine image, `apk add bash git curl` first.
EOF
}

# --- repo location ----------------------------------------------------------

# The repo root is wherever this script lives, unless we were piped in from
# curl, in which case BASH_SOURCE is a shell name or an fd and we clone.
script_dir() {
    local src="${BASH_SOURCE[0]:-}"
    case "$src" in
        ""|bash|-bash|sh|-sh|/dev/fd/*|/proc/self/fd/*|/dev/stdin) return 1 ;;
    esac
    ( cd "$(dirname "$src")" >/dev/null 2>&1 && pwd ) || return 1
}

is_repo() { [ -f "$1/.zshrc" ] && [ -f "$1/.gitconfig" ]; }

bootstrap() {
    if [ -n "${DOTFILES_BOOTSTRAPPED:-}" ]; then
        die "bootstrap loop: $CLONE_DEST does not look like the dotfiles repo"
    fi
    have git || die "git is required to bootstrap; install it and re-run"

    step "Bootstrapping from $REPO_URL_HTTPS"
    if [ -d "$CLONE_DEST/.git" ]; then
        ok "clone already present at $CLONE_DEST"
    else
        run mkdir -p "$(dirname "$CLONE_DEST")"
        run git clone "$REPO_URL_HTTPS" "$CLONE_DEST"
        act "cloned to $CLONE_DEST"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        act "would re-exec $CLONE_DEST/install.sh $*"
        exit 0
    fi

    export DOTFILES_BOOTSTRAPPED=1
    exec bash "$CLONE_DEST/install.sh" "$@"
}

# --- steps ------------------------------------------------------------------

ensure_backup_dir() {
    if [ "$backup_dir_ready" -eq 0 ]; then
        run mkdir -p "$BACKUP_DIR"
        backup_dir_ready=1
    fi
}

# Messages print ~ instead of the expanded $HOME purely for readability.
# shellcheck disable=SC2088
make_dirs() {
    step "Creating directories"
    local d
    for d in "${DIRS[@]}"; do
        if [ -d "$HOME/$d" ]; then
            ok "~/$d"
        else
            run mkdir -p "$HOME/$d"
            act "~/$d"
        fi
    done
    for d in "${PRIVATE_DIRS[@]}"; do
        if [ -d "$HOME/$d" ]; then
            ok "~/$d"
        else
            run mkdir -p "$HOME/$d"
            act "~/$d"
        fi
        run chmod 700 "$HOME/$d"
    done
}

link_file() {
    local src="$1" dest="$2"
    local name="${dest##*/}"

    # Accept a link already pointing at the right file whether it was written
    # absolute or relative. -ef compares device and inode, so it resolves the
    # link itself, with no readlink -f (absent on older macOS). A readlink
    # string compare misses the relative form and so relinks correct files,
    # backing each one up, on every single run.
    if [ -L "$dest" ] && [ "$dest" -ef "$src" ]; then
        ok "$name"
        return 0
    fi

    # -e is false for a broken symlink, hence the explicit -L.
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        ensure_backup_dir
        run mv "$dest" "$BACKUP_DIR/$name"
        act "$name (existing moved to $BACKUP_DIR/)"
    else
        act "$name"
    fi

    run ln -s "$src" "$dest"
}

link_dotfiles() {
    step "Linking dotfiles into $HOME"
    local f
    for f in "${DOTFILES[@]}"; do
        [ -f "$REPO_DIR/$f" ] || { warn "$f missing from $REPO_DIR, skipped"; continue; }
        link_file "$REPO_DIR/$f" "$HOME/$f"
    done
}

# shellcheck disable=SC2088  # ~ in messages is display text, not a path
setup_gitconfig_local() {
    step "Local git overrides"

    if [ -e "$GITCONFIG_LOCAL" ]; then
        ok "~/.gitconfig.local"
    elif [ "$DRY_RUN" -eq 1 ]; then
        act "~/.gitconfig.local (would create)"
    else
        cat >"$GITCONFIG_LOCAL" <<'EOF'
# Machine-local git config, not tracked by the dotfiles repo.
# Included from the bottom of ~/.gitconfig, so anything set here wins.
#
# Useful for a per-machine identity:
#   [user]
#       email = you@example.com
EOF
        act "~/.gitconfig.local (created)"
    fi

    if have diffr; then
        ok "diffr found, pager left as configured"
        return 0
    fi

    if [ -e "$GITCONFIG_LOCAL" ] && grep -qF "$MARKER_BEGIN" "$GITCONFIG_LOCAL"; then
        ok "diffr fallback already in place"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        act "would neutralize the diffr pager in ~/.gitconfig.local"
        return 0
    fi

    cat >>"$GITCONFIG_LOCAL" <<EOF

$MARKER_BEGIN
# diffr was not on PATH when install.sh ran, and .gitconfig pipes every diff
# through it. Without this, git diff and git log print nothing and git add -p
# breaks. Install diffr (cargo install diffr) and delete this block.
[core]
    pager = less -R
[interactive]
    diffFilter = cat
$MARKER_END
EOF
    warn "diffr not found, neutralized the git pager in ~/.gitconfig.local"
}

ZSHENV="$HOME/.zshenv"
LOCALE_BEGIN="# >>> dotfiles: utf-8 locale >>>"
LOCALE_END="# <<< dotfiles: utf-8 locale <<<"

env_is_utf8() {
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *[Uu][Tt][Ff]-8|*[Uu][Tt][Ff]8) return 0 ;;
        *) return 1 ;;
    esac
}

# Print the best UTF-8 locale this system can actually offer, if any.
available_utf8_locale() {
    have locale || return 1
    local list
    list="$(locale -a 2>/dev/null)" || return 1
    printf '%s\n' "$list" | grep -qiE '^en_US\.utf-?8$' && { printf 'en_US.UTF-8'; return 0; }
    printf '%s\n' "$list" | grep -qiE '^C\.utf-?8$' && { printf 'C.UTF-8'; return 0; }
    return 1
}

# shellcheck disable=SC2086  # $sudo_cmd is empty when already root
generate_utf8_locale() {
    have apt-get || return 1
    local sudo_cmd
    sudo_cmd="$(sudo_prefix)" || return 1
    if [ "$DRY_RUN" -eq 1 ]; then
        act "would install locales and generate en_US.UTF-8"
        return 1
    fi
    env DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get install -y -qq locales >/dev/null 2>&1 || return 1
    [ -f /etc/locale.gen ] || return 1
    $sudo_cmd sed -i 's/^# *\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen || return 1
    $sudo_cmd /usr/sbin/locale-gen >/dev/null 2>&1 || $sudo_cmd locale-gen >/dev/null 2>&1 || return 1
    return 0
}

# shellcheck disable=SC2088  # ~ in messages is display text, not a path
setup_locale() {
    step "UTF-8 locale"
    # .vimrc's listchars uses multibyte glyphs. Under LANG=C, the default on a
    # fresh Debian, vim aborts .vimrc with E474 on every launch.
    if env_is_utf8; then
        ok "current locale is already UTF-8"
        return 0
    fi

    local loc=""
    loc="$(available_utf8_locale)" || loc=""
    if [ -z "$loc" ] && [ "$FULL" -eq 1 ] && generate_utf8_locale; then
        act "generated en_US.UTF-8"
        loc="$(available_utf8_locale)" || loc=""
    fi

    if [ -z "$loc" ]; then
        warn "no UTF-8 locale available; vim will report E474 from .vimrc listchars"
        return 0
    fi

    if [ -e "$ZSHENV" ] && grep -qF "$LOCALE_BEGIN" "$ZSHENV"; then
        ok "LANG already exported from ~/.zshenv"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        act "would export LANG=$loc from ~/.zshenv"
        return 0
    fi

    cat >>"$ZSHENV" <<EOF

$LOCALE_BEGIN
# .vimrc uses multibyte listchars, which vim rejects with E474 under a
# non-UTF-8 locale. Safe to delete once the system locale is set properly.
export LANG=$loc
$LOCALE_END
EOF
    act "exported LANG=$loc from ~/.zshenv"
}

# chsh(1) edits /etc/passwd directly, so it cannot touch an account that NSS
# serves from somewhere else. getent finds such a user, which is why the shell
# lookup above succeeds right before chsh fails.
user_in_etc_passwd() {
    cut -d: -f1 /etc/passwd 2>/dev/null | grep -qxF "$1"
}

sudo_prefix() {
    if [ "$(id -u)" -eq 0 ]; then
        printf ''
    elif have sudo; then
        printf 'sudo'
    else
        return 1
    fi
}

# $sudo_cmd and $installer are deliberately unquoted: sudo_cmd is empty when
# we are already root, and installer is a multi-word command that must split.
# shellcheck disable=SC2086
install_packages() {
    step "Installing packages"

    local sudo_cmd
    if ! sudo_cmd="$(sudo_prefix)"; then
        warn "not root and no sudo available, skipping packages"
        return 0
    fi

    local installer=""
    if have apt-get; then
        run env DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get update -qq \
            || warn "apt-get update failed, continuing anyway"
        installer="env DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get install -y -qq"
    elif have dnf; then
        installer="$sudo_cmd dnf install -y"
    elif have apk; then
        installer="$sudo_cmd apk add --no-cache"
    elif have pacman; then
        installer="$sudo_cmd pacman -S --needed --noconfirm"
    else
        warn "no supported package manager found, skipping packages"
        return 0
    fi

    # Try the batch first; fall back to one at a time so a single bad package
    # name (they drift across distros) does not sink the rest.
    if run $installer "${PACKAGES[@]}"; then
        act "installed: ${PACKAGES[*]}"
        return 0
    fi

    warn "batch install failed, retrying individually"
    local p
    for p in "${PACKAGES[@]}"; do
        if run $installer "$p"; then
            act "$p"
        else
            warn "could not install $p"
        fi
    done
}

install_omz() {
    step "Installing oh-my-zsh and the spaceship theme"

    local omz="$HOME/.oh-my-zsh"
    if [ -d "$omz" ]; then
        ok "oh-my-zsh"
    else
        run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz" \
            || { warn "oh-my-zsh clone failed"; return 0; }
        act "oh-my-zsh"
    fi

    # .zshrc sets ZSH_THEME=spaceship, which oh-my-zsh resolves against
    # $ZSH_CUSTOM/themes/spaceship.zsh-theme.
    local custom="${ZSH_CUSTOM:-$omz/custom}"
    local theme_repo="$custom/themes/spaceship-prompt"
    run mkdir -p "$custom/themes"

    if [ -d "$theme_repo" ]; then
        ok "spaceship theme"
    else
        run git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git "$theme_repo" \
            || { warn "spaceship clone failed"; return 0; }
        act "spaceship theme"
    fi
    run ln -sf "$theme_repo/spaceship.zsh-theme" "$custom/themes/spaceship.zsh-theme"
}

install_git_tools() {
    step "Installing the tools .gitconfig depends on"

    local tool
    for tool in diffr git-absorb; do
        if have "$tool"; then
            ok "$tool"
        elif have cargo; then
            if run cargo install "$tool"; then
                act "$tool"
            else
                warn "cargo install $tool failed"
            fi
        else
            warn "$tool not installed: no cargo on PATH"
        fi
    done

    if ! have cargo && { ! have diffr || ! have git-absorb; }; then
        warn "install rust, then re-run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    fi
}

set_login_shell() {
    step "Setting the login shell"

    local zsh_path
    zsh_path="$(command -v zsh || true)"
    if [ -z "$zsh_path" ]; then
        warn "zsh not found, cannot change the login shell"
        return 0
    fi

    local me current
    me="$(id -un)"
    current="${SHELL:-}"
    if have getent; then
        current="$(getent passwd "$me" | cut -d: -f7)"
    fi
    case "$current" in
        */zsh) ok "already $current"; return 0 ;;
    esac

    # chsh refuses a shell that is not listed in /etc/shells.
    if [ -f /etc/shells ] && ! grep -qxF "$zsh_path" /etc/shells; then
        local sudo_cmd
        if sudo_cmd="$(sudo_prefix)"; then
            if [ "$DRY_RUN" -eq 1 ]; then
                act "would add $zsh_path to /etc/shells"
            elif printf '%s\n' "$zsh_path" | $sudo_cmd tee -a /etc/shells >/dev/null; then
                act "added $zsh_path to /etc/shells"
            else
                warn "could not add $zsh_path to /etc/shells"
            fi
        else
            warn "$zsh_path is not in /etc/shells and there is no sudo"
        fi
    fi

    if run chsh -s "$zsh_path"; then
        act "login shell set to $zsh_path"
    elif ! user_in_etc_passwd "$me"; then
        warn "chsh cannot change this account: $me is not in /etc/passwd"
        cat <<EOF

    $me is served by NSS rather than /etc/passwd (LDAP/SSSD, systemd-homed, or
    a provider login agent), and chsh only edits /etc/passwd. Set the login
    shell wherever the account is actually managed. Failing that, have bash
    hand off to zsh on login:

        echo '[ -z "\$ZSH_VERSION" ] && [ -t 1 ] && exec zsh -l' >> ~/.bashrc

EOF
    else
        warn "chsh failed, run it yourself: chsh -s $zsh_path"
    fi
}

summary() {
    step "Done"
    printf '    repo:    %s\n' "$REPO_DIR"
    if [ "$backup_dir_ready" -eq 1 ]; then
        printf '    backups: %s\n' "$BACKUP_DIR"
    fi
    if [ "$WARNINGS" -gt 0 ]; then
        printf '    %s%d warning(s) above%s\n' "$C_YELLOW" "$WARNINGS" "$C_RESET"
    fi

    if [ "$FULL" -eq 0 ] && [ ! -d "$HOME/.oh-my-zsh" ]; then
        printf '\n    oh-my-zsh is not installed, so zsh will start without a theme.\n'
        printf '    Re-run with --full to install it.\n'
    fi
    printf '\n    Start a new shell, or: exec zsh\n'
}

# --- main -------------------------------------------------------------------

main() {
    local args=("$@")

    while [ $# -gt 0 ]; do
        case "$1" in
            --full)         FULL=1 ;;
            -n|--dry-run)   DRY_RUN=1 ;;
            -h|--help)      usage; exit 0 ;;
            *)              printf 'unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done

    local dir
    if dir="$(script_dir)" && is_repo "$dir"; then
        REPO_DIR="$dir"
    else
        bootstrap "${args[@]+"${args[@]}"}"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%sdry run: nothing will be changed%s\n' "$C_DIM" "$C_RESET"
    fi

    if [ "$FULL" -eq 1 ]; then
        install_packages
        install_omz
        install_git_tools
    fi

    make_dirs
    link_dotfiles
    setup_gitconfig_local
    setup_locale

    if [ "$FULL" -eq 1 ]; then
        set_login_shell
    fi

    summary
}

main "$@"
