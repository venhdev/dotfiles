#!/usr/bin/env bash
set -e

DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
BASHRC="$HOME/.bashrc"

read -rp "Uninstall dotfiles? [y/N] " a </dev/tty
[[ $a =~ ^[Yy]$ ]] || {
  echo "Cancelled"
  exit 0
}

if [[ -f "$BASHRC" ]]; then
  sed -i '/^# Load dotfiles$/,/^unset _cfg DOTFILES$/d' "$BASHRC"
  echo "✅ Removed dotfiles loader from $BASHRC"
fi

rm -rf "$DIR"

echo "✅ Dotfiles uninstalled"
echo
echo "Run:"
echo "exec bash"
