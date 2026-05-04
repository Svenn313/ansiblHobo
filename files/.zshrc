# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  aliases
  alias-finder
  ansible
  zsh-autosuggestions
  zsh-bat
  fast-syntax-highlighting
  docker
  docker-compose
  sudo
)

DISABLE_AUTO_TITLE="true"

source $ZSH/oh-my-zsh.sh
source /usr/share/doc/fzf/examples/key-bindings.zsh

# Editors
export EDITOR=nvim
export VISUAL=nvim

#GPG
export GPG_TTY=$(tty)

# fzf
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :50 {}'"

# Aliases
alias cat='batcat -pp'
alias fd=fdfind
alias dpsa='docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}"'
alias dpsap='docker ps -a'
alias clip='base64 -w0 | xargs -I{} printf "\e]52;c;{}\a"'

# alias-finder config
zstyle ':omz:plugins:alias-finder' autoload yes
zstyle ':omz:plugins:alias-finder' longer yes
zstyle ':omz:plugins:alias-finder' exact yes
zstyle ':omz:plugins:alias-finder' cheaper yes

# PATH
export PATH="/opt/speedtest:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# p10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

. "$HOME/.local/bin/env"
