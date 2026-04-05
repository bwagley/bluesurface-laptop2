#!/usr/bin/env bash
# ==========================================================================
# build.sh — Build and push the Surface Laptop 2 custom image
# ==========================================================================
# Usage:
#   ./build.sh              # build and push
#   ./build.sh --build-only # build without pushing
#   ./build.sh --no-cache   # full rebuild (no layer cache)
# ==========================================================================
set -euo pipefail

# ── Configuration (loaded from .env) ─────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERROR: .env not found. Copy .env.example to .env and fill in your details:"
    echo "  cp .env.example .env"
    exit 1
fi

FULL_IMAGE="${REGISTRY}/${GITHUB_USER}/${IMAGE_NAME}:${TAG}"
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ONLY=false
EXTRA_ARGS=()

for arg in "$@"; do
    case "$arg" in
        --build-only) BUILD_ONLY=true ;;
        --no-cache)   EXTRA_ARGS+=(--no-cache) ;;
        *)            echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

# ── Pre-flight checks ───────────────────────────────────────────────────────
if [[ "${GITHUB_USER:-}" == "YOUR_GITHUB_USERNAME" || -z "${GITHUB_USER:-}" ]]; then
    echo "ERROR: Edit .env and set GITHUB_USER to your GitHub username."
    exit 1
fi

CAMERA_REPO="https://github.com/tomgood18/surface-laptop-2-camera.git"
DKMS_DIR="$SCRIPT_DIR/config/dkms"

if [[ ! -d "$DKMS_DIR/ipu-bridge-ov9734" ]]; then
    echo ""
    echo "Camera DKMS sources not found — cloning from upstream..."
    echo ""
    TMP_CAM=$(mktemp -d)
    git clone --depth 1 "$CAMERA_REPO" "$TMP_CAM"
    cp -r "$TMP_CAM/dkms/ipu-bridge-ov9734" "$DKMS_DIR/"
    cp -r "$TMP_CAM/dkms/ov9734-surface"    "$DKMS_DIR/"
    rm -rf "$TMP_CAM"

    # Apply local patches
    for patch in "$SCRIPT_DIR"/patches/*.patch; do
        [[ -f "$patch" ]] || continue
        echo "Applying patch: $(basename "$patch")"
        patch -d "$DKMS_DIR/.." -p1 < "$patch"
    done
    echo ""
fi

if [[ ! -f "$SCRIPT_DIR/config/mok/mok.priv" || ! -f "$SCRIPT_DIR/config/mok/mok.der" ]]; then
    echo ""
    echo "ERROR: MOK signing key pair not found!"
    echo ""
    echo "Generate it once with:"
    echo "  ./generate-mok.sh"
    echo ""
    echo "Then re-run this script."
    exit 1
fi

# ── Build ────────────────────────────────────────────────────────────────────
echo ""
echo "Building: ${FULL_IMAGE}"
echo "================================================"
echo ""

podman build \
    --pull=newer \
    "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" \
    -t "${FULL_IMAGE}" \
    -f "${SCRIPT_DIR}/Containerfile" \
    "${SCRIPT_DIR}"

echo ""
echo "Build complete: ${FULL_IMAGE}"

# ── Push ─────────────────────────────────────────────────────────────────────
if [[ "$BUILD_ONLY" == true ]]; then
    echo "Skipping push (--build-only)."
    exit 0
fi

echo ""
echo "Pushing to ${REGISTRY}..."
podman push "${FULL_IMAGE}"

echo ""
echo "================================================"
echo "Done! Image pushed to: ${FULL_IMAGE}"
echo ""
echo "On the Surface Laptop 2, rebase with:"
echo "  sudo bootc switch ${FULL_IMAGE}"
echo "  systemctl reboot"
echo ""
