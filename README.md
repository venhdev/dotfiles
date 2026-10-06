# Dotfiles

## Install / Update

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/install.sh | bash
```

If an existing checkout at `~/.config/dotfiles` has local changes that block a fast-forward pull, the installer asks whether to force the update. Choosing `yes` creates a stash (including untracked files), updates the checkout, and prints how to recover your local changes with:

```bash
git -C "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" stash pop
```

In non-interactive environments where prompting is not possible, the installer exits with a clear error instead of forcing or hanging.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/uninstall.sh | bash
```
