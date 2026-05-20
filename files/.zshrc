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

# Alias system healthcheck
syscheck() {
  local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}')
  local load=$(cut -d' ' -f1-3 /proc/loadavg | tr ' ' '/')
  local mem=$(free -h | awk '/^Mem:/{printf "%s/%s", $3, $2}')
  local swap=$(free -h | awk '/^Swap:/{printf "%s/%s", $3, $2}')
  local disk=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')

  # Réseau : mesure sur 1 seconde
  local iface=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
  local rx1=$(cat /proc/net/dev | awk -v i="$iface:" '$1==i {print $2}')
  local tx1=$(cat /proc/net/dev | awk -v i="$iface:" '$1==i {print $10}')
  sleep 1
  local rx2=$(cat /proc/net/dev | awk -v i="$iface:" '$1==i {print $2}')
  local tx2=$(cat /proc/net/dev | awk -v i="$iface:" '$1==i {print $10}')
  local rxs=$(awk "BEGIN {printf \"%.1f\", ($rx2 - $rx1) / 1048576}")
  local txs=$(awk "BEGIN {printf \"%.1f\", ($tx2 - $tx1) / 1048576}")

  echo ""
  echo "  $(hostname)  —  $(date '+%H:%M:%S')"
  echo "  ─────────────────────────────"
  echo "  CPU   ${cpu}%   load ${load}"
  echo "  RAM   ${mem}   swap ${swap}"
  echo "  /     ${disk}"
  echo "  NET   ${iface}   ↓ ${rxs} MB/s   ↑ ${txs} MB/s"
  echo ""
  df -h | awk 'NR>1 && !/tmpfs|udev|loop|efi/ && $6!="/" {printf "  %-6s %s/%s (%s)\n", $6, $3, $2, $5}'
  echo ""
}

# PATH
export PATH="/opt/speedtest:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# p10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

. "$HOME/.local/bin/env"
