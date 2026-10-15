# SSH helpers

SSH_INIT="${DOTFILES_SSH_INIT:-$HOME/.ssh/id_ed25519}"

ssha() {
  [[ -z $SSH_AUTH_SOCK ]] && eval "$(ssh-agent -s)" >/dev/null

  local keys=() k
  mapfile -t keys < <(
    find "$HOME/.ssh" -maxdepth 1 -type f \
      \( -name '*_ed25519' -o -name '*_rsa' \) 2>/dev/null
  )

  ((${#keys[@]})) || { echo "No SSH keys found"; return 1; }

  local PS3="SSH key: "
  select k in "${keys[@]}"; do
    [[ -n $k ]] && { ssh-add "$k"; return; }
  done
}

if [[ -n $SSH_INIT && -f $SSH_INIT ]]; then
  [[ -z $SSH_AUTH_SOCK ]] && eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$SSH_INIT" &>/dev/null
fi

