# Windows / WSL helpers

_WIN="${DOTFILES_WIN_PATH:-/mnt/c/Windows}"
_CLIP="$_WIN/System32/clip.exe"
_EXPLORER="$_WIN/explorer.exe"
_POWERSHELL="$_WIN/System32/WindowsPowerShell/v1.0/powershell.exe"

clip()       { "$_CLIP" "$@"; }
explorer()   { "$_EXPLORER" "$@"; }
powershell() { "$_POWERSHELL" "$@"; }

winpath() {
  wslpath -w "${1:-$PWD}"
}

opene() {
  explorer "$(winpath "${1:-$PWD}")"
}

cpath() {
  local p
  p=$(winpath "${1:-$PWD}")
  echo "Copied: $p"
  printf '%s' "$p" | clip
}

wcp() {
  (($# == 2)) || {
    echo "Usage: wcp <src> <dst>"
    return 1
  }

  local src="$1" dst="$2"

  [[ $src =~ ^[A-Za-z]:[\\/].* ]] && src=$(wslpath -u "$src")
  [[ $dst =~ ^[A-Za-z]:[\\/].* ]] && dst=$(wslpath -u "$dst")

  echo "$src → $dst"
  _confirm "Confirm? [Y/n] " || return 1

  cp "$src" "$dst"
}
