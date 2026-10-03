# ADB helpers

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
