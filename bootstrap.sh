#!/usr/bin/env bash
set -e

REPO="https://github.com/venhdev/dotfiles.git"
DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

if [[ -d "$DIR/.git" ]]; then
  git -C "$DIR" pull --ff-only
  ACTION="Updated"
else
  mkdir -p "$(dirname "$DIR")"
  git clone "$REPO" "$DIR"
  ACTION="Installed"
fi

exec "$DIR/install.sh"

echo "✅ Dotfiles $ACTION: $DIR"
echo
echo "Run:"
echo "source ~/.bashrc"
