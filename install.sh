#!/usr/bin/env bash

# TODO: Validate if all the required softwares are installed!

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# linking zshrc
mv ~/.zshrc ~/.zshrc.backup
ln ${SCRIPT_DIR}/zshrc ~/.zshrc

# linking gitconfig
rm -f ~/.gitconfig
ln ${SCRIPT_DIR}/git/gitconfig ~/.gitconfig

# linking vimrc
rm -f ~/.vimrc
ln ${SCRIPT_DIR}/vim/vimrc ~/.vimrc


# TODO:
