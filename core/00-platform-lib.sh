# Cross-platform environment detection and standard OS primitives (Linux, macOS, Windows)

# Detect Operating System Family
_detect_os() {
  if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
    echo "msys"
    return
  fi

  local uname_out
  uname_out="$(uname -s 2>/dev/null || echo "Unknown")"

  case "$uname_out" in
    Darwin*)
      echo "darwin"
      ;;
    MSYS*|MINGW*|CYGWIN*)
      echo "msys"
      ;;
    Linux*)
      if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ "$(uname -r 2>/dev/null)" == *[Mm]icrosoft* ]] || [[ -f /proc/version && "$(< /proc/version)" == *[Mm]icrosoft* ]]; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Detect Linux Distribution Family (from /etc/os-release)
_detect_distro() {
  if [[ -f /etc/os-release ]]; then
    local id="" id_like=""
    id="$(grep -E '^ID=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"'"'" | tr '[:upper:]' '[:lower:]')"
    id_like="$(grep -E '^ID_LIKE=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"'"'" | tr '[:upper:]' '[:lower:]')"
    echo "${id:-${id_like:-linux}}"
  else
    echo "unknown"
  fi
}

# Detect Windows Host System Directory
_detect_win_dir() {
  if [[ -n "${DOTFILES_WIN_PATH:-}" && -d "$DOTFILES_WIN_PATH" ]]; then
    echo "$DOTFILES_WIN_PATH"
  elif [[ -d "/c/Windows" ]]; then
    echo "/c/Windows"
  elif [[ -d "/mnt/c/Windows" ]]; then
    echo "/mnt/c/Windows"
  else
    echo "/mnt/c/Windows"
  fi
}

_OS_TYPE="$(_detect_os)"
_LINUX_DISTRO="$(_detect_distro)"
_WIN_DIR="$(_detect_win_dir)"

# SSOT Boolean Helper Functions
is_darwin() { [[ "$_OS_TYPE" == "darwin" ]]; }
is_mac() { is_darwin; }
is_wsl() { [[ "$_OS_TYPE" == "wsl" ]]; }
is_msys() { [[ "$_OS_TYPE" == "msys" ]]; }
is_linux() { [[ "$_OS_TYPE" == "linux" || "$_OS_TYPE" == "wsl" ]]; }
is_pure_linux() { [[ "$_OS_TYPE" == "linux" ]]; }
is_windows() { [[ "$_OS_TYPE" == "msys" || "$_OS_TYPE" == "wsl" ]]; }
has_apt() { command -v apt-get >/dev/null 2>&1; }

# Cross-platform clipboard helper
clip() {
  case "$_OS_TYPE" in
    darwin)
      if command -v pbcopy &>/dev/null; then
        pbcopy "$@"
        return $?
      fi
      ;;
    wsl|msys)
      local clip_exe="${DOTFILES_WIN_PATH:-$_WIN_DIR}/System32/clip.exe"
      if [[ -x "$clip_exe" ]]; then
        "$clip_exe" "$@"
        return $?
      elif command -v clip.exe &>/dev/null; then
        clip.exe "$@"
        return $?
      fi
      ;;
    linux)
      if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy &>/dev/null; then
        wl-copy "$@"
        return $?
      elif command -v xclip &>/dev/null; then
        xclip -selection clipboard "$@"
        return $?
      elif command -v xsel &>/dev/null; then
        xsel --clipboard --input "$@"
        return $?
      fi
      ;;
  esac

  echo "❌ No supported clipboard utility found (pbcopy, clip.exe, wl-copy, xclip, xsel)" >&2
  return 1
}

# Cross-platform file / URL opener
open_target() {
  local target="${1:-.}"

  case "$_OS_TYPE" in
    darwin)
      open "$target"
      ;;
    wsl)
      if command -v wslpath &>/dev/null && [[ -e "$target" ]]; then
        explorer.exe "$(wslpath -w "$target")"
      else
        explorer.exe "$target"
      fi
      ;;
    msys)
      explorer.exe "$target"
      ;;
    linux)
      if command -v xdg-open &>/dev/null; then
        xdg-open "$target" &>/dev/null &
      else
        echo "❌ xdg-open not found" >&2
        return 1
      fi
      ;;
    *)
      echo "❌ No supported opener found for OS: $_OS_TYPE" >&2
      return 1
      ;;
  esac
}

# Unified Package Manager abstraction (apt, brew, pacman, dnf, winget, scoop)
pkg() {
  local action="${1:-help}"
  shift 2>/dev/null || true

  # Detect installed package manager
  local mgr=""
  if command -v brew &>/dev/null; then
    mgr="brew"
  elif command -v apt-get &>/dev/null; then
    mgr="apt"
  elif command -v pacman &>/dev/null; then
    mgr="pacman"
  elif command -v dnf &>/dev/null; then
    mgr="dnf"
  elif command -v winget.exe &>/dev/null; then
    mgr="winget"
  elif command -v scoop &>/dev/null; then
    mgr="scoop"
  fi

  if [[ -z "$mgr" ]]; then
    echo "❌ No supported package manager found (brew, apt, pacman, dnf, winget, scoop)" >&2
    return 1
  fi

  case "$action" in
    update)
      case "$mgr" in
        brew)   brew update ;;
        apt)    sudo apt update ;;
        pacman) sudo pacman -Sy ;;
        dnf)    sudo dnf check-update ;;
        winget) winget.exe source update ;;
        scoop)  scoop update ;;
      esac
      ;;
    upgrade)
      case "$mgr" in
        brew)   brew upgrade ;;
        apt)    sudo apt update && sudo apt upgrade -y ;;
        pacman) sudo pacman -Syu ;;
        dnf)    sudo dnf upgrade -y ;;
        winget) winget.exe upgrade --all ;;
        scoop)  scoop update * ;;
      esac
      ;;
    install|add)
      case "$mgr" in
        brew)   brew install "$@" ;;
        apt)    sudo apt install "$@" ;;
        pacman) sudo pacman -S "$@" ;;
        dnf)    sudo dnf install "$@" ;;
        winget) winget.exe install "$@" ;;
        scoop)  scoop install "$@" ;;
      esac
      ;;
    remove|uninstall)
      case "$mgr" in
        brew)   brew uninstall "$@" ;;
        apt)    sudo apt remove "$@" ;;
        pacman) sudo pacman -R "$@" ;;
        dnf)    sudo dnf remove "$@" ;;
        winget) winget.exe uninstall "$@" ;;
        scoop)  scoop uninstall "$@" ;;
      esac
      ;;
    search)
      case "$mgr" in
        brew)   brew search "$@" ;;
        apt)    apt search "$@" ;;
        pacman) pacman -Ss "$@" ;;
        dnf)    dnf search "$@" ;;
        winget) winget.exe search "$@" ;;
        scoop)  scoop search "$@" ;;
      esac
      ;;
    *)
      cat <<EOF
Usage: pkg <command> [arguments...]

Supported commands:
  pkg update             Refresh package repository indexes
  pkg upgrade            Upgrade all installed packages
  pkg install <package>  Install a package
  pkg remove <package>   Uninstall a package
  pkg search <query>     Search for packages

Active manager detected: $mgr
EOF
      ;;
  esac
}

# Shell-aware reload helper (supports both Bash and Zsh)
rel() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    local zsh_rc="${ZDOTDIR:-$HOME}/.zshrc"
    if [[ -r "$zsh_rc" ]]; then
      # shellcheck disable=SC1090
      source "$zsh_rc"
      echo "✓ Reloaded $zsh_rc"
      return 0
    fi
  fi

  local bash_rc="$HOME/.bashrc"
  if [[ -r "$bash_rc" ]]; then
    # shellcheck disable=SC1090
    source "$bash_rc"
    echo "✓ Reloaded $bash_rc"
    return 0
  fi

  echo "❌ Neither ~/.zshrc nor ~/.bashrc found to reload." >&2
  return 1
}
