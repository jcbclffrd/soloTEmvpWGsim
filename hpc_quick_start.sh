#!/bin/bash
##############################################################################
# Quick Start: Complete HPC Setup from Fresh Clone
#
# This script guides you through the complete setup process on HPC.
# Run this after cloning the repository for the first time.
##############################################################################

set -e

echo "============================================"
echo "soloTEmvpWGsim - HPC Quick Start"
echo "============================================"
echo ""
echo "This script will guide you through:"
echo "  1. HPC account configuration"
echo "  2. Conda environment setup"
echo "  3. Reference download and index building"
echo "  4. Pipeline execution"
echo ""
echo "Prerequisites:"
echo "  - You are on an HPC login node"
echo "  - You have access to miniconda/anaconda modules"
echo "  - You have ~60 GB disk space available"
echo ""
read -p "Press Enter to continue or Ctrl+C to exit..."
echo ""

# ==============================================================================
# Step 1: Configure HPC Account
# ==============================================================================
echo "============================================"
echo "Step 1: Configure HPC Account"
echo "============================================"
echo ""

CURRENT_ACCOUNT=$(grep "#SBATCH -A" sbatch_run_pipeline.sh | awk '{print $3}')
echo "Current account: $CURRENT_ACCOUNT"
echo ""
read -p "Enter your HPC account name (or press Enter to keep '$CURRENT_ACCOUNT'): " NEW_ACCOUNT

if [ -n "$NEW_ACCOUNT" ] && [ "$NEW_ACCOUNT" != "$CURRENT_ACCOUNT" ]; then
    echo "Updating sbatch scripts to use account: $NEW_ACCOUNT"
    bash configure_hpc_account.sh <<< "$NEW_ACCOUNT"
else
    echo "Keeping current account: $CURRENT_ACCOUNT"
fi

echo ""

# ==============================================================================
# Step 2: Conda Environment Setup
# ==============================================================================
echo "============================================"
echo "Step 2: Conda Environment Setup"
echo "============================================"
echo ""
echo "Conda setup requires an interactive compute node."
echo ""
echo "You have two options:"
echo ""
echo "  A) Run conda setup NOW via srun (recommended)"
echo "  B) Skip for now and run manually later"
echo ""
read -p "Choose option (A/B): " CONDA_OPTION

if [[ "$CONDA_OPTION" =~ ^[Aa]$ ]]; then
    echo ""
    echo "Requesting interactive node (this may take a few minutes)..."
    echo ""
    
    # Create a script to run in the interactive session
    cat > /tmp/conda_setup_$$.sh << 'EOF'
#!/bin/bash
echo "On interactive node, setting up conda..."
echo ""

# Try to find miniconda module
CONDA_MODULE=$(module avail miniconda 2>&1 | grep -i miniconda | head -1 | awk '{print $1}')

if [ -z "$CONDA_MODULE" ]; then
    echo "ERROR: No miniconda module found"
    echo "Available modules:"
    module avail 2>&1 | grep -i conda
    exit 1
fi

echo "Loading module: $CONDA_MODULE"
module load $CONDA_MODULE

# Check if conda is initialized
if [ ! -f ~/.mycondainit* ]; then
    echo ""
    echo "Initializing conda for first time..."
    conda init bash
    
    echo ""
    echo "IMPORTANT: Move conda initialization to separate file"
    echo "This prevents conda from loading automatically in all sessions"
    echo ""
    echo "Run these commands manually after this script:"
    echo "  1. Edit ~/.bashrc"
    echo "  2. Find lines between '>>> conda initialize >>>' and '<<< conda initialize <<<'"
    echo "  3. Cut those lines and paste into ~/.mycondainit"
    echo ""
    read -p "Press Enter after you've moved the conda init lines..."
fi

# Source conda
if [ -f ~/.mycondainit ]; then
    . ~/.mycondainit
elif [ -f ~/.mycondainit-* ]; then
    . $(ls ~/.mycondainit-* | head -1)
else
    echo "ERROR: Conda init file not found"
    exit 1
fi

# Accept TOS if needed
echo "Accepting conda Terms of Service..."
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true

# Create environment
if conda env list | grep -q "solote_validation"; then
    echo "Environment 'solote_validation' already exists"
else
    echo ""
    echo "Creating conda environment (this takes ~5-10 minutes)..."
    conda env create -f environment.yml
fi

echo ""
echo "✓ Conda environment ready!"
EOF

    chmod +x /tmp/conda_setup_$$.sh
    srun -c 4 -p free --pty /tmp/conda_setup_$$.sh
    rm /tmp/conda_setup_$$.sh
    
    echo ""
    echo "✓ Conda setup complete!"
else
    echo ""
    echo "Skipping conda setup. Run manually with:"
    echo "  srun -c 4 -p free --pty /bin/bash -i"
    echo "  # Then follow conda setup instructions in HPC_SETUP.md"
fi

echo ""

# ==============================================================================
# Step 3: Submit Setup Jobs
# ==============================================================================
echo "============================================"
echo "Step 3: Submit Setup Jobs"
echo "============================================"
echo ""
echo "This will submit SLURM jobs to:"
echo "  1. Download T2T genome and annotations (~20 min)"
echo "  2. Build STAR index (~40 min)"
echo "  3. Install soloTE (~5 min)"
echo ""
read -p "Submit setup jobs now? (y/N): " SUBMIT_SETUP

if [[ "$SUBMIT_SETUP" =~ ^[Yy]$ ]]; then
    cd setup
    
    echo ""
    echo "Submitting reference download job..."
    REF_JOB=$(sbatch sbatch_00_setup_references.sh | awk '{print $4}')
    echo "  Job ID: $REF_JOB"
    
    echo ""
    echo "Submitting STAR index build (dependent on reference download)..."
    STAR_JOB=$(sbatch --dependency=afterok:$REF_JOB sbatch_01_build_star_index.sh | awk '{print $4}')
    echo "  Job ID: $STAR_JOB"
    
    echo ""
    echo "Submitting soloTE installation (dependent on STAR index)..."
    SOLOTE_JOB=$(sbatch --dependency=afterok:$STAR_JOB sbatch_02_install_solote.sh | awk '{print $4}')
    echo "  Job ID: $SOLOTE_JOB"
    
    cd ..
    
    echo ""
    echo "✓ Setup jobs submitted!"
    echo ""
    echo "Monitor progress with:"
    echo "  squeue -u \$USER"
    echo "  tail -f logs/setup_refs_${REF_JOB}.out"
    echo "  tail -f logs/build_star_${STAR_JOB}.out"
    echo ""
    echo "Setup will complete in ~60 minutes total"
    echo ""
    
    # Ask about pipeline
    echo "============================================"
    echo "Step 4: Submit Pipeline (Optional)"
    echo "============================================"
    echo ""
    read -p "Submit pipeline job to run after setup completes? (y/N): " SUBMIT_PIPELINE
    
    if [[ "$SUBMIT_PIPELINE" =~ ^[Yy]$ ]]; then
        PIPELINE_JOB=$(sbatch --dependency=afterok:$SOLOTE_JOB sbatch_run_pipeline.sh | awk '{print $4}')
        echo ""
        echo "✓ Pipeline job submitted: $PIPELINE_JOB"
        echo ""
        echo "The pipeline will automatically start when setup completes"
        echo "Check results later with:"
        echo "  cat validation_report/validation_metrics.tsv"
    fi
else
    echo ""
    echo "Skipping automatic submission."
    echo "Run setup manually with:"
    echo "  cd setup"
    echo "  sbatch sbatch_00_setup_references.sh"
    echo "  sbatch sbatch_01_build_star_index.sh"
    echo "  sbatch sbatch_02_install_solote.sh"
fi

echo ""
echo "============================================"
echo "Quick Start Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  - Monitor jobs: squeue -u \$USER"
echo "  - View logs: ls -lt logs/"
echo "  - Read detailed guide: cat HPC_SETUP.md"
echo "  - Check pipeline status: cat PIPELINE_STATUS.md"
echo ""
echo "After setup completes, run the pipeline with:"
echo "  sbatch sbatch_run_pipeline.sh"
echo ""
