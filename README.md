# dotfiles

Personal dotfiles for macOS and Linux. Symlinked into place; packages installed via
[Homebrew](https://brew.sh) on macOS or the native package manager on Linux.

## Setup

**Brand new machine/container** (no clone needed):

```sh
curl -fsSL https://raw.githubusercontent.com/nandakumar131/dotfiles/main/bootstrap.sh | bash
```

This clones the repo to `~/.dotfiles` and runs `install.sh`.

**Already cloned:**

```sh
~/.dotfiles/install.sh
```

`install.sh` is safe to re-run any time (e.g. after `git pull`, or to pick up
config files added later) - it installs packages (via Homebrew on macOS, or the
native package manager on Linux - see below), then symlinks every config into
place. Anything already at a destination path gets backed up
(`<file>.backup-<timestamp>`) before being replaced.

Update the alias `dotup` does exactly this: `git pull && ./install.sh`.

## Cross-platform package installation

`packages/packages.list` is a single, package-manager-agnostic manifest (one row per
tool, with a column per manager). `install.sh` detects the platform and picks the
right column: Homebrew on macOS, otherwise the first of `apt`/`dnf`/`pacman` found on
`PATH` (`zypper`/`apk` are detected but don't have verified package-name mappings yet -
anything landing there is reported as "install manually"). A tool already on `PATH` -
however it got there - is never reinstalled, and a manifest row with no known package
for the detected manager just prints a one-line "install manually" notice instead of
guessing.

A handful of tools (`starship`, `atuin`, `yq` on distros where they're not in the
default repos; the `zsh-autosuggestions`/`zsh-syntax-highlighting`/`fzf-tab` zsh
plugins everywhere) are installed via their official curl script or a plain
`git clone` instead - see `packages/script.install`/`packages/git.install`, which use
the same "skip if the binary or destination directory already exists" logic.

GUI apps (Alacritty, iTerm2, Rectangle, Karabiner-Elements) are intentionally **not**
automated - install them by hand. Their config files are still symlinked automatically
once the app is present (see below).

## What's here

| Path                  | Linked to                    |
|------------------------|-------------------------------|
| `config/zsh/zshrc`     | `~/.zshrc`                    |
| `config/git/gitconfig` | `~/.gitconfig`                |
| `config/nvim`          | `~/.config/vimrc`             |
| `config/alacritty`     | `~/.config/alacritty`         |
| `config/kitty`         | `~/.config/kitty`             |
| `config/tmux`          | `~/.config/tmux`              |
| `config/starship/starship.toml` | `~/.config/starship.toml` |

Each config only gets symlinked if its tool is actually installed (`lib/link.sh`
checks a binary, or - for GUI apps with no CLI, like Karabiner-Elements - the
`/Applications` bundle), so `install.sh`/`doctor.sh` won't create e.g.
`~/.config/kitty` on a machine that doesn't have kitty. `zshrc` and `gitconfig`
always link, since every machine needs them.

`config/zsh/alias` and `config/zsh/functions` are sourced directly by
`zshrc`, not linked standalone. `zshrc` itself only sources/inits tools that
are actually installed (`fzf`, `starship`, `atuin`, `zoxide`, `direnv`,
`fzf-tab`, `zsh-autosuggestions`, `zsh-syntax-highlighting`), so it won't
error on a machine missing any of them; the last three fall back to a
`git clone` under `~/.config/zsh/plugins/` (see `packages/git.install`) on
distros with no native package for them.

`fd` backs `fzf`'s file/dir pickers (`Ctrl-T`, `Alt-C`), respecting
`.gitignore`. `difftastic` is the default diff for `git diff`/`git log -p`/
`git show` (`diff.external = difft` in `config/git/gitconfig`) - structural,
syntax-aware diffs instead of line-based ones. `sesh` gives a `tmux`
project/session picker - `prefix+s` inside tmux, or `so` outside it. `gum`
and `tealdeer` (`tldr`) need no config beyond being on `PATH`; `install.sh`
seeds `tldr`'s cache.

`config/sketchybar/*` is macOS-only and not installed/linked automatically -
set up manually if you use it. `bin/*.sh` (aliased as `jd`, `ji`, `pd`) are
small personal Jira/PagerDuty dashboard and lookup scripts.

`bin/launcher` is a global command launcher: `config/launcher/commands`
(read directly from `~/.dotfiles`, not symlinked) lists `alias|command`
pairs, and `Ctrl+g` (zsh, works whether or not you're in tmux) / `prefix+g`
(tmux, works even when the focused pane isn't at a shell prompt)
fuzzy-picks one by alias and pastes the resolved command into the terminal
without running it. `~/.config/launcher/commands.local` is read too if
present, for machine-local entries you don't want tracked.

## Machine-local overrides

Not tracked by this repo, sourced/read automatically if present (`doctor.sh` reports
on all of these under "local overrides"):

| File                                     | Used by            | For                                                   |
|-------------------------------------------|--------------------|--------------------------------------------------------|
| `~/.config/zsh/alias.local`               | `zshrc`            | extra/overriding aliases                                |
| `~/.config/zsh/functions.local`           | `zshrc`            | extra/overriding functions                              |
| `~/.config/zsh/zshrc.local`               | `zshrc` (end)      | machine/work-specific env vars, tokens, PATH entries    |
| `~/.config/launcher/commands.local`       | `bin/launcher`     | machine-local launcher entries                          |
| `~/.config/git/gitconfig.local`           | `config/git/gitconfig` | machine/work-specific git config (`[include]`)      |
| `~/.config/starship/prompt.char.local`    | `config/starship/starship.toml` | custom prompt-char override            |
| `~/.config/jira/jira.yaml`                | `bin/jira`         | Jira connection settings and team member nicknames      |
| `~/.config/pagerduty/pagerduty.yaml`      | `bin/pagerduty`    | PagerDuty connection settings and team member nicknames |

Anything machine-specific or secret (API tokens, work-only SDK paths, etc.)
belongs in `~/.config/zsh/zshrc.local`, never in the tracked `zshrc`.

## Checking your setup

```sh
~/.dotfiles/doctor.sh
```

Read-only report of which symlinks are correct/stale/missing/skipped (tool not
installed), which expected CLI tools aren't on `PATH`, and which of the
machine-local override files above are present. Doesn't change anything -
re-run `install.sh` to fix what it finds.
