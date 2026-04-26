#!/bin/bash
##############################################################################
# Pipeline Script 6: Align Synthetic Reads with STARsolo
#
# This script aligns the synthetic 10x-formatted fastq files to the T2T
# genome using STARsolo, matching the parameters used in production pipelines.
#
# Input: synthetic_data/fastqs/synthetic_10x_S1_L001_R1_001.fastq.gz
#        synthetic_data/fastqs/synthetic_10x_S1_L001_R2_001.fastq.gz
# Output: synthetic_data/outputs/star_alignment/Aligned.sortedByCoord.out.bam
##############################################################################

set -e
set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

echo "================================================================================"
echo "Pipeline Step 6: STARsolo Alignment"
echo "================================================================================"
echo ""

# Check if STAR is available
if ! command -v STAR &> /dev/null; then
    echo "ERROR: STAR not found"
    echo "Please activate conda environment: conda activate solote_validation"
    exit 1
fi

echo "✓ STAR version:"
STAR --version
echo ""

# Load config
STAR_INDEX=$(grep "star_index:" config.yaml | awk '{print $2}')
THREADS=$(grep "threads:" config.yaml | grep -A1 "alignment:" | tail -1 | awk '{print $2}')
CB_START=$(grep "cb_start:" config.yaml | awk '{print $2}')
CB_LEN=$(grep "cb_len:" config.yaml | awk '{print $2}')
UMI_START=$(grep "umi_start:" config.yaml | awk '{print $2}')
UMI_LEN=$(grep "umi_len:" config.yaml | awk '{print $2}')

# Paths
R1_FASTQ="synthetic_data/fastqs/synthetic_10x_S1_L001_R1_001.fastq.gz"
R2_FASTQ="synthetic_data/fastqs/synthetic_10x_S1_L001_R2_001.fastq.gz"
CELL_BARCODES="synthetic_data/transcriptome/cell_barcodes.txt"
OUTPUT_DIR="synthetic_data/outputs/star_alignment"

echo "Configuration:"
echo "  STAR index: $STAR_INDEX"
echo "  Input R1: $R1_FASTQ"
echo "  Input R2: $R2_FASTQ"
echo "  Cell barcode whitelist: $CELL_BARCODES"
echo "  Output directory: $OUTPUT_DIR"
echo "  Threads: $THREADS"
echo ""

# Validate inputs
if [[ ! -f "$R1_FASTQ" ]] || [[ ! -f "$R2_FASTQ" ]]; then
    echo "ERROR: Input fastq files not found"
    echo "Please run: python scripts/05_add_barcodes.py"
    exit 1
fi

if [[ ! -d "$STAR_INDEX" ]] || [[ ! -f "$STAR_INDEX/SA" ]]; then
    echo "ERROR: STAR index not found: $STAR_INDEX"
    echo "Please run: bash setup/01_build_star_index.sh"
    exit 1
fi

if [[ ! -f "$CELL_BARCODES" ]]; then
    echo "ERROR: Cell barcodes not found: $CELL_BARCODES"
    echo "Please run: Rscript scripts/03_create_expression_profile.R"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# ==============================================================================
# Run STARsolo Alignment
# ==============================================================================
echo "Running STARsolo alignment..."
echo ""
echo "Parameters (matched to production pipeline):"
echo "  --outFilterMultimapNmax 100        # Keep reads mapping to 2-100 loci"
echo "  --winAnchorMultimapNmax 100        # Anchor multi-mapper limit"
echo "  --outSAMmultNmax 1                 # Output only best alignment"
echo "  --outMultimapperOrder Random       # Randomize multi-mapper choice"
echo "  --runRNGseed 777                   # Reproducible randomization"
echo ""
echo "This will take 5-15 minutes depending on dataset size..."
echo "Started: $(date)"
echo ""

STAR \
    --runThreadN "$THREADS" \
    --genomeDir "$REPO_ROOT/$STAR_INDEX" \
    --readFilesCommand zcat \
    --readFilesIn "$REPO_ROOT/$R2_FASTQ" "$REPO_ROOT/$R1_FASTQ" \
    --soloType CB_UMI_Simple \
    --soloCBwhitelist "$REPO_ROOT/$CELL_BARCODES" \
    --soloCBstart "$CB_START" \
    --soloCBlen "$CB_LEN" \
    --soloUMIstart "$UMI_START" \
    --soloUMIlen "$UMI_LEN" \
    --soloBarcodeReadLength 0 \
    --soloFeatures Gene GeneFull \
    --soloCBmatchWLtype 1MM_multi_Nbase_pseudocounts \
    --soloUMIfiltering MultiGeneUMI_CR \
    --soloUMIdedup 1MM_CR \
    --outSAMattributes NH HI AS nM CR CY UR UY CB UB GX GN \
    --outSAMtype BAM SortedByCoordinate \
    --outFileNamePrefix ./ \
    --limitBAMsortRAM 30000000000 \
    --outFilterMultimapNmax 100 \
    --winAnchorMultimapNmax 100 \
    --outSAMmultNmax 1 \
    --outMultimapperOrder Random \
    --runRNGseed 777

echo ""
echo "✓ STARsolo alignment complete"
echo "Finished: $(date)"
echo ""

cd "$REPO_ROOT"

# ==============================================================================
# Validation
# ==============================================================================
echo "Validating output..."
echo ""

BAM_FILE="$OUTPUT_DIR/Aligned.sortedByCoord.out.bam"

if [[ ! -f "$BAM_FILE" ]]; then
    echo "ERROR: BAM file not created: $BAM_FILE"
    exit 1
fi

echo "✓ Found BAM file: $BAM_FILE"

# Index BAM
if command -v samtools &> /dev/null; then
    echo "Indexing BAM file..."
    samtools index "$BAM_FILE"
    echo "✓ BAM indexed"
    echo ""
    
    # Get alignment statistics
    echo "Alignment statistics:"
    samtools flagstat "$BAM_FILE" | sed 's/^/  /'
    echo ""
fi

# Check Solo.out
SOLO_DIR="$OUTPUT_DIR/Solo.out"
if [[ -d "$SOLO_DIR" ]]; then
    echo "✓ STARsolo outputs found: $SOLO_DIR"
    echo ""
    
    # Check for Gene matrices
    GENE_FILTERED="$SOLO_DIR/Gene/filtered"
    if [[ -d "$GENE_FILTERED" ]]; then
        N_CELLS=$(wc -l < "$GENE_FILTERED/barcodes.tsv")
        N_GENES=$(wc -l < "$GENE_FILTERED/features.tsv")
        echo "  Gene expression (filtered):"
        echo "    Cells: $N_CELLS"
        echo "    Features: $N_GENES"
    fi
fi

echo ""

# File size
du -h "$BAM_FILE" | sed 's/^/  BAM size: /'
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "Step 6 Complete!"
echo "================================================================================"
echo ""
echo "Alignment outputs:"
echo "  BAM: $BAM_FILE"
echo "  STARsolo outputs: $OUTPUT_DIR/Solo.out/"
echo ""
echo "Next step: Run soloTE quantification"
echo "  bash scripts/07_run_solote.sh"
echo ""
