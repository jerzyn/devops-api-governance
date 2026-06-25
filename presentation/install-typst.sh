#!/usr/bin/env bash
# Install typst CLI to ~/.local/bin (required for presenterm typst +render slides).
set -euo pipefail

VERSION="v0.13.1"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

case "$(uname -m)" in
  x86_64|amd64) ARCH="x86_64-unknown-linux-musl" ;;
  aarch64|arm64) ARCH="aarch64-unknown-linux-musl" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

TARBALL="typst-${ARCH}.tar.xz"
URL="https://github.com/typst/typst/releases/download/${VERSION}/${TARBALL}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Downloading ${URL} ..."
curl -fsSL -o "${tmpdir}/${TARBALL}" "${URL}"
tar -xJf "${tmpdir}/${TARBALL}" -C "${tmpdir}"

mkdir -p "${INSTALL_DIR}"
install -m 0755 "${tmpdir}/typst-${ARCH}/typst" "${INSTALL_DIR}/typst"

echo "Installed typst to ${INSTALL_DIR}/typst"
"${INSTALL_DIR}/typst" --version

if ! command -v typst >/dev/null 2>&1; then
  echo
  echo "Add ${INSTALL_DIR} to your PATH, e.g.:"
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
