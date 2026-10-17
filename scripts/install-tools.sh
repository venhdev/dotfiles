#!/usr/bin/env bash
set -e

# Common CLI tools installer (git, curl, jq, rg)

can_prompt_interactively() {
  { exec 3<>/dev/tty; } 2>/dev/null || return 1
  exec 3>&-
}

restore_cursor() {
  tput cnorm >/dev/tty 2>/dev/null || printf "\033[?25h" >/dev/tty 2>/dev/null || true
}

handle_cancel() {
  restore_cursor
  printf "\n\033[90mInstallation cancelled.\033[0m\n" >/dev/tty 2>/dev/null || printf "\nInstallation cancelled.\n"
  exit 130
}

trap restore_cursor EXIT
trap handle_cancel INT TERM

# Probe tools and build registry
# format: command|package|description|version_cmd
TOOL_DEFS=(
  "git|git|Fast, distributed version control system|git --version 2>/dev/null | awk '{print \$3}'"
  "curl|curl|Command line tool for transferring data with URLs|curl --version 2>/dev/null | awk 'NR==1{print \$2}'"
  "jq|jq|Command-line JSON processor|jq --version 2>/dev/null | sed 's/^jq-//'"
  "rg|ripgrep|ripgrep (fast line-oriented search tool)|rg --version 2>/dev/null | awk 'NR==1{print \$2}'"
)

tool_cmds=()
tool_pkgs=()
tool_descs=()
tool_versions=()
tool_installed=()
menu_items=()
selected=()

for def in "${TOOL_DEFS[@]}"; do
  IFS='|' read -r cmd pkg desc vcmd <<< "$def"
  tool_cmds+=("$cmd")
  tool_pkgs+=("$pkg")
  tool_descs+=("$desc")

  if command -v "$cmd" >/dev/null 2>&1; then
    ver=$(eval "$vcmd")
    tool_versions+=("${ver:-installed}")
    tool_installed+=(1)
    # Default unselected if already installed
    selected+=(0)
    menu_items+=("$(printf '%-5s [v%-8s - Installed] - %s' "$cmd" "${ver:-ok}" "$desc")")
  else
    tool_versions+=("not installed")
    tool_installed+=(0)
    # Default selected if missing
    selected+=(1)
    menu_items+=("$(printf '%-5s [Not installed]          - %s' "$cmd" "$desc")")
  fi
done

count=${#tool_cmds[@]}

if can_prompt_interactively; then
  cursor=0
  tput civis >/dev/tty 2>/dev/null || printf "\033[?25l" >/dev/tty

  while true; do
    printf "\033[H\033[2J" >/dev/tty
    printf "\033[1;36m=== COMMON CLI TOOLS INSTALLER ===\033[0m\n" >/dev/tty
    printf "\033[1;34mSelect tools to install or update via apt:\033[0m\n" >/dev/tty
    printf "\033[90m[↑/↓] Navigate | [Space] Toggle | [a] Toggle All | [Enter] Confirm | [q] Cancel\033[0m\n\n" >/dev/tty

    for ((i=0; i<count; i++)); do
      mark=" "
      (( selected[i] )) && mark="x"

      if (( i == cursor )); then
        printf " \033[1;32m>\033[0m [\033[1;32m%s\033[0m] %s\n" "$mark" "${menu_items[i]}" >/dev/tty
      else
        printf "   [%s] %s\n" "$mark" "${menu_items[i]}" >/dev/tty
      fi
    done

    key=""
    IFS= read -rsn1 key < /dev/tty || handle_cancel

    if [[ $key == $'\x1b' ]]; then
      read -rsn2 -t 0.1 seq < /dev/tty || seq=""
      if [[ $seq == "[A" ]]; then
        if ((cursor > 0)); then cursor=$((cursor - 1)); else cursor=$((count - 1)); fi
      elif [[ $seq == "[B" ]]; then
        if ((cursor < count - 1)); then cursor=$((cursor + 1)); else cursor=0; fi
      fi
    elif [[ $key == "k" || $key == "K" ]]; then
      if ((cursor > 0)); then cursor=$((cursor - 1)); else cursor=$((count - 1)); fi
    elif [[ $key == "j" || $key == "J" ]]; then
      if ((cursor < count - 1)); then cursor=$((cursor + 1)); else cursor=0; fi
    elif [[ $key == "a" || $key == "A" ]]; then
      all_on=1
      for ((i=0; i<count; i++)); do
        (( selected[i] == 0 )) && { all_on=0; break; }
      done
      for ((i=0; i<count; i++)); do
        selected[i]=$(( 1 - all_on ))
      done
    elif [[ $key == " " ]]; then
      selected[cursor]=$(( 1 - selected[cursor] ))
    elif [[ $key == "q" || $key == "Q" || $key == $'\x03' ]]; then
      handle_cancel
    elif [[ $key == "" || $key == $'\r' || $key == $'\n' ]]; then
      break
    fi
  done
  restore_cursor
fi

# Collect packages to install
pkgs_to_install=()
cmds_to_install=()
skipped_items=()

for ((i=0; i<count; i++)); do
  if (( selected[i] )); then
    pkgs_to_install+=("${tool_pkgs[i]}")
    cmds_to_install+=("${tool_cmds[i]}")
  else
    if (( tool_installed[i] )); then
      skipped_items+=("${tool_cmds[i]} (v${tool_versions[i]})")
    else
      skipped_items+=("${tool_cmds[i]} (unselected)")
    fi
  fi
done

if (( ${#pkgs_to_install[@]} == 0 )); then
  printf "\nNo tools selected for installation.\n"
  exit 0
fi

printf "\n\033[1;36m================ TOOLS INSTALLATION PLAN ================\033[0m\n"
printf " The following packages will be installed/updated via apt:\n"
for ((i=0; i<count; i++)); do
  if (( selected[i] )); then
    printf "   \033[1;32m[+]\033[0m %-6s -> Package: %-10s (%s)\n" "${tool_cmds[i]}" "${tool_pkgs[i]}" "${tool_descs[i]}"
  fi
done

if (( ${#skipped_items[@]} > 0 )); then
  printf "\n Skipped (already up-to-date / unselected):\n"
  for s in "${skipped_items[@]}"; do
    printf "   \033[90m[-] %s\033[0m\n" "$s"
  done
fi
printf "\n"

# Prompt confirmation (default No)
confirm_proceed=0
if can_prompt_interactively; then
  while true; do
    printf "Proceed with 'sudo apt install'? [y/N]: " >/dev/tty
    IFS= read -r answer < /dev/tty || exit 130
    case "$answer" in
      [Yy]|[Yy][Ee][Ss]) confirm_proceed=1; break ;;
      ""|[Nn]|[Nn][Oo]) confirm_proceed=0; break ;;
      *) printf "Please answer y or n (Enter defaults to cancel).\n" >/dev/tty ;;
    esac
  done
else
  printf "Non-interactive environment detected. Skipping package installation.\n"
  exit 0
fi

if (( confirm_proceed )); then
  echo "==> Updating package index (sudo apt update)..."
  sudo apt update
  echo "==> Installing packages: ${pkgs_to_install[*]}..."
  sudo apt install -y "${pkgs_to_install[@]}"
  echo
  printf "\033[1;32m✔ Tools installation completed successfully!\033[0m\n"
else
  printf "\nInstallation cancelled.\n"
  exit 0
fi
