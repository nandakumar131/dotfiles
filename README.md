# dotfiles

Personal dotfiles for macOS and Linux. Symlinked into place and packages
installed via [Homebrew](https://brew.sh) on both platforms.

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
config files added later) - it installs Homebrew if missing, installs
packages from `packages/Brewfile` (and `packages/Brewfile.mac` on
macOS only, for GUI apps), then symlinks every config into place. Anything
already at a destination path gets backed up (`<file>.backup-<timestamp>`)
before being replaced.

Update the alias `dotup` does exactly this: `git pull && ./install.sh`.

## What's here

| Path                  | Linked to                    |
|------------------------|-------------------------------|
| `config/zsh/zshrc`     | `~/.zshrc`                    |
| `config/git/gitconfig` | `~/.gitconfig`                |
| `config/nvim`          | `~/.config/vimrc`             |
| `config/alacritty`     | `~/.config/alacritty`         |
| `config/kitty`         | `~/.config/kitty`             |
| `config/tmux`          | `~/.config/tmux`              |
| `config/starship/starship_hyprland.toml` | `~/.config/starship.toml` |

`config/zsh/alias` and `config/zsh/functions` are sourced directly by
`zshrc`, not linked standalone. `zshrc` itself only sources/inits tools that
are actually installed (`fzf`, `starship`, `atuin`, `zoxide`, `direnv`,
`fzf-tab`, `zsh-autosuggestions`, `zsh-syntax-highlighting`), so it won't
error on a machine missing any of them.

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

Not tracked by this repo, sourced automatically if present:

| File                 | Sourced from  | For                                                 |
|----------------------|---------------|------------------------------------------------------|
| `~/.alias.local`     | `zshrc`       | extra/overriding aliases                             |
| `~/.functions.local` | `zshrc`       | extra/overriding functions                           |
| `~/.zshrc.local`     | `zshrc` (end) | machine/work-specific env vars, tokens, PATH entries |

Anything machine-specific or secret (API tokens, work-only SDK paths, etc.)
belongs in `~/.zshrc.local`, never in the tracked `zshrc`.

## Checking your setup

```sh
~/.dotfiles/doctor.sh
```

Read-only report of which symlinks are correct/stale/missing and which
expected CLI tools aren't on `PATH`. Doesn't change anything - re-run
`install.sh` to fix what it finds.
