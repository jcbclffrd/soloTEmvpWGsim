#!/usr/bin/env bash
# Filter hg38-specific unmapped LINE/SINE loci to those >50 kb from any hg38
# assembly gap, producing the ~6,600-locus candidate set for polymorphism check.
# Run from repo root: bash analysis/te_polymorphism/01_extract_gap_distal.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
RESULTS_DIR="${SCRIPT_DIR}/results"
LIFTOVER_DATA="analysis/liftover/data"
LIFTOVER_RESULTS="analysis/liftover/results"

mkdir -p "${DATA_DIR}" "${RESULTS_DIR}"

# Input: hg38-specific unmapped loci (LINE/SINE only; 36,480 records)
UNMAPPED="${LIFTOVER_RESULTS}/hg38_to_chm13_unmapped.bed"
if [[ ! -f "${UNMAPPED}" ]]; then
    echo "[01] ERROR: ${UNMAPPED} not found. Run the liftover pipeline first."
    exit 1
fi

# Gaps BED — build from UCSC gap.txt if needed
GAPS_BED="${DATA_DIR}/hg38_gaps.bed"
if [[ ! -f "${GAPS_BED}" ]]; then
    GAP_TXT="${LIFTOVER_DATA}/hg38_gap.txt.gz"
    if [[ ! -f "${GAP_TXT}" ]]; then
        echo "[01] Downloading hg38 gap table..."
        wget -q -O "${GAP_TXT}" \
            "https://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/gap.txt.gz"
    fi
    echo "[01] Converting gap.txt → BED..."
    zcat "${GAP_TXT}" | awk 'BEGIN{OFS="\t"} {print $2,$3,$4,$8,$7}' \
        > "${GAPS_BED}"
fi

GAP_COUNT=$(wc -l < "${GAPS_BED}")
echo "[01] Gaps BED: ${GAP_COUNT} records"

# Extend each gap by 50 kb on each side, then subtract to find gap-distal loci.
# "Gap-distal" = no part of the locus within 50 kb of any gap.
GAP_DISTAL="${RESULTS_DIR}/hg38_specific_gap_distal.bed"

echo "[01] Filtering for loci >50 kb from any hg38 gap..."
bedtools slop -i "${GAPS_BED}" -g <(
    # Build chrom sizes on-the-fly from the unmapped BED itself (conservative)
    awk 'BEGIN{OFS="\t"} {if(!seen[$1]++){sizes[$1]=$1} end[$1]=(end[$1]>$3?end[$1]:$3)} END{for(c in sizes) print c, end[c]+1}' \
        "${UNMAPPED}"
) -b 50000 2>/dev/null \
| bedtools subtract -a "${UNMAPPED}" -b stdin -A \
> "${GAP_DISTAL}"

COUNT=$(wc -l < "${GAP_DISTAL}")
TOTAL=$(wc -l < "${UNMAPPED}")
echo "[01] Gap-distal loci: ${COUNT} / ${TOTAL} ($(echo "scale=1; ${COUNT}*100/${TOTAL}" | bc)%)"
echo "[01] Written: ${GAP_DISTAL}"
echo "[01] Done."
