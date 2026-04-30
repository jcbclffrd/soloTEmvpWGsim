#!/usr/bin/env bash
# Download 1000 Genomes Phase 3 SV VCF (includes MEI: ALU, LINE1, SVA)
# and optionally dbRIP BED.
# Run from repo root: bash analysis/te_polymorphism/00_download.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
mkdir -p "${DATA_DIR}"

# ── 1000 Genomes Phase 3 merged SV VCF ──────────────────────────────────────
VCF_URL="ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/integrated_sv_map/ALL.wgs.mergedSV.v8.20130502.svs.genotypes.vcf.gz"
VCF_OUT="${DATA_DIR}/1000g_sv.vcf.gz"
TBI_OUT="${DATA_DIR}/1000g_sv.vcf.gz.tbi"

if [[ ! -f "${VCF_OUT}" ]]; then
    echo "[00] Downloading 1000G SV VCF (~1.5 GB)..."
    wget -q --show-progress -O "${VCF_OUT}" "${VCF_URL}"
else
    echo "[00] ${VCF_OUT} already exists, skipping."
fi

# Tabix index (needed for bcftools queries)
TBI_URL="${VCF_URL}.tbi"
if [[ ! -f "${TBI_OUT}" ]]; then
    echo "[00] Downloading tabix index..."
    wget -q --show-progress -O "${TBI_OUT}" "${TBI_URL}" || {
        echo "[00] Remote index not available — building locally (requires tabix)."
        tabix -p vcf "${VCF_OUT}"
    }
else
    echo "[00] Tabix index already exists, skipping."
fi

# ── dbRIP (optional, may be intermittently unavailable) ──────────────────────
DBRIP_URL="http://dbrip.brocku.ca/downloads/alldbRIP.csv"
DBRIP_OUT="${DATA_DIR}/dbRIP_raw.csv"

if [[ ! -f "${DBRIP_OUT}" ]]; then
    echo "[00] Attempting dbRIP download (may fail if site is down)..."
    wget -q --show-progress --timeout=30 -O "${DBRIP_OUT}" "${DBRIP_URL}" \
        && echo "[00] dbRIP downloaded." \
        || { echo "[00] WARNING: dbRIP download failed — site may be unavailable. Skipping."; rm -f "${DBRIP_OUT}"; }
else
    echo "[00] ${DBRIP_OUT} already exists, skipping."
fi

echo "[00] Done."
