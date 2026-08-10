#!/usr/bin/env bash
# Shared linking logic used by install.sh and doctor.sh.
# Keeping the src -> dest mapping in one place so it's easy to extend.

DOTFILES_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)

# Parallel arrays (not an associative array - macOS ships bash 3.2, which
# doesn't have them) of repo-relative source paths, their $HOME dest, and the
# requirement that must be met before linking ("always", "bin:<name>" checked
# via `command -v`, or "app:<Name>" checked against /Applications on macOS).
LINK_SRC=(
	"config/zsh/zshrc"
	"config/git/gitconfig"
	"config/alacritty"
	"config/kitty"
	"config/tmux/tmux.conf"
	"config/karabiner/karabiner.json"
	"config/starship/starship.toml"
	"config/nvim/lua/config/options.lua"
	"config/nvim/lua/config/keymaps.lua"
	"config/nvim/lua/plugins/colorscheme.lua"
)
LINK_DEST=(
	"${HOME}/.zshrc"
	"${HOME}/.gitconfig"
	"${HOME}/.config/alacritty"
	"${HOME}/.config/kitty"
	"${HOME}/.config/tmux/tmux.conf"
	"${HOME}/.config/karabiner/karabiner.json"
	"${HOME}/.config/starship.toml"
	"${HOME}/.config/nvim/lua/config/options.lua"
	"${HOME}/.config/nvim/lua/config/keymaps.lua"
	"${HOME}/.config/nvim/lua/plugins/colorscheme.lua"
)
LINK_CHECK=(
	"always"
	"always"
	"bin_or_app:alacritty:Alacritty"
	"bin_or_app:kitty:kitty"
	"bin:tmux"
	"app:Karabiner-Elements"
	"bin:starship"
	"bin:nvim"
	"bin:nvim"
	"bin:nvim"
)

# requirement_met <check> - true if the tool a config depends on is installed.
requirement_met() {
	local check="$1"

	case "$check" in
	always) return 0 ;;
	bin:*) command -v "${check#bin:}" >/dev/null 2>&1 ;;
	app:*)
		local app="${check#app:}"
		[ "$(uname -s)" = "Darwin" ] &&
			{ [ -d "/Applications/${app}.app" ] || [ -d "${HOME}/Applications/${app}.app" ]; }
		;;
	bin_or_app:*)
		# GUI apps that also ship a CLI on Linux but not always on macOS
		# (e.g. a cask/manually-installed .app with no PATH symlink).
		local rest="${check#bin_or_app:}"
		local bin="${rest%%:*}"
		local app="${rest#*:}"
		command -v "$bin" >/dev/null 2>&1 && return 0
		[ "$(uname -s)" = "Darwin" ] &&
			{ [ -d "/Applications/${app}.app" ] || [ -d "${HOME}/Applications/${app}.app" ]; }
		;;
	*) return 0 ;;
	esac
}

# link_item <repo-relative-src> <dest-path> <check>
link_item() {
	local src="${DOTFILES_DIR}/$1"
	local dest="$2"
	local check="$3"

	if ! requirement_met "$check"; then
		echo "skip (not installed): ${dest}"
		return
	fi

	if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
		echo "= up to date: ${dest}"
		return
	fi

	if [ -e "$dest" ] || [ -L "$dest" ]; then
		local backup
		backup="${dest}.backup-$(date +%Y%m%d%H%M%S)"
		mv "$dest" "$backup"
		echo "! backed up existing ${dest} -> ${backup}"
	fi

	mkdir -p "$(dirname -- "$dest")"
	ln -s "$src" "$dest"
	echo "+ linked ${dest} -> ${src}"
}

link_all() {
	local i
	for i in "${!LINK_SRC[@]}"; do
		link_item "${LINK_SRC[$i]}" "${LINK_DEST[$i]}" "${LINK_CHECK[$i]}"
	done
}

# check_item <repo-relative-src> <dest-path> <check>
# Read-only status check used by doctor.sh - never touches the filesystem.
check_item() {
	local src="${DOTFILES_DIR}/$1"
	local dest="$2"
	local check="$3"

	if ! requirement_met "$check"; then
		echo "SKIP    ${dest} (tool not installed)"
		return
	fi

	if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
		echo "OK      ${dest}"
	elif [ -e "$dest" ] || [ -L "$dest" ]; then
		echo "STALE   ${dest} (exists but not linked to the repo)"
	else
		echo "MISSING ${dest}"
	fi
}

check_all() {
	local i
	for i in "${!LINK_SRC[@]}"; do
		check_item "${LINK_SRC[$i]}" "${LINK_DEST[$i]}" "${LINK_CHECK[$i]}"
	done
}
