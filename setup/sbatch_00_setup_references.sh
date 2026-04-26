#!/bin/bash
#SBATCH --job-name=setup_refs        # Job name
#SBATCH --output=logs/setup_refs_%j.out  # Standard output (%j = job ID)
#SBATCH --error=logs/setup_refs_%j.err   # Standard error
#SBATCH --time=01:00:00              # Time limit (1 hour)
#SBATCH --ntasks=1                   # Number of tasks
#SBATCH --cpus-per-task=2            # CPUs per task
#SBATCH --mem=4G                     # Memory per node
#SBATCH --partition=free             # Partition name

# Exit on error
set -e

echo "Job started: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo ""

# Load conda module and activate environment
module load miniconda3/25.11.1
source ~/.mycondainit-25.11.1
conda activate solote_validation

# Run the setup script
bash setup/00_setup_references.sh

echo ""
echo "Job completed: $(date)"
