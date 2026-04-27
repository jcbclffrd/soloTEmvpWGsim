#!/bin/bash
#SBATCH --job-name=redownload_genome
#SBATCH --output=../logs/redownload_genome_%j.out
#SBATCH --error=../logs/redownload_genome_%j.err
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --partition=free
#SBATCH -A vswarup_lab

################################################################################
# Fix Genome Download: Replace RefSeq with chr-named T2T version
#
# Issue: Pipeline step 2 fails because chromosome names don't match
#   - Current genome: NC_060925.1, NC_060926.1, etc. (RefSeq accessions)
#   - RepeatMasker: chr1, chr2, chr3, etc. (chr naming)
#   - Solution: Download T2T consortium version with chr naming
#
# Runtime: ~5-10 minutes (936 MB download)
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

echo "============================================"
echo "SLURM Job: Redownload T2T Genome (chr naming)"
echo "============================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 4G"
echo "Started: $(date)"
echo "============================================"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
GENOME_DIR="$REPO_ROOT/references/genome"

cd "$GENOME_DIR"

echo "Current directory: $PWD"
echo ""

# ==============================================================================
# Remove Old RefSeq Genome
# ==============================================================================
echo "============================================"
echo "1. Removing old RefSeq genome"
echo "============================================"
echo ""

if [[ -f "T2T-CHM13v2.0.fa.refseq_backup" ]]; then
    echo "Removing RefSeq backup (saves disk space)..."
    rm -f T2T-CHM13v2.0.fa.refseq_backup
    rm -f T2T-CHM13v2.0.fa.fai.refseq_backup
    echo "✓ Old genome removed"
else
    echo "No RefSeq backup found (already cleaned?)"
fi

echo ""

# ==============================================================================
# Download T2T Genome with chr Naming
# ==============================================================================
echo "============================================"
echo "2. Downloading T2T genome (chr naming)"
echo "============================================"
echo ""

GENOME_URL="https://s3-us-west-2.amazonaws.com/human-pangenomics/T2T/CHM13/assemblies/analysis_set/chm13v2.0.fa.gz"
GENOME_FILE="T2T-CHM13v2.0.fa.gz"
GENOME_FA="T2T-CHM13v2.0.fa"

if [[ -f "$GENOME_FA" ]]; then
    echo "✓ Genome already exists: $GENOME_FA"
    echo "  Checking if it has chr naming..."
    
    # Check chromosome naming
    FIRST_CHR=$(grep "^>" "$GENOME_FA" | head -1)
    if echo "$FIRST_CHR" | grep -q "^>chr"; then
        echo "✓ Genome has chr naming, no redownload needed"
    else
        echo "⚠ Genome has wrong naming, removing and redownloading..."
        rm -f "$GENOME_FA" "$GENOME_FA.fai"
    fi
fi

if [[ ! -f "$GENOME_FA" ]]; then
    echo "Downloading T2T genome from T2T Consortium (AWS S3)..."
    echo "  Source: $GENOME_URL"
    echo "  Target: $GENOME_FILE"
    echo "  Size: ~936 MB (uncompressed: ~3 GB)"
    echo ""
    
    wget -O "$GENOME_FILE" "$GENOME_URL"
    
    echo ""
    echo "✓ Download complete"
    echo ""
    
    # Decompress
    echo "Decompressing genome..."
    gunzip "$GENOME_FILE"
    echo "✓ Genome decompressed: $GENOME_FA"
fi

echo ""

# ==============================================================================
# Index Genome
# ==============================================================================
echo "============================================"
echo "3. Indexing genome with samtools"
echo "============================================"
echo ""

# Load conda environment (has samtools)
module load miniconda3/25.11.1
source ~/.mycondainit-25.11.1
conda activate solote_validation

if [[ ! -f "${GENOME_FA}.fai" ]]; then
    echo "Indexing genome with samtools faidx..."
    samtools faidx "$GENOME_FA"
    echo "✓ Genome indexed: ${GENOME_FA}.fai"
else
    echo "✓ Genome index already exists: ${GENOME_FA}.fai"
fi

echo ""

# Verify chromosome naming
echo "Verifying chromosome naming..."
echo "First 3 chromosomes:"
grep "^>" "$GENOME_FA" | head -3
echo ""

FIRST_CHR=$(grep "^>" "$GENOME_FA" | head -1)
if echo "$FIRST_CHR" | grep -q "^>chr"; then
    echo "✓ Genome has correct chr naming (matches RepeatMasker)"
else
    echo "⚠ WARNING: Genome does not have chr naming!"
    echo "  This will cause bedtools extraction to fail"
    exit 1
fi

echo ""
echo "============================================"
echo "Job Complete"
echo "============================================"
echo "Finished: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo ""
echo "Next: Rebuild STAR index with new genome"
echo "  sbatch setup/sbatch_01_build_star_index.sh"
