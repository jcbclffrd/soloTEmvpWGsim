#!/bin/bash
##############################################################################
# Pipeline Script 4: Simulate RNA-seq Reads
#
# This script uses wgsim to generate synthetic paired-end RNA-seq reads
# from the TE transcriptome.
#
# Input: synthetic_data/transcriptome/synthetic_transcriptome.fa
#        synthetic_data/transcriptome/expression_profile.tsv
# Output: synthetic_data/fastqs/synthetic_reads_R1.fastq
#         synthetic_data/fastqs/synthetic_reads_R2.fastq
#
# Note: Reads are generated WITHOUT barcodes initially. Barcodes are added
#       in the next step (05_add_barcodes.py) to properly simulate 10x format.
##############################################################################

set -e
set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

echo "================================================================================"
echo "Pipeline Step 4: Simulate RNA-seq Reads"
echo "================================================================================"
echo ""

# Check dependencies
if ! command -v wgsim &> /dev/null; then
    echo "ERROR: wgsim not found"
    echo "Please activate conda environment: conda activate solote_validation"
    exit 1
fi

# Load config parameters (basic shell parsing)
READ_LENGTH=$(grep "read_length:" config.yaml | awk '{print $2}')
N_CELLS=$(grep "n_cells:" config.yaml | awk '{print $2}')
READS_PER_CELL=$(grep "reads_per_cell:" config.yaml | awk '{print $2}')
RANDOM_SEED=$(grep "random_seed:" config.yaml | awk '{print $2}')

# Calculate total reads
TOTAL_READS=$((N_CELLS * READS_PER_CELL))

# Paths
TRANSCRIPTOME="synthetic_data/transcriptome/synthetic_transcriptome.fa"
OUTPUT_DIR="synthetic_data/fastqs"
R1_FASTQ="$OUTPUT_DIR/synthetic_reads_R1.fastq"
R2_FASTQ="$OUTPUT_DIR/synthetic_reads_R2.fastq"

echo "Configuration:"
echo "  Transcriptome: $TRANSCRIPTOME"
echo "  Read length: ${READ_LENGTH}bp"
echo "  Cells: $N_CELLS"
echo "  Reads per cell: $READS_PER_CELL"
echo "  Total reads: $(numfmt --grouping $TOTAL_READS || echo $TOTAL_READS)"
echo "  Random seed: $RANDOM_SEED"
echo ""

# Check input
if [[ ! -f "$TRANSCRIPTOME" ]]; then
    echo "ERROR: Transcriptome not found: $TRANSCRIPTOME"
    echo "Please run: bash scripts/02_extract_sequences.sh"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# ==============================================================================
# Simulate Reads with wgsim
# ==============================================================================
echo "Simulating reads with wgsim..."
echo ""
echo "Parameters:"
echo "  -e 0.001    # Base error rate (0.1%)"
echo "  -r 0.0      # Mutation rate (0% - perfect matches)"
echo "  -R 0.0      # Indel fraction (0% - no indels)"
echo "  -1 $READ_LENGTH  # Read 1 length"
echo "  -2 $READ_LENGTH  # Read 2 length"
echo "  -N $TOTAL_READS  # Number of read pairs"
echo "  -S $RANDOM_SEED  # Random seed"
echo ""
echo "This may take a few minutes..."
echo "Started: $(date)"
echo ""

# Run wgsim
# Note: -d 300 sets insert size to 300bp (typical for 10x)
# Note: -s 50 sets insert size standard deviation
wgsim \
    -e 0.001 \
    -r 0.0 \
    -R 0.0 \
    -1 $READ_LENGTH \
    -2 $READ_LENGTH \
    -d 300 \
    -s 50 \
    -N $TOTAL_READS \
    -S $RANDOM_SEED \
    "$TRANSCRIPTOME" \
    "$R1_FASTQ" \
    "$R2_FASTQ"

echo ""
echo "✓ Read simulation complete"
echo "Finished: $(date)"
echo ""

# ==============================================================================
# Validation
# ==============================================================================
echo "Validating output..."
echo ""

# Count reads
R1_READS=$(grep -c "^@" "$R1_FASTQ" || true)
R2_READS=$(grep -c "^@" "$R2_FASTQ" || true)

echo "  R1 reads: $(numfmt --grouping $R1_READS || echo $R1_READS)"
echo "  R2 reads: $(numfmt --grouping $R2_READS || echo $R2_READS)"

if [[ $R1_READS -ne $R2_READS ]]; then
    echo "  WARNING: R1 and R2 read counts don't match"
fi

echo ""

# Show first few reads
echo "  Example R1 read (first read):"
head -4 "$R1_FASTQ" | sed 's/^/    /'
echo ""

# File sizes
echo "  File sizes:"
du -h "$R1_FASTQ" "$R2_FASTQ" | sed 's/^/    /'
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "Step 4 Complete!"
echo "================================================================================"
echo ""
echo "Synthetic reads generated:"
echo "  R1: $R1_FASTQ"
echo "  R2: $R2_FASTQ"
echo "  Total read pairs: $(numfmt --grouping $R1_READS || echo $R1_READS)"
echo ""
echo "NOTE: These reads do NOT yet have cell barcodes or UMIs."
echo "      The next step will add 10x-style barcodes."
echo ""
echo "Next step: Add 10x cell barcodes and UMIs"
echo "  python scripts/05_add_barcodes.py"
echo ""

# EXTENSION POINT: Alternative Read Simulators
# ---------------------------------------------
# To use ART-illumina for more realistic quality scores:
#
# art_illumina \
#     -ss HS25 \            # HiSeq 2500 error profile
#     -i "$TRANSCRIPTOME" \
#     -p \                  # Paired-end
#     -l $READ_LENGTH \
#     -f $COVERAGE \        # Coverage (calculate from UMI counts)
#     -m 300 \              # Mean insert size
#     -s 50 \               # Insert size std dev
#     -rs $RANDOM_SEED \
#     -o "$OUTPUT_DIR/synthetic_reads"
