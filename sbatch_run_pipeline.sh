#!/bin/bash
##############################################################################
# Sbatch Wrapper: Run Complete Validation Pipeline
#
# Submit this script with: sbatch sbatch_run_pipeline.sh
# Monitor job with: squeue -u $USER
# Check logs in: logs/pipeline_*.{out,err}
##############################################################################

#SBATCH --job-name=solote_pipeline
#SBATCH --output=logs/pipeline_%j.out
#SBATCH --error=logs/pipeline_%j.err
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --partition=free
#SBATCH -A vswarup_lab

echo "============================================"
echo "SLURM Job: soloTEmvpWGsim Pipeline"
echo "============================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 32G"
echo "Started: $(date)"
echo "============================================"
echo ""

# Load conda environment
echo "Loading conda environment..."
module load miniconda3/25.11.1
source ~/.mycondainit-25.11.1
conda activate solote_validation

echo "✓ Environment activated"
echo ""

# Run the pipeline
bash scripts/run_pipeline.sh

echo ""
echo "============================================"
echo "Job Complete"
echo "============================================"
echo "Finished: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo ""
echo "Check validation results in validation_report/"
echo ""
