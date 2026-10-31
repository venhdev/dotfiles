# Docker & DevOps shortcuts

alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Safe prune (images, containers, build cache) - preserves database volumes
alias dcl='docker system prune -a'

# Interactive dangerous prune - requires confirmation before wiping volumes
dcl_hard() {
  echo "⚠️  WARNING: This will permanently delete ALL unused containers, networks, images, and VOLUMES."
  echo "   All local database data not mounted to a running container will be lost!"
  if command -v _confirm >/dev/null 2>&1; then
    _confirm "Are you absolutely sure you want to prune all volumes? [y/N] " || { echo "Aborted."; return 1; }
  else
    read -rp "Are you absolutely sure you want to prune all volumes? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
  fi
  docker system prune -a --volumes
}
