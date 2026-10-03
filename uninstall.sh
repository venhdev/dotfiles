#!/usr/bin/env bash
set -e

DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
BASHRC="$HOME/.bashrc"

read -rp "Uninstall dotfiles? [y/N] " a </dev/tty
[[ $a =~ ^[Yy]$ ]] || { echo "Cancelled"; exit; }

sed -i '/^# Load dotfiles$/,/^unset _cfg DOTFILES$/d' "$BASHRC"
rm -rf "$DIR"

echo "✅ Dotfiles uninstalled"
echo "→ exec bash"
