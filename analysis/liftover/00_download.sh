#!/bin/bash
##############################################################################
# Liftover Analysis — Step 0: Download Dependencies
#
# Downloads:
#   - UCSC liftOver binary
#   - hg38 → CHM13 chain file
#   - CHM13 → hg38 chain file
#   - hg38 RepeatMasker annotations (UCSC rmsk track)
#
# All files go to analysis/liftover/data/
# See MANIFEST.md for full file listing and cleanup instructions.
##############################################################################

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
DATA_DIR="$SCRIPT_DIR/data"

cd "$REPO_ROOT"

echo "================================================================================"
echo "Liftover Analysis — Step 0: Download Dependencies"
echo "================================================================================"
echo ""
echo "All files will be saved to: $DATA_DIR"
echo "See analysis/liftover/MANIFEST.md for details and cleanup instructions."
echo ""

mkdir -p "$DATA_DIR"

# ==============================================================================
# liftOver binary
# ==============================================================================
echo "Downloading liftOver binary..."
if [[ -f "$DATA_DIR/liftOver" ]]; then
    echo "  Already exists, skipping."
else
    wget -q -O "$DATA_DIR/liftOver" \
        https://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/liftOver
    chmod +x "$DATA_DIR/liftOver"
    echo "  ✓ liftOver binary downloaded"
fi
echo ""

# ==============================================================================
# Chain files
# ==============================================================================
echo "Downloading chain files..."

if [[ -f "$DATA_DIR/hg38ToHs1.over.chain.gz" ]]; then
    echo "  hg38→CHM13 chain: already exists, skipping."
else
    echo "  Downloading hg38 → CHM13 (hs1) chain file..."
    wget -q --show-progress -O "$DATA_DIR/hg38ToHs1.over.chain.gz" \
        https://hgdownload.soe.ucsc.edu/goldenPath/hg38/liftOver/hg38ToHs1.over.chain.gz
    echo "  ✓ hg38→CHM13 chain downloaded"
fi

if [[ -f "$DATA_DIR/hs1ToHg38.over.chain.gz" ]]; then
    echo "  CHM13→hg38 chain: already exists, skipping."
else
    echo "  Downloading CHM13 (hs1) → hg38 chain file..."
    wget -q --show-progress -O "$DATA_DIR/hs1ToHg38.over.chain.gz" \
        https://hgdownload.soe.ucsc.edu/goldenPath/hs1/liftOver/hs1ToHg38.over.chain.gz
    echo "  ✓ CHM13→hg38 chain downloaded"
fi
echo ""

# ==============================================================================
# hg38 RepeatMasker annotations
# ==============================================================================
echo "Downloading hg38 RepeatMasker annotations (~180 MB compressed)..."
if [[ -f "$DATA_DIR/hg38_rmsk.txt.gz" ]]; then
    echo "  Already exists, skipping."
else
    wget -q --show-progress -O "$DATA_DIR/hg38_rmsk.txt.gz" \
        https://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/rmsk.txt.gz
    echo "  ✓ hg38 RepeatMasker downloaded"
fi
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "Download complete!"
echo "================================================================================"
echo ""
echo "Files in $DATA_DIR:"
ls -lh "$DATA_DIR/"
echo ""
echo "Next step: Prepare BED files"
echo "  bash analysis/liftover/01_prepare_beds.sh"
echo ""
