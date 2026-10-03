# System info helpers

sysinfo() {
  echo "=== OS Information ==="
  cat /etc/os-release

  echo
  echo "=== Architecture ==="
  uname -m

  echo
  echo "=== Memory Usage ==="
  free -h

  echo
  echo "=== Disk Usage ==="
  df -h
}

envinfo() {
  echo "=== System ==="
  echo "OS:      $(uname -s)"
  echo "Kernel:  $(uname -r)"
  echo "Arch:    $(uname -m)"

  echo
  echo "=== Node ==="
  echo "Node:    $(node -v 2>/dev/null || echo N/A)"
  echo "npm:     $(npm -v 2>/dev/null || echo N/A)"
  echo "pnpm:    $(pnpm -v 2>/dev/null || echo N/A)"
  echo "yarn:    $(yarn -v 2>/dev/null || echo N/A)"
  echo "nvm:     $(nvm --version 2>/dev/null || echo N/A)"

  echo
  echo "=== Languages ==="
  echo "Python:  $(python3 --version 2>/dev/null || echo N/A)"
  echo "Go:      $(go version 2>/dev/null || echo N/A)"
  echo "Java:    $(java -version 2>&1 | head -n 1 || echo N/A)"

  echo
  echo "=== Containers ==="
  echo "Docker:  $(docker --version 2>/dev/null || echo N/A)"
  echo "Compose: $(docker compose version 2>/dev/null || echo N/A)"

  echo
  echo "=== Git ==="
  echo "Git:     $(git --version 2>/dev/null || echo N/A)"

  echo
  echo "=== Editors / Tools ==="
  echo "VSCode:  $(code --version 2>/dev/null | head -n 1 || echo N/A)"
  echo "curl:    $(curl --version 2>/dev/null | head -n 1 || echo N/A)"
}
