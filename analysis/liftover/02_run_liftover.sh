#!/bin/bash
##############################################################################
# Liftover Analysis — Step 2: Run LiftOver in Both Directions
#
# Direction 1: hg38 → CHM13
#   Question: how many hg38 LINE/SINE loci cannot be lifted to CHM13?
#   (hg38-specific TEs: misassemblies, collapsed duplications, or
#   polymorphic insertions absent from CHM13/this individual)
#
# Direction 2: CHM13 → hg38
#   Question: how many CHM13 LINE/SINE loci cannot be lifted to hg38?
#   (CHM13-specific TEs: gap-filled regions, novel insertions)
#   Hoyt et al. 2022 reported 20,427 CHM13-specific TEs total (all classes).
#   This reproduces that analysis for LINE/SINE only.
#
# Outputs:
#   results/hg38_to_chm13_mapped.bed   — successfully lifted
#   results/hg38_to_chm13_unmapped.bed — failed to lift
#   results/chm13_to_hg38_mapped.bed
#   results/chm13_to_hg38_unmapped.bed
##############################################################################

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATA_DIR="$SCRIPT_DIR/data"
RESULTS_DIR="$SCRIPT_DIR/results"
LIFTOVER="$DATA_DIR/liftOver"

mkdir -p "$RESULTS_DIR"

echo "================================================================================"
echo "Liftover Analysis — Step 2: Run LiftOver"
echo "================================================================================"
echo ""

# Check dependencies
if [[ ! -x "$LIFTOVER" ]]; then
    echo "ERROR: liftOver not found at $LIFTOVER"
    echo "Run 00_download.sh first."
    exit 1
fi

HG38_BED="$DATA_DIR/hg38_rmsk_LINE_SINE.bed"
CHM13_BED="$DATA_DIR/chm13_rmsk_LINE_SINE.bed"
HG38_TO_CHM13_CHAIN="$DATA_DIR/hg38ToHs1.over.chain.gz"
CHM13_TO_HG38_CHAIN="$DATA_DIR/hs1ToHg38.over.chain.gz"

for f in "$HG38_BED" "$CHM13_BED" "$HG38_TO_CHM13_CHAIN" "$CHM13_TO_HG38_CHAIN"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: Required file not found: $f"
        echo "Run 00_download.sh and 01_prepare_beds.sh first."
        exit 1
    fi
done

# ==============================================================================
# Direction 1: hg38 → CHM13
# ==============================================================================
echo "Direction 1: hg38 → CHM13"
echo "  Input:  $HG38_BED"
echo "  Chain:  $HG38_TO_CHM13_CHAIN"
echo "  Started: $(date)"
echo ""

MAPPED1="$RESULTS_DIR/hg38_to_chm13_mapped.bed"
UNMAPPED1="$RESULTS_DIR/hg38_to_chm13_unmapped.bed"

"$LIFTOVER" \
    "$HG38_BED" \
    "$HG38_TO_CHM13_CHAIN" \
    "$MAPPED1" \
    "$UNMAPPED1"

mapped1=$(grep -v "^#" "$MAPPED1" | wc -l)
unmapped1=$(grep -v "^#" "$UNMAPPED1" | wc -l)
total1=$((mapped1 + unmapped1))
pct_unmapped1=$(awk "BEGIN{printf \"%.1f\", $unmapped1*100/$total1}")

echo "  ✓ Done"
echo "  Total input:    $total1"
echo "  Mapped:         $mapped1 ($(awk "BEGIN{printf \"%.1f\", $mapped1*100/$total1}")%)"
echo "  Unmapped:       $unmapped1 ($pct_unmapped1%)  ← hg38-specific TEs"
echo ""

# ==============================================================================
# Direction 2: CHM13 → hg38
# ==============================================================================
echo "Direction 2: CHM13 → hg38"
echo "  Input:  $CHM13_BED"
echo "  Chain:  $CHM13_TO_HG38_CHAIN"
echo "  Started: $(date)"
echo ""

MAPPED2="$RESULTS_DIR/chm13_to_hg38_mapped.bed"
UNMAPPED2="$RESULTS_DIR/chm13_to_hg38_unmapped.bed"

"$LIFTOVER" \
    "$CHM13_BED" \
    "$CHM13_TO_HG38_CHAIN" \
    "$MAPPED2" \
    "$UNMAPPED2"

mapped2=$(grep -v "^#" "$MAPPED2" | wc -l)
unmapped2=$(grep -v "^#" "$UNMAPPED2" | wc -l)
total2=$((mapped2 + unmapped2))
pct_unmapped2=$(awk "BEGIN{printf \"%.1f\", $unmapped2*100/$total2}")

echo "  ✓ Done"
echo "  Total input:    $total2"
echo "  Mapped:         $mapped2 ($(awk "BEGIN{printf \"%.1f\", $mapped2*100/$total2}")%)"
echo "  Unmapped:       $unmapped2 ($pct_unmapped2%)  ← CHM13-specific TEs"
echo ""

# ==============================================================================
# Quick comparison
# ==============================================================================
echo "================================================================================"
echo "Comparison"
echo "================================================================================"
echo ""
printf "  %-45s %s\n" "hg38 LINE/SINE total:" "$total1"
printf "  %-45s %s (%.1f%%)\n" "hg38-specific (failed hg38→CHM13 lift):" "$unmapped1" "$(awk "BEGIN{printf \"%.1f\", $unmapped1*100/$total1}")"
echo ""
printf "  %-45s %s\n" "CHM13 LINE/SINE total:" "$total2"
printf "  %-45s %s (%.1f%%)\n" "CHM13-specific (failed CHM13→hg38 lift):" "$unmapped2" "$(awk "BEGIN{printf \"%.1f\", $unmapped2*100/$total2}")"
echo ""
echo "  (Hoyt et al. 2022 reported 20,427 CHM13-specific TEs across ALL TE classes"
echo "   using a slightly different pipeline — LINE/SINE subset expected to be lower)"
echo ""
echo "Next step: Analyze subfamily composition of unmapped sets"
echo "  python analysis/liftover/03_analyze.py"
echo ""
