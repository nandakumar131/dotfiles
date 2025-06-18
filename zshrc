
autoload -U colors && colors
PROMPT="%{$fg[blue]%} ❯ %{$reset_color%}"

fpath=( ~/.dotfiles/autocomplete "${fpath[@]}" )

zstyle ':completion:*:*:git:*' script ~/.dotfiles/git/git-completion.bash
autoload -U compinit
compinit -i

source ~/.dotfiles/fzf-tab/fzf-tab.plugin.zsh
source ~/.dotfiles/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/etc/profile.d/z.sh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#737272"

setopt autocd

# hook to load env fine from .dev-tools directory
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

export EDITOR='nvim'
export GOPATH=$HOME/Codebase/go
export LIMA_SHELL='zsh'
export FZF_DEFAULT_OPTS='--height 70% --reverse --inline-info --cycle'
export NAVI_PATH=$HOME/.dotfiles/config/navi/cheats
export WALK_EDITOR='nvim'
export LESSOPEN="| /opt/homebrew/Cellar/source-highlight/3.1.9_6/bin/src-hilite-lesspipe.sh %s"
export LESS=' -R '

# history setup
HISTFILE=$HOME/.zsh_history
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# starship prompt
eval "$(starship init zsh)"
eval "$(navi widget zsh)"

# keybindings
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward
bindkey -e
bindkey '^ ' forward-word
#bindkey "^i" vi-cmd-mode

# keybind for tmux
bindkey "^o" kill-line
bindkey "^u" backward-kill-line
bindkey "^b" backward-word

source <(kubectl completion zsh)

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
