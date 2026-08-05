#!/usr/bin/env bash
# Shared linking logic used by install.sh and doctor.sh.
# Keeping the src -> dest mapping in one place so it's easy to extend.

DOTFILES_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)

# Parallel arrays (not an associative array - macOS ships bash 3.2, which
# doesn't have them) of repo-relative source paths and their $HOME dest.
LINK_SRC=(
	"config/zsh/zshrc"
	"config/git/gitconfig"
	"config/alacritty"
	"config/kitty"
	"config/tmux/tmux.conf"
	"config/karabiner/karabiner.json"
	"config/starship/starship_hyprland.toml"
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

# link_item <repo-relative-src> <dest-path>
link_item() {
	local src="${DOTFILES_DIR}/$1"
	local dest="$2"

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
		link_item "${LINK_SRC[$i]}" "${LINK_DEST[$i]}"
	done
}

# check_item <repo-relative-src> <dest-path>
# Read-only status check used by doctor.sh - never touches the filesystem.
check_item() {
	local src="${DOTFILES_DIR}/$1"
	local dest="$2"

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
		check_item "${LINK_SRC[$i]}" "${LINK_DEST[$i]}"
	done
}
