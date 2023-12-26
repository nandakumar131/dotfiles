
PROMPT='%2~ > '

PATH=/Users/nvadivelu/.pyenv/versions/3.10.6/bin:/Applications/Maven/bin:/Applications/gh/bin:/opt/homebrew/bin:/Users/nvadivelu/Tools/scripts:$PATH
fpath=( ~/.dotfiles/autocomplete "${fpath[@]}" )

zstyle ':completion:*:*:git:*' script ~/.dotfiles/git-completion.bash

autoload -U compinit
compinit -i

# Hook to load env fine from .dev-tools directory
autoload -U add-zsh-hook
load-local-conf() {
     # check file exists, is regular file and is readable:
     if [[ -f .dev-tools/env && -r .dev-tools/env ]]; then
       source .dev-tools/env
     fi
}
add-zsh-hook chpwd load-local-conf

[ -f ~/.dotfiles/fzf.zsh ] && source ~/.dotfiles/fzf.zsh
[ -f ~/.dotfiles/alias ] && source ~/.dotfiles/alias
[ -f ~/.dotfiles/functions ] && source ~/.dotfiles/functions

export JAVA_HOME=$(/usr/libexec/java_home -v 1.8.0)
