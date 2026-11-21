#!/bin/sh
set -eu
mkdir -p /logs/verifier
exec godot --headless --path /nursery --script res://tasks/star_grader.gd -- /logs/artifacts/policy.json /logs/verifier/reward.json
