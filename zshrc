
autoload -U colors && colors
PROMPT="%{$fg[blue]%} ❯ %{$reset_color%}"

PATH=/Users/nvadivelu/.pyenv/versions/3.10.6/bin:/Applications/Maven/bin:/Applications/gh/bin:/opt/homebrew/bin:/Users/nvadivelu/Tools/scripts:$PATH
fpath=( ~/.dotfiles/autocomplete "${fpath[@]}" )

zstyle ':completion:*:*:git:*' script ~/.dotfiles/git-completion.bash

source ~/.dotfiles/zsh-autocomplete/zsh-autocomplete.plugin.zsh
#autoload -U compinit
#compinit -i

# Hook to load env fine from .dev-tools directory
autoload -U add-zsh-hook
load-local-conf() {
     # check file exists, is regular file and is readable:
     if [[ -f .git/env && -r .git/env ]]; then
       source .git/env
     fi
}
add-zsh-hook chpwd load-local-conf

[ -f ~/.dotfiles/fzf.zsh ] && source ~/.dotfiles/fzf.zsh
[ -f ~/.dotfiles/alias ] && source ~/.dotfiles/alias
[ -f ~/.dotfiles/functions ] && source ~/.dotfiles/functions

export GOPATH='/Users/nvadivelu/Codebase/go'
export LIMA_SHELL='zsh'

# starship prompt
eval "$(starship init zsh)"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
