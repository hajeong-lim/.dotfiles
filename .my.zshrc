source ~/.my.profile
source <(fzf --zsh)

# Prompt
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git svn
zstyle ':vcs_info:*' formats '%F{yellow}[%b%c]%f'
zstyle ':vcs_info:*' stagedstr '*'
zstyle ':vcs_info:*' check-for-staged-changes true
precmd() {
    vcs_info
}
setopt prompt_subst


PROMPT='%F{green}[$USER@$HOST]%f'
PROMPT=$PROMPT'${vcs_info_msg_0_}'
PROMPT=$PROMPT'%F{cyan}[%3~]%f%B\$%f%b '

[ $TERM = "dumb" ] && unsetopt zle && PS1='$ '


if command -v starship &>/dev/null; then 
    eval "$(starship init zsh)"
fi

# Load direnv
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# Setup Basic Completion (requires `zsh-completions')
autoload -U compinit && compinit