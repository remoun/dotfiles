# Global preferences for Remoun

## Git workflow

- **Always prefer merge commits over rebasing.** Preserves the actual
  history of how work happened, keeps blame useful, and avoids the
  "why is my commit gone?" surprises that rebasing causes. If a branch
  has noisy fixup/WIP commits, squash-merge it rather than rebasing.
- **Never force-push.** No `git push --force`, no `--force-with-lease`,
  no `git commit --amend` followed by a push. Amending rewrites a commit
  that's already on the remote, which is the same history-rewriting
  problem as rebasing. If a commit needs fixing, make a new one
  (`fix:`, `style:`, etc.). The history of the fix is itself useful
  information.

## Writing style

- **Never use em dashes or en dashes in prose.** Not the characters
  themselves, and not a spaced hyphen (` - `) standing in as a
  lookalike. Use a comma when the aside is mild, parentheses when it
  is genuinely parenthetical, a colon when the second half explains
  the first, and a period when the two halves are really two
  sentences. Plain hyphens remain fine for compound modifiers
  (`--force-with-lease`) and numeric ranges (`3-5`). This applies to
  everything you write: chat replies, code comments, commit messages,
  PR descriptions, and docs. Leave existing text alone, including
  quotations and dashes already in a file, unless cleaning them up is
  the actual task.
- **No military parlance.** Don't reach for the war metaphor: no
  "mission-critical", "war room", "battle-tested", "in the trenches",
  "on the front lines", "boots on the ground", "rally the troops",
  "attack the problem", "double down", "execute on the plan", "blast
  radius", or "tactical" and "strategic" used as filler intensifiers.
  Say the plain thing instead: this release is risky, the deploy is
  blocked, this library is well tested, let's fix the parser.
  Established technical terms that happen to have military roots are
  exempt and stay as they are: deploy, kill a process, abort, attack
  vector, defense in depth, build target, triage.

## Shell environment

- **My interactive shell is zsh**, both on macOS and on the Debian hosts I
  administer. Do not write bare zsh one-liners and hope they are portable.
  The default is to wrap: anything beyond a single trivial command goes
  through `bash -c '...'`, and anything spanning more than one line gets
  written to a file with a `#!/usr/bin/env bash` shebang and then run.
  Quietly assuming bash produces commands that fail in confusing ways, and
  the error rarely points at the shell as the cause.
- **"Trivial" means a single command with plain arguments** and no shell
  constructs: `ls -la /srv`, `git status`, `docker compose ps`. The moment
  a glob, a loop, a conditional, a `read`, an array, parameter expansion
  beyond a plain `$VAR`, or a quoting-sensitive pipeline appears, wrap it.
  Wrapping an already-portable command costs nothing; guessing wrong costs
  a debugging detour. When in doubt, wrap.
- **Prefer `#!/usr/bin/env bash` over `#!/bin/bash`.** Homebrew bash 5.3 is
  installed at `/opt/homebrew/bin/bash`, and `/opt/homebrew/bin` sits ahead
  of `/bin` on my PATH, so `env bash` and a bare `bash -c` both get 5.3 on
  macOS and 5.2 on Debian. The absolute-path form is the trap: `/bin/bash`
  is still Apple's frozen 3.2.57, where associative arrays, `${var^^}`,
  `mapfile`, and `**` globstar all fail.
- Concrete differences that have already cost time: `read -p prompt` is
  bash only, and zsh spells it `read "VAR?prompt"`; an unmatched glob is a
  fatal error in zsh rather than being passed through literally (a safety
  feature worth keeping, not a bug to work around); and `timeout` does not
  exist on macOS, where it is `gtimeout` from coreutils if installed at
  all. The `timeout` gap is a coreutils packaging difference, not a shell
  difference, so wrapping in `bash -c` does not fix it.
- Heredocs sent through `ssh` are worth extra care. Nested quoting between
  the local shell, ssh, and the remote shell has mangled scripts more than
  once. Prefer writing the script to a file and copying it over.
- A script with a shebang runs under the interpreter it names, so my login
  shell is irrelevant to it. This rule is only about ad-hoc one-liners,
  which is where the failures actually happen.
