# Editor helpers

if command -v micro &>/dev/null; then
  export EDITOR=micro
elif command -v nano &>/dev/null; then
  export EDITOR=nano
elif command -v nvim &>/dev/null; then
  export EDITOR=nvim
else
  export EDITOR=vim
fi

export VISUAL="$EDITOR"

e() {
  "$EDITOR" "$@"
}

set_editor() {
  local editors=(micro nvim vim nano)
  local PS3="Editor: " choice

  select choice in "${editors[@]}"; do
    if [[ -n $choice ]] && command -v "$choice" &>/dev/null; then
      export EDITOR="$choice"
      export VISUAL="$choice"
      echo "EDITOR set to: $EDITOR"
      return
    fi

    echo "Invalid selection or editor not found."
  done
}
