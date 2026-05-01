#!/bin/bash
##############################################################################
# Master Pipeline Runner
#
# Runs the complete validation pipeline from start to finish, beginning with
# an archive-and-clean of previous outputs (step 0).
#
# Usage:
#   bash scripts/run_pipeline.sh [options]
#
# Options:
#   --no-archive       Delete previous outputs without archiving (faster,
#                      irreversible). Default: archive before cleaning.
#   --keep-N N         Keep only the last N timestamped archives per folder
#                      and remove older ones. Default: 3.
#   --skip-clean       Skip step 0 entirely (keep previous outputs as-is).
#                      Useful when re-running a failed step mid-pipeline.
##############################################################################

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

# ==============================================================================
# Parse Arguments
# ==============================================================================
ARCHIVE_FLAG=""          # empty → archive with retention default
KEEP_N=3                 # keep last 3 archives per folder by default
SKIP_CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-archive)
            ARCHIVE_FLAG="--no-archive"
            shift
            ;;
        --keep-N)
            KEEP_N="$2"
            shift 2
            ;;
        --skip-clean)
            SKIP_CLEAN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: bash scripts/run_pipeline.sh [--no-archive] [--keep-N N] [--skip-clean]"
            exit 1
            ;;
    esac
done

echo "================================================================================"
echo "soloTEmvpWGsim - Complete Validation Pipeline"
echo "================================================================================"
echo ""
echo "Started: $(date)"
echo "Archive mode: ${ARCHIVE_FLAG:-archive (keep last $KEEP_N runs)}"
echo ""

# ==============================================================================
# Activate Conda Environment
# ==============================================================================
echo "Activating conda environment..."

# Source conda initialization (temporarily disable set -u for conda init)
set +u
source "$HOME/miniconda3/etc/profile.d/conda.sh"

# Activate environment
conda activate solote_validation
set -u  # Re-enable exit on undefined variable

echo "✓ Conda environment activated: solote_validation"
echo ""

# ==============================================================================
# Pre-flight Checks
# ==============================================================================
echo "Running pre-flight checks..."
echo ""

# Check if setup has been run
if [[ ! -f "references/genome/T2T-CHM13v2.0.fa" ]]; then
    echo "ERROR: T2T genome not found"
    echo "Please run setup scripts first:"
    echo "  bash setup/00_setup_references.sh"
    echo "  bash setup/01_build_star_index.sh"
    echo "  bash setup/02_install_solote.sh"
    exit 1
fi

if [[ ! -d "references/STARsolo_index" ]] || [[ ! -f "references/STARsolo_index/SA" ]]; then
    echo "ERROR: STAR index not found"
    echo "Please run: bash setup/01_build_star_index.sh"
    exit 1
fi

if [[ ! -f "software/SoloTE/SoloTE_pipeline.py" ]]; then
    echo "ERROR: soloTE not found"
    echo "Please run: bash setup/02_install_solote.sh"
    exit 1
fi

echo "✓ Setup complete, ready to run pipeline"
echo ""

# ==============================================================================
# Build STEPS array (needed before step 0 for step count display)
# ==============================================================================
INCLUDE_GENES=$(grep "include_genes:" config.yaml | awk '{print $2}')

if [[ "$INCLUDE_GENES" == "true" ]]; then
    STEPS=(
        "01_select_te_loci.R|Select TE loci from RepeatMasker"
        "01g_select_genes.R|Select housekeeping genes from GFF3"
        "02_extract_sequences.sh|Extract TE sequences from genome"
        "02g_extract_gene_sequences.sh|Extract gene sequences from genome"
        "03_merge_transcriptomes.sh|Merge TE and gene transcriptomes"
        "03_create_expression_profile.R|Create expression profile (TEs + genes)"
        "04_simulate_reads.py|Simulate 3' scRNA-seq reads (TEs + genes)"
        "05_add_barcodes.py|Add 10x cell barcodes and UMIs"
        "06_align_starsolo.sh|Align reads with STARsolo"
        "07_run_solote.sh|Run soloTE quantification"
        "08_validate_results.R|Validate against ground truth (+ gene bleed check)"
    )
        echo "Gene simulation: ENABLED"
else
    STEPS=(
        "01_select_te_loci.R|Select TE loci from RepeatMasker"
        "02_extract_sequences.sh|Extract TE sequences from genome"
        "03_create_expression_profile.R|Create expression profile"
        "04_simulate_reads.py|Simulate 3' scRNA-seq reads"
        "05_add_barcodes.py|Add 10x cell barcodes and UMIs"
        "06_align_starsolo.sh|Align reads with STARsolo"
        "07_run_solote.sh|Run soloTE quantification"
        "08_validate_results.R|Validate against ground truth"
    )
    echo "Gene simulation: disabled"
fi
echo "Pipeline steps: ${#STEPS[@]} (+ step 0 cleanup)"
echo ""

# ==============================================================================
# Step 0: Archive previous run and clean data folders
# ==============================================================================
if [[ "$SKIP_CLEAN" == "true" ]]; then
    echo "Skipping step 0 (--skip-clean)."
    echo ""
else
    echo "================================================================================"
    echo "Step 0/${#STEPS[@]}: Archive previous run and clean data folders"
    echo "================================================================================"
    echo ""

    CLEAN_ARGS=""
    [[ -n "$ARCHIVE_FLAG" ]] && CLEAN_ARGS="$ARCHIVE_FLAG"
    [[ -z "$ARCHIVE_FLAG" ]] && CLEAN_ARGS="--keep-N $KEEP_N"

    bash scripts/00_archive_and_clean.sh $CLEAN_ARGS
    echo ""
fi

# ==============================================================================
# Run Pipeline Steps
# ==============================================================================
TOTAL_STEPS=${#STEPS[@]}
CURRENT_STEP=0

for step_info in "${STEPS[@]}"; do
    CURRENT_STEP=$((CURRENT_STEP + 1))
    
    script=$(echo "$step_info" | cut -d'|' -f1)
    description=$(echo "$step_info" | cut -d'|' -f2)
    
    echo "================================================================================"
    echo "Step $CURRENT_STEP/$TOTAL_STEPS: $description"
    echo "================================================================================"
    echo ""
    echo "Running: $script"
    echo "Started: $(date)"
    echo ""
    
    step_start=$(date +%s)
    
    # Determine how to run the script based on extension
    if [[ "$script" == *.R ]]; then
        Rscript "scripts/$script"
    elif [[ "$script" == *.py ]]; then
        python "scripts/$script"
    elif [[ "$script" == *.sh ]]; then
        bash "scripts/$script"
    else
        echo "ERROR: Unknown script type: $script"
        exit 1
    fi
    
    step_end=$(date +%s)
    step_duration=$((step_end - step_start))
    
    echo ""
    echo "✓ Step $CURRENT_STEP complete (${step_duration}s)"
    echo ""
done

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "Pipeline Complete!"
echo "================================================================================"
echo ""
echo "Finished: $(date)"
echo ""
echo "All steps completed successfully. Validation results:"
echo "  - Metrics: validation_report/validation_metrics.tsv"
echo "  - Plots: validation_report/validation_plots.pdf"
echo "  - Per-locus accuracy: validation_report/per_locus_accuracy.tsv"
echo ""
echo "Check validation_report/validation_metrics.tsv for pass/fail status."
echo ""
