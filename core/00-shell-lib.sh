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


# Common shell helpers

_CMD_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/commands.log"

# Separate consecutive prompt blocks without polluting captured stdout.
_prompt_gap() {
  printf '\n' >&2
}

_confirm() {
  local prompt="${1:-OK? [Y/n] }"
  local a default="y"
  [[ $prompt =~ \[y/N\] ]] && default="n"
  _prompt_gap
  read -rp "$prompt" a
  [[ ${a:-$default} =~ ^[Yy]$ ]]
}

_format_cmdline() {
  if (($# == 1)) && [[ "$1" =~ [[:space:]] ]]; then
    printf '%s' "$1"
    return
  fi

  local arg out=""
  for arg in "$@"; do
    if [[ -z $arg ]]; then
      out+="${out:+ }''"
    elif [[ "$arg" == *" "* || "$arg" == *$'\t'* || "$arg" == *$'\n'* || "$arg" == *"'"* ]]; then
      local quoted="'${arg//\'/\'\\\'\'}'"
      out+="${out:+ }$quoted"
    else
      local q
      printf -v q '%q' "$arg"
      out+="${out:+ }$q"
    fi
  done
  printf '%s' "$out"
}

_log_cmd_record() {
  local status="$1" duration="$2" cwd="$3"
  shift 3
  mkdir -p "$(dirname "$_CMD_LOG")"

  local cmd_str
  cmd_str="$(_format_cmdline "$@")"

  {
    printf '[%s] [status:%s] [dur:%ss] [cwd:%s] ▶ %s\n' \
      "$(date '+%F %T')" "$status" "$duration" "$cwd" "$cmd_str"
  } >>"$_CMD_LOG"
}

_log_cmd() {
  local cwd="${PWD:-$HOME}"
  _log_cmd_record "0" "0" "$cwd" "$@"
}

# Print the label/icon and the command on separate lines so the command can be
# selected and copied without picking up the prefix.
_print_cmdline() {
  _format_cmdline "$@"
  printf '\n'
}

_print_cmd() {
  local label="$1"
  shift

  printf '▶ %s\n' "$label"
  _print_cmdline "$@"
}

_run_confirm() {
  printf '\n'
  _print_cmd "Command:" "$@"

  _confirm || {
    echo "✗ cancelled"
    return 1
  }

  local start_time=$SECONDS
  local cwd="${PWD:-$HOME}"
  local rc=0

  "$@" || rc=$?

  local duration=$((SECONDS - start_time))
  _log_cmd_record "$rc" "$duration" "$cwd" "$@"

  return $rc
}

_pick_one() {
  local PS3="$1" item
  shift

  (($#)) || return 1
  (($# == 1)) && { echo "$1"; return; }

  _prompt_gap
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

  _prompt_gap
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
