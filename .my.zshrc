source ~/.dotfiles/.my.shrc

if [[ -n "$SSH_CONNECTION" ]]; then
    PS1='%B%F{green}[%m] %f%F{blue}%B%~%b%f%(?.. [%F{red}%?%f])%F{green} ❯%f '
else
    PS1='%F{blue}%B%~%b%f%(?.. [%F{red}%?%f])%F{green} ❯%f '
fi

HISTFILE=~/.history
HISTSIZE=100000
SAVEHIST=100000

setopt inc_append_history

autoload -U compinit && compinit

bindkey -e
bindkey "\e[A" history-beginning-search-backward
bindkey "\e[B" history-beginning-search-forward

alias v='nvim'
alias g='git'

# color
alias ls='ls --color=auto -hv'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -c=auto'

alias l='ls'
alias ll='ls -l'
alias la='ls -lA'

alias mv='mv -i'

precmd () { print -Pn "\e]2;%-3~\a"; }


[ $TERM = "dumb" ] && unsetopt zle && PS1='$ '

# Load direnv
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# Setup Basic Completion (requires `zsh-completions')
autoload -U compinit && compinit

# Ruby configuration
export GEM_HOME="$HOME/.gem"
if command -v rbenv &>/dev/null; then
    eval "$(rbenv init -)"
fi