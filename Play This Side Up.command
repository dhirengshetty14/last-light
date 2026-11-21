#!/bin/bash
set -e
project_dir=$(cd -- "$(dirname -- "$0")" && pwd)
cd -- "$project_dir"
watcher=""
if command -v python3 >/dev/null && { command -v bruin >/dev/null || [ -x "$HOME/.local/bin/bruin" ]; }; then
    mkdir -p telemetry/local
    python3 telemetry/watch.py --watch >telemetry/local/live.log 2>&1 &
    watcher=$!
fi
finish() {
    if [ -n "$watcher" ] && jobs -pr | grep -Fxq -- "$watcher"; then
        kill "$watcher" 2>/dev/null || true
        wait "$watcher" 2>/dev/null || true
    fi
}
trap finish EXIT
if [ -x "exports/This Side Up.app/Contents/MacOS/This Side Up" ]; then
    "exports/This Side Up.app/Contents/MacOS/This Side Up" "$@"
else
    game_bin="${GODOT_BIN:-}"
    for candidate in "$game_bin" "$HOME/Applications/Godot 4.7.2.app/Contents/MacOS/Godot" "/Applications/Godot.app/Contents/MacOS/Godot" "$(command -v godot || true)"; do
        if [ -x "$candidate" ]; then
            "$candidate" --headless --path "$project_dir" --import
            "$candidate" --path "$project_dir" "$@"
            exit $?
        fi
    done
    echo 'Install Godot 4.7.2 or set GODOT_BIN to its executable to play from source.'
    exit 1
fi
