#!/usr/bin/env bash
set -e

REPO="https://github.com/venhdev/dotfiles.git"
DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
BASHRC="$HOME/.bashrc"
MARKER="# Load dotfiles"

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
  git clone "$REPO" "$DIR"
  ACTION=installed
fi

touch "$BASHRC"

grep -Fq "$MARKER" "$BASHRC" || cat >>"$BASHRC" <<'EOF'

# Load dotfiles
DOTFILES="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

for _cfg in "$DOTFILES"/.*_aliases "$DOTFILES"/scripts/*.sh "$HOME/.env"; do
  [ -r "$_cfg" ] && . "$_cfg"
done

unset _cfg DOTFILES
EOF

echo "Dotfiles $ACTION: $DIR"
echo
echo "Run below command to reload:"
echo "source ~/.bashrc"
