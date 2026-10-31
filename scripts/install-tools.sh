#!/usr/bin/env bash
# ==============================================================================
# scripts/install-tools.sh - Dotfiles Package & Tools Notebook Manager
# ==============================================================================
# Interactive TUI notebook to inventory, install, update, remove, and audit
# developer CLI tools across APT and upstream GitHub releases.
# ==============================================================================
set -e

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DOTFILES_ROOT="$(cd "$_SCRIPT_DIR/.." && pwd)"

# Source SSOT libraries
if [[ -f "$_DOTFILES_ROOT/core/00-platform-lib.sh" ]]; then
  # shellcheck source=../core/00-platform-lib.sh
  . "$_DOTFILES_ROOT/core/00-platform-lib.sh"
else
  is_msys() { [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* || "$(uname -s 2>/dev/null)" == MSYS* ]]; }
  is_darwin() { [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; }
  has_apt() { command -v apt-get >/dev/null 2>&1; }
fi

if [[ -f "$_DOTFILES_ROOT/core/05-tui-lib.sh" ]]; then
  # shellcheck source=../core/05-tui-lib.sh
  . "$_DOTFILES_ROOT/core/05-tui-lib.sh"
fi

# Pre-flight OS check
if is_msys; then
  echo "Notice: Common CLI tools installer is not applicable on Windows (Git Bash)."
  echo "Git and curl are bundled with Git Bash. Use winget, choco, or scoop to manage Windows packages."
  exit 0
fi

if is_darwin; then
  echo "Notice: Common CLI tools installer currently targets Debian/Ubuntu (apt/binary)."
  echo "On macOS, please use Homebrew: brew install git curl jq ripgrep lazygit"
  exit 0
fi

# ==============================================================================
# DECLARATIVE TOOL NOTEBOOK REGISTRY
# format: cmd|apt_pkg|gh_repo|asset_template|bin_in_archive|version_cmd|desc|homepage
# ==============================================================================
TOOL_NOTEBOOK=(
  "git|git||||git --version 2>/dev/null | awk '{print \$3}'|Fast, distributed version control system|https://git-scm.com"
  "curl|curl||||curl --version 2>/dev/null | awk 'NR==1{print \$2}'|Command line tool for transferring data with URLs|https://curl.se"
  "jq|jq||||jq --version 2>/dev/null | sed 's/^jq-//'|Command-line JSON processor|https://jqlang.github.io/jq/"
  "rg|ripgrep|BurntSushi/ripgrep|ripgrep_{ver}_{arch}-unknown-linux-musl.tar.gz|rg|rg --version 2>/dev/null | awk 'NR==1{print \$2}'|ripgrep line-oriented search tool|https://github.com/BurntSushi/ripgrep"
  "lazygit|lazygit|jesseduffield/lazygit|lazygit_{ver}_Linux_{arch}.tar.gz|lazygit|lazygit --version 2>/dev/null | awk '{print \$6}'|Simple terminal UI for git commands|https://github.com/jesseduffield/lazygit"
)

# CLI Options
OPT_ALL=0
for arg in "$@"; do
  case "$arg" in
    -a|--all|-y|--yes)
      OPT_ALL=1
      ;;
    -h|--help)
      echo "Usage: ./install-tools.sh [OPTIONS]"
      echo
      echo "Options:"
      echo "  -a, --all, -y, --yes  Install missing APT packages non-interactively"
      echo "  -h, --help            Show this help message"
      echo
      echo "Interactive mode:"
      echo "  Run without arguments to launch the Package & Tools Notebook TUI."
      exit 0
      ;;
  esac
done

# Hardware Architecture Normalization
_get_arch() {
  local m
  m="$(uname -m 2>/dev/null || echo "x86_64")"
  case "$m" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armhf) echo "armv7" ;;
    i386|i686) echo "32-bit" ;;
    *) echo "$m" ;;
  esac
}

# Check if a package is available in APT repositories
_is_in_apt() {
  local pkg="$1"
  [[ -n "$pkg" ]] || return 1
  has_apt || return 1
  apt-cache show "$pkg" >/dev/null 2>&1
}

# Resolve Latest Release Tag from GitHub (with redirect fallback for API rate limit)
_get_github_latest_ver() {
  local repo="$1"
  local ver=""

  # Try API first
  ver="$(curl -s --connect-timeout 4 "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep -Po '"tag_name":\s*"\K[^"]*' || true)"
  if [[ -n "$ver" ]]; then
    echo "${ver#v}"
    return 0
  fi

  # Fallback to HTTP redirect header (zero API rate limit consumption)
  local redirect_url
  redirect_url="$(curl -sI --connect-timeout 4 "https://github.com/${repo}/releases/latest" 2>/dev/null | grep -i '^location:' | awk '{print $2}' | tr -d '\r\n' || true)"
  if [[ "$redirect_url" =~ /tag/(v?)([^/]+)$ ]]; then
    echo "${BASH_REMATCH[2]}"
    return 0
  fi

  echo "unknown"
  return 1
}

# Detect Installation Source & Path of a Command
_detect_origin() {
  local cmd="$1"
  local bin_path
  bin_path="$(command -v "$cmd" 2>/dev/null || true)"

  if [[ -z "$bin_path" ]]; then
    echo "NONE|-|-"
    return 0
  fi

  # Local user binary directory
  if [[ "$bin_path" == "$HOME/.local/bin/"* ]]; then
    echo "github (local)|$bin_path|local"
    return 0
  fi

  # System package manager check
  if command -v dpkg >/dev/null 2>&1; then
    if dpkg -S "$bin_path" >/dev/null 2>&1; then
      echo "apt (system)|$bin_path|apt"
      return 0
    fi
  fi

  echo "system|$bin_path|system"
}

# Dynamic Ledger In-memory State
item_count=${#TOOL_NOTEBOOK[@]}
cmds=()
apt_pkgs=()
gh_repos=()
asset_fmts=()
bin_names=()
vcmds=()
descs=()
homepages=()

statuses=()
versions=()
origins=()
paths=()
selected=()

_refresh_inventory() {
  cmds=()
  apt_pkgs=()
  gh_repos=()
  asset_fmts=()
  bin_names=()
  vcmds=()
  descs=()
  homepages=()

  statuses=()
  versions=()
  origins=()
  paths=()

  local i def cmd apt_pkg gh_repo asset_fmt bin_name vcmd desc homepage
  local origin_info origin_label path_val origin_type ver_str

  for ((i=0; i<item_count; i++)); do
    def="${TOOL_NOTEBOOK[i]}"
    IFS='|' read -r cmd apt_pkg gh_repo asset_fmt bin_name vcmd desc homepage <<< "$def"
    cmds+=("$cmd")
    apt_pkgs+=("$apt_pkg")
    gh_repos+=("$gh_repo")
    asset_fmts+=("$asset_fmt")
    bin_names+=("${bin_name:-$cmd}")
    vcmds+=("$vcmd")
    descs+=("$desc")
    homepages+=("$homepage")

    origin_info="$(_detect_origin "$cmd")"
    IFS='|' read -r origin_label path_val origin_type <<< "$origin_info"
    origins+=("$origin_label")
    paths+=("$path_val")

    if [[ "$origin_label" == "NONE" ]]; then
      statuses+=(0) # Not installed
      versions+=("-")
    else
      statuses+=(1) # Installed
      ver_str="$(eval "$vcmd" 2>/dev/null || echo "ok")"
      versions+=("${ver_str:-ok}")
    fi

    # Maintain existing selection or default to unselected
    if [[ -z "${selected[i]:-}" ]]; then
      selected+=(0)
    fi
  done
}

# Initial inventory load
_refresh_inventory

# Non-interactive CLI Mode Handler
if (( OPT_ALL )); then
  missing_apt=()
  missing_gh=()

  for ((i=0; i<item_count; i++)); do
    if (( statuses[i] == 0 )); then
      if _is_in_apt "${apt_pkgs[i]}"; then
        missing_apt+=("${apt_pkgs[i]}")
      elif [[ -n "${gh_repos[i]}" ]]; then
        missing_gh+=("${cmds[i]}")
      fi
    fi
  done

  if (( ${#missing_apt[@]} == 0 && ${#missing_gh[@]} == 0 )); then
    echo "✔ All registered tools are already installed."
    exit 0
  fi

  if (( ${#missing_apt[@]} > 0 )); then
    echo "==> Updating package index (sudo apt update)..."
    sudo apt update
    echo "==> Installing missing packages via APT: ${missing_apt[*]}..."
    sudo apt install -y "${missing_apt[@]}"
  fi

  if (( ${#missing_gh[@]} > 0 )); then
    echo
    echo "Notice: The following tools are not available in current APT repositories: ${missing_gh[*]}"
    echo "To install upstream binaries into ~/.local/bin safely with explicit review, launch the notebook:"
    echo "  ./scripts/install-tools.sh"
  fi

  echo
  printf "\033[1;32m✔ Non-interactive package processing completed.\033[0m\n"
  exit 0
fi

# Check interactive TTY capabilities
if ! _tui_is_interactive; then
  echo "Non-interactive environment detected. Use -a or -y to install via apt."
  exit 0
fi

# ==============================================================================
# ACTION HANDLERS (Install, Update, Delete, Info)
# ==============================================================================

# Download and Install GitHub Pre-built Binary
_install_from_github() {
  local cmd="$1"
  local repo="$2"
  local asset_pattern="$3"
  local bin_name="$4"
  local desc="$5"

  local arch
  arch="$(_get_arch)"

  printf "\n${_TUI_CYAN}==> Đang truy vấn phiên bản mới nhất từ GitHub (${repo})...${_TUI_RESET}\n" >/dev/tty
  local ver
  ver="$(_get_github_latest_ver "$repo")"

  if [[ "$ver" == "unknown" || -z "$ver" ]]; then
    printf "${_TUI_RED}Lỗi: Không thể kết nối tới GitHub Releases để lấy phiên bản cho %s.${_TUI_RESET}\n" "$cmd" >/dev/tty
    return 1
  fi

  # Render asset filename from pattern
  local asset_file="$asset_pattern"
  asset_file="${asset_file//\{ver\}/$ver}"
  asset_file="${asset_file//\{arch\}/$arch}"
  asset_file="${asset_file//\{os\}/Linux}"

  local download_url="https://github.com/${repo}/releases/download/v${ver}/${asset_file}"
  # Some repos don't prefix with 'v' in release download URL
  local target_dir="$HOME/.local/bin"

  # Display Transparency Card
  printf "\n${_TUI_GRAY}────────────────────────────────────────────────────────────────────────${_TUI_RESET}\n" >/dev/tty
  printf "${_TUI_CYAN}${_TUI_BOLD} [THÔNG TIN CÀI ĐẶT PRE-BUILT BINARY CHÍNH CHỦ]${_TUI_RESET}\n" >/dev/tty
  printf " • Công cụ       : %s (%s)\n" "$cmd" "$desc" >/dev/tty
  printf " • Repository    : https://github.com/%s\n" "$repo" >/dev/tty
  printf " • Release Page  : https://github.com/%s/releases\n" "$repo" >/dev/tty
  printf " • Phiên bản     : v%s (Kiến trúc: %s)\n" "$ver" "$arch" >/dev/tty
  printf " • File tải về   : %s\n" "$asset_file" >/dev/tty
  printf " • URL chính xác : %s\n" "$download_url" >/dev/tty
  printf " • Thư mục đích  : %s/%s ${_TUI_GREEN}(Không cần sudo, chỉ cho user này)${_TUI_RESET}\n" "$target_dir" "$cmd" >/dev/tty
  printf "${_TUI_GRAY}────────────────────────────────────────────────────────────────────────${_TUI_RESET}\n" >/dev/tty

  if ! _tui_confirm_prompt "Bạn có muốn tải và cài đặt binary từ nguồn GitHub trên không?" "N"; then
    printf "${_TUI_YELLOW}[-] Đã bỏ qua cài đặt %s dạng binary.${_TUI_RESET}\n" "$cmd" >/dev/tty
    printf "    Tài liệu hướng dẫn cài đặt thủ công: https://github.com/%s#installation\n" "$repo" >/dev/tty
    return 0
  fi

  mkdir -p "$target_dir"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  printf "==> Đang tải %s...\n" "$download_url" >/dev/tty
  if ! curl -sL --fail "$download_url" -o "$tmp_dir/$asset_file"; then
    # Try without 'v' prefix in download url if failed
    local alt_url="https://github.com/${repo}/releases/download/${ver}/${asset_file}"
    if ! curl -sL --fail "$alt_url" -o "$tmp_dir/$asset_file"; then
      printf "${_TUI_RED}Lỗi: Tải file thất bại từ cả hai URL:${_TUI_RESET}\n 1. %s\n 2. %s\n" "$download_url" "$alt_url" >/dev/tty
      rm -rf "$tmp_dir"
      return 1
    fi
  fi

  printf "==> Đang giải nén và cài đặt vào %s/%s...\n" "$target_dir" "$cmd" >/dev/tty
  if [[ "$asset_file" == *.tar.gz || "$asset_file" == *.tgz ]]; then
    tar -xzf "$tmp_dir/$asset_file" -C "$tmp_dir"
  elif [[ "$asset_file" == *.zip ]]; then
    unzip -q "$tmp_dir/$asset_file" -d "$tmp_dir"
  fi

  # Find binary location inside extracted tree
  local extracted_bin=""
  if [[ -f "$tmp_dir/$bin_name" ]]; then
    extracted_bin="$tmp_dir/$bin_name"
  else
    extracted_bin="$(find "$tmp_dir" -type f -name "$bin_name" | head -n 1)"
  fi

  if [[ -z "$extracted_bin" || ! -f "$extracted_bin" ]]; then
    printf "${_TUI_RED}Lỗi: Không tìm thấy file thực thi '%s' trong gói đã giải nén.${_TUI_RESET}\n" "$bin_name" >/dev/tty
    rm -rf "$tmp_dir"
    return 1
  fi

  install -m 755 "$extracted_bin" "$target_dir/$cmd"
  rm -rf "$tmp_dir"

  printf "${_TUI_GREEN}${_TUI_BOLD}✔ Cài đặt thành công %s v%s vào %s/%s${_TUI_RESET}\n" "$cmd" "$ver" "$target_dir" "$cmd" >/dev/tty
}

_action_install() {
  local target_indices=()
  for ((i=0; i<item_count; i++)); do
    (( selected[i] )) && target_indices+=("$i")
  done

  if (( ${#target_indices[@]} == 0 )); then
    target_indices+=("$cursor")
  fi

  local apt_queue=()
  local gh_queue=()

  for idx in "${target_indices[@]}"; do
    local c="${cmds[idx]}"
    local pkg="${apt_pkgs[idx]}"
    local repo="${gh_repos[idx]}"

    if _is_in_apt "$pkg"; then
      apt_queue+=("$pkg")
    elif [[ -n "$repo" ]]; then
      gh_queue+=("$idx")
    else
      printf "${_TUI_RED}Gói '%s' không có trong APT và không có nguồn binary GitHub.${_TUI_RESET}\n" "$c" >/dev/tty
    fi
  done

  _tui_exit

  # 1. Standard APT flow (asks sudo password naturally)
  if (( ${#apt_queue[@]} > 0 )); then
    printf "\n${_TUI_CYAN}${_TUI_BOLD}=== CÀI ĐẶT QUA APT (HỆ THỐNG) ===${_TUI_RESET}\n"
    printf "Các gói sẽ cài đặt: ${_TUI_GREEN}%s${_TUI_RESET}\n\n" "${apt_queue[*]}"
    if _tui_confirm_prompt "Tiến hành chạy 'sudo apt update && sudo apt install'?" "Y"; then
      sudo apt update && sudo apt install -y "${apt_queue[@]}"
    fi
  fi

  # 2. Explicit Opt-in GitHub Binary Flow
  if (( ${#gh_queue[@]} > 0 )); then
    for g_idx in "${gh_queue[@]}"; do
      _install_from_github "${cmds[g_idx]}" "${gh_repos[g_idx]}" "${asset_fmts[g_idx]}" "${bin_names[g_idx]}" "${descs[g_idx]}"
    done
  fi

  printf "\n${_TUI_GRAY}Nhấn Enter để quay lại Sổ tay...${_TUI_RESET}"
  read -r _ </dev/tty || true
  _tui_enter
}

_action_update() {
  local target_indices=()
  for ((i=0; i<item_count; i++)); do
    (( selected[i] )) && target_indices+=("$i")
  done

  if (( ${#target_indices[@]} == 0 )); then
    target_indices+=("$cursor")
  fi

  _tui_exit
  local apt_updates=()

  for idx in "${target_indices[@]}"; do
    if (( statuses[idx] == 0 )); then
      printf "${_TUI_YELLOW}Bỏ qua '%s' vì chưa được cài đặt.${_TUI_RESET}\n" "${cmds[idx]}"
      continue
    fi

    local orig="${origins[idx]}"
    if [[ "$orig" == *"apt"* ]]; then
      apt_updates+=("${apt_pkgs[idx]}")
    elif [[ "$orig" == *"github"* && -n "${gh_repos[idx]}" ]]; then
      _install_from_github "${cmds[idx]}" "${gh_repos[idx]}" "${asset_fmts[idx]}" "${bin_names[idx]}" "${descs[idx]}"
    else
      printf "Công cụ '%s' thuộc nguồn '%s', không hỗ trợ tự động cập nhật.\n" "${cmds[idx]}" "$orig"
    fi
  done

  if (( ${#apt_updates[@]} > 0 )); then
    printf "\n==> Cập nhật các gói APT: %s...\n" "${apt_updates[*]}"
    sudo apt update && sudo apt --only-upgrade install -y "${apt_updates[@]}"
  fi

  printf "\n${_TUI_GRAY}Nhấn Enter để quay lại Sổ tay...${_TUI_RESET}"
  read -r _ </dev/tty || true
  _tui_enter
}

_action_delete() {
  local target_indices=()
  for ((i=0; i<item_count; i++)); do
    (( selected[i] )) && target_indices+=("$i")
  done

  if (( ${#target_indices[@]} == 0 )); then
    target_indices+=("$cursor")
  fi

  local to_delete=()
  for idx in "${target_indices[@]}"; do
    (( statuses[idx] == 1 )) && to_delete+=("$idx")
  done

  if (( ${#to_delete[@]} == 0 )); then
    _tui_exit
    printf "\n${_TUI_YELLOW}Không có công cụ nào đã cài đặt được chọn để gỡ bỏ.${_TUI_RESET}\n"
    sleep 1.2
    _tui_enter
    return 0
  fi

  _tui_exit
  local delete_names=()
  for idx in "${to_delete[@]}"; do delete_names+=("${cmds[idx]}"); done

  printf "\n${_TUI_RED}${_TUI_BOLD}=== XÁC NHẬN GỠ BỎ CÔNG CỤ ===${_TUI_RESET}\n"
  printf "Các công cụ sau sẽ bị gỡ bỏ: ${_TUI_YELLOW}%s${_TUI_RESET}\n" "${delete_names[*]}"

  if ! _tui_confirm_prompt "Bạn có chắc chắn muốn gỡ bỏ không?" "N"; then
    printf "Đã hủy thao tác gỡ bỏ.\n"
    sleep 1
    _tui_enter
    return 0
  fi

  for idx in "${to_delete[@]}"; do
    local c="${cmds[idx]}"
    local orig="${origins[idx]}"
    local p="${paths[idx]}"
    local pkg="${apt_pkgs[idx]}"

    if [[ "$orig" == *"github"* || "$p" == "$HOME/.local/bin/"* ]]; then
      rm -f "$p"
      printf "${_TUI_GREEN}✔ Đã xóa binary người dùng: %s${_TUI_RESET}\n" "$p"
    elif [[ "$orig" == *"apt"* ]]; then
      sudo apt remove -y "$pkg"
    else
      printf "${_TUI_YELLOW}Bỏ qua '%s': không thể gỡ tự động nguồn '%s'.${_TUI_RESET}\n" "$c" "$orig"
    fi
  done

  printf "\n${_TUI_GRAY}Nhấn Enter để quay lại Sổ tay...${_TUI_RESET}"
  read -r _ </dev/tty || true
  _tui_enter
}

_action_info() {
  local idx="$cursor"
  local c="${cmds[idx]}"
  local d="${descs[idx]}"
  local h="${homepages[idx]}"
  local s="NOT INSTALLED"
  (( statuses[idx] == 1 )) && s="INSTALLED"
  local v="${versions[idx]}"
  local o="${origins[idx]}"
  local p="${paths[idx]}"
  local apt_avail="Không có trong kho Debian/Ubuntu hiện tại"
  if _is_in_apt "${apt_pkgs[idx]}"; then
    apt_avail="Có sẵn trong APT (${apt_pkgs[idx]})"
  fi

  local lines=(
    "Tên lệnh      : $c"
    "Mô tả         : $d"
    "Trạng thái    : $s"
    "Phiên bản     : $v"
    "Nguồn quản lý : $o"
    "Đường dẫn cài : $p"
    "Kho lưu APT   : $apt_avail"
    "GitHub Repo   : ${gh_repos[idx]:-Không có (Native APT)}"
    "Trang chủ     : $h"
  )

  _tui_modal_box "HỒ SƠ CÔNG CỤ: $c" lines
}

# ==============================================================================
# MAIN TUI INTERACTIVE LOOP
# ==============================================================================
cursor=0
_tui_enter

while true; do
  _tui_clear
  _tui_draw_header "DOTFILES PACKAGE & TOOLS NOTEBOOK" "Sổ tay Quản lý & Cung ứng Công cụ Lập trình viên"

  # Table Column Header
  printf "   ${_TUI_BOLD}%-10s %-15s %-10s %-16s %s${_TUI_RESET}\n" "LỆNH" "TRẠNG THÁI" "PHIÊN BẢN" "NGUỒN CÀI" "MÔ TẢ" >/dev/tty
  printf "   ${_TUI_GRAY}%-10s %-15s %-10s %-16s %s${_TUI_RESET}\n" "──────────" "───────────────" "──────────" "────────────────" "──────────────────────────────" >/dev/tty

  # Render Rows
  for ((i=0; i<item_count; i++)); do
    mark=" "
    (( selected[i] )) && mark="x"

    status_str="${_TUI_GRAY}Not Installed${_TUI_RESET}"
    if (( statuses[i] )); then
      status_str="${_TUI_GREEN}Installed${_TUI_RESET}    "
    fi

    ver_str="${versions[i]}"
    origin_str="${origins[i]}"
    [[ "$origin_str" == "NONE" ]] && origin_str="${_TUI_GRAY}-${_TUI_RESET}"

    row_content="$(printf "[%s] %-8s %b %-10s %-16s %s" \
      "$mark" "${cmds[i]}" "$status_str" "$ver_str" "$origin_str" "${descs[i]}")"

    if (( i == cursor )); then
      printf " ${_TUI_GREEN}${_TUI_BOLD}>${_TUI_RESET} %b\n" "$row_content" >/dev/tty
    else
      printf "   %b\n" "$row_content" >/dev/tty
    fi
  done

  _tui_draw_footer "[↑/↓] Di chuyển  [Space] Chọn  [a] Tất cả  [i/Enter] Cài đặt  [u] Cập nhật  [d] Gỡ bỏ  [?] Chi tiết  [q/Esc] Thoát"

  action=""
  _tui_read_key action

  case "$action" in
    UP)
      if (( cursor > 0 )); then cursor=$((cursor - 1)); else cursor=$((item_count - 1)); fi
      ;;
    DOWN)
      if (( cursor < item_count - 1 )); then cursor=$((cursor + 1)); else cursor=0; fi
      ;;
    SPACE)
      selected[cursor]=$(( 1 - selected[cursor] ))
      ;;
    ALL)
      all_on=1
      for ((i=0; i<item_count; i++)); do
        (( selected[i] == 0 )) && { all_on=0; break; }
      done
      for ((i=0; i<item_count; i++)); do
        selected[i]=$(( 1 - all_on ))
      done
      ;;
    INSTALL|ENTER)
      _action_install
      _refresh_inventory
      ;;
    UPDATE)
      _action_update
      _refresh_inventory
      ;;
    DELETE)
      _action_delete
      _refresh_inventory
      ;;
    INFO)
      _action_info
      ;;
    QUIT|ESC)
      break
      ;;
  esac
done

_tui_exit
printf "\nĐã đóng Sổ tay Công cụ.\n"
