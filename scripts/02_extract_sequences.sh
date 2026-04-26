#!/bin/bash
##############################################################################
# Pipeline Script 2: Extract TE Sequences from Genome
#
# This script uses bedtools getfasta to extract the sequences of selected
# TE loci from the T2T genome, creating a synthetic transcriptome.
#
# Input: ground_truth/selected_te_loci.bed
# Output: synthetic_data/transcriptome/synthetic_transcriptome.fa
##############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Get repository root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

echo "================================================================================"
echo "Pipeline Step 2: Extract TE Sequences from Genome"
echo "================================================================================"
echo ""

# Check if bedtools is available
if ! command -v bedtools &> /dev/null; then
    echo "ERROR: bedtools not found"
    echo "Please activate conda environment: conda activate solote_validation"
    exit 1
fi

# Load config (basic shell parsing of YAML)
GENOME_FA=$(grep "genome_fasta:" config.yaml | awk '{print $2}')

# Paths
GROUND_TRUTH_BED="ground_truth/selected_te_loci.bed"
OUTPUT_DIR="synthetic_data/transcriptome"
OUTPUT_FA="$OUTPUT_DIR/synthetic_transcriptome.fa"

# Check inputs
if [[ ! -f "$GROUND_TRUTH_BED" ]]; then
    echo "ERROR: Ground truth BED file not found: $GROUND_TRUTH_BED"
    echo "Please run: Rscript scripts/01_select_te_loci.R"
    exit 1
fi

if [[ ! -f "$GENOME_FA" ]]; then
    echo "ERROR: Genome FASTA not found: $GENOME_FA"
    echo "Please run: bash setup/00_setup_references.sh"
    exit 1
fi

echo "Configuration:"
echo "  Input BED: $GROUND_TRUTH_BED"
echo "  Genome: $GENOME_FA"
echo "  Output: $OUTPUT_FA"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# ==============================================================================
# Extract Sequences with bedtools getfasta
# ==============================================================================
echo "Extracting TE sequences from genome..."
echo ""

# Use bedtools getfasta with strand information
# -name: Use BED name field as FASTA header
# -s: Honor strand (reverse complement for minus strand)
# -fi: Input FASTA
# -bed: Input BED
# -fo: Output FASTA
bedtools getfasta \
    -name \
    -s \
    -fi "$GENOME_FA" \
    -bed "$GROUND_TRUTH_BED" \
    -fo "$OUTPUT_FA"

echo "✓ Sequences extracted"
echo ""

# ==============================================================================
# Validation and Statistics
# ==============================================================================
echo "Validating output..."
echo ""

# Count sequences
N_SEQS=$(grep -c "^>" "$OUTPUT_FA" || true)
echo "  Sequences in transcriptome: $N_SEQS"

# Get sequence lengths
echo ""
echo "  Sequence lengths:"
awk '/^>/ {if (seq) print length(seq); seq=""; next} {seq=seq$0} END {if (seq) print length(seq)}' "$OUTPUT_FA" | \
    awk '{
        sum+=$1; 
        if(NR==1) {min=$1; max=$1} 
        if($1<min) min=$1; 
        if($1>max) max=$1
    } 
    END {
        printf "    Min: %d bp\n", min
        printf "    Max: %d bp\n", max
        printf "    Mean: %.0f bp\n", sum/NR
    }'

echo ""

# Show first few sequence headers
echo "  First 3 sequences:"
grep "^>" "$OUTPUT_FA" | head -3 | sed 's/^/    /'

echo ""

# Index FASTA for future use
if command -v samtools &> /dev/null; then
    echo "Indexing transcriptome FASTA..."
    samtools faidx "$OUTPUT_FA"
    echo "✓ Index created: ${OUTPUT_FA}.fai"
    echo ""
fi

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "Step 2 Complete!"
echo "================================================================================"
echo ""
echo "Synthetic transcriptome created:"
echo "  Location: $OUTPUT_FA"
echo "  Sequences: $N_SEQS"
echo ""
echo "Next step: Create expression profile"
echo "  Rscript scripts/03_create_expression_profile.R"
echo ""

# EXTENSION POINT: Add Control Genes
# -----------------------------------
# To include housekeeping genes for background signal:
#
# if grep -q "include_genes: true" config.yaml; then
#     GENE_GTF=$(grep "gene_gtf:" config.yaml | awk '{print $2}')
#     
#     # Extract gene sequences (e.g., GAPDH, ACTB, etc.)
#     # ... bedtools getfasta for gene coordinates
#     
#     # Concatenate with TE sequences
#     cat TE_sequences.fa gene_sequences.fa > synthetic_transcriptome.fa
# fi
