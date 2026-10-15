#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/tooling/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/tooling/user-data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/tooling/cache}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-/workspace/tooling/android-user}"
export ANDROID_SDK_HOME="${ANDROID_SDK_HOME:-/workspace/tooling/android-home}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$ANDROID_USER_HOME" "$ANDROID_SDK_HOME/.android"
godot_binary="${GODOT_BIN:-/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64}"
exec "$godot_binary" --path "$project_dir" "$@"
