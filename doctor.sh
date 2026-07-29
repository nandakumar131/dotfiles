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
BREWFILE="${SCRIPT_DIR}/packages/Brewfile"

# formula name -> binary name, for the few Brewfile entries where they differ
declare -A BIN_OVERRIDES=(
  [neovim]=nvim
  [ripgrep]=rg
  [ast-grep]=sg
  [maven]=mvn
  [difftastic]=difft
  [tealdeer]=tldr
)

# formulas that don't provide a standalone binary (e.g. zsh plugins) fall
# back to `brew list` when no matching binary is found on PATH
command -v brew >/dev/null 2>&1 && echo "OK      brew" || echo "MISSING brew (expects 'brew' on PATH)"

while IFS= read -r formula; do
  bin="${BIN_OVERRIDES[$formula]:-$formula}"
  if command -v "$bin" >/dev/null 2>&1; then
    echo "OK      ${formula}"
  elif brew list --versions "$formula" >/dev/null 2>&1; then
    echo "OK      ${formula}"
  else
    echo "MISSING ${formula}"
  fi
done < <(grep -oE '^brew "[^"]+"' "$BREWFILE" | sed -E 's/^brew "([^"]+)"/\1/')

if [ "$(uname -s)" = "Darwin" ]; then
  BREWFILE_MAC="${SCRIPT_DIR}/packages/Brewfile.mac"
  while IFS= read -r cask; do
    if brew list --cask --versions "$cask" >/dev/null 2>&1; then
      echo "OK      ${cask}"
      continue
    fi

    app=$(brew info --cask "$cask" --json=v2 2>/dev/null | jq -r '.casks[0].artifacts[]? | select(.app) | .app[0]' | head -n1)
    if [ -n "$app" ] && { [ -d "/Applications/${app}" ] || [ -d "${HOME}/Applications/${app}" ]; }; then
      echo "OK      ${cask} (installed outside brew)"
    else
      echo "MISSING ${cask}"
    fi
  done < <(grep -oE '^cask "[^"]+"' "$BREWFILE_MAC" | sed -E 's/^cask "([^"]+)"/\1/')
fi

check_manifest() {
  local file="$1"
  local name dest cmd
  while IFS='|' read -r name dest cmd; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    dest="${dest/#\~/$HOME}"
    if [ -d "$dest" ]; then
      echo "OK      ${name}"
    else
      echo "MISSING ${name} (expects ${dest}, run ./install.sh)"
    fi
  done < "$file"
}

check_manifest "${SCRIPT_DIR}/packages/script.install"
check_manifest "${SCRIPT_DIR}/packages/git.install"
