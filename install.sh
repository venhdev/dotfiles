#!/usr/bin/env bash
set -e

BASHRC="$HOME/.bashrc"
MARKER="# Load dotfiles"

touch "$BASHRC"

grep -Fq "$MARKER" "$BASHRC" || cat >>"$BASHRC" <<'EOF'

# Load dotfiles
DOTFILES="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

for _cfg in "$DOTFILES"/.*_aliases "$DOTFILES"/scripts/*.sh "$HOME/.env"; do
  [ -r "$_cfg" ] && . "$_cfg"
done

unset _cfg DOTFILES
EOF
