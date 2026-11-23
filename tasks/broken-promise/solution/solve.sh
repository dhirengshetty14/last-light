#!/bin/sh
set -eu
mkdir -p /logs/artifacts
printf '%s\n' '{"choice":3,"delay":10}' > /logs/artifacts/policy.json
