# Sourced by the demo scripts: picks the container engine and its compose
# command. Sets ENGINE (docker|podman) and COMPOSE (array).
#
# DEMO_ENGINE=docker|podman forces one. Otherwise: the engine that runs the
# demo's gitea container; else Docker if it answers; else Podman.

_demo_is_podman_shim() { docker --version 2>/dev/null | grep >/dev/null -ci podman; }
_demo_runs_gitea() { "$1" ps --format '{{.Names}}' 2>/dev/null | grep >/dev/null -cx gitea; }

if [ -n "${DEMO_ENGINE:-}" ]; then
  ENGINE="$DEMO_ENGINE"
elif command -v podman >/dev/null && _demo_runs_gitea podman; then
  ENGINE=podman
elif command -v docker >/dev/null && ! _demo_is_podman_shim && _demo_runs_gitea docker; then
  ENGINE=docker
elif command -v docker >/dev/null && ! _demo_is_podman_shim && docker info >/dev/null 2>&1; then
  ENGINE=docker
elif command -v podman >/dev/null; then
  ENGINE=podman
else
  echo "no container engine found: install Docker (with Compose) or Podman (with podman-compose)" >&2
  exit 1
fi

case "$ENGINE" in
  docker)
    if docker compose version >/dev/null 2>&1; then COMPOSE=(docker compose)
    elif command -v docker-compose >/dev/null; then COMPOSE=(docker-compose)
    else echo "Docker found, but not Docker Compose (docker compose)" >&2; exit 1; fi ;;
  podman)
    if command -v podman-compose >/dev/null; then COMPOSE=(podman-compose)
    else COMPOSE=(podman compose); fi ;;
  *) echo "DEMO_ENGINE must be docker or podman, not '$ENGINE'" >&2; exit 1 ;;
esac
