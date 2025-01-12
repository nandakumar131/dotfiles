#!/usr/bin/env bash

# This script requires fzf, git, github gh to be installed

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# linking zshrc
rm -f ~/.zshrc
ln ${SCRIPT_DIR}/zshrc ~/.zshrc

# linking gitconfig
rm -f ~/.gitconfig
ln ${SCRIPT_DIR}/gitconfig ~/.gitconfig

# linking vimrc
rm -f ~/.vimrc
ln ${SCRIPT_DIR}/vimrc ~/.vimrc
