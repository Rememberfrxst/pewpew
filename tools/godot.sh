#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tooling_root="${PEWPEW_TOOLING_ROOT:-/workspace/tooling}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$tooling_root/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$tooling_root/user-data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$tooling_root/cache}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$tooling_root/android-user}"
export ANDROID_SDK_HOME="${ANDROID_SDK_HOME:-$tooling_root/android-home}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$ANDROID_USER_HOME" "$ANDROID_SDK_HOME/.android"
godot_binary="${GODOT_BIN:-/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64}"
exec "$godot_binary" --path "$project_dir" "$@"
