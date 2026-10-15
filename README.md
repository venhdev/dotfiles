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

## Git aliases

Installer adds `~/.config/dotfiles/.gitconfig_aliases` to global Git `include.path`, so aliases can be managed outside `~/.gitconfig`.

- `git lg` → latest 10 commits (or `git lg <count>`)
- `git lga` → full history

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/venhdev/dotfiles/main/uninstall.sh | bash
```
