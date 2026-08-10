#!/usr/bin/env bash
# Cross-platform package-manager helpers shared by install.sh, doctor.sh, and
# lib/link.sh. Deliberately dependency-free (no jq/yq) so a bare machine can still
# bootstrap - same reasoning as the pipe-delimited packages.list/script.install/
# git.install files this sources data from.

# Print the detected package manager: brew, apt, dnf, pacman, zypper, apk, or
# unknown. macOS always uses brew; Linux probes for the first manager found on PATH.
detect_manager() {
	if [ "$(uname -s)" = "Darwin" ]; then
		echo brew
		return
	fi

	if command -v apt-get >/dev/null 2>&1; then
		echo apt
	elif command -v dnf >/dev/null 2>&1; then
		echo dnf
	elif command -v pacman >/dev/null 2>&1; then
		echo pacman
	elif command -v zypper >/dev/null 2>&1; then
		echo zypper
	elif command -v apk >/dev/null 2>&1; then
		echo apk
	else
		echo unknown
	fi
}

# platform_applies <platforms-field> <manager>
# platforms-field is "all", "darwin", "linux", or a comma-separated list of manager
# names (e.g. "apt,dnf" - used by script.install/git.install rows to target only the
# Linux managers that don't already have a native package for that tool).
platform_applies() {
	local platforms="$1" manager="$2" os
	if [ "$(uname -s)" = "Darwin" ]; then os=darwin; else os=linux; fi

	case ",${platforms}," in
	*,all,*) return 0 ;;
	*",${os},"*) return 0 ;;
	*",${manager},"*) return 0 ;;
	*) return 1 ;;
	esac
}

# pkg_installed <bin> <manager> <pkgname>
# True if the binary is already on PATH, or (failing that) the active package manager
# already considers the package installed - so anything hand-built or manually
# installed outside the package manager is never reinstalled or flagged missing.
pkg_installed() {
	local bin="$1" manager="$2" pkgname="$3"

	if [ "$bin" != "-" ] && command -v "$bin" >/dev/null 2>&1; then
		return 0
	fi

	[ -n "$pkgname" ] && [ "$pkgname" != "-" ] || return 1

	case "$manager" in
	brew) brew list --versions "$pkgname" >/dev/null 2>&1 ;;
	apt) dpkg -s "$pkgname" >/dev/null 2>&1 ;;
	dnf) rpm -q "$pkgname" >/dev/null 2>&1 ;;
	pacman) pacman -Qi "$pkgname" >/dev/null 2>&1 ;;
	zypper) rpm -q "$pkgname" >/dev/null 2>&1 ;;
	apk) apk info -e "$pkgname" >/dev/null 2>&1 ;;
	*) return 1 ;;
	esac
}

# dest_or_bin_installed <dest> <bin>
# Used by script.install/git.install: installed if the destination directory exists,
# or the binary is already on PATH - covers both plugin/config-directory installs
# (tpm, lazyvim) and bare-binary installs (starship, atuin, yq) with one check.
dest_or_bin_installed() {
	local dest="${1/#\~/$HOME}" bin="$2"

	if [ -n "$dest" ] && [ "$dest" != "-" ] && [ -d "$dest" ]; then
		return 0
	fi
	[ -n "$bin" ] && [ "$bin" != "-" ] && command -v "$bin" >/dev/null 2>&1
}

# Prefix for privileged commands: empty when already root (e.g. inside a container),
# "sudo" otherwise.
sudo_if_needed() {
	if [ "$(id -u)" -eq 0 ]; then
		echo ""
	else
		echo "sudo"
	fi
}

# pkg_install_batch <manager> <pkgname...>
# Installs every named package in one shot. Non-fatal on failure - callers already
# expect to keep going and report a warning, matching install.sh's existing tone.
pkg_install_batch() {
	local manager="$1"
	shift
	local -a pkgs=("$@")
	[ "${#pkgs[@]}" -eq 0 ] && return 0

	local sudo_cmd
	sudo_cmd=$(sudo_if_needed)

	case "$manager" in
	brew) brew install "${pkgs[@]}" ;;
	apt) $sudo_cmd apt-get update -y && $sudo_cmd apt-get install -y "${pkgs[@]}" ;;
	dnf) $sudo_cmd dnf install -y "${pkgs[@]}" ;;
	pacman) $sudo_cmd pacman -Sy --noconfirm "${pkgs[@]}" ;;
	zypper) $sudo_cmd zypper install -y "${pkgs[@]}" ;;
	apk) $sudo_cmd apk add "${pkgs[@]}" ;;
	*)
		echo "! unknown package manager, cannot install: ${pkgs[*]}" >&2
		return 1
		;;
	esac
}
