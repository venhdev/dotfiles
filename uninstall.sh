#!/usr/bin/env bash
set -e

DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
BASHRC="$HOME/.bashrc"

read -rp "Uninstall dotfiles? [y/N] " a </dev/tty
[[ $a =~ ^[Yy]$ ]] || { echo "Cancelled"; exit; }

sed -i '/^# Load dotfiles$/,/^unset _cfg DOTFILES$/d' "$BASHRC"

GIT_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/.gitconfig"
OLD_GIT_ALIASES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/.gitconfig_aliases"
if command -v git >/dev/null 2>&1; then
  git config --global --unset-all include.path "$GIT_CONFIG_FILE" 2>/dev/null || true
  git config --global --unset-all include.path "$OLD_GIT_ALIASES_FILE" 2>/dev/null || true
fi

rm -rf "$DIR"

echo "Dotfiles uninstalled"
echo
echo "Run below command to reload:"
echo "exec bash"
