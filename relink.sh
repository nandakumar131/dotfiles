#!/usr/bin/env bash
# Re-run after `git pull` to refresh symlinks (e.g. picks up newly added
# config files) without touching packages. Safe to run any time -
# already-correct links are skipped.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/lib/link.sh"

link_all
