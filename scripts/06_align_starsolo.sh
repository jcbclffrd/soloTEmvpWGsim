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
# Get threads from alignment section
THREADS=$(grep -A 20 "^alignment:" config.yaml | grep "threads:" | awk '{print $2}')
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

# STARsolo parameter reference:
#
#  General:
#   --runThreadN               number of parallel threads
#   --genomeDir                pre-built STAR genome index directory
#   --readFilesCommand zcat    decompress gzipped FASTQs on the fly
#   --readFilesIn R2 R1        R2 first (cDNA), R1 second (CB+UMI) — STARsolo convention
#
#  10x barcode / UMI:
#   --soloType CB_UMI_Simple   10x Chromium v2/v3: fixed-position CB and UMI on R1
#   --soloCBwhitelist          list of valid cell barcodes to match against
#   --soloCBstart              R1 position where cell barcode starts (1-based; = 1)
#   --soloCBlen                cell barcode length in bp (10x v3 = 16)
#   --soloUMIstart             R1 position where UMI starts (= CB_START + CB_LEN = 17)
#   --soloUMIlen               UMI length in bp (10x v3 = 12)
#   --soloBarcodeReadLength 0  do not enforce R1 length check (R1 is CB+UMI only, 28bp)
#
#  Quantification:
#   --soloFeatures Gene                         quantify at gene level (soloTE re-quantifies at TE level post-hoc)
#   --soloCBmatchWLtype 1MM_multi_Nbase_...     allow 1 mismatch in CB; resolve ambiguous matches with pseudocounts (Cell Ranger default)
#   --soloUMIfiltering MultiGeneUMI_CR          discard UMIs mapping to >1 gene (Cell Ranger method)
#   --soloUMIdedup 1MM_CR                       collapse UMIs with 1 mismatch using directional method (Cell Ranger default)
#
#  BAM output:
#   --outSAMattributes NH HI AS nM CR CY UR UY CB UB GX GN
#                              NH=hit count, HI=hit index, CR/CY=raw CB+qual, UR/UY=raw UMI+qual,
#                              CB/UB=corrected CB/UMI, GX/GN=gene ID/name
#   --outSAMtype BAM SortedByCoordinate   coordinate-sorted BAM (required by soloTE)
#   --outFileNamePrefix ./     write all output to current working directory
#   --limitBAMsortRAM          max RAM for BAM sorting in bytes (30 GB)
#
#  Multi-mapper handling (critical for repetitive TEs):
#   --outFilterMultimapNmax 100   keep reads mapping to up to 100 loci
#   --winAnchorMultimapNmax 100   max loci for anchor seeds (must match outFilterMultimapNmax)
#   --outSAMmultNmax 1            write only 1 alignment per multi-mapping read to BAM
#   --outMultimapperOrder Random  choose which alignment to output for multi-mappers at random
#   --runRNGseed                  random seed for reproducibility of multi-mapper selection
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
    --soloFeatures Gene \
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

# Convert BAM to SAM so both formats are available for inspection.
# BAM is kept for downstream tools (soloTE, samtools, IGV);
# SAM is human-readable for manual inspection.
echo "Converting BAM to SAM..."
samtools view -h Aligned.sortedByCoord.out.bam > Aligned.sortedByCoord.out.sam
sam_size=$(du -sh Aligned.sortedByCoord.out.sam | cut -f1)
bam_size=$(du -sh Aligned.sortedByCoord.out.bam | cut -f1)
echo "  BAM: $bam_size   SAM: $sam_size"
echo "✓ SAM written"
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
