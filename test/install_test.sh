#!/usr/bin/env bash
#
# Exercises install.sh against a throwaway $HOME. Safe to run anywhere: every
# path install.sh touches is derived from $HOME, so pointing that at a temp
# directory sandboxes the whole thing. Nothing here needs root or a network.
#
#   ./test/install_test.sh
#
# This covers the default tier only. The --full tier installs packages and
# changes the login shell, so it needs a disposable machine:
#
#   docker run --rm -v "$PWD:/repo:ro" debian:bookworm bash /repo/install.sh --full

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A PATH with coreutils and git but, on any sane machine, no diffr - so the
# fallback branch is what gets exercised unless a test says otherwise.
BARE_PATH=/usr/bin:/bin:/usr/sbin:/sbin

PASS=0
FAIL=0

check() { # check <description> <command...>
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf '  PASS  %s\n' "$desc"; PASS=$((PASS + 1))
    else
        printf '  FAIL  %s\n' "$desc"; FAIL=$((FAIL + 1))
    fi
}

# BSD and GNU userland disagree on both of these.
hashsum() { if command -v md5sum >/dev/null 2>&1; then md5sum; else md5; fi; }
filemode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

install_to() { # install_to <home> [env assignments...] -- runs the default tier
    local home="$1"; shift
    env HOME="$home" PATH="$BARE_PATH" "$@" bash "$REPO/install.sh" >/dev/null 2>&1
}

echo "== dry run changes nothing =="
H=$(mktemp -d)
env HOME="$H" PATH="$BARE_PATH" bash "$REPO/install.sh" --dry-run >/dev/null 2>&1
check "no files created" [ -z "$(ls -A "$H")" ]

echo "== default tier =="
H=$(mktemp -d)
install_to "$H"
for f in .zshrc .vimrc .gitconfig .gitignore .ackrc; do
    check "$f is a symlink to the repo" [ "$(readlink "$H/$f")" = "$REPO/$f" ]
done
for d in .vim/undodir .vim-tmp bin .local/bin; do
    check "dir $d created" [ -d "$H/$d" ]
done
check ".gitconfig.local created" [ -f "$H/.gitconfig.local" ]
check ".ssh created" [ -d "$H/.ssh" ]
check ".ssh is mode 700" [ "$(filemode "$H/.ssh")" = "700" ]
check "no backup dir when nothing to back up" [ ! -d "$H/.dotfiles-backup" ]

echo "== diffr absent: fallback written and honoured by git =="
check "fallback marker present" grep -q "dotfiles: diffr fallback" "$H/.gitconfig.local"
check "core.pager resolves to 'less -R'" \
    [ "$(env HOME="$H" git config --get core.pager)" = "less -R" ]
check "interactive.diffFilter resolves to 'cat'" \
    [ "$(env HOME="$H" git config --get interactive.diffFilter)" = "cat" ]
check "user.name still inherited from the repo .gitconfig" \
    [ -n "$(env HOME="$H" git config --get user.name)" ]

echo "== re-running is idempotent =="
before=$(cd "$H" && find . | sort | hashsum)
install_to "$H"
after=$(cd "$H" && find . | sort | hashsum)
check "filesystem unchanged on second run" [ "$before" = "$after" ]
check "fallback block not duplicated" \
    [ "$(grep -c 'diffr fallback >>>' "$H/.gitconfig.local")" = "1" ]

echo "== existing real files are backed up, not clobbered =="
H=$(mktemp -d)
echo "pre-existing" > "$H/.zshrc"
echo "pre-existing" > "$H/.gitconfig"
install_to "$H"
check "backup dir created" [ -d "$H/.dotfiles-backup" ]
B=$(find "$H/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d | head -1)
check "old .zshrc preserved" grep -q "pre-existing" "$B/.zshrc"
check "old .gitconfig preserved" grep -q "pre-existing" "$B/.gitconfig"
check ".zshrc now links to the repo" [ "$(readlink "$H/.zshrc")" = "$REPO/.zshrc" ]

echo "== a symlink pointing somewhere else is backed up too =="
H=$(mktemp -d)
ln -s /etc/hosts "$H/.ackrc"
install_to "$H"
check ".ackrc relinked to the repo" [ "$(readlink "$H/.ackrc")" = "$REPO/.ackrc" ]
check "foreign link preserved in backup" [ -n "$(find "$H/.dotfiles-backup" -name .ackrc)" ]

echo "== diffr present: config left alone =="
H=$(mktemp -d)
FAKEBIN=$(mktemp -d)
printf '#!/bin/sh\ncat\n' > "$FAKEBIN/diffr"
chmod +x "$FAKEBIN/diffr"
env HOME="$H" PATH="$FAKEBIN:$BARE_PATH" bash "$REPO/install.sh" >/dev/null 2>&1
check "no fallback block written" \
    bash -c "! grep -q 'diffr fallback' '$H/.gitconfig.local'"
check "pager left as configured" \
    [ "$(env HOME="$H" git config --get core.pager)" = "diffr | less -R" ]

echo "== locale handling =="
H=$(mktemp -d)
install_to "$H" LANG=en_US.UTF-8
check "UTF-8 environment: .zshenv left alone" [ ! -f "$H/.zshenv" ]
H=$(mktemp -d)
install_to "$H" LANG=C LC_ALL=C
check "LANG=C: .zshenv written" [ -f "$H/.zshenv" ]
check "LANG=C: exports a UTF-8 LANG" grep -qE '^export LANG=(en_US|C)\.UTF-8$' "$H/.zshenv"
install_to "$H" LANG=C LC_ALL=C
check "LANG=C: block not duplicated" [ "$(grep -c 'utf-8 locale >>>' "$H/.zshenv")" = "1" ]
H=$(mktemp -d)
printf 'alias foo=bar\n' > "$H/.zshenv"
install_to "$H" LANG=C LC_ALL=C
check "existing .zshenv contents preserved" grep -q 'alias foo=bar' "$H/.zshenv"

echo "== piped from stdin: bootstraps instead of guessing a repo =="
H=$(mktemp -d)
out=$(env HOME="$H" PATH="$BARE_PATH" bash -s -- --dry-run < "$REPO/install.sh" 2>&1)
check "detects it is not inside a repo" \
    bash -c "printf '%s' \"\$1\" | grep -q Bootstrapping" _ "$out"
check "would clone to \$HOME/code/dotfiles" \
    bash -c "printf '%s' \"\$1\" | grep -q 'code/dotfiles'" _ "$out"
check "clones over HTTPS" \
    bash -c "printf '%s' \"\$1\" | grep -q 'https://github.com/remoun/dotfiles.git'" _ "$out"
check "leaves origin on HTTPS (no set-url)" \
    bash -c "! printf '%s' \"\$1\" | grep -q 'set-url'" _ "$out"
check "nothing actually created" [ -z "$(ls -A "$H")" ]

echo "== CLI contract =="
H=$(mktemp -d)
env HOME="$H" bash "$REPO/install.sh" --help >/dev/null 2>&1
check "--help exits 0" [ $? -eq 0 ]
env HOME="$H" bash "$REPO/install.sh" --bogus >/dev/null 2>&1
check "unknown flag exits 2" [ $? -eq 2 ]

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
