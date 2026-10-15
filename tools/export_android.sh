#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$project_dir/build"
bash "$project_dir/tools/godot.sh" --headless --export-debug Android "$project_dir/build/pewpew-debug.apk"
sdk_root="${ANDROID_HOME:-${PEWPEW_TOOLING_ROOT:-/workspace/tooling}/android-sdk}"
"$sdk_root/build-tools/36.0.0/apksigner" verify --verbose "$project_dir/build/pewpew-debug.apk"
(cd "$project_dir/build" && sha256sum pewpew-debug.apk > pewpew-debug.apk.sha256)
