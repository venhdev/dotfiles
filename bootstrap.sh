#!/usr/bin/env bash
set -e

REPO="https://github.com/venhdev/dotfiles.git"
DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

if [[ -d "$DIR/.git" ]]; then
  git -C "$DIR" pull --ff-only
  ACTION=updated
else
  git clone "$REPO" "$DIR"
  ACTION=installed
fi

"$DIR/install.sh"

echo "✅ Dotfiles $ACTION: $DIR"
