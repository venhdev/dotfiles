# Confirmed command audit log manager & rerun helpers

_cmdlog_file() {
  echo "${_CMD_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/commands.log}"
}

_cmdlog_parse_records() {
  local file="$1"
  [[ -f $file ]] || return 0

  local reverse_cmd="tac"
  command -v tac &>/dev/null || reverse_cmd="awk '{a[i++]=\$0} END {for (j=i-1; j>=0; j--) print a[j]}'"

  eval "$reverse_cmd" "$file" | while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\](.*)$ ]]; then
      local ts="${BASH_REMATCH[1]}"
      local rest="${BASH_REMATCH[2]}"
      local status="-" dur="-" cwd="-" cmd=""

      if [[ $rest =~ \[status:([^]]*)\] ]]; then status="${BASH_REMATCH[1]}"; fi
      if [[ $rest =~ \[dur:([^]]*)\] ]]; then dur="${BASH_REMATCH[1]}"; fi
      if [[ $rest =~ \[cwd:([^]]*)\] ]]; then cwd="${BASH_REMATCH[1]}"; fi

      if [[ $rest == *" ▶ "* ]]; then
        cmd="${rest#* ▶ }"
      else
        cmd="${rest# }"
        cmd="${cmd//\\ / }"
      fi

      # Trim whitespace
      cmd="${cmd%"${cmd##*[![:space:]]}"}"
      cmd="${cmd#"${cmd%%[![:space:]]*}"}"

      [[ -n $cmd ]] || continue
      printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$status" "$dur" "$cwd" "$cmd"
    fi
  done
}

_cmdlog_shorten_path() {
  local p="$1"
  if [[ $p == "$HOME"* ]]; then
    echo "~${p#"$HOME"}"
  else
    echo "$p"
  fi
}

_cmdlog_help() {
  cat <<'EOF'
cmdlog / clog - Confirmed Command Audit Log & Rerun

Usage:
  clog [query] [limit]    View recent confirmed commands (default: 10)
  clog -d [limit]         View commands executed in current directory ($PWD)
  clog -a / all           View full command history
  clog path               Print path to commands.log
  clog clean [--keep N]   Truncate log keeping latest N entries (default: 500)
  clog clip [index]       Copy command to clipboard (default: latest)

  cr [query|index]        Interactive picker or direct rerun by index
  cr -e [index]           Edit command before rerun (Readline prompt)
  cr -d [query]           Rerun scoped to current directory ($PWD)

Aliases:
  clog -> cmdlog
  cr   -> cmdlog run
EOF
}

_cmdlog_clean() {
  local file="$1"
  shift
  local keep=500

  while (($# > 0)); do
    case "$1" in
      --keep|-k)
        keep="$2"
        shift 2
        ;;
      [0-9]*)
        keep="$1"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  [[ -f $file ]] || {
    echo "Log file not found: $file" >&2
    return 1
  }

  local total
  total=$(wc -l < "$file")
  if ((total <= keep)); then
    echo "Log has $total entries (<= $keep). No truncation needed."
    return 0
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  tail -n "$keep" "$file" > "$tmp_file" && mv "$tmp_file" "$file"
  echo "Cleaned log: kept latest $keep entries (was $total)."
}

_cmdlog_clip() {
  local file="$1"
  shift
  local target_idx="${1:-1}"
  [[ $target_idx =~ ^[0-9]+$ ]] || target_idx=1

  local line cmd
  line=$(_cmdlog_parse_records "$file" | sed -n "${target_idx}p")
  [[ -n $line ]] || {
    echo "No log entry found at index $target_idx" >&2
    return 1
  }

  IFS=$'\t' read -r _ _ _ _ cmd <<< "$line"

  if command -v clip.exe &>/dev/null; then
    printf '%s' "$cmd" | clip.exe
  elif command -v wl-copy &>/dev/null; then
    printf '%s' "$cmd" | wl-copy
  elif command -v xclip &>/dev/null; then
    printf '%s' "$cmd" | xclip -selection clipboard
  elif command -v xsel &>/dev/null; then
    printf '%s' "$cmd" | xsel --clipboard --input
  else
    echo "No clipboard utility found (clip.exe, wl-copy, xclip, xsel)" >&2
    echo "Command: $cmd"
    return 1
  fi
  printf 'Copied to clipboard: %s\n' "$cmd"
}

_cmdlog_list() {
  local file="$1"
  shift

  local limit=10
  local query=""
  local cwd_only=0
  local show_all=0

  while (($# > 0)); do
    case "$1" in
      -d|--cwd|\.)
        cwd_only=1
        shift
        ;;
      -a|--all|all)
        show_all=1
        shift
        ;;
      [0-9]*)
        limit="$1"
        shift
        ;;
      *)
        query="${query:+$query }$1"
        shift
        ;;
    esac
  done

  ((show_all)) && limit=999999
  ((limit <= 0)) && limit=10

  local entries=()
  local line ts status dur cwd cmd
  local current_pwd="${PWD:-$HOME}"

  while IFS= read -r line || [[ -n $line ]]; do
    [[ -n $line ]] || continue
    IFS=$'\t' read -r ts status dur cwd cmd <<< "$line"

    if ((cwd_only)) && [[ $cwd != "$current_pwd" ]]; then
      continue
    fi

    if [[ -n $query ]]; then
      local lower_cmd="${cmd,,}"
      local lower_query="${query,,}"
      if [[ $lower_cmd != *"$lower_query"* && ${cwd,,} != *"$lower_query"* ]]; then
        continue
      fi
    fi

    entries+=("$line")
    ((${#entries[@]} >= limit)) && break
  done < <(_cmdlog_parse_records "$file")

  local total=${#entries[@]}
  if ((total == 0)); then
    if ((cwd_only)); then
      echo "No confirmed commands found for current directory ($current_pwd)" >&2
    elif [[ -n $query ]]; then
      echo "No confirmed commands matching '$query'" >&2
    else
      echo "No confirmed commands found in log." >&2
    fi
    return 0
  fi

  local title="Confirmed Commands (latest $total)"
  ((cwd_only)) && title="Confirmed Commands in $current_pwd (latest $total)"
  [[ -n $query ]] && title="Confirmed Commands matching '$query' (latest $total)"

  printf '\033[1;34m=== %s ===\033[0m\n' "$title"

  local i
  for i in "${!entries[@]}"; do
    IFS=$'\t' read -r ts status dur cwd cmd <<< "${entries[i]}"
    local idx=$((i + 1))
    local st_str=""
    case "$status" in
      0)   st_str="\033[1;32m[OK]\033[0m" ;;
      "-") st_str="\033[0;90m[-]\033[0m" ;;
      *)   st_str="\033[1;31m[ERR:$status]\033[0m" ;;
    esac

    local cwd_str=""
    if [[ $cwd != "-" && -n $cwd ]]; then
      cwd_str=" \033[0;33m[$(_cmdlog_shorten_path "$cwd")]\033[0m"
    fi

    printf ' \033[1;36m%2d)\033[0m \033[0;90m%s\033[0m %b%b %s\n' \
      "$idx" "$ts" "$st_str" "$cwd_str" "$cmd"
  done
}

_cmdlog_run() {
  local file="$1"
  shift

  local limit=10
  local query=""
  local cwd_only=0
  local edit_mode=0
  local target_idx=""

  while (($# > 0)); do
    case "$1" in
      -e|--edit)
        edit_mode=1
        shift
        ;;
      -d|--cwd|\.)
        cwd_only=1
        shift
        ;;
      *)
        if [[ "$1" =~ ^[0-9]+$ ]] && [[ -z $target_idx ]]; then
          target_idx="$1"
        else
          query="${query:+$query }$1"
        fi
        shift
        ;;
    esac
  done

  local entries=()
  local line ts status dur cwd cmd
  local current_pwd="${PWD:-$HOME}"

  while IFS= read -r line || [[ -n $line ]]; do
    [[ -n $line ]] || continue
    IFS=$'\t' read -r ts status dur cwd cmd <<< "$line"

    if ((cwd_only)) && [[ $cwd != "$current_pwd" ]]; then
      continue
    fi

    if [[ -n $query ]]; then
      local lower_cmd="${cmd,,}"
      local lower_query="${query,,}"
      if [[ $lower_cmd != *"$lower_query"* && ${cwd,,} != *"$lower_query"* ]]; then
        continue
      fi
    fi

    entries+=("$line")
    ((${#entries[@]} >= limit)) && break
  done < <(_cmdlog_parse_records "$file")

  local total=${#entries[@]}
  if ((total == 0)); then
    echo "No matching commands found to run." >&2
    return 1
  fi

  local chosen_idx="$target_idx"

  # If not passed via CLI index, ask interactively
  if [[ -z $chosen_idx ]]; then
    local title="Rerun Confirmed Commands (latest $total)"
    [[ -n $query ]] && title="Rerun Commands matching '$query' (latest $total)"
    printf '\033[1;34m=== %s ===\033[0m\n' "$title"

    local i
    for i in "${!entries[@]}"; do
      IFS=$'\t' read -r ts status dur cwd cmd <<< "${entries[i]}"
      local st_str=""
      case "$status" in
        0)   st_str="\033[1;32m[OK]\033[0m" ;;
        "-") st_str="\033[0;90m[-]\033[0m" ;;
        *)   st_str="\033[1;31m[ERR:$status]\033[0m" ;;
      esac
      local cwd_str=""
      if [[ $cwd != "-" && -n $cwd ]]; then
        cwd_str=" \033[0;33m[$(_cmdlog_shorten_path "$cwd")]\033[0m"
      fi
      printf ' \033[1;36m%2d)\033[0m \033[0;90m%s\033[0m %b%b %s\n' \
        "$((i + 1))" "$ts" "$st_str" "$cwd_str" "$cmd"
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
        chosen_idx=1
        ;;
      *)
        chosen_idx="$choice"
        ;;
    esac
  fi

  if ! [[ "$chosen_idx" =~ ^[0-9]+$ ]] || ((chosen_idx < 1 || chosen_idx > total)); then
    echo "Invalid selection: $chosen_idx (must be 1-$total)" >&2
    return 1
  fi

  local selected_entry="${entries[chosen_idx - 1]}"
  IFS=$'\t' read -r ts status dur cwd cmd <<< "$selected_entry"

  # CWD difference check
  if [[ $cwd != "-" && -n $cwd && $cwd != "$current_pwd" && -d $cwd ]]; then
    printf '\033[1;33m⚠️  CWD Notice:\033[0m Command originally ran in:\n' >&2
    printf '   Original: %s\n' "$cwd" >&2
    printf '   Current:  %s\n' "$current_pwd" >&2
    local dir_choice
    read -rp "Run in current dir [y], cd to original dir and run [c], cancel [N]? " dir_choice
    case "$dir_choice" in
      c|C)
        echo "Navigating to: $cwd"
        cd "$cwd" || return 1
        ;;
      y|Y)
        # proceed in current dir
        ;;
      *)
        echo "Cancelled"
        return 0
        ;;
    esac
  fi

  local cmd_to_run="$cmd"

  if ((edit_mode)); then
    read -e -i "$cmd_to_run" -p "Edit command: " edited_cmd
    [[ -n $edited_cmd ]] || { echo "Cancelled"; return 0; }
    cmd_to_run="$edited_cmd"
  fi

  printf '\n▶ %s\n' "$cmd_to_run"
  history -s "$cmd_to_run" 2>/dev/null || true

  local start_time=$SECONDS
  local run_cwd="${PWD:-$HOME}"
  local rc=0

  eval "$cmd_to_run" || rc=$?

  local duration=$((SECONDS - start_time))
  if declare -F _log_cmd_record &>/dev/null; then
    _log_cmd_record "$rc" "$duration" "$run_cwd" "$cmd_to_run"
  fi

  return $rc
}

cmdlog() {
  local log_file
  log_file="$(_cmdlog_file)"

  case "${1:-}" in
    path)
      echo "$log_file"
      return 0
      ;;
    help|--help|-h)
      _cmdlog_help
      return 0
      ;;
    clean)
      shift
      _cmdlog_clean "$log_file" "$@"
      return $?
      ;;
    clip|cp)
      shift
      _cmdlog_clip "$log_file" "$@"
      return $?
      ;;
    run)
      shift
      _cmdlog_run "$log_file" "$@"
      return $?
      ;;
    *)
      _cmdlog_list "$log_file" "$@"
      return $?
      ;;
  esac
}

# Clean up any preexisting aliases from earlier sessions or dotfiles loads
unalias clog cr 2>/dev/null || true

# Provide wrapper functions so clog and cr work across interactive shells
# and subshells without alias collision or re-source errors.
clog() {
  cmdlog "$@"
}

cr() {
  cmdlog run "$@"
}
