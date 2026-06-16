#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# blue-build installer — online + offline, any distro
# ============================================================
# Online:  curl .../install-local.sh | bash
# Offline: ./install-local.sh ./bluebuild   (pass binary path)
#          or drop bluebuild next to this script (auto-detect)

VERSION="${BLUEBUILD_VERSION:-v0.9.35}"
IMAGE="ghcr.io/blue-build/cli:${VERSION}-installer"
INSTALL_DIR="${BLUEBUILD_INSTALL_DIR:-/usr/local/bin}"
BINARY_NAME="bluebuild"

# ---- helpers ----

detect_runner() {
    if command -v podman &>/dev/null; then
        echo "podman"
    elif command -v docker &>/dev/null; then
        echo "docker"
    else
        echo ""
    fi
}

install_binary() {
    local src="$1"
    local dest="${INSTALL_DIR}/${BINARY_NAME}"

    if [[ "$INSTALL_DIR" == "$HOME"* ]]; then
        mkdir -p "$INSTALL_DIR"
        cp "$src" "$dest"
    else
        sudo mkdir -p "$INSTALL_DIR"
        sudo cp "$src" "$dest"
    fi
    chmod +x "$dest" 2>/dev/null || sudo chmod +x "$dest"
    echo "✔ bluebuild installed at $dest"
}

extract_from_image() {
    local runner="$1"
    local tmpdir
    tmpdir="$(mktemp -d)"

    echo "→ Pulling $IMAGE ..."
    "$runner" pull "$IMAGE"

    echo "→ Extracting binary ..."
    "$runner" create --name bluebuild-extract "$IMAGE" >/dev/null
    "$runner" cp bluebuild-extract:/out/bluebuild "$tmpdir/bluebuild"
    "$runner" rm bluebuild-extract >/dev/null 2>&1 || true

    install_binary "$tmpdir/bluebuild"
    rm -rf "$tmpdir"
}

# ---- main ----

# Offline: user passed a binary path
if [[ $# -ge 1 && -f "$1" ]]; then
    echo "↳ Offline mode: using local binary $1"
    install_binary "$1"
    exit 0
fi

# Offline: binary sitting next to this script
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/bluebuild" ]]; then
    echo "↳ Offline mode: found bluebuild next to script"
    install_binary "$SCRIPT_DIR/bluebuild"
    exit 0
fi

# Online: pull from ghcr.io
runner="$(detect_runner)"
if [[ -n "$runner" ]]; then
    echo "↳ Online mode: using $runner"
    extract_from_image "$runner"
    exit 0
fi

# No container runtime, no local binary — guide the user
echo "✖ Could not install bluebuild."
echo ""
echo "  You need at least ONE of:"
echo "  1. podman or docker installed → pulls pre-built binary automatically"
echo "  2. A local bluebuild binary → drop it next to this script or pass it as arg"
echo ""
echo "  Offline workflow (do once on a machine with podman/docker):"
echo "    podman pull $IMAGE"
echo "    podman create --name bb-tmp $IMAGE"
echo "    podman cp bb-tmp:/out/bluebuild ./bluebuild"
echo "    podman rm bb-tmp"
echo "    # → copy bluebuild to target machine"
echo "    # → run: ./install-local.sh ./bluebuild"
exit 1
