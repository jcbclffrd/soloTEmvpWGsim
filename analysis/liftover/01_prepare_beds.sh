#!/bin/bash
##############################################################################
# Liftover Analysis — Step 1: Prepare BED Files
#
# Converts hg38 RepeatMasker (UCSC rmsk.txt format) to BED,
# filtered to LINE and SINE classes only.
#
# Also prepares the CHM13 BED (already in BED format, just filters to
# LINE/SINE to match hg38 for a fair comparison).
#
# hg38 rmsk.txt columns (0-based):
#   0:bin  1:swScore  2:milliDiv  3:milliDel  4:milliIns
#   5:genoName  6:genoStart  7:genoEnd  8:genoLeft
#   9:strand  10:repName  11:repClass  12:repFamily
#   13:repStart  14:repEnd  15:repLeft  16:id
#
# Output BED columns (matching CHM13 BED format):
#   chr  start  end  name  score  strand  class  family  percDiv  id
##############################################################################

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
DATA_DIR="$SCRIPT_DIR/data"
RESULTS_DIR="$SCRIPT_DIR/results"

mkdir -p "$RESULTS_DIR"

echo "================================================================================"
echo "Liftover Analysis — Step 1: Prepare BED Files"
echo "================================================================================"
echo ""

# ==============================================================================
# hg38: convert rmsk.txt to BED, filter to LINE/SINE
# ==============================================================================
HG38_BED="$DATA_DIR/hg38_rmsk_LINE_SINE.bed"

echo "Converting hg38 RepeatMasker to BED (LINE/SINE only)..."
if [[ -f "$HG38_BED" ]]; then
    echo "  Already exists, skipping."
else
    if [[ ! -f "$DATA_DIR/hg38_rmsk.txt.gz" ]]; then
        echo "ERROR: hg38_rmsk.txt.gz not found. Run 00_download.sh first."
        exit 1
    fi

    # UCSC rmsk.txt: tab-separated, no header
    # Filter to class == LINE or SINE, output standard BED6 + class/family/percDiv/id
    zcat "$DATA_DIR/hg38_rmsk.txt.gz" | \
        awk 'BEGIN{OFS="\t"}
             ($12 == "LINE" || $12 == "SINE") {
                 # milliDiv (col 3) / 10 = percent divergence
                 percDiv = $3 / 10.0
                 print $6, $7, $8, $11, $2, $10, $12, $13, percDiv, $17
             }' | \
        sort -k1,1 -k2,2n > "$HG38_BED"

    echo "  ✓ Written: $HG38_BED"
fi

hg38_count=$(wc -l < "$HG38_BED")
echo "  hg38 LINE/SINE loci: $(printf '%s' "$hg38_count" | numfmt --grouping 2>/dev/null || echo "$hg38_count")"
echo ""

# ==============================================================================
# CHM13: filter existing BED to LINE/SINE
# ==============================================================================
CHM13_SOURCE="$REPO_ROOT/references/annotations/T2T-CHM13v2.0_RepeatMasker.bed"
CHM13_BED="$DATA_DIR/chm13_rmsk_LINE_SINE.bed"

echo "Filtering CHM13 RepeatMasker to LINE/SINE..."
if [[ ! -f "$CHM13_SOURCE" ]]; then
    echo "ERROR: CHM13 RepeatMasker BED not found: $CHM13_SOURCE"
    exit 1
fi

if [[ -f "$CHM13_BED" ]]; then
    echo "  Already exists, skipping."
else
    awk '$7 == "LINE" || $7 == "SINE"' "$CHM13_SOURCE" > "$CHM13_BED"
    echo "  ✓ Written: $CHM13_BED"
fi

chm13_count=$(wc -l < "$CHM13_BED")
echo "  CHM13 LINE/SINE loci: $(printf '%s' "$chm13_count" | numfmt --grouping 2>/dev/null || echo "$chm13_count")"
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "BED preparation complete!"
echo "================================================================================"
echo ""
printf "  %-30s %s loci\n" "hg38 LINE/SINE:" "$hg38_count"
printf "  %-30s %s loci\n" "CHM13 LINE/SINE:" "$chm13_count"
echo ""
echo "Next step: Run liftover"
echo "  bash analysis/liftover/02_run_liftover.sh"
echo ""
