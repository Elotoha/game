#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/android
# Configure the Android SDK, Java and debug keystore in Godot's editor settings first.
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run.gd
godot --headless --path . --export-debug Android build/android/apex.apk
printf 'APK: %s/build/android/apex.apk\n' "$PWD"
