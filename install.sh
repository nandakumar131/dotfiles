#!/usr/bin/env bash
# Safe to re-run any time (e.g. after `git pull`) - already-correct links
# are skipped, and anything at a destination path is backed up before
# being replaced.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/lib/link.sh"

OS="$(uname -s)"

install_homebrew_if_missing() {
	if command -v brew >/dev/null 2>&1; then
		return
	fi
	echo "Homebrew not found, installing it..."
	NONINTERACTIVE=1 /bin/bash -c \
		"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	if [ "$OS" = "Linux" ] && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	fi
}

install_packages() {
	install_homebrew_if_missing
	if ! command -v brew >/dev/null 2>&1; then
		echo "! Homebrew still not on PATH - skipping package install, run brew bundle manually." >&2
		return
	fi

	brew bundle --file="${SCRIPT_DIR}/config/brew/Brewfile" || echo "! some packages from Brewfile failed to install" >&2

	if [ "$OS" = "Darwin" ]; then
		brew bundle --file="${SCRIPT_DIR}/config/brew/Brewfile.mac" || echo "! some casks from Brewfile.mac failed to install" >&2
	fi

	if [ ! -d "${HOME}/.sdkman" ]; then
		curl -s "https://get.sdkman.io" | bash || echo "! sdkman install failed" >&2
	fi
}

install_packages
link_all

cat <<'EOF'

Done. Open a new shell to pick everything up.
EOF
