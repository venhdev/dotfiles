#!/usr/bin/env bash
# Flutter probes `<CHROME_EXECUTABLE> --version` while discovering devices.
# Windows Chrome does not support `--version` and would open a browser window,
# so answer the probe locally and forward every other invocation to real Chrome.
if [[ "${1:-}" == "--version" ]]; then
  printf 'Google Chrome (Windows)\n'
  exit 0
fi

exec "${DOTFILES_CHROME_EXECUTABLE:?DOTFILES_CHROME_EXECUTABLE is not set}" "$@"
