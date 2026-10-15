# Mobile development helpers (ADB, Flutter, Shorebird)

# --- ADB helpers ---

_adb_devices() {
  adb devices -l | awk '
    NR>1 && NF {
      m="?"
      for(i=3;i<=NF;i++)
        if($i~/^model:/) { m=substr($i,7); break }
      print $1 "\t" $2 "\t" m
    }'
}

_adb_model() {
  _adb_devices |
    awk -F'\t' -v s="$1" '$1==s {print $3; exit}'
}

_adb_pick_devices() {
  local items=() picked s state model

  while IFS=$'\t' read -r s state model; do
    [[ $state == device ]] && items+=("$s | $model")
  done < <(_adb_devices)

  mapfile -t picked < <(_pick_many "📱 Select device(s):" "${items[@]}")

  for s in "${picked[@]}"; do
    echo "${s%% | *}"
  done
}

_adb_pick_apks() {
  local dir="${1:-build/app/outputs/flutter-apk}" filter="${2:-}"
  local apks=() f

  for f in "$dir"/*.apk; do
    [[ -e $f && ( -z $filter || $f == *"$filter"* ) ]] &&
      apks+=("$f")
  done

  _pick_many "📦 Select APK(s):" "${apks[@]}"
}

adbls() {
  while IFS=$'\t' read -r s state model; do
    printf "%-24s %-8s %s\n" "$s" "$state" "$model"
  done < <(_adb_devices)
}

adbid() {
  local targets apks t apk m ok=0 fail=0

  mapfile -t targets < <(_adb_pick_devices)
  ((${#targets[@]})) || { echo "❌ No device"; return 1; }

  mapfile -t apks < <(_adb_pick_apks "${1:-}" "${2:-}")
  ((${#apks[@]})) || { echo "❌ No APK"; return 1; }

  echo
  for t in "${targets[@]}"; do
    m=$(_adb_model "$t")
    for apk in "${apks[@]}"; do
      echo "▶ [$m] adb -s $t install -r $apk"
    done
  done

  _confirm || { echo "✗ cancelled"; return 1; }

  for t in "${targets[@]}"; do
    m=$(_adb_model "$t")
    echo "── $t | $m ──"

    for apk in "${apks[@]}"; do
      _log_cmd adb -s "$t" install -r "$apk"
      adb -s "$t" install -r "$apk" &&
        ((++ok)) || ((++fail))
    done
  done

  echo
  echo "✅ $ok ok, ❌ $fail failed"
  ((fail == 0))
}

# --- Flutter helpers ---

_flutter_devices() {
  fvm flutter devices --machine |
    jq -r '.[] | [.id, .name] | @tsv'
}

_flutter_pick_device() {
  local items=() id name picked

  while IFS=$'\t' read -r id name; do
    items+=("$name | $id")
  done < <(_flutter_devices)

  picked=$(_pick_one "Device: " "${items[@]}") || return
  echo "${picked##* | }"
}

_flutter_flavors() {
  local file

  for file in android/app/build.gradle android/app/build.gradle.kts; do
    [[ -f $file ]] || continue

    awk '
      /productFlavors[[:space:]]*\{/ { on=1; depth=1; next }

      on {
        line=$0

        if(depth==1) {
          s=line
          sub(/^[[:space:]]*/, "", s)

          if(s ~ /^create\("[^"]+"\)/) {
            sub(/^create\("/, "", s)
            sub(/".*/, "", s)
            print s
          }
          else if(s ~ /^[A-Za-z0-9_]+[[:space:]]*\{/) {
            sub(/[[:space:]]*\{.*/, "", s)
            print s
          }
        }

        o=gsub(/\{/,"{",line)
        c=gsub(/\}/,"}",line)
        depth+=o-c

        if(depth<=0) exit
      }
    ' "$file"

    return
  done
}

_flutter_pick_flavor() {
  local flavors=() f
  mapfile -t flavors < <(_flutter_flavors)

  if ((${#flavors[@]})); then
    f=$(_pick_one "Flavor: " "${flavors[@]}" skip) || return
    [[ $f != skip ]] && echo "$f"
  else
    read -rp "Flavor (skip=Enter): " f
    [[ -n $f ]] && echo "$f"
  fi

  return 0
}

_flutter_pick_mode() {
  local PS3="Mode: " mode

  select mode in debug profile release; do
    echo "${mode:-debug}"
    return
  done
}

# Default to keeping the full icon font: a tree-shaken icon font differs between
# builds, which shows up as an asset diff in diffing tools (e.g. Shorebird patch).
_flutter_icon_args() {
  local -n out="$1"

  if _confirm "no-tree-shake-icons? [Y/n] "; then
    out+=(--no-tree-shake-icons)
  fi
}

_flutter_args() {
  local -n out="$1"
  local f flavor mode

  read -rp "dart-define-from-file (skip=Enter): " f
  [[ -n $f ]] && out+=(--dart-define-from-file="$f")

  flavor=$(_flutter_pick_flavor) || return
  [[ -n $flavor ]] && out+=(--flavor="$flavor")

  mode=$(_flutter_pick_mode) || return
  out+=("--$mode")
}

flr() {
  local device args=() cmd

  device=$(_flutter_pick_device) ||
    { echo "❌ No device"; return 1; }

  _flutter_args args || return

  cmd=(fvm flutter run -d "$device" "${args[@]}")
  _run_confirm "${cmd[@]}"
}

flb() {
  local target="${1:-apk}" args=() cmd

  _flutter_icon_args args || return
  _flutter_args args || return

  cmd=(fvm flutter build "$target" "${args[@]}")
  _run_confirm "${cmd[@]}"
}

# --- Shorebird helpers ---

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

sbr() {
  local dry_run=0
  local artifact current flavor
  local cmd=() args=()

  [[ ${1:-} == -n ]] && dry_run=1

  _shorebird_preflight || return
  command -v fvm &>/dev/null || {
    echo "❌ fvm not found (cần cho --flutter-version=fvm)" >&2
    return 1
  }

  current=$(_shorebird_version)
  [[ -n $current ]] || {
    echo "❌ version: not found in pubspec.yaml" >&2
    return 1
  }
  echo "Version: $current"

  artifact=$(_shorebird_pick Artifact apk aab apk) || return
  flavor=$(_flutter_pick_flavor) || return
  _flutter_icon_args args || return

  cmd=(shorebird release android --flutter-version=fvm --artifact "$artifact")
  ((dry_run)) && cmd+=(--dry-run)
  [[ -n $flavor ]] && cmd+=(--flavor "$flavor")

  _shorebird_dart_args args "$flavor" || return
  cmd+=(-- "${args[@]}")

  _run_confirm "${cmd[@]}"
}

sbp() {
  local dry_run=0
  local track current flavor
  local cmd=() args=()

  [[ ${1:-} == -n ]] && dry_run=1

  _shorebird_preflight || return

  current=$(_shorebird_version)
  [[ -n $current ]] || {
    echo "❌ version: not found in pubspec.yaml" >&2
    return 1
  }

  track=$(_shorebird_pick Track staging staging stable) || return
  flavor=$(_flutter_pick_flavor) || return
  _flutter_icon_args args || return

  cmd=(shorebird patch android --track "$track" --release-version "$current")
  ((dry_run)) && cmd+=(--dry-run)
  [[ -n $flavor ]] && cmd+=(--flavor "$flavor")

  _shorebird_dart_args args "$flavor" || return
  cmd+=(-- "${args[@]}")

  _run_confirm "${cmd[@]}"
}
