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

# Flutter web browser integration
if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
  for _c in \
    "${DOTFILES_CHROME_EXECUTABLE:-}" \
    "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
    "$HOME/.local/bin/chrome"; do
    if [[ -n "$_c" && -x "$_c" ]]; then
      export CHROME_EXECUTABLE="$_c"
      break
    fi
  done
  unset _c
fi

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
  local platform="${2:-}"
  local f flavor mode

  read -rp "dart-define-from-file (skip=Enter): " f
  [[ -n $f ]] && out+=(--dart-define-from-file="$f")

  if [[ $platform != web ]]; then
    flavor=$(_flutter_pick_flavor) || return
    [[ -n $flavor ]] && out+=(--flavor="$flavor")
  fi

  mode=$(_flutter_pick_mode) || return
  out+=("--$mode")
}

_flutter_pick_platform() {
  local items=(
    "android-apk"
    "android aab"
    "ios (comming soon)"
    "web"
  )
  local choice i

  echo "Platform:" >&2
  for i in "${!items[@]}"; do
    if ((i == 0)); then
      printf '  %d) %s (default)\n' "$((i+1))" "${items[i]}" >&2
    else
      printf '  %d) %s\n' "$((i+1))" "${items[i]}" >&2
    fi
  done

  while true; do
    read -rp "Select platform (1-4, Enter=1): " choice || return 1
    choice="${choice:-1}"

    case "$choice" in
      1|"android-apk"|"apk"|"android apk")
        echo "apk"
        return 0
        ;;
      2|"android aab"|"aab"|"appbundle"|"android-aab")
        echo "appbundle"
        return 0
        ;;
      3|"ios"|"ios (comming soon)"|"ios (coming soon)")
        echo "❌ ios is disabled (comming soon)" >&2
        ;;
      4|"web")
        echo "web"
        return 0
        ;;
      *)
        echo "❌ Invalid platform: $choice" >&2
        ;;
    esac
  done
}

_flutter_pick_target() {
  [[ -d lib ]] || return 0
  local f files=() other=0

  for f in lib/*main*.dart; do
    [[ -f $f ]] || continue
    files+=("$f")
    [[ $f != "lib/main.dart" ]] && other=1
  done

  ((other)) || return 0

  local targets=()
  [[ -f lib/main.dart ]] && targets+=("lib/main.dart")
  for f in "${files[@]}"; do
    [[ $f != "lib/main.dart" ]] && targets+=("$f")
  done

  ((${#targets[@]})) || return 0

  local def="${targets[0]}" choice i
  echo "Target:" >&2
  for i in "${!targets[@]}"; do
    if [[ ${targets[i]} == "$def" ]]; then
      printf '  %d) %s (default)\n' "$((i+1))" "${targets[i]}" >&2
    else
      printf '  %d) %s\n' "$((i+1))" "${targets[i]}" >&2
    fi
  done

  while true; do
    read -rp "Select target (1-${#targets[@]}, Enter=$def): " choice || return 1
    choice="${choice:-1}"

    if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#targets[@]})); then
      echo "${targets[choice-1]}"
      return 0
    fi

    for f in "${targets[@]}"; do
      if [[ $choice == "$f" || $choice == "${f#lib/}" ]]; then
        echo "$f"
        return 0
      fi
    done

    echo "❌ Invalid target: $choice" >&2
  done
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
  local platform="${1:-}" target args=() cmd

  case "$platform" in
    apk|"android-apk"|"android apk") platform="apk" ;;
    aab|"android aab"|"android-aab"|appbundle) platform="appbundle" ;;
    web) platform="web" ;;
    ios*|"ios (comming soon)"|"ios (coming soon)")
      echo "❌ ios is disabled (comming soon)" >&2
      return 1
      ;;
    "")
      platform=$(_flutter_pick_platform) || return
      ;;
    *)
      echo "❌ Unknown platform: $platform (choose apk, aab, or web)" >&2
      return 1
      ;;
  esac

  target=$(_flutter_pick_target) || return
  [[ -n $target ]] && args+=(-t "$target")

  _flutter_icon_args args || return
  _flutter_args args "$platform" || return

  cmd=(fvm flutter build "$platform" "${args[@]}")
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
