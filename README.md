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
packages from `config/brew/Brewfile` (and `config/brew/Brewfile.mac` on
macOS only, for GUI apps), then symlinks every config into place. Anything
already at a destination path gets backed up (`<file>.backup-<timestamp>`)
before being replaced.

Update the alias `dotup` does exactly this: `git pull && ./install.sh`.

## What's here

| Path                  | Linked to                    |
|------------------------|-------------------------------|
| `config/zsh/zshrc`     | `~/.zshrc`                    |
| `config/git/gitconfig` | `~/.gitconfig`                |
| `config/vim/vimrc`     | `~/.vimrc`                    |
| `config/alacritty`     | `~/.config/alacritty`         |
| `config/kitty`         | `~/.config/kitty`             |
| `config/tmux`          | `~/.config/tmux`              |
| `config/starship/starship_hyprland.toml` | `~/.config/starship.toml` |

`config/zsh/alias` and `config/zsh/functions` are sourced directly by
`zshrc`, not linked standalone. `zshrc` itself only sources/inits tools that
are actually installed (`fzf`, `starship`, `atuin`, `z`, `zsh-autosuggestions`,
`zsh-syntax-highlighting`), so it won't error on a machine missing any of
them.

`config/sketchybar/*` is macOS-only and not installed/linked automatically -
set up manually if you use it. `bin/*.sh` (aliased as `jd`, `pd`) are small
personal dashboard scripts.

## Machine-local overrides

Not tracked by this repo, sourced automatically if present:

| File               | Sourced from  | For                                              |
|--------------------|---------------|---------------------------------------------------|
| `~/.alias`         | `zshrc`       | extra/overriding aliases                          |
| `~/.functions`     | `zshrc`       | extra/overriding functions                        |
| `~/.zshrc.local`   | `zshrc` (end) | machine/work-specific env vars, tokens, PATH entries |

Anything machine-specific or secret (API tokens, work-only SDK paths, etc.)
belongs in `~/.zshrc.local`, never in the tracked `zshrc`.

## Checking your setup

```sh
~/.dotfiles/doctor.sh
```

Read-only report of which symlinks are correct/stale/missing and which
expected CLI tools aren't on `PATH`. Doesn't change anything - re-run
`install.sh` to fix what it finds.
