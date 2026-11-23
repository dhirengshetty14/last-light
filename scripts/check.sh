#!/bin/sh
# Every headless check for Last Light. Run it before you push; Docker runs the same script.
#
#   scripts/check.sh           court, Free Agents, Gemini and host tests, a replay, a quick steal test
#   scripts/check.sh --full    also the six full-game playtests (several minutes)
#
# Set GODOT to the Godot 4.7.2 executable if it is not on your PATH or in a usual place.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
	for candidate in \
		"$(command -v godot 2>/dev/null || true)" \
		"$HOME/Applications/Godot 4.7.2.app/Contents/MacOS/Godot" \
		"/Applications/Godot.app/Contents/MacOS/Godot"; do
		if [ -n "$candidate" ] && [ -x "$candidate" ]; then
			GODOT="$candidate"
			break
		fi
	done
fi
if [ -z "$GODOT" ]; then
	echo "Godot 4.7.2 not found. Install it, or set GODOT to its executable." >&2
	exit 2
fi
version=$("$GODOT" --version 2>/dev/null | head -n 1)
case "$version" in
	4.7.2.*) ;;
	*) echo "Warning: this project is tested on Godot 4.7.2, found '$version'." >&2 ;;
esac

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failed=0

check() {
	label=$1
	shift
	printf '%-34s' "$label"
	if "$@" >"$scratch/out.txt" 2>&1; then
		echo "ok"
	else
		echo "FAILED"
		tail -n 25 "$scratch/out.txt" | sed 's/^/    /'
		failed=1
	fi
}

if [ ! -d .godot/imported ]; then
	echo "First run: importing assets (a minute or two)..."
	"$GODOT" --headless --path . --import >"$scratch/import.txt" 2>&1 || {
		tail -n 25 "$scratch/import.txt"
		exit 1
	}
fi

check "court rules and robots" "$GODOT" --headless --path . -s tests/star_match_test.gd
check "free agents (promises, union)" "$GODOT" --headless --path . -s tests/free_agents_test.gd
check "gemini turns (no network)" "$GODOT" --headless --path . -s tests/gemini_court.gd
check "gemini host (no network)" python3 tests/radio_host_test.py
check "replay of docs/match-87" "$GODOT" --headless --path . -s tools/replay_court.gd -- docs/match-87.jsonl
check "steal test, two series" "$GODOT" --headless --path . -s learning/steal_eval.gd -- --series=2 --out="$scratch/steal.json"

if [ "${1:-}" = "--full" ]; then
	check "playtest: rivals" "$GODOT" --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --rivals --seed=87
	check "playtest: swapped pilots" "$GODOT" --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --swap-pilots --seed=87
	check "playtest: free agents" "$GODOT" --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --seed=87
	check "playtest: free agents, liars" "$GODOT" --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --liars --seed=87
	check "playtest: written rules" "$GODOT" --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --written-rules --seed=87
	check "playtest: liars, written rules" "$GODOT" --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --liars --written-rules --seed=87
fi

if [ "$failed" -ne 0 ]; then
	echo "Some checks failed."
	exit 1
fi
echo "All checks passed."
