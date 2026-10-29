# Windows / WSL helpers

_WIN="${DOTFILES_WIN_PATH:-/mnt/c/Windows}"
_CLIP="$_WIN/System32/clip.exe"
_EXPLORER="$_WIN/explorer.exe"
_POWERSHELL="$_WIN/System32/WindowsPowerShell/v1.0/powershell.exe"

clip() {
  if [[ -x "$_CLIP" ]]; then
    "$_CLIP" "$@"
  elif command -v clip.exe &>/dev/null; then
    clip.exe "$@"
  else
    echo "❌ clip.exe not found at $_CLIP" >&2
    return 1
  fi
}

explorer() {
  if [[ -x "$_EXPLORER" ]]; then
    "$_EXPLORER" "$@"
  elif command -v explorer.exe &>/dev/null; then
    explorer.exe "$@"
  else
    echo "❌ explorer.exe not found at $_EXPLORER" >&2
    return 1
  fi
}

powershell() {
  if [[ -x "$_POWERSHELL" ]]; then
    "$_POWERSHELL" "$@"
  elif command -v powershell.exe &>/dev/null; then
    powershell.exe "$@"
  else
    echo "❌ powershell.exe not found at $_POWERSHELL" >&2
    return 1
  fi
}

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
  _run_confirm cp "$src" "$dst"
}
