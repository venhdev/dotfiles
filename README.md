# Dotfiles

A fast, modular, zero-dependency dotfiles system for Linux and WSL with an interactive TUI installer and dynamic machine-specific configurations.

## Architecture

```text
dotfiles/
├── core/                        # Always loaded
│   ├── 00-shell-lib.sh          # Utilities (_confirm, _log_cmd, pickers)
│   ├── 10-base-aliases.sh       # Base aliases (nav, systemctl, safe apt)
│   ├── 20-editor-lib.sh         # Auto-detect or configured EDITOR
│   ├── 30-config-lib.sh         # Quick config opener (conf)
│   └── 40-info-lib.sh           # Diagnostics (sysinfo, envinfo)
├── modules/                     # Optional modules
│   ├── ssh/                     # SSH agent & auto-load key
│   ├── wsl/                     # Windows WSL integration (clip, winpath, explorer, wcp)
│   ├── mobile/                  # Flutter, Shorebird, Android ADB tools
│   ├── docker/                  # Docker CLI shortcuts (dps, dcl)
│   └── ai/                      # AI & Agent CLI helpers (Claude, OpenClaw, Skills)
├── enabled.d/                   # Symlinks to active modules (git-ignored)
└── local/                       # Machine-specific config (git-ignored)
    └── local.env                # Local environment variables (DOTFILES_SSH_INIT, etc.)
```

## Install / Update

### Interactive TUI Installation

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/install.sh | bash
```

**TUI Navigation & Controls:**
- `[↑/↓]` or `[j/k]`: Navigate options
- `[Space]`: Toggle selected module
- `[a]`: Toggle all modules
- `[Enter]`: Confirm and proceed to configuration
- `[q]` or `[Ctrl+C]`: Cancel installation

The installer will auto-detect sensible defaults (e.g. detecting WSL or scanning `~/.ssh/` for key candidates) and prompt for any dynamic module settings.

### Non-Interactive (Install All Modules)

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/install.sh | bash -s -- --all
```

If an existing checkout at `~/.config/dotfiles` has local changes that block a fast-forward pull, the installer asks whether to force the update. Choosing `yes` creates a stash, updates the checkout, and prints how to recover changes with:

```bash
git -C "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" stash pop
```

## Git Aliases

The installer adds `~/.config/dotfiles/.gitconfig` to global Git `include.path`:

- `git lg` → latest 10 commits (or `git lg <count>`, e.g. `git lg 5` or `git lg main`)
- `git lga` → full history
- `git inf` → quick branch status and remote summary

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/uninstall.sh | bash
```
