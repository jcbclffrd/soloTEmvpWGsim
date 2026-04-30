#!/usr/bin/env bash
# Intersect gap-distal hg38-specific LINE/SINE loci with 1000G MEI calls
# (and dbRIP if available).
# Run from repo root: bash analysis/te_polymorphism/03_intersect.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"

CANDIDATES="${RESULTS_DIR}/hg38_specific_gap_distal.bed"
MEI_ALL="${RESULTS_DIR}/mei_all.bed"
MEI_ALU="${RESULTS_DIR}/mei_alu.bed"
MEI_LINE1="${RESULTS_DIR}/mei_line1.bed"
DBRIP="${RESULTS_DIR}/dbrip.bed"

for f in "${CANDIDATES}" "${MEI_ALL}"; do
    if [[ ! -f "$f" ]]; then
        echo "[03] ERROR: ${f} not found. Run previous steps first."
        exit 1
    fi
done

# ── Intersect with 1000G MEI (any overlap) ──────────────────────────────────
echo "[03] Intersecting candidates with 1000G MEI (any overlap)..."

bedtools intersect -a "${CANDIDATES}" -b "${MEI_ALL}" -wa -wb \
    > "${RESULTS_DIR}/hits_1000g_any.bed"
HIT_COUNT=$(cut -f1-6 "${RESULTS_DIR}/hits_1000g_any.bed" | sort -u | wc -l)
CAND_COUNT=$(wc -l < "${CANDIDATES}")
echo "[03]   ${HIT_COUNT} / ${CAND_COUNT} candidates overlap any 1000G MEI"

# Per-class breakdown
for cls in alu line1 sva; do
    mei_bed="${RESULTS_DIR}/mei_${cls}.bed"
    [[ -f "${mei_bed}" ]] || continue
    out="${RESULTS_DIR}/hits_1000g_${cls}.bed"
    bedtools intersect -a "${CANDIDATES}" -b "${mei_bed}" -wa -wb > "${out}"
    n=$(cut -f1-6 "${out}" | sort -u | wc -l)
    echo "[03]   ${cls^^}: ${n} candidate hits"
done

# ── Low-frequency MEI hits (AF < 0.05 = rare / population-private) ──────────
echo "[03] Filtering for low-frequency MEIs (AF < 0.05)..."
awk 'BEGIN{OFS="\t"} {
    # column 11 (6 candidate cols + 5th MEI col) = AF
    af = $(NF-1)
    if (af == "NA" || af+0 < 0.05) print
}' "${RESULTS_DIR}/hits_1000g_any.bed" \
> "${RESULTS_DIR}/hits_1000g_lowAF.bed"
LOW_COUNT=$(cut -f1-6 "${RESULTS_DIR}/hits_1000g_lowAF.bed" | sort -u | wc -l)
echo "[03]   ${LOW_COUNT} candidates overlap low-frequency MEIs (AF < 0.05)"

# ── High-frequency MEI hits (AF >= 0.5 = likely fixed in hg38 by design) ────
awk 'BEGIN{OFS="\t"} {
    af = $(NF-1)
    if (af != "NA" && af+0 >= 0.5) print
}' "${RESULTS_DIR}/hits_1000g_any.bed" \
> "${RESULTS_DIR}/hits_1000g_highAF.bed"
HIGH_COUNT=$(cut -f1-6 "${RESULTS_DIR}/hits_1000g_highAF.bed" | sort -u | wc -l)
echo "[03]   ${HIGH_COUNT} candidates overlap high-frequency MEIs (AF >= 0.5)"

# ── Candidates with NO MEI overlap (residual — no polymorphism evidence) ─────
bedtools intersect -a "${CANDIDATES}" -b "${MEI_ALL}" -v \
    > "${RESULTS_DIR}/no_mei_overlap.bed"
NOHIT=$(wc -l < "${RESULTS_DIR}/no_mei_overlap.bed")
echo "[03]   ${NOHIT} candidates have no 1000G MEI overlap"

# ── dbRIP intersection (if available) ────────────────────────────────────────
if [[ -f "${DBRIP}" ]]; then
    echo "[03] Intersecting with dbRIP..."
    bedtools intersect -a "${CANDIDATES}" -b "${DBRIP}" -wa -wb \
        > "${RESULTS_DIR}/hits_dbrip.bed"
    DBRIP_HITS=$(cut -f1-6 "${RESULTS_DIR}/hits_dbrip.bed" | sort -u | wc -l)
    echo "[03]   ${DBRIP_HITS} candidates overlap dbRIP entries"
fi

# ── Summary table ─────────────────────────────────────────────────────────────
SUMMARY="${RESULTS_DIR}/intersection_summary.tsv"
{
    printf "category\tcount\tpct_of_candidates\n"
    printf "total_candidates\t%d\t100.0\n" "${CAND_COUNT}"
    printf "1000g_mei_any_overlap\t%d\t%.1f\n" \
        "${HIT_COUNT}" "$(echo "scale=1; ${HIT_COUNT}*100/${CAND_COUNT}" | bc)"
    printf "1000g_mei_lowAF_(AF<0.05)\t%d\t%.1f\n" \
        "${LOW_COUNT}" "$(echo "scale=1; ${LOW_COUNT}*100/${CAND_COUNT}" | bc)"
    printf "1000g_mei_highAF_(AF>=0.5)\t%d\t%.1f\n" \
        "${HIGH_COUNT}" "$(echo "scale=1; ${HIGH_COUNT}*100/${CAND_COUNT}" | bc)"
    printf "no_mei_overlap\t%d\t%.1f\n" \
        "${NOHIT}" "$(echo "scale=1; ${NOHIT}*100/${CAND_COUNT}" | bc)"
    if [[ -f "${DBRIP}" ]]; then
        printf "dbrip_overlap\t%d\t%.1f\n" \
            "${DBRIP_HITS}" "$(echo "scale=1; ${DBRIP_HITS}*100/${CAND_COUNT}" | bc)"
    fi
} > "${SUMMARY}"

echo "[03] Summary written: ${SUMMARY}"
echo "[03] Done."
