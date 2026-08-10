#!/usr/bin/env bash
# Safe to re-run any time (e.g. after `git pull`) - already-correct links
# are skipped, and anything at a destination path is backed up before
# being replaced.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/lib/link.sh"
source "${SCRIPT_DIR}/lib/pkg.sh"

install_homebrew_if_missing() {
	if command -v brew >/dev/null 2>&1; then
		return
	fi
	echo "Homebrew not found, installing it..."
	NONINTERACTIVE=1 /bin/bash -c \
		"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	activate_homebrew
}

activate_homebrew() {
	local brew_bin

	for brew_bin in \
		/opt/homebrew/bin/brew \
		/usr/local/bin/brew
	do
		if [[ -x "$brew_bin" ]]; then
			eval "$("$brew_bin" shellenv)"
			return 0
		fi
	done

	return 1
}

# install_git_packages <file> <manager>
install_git_packages() {
	local file="$1" manager="$2"
	local name platforms dest bin repo
	while IFS='|' read -r name platforms dest bin repo; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		platform_applies "$platforms" "$manager" || continue
		dest_or_bin_installed "$dest" "$bin" && continue

		echo "installing ${name}..."
		git clone "$repo" "${dest/#\~/$HOME}" || echo "! ${name} install failed" >&2
	done < "$file"
}

# install_script_packages <file> <manager>
install_script_packages() {
	local file="$1" manager="$2"
	local name platforms dest bin cmd
	while IFS='|' read -r name platforms dest bin cmd; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		platform_applies "$platforms" "$manager" || continue
		dest_or_bin_installed "$dest" "$bin" && continue

		echo "installing ${name}..."
		eval "$cmd" || echo "! ${name} install failed" >&2
	done < "$file"
}

# install_native_packages <manager>
# Installs everything in packages/packages.list applicable to $manager, skipping
# anything already on PATH or already known to the package manager, and batching
# the rest into a single install call.
install_native_packages() {
	local manager="$1"

	local -a to_install=()
	local name bin platforms brew_pkg apt_pkg dnf_pkg pacman_pkg pkgname
	while IFS='|' read -r name bin platforms brew_pkg apt_pkg dnf_pkg pacman_pkg; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		platform_applies "$platforms" "$manager" || continue

		case "$manager" in
		brew) pkgname="$brew_pkg" ;;
		apt) pkgname="$apt_pkg" ;;
		dnf) pkgname="$dnf_pkg" ;;
		pacman) pkgname="$pacman_pkg" ;;
		*) pkgname="-" ;;
		esac

		if [ "$pkgname" = "-" ] || [ -z "$pkgname" ]; then
			continue
		fi

		pkg_installed "$bin" "$manager" "$pkgname" || to_install+=("$pkgname")
	done < "${SCRIPT_DIR}/packages/packages.list"

	if [ "${#to_install[@]}" -gt 0 ]; then
		echo "installing: ${to_install[*]}"
		pkg_install_batch "$manager" "${to_install[@]}" || echo "! some packages failed to install" >&2
	fi
}

install_packages() {
	local manager
	manager=$(detect_manager)

	if [ "$manager" = brew ]; then
		install_homebrew_if_missing
		if ! command -v brew >/dev/null 2>&1; then
			echo "! Homebrew still not on PATH - skipping package install, run brew bundle manually." >&2
			manager=unknown
		fi
	elif [ "$manager" = unknown ]; then
		echo "! could not detect a supported package manager (apt/dnf/pacman/...) - skipping native package install." >&2
	fi

	[ "$manager" != unknown ] && install_native_packages "$manager"

	install_script_packages "${SCRIPT_DIR}/packages/script.install" "$manager"
	install_git_packages "${SCRIPT_DIR}/packages/git.install" "$manager"
}

install_packages
link_all

cat <<'EOF'

Done. Final status:
EOF

"${SCRIPT_DIR}/doctor.sh" || true

echo
echo "Open a new shell to pick everything up."
