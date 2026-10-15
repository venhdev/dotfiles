#!/usr/bin/env bash
set -e

DIR="${DOTFILES_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}"
BASHRC="${DOTFILES_BASHRC:-$HOME/.bashrc}"

can_prompt_interactively() {
  { exec 3<>/dev/tty; } 2>/dev/null || return 1
  exec 3>&-
}

if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
  CONFIRMED=1
elif can_prompt_interactively; then
  read -rp "Uninstall dotfiles? [y/N] " a </dev/tty
  [[ $a =~ ^[Yy]$ ]] || { echo "Cancelled"; exit; }
else
  read -rp "Uninstall dotfiles? [y/N] " a
  [[ $a =~ ^[Yy]$ ]] || { echo "Cancelled"; exit; }
fi

sed -i '/^# Load dotfiles$/,/^unset _\(cfg\|f\) DOTFILES$/d' "$BASHRC"

GIT_CONFIG_FILE="$DIR/.gitconfig"
OLD_GIT_ALIASES_FILE="$DIR/.gitconfig_aliases"
if command -v git >/dev/null 2>&1; then
  git config --global --unset-all include.path "$GIT_CONFIG_FILE" 2>/dev/null || true
  git config --global --unset-all include.path "$OLD_GIT_ALIASES_FILE" 2>/dev/null || true
fi

rm -rf "$DIR"

echo "Dotfiles uninstalled"
echo
echo "Run below command to reload:"
echo "exec bash"
