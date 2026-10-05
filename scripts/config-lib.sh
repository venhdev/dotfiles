# Config helpers

conf() {
  local dotfiles="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

  local -A m=(
    [bashrc]="$HOME/.bashrc"
    [alidev]="$dotfiles/.dev_aliases"
    [aliwin]="$dotfiles/.win_aliases"
    [ssh]="$HOME/.ssh/config"
    [env]="$HOME/.env"
    [profile]="/etc/profile"
    [git]="$HOME/.gitconfig"
    [claude]="$HOME/.claude/settings.json"
    [codex]="$HOME/.codex/config.toml"
    [docker]="$HOME/.docker/config.json"
    [oc]="$HOME/.openclaw/openclaw.json"
    [opencode]="$HOME/.config/opencode/opencode.json"
  )

  local f k="${1:-}" x l

  for f in "$dotfiles"/scripts/*.sh "$HOME"/bin/*.sh; do
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

autoremove() {
  sudo apt autoremove --dry-run

  read -rp "Continue? [y/N] " r
  [[ $r =~ ^[Yy]$ ]] &&
    sudo apt autoremove ||
    echo "Cancelled"
}
