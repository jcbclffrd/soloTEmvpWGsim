# HPC Setup Guide for soloTEmvpWGsim

**Complete guide for running this pipeline on UCI HPC3 (or similar SLURM-based HPC systems)**

---

## Prerequisites

- Access to an HPC cluster with SLURM scheduler
- Miniconda/Anaconda module available
- ~60 GB disk space in your workspace
- Ability to submit batch jobs

---

## Step-by-Step HPC Setup

### 1. Clone Repository

```bash
# Navigate to your workspace
cd /dfs7/swaruplab/$USER  # Adjust path for your HPC

# Clone repository
git clone https://github.com/jcbclffrd/soloTEmvpWGsim.git
cd soloTEmvpWGsim
```

### 2. Setup Conda Environment

**IMPORTANT**: On HPC systems, conda setup requires special handling.

#### First Time Conda Setup (One-Time Only)

```bash
# Get an interactive compute node (required for conda operations)
srun -c 4 -p free --pty /bin/bash -i

# Load miniconda module
module load miniconda3/25.11.1  # Or latest version available

# Initialize conda (one-time)
conda init bash

# IMPORTANT: Move conda initialization to separate file
# This prevents conda from loading automatically in all terminals
# 1. Open ~/.bashrc
# 2. Find lines between ">>> conda initialize >>>" and "<<< conda initialize <<<"
# 3. Cut those lines
# 4. Paste into new file: ~/.mycondainit-25.11.1

# Source conda when needed
. ~/.mycondainit-25.11.1

# Accept conda Terms of Service (one-time)
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create environment (takes ~5-10 minutes)
conda env create -f environment.yml

# Exit interactive node
exit
```

#### Activating Environment in Future Sessions

```bash
# In any new terminal session:
. ~/.mycondainit-25.11.1
conda activate solote_validation
```

### 3. Configure for Your HPC System

Edit SLURM job scripts if needed to match your HPC configuration:

**Files to check**:
- `sbatch_run_pipeline.sh` - Main pipeline
- `setup/sbatch_00_setup_references.sh` - Reference download
- `setup/sbatch_01_build_star_index.sh` - STAR index build
- `setup/sbatch_02_install_solote.sh` - soloTE installation

**Common parameters to adjust**:
```bash
#SBATCH -A your_account_lab    # Your lab/account name
#SBATCH -p standard            # Partition: free, standard, etc.
#SBATCH --time=2:00:00         # Wall time (adjust as needed)
```

The scripts currently use:
- Account: `vswarup_lab` (change if needed)
- Partition: `standard` or `free`

### 4. Run Setup (Via SLURM)

Submit setup jobs to build indices and download references:

```bash
# Submit all setup jobs
cd setup

# Download references (~20 min, ~4 GB download)
sbatch sbatch_00_setup_references.sh

# Wait for job to complete, then check
squeue -u $USER

# Build STAR index (~40 min, needs 40 GB RAM)
sbatch sbatch_01_build_star_index.sh

# Wait for completion
squeue -u $USER

# Install soloTE
sbatch sbatch_02_install_solote.sh
```

**Monitor jobs**:
```bash
# Check queue
squeue -u $USER

# Check logs
tail -f logs/setup_refs_*.out
tail -f logs/build_star_*.out
tail -f logs/install_solote_*.out
```

### 5. Run Pipeline

#### Option A: Submit and Monitor

```bash
# Return to repo root
cd ..

# Submit pipeline
sbatch sbatch_run_pipeline.sh

# Get job ID
JOB_ID=$(squeue -u $USER -n solote_pipeline -h -o "%i")

# Monitor
tail -f logs/pipeline_${JOB_ID}.out
```

#### Option B: Submit with Dependency (Recommended for Fresh Setup)

This ensures the pipeline only starts after the STAR index is built:

```bash
# From repo root
cd setup

# Submit STAR index build
STAR_JOB=$(sbatch sbatch_01_build_star_index.sh | awk '{print $4}')

# Return to root and submit pipeline with dependency
cd ..
bash submit_pipeline_after_index.sh $STAR_JOB

# This will queue the pipeline to start automatically after index build completes
```

### 6. Check Results

```bash
# View validation metrics
cat validation_report/validation_metrics.tsv

# List all outputs
ls -lh validation_report/
ls -lh synthetic_data/outputs/

# View detailed findings
cat PIPELINE_STATUS.md
```

---

## Quick Reference: SLURM Commands

```bash
# Check your jobs
squeue -u $USER

# Check specific job details
scontrol show job <JOBID>

# Cancel a job
scancel <JOBID>

# Check completed jobs
sacct -u $USER --starttime=2026-04-27

# Monitor job output in real-time
tail -f logs/pipeline_*.out

# Check job efficiency
seff <JOBID>
```

---

## Resource Requirements

### Setup Phase

| Step | Time | CPUs | Memory | Disk | 
|------|------|------|--------|------|
| Reference download | 15-20 min | 1 | 4 GB | 4 GB |
| STAR index build | 35-45 min | 16 | 40 GB | 30 GB |
| soloTE install | 2-5 min | 1 | 4 GB | 100 MB |

### Pipeline Execution

| Step | Time | CPUs | Memory | Disk |
|------|------|------|--------|------|
| TE selection | <1 min | 1 | 2 GB | 1 MB |
| Sequence extraction | <1 min | 1 | 2 GB | 10 KB |
| Expression profile | <1 min | 1 | 2 GB | 100 KB |
| Read simulation | 1-2 min | 1 | 2 GB | 200 MB |
| Barcode addition | 2-3 min | 1 | 4 GB | 200 MB |
| STARsolo alignment | 1-2 min | 16 | 35 GB | 60 MB |
| soloTE quantification | 2-3 min | 8 | 8 GB | 50 MB |
| Validation | <1 min | 1 | 4 GB | 5 MB |

**Total pipeline runtime**: ~6-8 minutes  
**Total disk space**: ~60 GB (including references)

---

## Troubleshooting

### Job Fails Immediately

**Check logs**:
```bash
# Look at error log
cat logs/pipeline_*.err

# Common issues:
# - Conda not activated (module load miniconda first)
# - Wrong partition/account
# - Insufficient resources
```

### Out of Memory

**Increase memory allocation** in sbatch script:
```bash
#SBATCH --mem=50G  # Increase from default
```

### Job Stuck in Queue

**Check partition availability**:
```bash
sinfo -p standard  # Check if nodes available
squeue -p standard | wc -l  # Check queue length
```

**Try different partition**:
```bash
#SBATCH -p free  # Or other available partition
```

### Conda Environment Issues

**Recreate environment**:
```bash
# Get interactive node
srun -c 4 -p free --pty /bin/bash -i

# Source conda
. ~/.mycondainit-25.11.1

# Remove old environment
conda env remove -n solote_validation

# Recreate
conda env create -f environment.yml
```

### STAR Index Build Fails

**Check available memory**:
```bash
# STAR index needs ~35-40 GB RAM
# Increase in sbatch script:
#SBATCH --mem=50G
```

---

## File Locations

After successful setup, you'll have:

```
soloTEmvpWGsim/
├── references/
│   ├── genome/T2T-CHM13v2.0.fa (~3 GB)
│   ├── annotations/*.bed
│   └── STARsolo_index/ (~22 GB)
├── software/SoloTE/
├── ground_truth/ (generated by pipeline)
├── synthetic_data/ (generated by pipeline)
├── validation_report/ (generated by pipeline)
└── logs/ (SLURM job logs)
```

---

## Complete Fresh Run Example

```bash
# 1. Clone
git clone https://github.com/jcbclffrd/soloTEmvpWGsim.git
cd soloTEmvpWGsim

# 2. Setup conda (interactive node)
srun -c 4 -p free --pty /bin/bash -i
module load miniconda3/25.11.1
. ~/.mycondainit-25.11.1
conda env create -f environment.yml
exit

# 3. Edit sbatch scripts for your account
sed -i 's/vswarup_lab/YOUR_LAB/g' sbatch_run_pipeline.sh
sed -i 's/vswarup_lab/YOUR_LAB/g' setup/sbatch_*.sh

# 4. Submit setup
cd setup
sbatch sbatch_00_setup_references.sh
# Wait for completion
sbatch sbatch_01_build_star_index.sh
# Wait for completion  
sbatch sbatch_02_install_solote.sh
cd ..

# 5. Run pipeline
sbatch sbatch_run_pipeline.sh

# 6. Check results
tail -f logs/pipeline_*.out
cat validation_report/validation_metrics.tsv
```

---

## Account-Specific Setup

If you need to customize for your lab account, run:

```bash
# Replace account name in all sbatch scripts
find . -name "sbatch*.sh" -exec sed -i 's/vswarup_lab/YOUR_LAB_NAME/g' {} \;

# Verify changes
grep "#SBATCH -A" sbatch_run_pipeline.sh setup/sbatch_*.sh
```

---

## Notes

- **Partition choice**: Use `free` for testing, `standard` for production
- **Time limits**: Adjust `--time` based on your HPC queue policies
- **Disk space**: Ensure adequate quota in your workspace
- **Conda path**: The pipeline assumes conda is available via module load
- **Job dependencies**: Use `submit_pipeline_after_index.sh` for chained jobs

---

## Support

For HPC-specific issues:
1. Check SLURM logs in `logs/` directory
2. Review PIPELINE_STATUS.md for known issues
3. Consult your HPC documentation for resource limits
4. Contact your HPC support team for cluster-specific help
