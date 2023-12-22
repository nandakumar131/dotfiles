
PROMPT='%2~ > '

PATH=$PATH:/Applications/Maven/bin:/Applications/gh/bin:/opt/homebrew/bin:/Users/nvadivelu/Tools/scripts
fpath=( ~/.dotfiles/autocomplete "${fpath[@]}" )

zstyle ':completion:*:*:git:*' script ~/.dotfiles/git-completion.bash

autoload -U compinit
compinit -i

[ -f ~/.dotfiles/fzf.zsh ] && source ~/.dotfiles/fzf.zsh
[ -f ~/.dotfiles/alias ] && source ~/.dotfiles/alias
[ -f ~/.dotfiles/functions ] && source ~/.dotfiles/functions

export JAVA_HOME=$(/usr/libexec/java_home -v 1.8.0)
