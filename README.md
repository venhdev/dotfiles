# Dotfiles

A fast, modular, zero-dependency dotfiles system for Linux, macOS, and Windows with interactive installers, native PowerShell integration, and dynamic machine-specific configurations.

---

## Quick Reference & Table of Contents

1. [Installation & Reload](#1-installation--reload)
2. [Navigation & History Search](#2-navigation--history-search)
3. [Command Audit Log & Smart Re-run (clog, cr)](#3-command-audit-log--smart-re-run-clog-cr)
4. [Configuration & Editor Management (conf, e)](#4-configuration--editor-management-conf-e)
5. [Cross-Platform Clipboard & File Opener (clip, open_target)](#5-cross-platform-clipboard--file-opener-clip-open_target)
6. [Universal Package Manager (pkg)](#6-universal-package-manager-pkg)
7. [Windows & WSL Host Management](#7-windows--wsl-host-management)
8. [Advanced Git Workflow & Aliases](#8-advanced-git-workflow--aliases)
9. [System Diagnostics & Networking (sysinfo, envinfo)](#9-system-diagnostics--networking-sysinfo-envinfo)
10. [Developer Toolchain: Mobile & Docker](#10-developer-toolchain-mobile--docker)
11. [AI & Coding Agent CLI Helpers](#11-ai--coding-agent-cli-helpers)
12. [Architecture & Directory Structure](#12-architecture--directory-structure)
13. [Uninstallation](#13-uninstallation)

---

## 1. Installation & Reload

### 🐧 Linux, macOS & Git Bash (POSIX)

#### Interactive TUI Installation:
```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/install.sh | bash
```
- **TUI Controls:** `[↑/↓]` or `[j/k]` to navigate, `[Space]` to toggle selection, `[a]` to toggle all, `[Enter]` to confirm, `[q]` to cancel.
- **Auto-Detection:** Automatically detects Zsh vs. Bash, WSL environment, SSH keys in `~/.ssh/`, and automatically hooks PowerShell `$PROFILE` when installing from Git Bash on Windows.

#### Automated Non-Interactive Installation (All Modules):
```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/install.sh | bash -s -- --all
```

---

### 🪟 Windows (Native PowerShell)

Open PowerShell (Windows Terminal) and run:
```powershell
irm https://raw.githubusercontent.com/venhdev/dotfiles/main/install.ps1 | iex
```
This configures your PowerShell `$PROFILE`, prepends `~/bin` & `~/.local/bin` to `$env:PATH`, and configures global Git `include.path`.

---

### 🔄 Reload Shell Configuration

`🏷️ [Cross-Platform]` **`rel`**
Automatically detects the active shell and reloads configuration instantly (supports Zsh, Bash, and PowerShell):
```bash
rel
# On Bash       -> reloads ~/.bashrc
# On Zsh        -> reloads ~/.zshrc
# On PowerShell -> reloads $PROFILE
```

---

### 🚀 Installer & Maintenance Shortcuts

`🏷️ [Cross-Platform]` **`insdf [modules...]`**
Re-runs the dotfiles installer to update the repository, configure shell profile hooks, or install extensions:
- **On POSIX (Bash/Zsh)**: Executes `install.sh [modules...]`
- **On Windows (PowerShell)**: Executes `install.ps1` (or delegates to `install.sh` when specific modules are passed and `bash.exe` is present)

Convenient module shortcuts:
- `instools` → Install common CLI tools (git, curl, jq, rg)
- `insssh` → Configure SSH agent and keys
- `inswsl` → Configure WSL interop tools
- `insmobile` → Configure Flutter, Shorebird, and Android ADB
- `insdocker` → Configure Docker shortcuts
- `insai` → Configure AI agent CLI helpers
- `insgit` → Configure global Git aliases (`include.path`)

---

## 2. Navigation & History Search

### 🔍 Command History Search: `h`

`🏷️ [Cross-Platform]` **`h [query] [limit]`**
Fast, bounded command history search (default limit: 10 lines) preventing terminal buffer overflows. Operates identically across Bash, Zsh, and PowerShell (reading from PSReadLine persistent history).

```bash
# 1. View latest 10 commands
h

# 2. View custom number of commands (e.g. 20)
h 20

# 3. Filter by keyword (defaults to 10 latest results)
h flutter
h git
h docker

# 4. Filter by keyword with custom limit
h flutter 5     # Latest 5 flutter commands
h "git commit" 3
```

---

### 📂 Directory Navigation & File Operations

`🏷️ [Cross-Platform]`
- `..` → Move up 1 directory (`cd ..`)
- `...` → Move up 2 directories (`cd ../..`)
- `....` → Move up 3 directories (`cd ../../..`)
- `--` → Return to previous directory (`cd -`) `[POSIX]`
- `ll` → Detailed file listing
- `la` → Detailed file listing including hidden files
- `cl` → Clear terminal screen

---

### 📊 Directory Disk Usage: `dirsize` / `ds`

`🏷️ [Cross-Platform]` **`dirsize [path] [limit]`** (Alias: **`ds`**)
Fast subfolder storage analyzer listing immediate subdirectories sorted descending by disk space:
- **Windows (PowerShell)**: High-speed multi-threaded Robocopy kernel scan (`/NFL /NDL /XJ /R:0 /W:0`) avoiding NTFS junction loops and deep `.NET` object allocation overhead. Auto-parallelized across 8 threads on PowerShell 7+.
- **Linux / macOS (POSIX)**: High-speed `du` scan sorted numerically with automatic human-readable unit scaling (B, KB, MB, GB).

```bash
# Analyze subdirectories in current working directory
ds

# Analyze a specific path
ds D:\Develop
ds /var/log

# Limit output to top N largest folders
ds 5
ds /var/log 10
```

---

## 3. Command Audit Log & Smart Re-run

The **Confirmed Command Audit Log** records critical command executions, exit codes, elapsed durations, and working directories in `~/.config/dotfiles/.cmdlog`.

### 📜 View Command Audit Log: `clog`

`🏷️ [Cross-Platform]` **`clog [options] [query] [limit]`**

```bash
# View latest 10 executed commands from audit log
clog

# View latest 20 commands
clog 20

# Filter by keyword
clog flutter
clog deploy 5

# View commands executed within current directory only ($PWD)
clog -d
clog -d 5
```

---

### ⚡ Smart Command Re-run: `cr`

`🏷️ [Cross-Platform]` **`cr [options] [query|index]`**

```bash
# 1. Open interactive picker (fzf if available) to select and re-run
cr

# 2. Re-run immediately by chronological index
cr 1          # Re-run latest logged command
cr 2          # Re-run second latest command

# 3. Search by keyword and select
cr git
cr build

# 4. Open command in $EDITOR to inspect or edit before execution
cr -e 1
cr -e flutter

# 5. Restrict selection to commands executed in current directory ($PWD)
cr -d
cr -d 1
```

---

### 🛡️ Wrap & Audit Critical Commands: `cmdlog wrap`

`🐧 [POSIX]` **`cmdlog wrap <command...>`**
Prompts for interactive confirmation `[y/N]`, benchmarks execution time, and logs the result:
```bash
cmdlog wrap npm run build:prod
cmdlog wrap docker compose down -v
```

---

## 4. Configuration & Editor Management

### ⚙️ Quick Configuration Opener: `conf`

`🏷️ [Cross-Platform]` **`conf [target]`**
Quickly open essential configuration files in your default editor (supports interactive fuzzy matching via `fzf`):

```bash
# Open interactive configuration menu
conf

# Open specific configuration targets directly:
conf profile     # Shell startup profile (.bashrc / .zshrc / $PROFILE)
conf env         # Personal environment variables (~/.env)
conf git         # Personal Git configuration (~/.gitconfig)
conf gitdot      # Dotfiles Git configuration (.gitconfig)
conf ssh         # SSH configuration (~/.ssh/config)
conf claude      # Claude Code settings (settings.json)
conf localenv    # Machine-specific overrides (local.env / local.ps1)

# Windows specific:
conf sysenv      # Opens Windows "System Environment Variables" dialog (sysdm.cpl)
```

---

### 📝 Editor & Environment Inspection

- **`e <file>`** `🏷️ [Cross-Platform]`: Open file in default `$EDITOR` (auto-detected in priority order: `code` / `micro` → `nvim` → `nano` → `notepad` / `vim`).
- **`set_editor [name]`** `🏷️ [Cross-Platform]`: Select or directly set and persist default `$EDITOR` across sessions (e.g. `set_editor`, `set_editor notepad`, `set_editor code`, `set_editor nvim`).
- **`gete <VAR_NAME>`** `[PowerShell]`: Inspect environment variable values across `Process`, `User`, and `Machine` scopes simultaneously.
  ```powershell
  gete PATH
  gete JAVA_HOME
  ```
- **`ep`** `[PowerShell]`: Shortcut for `conf profile`.

---

## 5. Cross-Platform Clipboard & File Opener

### 📋 Universal System Clipboard: `clip`

`🏷️ [Cross-Platform]` **`clip`**
A single clipboard utility that works consistently across every environment:
- macOS: native `pbcopy` / `pbpaste`
- WSL: automatically calls Windows `clip.exe`
- Native Linux: automatically selects `wl-copy` (Wayland), `xclip`, or `xsel` (X11)
- Windows PowerShell: native `Set-Clipboard` / `Get-Clipboard`

```bash
# Copy piped data into clipboard:
echo "secret_api_key" | clip
cat ~/.ssh/id_ed25519.pub | clip

# Paste data from clipboard to terminal:
clip
clip > copied_code.txt
```

---

### 🚀 Default App & URL Opener: `open_target`

`🏷️ [Cross-Platform]` **`open_target [path|url]`**
Launches targets using the operating system's default handler (`open` on macOS, `explorer.exe` on WSL/Windows, `xdg-open` on Linux):

```bash
open_target .                     # Open current directory in File Explorer / Finder
open_target document.pdf          # Open PDF with default system reader
open_target https://github.com    # Open URL in default browser
```

---

## 6. Universal Package Manager

`🏷️ [Cross-Platform]` **`pkg <action> [package]`**
Standardized CLI interface abstracting underlying package managers (`apt`, `brew`, `pacman`, `dnf`, `winget`, `scoop`, `choco`):

```bash
# 1. Refresh repository indexes
pkg update

# 2. Upgrade all installed packages
pkg upgrade

# 3. Install a new package
pkg install ripgrep
pkg install jq

# 4. Uninstall a package
pkg remove jq

# 5. Search for packages
pkg search python
```

---

## 7. Windows & WSL Host Management

### 🐧 Commands Inside WSL (Linux Subsystem)

- **`winpath [path]`**: Convert Linux path to Windows path format:
  ```bash
  winpath .
  # Output: C:\Users\YourName\projects\my-app
  ```
- **`opene [dir]`**: Open current or specified Linux directory directly in **Windows File Explorer**:
  ```bash
  opene
  opene /var/log
  ```
- **`gete`**: Retrieve path from active Windows File Explorer window and print or navigate to it.
- **`wcp <src> <dst>`**: Fast file copy between Linux and Windows filesystems.
- **`powershell`**: Execute Windows PowerShell directly from WSL terminal.

---

### 🪟 WSL Management from Windows Host (PowerShell as Admin)

- **`wslcompact [path]`**: Safe compaction and disk reclamation for WSL virtual disks (`ext4.vhdx`):
  - Automatically discovers `ext4.vhdx` instances across standard WSL locations.
  - Checks running instances and prompts for a graceful shutdown (`wsl --shutdown`).
  - Utilizes `Optimize-VHD` (Hyper-V) or `diskpart` to reclaim tens of gigabytes of disk space.
  ```powershell
  # Run in PowerShell (Administrator):
  wslcompact
  ```

---

## 8. Advanced Git Workflow & Aliases

Global Git aliases configured via `include.path` (`~/.config/dotfiles/.gitconfig`):

| Command | Description | Example |
| :--- | :--- | :--- |
| `git lg [n\|branch]` | Compact commit graph (default: 15 commits) | `git lg`<br>`git lg 5`<br>`git lg main` |
| `git lga` | Complete commit graph across all branches | `git lga` |
| `git inf` | Summary of current branch, remote tracking, unpushed/unpulled commits | `git inf` |
| `git swr <branch>` | Switch branch or auto-track remote branch if not present locally | `git swr feature-auth`<br>`git swr origin/feat-login` |
| `git unstage [files]` | Remove files from staging area | `git unstage src/index.ts` |
| `git undo` | Undo last commit while preserving staged changes | `git undo` |
| `git br` | List branches | `git br -a` |
| `git co <branch>` | Checkout branch | `git co main` |
| `git ci` | Git commit | `git ci -m "feat: login"` |
| `git st` | Short status summary | `git st` |

---

## 9. System Diagnostics & Networking

### 🖥️ System & Toolchain Inspection

- **`sysinfo`** `[POSIX]`: Summary of hardware specs: CPU, available RAM, disk usage, Kernel, and Uptime.
- **`envinfo`** `[POSIX]`: Full developer toolchain audit (OS, Distro, Kernel, Node, npm, pnpm, Python, Go, Rust, Java, Docker, Git) with safe TTL timeouts.

```bash
sysinfo
envinfo
```

---

### 🌐 Network & Process Monitoring

- **`myip`** `[POSIX]` / **`curlip`** `[PowerShell]`: Query public IP address.
- **`ports`** `[POSIX]`: View all active listening TCP/UDP ports (`ss -tulpn`).
- **`portss <port>`** `[POSIX]`: Identify which process is listening on a specific port:
  ```bash
  portss 3000
  portss 8080
  ```
- **`psmem`** `[POSIX]`: View top 10 processes consuming memory.
- **`pscpu`** `[POSIX]`: View top 10 processes consuming CPU.
- **`va`** / **`vd`** `[PowerShell]`: Activate (`va`) or Deactivate (`vd`) Python virtual environments (`.venv`, `venv`, `env`).

---

## 10. Developer Toolchain: Mobile & Docker

### 📱 Mobile Development (Flutter, Shorebird & Android)

When the `mobile` module is enabled:
- **Flutter Shortcuts**:
  - `fl` → `flutter`
  - `flr` → `flutter run`
  - `flb` → `flutter build`
  - `fld` → `flutter doctor`
  - `flpub` → `flutter pub get`
  - `flclean` → `flutter clean`
- **Shorebird Shortcuts**:
  - `sb` → `shorebird`
  - `sbr` → `shorebird run`
  - `sbrp` → `shorebird release`
- **Android ADB Shortcuts**:
  - `adbd` → `adb devices`
  - `adbl` → `adb logcat`
  - `adbi` → `adb install`

---

### 🐳 Docker & DevOps Shortcuts

When the `docker` module is enabled:
- **`dps`**: Formatted active container table (ID, Names, Status, Ports).
- **`dpsa`**: Formatted table of all containers (including stopped).
- **`dcl`**: Thorough system cleanup (`docker system prune -a --volumes`).

---

## 11. AI & Coding Agent CLI Helpers

When the `ai` module is enabled:
- **`clpp`** / **`claudebypass`**: Launch Claude Code with auto-approved execution permissions (`--dangerously-skip-permissions`).
- **`ski`**: Add skills using Skills CLI (`npx skills add`).
- **`skiv`**: Add personal skill repository (`npx skills add venhdev/skills`).
- **`skiu`**: Remove skills (`npx skills remove`).
- **`ocwatch`** / **`ocstop`**: Start or Stop OpenClaw Gateway.

---

## 12. Architecture & Directory Structure

```text
dotfiles/
├── install.sh                       # POSIX Interactive TUI & Non-Interactive Installer
├── install.ps1                      # Windows Native PowerShell Installer
├── uninstall.sh                     # POSIX Uninstaller & Cleaner
├── core/                            # POSIX Shell Core (Linux, macOS, Git Bash)
│   ├── 00-platform-lib.sh           # SSOT OS detection & shims (clip, open, pkg, rel)
│   ├── 00-shell-lib.sh              # Shell utilities (_confirm, _log_cmd, showfunc, portss)
│   ├── 10-base-aliases.sh           # Navigation, safe defaults, ports, and 'h' history search
│   ├── 15-cmdlog-lib.sh             # Confirmed command audit log & rerun engine (clog, cr)
│   ├── 20-editor-lib.sh             # Editor detection ($EDITOR) & picker (e, set_editor)
│   ├── 30-config-lib.sh             # Config file opener (conf)
│   └── 40-info-lib.sh               # Diagnostics & toolchain inspection (sysinfo, envinfo)
├── powershell/                      # Windows Native PowerShell Engine
│   ├── profile.ps1                  # Sourced by $PROFILE (PATH setup, ~/.env loader, rel)
│   └── core/
│       ├── 00-PlatformShims.ps1     # Platform shims ($global:IsWindowsHost, clip, open_target, pkg, sudo)
│       ├── 10-BaseAliases.ps1       # Base aliases, PSReadLine history (h), env inspection (gete), venv
│       ├── 15-CmdLog.ps1            # PowerShell Confirmed Command Audit Log (clog, cr)
│       ├── 20-WslHost.ps1           # Host WSL management & VHDX compaction (wslcompact, gete)
│       └── 30-Config.ps1            # Config opener and editor tools (conf, set_editor, e)
├── modules/                         # Optional Modular Extensions
│   ├── ssh/module.sh                # SSH agent auto-start & key loader (ssha)
│   ├── wsl/module.sh                # Windows/WSL interop (clip, explorer, winpath, opene, gete, wcp)
│   ├── mobile/                      # Flutter, Shorebird, and Android ADB helpers
│   ├── docker/module.sh             # Docker & Compose shortcuts (dps, dpsa, dcl)
│   └── ai/module.sh                 # AI agent CLI helpers (Claude, Skills CLI, OpenClaw)
├── scripts/
│   └── install-tools.sh             # Common CLI tools installer (git, curl, jq, rg via apt)
├── enabled.d/                       # Symlinks to active modules (git-ignored)
└── local/                           # Machine-specific overrides (git-ignored)
    ├── local.env                    # Local environment variables for POSIX
    └── local.ps1                    # Local environment settings for PowerShell
```

---

## 13. Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/uninstall.sh | bash
```
