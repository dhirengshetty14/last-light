#!/bin/sh
# Harbor 0.27 requires a Linux egress controller for its no-network provider.
# This local runner uses Docker's network namespace directly for both halves.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run_dir=$(mktemp -d)
printf 'Writing trial outputs under %s\n' "$run_dir"
if [ "$#" -eq 0 ]; then set -- catch-window broken-promise ring-window; fi
for task in "$@"; do
    case "$task" in
        ring-window) trial_image=last-light-harbor:4.7.2 ;;
        catch-window|broken-promise) trial_image=this-side-up-harbor:4.7.2 ;;
        *) exit 2 ;;
    esac
    mkdir -p "$run_dir/$task/artifacts" "$run_dir/$task/verifier"
    docker run --rm --network none --pull never --read-only --cap-drop ALL --security-opt no-new-privileges \
        --user "$(id -u):$(id -g)" --tmpfs /tmp \
        -v "$project_dir/tasks/$task/solution:/solution:ro" -v "$run_dir/$task/artifacts:/logs/artifacts" \
        "$trial_image" /bin/sh /solution/solve.sh
    docker run --rm --network none --pull never --read-only --cap-drop ALL --security-opt no-new-privileges \
        --user "$(id -u):$(id -g)" --tmpfs /tmp -e XDG_DATA_HOME=/tmp/data -e XDG_CONFIG_HOME=/tmp/config -e XDG_CACHE_HOME=/tmp/cache \
        -v "$project_dir/tasks/$task/tests:/tests:ro" -v "$run_dir/$task/artifacts:/logs/artifacts:ro" \
        -v "$run_dir/$task/verifier:/logs/verifier" "$trial_image" /bin/sh /tests/test.sh
    python3 -c 'import json,sys; result=json.load(open(sys.argv[2])); print(sys.argv[1],result); sys.exit(0 if result.get("all_pass")==1 and result.get("score")==1 else 1)' "$task" "$run_dir/$task/verifier/reward.json"
done
