#!/usr/bin/env bash
# ==============================================================================
# core/05-tui-lib.sh - Standardized Pure-Bash TUI Component & Event Engine
# ==============================================================================
# Provides reusable terminal raw-mode control, normalized keyboard events,
# ANSI table rendering, and interactive modal dialogs across dotfiles utilities.
# ==============================================================================

# ANSI Color & Style Palettes
_TUI_RESET="\033[0m"
_TUI_BOLD="\033[1m"
_TUI_DIM="\033[2m"
_TUI_CYAN="\033[1;36m"
_TUI_BLUE="\033[1;34m"
_TUI_GREEN="\033[1;32m"
_TUI_YELLOW="\033[1;33m"
_TUI_RED="\033[1;31m"
_TUI_GRAY="\033[90m"
_TUI_WHITE="\033[37m"

_TUI_ORIG_STTY=""
_TUI_IS_ACTIVE=0

# Check if TTY is interactive and writable
_tui_is_interactive() {
  { exec 3<>/dev/tty; } 2>/dev/null || return 1
  exec 3>&-
  return 0
}

# Enter TUI Raw Mode
_tui_enter() {
  _TUI_ORIG_STTY="$(stty -g < /dev/tty 2>/dev/null || true)"
  stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null || true
  printf "\033[?25l" >/dev/tty 2>/dev/null || true
  _TUI_IS_ACTIVE=1
  trap '_tui_exit' EXIT INT TERM
}

# Exit TUI Raw Mode and Restore Terminal State
_tui_exit() {
  printf "\033[?25h" >/dev/tty 2>/dev/null || true
  if [[ -n "${_TUI_ORIG_STTY:-}" ]]; then
    stty "$_TUI_ORIG_STTY" < /dev/tty 2>/dev/null || true
  fi
  _TUI_IS_ACTIVE=0
}

# Clear screen and return cursor to home (0,0)
_tui_clear() {
  printf "\033[H\033[2J" >/dev/tty 2>/dev/null || true
}

# Read and Normalize Keyboard Event from TTY
# Output variable names:
#   UP, DOWN, LEFT, RIGHT, SPACE, ENTER, ESC, QUIT,
#   ALL, INSTALL, UPDATE, DELETE, INFO, or CHAR:<c>
_tui_read_key() {
  local _out_var="$1"
  local key=""
  IFS= read -rsn1 key < /dev/tty 2>/dev/null || { eval "$_out_var='QUIT'"; return; }

  if [[ "$key" == $'\x1b' ]]; then
    local seq=""
    read -rsn2 -t 0.1 seq < /dev/tty 2>/dev/null || seq=""
    case "$seq" in
      "[A"|"OA") eval "$_out_var='UP'" ;;
      "[B"|"OB") eval "$_out_var='DOWN'" ;;
      "[C"|"OC") eval "$_out_var='RIGHT'" ;;
      "[D"|"OD") eval "$_out_var='LEFT'" ;;
      "")        eval "$_out_var='ESC'" ;;
      *)         eval "$_out_var='ESC'" ;;
    esac
  elif [[ "$key" == "k" || "$key" == "K" ]]; then
    eval "$_out_var='UP'"
  elif [[ "$key" == "j" || "$key" == "J" ]]; then
    eval "$_out_var='DOWN'"
  elif [[ "$key" == " " ]]; then
    eval "$_out_var='SPACE'"
  elif [[ "$key" == "a" || "$key" == "A" ]]; then
    eval "$_out_var='ALL'"
  elif [[ "$key" == "i" || "$key" == "I" ]]; then
    eval "$_out_var='INSTALL'"
  elif [[ "$key" == "u" || "$key" == "U" ]]; then
    eval "$_out_var='UPDATE'"
  elif [[ "$key" == "d" || "$key" == "D" ]]; then
    eval "$_out_var='DELETE'"
  elif [[ "$key" == "?" || "$key" == "o" || "$key" == "O" ]]; then
    eval "$_out_var='INFO'"
  elif [[ "$key" == "q" || "$key" == "Q" || "$key" == $'\x03' ]]; then
    eval "$_out_var='QUIT'"
  elif [[ "$key" == "" || "$key" == $'\r' || "$key" == $'\n' ]]; then
    eval "$_out_var='ENTER'"
  else
    eval "$_out_var=\"CHAR:$key\""
  fi
}

# Render Standard Header
_tui_draw_header() {
  local title="$1"
  local subtitle="${2:-}"

  printf "${_TUI_CYAN}${_TUI_BOLD}=== %s ===${_TUI_RESET}\n" "$title" >/dev/tty
  if [[ -n "$subtitle" ]]; then
    printf "${_TUI_BLUE}%s${_TUI_RESET}\n" "$subtitle" >/dev/tty
  fi
  printf "${_TUI_GRAY}%s${_TUI_RESET}\n\n" "────────────────────────────────────────────────────────────────────────" >/dev/tty
}

# Render Standard Footer
_tui_draw_footer() {
  local help_text="$1"
  printf "\n${_TUI_GRAY}%s${_TUI_RESET}\n" "────────────────────────────────────────────────────────────────────────" >/dev/tty
  printf "${_TUI_GRAY}%s${_TUI_RESET}\n" "$help_text" >/dev/tty
}

# Render Modal Dialog Box with fixed neat width
_tui_modal_box() {
  local title="$1"
  local -n _lines="$2"
  local width=78
  local inner_width=$((width - 4))

  _tui_clear

  local title_part="┌─[ $title ]"
  local pad_len=$((width - ${#title_part} - 1))
  local top_dashes=""
  for ((d=0; d<pad_len; d++)); do top_dashes="${top_dashes}─"; done
  printf "${_TUI_CYAN}${_TUI_BOLD}%s%s┐${_TUI_RESET}\n" "$title_part" "$top_dashes" >/dev/tty

  local line
  for line in "${_lines[@]}"; do
    printf "${_TUI_CYAN}│${_TUI_RESET} %-*.*s ${_TUI_CYAN}│${_TUI_RESET}\n" "$inner_width" "$inner_width" "$line" >/dev/tty
  done

  local div_dashes=""
  for ((d=0; d<width-2; d++)); do div_dashes="${div_dashes}─"; done
  printf "${_TUI_CYAN}├%s┤${_TUI_RESET}\n" "$div_dashes" >/dev/tty
  printf "${_TUI_CYAN}│${_TUI_RESET} ${_TUI_GRAY}%-*.*s${_TUI_RESET} ${_TUI_CYAN}│${_TUI_RESET}\n" "$inner_width" "$inner_width" "  [Press any key or Esc/q to return]" >/dev/tty
  printf "${_TUI_CYAN}└%s┘${_TUI_RESET}\n" "$div_dashes" >/dev/tty

  local dummy=""
  IFS= read -rsn1 dummy < /dev/tty 2>/dev/null || true
  if [[ "$dummy" == $'\x1b' ]]; then
    read -rsn2 -t 0.1 dummy < /dev/tty 2>/dev/null || true
  fi
}

# Prompt user for confirmation with safe temporary cooked terminal
_tui_confirm_prompt() {
  local prompt_msg="$1"
  local default_val="${2:-N}"

  local hint="[y/N]"
  [[ "$default_val" == "Y" || "$default_val" == "y" ]] && hint="[Y/n]"

  printf "\033[?25h" >/dev/tty 2>/dev/null || true
  if [[ -n "${_TUI_ORIG_STTY:-}" ]]; then
    stty "$_TUI_ORIG_STTY" < /dev/tty 2>/dev/null || true
  fi

  local answer=""
  printf "%s %s: " "$prompt_msg" "$hint" >/dev/tty
  IFS= read -r answer < /dev/tty || answer=""

  if (( _TUI_IS_ACTIVE )); then
    stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null || true
    printf "\033[?25l" >/dev/tty 2>/dev/null || true
  fi

  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    [Nn]|[Nn][Oo]) return 1 ;;
    "")
      [[ "$default_val" == "Y" || "$default_val" == "y" ]] && return 0
      return 1
      ;;
    *) return 1 ;;
  esac
}
