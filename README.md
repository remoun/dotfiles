# dotfiles

Personal `zsh`, `vim`, `git` and `ack` configuration.

## Install

On a machine that already has the repo:

```sh
git clone git@github.com:remoun/dotfiles.git ~/code/dotfiles
~/code/dotfiles/install.sh
```

On a bare VPS, where there is no SSH key for GitHub yet:

```sh
curl -fsSL https://raw.githubusercontent.com/remoun/dotfiles/main/install.sh | bash -s -- --full
```

That clones over HTTPS to `~/code/dotfiles`, rewrites `origin` to the SSH URL so
later pushes work, and re-runs itself from the clone. Set `DOTFILES_DIR` to
clone somewhere else. Note `bash`, not `sh` — on a minimal Alpine image,
`apk add bash git curl` first.

## What it does

`install.sh` has two tiers.

**Default.** Touches only `$HOME`, never uses the network:

- Symlinks `.ackrc`, `.gitconfig`, `.gitignore`, `.vimrc` and `.zshrc` into
  `$HOME`. `.gitignore` is included on purpose — `.gitconfig` points
  `core.excludesfile` at `~/.gitignore`.
- Creates `~/.vim/undodir` (without it vim silently discards persistent undo),
  `~/.vim-tmp`, `~/bin`, `~/.local/bin`, and `~/.ssh` at mode 700 (the
  oh-my-zsh `ssh-agent` plugin warns on every shell start without it).
- Creates `~/.gitconfig.local`, and neutralizes the `diffr` pager there if
  `diffr` is not installed. See below.
- Exports `LANG` from `~/.zshenv` if the current locale is not UTF-8.
  `.vimrc`'s `listchars` uses multibyte glyphs, which vim rejects with `E474`
  under `LANG=C` — the default on a fresh Debian.

**`--full`.** Everything above, plus:

- OS packages via `apt-get`, `dnf`, `apk` or `pacman`: `zsh vim git curl less
  ack git-lfs`. Uses `sudo` when not already root.
- oh-my-zsh and the spaceship theme.
- `diffr` and `git-absorb`, via `cargo` if it is available.
- Generates a UTF-8 locale if the system has none at all.
- Sets zsh as the login shell.

`--dry-run` prints every action without performing it. `--help` for the rest.

Re-running is safe. Anything already in place is left alone, and a real file
sitting where a symlink belongs is moved to `~/.dotfiles-backup/<timestamp>/`
rather than overwritten.

## Per-machine configuration

Two files stay out of the repo and hold whatever is specific to one machine:

- `~/.zshenv` — sourced by zsh at startup and again from the bottom of
  `.zshrc`. Machine-local aliases, `PATH` entries, environment.
- `~/.gitconfig.local` — included from the *bottom* of `.gitconfig`, so
  anything set there overrides the tracked config. A different `user.email`
  per machine goes here.

The `.gitconfig.local` include is also the escape hatch for `diffr`.
`.gitconfig` sets `core.pager = diffr | less -R` and
`interactive.diffFilter = diffr`, so on a box without `diffr` installed
`git diff` and `git log` print nothing at all and `git add -p` breaks. When the
installer does not find `diffr` it writes a marked block into
`~/.gitconfig.local` falling back to plain `less -R`. Install `diffr` and
delete the block to get the colours back.

## Tests

```sh
./test/install_test.sh
```

Runs the default tier against a throwaway `$HOME`, so it is safe on a machine
that is already set up. Needs no root and no network.

The `--full` tier changes the login shell and installs packages, so it wants a
disposable machine:

```sh
docker run --rm -v "$PWD:/repo:ro" debian:bookworm bash /repo/install.sh --full
```

## Credits

Much of `.zshrc` began life as the [oh-my-zsh][omz] zshrc template, which is
MIT licensed. A couple of lines are credited inline to their original sources.

[omz]: https://github.com/ohmyzsh/ohmyzsh

## License

MIT — see [LICENSE](LICENSE).
