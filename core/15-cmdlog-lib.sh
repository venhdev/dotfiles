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
  local seen_cmds=$'\n'
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

    # Deduplication: keep only the latest occurrence
    if [[ $seen_cmds == *$'\n'"$cmd"$'\n'* ]]; then
      continue
    fi
    seen_cmds+="$cmd"$'\n'

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

  local max_cols
  max_cols=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
  ((max_cols <= 20)) && max_cols=80

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

    local disp_cmd="$cmd"
    if (( ${#disp_cmd} > max_cols - 2 )); then
      disp_cmd="${disp_cmd:0:$((max_cols - 5))}..."
    fi

    if ((i < total - 1)); then
      printf ' \033[1;36m[%d]\033[0m \033[0;90m%s\033[0m %b%b\n%s\n\n' \
        "$idx" "$ts" "$st_str" "$cwd_str" "$disp_cmd"
    else
      printf ' \033[1;36m[%d]\033[0m \033[0;90m%s\033[0m %b%b\n%s\n' \
        "$idx" "$ts" "$st_str" "$cwd_str" "$disp_cmd"
    fi
  done
}

_cmdlog_copy_to_clip() {
  local to_copy="$1"
  if command -v clip >/dev/null 2>&1; then
    printf '%s' "$to_copy" | clip
  elif command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "$to_copy" | clip.exe
  elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$to_copy" | wl-copy
  elif command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$to_copy" | pbcopy
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$to_copy" | xclip -selection clipboard
  fi
  echo "✓ Copied to clipboard: $to_copy"
}

_cmdlog_tui_select() {
  local prompt_title="$1"
  shift
  local raw_entries=("$@")
  local total=${#raw_entries[@]}
  ((total == 0)) && return 1

  local cursor=0
  local search_mode=0
  local filter_query=""
  local filtered_indices=()
  local i

  for ((i=0; i<total; i++)); do filtered_indices+=("$i"); done

  _update_filter() {
    filtered_indices=()
    local q="${filter_query,,}"
    for ((i=0; i<total; i++)); do
      local r_entry="${raw_entries[i]}"
      local e_cmd="${r_entry#*$'\t'*$'\t'*$'\t'*$'\t'}"
      local item_lower="${e_cmd,,}"
      if [[ -z "$q" || "$item_lower" == *"$q"* ]]; then
        filtered_indices+=("$i")
      fi
    done
    if ((cursor >= ${#filtered_indices[@]})); then
      cursor=$(( ${#filtered_indices[@]} > 0 ? ${#filtered_indices[@]} - 1 : 0 ))
    fi
  }

  local max_cols
  max_cols=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
  ((max_cols <= 20)) && max_cols=80

  # Hide cursor on TTY
  tput civis >/dev/tty 2>/dev/null || printf "\033[?25l" >/dev/tty

  _tui_cleanup() {
    tput cnorm >/dev/tty 2>/dev/null || printf "\033[?25h" >/dev/tty
  }
  trap _tui_cleanup RETURN INT TERM

  while true; do
    printf "\033[H\033[2J" >/dev/tty
    printf "\033[1;34m=== %s ===\033[0m\n" "$prompt_title" >/dev/tty
    if ((search_mode)); then
      printf "\033[1;33m[SEARCH]\033[0m Query: \033[1m%s\033[0m█ \033[90m(Type to filter | Enter: Run | Tab: Copy | Esc: Clear)\033[0m\n" "$filter_query" >/dev/tty
    else
      printf "\033[90m[↑/↓/j/k] Select | [/] Search | [c] Copy | [r/Enter] Run | [q] Cancel\033[0m\n" >/dev/tty
      [[ -n "$filter_query" ]] && printf "\033[0;33mFiltered by:\033[0m '%s' \033[90m(press / to edit)\033[0m\n" "$filter_query" >/dev/tty
    fi
    printf "\n" >/dev/tty

    local f_count=${#filtered_indices[@]}
    if ((f_count == 0)); then
      printf " \033[90m(No commands match '%s')\033[0m\n\n" "$filter_query" >/dev/tty
    else
      local idx
      for ((idx=0; idx<f_count; idx++)); do
        local orig_i="${filtered_indices[idx]}"
        local entry="${raw_entries[orig_i]}"
        local ts status dur cwd cmd
        IFS=$'\t' read -r ts status dur cwd cmd <<< "$entry"

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

        local disp_cmd="$cmd"
        if (( ${#disp_cmd} > max_cols - 2 )); then
          disp_cmd="${disp_cmd:0:$((max_cols - 5))}..."
        fi

        if ((idx == cursor)); then
          printf "\033[1;32m▶ [%d]\033[0m \033[0;90m%s\033[0m %b%b\n\033[1m%s\033[0m\n\n" \
            "$((orig_i + 1))" "$ts" "$st_str" "$cwd_str" "$disp_cmd" >/dev/tty
        else
          printf "  \033[1;36m[%d]\033[0m \033[0;90m%s\033[0m %b%b\n%s\n\n" \
            "$((orig_i + 1))" "$ts" "$st_str" "$cwd_str" "$disp_cmd" >/dev/tty
        fi
      done
    fi

    # Read keystroke
    local key="" seq=""
    IFS= read -rsn1 key < /dev/tty

    if ((search_mode)); then
      if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.05 seq < /dev/tty || true
        case "$seq" in
          "[A"|"OA") ((cursor > 0)) && cursor=$((cursor - 1)) ;;
          "[B"|"OB") ((cursor < f_count - 1)) && cursor=$((cursor + 1)) ;;
          "") search_mode=0; filter_query=""; _update_filter ;;
        esac
      elif [[ $key == "" || $key == $'\n' || $key == $'\r' ]]; then
        if ((f_count > 0)); then
          TUI_ACTION="RUN"
          TUI_CHOSEN_IDX="${filtered_indices[cursor]}"
          return 0
        fi
      elif [[ $key == $'\t' ]]; then
        if ((f_count > 0)); then
          TUI_ACTION="COPY"
          TUI_CHOSEN_IDX="${filtered_indices[cursor]}"
          return 0
        fi
      elif [[ $key == $'\x7f' || $key == $'\b' ]]; then
        if [[ -n "$filter_query" ]]; then
          filter_query="${filter_query:0:-1}"
          _update_filter
        fi
      else
        if [[ $key =~ [[:print:]] ]]; then
          filter_query+="$key"
          _update_filter
        fi
      fi
      continue
    fi

    # Normal navigation mode
    if [[ $key == $'\x1b' ]]; then
      read -rsn2 -t 0.05 seq < /dev/tty || true
      case "$seq" in
        "[A"|"OA") ((cursor > 0)) && cursor=$((cursor - 1)) ;;
        "[B"|"OB") ((cursor < f_count - 1)) && cursor=$((cursor + 1)) ;;
        "") TUI_ACTION="CANCEL"; return 0 ;;
      esac
    elif [[ $key == "k" || $key == "K" ]]; then
      ((cursor > 0)) && cursor=$((cursor - 1))
    elif [[ $key == "j" || $key == "J" ]]; then
      ((cursor < f_count - 1)) && cursor=$((cursor + 1))
    elif [[ $key == "/" ]]; then
      search_mode=1
    elif [[ $key == "q" || $key == "Q" || $key == $'\x03' ]]; then
      TUI_ACTION="CANCEL"
      return 0
    elif [[ $key == "c" || $key == "C" ]]; then
      if ((f_count > 0)); then
        TUI_ACTION="COPY"
        TUI_CHOSEN_IDX="${filtered_indices[cursor]}"
        return 0
      fi
    elif [[ $key == "r" || $key == "R" || $key == "" || $key == $'\n' || $key == $'\r' ]]; then
      if ((f_count > 0)); then
        TUI_ACTION="RUN"
        TUI_CHOSEN_IDX="${filtered_indices[cursor]}"
        return 0
      fi
    fi
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
  local seen_cmds=$'\n'
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

    # Deduplication: keep only the latest occurrence
    if [[ $seen_cmds == *$'\n'"$cmd"$'\n'* ]]; then
      continue
    fi
    seen_cmds+="$cmd"$'\n'

    entries+=("$line")
    ((${#entries[@]} >= limit)) && break
  done < <(_cmdlog_parse_records "$file")

  local total=${#entries[@]}
  if ((total == 0)); then
    echo "No matching commands found to run." >&2
    return 1
  fi

  local chosen_idx="$target_idx"
  local interactive_choice=0

  # If not passed via CLI index, ask interactively
  if [[ -z $chosen_idx ]]; then
    local title="Rerun Confirmed Commands (latest $total)"
    [[ -n $query ]] && title="Rerun Commands matching '$query' (latest $total)"

    if [[ -t 0 && -t 1 ]] && [[ -e /dev/tty ]]; then
      # Tier 1: fzf if available and not disabled
      if command -v fzf >/dev/null 2>&1 && [[ -z "${DOTFILES_NO_FZF:-}" ]]; then
        local fzf_input=""
        local i
        for i in "${!entries[@]}"; do
          IFS=$'\t' read -r ts status dur cwd cmd <<< "${entries[i]}"
          local short_cwd="$(_cmdlog_shorten_path "$cwd")"
          fzf_input+="$((i + 1))\t$ts\t[$status]\t[$short_cwd]\t$cmd"$'\n'
        done

        local fzf_res
        fzf_res=$(printf '%s' "$fzf_input" | fzf \
          --height 50% \
          --reverse \
          --delimiter $'\t' \
          --with-nth 1,2,3,4,5 \
          --prompt="Rerun > " \
          --header="[Enter] Run | [Ctrl-Y/Alt-C] Copy | [Esc] Cancel" \
          --expect=enter,ctrl-y,alt-c \
          --query="$query" || true)

        local fzf_key chosen_line
        fzf_key=$(echo "$fzf_res" | head -n 1)
        chosen_line=$(echo "$fzf_res" | sed 1d)

        if [[ -z "$chosen_line" ]]; then
          echo "Cancelled"
          return 0
        fi

        local chosen_num
        chosen_num=$(echo "$chosen_line" | cut -f1)
        local selected_entry="${entries[chosen_num - 1]}"
        local s_ts s_st s_dur s_cwd s_cmd
        IFS=$'\t' read -r s_ts s_st s_dur s_cwd s_cmd <<< "$selected_entry"

        if [[ "$fzf_key" == "ctrl-y" || "$fzf_key" == "alt-c" ]]; then
          _cmdlog_copy_to_clip "$s_cmd"
          return 0
        fi

        chosen_idx="$chosen_num"
        interactive_choice=1
      else
        # Tier 2: Pure Bash Native TUI
        TUI_ACTION=""
        TUI_CHOSEN_IDX=""
        _cmdlog_tui_select "$title" "${entries[@]}"
        case "$TUI_ACTION" in
          COPY)
            local to_copy="${entries[TUI_CHOSEN_IDX]}"
            local c_ts c_st c_dur c_cwd c_cmd
            IFS=$'\t' read -r c_ts c_st c_dur c_cwd c_cmd <<< "$to_copy"
            _cmdlog_copy_to_clip "$c_cmd"
            return 0
            ;;
          RUN)
            chosen_idx=$((TUI_CHOSEN_IDX + 1))
            interactive_choice=1
            ;;
          *)
            echo "Cancelled"
            return 0
            ;;
        esac
      fi
    else
      # Tier 3: Non-interactive pipe or dumb terminal fallback (numbered menu)
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
        if ((i < total - 1)); then
          printf ' \033[1;36m[%d]\033[0m \033[0;90m%s\033[0m %b%b\n%s\n\n' \
            "$((i + 1))" "$ts" "$st_str" "$cwd_str" "$cmd"
        else
          printf ' \033[1;36m[%d]\033[0m \033[0;90m%s\033[0m %b%b\n%s\n' \
            "$((i + 1))" "$ts" "$st_str" "$cwd_str" "$cmd"
        fi
      done

      local choice
      if ! read -rp "Select [1-$total, default 1, c <num> to copy, q to cancel]: " choice; then
        echo "Cancelled"
        return 0
      fi

      case "$choice" in
        q|Q|0)
          echo "Cancelled"
          return 0
          ;;
        c*|clip*|copy*)
          local copy_idx="${choice#* }"
          [[ "$copy_idx" =~ ^[0-9]+$ ]] || copy_idx=1
          if ((copy_idx >= 1 && copy_idx <= total)); then
            local to_copy="${entries[copy_idx - 1]}"
            local c_ts c_st c_dur c_cwd c_cmd
            IFS=$'\t' read -r c_ts c_st c_dur c_cwd c_cmd <<< "$to_copy"
            _cmdlog_copy_to_clip "$c_cmd"
            return 0
          else
            echo "Invalid copy index: $copy_idx (must be 1-$total)" >&2
            return 1
          fi
          ;;
        "")
          chosen_idx=1
          ;;
        *)
          chosen_idx="$choice"
          ;;
      esac
    fi
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

  if ((interactive_choice)); then
    printf '\n\033[1;36m▶ Run:\033[0m %s\n' "$cmd_to_run"
    if ! _confirm "Execute command? [Y/n] "; then
      echo "Cancelled"
      return 0
    fi
  else
    printf '\n▶ %s\n' "$cmd_to_run"
  fi
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
