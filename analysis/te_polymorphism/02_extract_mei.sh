#!/usr/bin/env bash
# Extract ALU, LINE1, and SVA mobile element insertion (MEI) calls from the
# 1000 Genomes Phase 3 SV VCF and convert to BED format.
# Run from repo root: bash analysis/te_polymorphism/02_extract_mei.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
RESULTS_DIR="${SCRIPT_DIR}/results"
mkdir -p "${RESULTS_DIR}"

VCF="${DATA_DIR}/1000g_sv.vcf.gz"
if [[ ! -f "${VCF}" ]]; then
    echo "[02] ERROR: ${VCF} not found. Run 00_download.sh first."
    exit 1
fi

# Check for bcftools or fall back to grep/awk
if command -v bcftools &>/dev/null; then
    USE_BCFTOOLS=1
else
    echo "[02] bcftools not found — using awk/grep (slower)."
    USE_BCFTOOLS=0
fi

extract_mei() {
    local svtype="$1"   # ALU, LINE1, or SVA
    local out_bed="$2"

    if [[ $USE_BCFTOOLS -eq 1 ]]; then
        bcftools view -i "SVTYPE=\"${svtype}\"" "${VCF}" \
        | bcftools query -f '%CHROM\t%POS\t%INFO/END\t%ID\t%INFO/AF\t%INFO/SVTYPE\n' \
        | awk 'BEGIN{OFS="\t"} {
            end = ($3 == "." || $3 == "") ? $2+1 : $3
            af  = ($5 == "." || $5 == "") ? "NA" : $5
            print $1, $2-1, end, $4, af, $6
        }' > "${out_bed}"
    else
        zcat "${VCF}" \
        | grep -v "^#" \
        | awk -v svt="${svtype}" 'BEGIN{OFS="\t"} {
            if ($8 !~ "SVTYPE="svt) next
            # Extract AF
            af = "NA"
            n = split($8, fields, ";")
            for (i=1; i<=n; i++) {
                if (fields[i] ~ /^AF=/) { af = substr(fields[i], 4); break }
            }
            # Extract END
            end_pos = $2
            for (i=1; i<=n; i++) {
                if (fields[i] ~ /^END=/) { end_pos = substr(fields[i], 5)+0; break }
            }
            if (end_pos <= $2) end_pos = $2 + 1
            print $1, $2-1, end_pos, $3, af, svt
        }' > "${out_bed}"
    fi

    COUNT=$(wc -l < "${out_bed}")
    echo "[02]   ${svtype}: ${COUNT} MEIs → ${out_bed}"
}

echo "[02] Extracting MEIs from 1000G VCF..."
extract_mei ALU   "${RESULTS_DIR}/mei_alu.bed"
extract_mei LINE1 "${RESULTS_DIR}/mei_line1.bed"
extract_mei SVA   "${RESULTS_DIR}/mei_sva.bed"

# Combined MEI BED (all three classes)
cat "${RESULTS_DIR}/mei_alu.bed" \
    "${RESULTS_DIR}/mei_line1.bed" \
    "${RESULTS_DIR}/mei_sva.bed" \
| sort -k1,1 -k2,2n \
> "${RESULTS_DIR}/mei_all.bed"

TOTAL=$(wc -l < "${RESULTS_DIR}/mei_all.bed")
echo "[02] Combined MEI BED: ${TOTAL} records → ${RESULTS_DIR}/mei_all.bed"

# ── dbRIP (if downloaded) ────────────────────────────────────────────────────
DBRIP_CSV="${DATA_DIR}/dbRIP_raw.csv"
DBRIP_BED="${RESULTS_DIR}/dbrip.bed"
if [[ -f "${DBRIP_CSV}" ]]; then
    echo "[02] Converting dbRIP CSV → BED..."
    # dbRIP CSV columns vary by version; common layout:
    # ID, family, chr, start, end, strand, population, frequency, ...
    # Try to detect header and find chr/start/end columns
    head -1 "${DBRIP_CSV}"
    awk -F',' 'NR==1{
        for(i=1;i<=NF;i++){
            gsub(/"/,"",$i)
            if($i~/[Cc]hr/) chr_col=i
            if($i~/[Ss]tart/) start_col=i
            if($i~/[Ee]nd/) end_col=i
            if($i~/[Ff]am/) fam_col=i
        }
        next
    }
    {
        gsub(/"/,"")
        if(chr_col && start_col && end_col)
            print $chr_col"\t"$start_col"\t"$end_col"\t"$fam_col
    }' "${DBRIP_CSV}" \
    | sort -k1,1 -k2,2n \
    > "${DBRIP_BED}"
    DBRIP_COUNT=$(wc -l < "${DBRIP_BED}")
    echo "[02] dbRIP BED: ${DBRIP_COUNT} records → ${DBRIP_BED}"
else
    echo "[02] dbRIP CSV not found, skipping."
fi

echo "[02] Done."
