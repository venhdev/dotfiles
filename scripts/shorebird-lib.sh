# Shorebird helpers

_shorebird_preflight() {
  command -v shorebird &>/dev/null || {
    echo "❌ shorebird not found" >&2
    return 1
  }

  [[ -f shorebird.yaml ]] || {
    echo "❌ shorebird.yaml not found (chạy: shorebird init)" >&2
    return 1
  }

  [[ -f pubspec.yaml ]] || {
    echo "❌ pubspec.yaml not found (chạy ở project root)" >&2
    return 1
  }
}

# Top-level `version:` only, so `version:` under dependencies never matches.
_shorebird_version() {
  awk '
    /^version:[[:space:]]*/ {
      sub(/^version:[[:space:]]*/, "")
      sub(/[[:space:]]*#.*/, "")
      gsub(/[[:space:]"]/, "")
      print
      exit
    }
  ' pubspec.yaml
}

# _shorebird_pick <label> <default> <option>...
# Runs inside $(...), so the picked value goes to stdout and errors to stderr.
_shorebird_pick() {
  local label="$1" def="$2" v opt
  shift 2

  read -rp "$label ($*, Enter=$def): " v
  v="${v:-$def}"

  for opt in "$@"; do
    [[ $v == "$opt" ]] && { echo "$v"; return; }
  done

  echo "❌ $label phải là: $* (đã nhận: $v)" >&2
  return 1
}

# Appends to the caller's array, so it must not run inside $(...).
_shorebird_dart_args() {
  local -n out="$1"
  local flavor="$2" envfile

  if [[ -n $flavor ]]; then
    envfile=".env.$flavor"

    [[ -f $envfile ]] || {
      echo "❌ Missing env file: $envfile" >&2
      return 1
    }
  else
    envfile=".env"
  fi

  [[ -f $envfile ]] && out+=(--dart-define-from-file="$envfile")
  return 0
}