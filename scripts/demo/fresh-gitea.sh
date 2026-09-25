#!/bin/bash
# Wipe the demo Gitea (all PRs, CI runs and branches) and the runner
# registration, bring the stack up again and set it to the Stage 1 start.
# Use it before the final recording, so PR numbers start at #1 and the Actions
# tab has no rehearsal runs. Destructive: asks first (or pass --yes).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROFILES=(--profile contract --profile catalog --profile gateway)
cd "$ROOT"

if [ "${1:-}" != --yes ]; then
  read -r -p "Delete ALL data of the demo Gitea (./gitea-data) and the runner registration (./runner-data)? [y/N] " a
  [ "$a" = y ] || { echo "aborted"; exit 1; }
fi

podman-compose "${PROFILES[@]}" down
# Files inside are owned by container users, so delete them in podman's user namespace.
podman unshare rm -rf gitea-data runner-data
mkdir -p gitea-data runner-data
podman-compose "${PROFILES[@]}" up -d

echo "waiting for the stack..."
for i in $(seq 1 100); do
  ok=1
  curl -sf -o /dev/null http://localhost:3000/api/healthz || ok=0
  curl -sf -o /dev/null http://localhost:7007 || ok=0
  curl -sf -o /dev/null http://localhost:8081/health || ok=0
  curl -sf -o /dev/null http://localhost:8080/api/health || ok=0
  podman logs gitea-runner 2>&1 | grep >/dev/null -c "declare successfully" || ok=0
  [ $ok = 1 ] && break
  sleep 3
done
[ $ok = 1 ] || { echo "stack did not come up; check podman ps" >&2; exit 1; }
"$ROOT/scripts/demo/prep-stage.sh" goto 1
