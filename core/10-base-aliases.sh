# Base system, navigation, dev, and package management aliases

# ENVIRONMENT & RELOAD
alias rebash='exec bash'
alias rezsh='exec zsh'
alias insdf='bash "${DOTFILES:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}/install.sh"'
alias ts='date +%s'

# PYTHON VENV
alias va='source .venv/bin/activate'
alias vd='deactivate'

# SYSTEM CONTROL & JOURNAL (enabled when systemctl is present)
if command -v systemctl &>/dev/null; then
  alias sc='systemctl'
  alias scu='systemctl --user'
  alias scr='sudo systemctl restart'
  alias scs='systemctl status'
  alias sce='sudo systemctl enable --now'
  alias scd='sudo systemctl disable --now'
  alias scdr='sudo systemctl daemon-reload'
  alias scedit='sudo systemctl edit --full'

  alias jc='journalctl'
  alias jcs='journalctl -u'
  alias jcf='journalctl -f -u'
fi

# SECURITY & NETWORK CHECK
alias curlip='curl ifconfig.me' # Quick check of public IP
alias ports_listen='sudo lsof -i -P -n | grep LISTEN' # Check what's hogging ports

# ENVIRONMENT VARIABLES INSPECTION
gete() {
  local key="${1:-}"
  if [[ -z "$key" ]]; then
    printenv | sort
    return 0
  fi

  local val
  if val="$(printenv "$key" 2>/dev/null)"; then
    printf "%s=%s\n" "$key" "$val"
  else
    echo "⚠️  Environment variable '$key' not found." >&2
    return 1
  fi
}

# PACKAGE MANAGEMENT ALIASES (Apt on Debian/Ubuntu, or shims to universal pkg)
if command -v apt-get &>/dev/null; then
  alias aupdate='sudo apt update'
  alias aupgrade='sudo apt update && sudo apt upgrade -y'
  alias ainstall='sudo apt install'
  alias aremove='sudo apt remove'
  alias asearch='apt search'
  alias afix='sudo apt --fix-broken install'
  aautoremove() {
    sudo apt autoremove --dry-run
    _run_confirm sudo apt autoremove
  }
else
  alias aupdate='pkg update'
  alias aupgrade='pkg upgrade'
  alias ainstall='pkg install'
  alias aremove='pkg remove'
  alias asearch='pkg search'
fi

# PROCESS & SYSTEM MONITORING
alias pg='ps aux | grep'
psmem() {
  local count="${1:-15}"
  [[ "$count" =~ ^[0-9]+$ ]] || count=15
  ps -eo pid,ppid,rss,%mem,cmd --sort=-rss | head -n "$((count + 1))"
}
pscpu() {
  local count="${1:-15}"
  [[ "$count" =~ ^[0-9]+$ ]] || count=15
  ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -n "$((count + 1))"
}

# FILE & SYSTEM & NAVIGATION
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -haltF' # Long list, hidden files, human sizes
alias la='ls -A'
alias l='ls -CF'
alias lsize='ls -lSrh' # Sort by size, largest at bottom

# DIRECTORY DISK USAGE (POSIX: Linux, macOS, WSL, default limit: none)
unalias ds 2>/dev/null || true
unalias dirsize 2>/dev/null || true
dirsize() {
  local target="."
  local limit=""

  case $# in
    0)
      target="."
      limit=""
      ;;
    1)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        limit="$1"
        target="."
      else
        target="$1"
        limit=""
      fi
      ;;
    *)
      if [[ "$2" =~ ^[0-9]+$ ]]; then
        target="$1"
        limit="$2"
      elif [[ "$1" =~ ^[0-9]+$ ]]; then
        limit="$1"
        target="$2"
      else
        target="$1"
        limit=""
      fi
      ;;
  esac

  if [[ ! -d "$target" ]]; then
    echo "❌ Directory not found: $target" >&2
    return 1
  fi

  local clean_target="${target%/}"
  [[ -z "$clean_target" ]] && clean_target="/"

  local cmd
  if du -d 1 -k /dev/null &>/dev/null; then
    cmd="du -d 1 -k \"$target\" 2>/dev/null"
  else
    cmd="du -k --max-depth=1 \"$target\" 2>/dev/null"
  fi

  local raw_output
  raw_output="$(eval "$cmd" | grep -v -E "[[:space:]]+(\./?|${clean_target})$" | sort -nr)"

  if [[ -z "$raw_output" ]]; then
    echo "No subdirectories found in '$target'."
    return 0
  fi

  local awk_script='
  function human(k) {
    if (k >= 1048576) return sprintf("%.2f GB", k / 1048576);
    if (k >= 1024) return sprintf("%.2f MB", k / 1024);
    return sprintf("%d KB", k);
  }
  BEGIN {
    printf "%-12s %s\n", "SIZE", "DIRECTORY";
    printf "%-12s %s\n", "----", "---------";
  }
  {
    kb = $1;
    $1 = "";
    sub(/^[[:space:]]+/, "");
    printf "%-12s %s\n", human(kb), $0;
  }
  '

  if [[ -n "$limit" ]]; then
    printf "%s\n" "$raw_output" | head -n "$limit" | awk "$awk_script"
  else
    printf "%s\n" "$raw_output" | awk "$awk_script"
  fi
}
# HISTORY SEARCH (POSIX: Bash & Zsh, default limit: 10)
unalias h 2>/dev/null || true
h() {
  local query=""
  local limit=10

  case $# in
    0)
      query=""
      limit=10
      ;;
    1)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        limit="$1"
        query=""
      else
        query="$1"
        limit=10
      fi
      ;;
    *)
      local last="${!#}"
      if [[ "$last" =~ ^[0-9]+$ ]]; then
        limit="$last"
        query="${*:1:$#-1}"
      elif [[ "$1" =~ ^[0-9]+$ ]]; then
        limit="$1"
        query="${*:2}"
      else
        query="$*"
        limit=10
      fi
      ;;
  esac

  ((limit <= 0)) && limit=10

  if ! builtin history &>/dev/null || [[ $(builtin history | wc -l) -eq 0 ]]; then
    set -o history 2>/dev/null || true
    [[ -f "${HISTFILE:-$HOME/.bash_history}" ]] && history -r "${HISTFILE:-$HOME/.bash_history}" 2>/dev/null || true
  fi

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    if [[ -n "$query" ]]; then
      fc -l -n 1 2>/dev/null | grep -i -F -- "$query" | grep -v -E '^[[:space:]]*h([[:space:]]|$)' | tail -n "$limit" | awk '{printf " \033[0;90m%2d)\033[0m %s\n", NR, $0}'
    else
      fc -l -n 1 2>/dev/null | grep -v -E '^[[:space:]]*h([[:space:]]|$)' | tail -n "$limit" | awk '{printf " \033[0;90m%2d)\033[0m %s\n", NR, $0}'
    fi
  else
    HISTTIMEFORMAT="" history | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' | \
      grep -v -E '^[[:space:]]*h([[:space:]]|$)' | \
      if [[ -n "$query" ]]; then grep -i -F -- "$query"; else cat; fi | \
      tail -n "$limit" | awk '{printf " \033[0;90m%2d)\033[0m %s\n", NR, $0}'
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

alias dfh='df -h'
alias bigfiles='find . -type f -exec du -h {} + | sort -hr | head -20'
