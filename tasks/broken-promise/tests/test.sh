#!/bin/sh
set -eu
mkdir -p /logs/verifier
exec godot --headless --path /nursery --script res://tasks/grader.gd -- broken-promise /logs/artifacts/policy.json /logs/verifier/reward.json
