# Flutter helpers

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
