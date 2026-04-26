#!/bin/bash
##############################################################################
# Setup Script 0: Download T2T Reference Genome and Annotations
# 
# This script downloads the T2T-CHM13v2.0 reference genome and RepeatMasker
# annotations needed for the validation pipeline.
#
# Runtime: ~10-15 minutes (depends on internet speed)
# Disk space: ~4 GB
##############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Get script directory (works even if script is symlinked)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "============================================"
echo "Setup Step 0: Download T2T References"
echo "============================================"
echo ""
echo "Repository root: $REPO_ROOT"
echo "Date: $(date)"
echo ""

# Create directories
GENOME_DIR="$REPO_ROOT/references/genome"
ANNOT_DIR="$REPO_ROOT/references/annotations"

mkdir -p "$GENOME_DIR"
mkdir -p "$ANNOT_DIR"

cd "$GENOME_DIR"

# ==============================================================================
# Download T2T-CHM13v2.0 Reference Genome
# ==============================================================================
echo "============================================"
echo "1. Downloading T2T-CHM13v2.0 Genome"
echo "============================================"
echo ""

GENOME_URL="https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/GCF_009914755.1_T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz"
GENOME_FILE="T2T-CHM13v2.0.fa.gz"
GENOME_FA="T2T-CHM13v2.0.fa"

if [[ -f "$GENOME_FA" ]]; then
    echo "✓ Genome already exists: $GENOME_FA"
    echo "  Skipping download"
else
    echo "Downloading T2T genome from NCBI..."
    echo "  Source: $GENOME_URL"
    echo "  Target: $GENOME_FILE"
    echo ""
    echo "This will download ~1 GB (uncompressed: ~3 GB)"
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

# Index genome with samtools
if [[ ! -f "${GENOME_FA}.fai" ]]; then
    echo "Indexing genome with samtools faidx..."
    samtools faidx "$GENOME_FA"
    echo "✓ Genome indexed: ${GENOME_FA}.fai"
else
    echo "✓ Genome index already exists: ${GENOME_FA}.fai"
fi

echo ""

# ==============================================================================
# Download T2T RepeatMasker Annotations
# ==============================================================================
echo "============================================"
echo "2. Downloading RepeatMasker Annotations"
echo "============================================"
echo ""

cd "$ANNOT_DIR"

RMSK_URL="https://hgdownload.soe.ucsc.edu/goldenPath/hs1/bigZips/hs1.rmsk.bed.gz"
RMSK_FILE="T2T-CHM13v2.0_RepeatMasker.bed.gz"
RMSK_BED="T2T-CHM13v2.0_RepeatMasker.bed"

if [[ -f "$RMSK_BED" ]]; then
    echo "✓ RepeatMasker annotations already exist: $RMSK_BED"
    echo "  Skipping download"
else
    echo "Downloading RepeatMasker from UCSC..."
    echo "  Source: $RMSK_URL"
    echo "  Target: $RMSK_FILE"
    echo ""
    
    wget -O "$RMSK_FILE" "$RMSK_URL"
    
    echo ""
    echo "✓ Download complete"
    echo ""
    
    # Decompress
    echo "Decompressing RepeatMasker annotations..."
    gunzip "$RMSK_FILE"
    echo "✓ RepeatMasker decompressed: $RMSK_BED"
fi

echo ""

# ==============================================================================
# Filter RepeatMasker to TE Classes Only (SoloTE Format)
# ==============================================================================
echo "============================================"
echo "3. Filtering RepeatMasker to TE Classes"
echo "============================================"
echo ""

RMSK_FILTERED="T2T-CHM13v2.0_RepeatMasker_SoloTE_filtered.bed"

if [[ -f "$RMSK_FILTERED" ]]; then
    echo "✓ Filtered RepeatMasker already exists: $RMSK_FILTERED"
else
    echo "Filtering RepeatMasker to TE classes only (LINE|SINE|LTR|DNA|RC)..."
    echo ""
    
    # Filter to TE classes and convert to 6-column BED format for soloTE
    # Column 4 format: chrom|start|end|family:subfamily:class|score|strand
    awk 'BEGIN {OFS="\t"}
    {
        # Extract TE class from column 12 (repClass)
        class = $12
        family = $11  # repFamily
        name = $10    # repName
        
        # Filter to TE classes only
        if (class ~ /LINE|SINE|LTR|DNA|RC/) {
            # Create soloTE-compatible name field
            # Format: chr|start|end|name:family:class|score|strand
            name_field = $1 "|" $2 "|" $3 "|" name ":" family ":" class "|" $5 "|" $6
            
            print $1, $2, $3, name_field, $5, $6
        }
    }' "$RMSK_BED" > "$RMSK_FILTERED"
    
    echo "✓ Filtered RepeatMasker created: $RMSK_FILTERED"
    echo ""
    
    # Show statistics
    TOTAL_FEATURES=$(wc -l < "$RMSK_BED")
    TE_FEATURES=$(wc -l < "$RMSK_FILTERED")
    
    echo "Statistics:"
    echo "  Total RepeatMasker features: $(numfmt --grouping $TOTAL_FEATURES || echo $TOTAL_FEATURES)"
    echo "  TE-only features: $(numfmt --grouping $TE_FEATURES || echo $TE_FEATURES)"
    echo "  Filtered out: $(numfmt --grouping $((TOTAL_FEATURES - TE_FEATURES)) || echo $((TOTAL_FEATURES - TE_FEATURES)))"
fi

echo ""

# ==============================================================================
# Optional: Download Gene Annotations (for future extension)
# ==============================================================================
echo "============================================"
echo "4. Downloading Gene Annotations (Optional)"
echo "============================================"
echo ""

GENE_GFF="T2T-CHM13v2.0_RefSeq_Curated_20231005.gff3.gz"
GENE_GFF_DECOMPRESSED="T2T-CHM13v2.0_RefSeq_Curated_20231005.gff3"

if [[ -f "$GENE_GFF_DECOMPRESSED" ]]; then
    echo "✓ Gene annotations already exist: $GENE_GFF_DECOMPRESSED"
else
    echo "Downloading RefSeq gene annotations..."
    echo "Note: This is for future gene contamination testing"
    echo ""
    
    GENE_URL="https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/GCF_009914755.1_T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.gff.gz"
    
    if wget -O "$GENE_GFF" "$GENE_URL" 2>/dev/null; then
        gunzip "$GENE_GFF"
        echo "✓ Gene annotations downloaded and decompressed"
    else
        echo "⚠ Could not download gene annotations (optional, can skip)"
        echo "  You can add these later for gene contamination testing"
    fi
fi

echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "============================================"
echo "Setup Complete!"
echo "============================================"
echo ""
echo "Downloaded files:"
echo "  Genome: $GENOME_DIR/$GENOME_FA"
echo "  Genome index: $GENOME_DIR/${GENOME_FA}.fai"
echo "  RepeatMasker (full): $ANNOT_DIR/$RMSK_BED"
echo "  RepeatMasker (TE-only): $ANNOT_DIR/$RMSK_FILTERED"
if [[ -f "$ANNOT_DIR/$GENE_GFF_DECOMPRESSED" ]]; then
    echo "  Gene annotations: $ANNOT_DIR/$GENE_GFF_DECOMPRESSED"
fi
echo ""
echo "Disk usage:"
du -sh "$GENOME_DIR" "$ANNOT_DIR" | sed 's/^/  /'
echo ""
echo "Next step: Build STAR index"
echo "  bash setup/01_build_star_index.sh"
echo ""
