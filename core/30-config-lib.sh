# Config helpers

conf() {
  local dotfiles="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

  local -A m=(
    [bashrc]="$HOME/.bashrc"
    [zshrc]="${ZDOTDIR:-$HOME}/.zshrc"
    [platform]="$dotfiles/core/00-platform-lib.sh"
    [ali]="$dotfiles/core/10-base-aliases.sh"
    [localenv]="$dotfiles/local/local.env"
    [ssh]="$HOME/.ssh/config"
    [env]="$HOME/.env"
    [profile]="/etc/profile"
    [pwprofile]="$dotfiles/powershell/profile.ps1"
    [git]="$HOME/.gitconfig"
    [gitdot]="$dotfiles/.gitconfig"
    [claude]="$HOME/.claude/settings.json"
    [codex]="$HOME/.codex/config.toml"
    [docker]="$HOME/.docker/config.json"
    [oc]="$HOME/.openclaw/openclaw.json"
    [opencode]="$HOME/.config/opencode/opencode.json"
    [cmdlog]="$dotfiles/core/15-cmdlog-lib.sh"
    [clog]="$dotfiles/core/15-cmdlog-lib.sh"
  )

  local f k="${1:-}" x l

  for f in "$dotfiles"/core/*.sh "$dotfiles"/modules/*/*.sh "$HOME"/bin/*.sh; do
    [[ -e $f ]] && m[$(basename "$f" .sh)]="$f"
  done

  if [[ -z $k ]]; then
    local lines=()

    for x in "${!m[@]}"; do
      lines+=("$(printf '%-10s %s' "$x" "${m[$x]}")")
    done

    mapfile -t lines < <(printf '%s\n' "${lines[@]}" | sort)

    if command -v fzf &>/dev/null; then
      k=$(printf '%s\n' "${lines[@]}" |
        fzf --prompt='Config > ' |
        awk '{print $1}') || return
    else
      select l in "${lines[@]}"; do
        [[ -n $l ]] && { k=${l%% *}; break; }
      done
    fi
  fi

  [[ -n ${m[$k]:-} ]] || {
    echo "Unknown: $k" >&2
    return 1
  }

  "$EDITOR" "${m[$k]}"
}
