#!/usr/bin/env bash
# Runs every headless test suite. Usage: GODOT=/path/to/godot ./run_tests.sh
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1
status=0
for suite in movement_test troll_test level_test audio_test menu_test; do
	echo "== $suite"
	"$GODOT" --headless --path . "res://tests/$suite.tscn" 2>&1 | grep -v '^Godot Engine' | grep -v '^$'
	[ "${PIPESTATUS[0]}" -eq 0 ] || status=1
done
exit $status
