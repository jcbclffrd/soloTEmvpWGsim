#!/bin/bash
##############################################################################
# Pipeline Script 03: Merge TE and Gene Transcriptomes
#
# Concatenates the TE FASTA and gene FASTA into a single combined transcriptome
# used by the read simulator (step 04).
#
# Input:  synthetic_data/transcriptome/synthetic_transcriptome.fa  (TEs)
#         synthetic_data/transcriptome/gene_transcriptome.fa       (genes)
# Output: synthetic_data/transcriptome/combined_transcriptome.fa
##############################################################################

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

echo "================================================================================"
echo "Pipeline Step 03: Merge TE and Gene Transcriptomes"
echo "================================================================================"
echo ""

TE_FA="synthetic_data/transcriptome/synthetic_transcriptome.fa"
GENE_FA="synthetic_data/transcriptome/gene_transcriptome.fa"
COMBINED_FA="synthetic_data/transcriptome/combined_transcriptome.fa"

for f in "$TE_FA" "$GENE_FA"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Missing input: $f"
    echo "Run scripts/02_extract_sequences.sh and scripts/02g_extract_gene_sequences.sh first."
    exit 1
  fi
done

N_TE=$(grep -c "^>" "$TE_FA")
N_GENE=$(grep -c "^>" "$GENE_FA")

echo "  TE sequences:   ${N_TE}"
echo "  Gene sequences: ${N_GENE}"

cat "$TE_FA" "$GENE_FA" > "$COMBINED_FA"

N_COMBINED=$(grep -c "^>" "$COMBINED_FA")
echo "  Combined total: ${N_COMBINED}"
echo ""
echo "✓ Written: $COMBINED_FA"
echo ""
echo "================================================================================"
echo "Step 03 Complete!"
echo "================================================================================"
echo ""
echo "Next step: Create expression profile"
echo "  Rscript scripts/03_create_expression_profile.R"
echo ""
