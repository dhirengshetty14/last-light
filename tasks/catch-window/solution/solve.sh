#!/bin/sh
set -eu
mkdir -p /logs/artifacts
printf '%s\n' '{"lead":100,"hold":24}' > /logs/artifacts/policy.json
