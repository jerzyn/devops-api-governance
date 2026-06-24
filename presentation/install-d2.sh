#!/usr/bin/env bash
# Install d2 CLI to ~/.local/bin (required for presenterm d2 diagram slides).
set -euo pipefail

VERSION="v0.7.1"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

case "$(uname -m)" in
  x86_64|amd64) ARCH="linux-amd64" ;;
  aarch64|arm64) ARCH="linux-arm64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

TARBALL="d2-${VERSION}-${ARCH}.tar.gz"
URL="https://github.com/terrastruct/d2/releases/download/${VERSION}/${TARBALL}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Downloading ${URL} ..."
curl -fsSL -o "${tmpdir}/${TARBALL}" "${URL}"
tar -xzf "${tmpdir}/${TARBALL}" -C "${tmpdir}"

mkdir -p "${INSTALL_DIR}"
install -m 0755 "${tmpdir}/d2" "${INSTALL_DIR}/d2"

echo "Installed d2 to ${INSTALL_DIR}/d2"
"${INSTALL_DIR}/d2" --version

if ! command -v d2 >/dev/null 2>&1; then
  echo
  echo "Add ${INSTALL_DIR} to your PATH, e.g.:"
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
