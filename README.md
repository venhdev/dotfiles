# Dotfiles

A fast, modular, zero-dependency dotfiles system for Linux, macOS, and Windows with interactive installers and dynamic machine-specific configurations.

## Architecture

```text
dotfiles/
├── core/                        # POSIX Shell Core (Linux, macOS, Git Bash)
│   ├── 00-platform-lib.sh       # OS detection (Linux/Darwin/MSYS/WSL) & shims (clip, open, pkg)
│   ├── 00-shell-lib.sh          # Utilities (_confirm, _log_cmd, pickers)
│   ├── 10-base-aliases.sh       # Base aliases (nav, systemctl/brew, safe package manager)
│   ├── 15-cmdlog-lib.sh         # Confirmed command audit log & rerun (clog, cr)
│   ├── 20-editor-lib.sh         # Auto-detect or configured EDITOR
│   ├── 30-config-lib.sh         # Quick config opener (conf)
│   └── 40-info-lib.sh           # Diagnostics (sysinfo, envinfo)
├── powershell/                  # Windows Native PowerShell Core
│   ├── profile.ps1              # Sourced by $PROFILE (Microsoft.PowerShell_profile.ps1)
│   └── core/                    # Platform shims, base aliases, cmdlog, cr, and conf
├── modules/                     # Optional modules
│   ├── ssh/                     # SSH agent & auto-load key
│   ├── wsl/                     # Windows WSL integration (clip, winpath, explorer, wcp)
│   ├── mobile/                  # Flutter, Shorebird, Android ADB tools
│   ├── docker/                  # Docker CLI shortcuts (dps, dcl)
│   └── ai/                      # AI & Agent CLI helpers (Claude, OpenClaw, Skills)
├── enabled.d/                   # Symlinks to active modules (git-ignored)
└── local/                       # Machine-specific config (git-ignored)
    ├── local.env                # Local environment variables for POSIX
    └── local.ps1                # Local environment settings for PowerShell
```

## Install / Update

### Linux, macOS & Git Bash (POSIX)

#### Interactive TUI Installation:
```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/install.sh | bash
```

**TUI Navigation & Controls:**
- `[↑/↓]` or `[j/k]`: Navigate options
- `[Space]`: Toggle selected module
- `[a]`: Toggle all modules
- `[Enter]`: Confirm and proceed to configuration
- `[q]` or `[Ctrl+C]`: Cancel installation

The installer auto-detects sensible defaults (e.g. detecting macOS Zsh vs Linux Bash, WSL, or scanning `~/.ssh/` for key candidates).

#### Non-Interactive (Install All Modules):
```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/install.sh | bash -s -- --all
```

---

### Windows (PowerShell Native)

Open PowerShell (Windows Terminal) and run:
```powershell
irm https://raw.githubusercontent.com/venhdev/dotfiles/main/install.ps1 | iex
```

This configures your PowerShell `$PROFILE` and global `.gitconfig` with native shims (`cmdlog`, `clog`, `cr`, `conf`, `clip`, `pkg`).

If an existing checkout at `~/.config/dotfiles` has local changes that block a fast-forward pull, the installer asks whether to force the update. Choosing `yes` creates a stash, updates the checkout, and prints how to recover changes with:

```bash
git -C "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" stash pop
```

## Git Aliases

The installer adds `~/.config/dotfiles/.gitconfig` to global Git `include.path`:

- `git lg` → latest 15 commits (or `git lg <count>`, e.g. `git lg 5` or `git lg main`)
- `git lga` → full history
- `git inf` → quick branch status and remote summary
- `git swr <branch>` → switch branch or track remote branch (accepts `origin/<branch>` or `<branch>`)

## Shell & History Helpers

- `h <keyword>` → grep command history
- `he [keyword] [limit]` → search and interactively execute recent command (default limit: 10, e.g. `he python` or `he python 5`)
- `clog [query] [limit]` → view confirmed command history (`clog -d` to filter by current `$PWD`)
- `cr [query|index]` → search/pick and rerun confirmed command (`cr -e` to edit before running)
- `conf` → interactive config file opener (`conf` or `conf <alias>`)

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/uninstall.sh | bash
```
