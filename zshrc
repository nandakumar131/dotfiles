
autoload -U colors && colors
PROMPT="%{$fg[blue]%} ❯ %{$reset_color%}"

fpath=( ~/.dotfiles/autocomplete "${fpath[@]}" )

zstyle ':completion:*:*:git:*' script ~/.dotfiles/git-completion.bash
autoload -U compinit
compinit -i

source ~/.dotfiles/fzf-tab/fzf-tab.plugin.zsh
source ~/.dotfiles/zsh-autosuggestions/zsh-autosuggestions.zsh

. /opt/homebrew/etc/profile.d/z.sh

setopt autocd

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

export EDITOR='vi'
export GOPATH='/Users/nvadivelu/Codebase/go'
export LIMA_SHELL='zsh'
export FZF_DEFAULT_OPTS='--height 70% --reverse --inline-info --cycle'
export NAVI_PATH='/Users/nvadivelu/.dotfiles/navi/cheats'
export WALK_EDITOR='vi'
export LESSOPEN="| /opt/homebrew/Cellar/source-highlight/3.1.9_6/bin/src-hilite-lesspipe.sh %s"
export LESS=' -R '


# starship prompt
eval "$(starship init zsh)"
eval "$(navi widget zsh)"

bindkey -e
bindkey '^ ' forward-word
#bindkey "^i" vi-cmd-mode
source <(kubectl completion zsh)

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
