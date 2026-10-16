#!/usr/bin/env bash
set -e

REPO="https://github.com/venhdev/dotfiles.git"
DIR="${DOTFILES_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}"
BASHRC="${DOTFILES_BASHRC:-$HOME/.bashrc}"
MARKER="# Load dotfiles"

# Parse CLI arguments
OPT_ALL=0
for arg in "$@"; do
  case "$arg" in
    -a|--all)
      OPT_ALL=1
      ;;
    -h|--help)
      echo "Usage: ./install.sh [OPTIONS]"
      echo
      echo "Options:"
      echo "  -a, --all    Install all modules with defaults (non-interactive)"
      echo "  -h, --help   Show this help message"
      exit 0
      ;;
  esac
done

is_worktree_dirty() {
  [[ -n "$(git -C "$DIR" status --porcelain)" ]]
}

is_local_change_pull_error() {
  case "$1" in
    *"would be overwritten by merge"*|\
    *"Please commit your changes or stash them before you merge."*|\
    *"cannot pull with rebase: You have unstaged changes"*|\
    *"cannot pull with rebase: Your index contains uncommitted changes."*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

can_prompt_interactively() {
  { exec 3<>/dev/tty; } 2>/dev/null || return 1
  exec 3>&-
}

prompt_yes_no() {
  local answer
  while true; do
    printf "%s [y/N]: " "$1" > /dev/tty
    IFS= read -r answer < /dev/tty || return 1
    case "$answer" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]|"") return 1 ;;
      *) printf "Please answer yes or no.\n" > /dev/tty ;;
    esac
  done
}

# 1. Update or clone repository
if [[ -d "$DIR/.git" ]]; then
  if pull_output="$(git -C "$DIR" pull --ff-only 2>&1)"; then
    [ -n "$pull_output" ] && printf '%s\n' "$pull_output"
    ACTION=updated
  else
    pull_exit=$?
    if is_worktree_dirty && is_local_change_pull_error "$pull_output"; then
      printf '%s\n' "$pull_output" >&2
      if ! can_prompt_interactively; then
        echo "Cannot prompt to force update without an interactive terminal." >&2
        echo "Please stash or commit your local changes in $DIR, then re-run install.sh." >&2
        exit "$pull_exit"
      fi

      if prompt_yes_no "Local changes detected in $DIR. Stash changes and force update?"; then
        stash_message="dotfiles installer auto-stash $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        git -C "$DIR" stash push -u -m "$stash_message" >/dev/null
        stash_ref="$(git -C "$DIR" rev-parse --short -q --verify refs/stash)"

        if pull_output="$(git -C "$DIR" pull --ff-only 2>&1)"; then
          [ -n "$pull_output" ] && printf '%s\n' "$pull_output"
          ACTION=updated
          echo "Stashed local changes before update as stash@{0} (${stash_ref})."
          echo "Re-apply when ready with: git -C \"$DIR\" stash pop"
        else
          printf '%s\n' "$pull_output" >&2
          echo "Update failed after stashing. Your local changes are preserved in stash@{0} (${stash_ref})." >&2
          echo "Recover with: git -C \"$DIR\" stash pop" >&2
          exit 1
        fi
      else
        echo "Install cancelled: leaving local checkout unchanged at $DIR." >&2
        exit 1
      fi
    else
      printf '%s\n' "$pull_output" >&2
      exit "$pull_exit"
    fi
  fi
else
  # If running in local checkout not at $DIR, copy or clone
  if [[ ! -d "$DIR" ]]; then
    git clone "$REPO" "$DIR"
    ACTION=installed
  else
    ACTION=updated
  fi
fi

# 2. Existing local config detection
existing_ssh_init=""
existing_win_path=""
if [[ -f "$DIR/local/local.env" ]]; then
  existing_ssh_init="$(grep -E '^export DOTFILES_SSH_INIT=' "$DIR/local/local.env" | cut -d'"' -f2 || true)"
  existing_win_path="$(grep -E '^export DOTFILES_WIN_PATH=' "$DIR/local/local.env" | cut -d'"' -f2 || true)"
fi

detected_ssh_keys=()
if [[ -d "$HOME/.ssh" ]]; then
  while IFS= read -r -d "" file; do
    detected_ssh_keys+=("$file")
  done < <(find "$HOME/.ssh" -maxdepth 1 -type f \
    \( -name "*_ed25519" -o -name "*_rsa" -o -name "*_ecdsa" -o -name "id_*" \) \
    ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" \
    ! -name "*.old" ! -name "*.bak" -print0 2>/dev/null | sort -z)
fi

auto_key=""
if (( ${#detected_ssh_keys[@]} > 0 )); then
  auto_key="${detected_ssh_keys[0]}"
fi
default_ssh="${existing_ssh_init:-$auto_key}"
default_win="${existing_win_path:-/mnt/c/Windows}"

# Module definitions:
# index 0: [ALL]
# index 1: ssh
# index 2: wsl
# index 3: mobile
modules=("ALL" "ssh" "wsl" "mobile")
menu_labels=(
  "[ALL] Select / Deselect all modules"
  "ssh    - SSH Manager (Auto ssh-agent & SSH key loading)"
  "wsl    - WSL Integration (clip, explorer, winpath)"
  "mobile - Mobile Dev (Flutter, Shorebird, Android ADB tools)"
)
num_items=${#modules[@]}
selected=(0 0 0 0)

# Pre-select initial state based on environment or existing symlinks
if [[ -L "$DIR/enabled.d/50-ssh.sh" ]]; then
  selected[1]=1
elif [[ -n "$auto_key" || -n "$existing_ssh_init" ]]; then
  selected[1]=1
fi

if [[ -L "$DIR/enabled.d/50-wsl.sh" ]]; then
  selected[2]=1
elif grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  selected[2]=1
fi

if [[ -L "$DIR/enabled.d/50-mobile.sh" ]]; then
  selected[3]=1
fi

toggle_all() {
  local all_on=1
  for ((idx=1; idx<num_items; idx++)); do
    (( selected[idx] == 0 )) && { all_on=0; break; }
  done
  for ((idx=1; idx<num_items; idx++)); do
    selected[idx]=$(( 1 - all_on ))
  done
}

# 3. Interactive Selection or Non-interactive Fallback
ssh_init_val="$default_ssh"
win_path_val="$default_win"

if (( OPT_ALL )); then
  for ((idx=1; idx<num_items; idx++)); do
    selected[idx]=1
  done
elif can_prompt_interactively; then
  tput civis >/dev/tty 2>/dev/null || printf "\033[?25l" >/dev/tty
  restore_cursor() {
    tput cnorm >/dev/tty 2>/dev/null || printf "\033[?25h" >/dev/tty
  }
  trap restore_cursor EXIT INT TERM

  cursor=0
  while true; do
    printf "\033[H\033[2J" >/dev/tty
    printf "\033[1;36m=== DOTFILES MODULE SELECTOR ===\033[0m\n" >/dev/tty
    printf "\033[90m[↑/↓] Navigate | [Space] Toggle | [a] Toggle All | [Enter] Confirm\033[0m\n\n" >/dev/tty

    total_selected=0
    for ((i=1; i<num_items; i++)); do
      if (( selected[i] )); then
        total_selected=$((total_selected + 1))
      fi
    done

    all_mark=" "
    if (( total_selected == num_items - 1 )); then
      all_mark="*"
    elif (( total_selected > 0 )); then
      all_mark="-"
    fi

    for ((i=0; i<num_items; i++)); do
      mark=" "
      if (( i == 0 )); then
        mark="$all_mark"
      else
        (( selected[i] )) && mark="x"
      fi

      if (( i == cursor )); then
        printf " \033[1;32m> [%s] %s\033[0m\n" "$mark" "${menu_labels[i]}" >/dev/tty
      else
        printf "   [%s] %s\n" "$mark" "${menu_labels[i]}" >/dev/tty
      fi
    done
    printf "\n" >/dev/tty

    IFS= read -rsn1 key < /dev/tty
    if [[ $key == $'\x1b' ]]; then
      read -rsn2 -t 0.1 seq < /dev/tty || true
      case "$seq" in
        "[A"|"OA") if ((cursor > 0)); then cursor=$((cursor - 1)); else cursor=$((num_items - 1)); fi ;;
        "[B"|"OB") if ((cursor < num_items - 1)); then cursor=$((cursor + 1)); else cursor=0; fi ;;
      esac
    elif [[ $key == "k" || $key == "K" ]]; then
      if ((cursor > 0)); then cursor=$((cursor - 1)); else cursor=$((num_items - 1)); fi
    elif [[ $key == "j" || $key == "J" ]]; then
      if ((cursor < num_items - 1)); then cursor=$((cursor + 1)); else cursor=0; fi
    elif [[ $key == "a" || $key == "A" ]]; then
      toggle_all
    elif [[ $key == " " ]]; then
      if (( cursor == 0 )); then
        toggle_all
      else
        selected[cursor]=$(( 1 - selected[cursor] ))
      fi
    elif [[ $key == "" || $key == $'\r' || $key == $'\n' ]]; then
      break
    fi
  done
  restore_cursor
  trap - EXIT INT TERM

  # Dynamic Configuration Prompts
  if (( selected[1] || selected[2] )); then
    printf "\033[1;34m--- Dynamic Configuration ---\033[0m\n" >/dev/tty

    if (( selected[1] )); then
      num_detected=${#detected_ssh_keys[@]}
      if (( num_detected > 0 )); then
        ssh_menu_items=()
        for k in "${detected_ssh_keys[@]}"; do
          base_name="$(basename "$k")"
          ssh_menu_items+=("$base_name (~/.ssh/$base_name)")
        done
        ssh_menu_items+=("[None] Skip SSH auto-load")
        ssh_menu_items+=("[Custom] Enter path manually...")
        ssh_item_count=${#ssh_menu_items[@]}

        ssh_cursor=0
        if [[ -n "$existing_ssh_init" ]]; then
          for ((k_idx=0; k_idx<num_detected; k_idx++)); do
            if [[ "${detected_ssh_keys[k_idx]}" == "$existing_ssh_init" ]]; then
              ssh_cursor=$k_idx
              break
            fi
          done
        fi

        tput civis >/dev/tty 2>/dev/null || printf "\033[?25l" >/dev/tty
        trap restore_cursor EXIT INT TERM

        while true; do
          printf "\033[H\033[2J" >/dev/tty
          printf "\033[1;36m=== DOTFILES CONFIGURATION ===\033[0m\n" >/dev/tty
          printf "\033[1;34m--- Dynamic Configuration ---\033[0m\n" >/dev/tty
          printf "Select an SSH key to auto-load on shell startup:\n" >/dev/tty
          printf "\033[90m[↑/↓] Navigate | [Enter] Confirm\033[0m\n\n" >/dev/tty

          for ((i=0; i<ssh_item_count; i++)); do
            if (( i == ssh_cursor )); then
              printf " \033[1;32m> %s\033[0m\n" "${ssh_menu_items[i]}" >/dev/tty
            else
              printf "   %s\n" "${ssh_menu_items[i]}" >/dev/tty
            fi
          done
          printf "\n" >/dev/tty

          IFS= read -rsn1 key < /dev/tty
          if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 seq < /dev/tty || true
            case "$seq" in
              "[A"|"OA") if ((ssh_cursor > 0)); then ssh_cursor=$((ssh_cursor - 1)); else ssh_cursor=$((ssh_item_count - 1)); fi ;;
              "[B"|"OB") if ((ssh_cursor < ssh_item_count - 1)); then ssh_cursor=$((ssh_cursor + 1)); else ssh_cursor=0; fi ;;
            esac
          elif [[ $key == "k" || $key == "K" ]]; then
            if ((ssh_cursor > 0)); then ssh_cursor=$((ssh_cursor - 1)); else ssh_cursor=$((ssh_item_count - 1)); fi
          elif [[ $key == "j" || $key == "J" ]]; then
            if ((ssh_cursor < ssh_item_count - 1)); then ssh_cursor=$((ssh_cursor + 1)); else ssh_cursor=0; fi
          elif [[ $key == "" || $key == $'\r' || $key == $'\n' ]]; then
            break
          fi
        done
        restore_cursor
        trap - EXIT INT TERM

        if (( ssh_cursor < num_detected )); then
          ssh_init_val="${detected_ssh_keys[ssh_cursor]}"
        elif (( ssh_cursor == num_detected )); then
          ssh_init_val=""
        else
          printf "Custom SSH key path (leave empty to skip): " >/dev/tty
          IFS= read -r input_ssh < /dev/tty
          ssh_init_val="${input_ssh:-}"
        fi
      else
        printf "No SSH keys found in ~/.ssh.\n" >/dev/tty
        printf "SSH key path to auto-load (press Enter to skip): " >/dev/tty
        IFS= read -r input_ssh < /dev/tty
        ssh_init_val="${input_ssh:-}"
      fi
    fi

    if (( selected[2] )); then
      printf "Windows system path [%s]: " "$default_win" >/dev/tty
      IFS= read -r input_win < /dev/tty
      win_path_val="${input_win:-$default_win}"
    fi
  fi

  # Summary and Confirmation
  printf "\n\033[1;36m================ INSTALLATION SUMMARY ================\033[0m\n" >/dev/tty
  printf " Core: shell-lib, base-aliases, editor-lib, config-lib, info-lib (Always enabled)\n" >/dev/tty
  printf " Modules:\n" >/dev/tty
  if (( selected[1] )); then
    if [[ -n "$ssh_init_val" ]]; then
      printf "   \033[1;32m[✔] ssh\033[0m    -> Key: %s\n" "$ssh_init_val" >/dev/tty
    else
      printf "   \033[1;32m[✔] ssh\033[0m    -> Key: (None - auto-load skipped)\n" >/dev/tty
    fi
  else
    printf "   \033[90m[ ] ssh    -> Disabled\033[0m\n" >/dev/tty
  fi

  if (( selected[2] )); then
    printf "   \033[1;32m[✔] wsl\033[0m    -> WinPath: %s\n" "$win_path_val" >/dev/tty
  else
    printf "   \033[90m[ ] wsl    -> Disabled\033[0m\n" >/dev/tty
  fi

  if (( selected[3] )); then
    printf "   \033[1;32m[✔] mobile\033[0m -> Flutter, Shorebird, ADB tools enabled\n" >/dev/tty
  else
    printf "   \033[90m[ ] mobile -> Disabled\033[0m\n" >/dev/tty
  fi
  printf "\n" >/dev/tty

  if ! prompt_yes_no "Proceed with installation?"; then
    echo "Installation cancelled." >&2
    exit 1
  fi
fi

# 4. Apply Configuration and Setup Symlinks
mkdir -p "$DIR/local" "$DIR/enabled.d"

# Write local.env
cat > "$DIR/local/local.env.tmp" <<EOF
# Machine-specific local configuration (managed by dotfiles install.sh)
export DOTFILES_SSH_INIT="${ssh_init_val}"
export DOTFILES_WIN_PATH="${win_path_val}"
EOF
chmod 600 "$DIR/local/local.env.tmp"
mv "$DIR/local/local.env.tmp" "$DIR/local/local.env"

# Sync symlinks in enabled.d
rm -f "$DIR/enabled.d"/50-*.sh
(( selected[1] )) && ln -sfn "../modules/ssh/module.sh" "$DIR/enabled.d/50-ssh.sh"
(( selected[2] )) && ln -sfn "../modules/wsl/module.sh" "$DIR/enabled.d/50-wsl.sh"
(( selected[3] )) && ln -sfn "../modules/mobile/module.sh" "$DIR/enabled.d/50-mobile.sh"

# 5. Update ~/.bashrc
touch "$BASHRC"

if grep -Fq "$MARKER" "$BASHRC"; then
  sed -i '/^# Load dotfiles$/,/^unset _\(cfg\|f\) DOTFILES$/d' "$BASHRC"
fi

cat >>"$BASHRC" <<'EOF'

# Load dotfiles
DOTFILES="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

[ -r "$DOTFILES/local/local.env" ] && . "$DOTFILES/local/local.env"

for _f in "$DOTFILES"/core/*.sh "$DOTFILES"/enabled.d/*.sh "$HOME/.env"; do
  [ -r "$_f" ] && . "$_f"
done

unset _f DOTFILES
EOF

# 6. Global Git Configuration
GIT_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/.gitconfig"
OLD_GIT_ALIASES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/.gitconfig_aliases"
if command -v git >/dev/null 2>&1; then
  if git config --global --get-all include.path 2>/dev/null | grep -Fxq "$OLD_GIT_ALIASES_FILE"; then
    git config --global --unset-all include.path "$OLD_GIT_ALIASES_FILE" 2>/dev/null || true
  fi
  if ! git config --global --get-all include.path 2>/dev/null | grep -Fxq "$GIT_CONFIG_FILE"; then
    git config --global --add include.path "$GIT_CONFIG_FILE"
  fi
fi

echo
echo "Dotfiles $ACTION successfully: $DIR"
echo
echo "Run below command to reload:"
echo "source ~/.bashrc"
