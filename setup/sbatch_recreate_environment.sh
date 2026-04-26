#!/bin/bash
##############################################################################
# Sbatch Wrapper: Recreate Conda Environment with CPython
#
# This script removes the existing PyPy environment and creates a new one
# with CPython to fix pysam compatibility.
#
# Submit with: sbatch setup/sbatch_recreate_environment.sh
##############################################################################

#SBATCH --job-name=recreate_conda_env
#SBATCH --output=logs/recreate_env_%j.out
#SBATCH --error=logs/recreate_env_%j.err
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --partition=free
#SBATCH -A vswarup_lab

echo "============================================"
echo "SLURM Job: Recreate Conda Environment"
echo "============================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 16G"
echo "Started: $(date)"
echo "============================================"
echo ""

# Load conda
echo "Loading conda module..."
module load miniconda3/25.11.1
source ~/.mycondainit-25.11.1

echo "✓ Conda loaded"
echo ""

# Remove old environment
echo "============================================"
echo "Removing Old Environment (PyPy)"
echo "============================================"
echo ""

if conda env list | grep -q "solote_validation"; then
    echo "Removing existing solote_validation environment..."
    conda env remove -n solote_validation -y
    echo "✓ Old environment removed"
else
    echo "No existing environment found (OK)"
fi

echo ""

# Create new environment with CPython
echo "============================================"
echo "Creating New Environment (CPython)"
echo "============================================"
echo ""

cd /dfs7/swaruplab/jcliffo1/soloTEmvpWGsim

echo "Creating environment from environment.yml..."
echo "This will take approximately 10-15 minutes..."
echo ""

conda env create -f environment.yml

echo ""
echo "✓ Environment created"
echo ""

# Activate and verify
echo "============================================"
echo "Verifying Installation"
echo "============================================"
echo ""

conda activate solote_validation

echo "Python implementation:"
python3 -c "import sys; print('  ', sys.implementation.name, sys.version)"
echo ""

echo "Testing critical imports..."

# Test pysam
if python3 -c "import pysam; print('✓ pysam:', pysam.__version__)" 2>&1; then
    PYSAM_OK=1
else
    echo "❌ pysam import FAILED"
    PYSAM_OK=0
fi

# Test other imports
python3 -c "import numpy; print('✓ numpy:', numpy.__version__)"
python3 -c "import pandas; print('✓ pandas:', pandas.__version__)"
python3 -c "import Bio; print('✓ biopython:', Bio.__version__)"

echo ""

# Test tools
echo "Tool versions:"
samtools --version | head -1 | sed 's/^/  /'
bedtools --version | sed 's/^/  /'
STAR --version | sed 's/^/  /'

echo ""

# Summary
echo "============================================"
echo "Recreation Complete"
echo "============================================"
echo ""

if [ $PYSAM_OK -eq 1 ]; then
    echo "✅ SUCCESS: pysam now works correctly"
    echo ""
    echo "The pipeline is now ready to run!"
else
    echo "❌ FAILURE: pysam still broken"
    echo ""
    echo "Manual intervention required"
fi

echo ""
echo "Finished: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo ""
