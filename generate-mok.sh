#!/usr/bin/env bash
# ==========================================================================
# generate-mok.sh — Generate a persistent MOK signing key pair
# ==========================================================================
# Run this ONCE before your first build. The key pair is reused across all
# future builds so that MOK enrollment on the laptop is a one-time step.
#
# The private key (mok.priv) signs kernel modules at build time.
# The public cert (mok.der) ships in the image for MOK Manager enrollment.
# ==========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOK_DIR="$SCRIPT_DIR/config/mok"
CNF="$SCRIPT_DIR/config/mok-signing.cnf"

if [[ -f "$MOK_DIR/mok.priv" && -f "$MOK_DIR/mok.der" ]]; then
    echo "MOK key pair already exists at $MOK_DIR/"
    echo "Delete both files if you want to regenerate (you'll need to re-enroll on the laptop)."
    exit 0
fi

mkdir -p "$MOK_DIR"

echo "Generating MOK signing key pair..."
openssl req -new -x509 -newkey rsa:4096 \
    -keyout "$MOK_DIR/mok.priv" \
    -outform DER -out "$MOK_DIR/mok.der" \
    -days 36500 -nodes \
    -config "$CNF"

echo ""
echo "Done! Key pair created:"
echo "  Private key: $MOK_DIR/mok.priv"
echo "  Public cert: $MOK_DIR/mok.der"
echo ""
echo "These are gitignored. Back them up somewhere safe — if you lose the"
echo "private key you'll need to regenerate and re-enroll on the laptop."
