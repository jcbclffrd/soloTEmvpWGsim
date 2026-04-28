#!/bin/bash
##############################################################################
# Master Pipeline Runner
#
# This script runs the complete validation pipeline from start to finish:
#   1. Select TE loci
#   2. Extract sequences
#   3. Create expression profile
#   4. Simulate reads
#   5. Add barcodes
#   6. Align with STARsolo
#   7. Run soloTE quantification
#   8. Validate results
#
# Usage: bash scripts/run_pipeline.sh
##############################################################################

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

echo "================================================================================"
echo "soloTEmvpWGsim - Complete Validation Pipeline"
echo "================================================================================"
echo ""
echo "This will run all 8 pipeline steps sequentially."
echo "Estimated total runtime: 30-60 minutes"
echo ""
echo "Started: $(date)"
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
# Archive previous run and clean data folders
# ==============================================================================
echo "================================================================================"
echo "Step 0/8: Archive previous run and clean data folders"
echo "================================================================================"
echo ""
bash scripts/00_archive_and_clean.sh
echo ""

# ==============================================================================
# Run Pipeline Steps
# ==============================================================================
STEPS=(
    "01_select_te_loci.R|Select TE loci from RepeatMasker"
    "02_extract_sequences.sh|Extract TE sequences from genome"
    "03_create_expression_profile.R|Create expression profile"
    "04_simulate_reads.sh|Simulate RNA-seq reads"
    "05_add_barcodes.py|Add 10x cell barcodes and UMIs"
    "06_align_starsolo.sh|Align reads with STARsolo"
    "07_run_solote.sh|Run soloTE quantification"
    "08_validate_results.R|Validate against ground truth"
)

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
