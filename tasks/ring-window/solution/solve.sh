#!/bin/sh
set -eu
mkdir -p /logs/artifacts
printf '%s\n' '{"shoot_cm":254,"dash_tick":0}' > /logs/artifacts/policy.json
