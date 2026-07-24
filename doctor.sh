#!/usr/bin/env bash
# Report the health of this dotfiles install: which symlinks are correct,
# stale, or missing, and which expected tools aren't on PATH. Read-only -
# never modifies anything. Run ./install.sh to fix what it reports.
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/lib/link.sh"

echo "== symlinks =="
check_all

echo
echo "== tools =="
# formula name : binary name (they differ for a few Brewfile entries)
TOOLS=(
	"brew:brew"
	"git:git"
	"gh:gh"
	"tmux:tmux"
	"neovim:nvim"
	"fzf:fzf"
	"ripgrep:rg"
	"bat:bat"
	"lsd:lsd"
	"walk:walk"
	"jq:jq"
	"yq:yq"
	"starship:starship"
	"atuin:atuin"
	"zoxide:zoxide"
	"direnv:direnv"
	"ast-grep:sg"
	"source-highlight:source-highlight"
	"maven:mvn"
	"fd:fd"
	"difftastic:difft"
	"sesh:sesh"
	"gum:gum"
	"tealdeer:tldr"
	"btop:btop"
	"dust:dust"
	"procs:procs"
)

for entry in "${TOOLS[@]}"; do
	name="${entry%%:*}"
	bin="${entry##*:}"
	if command -v "$bin" >/dev/null 2>&1; then
		echo "OK      ${name}"
	else
		echo "MISSING ${name} (expects '${bin}' on PATH)"
	fi
done
