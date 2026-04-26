#!/bin/bash
##############################################################################
# Setup Script 1: Build STAR Index for T2T-CHM13v2.0
#
# This script builds the STAR index needed for STARsolo alignment.
#
# Requirements:
#   - STAR aligner (installed via conda environment)
#   - T2T genome (run 00_setup_references.sh first)
#
# Runtime: ~20-30 minutes
# Disk space: ~30 GB
# Memory: ~32 GB RAM recommended
##############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "============================================"
echo "Setup Step 1: Build STAR Index"
echo "============================================"
echo ""
echo "Repository root: $REPO_ROOT"
echo "Date: $(date)"
echo ""

# Check if STAR is available
if ! command -v STAR &> /dev/null; then
    echo "ERROR: STAR not found in PATH"
    echo ""
    echo "Please activate the conda environment first:"
    echo "  conda activate solote_validation"
    echo ""
    echo "If not yet created, run:"
    echo "  conda env create -f environment.yml"
    exit 1
fi

echo "✓ STAR version:"
STAR --version
echo ""

# Paths
GENOME_DIR="$REPO_ROOT/references/genome"
INDEX_DIR="$REPO_ROOT/references/STARsolo_index"
GENOME_FA="$GENOME_DIR/T2T-CHM13v2.0.fa"

# Validate genome exists
if [[ ! -f "$GENOME_FA" ]]; then
    echo "ERROR: T2T genome not found: $GENOME_FA"
    echo ""
    echo "Please run the reference download script first:"
    echo "  bash setup/00_setup_references.sh"
    exit 1
fi

echo "✓ Found T2T genome: $GENOME_FA"
echo ""

# Check if index already exists
if [[ -f "$INDEX_DIR/SA" ]] && [[ -f "$INDEX_DIR/Genome" ]]; then
    echo "============================================"
    echo "STAR Index Already Exists"
    echo "============================================"
    echo ""
    echo "Found existing STAR index in: $INDEX_DIR"
    echo ""
    read -p "Rebuild index? This will take ~20-30 minutes (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping index build"
        echo ""
        echo "Next step: Install soloTE"
        echo "  bash setup/02_install_solote.sh"
        exit 0
    fi
    echo ""
    echo "Removing old index..."
    rm -rf "$INDEX_DIR"/*
fi

# Create index directory
mkdir -p "$INDEX_DIR"

# ==============================================================================
# Build STAR Index
# ==============================================================================
echo "============================================"
echo "Building STAR Index"
echo "============================================"
echo ""
echo "Configuration:"
echo "  Genome: $GENOME_FA"
echo "  Output: $INDEX_DIR"
echo "  Threads: ${THREADS:-16}"
echo ""
echo "This will take approximately 20-30 minutes..."
echo "Started: $(date)"
echo ""

# Determine number of threads (use config or default)
THREADS=${THREADS:-16}

# Build index
STAR \
    --runMode genomeGenerate \
    --runThreadN "$THREADS" \
    --genomeDir "$INDEX_DIR" \
    --genomeFastaFiles "$GENOME_FA" \
    --genomeSAindexNbases 14

echo ""
echo "============================================"
echo "STAR Index Build Complete!"
echo "============================================"
echo ""
echo "Finished: $(date)"
echo ""

# Show index statistics
echo "Index location: $INDEX_DIR"
echo ""
echo "Index files:"
ls -lh "$INDEX_DIR" | grep -v "^total" | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "Disk usage:"
du -sh "$INDEX_DIR" | sed 's/^/  /'
echo ""

echo "Next step: Install soloTE"
echo "  bash setup/02_install_solote.sh"
echo ""
