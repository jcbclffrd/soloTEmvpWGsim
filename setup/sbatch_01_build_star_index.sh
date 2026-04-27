#!/bin/bash
##############################################################################
# Sbatch Wrapper: Build STAR Index
#
# Submit this script with: sbatch setup/sbatch_01_build_star_index.sh
# Monitor job with: squeue -u $USER
# Check logs in: logs/build_star_*.{out,err}
##############################################################################

#SBATCH --job-name=build_star_index
#SBATCH --output=logs/build_star_%j.out
#SBATCH --error=logs/build_star_%j.err
#SBATCH --time=01:30:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=40G
#SBATCH --partition=standard
#SBATCH -A vswarup_lab

echo "============================================"
echo "SLURM Job: Build STAR Index"
echo "============================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 40G"
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

# Set threads to match SLURM allocation
export THREADS=$SLURM_CPUS_PER_TASK

# Run STAR index build (automatically answers 'y' to rebuild prompt if exists)
echo "y" | bash setup/01_build_star_index.sh

echo ""
echo "============================================"
echo "Job Complete"
echo "============================================"
echo "Finished: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo ""
