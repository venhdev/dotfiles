# General shell helpers

portss() {
  ss -tulpn | grep "$1" | column -t
}

sudoportss() {
  sudo ss -tulpn | grep "$1" | column -t
}

alias lsfunc='showfunc'

showfunc() {
  if (($# == 0)); then
    echo "Available functions:"
    declare -F |
      awk '{print $3}' |
      sort |
      grep -v '^_' |
      awk '{printf "%2d. %s\n", NR, $0}'
    return
  fi

  if declare -F "$1" &>/dev/null; then
    type "$1" | tail -n +2
  else
    echo "Function '$1' not found"
    return 1
  fi
}

wcp() {
  (($# == 2)) || {
    echo "Usage: wcp <src> <dst>"
    return 1
  }

  local src="$1" dst="$2"

  [[ $src =~ ^[A-Za-z]:[\\/].* ]] && src=$(wslpath -u "$src")
  [[ $dst =~ ^[A-Za-z]:[\\/].* ]] && dst=$(wslpath -u "$dst")

  echo "$src → $dst"
  _confirm "Confirm? [Y/n] " || return 1

  cp "$src" "$dst"
}


# Common shell helpers

_CMD_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/commands.log"

_confirm() {
  local a
  read -rp "${1:-OK? [Y/n] }" a
  [[ ${a:-y} =~ ^[Yy]$ ]]
}

_log_cmd() {
  mkdir -p "$(dirname "$_CMD_LOG")"

  {
    printf '[%s] ' "$(date '+%F %T')"
    printf '%q ' "$@"
    printf '\n'
  } >>"$_CMD_LOG"
}

_run_confirm() {
  printf '\n▶'; printf ' %q' "$@"; echo

  _confirm || {
    echo "✗ cancelled"
    return 1
  }

  _log_cmd "$@"
  "$@"
}

_pick_one() {
  local PS3="$1" item
  shift

  (($#)) || return 1
  (($# == 1)) && { echo "$1"; return; }

  select item in "$@"; do
    [[ -n $item ]] && { echo "$item"; return; }
  done
}

_pick_many() {
  local title="$1" picked n ok=0
  shift
  local items=("$@")

  ((${#items[@]})) || return 1
  ((${#items[@]} == 1)) && { echo "${items[0]}"; return; }

  echo "$title" >&2
  for n in "${!items[@]}"; do
    printf '  %d) %s\n' "$((n+1))" "${items[n]}" >&2
  done

  read -rp "#? (space-sep): " -a picked

  for n in "${picked[@]}"; do
    [[ $n =~ ^[0-9]+$ ]] &&
      ((n >= 1 && n <= ${#items[@]})) &&
      { echo "${items[n-1]}"; ok=1; }
  done

  ((ok))
}
