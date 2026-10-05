#!/usr/bin/env bash
set -e

REPO="https://github.com/venhdev/dotfiles.git"
DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
BASHRC="$HOME/.bashrc"
MARKER="# Load dotfiles"

if [[ -d "$DIR/.git" ]]; then
  git -C "$DIR" pull --ff-only
  ACTION=updated
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
