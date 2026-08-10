#!/usr/bin/env bash
# Report the health of this dotfiles install: which symlinks are correct,
# stale, or missing, which expected tools aren't on PATH, and which optional
# machine-local config files are present. Read-only - never modifies anything.
# Run ./install.sh to fix what it reports.
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/lib/link.sh"
source "${SCRIPT_DIR}/lib/pkg.sh"

echo "== symlinks =="
check_all

echo
echo "== tools =="

MANAGER=$(detect_manager)
if [ "$MANAGER" = unknown ]; then
	echo "MISSING package manager (could not detect brew/apt/dnf/pacman/zypper/apk)"
else
	echo "OK      package manager: ${MANAGER}"
fi

while IFS='|' read -r name bin platforms brew_pkg apt_pkg dnf_pkg pacman_pkg; do
	[[ -z "$name" || "$name" == \#* ]] && continue

	if ! platform_applies "$platforms" "$MANAGER"; then
		echo "SKIP    ${name} (not applicable on this platform)"
		continue
	fi

	case "$MANAGER" in
	brew) pkgname="$brew_pkg" ;;
	apt) pkgname="$apt_pkg" ;;
	dnf) pkgname="$dnf_pkg" ;;
	pacman) pkgname="$pacman_pkg" ;;
	*) pkgname="-" ;;
	esac

	if pkg_installed "$bin" "$MANAGER" "$pkgname"; then
		echo "OK      ${name}"
	elif [ "$pkgname" = "-" ] || [ -z "$pkgname" ]; then
		echo "MISSING ${name} (no known ${MANAGER} package - install manually)"
	else
		echo "MISSING ${name}"
	fi
done < "${SCRIPT_DIR}/packages/packages.list"

# check_manifest <file>
# script.install/git.install rows that don't apply to this platform (e.g. the
# Linux-only starship/atuin/yq fallbacks on macOS, where packages.list already
# installs them via brew) are silently skipped - packages.list is the source of
# truth for whether the tool itself is installed, so a second "not applicable"
# line here would just contradict the OK/MISSING already reported above.
check_manifest() {
	local file="$1"
	local name platforms dest bin cmd_or_repo
	while IFS='|' read -r name platforms dest bin cmd_or_repo; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		platform_applies "$platforms" "$MANAGER" || continue

		if dest_or_bin_installed "$dest" "$bin"; then
			echo "OK      ${name}"
		else
			echo "MISSING ${name} (run ./install.sh)"
		fi
	done < "$file"
}

check_manifest "${SCRIPT_DIR}/packages/script.install"
check_manifest "${SCRIPT_DIR}/packages/git.install"

echo
echo "== local overrides (optional, not tracked by this repo) =="

LOCAL_FILES=(
	"${HOME}/.config/zsh/zshrc.local"
	"${HOME}/.config/zsh/alias.local"
	"${HOME}/.config/zsh/functions.local"
	"${HOME}/.config/launcher/commands.local"
	"${HOME}/.config/git/gitconfig.local"
	"${HOME}/.config/starship/prompt.char.local"
	"${HOME}/.config/jira/jira.yaml"
	"${HOME}/.config/pagerduty/pagerduty.yaml"
)

for local_file in "${LOCAL_FILES[@]}"; do
	if [ -f "$local_file" ]; then
		echo "OK      ${local_file}"
	else
		echo "-       ${local_file} (not present)"
	fi
done
