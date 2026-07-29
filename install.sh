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

install_git_packages() {
	local file="$1"
	local name dest repo
	while IFS='|' read -r name dest repo; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		dest="${dest/#\~/$HOME}"
		if [ ! -d "$dest" ]; then
			echo "installing ${name}..."
			git clone "$repo" "$dest" || echo "! ${name} install failed" >&2
		fi
	done < "$file"
}

install_script_packages() {
	local file="$1"
	local name dest cmd
	while IFS='|' read -r name dest cmd; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		dest="${dest/#\~/$HOME}"
		if [ ! -d "$dest" ]; then
			echo "installing ${name}..."
			eval "$cmd" || echo "! ${name} install failed" >&2
		fi
	done < "$file"
}

install_packages() {
	install_homebrew_if_missing
	if ! command -v brew >/dev/null 2>&1; then
		echo "! Homebrew still not on PATH - skipping package install, run brew bundle manually." >&2
		return
	fi

	brew bundle --file="${SCRIPT_DIR}/packages/Brewfile" || echo "! some packages from Brewfile failed to install" >&2

	if [ "$OS" = "Darwin" ]; then
		brew bundle --file="${SCRIPT_DIR}/packages/Brewfile.mac" || echo "! some casks from Brewfile.mac failed to install" >&2
	fi

	install_script_packages "${SCRIPT_DIR}/packages/script.install"
	install_git_packages "${SCRIPT_DIR}/packages/git.install"
}

install_packages
link_all

cat <<'EOF'

Done. Open a new shell to pick everything up.
EOF
