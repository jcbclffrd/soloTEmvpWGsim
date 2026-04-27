#!/bin/bash
##############################################################################
# SLURM Job: Run Steps 6-8 Only (Alignment -> soloTE -> Validation)
# 
# Use this to test UMI fix without rerunning the entire pipeline
##############################################################################

#SBATCH --job-name=solote_validate
#SBATCH --output=logs/validate_%j.out
#SBATCH --error=logs/validate_%j.err
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --partition=standard
#SBATCH -A vswarup_lab

set -e

echo "============================================"
echo "soloTE Validation Test (Steps 6-8)"
echo "============================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Started: $(date)"
echo ""

# Load conda
module load miniconda3/25.11.1
source ~/.mycondainit-25.11.1
conda activate solote_validation

# Change to repo directory
cd /dfs7/swaruplab/jcliffo1/soloTEmvpWGsim

echo "Step 6: STAR alignment..."
bash scripts/06_align_starsolo.sh

echo ""
echo "Step 7: soloTE quantification..."
bash scripts/07_run_solote.sh

echo ""
echo "Step 8: Validation..."
Rscript scripts/08_validate_results.R

echo ""
echo "============================================"
echo "Job Complete"
echo "============================================"
echo "Finished: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo ""
echo "Check validation results in validation_report/"
