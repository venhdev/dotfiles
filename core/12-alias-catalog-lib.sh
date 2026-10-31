#!/usr/bin/env bash
# ==============================================================================
# core/12-alias-catalog-lib.sh - Zen Alias Catalog & Directory Engine
# ==============================================================================
# Categorizes, formats, and searches dotfiles shortcuts and command aliases.
# ==============================================================================

_zen_alias_catalog() {
  local query="${1:-}"
  if [[ "$query" == "list" ]]; then
    query="${2:-}"
  fi

  local dotfiles_root
  if declare -F _get_dotfiles_root >/dev/null 2>&1; then
    dotfiles_root="$(_get_dotfiles_root)"
  else
    dotfiles_root="${DOTFILES:-${DOTFILES_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}}"
  fi
  local alias_file="$dotfiles_root/core/10-base-aliases.sh"

  if [[ ! -f "$alias_file" ]]; then
    echo "Error: Alias definition file not found at $alias_file" >&2
    return 1
  fi

  local c_reset="\033[0m"
  local c_green="\033[1;32m"
  local c_yellow="\033[1;33m"
  local c_cyan="\033[1;36m"
  local c_bold="\033[1m"
  local c_gray="\033[90m"

  printf "\n${c_bold}${c_cyan}=== ZEN SHORTCUT & ALIAS DIRECTORY ===${c_reset}\n"
  if [[ -n "$query" ]]; then
    printf "${c_gray}Filtering aliases matching: '${query}'${c_reset}\n\n"
  else
    printf "${c_gray}Authoritative registry of navigation, system, and dev aliases${c_reset}\n\n"
  fi

  awk -v q="$query" \
      -v cg="$c_green" -v cy="$c_yellow" -v cc="$c_cyan" -v cb="$c_bold" -v cgr="$c_gray" -v cr="$c_reset" '
  BEGIN {
    category = "General Navigation & Environment";
    has_matches = 0;
  }

  /^# [A-Z]/ {
    sub(/^# /, "");
    category = $0;
    next;
  }

  /^(alias|function) / || /^[a-zA-Z0-9_.-]+\(\)[[:space:]]*\{/ {
    line = $0;
    cmd = "";
    desc = "";

    if (line ~ /^alias /) {
      sub(/^alias /, "", line);
      split(line, parts, "=");
      cmd = parts[1];
      rest = parts[2];

      split(rest, subparts, "#");
      expansion = subparts[1];
      gsub(/^[ \t\047"]+|[ \t\047"]+$/, "", expansion);

      if (length(subparts) > 1) {
        desc = subparts[2];
        gsub(/^[ \t]+|[ \t]+$/, "", desc);
      }

      # Filter query
      target = tolower(category " " cmd " " expansion " " desc);
      if (q != "" && index(target, tolower(q)) == 0) {
        next;
      }

      if (curr_cat != category) {
        if (curr_cat != "") printf "\n";
        printf "%s┌─[ %s ]%s\n", cb, category, cr;
        curr_cat = category;
      }

      printf "  %s%-12s%s → %s%-32s%s", cg, cmd, cr, cy, expansion, cr;
      if (desc != "") {
        printf " %s# %s%s", cgr, desc, cr;
      }
      printf "\n";
      has_matches = 1;
    }
  }

  END {
    if (!has_matches) {
      printf "  %s(No aliases found matching query)%s\n", cgr, cr;
    }
    printf "\n";
  }
  ' "$alias_file"
}
