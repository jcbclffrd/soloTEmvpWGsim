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
ANNOT_DIR="$REPO_ROOT/references/annotations"
INDEX_DIR="$REPO_ROOT/references/STARsolo_index"
GENOME_FA="$GENOME_DIR/T2T-CHM13v2.0.fa"
# Use real gene annotation (chr-named RefSeq Liftoff from T2T consortium)
# This fixes KNOWN_ISSUES.md Issue #1 (TE reads were being tagged as genes)
GENE_GFF3="$ANNOT_DIR/chm13v2.0_RefSeq_Liftoff_v5.1.gff3"
GTF_FILE="$GENE_GFF3"

# Download chr-named gene annotation if not present
mkdir -p "$ANNOT_DIR"
if [[ ! -f "$GENE_GFF3" ]]; then
    echo "Downloading T2T RefSeq Liftoff gene annotation (chr-named)..."
    GFF3_GZ="${GENE_GFF3}.gz"
    GFF3_URL="https://s3-us-west-2.amazonaws.com/human-pangenomics/T2T/CHM13/assemblies/annotation/chm13v2.0_RefSeq_Liftoff_v5.1.gff3.gz"
    wget -O "$GFF3_GZ" "$GFF3_URL"
    gunzip "$GFF3_GZ"
    echo "✓ Gene annotation downloaded: $GENE_GFF3"
else
    echo "✓ Gene annotation already exists: $GENE_GFF3"
fi
echo ""

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
echo "  GTF annotations: $GTF_FILE"
echo "  Output: $INDEX_DIR"
echo "  Threads: ${THREADS:-16}"
echo ""
echo "This will take approximately 20-30 minutes..."
echo "Started: $(date)"
echo ""

# Determine number of threads (use config or default)
THREADS=${THREADS:-16}

# Validate annotation
if [[ ! -f "$GTF_FILE" ]]; then
    echo "ERROR: Gene annotation not found: $GTF_FILE"
    echo "Download failed — check connectivity and re-run this script."
    exit 1
fi

# Build index
# --sjdbGTFtagExonParentTranscript Parent: interpret GFF3 Parent attribute
STAR \
    --runMode genomeGenerate \
    --runThreadN "$THREADS" \
    --genomeDir "$INDEX_DIR" \
    --genomeFastaFiles "$GENOME_FA" \
    --sjdbGTFfile "$GTF_FILE" \
    --sjdbGTFtagExonParentTranscript Parent \
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
