#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output_directory="$project_dir/build/android"
output_apk="$output_directory/astral-relay.apk"

mkdir -p -- "$output_directory"
"$godot_bin" --headless --path "$project_dir" --editor --import --quit
"$godot_bin" --headless --path "$project_dir" --export-debug Android "$output_apk"
printf 'APK : %s\n' "$output_apk"
