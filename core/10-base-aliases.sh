# Base system, navigation, dev, and package management aliases

# ENVIRONMENT & RELOAD
alias rel='source ~/.bashrc'
alias rebash='exec bash'
alias insdf='bash "${DOTFILES:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}/install.sh"'
alias instools='bash "${DOTFILES:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}/scripts/install-tools.sh"'
alias insssh='insdf ssh'
alias inswsl='insdf wsl'
alias insmobile='insdf mobile'
alias insdocker='insdf docker'
alias insai='insdf ai'
alias insgit='insdf gitconfig'
alias ts='date +%s'

# PYTHON VENV
alias va='source .venv/bin/activate'
alias vd='deactivate'

# SYSTEM CONTROL
alias sc='systemctl'
alias scu='systemctl --user'
alias scr='sudo systemctl restart'
alias scs='systemctl status'
alias sce='sudo systemctl enable --now'
alias scd='sudo systemctl disable --now'
alias scdr='sudo systemctl daemon-reload'
alias scedit='sudo systemctl edit --full'

# JOURNAL
alias jc='journalctl'
alias jcs='journalctl -u'
alias jcf='journalctl -f -u'

# SECURITY & NETWORK CHECK
alias curlip='curl ifconfig.me' # Quick check of public IP
alias ports_listen='sudo lsof -i -P -n | grep LISTEN' # Check what's hogging ports

# APT PACKAGE MANAGEMENT
alias aupdate='sudo apt update'
alias aupgrade='sudo apt update && sudo apt upgrade -y'
alias ainstall='sudo apt install'
alias aremove='sudo apt remove'
alias asearch='apt search'
alias afix='sudo apt --fix-broken install'
aautoremove() {
  sudo apt autoremove --dry-run

  _confirm "Continue? [y/N] " &&
    sudo apt autoremove ||
    echo "Cancelled"
}

# PROCESS & SYSTEM MONITORING
alias pg='ps aux | grep'
topmem() {
  local count="${1:-15}"
  [[ "$count" =~ ^[0-9]+$ ]] || count=15
  ps -eo pid,ppid,rss,%mem,cmd --sort=-rss | head -n "$((count + 1))"
}
topcpu() {
  local count="${1:-15}"
  [[ "$count" =~ ^[0-9]+$ ]] || count=15
  ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -n "$((count + 1))"
}
alias psmem='topmem'
alias pscpu='topcpu'

# FILE & SYSTEM & NAVIGATION
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -haltF' # Long list, hidden files, human sizes
alias la='ls -A'
alias l='ls -CF'
alias lsize='ls -lSrh' # Sort by size, largest at bottom
alias h='history | grep'

# HISTORY EXECUTE
he() {
  local limit=10
  local query=""

  if (($# == 0)); then
    limit=10
    query=""
  elif (($# == 1)); then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      limit="$1"
      query=""
    else
      query="$1"
      limit=10
    fi
  else
    local last="${!#}"
    if [[ "$last" =~ ^[0-9]+$ ]]; then
      limit="$last"
      query="${*:1:$#-1}"
    else
      limit=10
      query="$*"
    fi
  fi

  ((limit <= 0)) && limit=10

  if ! builtin history &>/dev/null || [[ $(builtin history | wc -l) -eq 0 ]]; then
    set -o history
    [[ -f "${HISTFILE:-$HOME/.bash_history}" ]] && history -r "${HISTFILE:-$HOME/.bash_history}"
  fi

  history -a 2>/dev/null || true

  local reverse_cmd="tac"
  command -v tac &>/dev/null || reverse_cmd="awk '{a[i++]=\$0} END {for (j=i-1; j>=0; j--) print a[j]}'"

  local raw_cmds
  if [[ -n "$query" ]]; then
    raw_cmds=$(HISTTIMEFORMAT="" history |
      sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' |
      eval "$reverse_cmd" |
      grep -v -E '^[[:space:]]*(he|h)([[:space:]]|$)' |
      grep -v '^[[:space:]]*$' |
      grep -F -i -- "$query" |
      awk '!seen[$0]++' |
      head -n "$limit")
  else
    raw_cmds=$(HISTTIMEFORMAT="" history |
      sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' |
      eval "$reverse_cmd" |
      grep -v -E '^[[:space:]]*(he|h)([[:space:]]|$)' |
      grep -v '^[[:space:]]*$' |
      awk '!seen[$0]++' |
      head -n "$limit")
  fi

  local cmds=()
  if [[ -n "$raw_cmds" ]]; then
    mapfile -t cmds <<< "$raw_cmds"
  fi

  local total=${#cmds[@]}
  if ((total == 0)); then
    if [[ -n "$query" ]]; then
      echo "No matching commands found for: $query" >&2
    else
      echo "No recent commands found in history." >&2
    fi
    return 1
  fi

  local title="Recent commands"
  [[ -n "$query" ]] && title="Recent commands matching '$query'"
  printf '\033[1;34m=== %s (latest %d) ===\033[0m\n' "$title" "$total"

  local i
  for i in "${!cmds[@]}"; do
    printf ' \033[1;36m%2d)\033[0m %s\n' "$((i + 1))" "${cmds[i]}"
  done

  local choice
  if ! read -rp "Select [1-$total, default 1, q to cancel]: " choice; then
    echo "Cancelled"
    return 0
  fi

  case "$choice" in
    q|Q|0)
      echo "Cancelled"
      return 0
      ;;
    "")
      choice=1
      ;;
  esac

  if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= total)); then
    local chosen="${cmds[choice - 1]}"
    printf '\n▶ %s\n' "$chosen"
    history -s "$chosen"
    if declare -F _log_cmd &>/dev/null; then
      _log_cmd "$chosen"
    fi
    eval "$chosen"
  else
    echo "Invalid selection: $choice" >&2
    return 1
  fi
}
alias cls='clear'

alias cx='chmod +x'
alias chownme='sudo chown -R $USER:$USER'

alias rm='rm -i'
alias rmf='rm -rf'

alias lst4='tree -a -h -L 4'
alias lst3='tree -a -h -L 3'
alias lst2='tree -a -h -L 2'
alias lst1='tree -a -h -L 1'
alias lst='tree -a -h -L 1'

alias dus='du -sh * | sort -h'
alias dut='du -h --max-depth=1 . | sort -h'
alias dfh='df -h'
alias bigfiles='find . -type f -exec du -h {} + | sort -hr | head -20'
