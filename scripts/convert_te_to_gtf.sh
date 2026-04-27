#!/bin/bash
##############################################################################
# Convert TE loci BED to GTF format for STAR index
#
# Creates a minimal GTF file from selected TE loci so STARsolo can run
##############################################################################

set -e
set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

INPUT_BED="ground_truth/selected_te_loci.bed"
OUTPUT_GTF="references/annotations/selected_te_loci.gtf"

echo "Converting TE loci from BED to GTF format..."
echo "  Input: $INPUT_BED"
echo "  Output: $OUTPUT_GTF"
echo ""

# Create GTF from BED
# GTF format: chr source feature start end score strand frame attributes
awk 'BEGIN {OFS="\t"} {
    # BED is 0-based, GTF is 1-based
    start = $2 + 1
    end = $3
    chr = $1
    name = $4
    strand = $6
    
    # Create gene and transcript attributes
    gene_id = name
    transcript_id = name "_transcript"
    
    # Gene feature
    print chr, "TE_annotation", "gene", start, end, ".", strand, ".", "gene_id \"" gene_id "\"; gene_name \"" name "\"; gene_type \"TE\";"
    
    # Exon feature (required for STAR)
    print chr, "TE_annotation", "exon", start, end, ".", strand, ".", "gene_id \"" gene_id "\"; transcript_id \"" transcript_id "\"; gene_name \"" name "\"; gene_type \"TE\";"
}' "$INPUT_BED" > "$OUTPUT_GTF"

echo "✓ GTF created: $OUTPUT_GTF"
echo ""

# Show first few lines
echo "First 5 entries:"
head -5 "$OUTPUT_GTF"
echo ""

# Count features
N_GENES=$(grep -c "gene" "$OUTPUT_GTF" || true)
N_EXONS=$(grep -c "exon" "$OUTPUT_GTF" || true)
echo "Summary:"
echo "  Genes: $N_GENES"
echo "  Exons: $N_EXONS"
echo ""
