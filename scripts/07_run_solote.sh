#!/bin/bash
##############################################################################
# Pipeline Script 7: Run soloTE Quantification
#
# This script runs soloTE on the aligned BAM file to generate locus-level
# TE quantification.
#
# Input: synthetic_data/outputs/star_alignment/Aligned.sortedByCoord.out.bam
# Output: synthetic_data/outputs/solote/synthetic_validation_SoloTE_output/
##############################################################################

set -e
set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

echo "================================================================================"
echo "Pipeline Step 7: soloTE Quantification"
echo "================================================================================"
echo ""

# Check dependencies
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found"
    echo "Please activate conda environment: conda activate solote_validation"
    exit 1
fi

if ! command -v samtools &> /dev/null; then
    echo "ERROR: samtools not found"
    echo "Please activate conda environment: conda activate solote_validation"
    exit 1
fi

# Load config
SOLOTE_DIR=$(grep "solote_dir:" config.yaml | awk '{print $2}')
REPEATMASKER_BED=$(grep "repeatmasker_bed:" config.yaml | awk '{print $2}')
THREADS=$(grep "threads:" config.yaml | grep -A1 "solote:" | tail -1 | awk '{print $2}')
OUTPUT_PREFIX=$(grep "output_prefix:" config.yaml | awk '{print $2}')

# Paths
BAM_FILE="synthetic_data/outputs/star_alignment/Aligned.sortedByCoord.out.bam"
OUTPUT_DIR="synthetic_data/outputs/solote"

echo "Configuration:"
echo "  soloTE directory: $SOLOTE_DIR"
echo "  Input BAM: $BAM_FILE"
echo "  RepeatMasker BED: $REPEATMASKER_BED"
echo "  Output directory: $OUTPUT_DIR"
echo "  Output prefix: $OUTPUT_PREFIX"
echo "  Threads: $THREADS"
echo ""

# Validate inputs
if [[ ! -f "$BAM_FILE" ]]; then
    echo "ERROR: BAM file not found: $BAM_FILE"
    echo "Please run: bash scripts/06_align_starsolo.sh"
    exit 1
fi

if [[ ! -f "$REPEATMASKER_BED" ]]; then
    echo "ERROR: RepeatMasker file not found: $REPEATMASKER_BED"
    echo "Please run: bash setup/00_setup_references.sh"
    exit 1
fi

SOLOTE_SCRIPT="$SOLOTE_DIR/SoloTE_pipeline.py"
if [[ ! -f "$SOLOTE_SCRIPT" ]]; then
    echo "ERROR: soloTE not found: $SOLOTE_SCRIPT"
    echo "Please run: bash setup/02_install_solote.sh"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# ==============================================================================
# Run soloTE
# ==============================================================================
echo "Running soloTE quantification..."
echo ""
echo "soloTE quantification strategy:"
echo "  - Unique mappers (MAPQ ≥ 255) → Locus-level counts"
echo "  - Multi-mappers (MAPQ < 255) → Family-level counts"
echo ""
echo "This may take 10-30 minutes depending on BAM size..."
echo "Started: $(date)"
echo ""

python3 "$SOLOTE_SCRIPT" \
    --threads "$THREADS" \
    --bam "$BAM_FILE" \
    --teannotation "$REPEATMASKER_BED" \
    --outputprefix "$OUTPUT_PREFIX" \
    --outputdir "$OUTPUT_DIR"

echo ""
echo "✓ soloTE quantification complete"
echo "Finished: $(date)"
echo ""

# ==============================================================================
# Validation
# ==============================================================================
echo "Validating soloTE outputs..."
echo ""

SOLOTE_OUTPUT="$OUTPUT_DIR/${OUTPUT_PREFIX}_SoloTE_output"

if [[ ! -d "$SOLOTE_OUTPUT" ]]; then
    echo "ERROR: soloTE output directory not found: $SOLOTE_OUTPUT"
    exit 1
fi

echo "✓ Found soloTE output directory: $SOLOTE_OUTPUT"
echo ""

# List output matrices
echo "soloTE output matrices:"
for matrix_dir in "$SOLOTE_OUTPUT"/*_MATRIX; do
    if [[ -d "$matrix_dir" ]]; then
        matrix_name=$(basename "$matrix_dir")
        
        if [[ -f "$matrix_dir/barcodes.tsv" ]] && \
           [[ -f "$matrix_dir/features.tsv" ]] && \
           [[ -f "$matrix_dir/matrix.mtx" ]]; then
            
            n_barcodes=$(wc -l < "$matrix_dir/barcodes.tsv")
            n_features=$(wc -l < "$matrix_dir/features.tsv")
            
            echo "  $matrix_name"
            echo "    Cells: $n_barcodes"
            echo "    Features: $n_features"
        fi
    fi
done

echo ""

# Check for locus-level matrix (most important for validation)
LOCUS_MATRIX="$SOLOTE_OUTPUT/${OUTPUT_PREFIX}_locustes_MATRIX"
if [[ -d "$LOCUS_MATRIX" ]]; then
    echo "✓ Locus-level TE matrix found: $LOCUS_MATRIX"
    
    N_CELLS=$(wc -l < "$LOCUS_MATRIX/barcodes.tsv")
    N_LOCI=$(wc -l < "$LOCUS_MATRIX/features.tsv")
    
    echo "  Cells detected: $N_CELLS"
    echo "  TE loci detected: $N_LOCI"
    echo ""
    
    echo "  First few detected TE loci:"
    head -5 "$LOCUS_MATRIX/features.tsv" | sed 's/^/    /'
else
    echo "WARNING: Locus-level matrix not found"
fi

echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "Step 7 Complete!"
echo "================================================================================"
echo ""
echo "soloTE outputs:"
echo "  Directory: $SOLOTE_OUTPUT"
echo ""
echo "Key outputs for validation:"
echo "  - Locus-level matrix: ${OUTPUT_PREFIX}_locustes_MATRIX/"
echo "  - Family-level matrix: ${OUTPUT_PREFIX}_familytes_MATRIX/"
echo "  - Subfamily-level matrix: ${OUTPUT_PREFIX}_subfamilytes_MATRIX/"
echo ""
echo "Next step: Validate results against ground truth"
echo "  Rscript scripts/08_validate_results.R"
echo ""
