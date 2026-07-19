#!/usr/bin/env bash
# One-command setup for a brand new machine/container:
#
#   curl -fsSL https://raw.githubusercontent.com/nandakumar131/dotfiles/main/bootstrap.sh | bash
#
# Clones (or updates) this repo to ~/.dotfiles and runs install.sh.
# Safe to re-run - install.sh itself is idempotent.
set -euo pipefail

REPO_URL="https://github.com/nandakumar131/dotfiles.git"
DOTFILES_DIR="${HOME}/.dotfiles"

if [ -d "${DOTFILES_DIR}/.git" ]; then
	echo "~/.dotfiles already exists, pulling latest instead of cloning..."
	git -C "$DOTFILES_DIR" pull --ff-only
else
	command -v git >/dev/null 2>&1 || {
		echo "git is required to bootstrap this repo, install it first." >&2
		exit 1
	}
	git clone "$REPO_URL" "$DOTFILES_DIR"
fi

exec "${DOTFILES_DIR}/install.sh"
