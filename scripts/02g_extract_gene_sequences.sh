#!/bin/bash
##############################################################################
# Pipeline Script 02g: Extract Gene Sequences from Genome
#
# Uses bedtools getfasta to pull each selected gene's sequence, then appends
# a synthetic poly-A tail so the 3' read simulator can capture it the same
# way it captures TE sequences.
#
# Input:  ground_truth/selected_gene_loci.bed
# Output: synthetic_data/transcriptome/gene_transcriptome.fa
##############################################################################

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

echo "================================================================================"
echo "Pipeline Step 02g: Extract Gene Sequences from Genome"
echo "================================================================================"
echo ""

# Load config
GENOME_FA=$(grep "genome_fasta:" config.yaml | awk '{print $2}')
POLY_A_LEN=$(grep "poly_a_length:" config.yaml | awk '{print $2}')
POLY_A_LEN=${POLY_A_LEN:-50}

GENE_BED="ground_truth/selected_gene_loci.bed"
OUTPUT_DIR="synthetic_data/transcriptome"
RAW_FA="$OUTPUT_DIR/gene_sequences_raw.fa"
OUTPUT_FA="$OUTPUT_DIR/gene_transcriptome.fa"

echo "Configuration:"
echo "  Genome: $GENOME_FA"
echo "  Gene BED: $GENE_BED"
echo "  Poly-A tail length: ${POLY_A_LEN} bp"
echo "  Output: $OUTPUT_FA"
echo ""

if [[ ! -f "$GENE_BED" ]]; then
  echo "ERROR: Gene BED not found: $GENE_BED"
  echo "Please run: Rscript scripts/01g_select_genes.R"
  exit 1
fi

if [[ ! -f "$GENOME_FA" ]]; then
  echo "ERROR: Genome FASTA not found: $GENOME_FA"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Extract sequences, honoring strand (reverse-complement for minus-strand genes)
echo "Extracting gene sequences..."
bedtools getfasta \
  -name \
  -s \
  -fi "$GENOME_FA" \
  -bed "$GENE_BED" \
  -fo "$RAW_FA"

N_SEQS=$(grep -c "^>" "$RAW_FA")
echo "  Extracted ${N_SEQS} sequences"
echo ""

# Append poly-A tail to each sequence so the 3'-end simulator can capture it.
# Real mRNAs have a ~200 bp poly-A tail; we use a shorter synthetic tail.
POLY_A=$(python3 -c "print('A' * ${POLY_A_LEN})")

echo "Appending ${POLY_A_LEN}-bp poly-A tail to each sequence..."

# Process FASTA: for each record append poly-A on a new line
python3 - <<PYEOF
fasta_in  = "$RAW_FA"
fasta_out = "$OUTPUT_FA"
poly_a    = "A" * ${POLY_A_LEN}

with open(fasta_in) as fh_in, open(fasta_out, "w") as fh_out:
    name, parts = None, []
    for line in fh_in:
        line = line.rstrip()
        if line.startswith(">"):
            if name:
                seq = "".join(parts) + poly_a
                fh_out.write(f">{name}\n{seq}\n")
            # Rename header: GENE_001::chr1:1000-2000(+) -> keep as-is
            name, parts = line[1:], []
        else:
            parts.append(line)
    if name:
        seq = "".join(parts) + poly_a
        fh_out.write(f">{name}\n{seq}\n")

print(f"  Written: {fasta_out}")
PYEOF

echo ""
echo "Sequence lengths (including ${POLY_A_LEN}-bp poly-A tail):"
awk '/^>/{if(seq) printf "  %s: %d bp\n", name, length(seq); name=$0; seq=""} \
     !/^>/{seq=seq$0} \
     END{if(seq) printf "  %s: %d bp\n", name, length(seq)}' "$OUTPUT_FA" | head -10

rm -f "$RAW_FA"

echo ""
echo "================================================================================"
echo "Step 02g Complete!"
echo "================================================================================"
echo ""
echo "Next step: Merge TE and gene transcriptomes"
echo "  bash scripts/03_merge_transcriptomes.sh"
echo ""
