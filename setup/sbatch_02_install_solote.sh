#!/bin/bash
##############################################################################
# Sbatch Wrapper: Install SoloTE
#
# Submit this script with: sbatch setup/sbatch_02_install_solote.sh
# Monitor job with: squeue -u $USER
# Check logs in: logs/install_solote_*.{out,err}
##############################################################################

#SBATCH --job-name=install_solote
#SBATCH --output=logs/install_solote_%j.out
#SBATCH --error=logs/install_solote_%j.err
#SBATCH --time=00:10:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --partition=free

echo "============================================"
echo "SLURM Job: Install SoloTE"
echo "============================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 4G"
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

# Run SoloTE installation (automatically answers 'y' to update prompt if exists)
echo "y" | bash setup/02_install_solote.sh

echo ""
echo "============================================"
echo "Job Complete"
echo "============================================"
echo "Finished: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo ""
