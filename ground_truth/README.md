# Ground Truth

This directory contains the selected TE loci used for validation.

## Generated Files

After running `Rscript scripts/01_select_te_loci.R`:

- `selected_te_loci.tsv` - Ground truth metadata table
- `selected_te_loci.bed` - BED format for bedtools

## selected_te_loci.tsv Format

| Column | Description |
|--------|-------------|
| `locus_id` | Unique locus identifier (e.g., TE_001) |
| `locus_name` | Genomic coordinates (chr:start-end(strand)) |
| `chr` | Chromosome |
| `start` | Start position (1-based) |
| `end` | End position |
| `strand` | Strand (+/-) |
| `te_name` | TE instance name |
| `te_family` | TE family (Alu, L1, L2, etc.) |
| `te_class` | TE class (SINE, LINE, LTR, etc.) |
| `length` | TE length (bp) |
| `score` | RepeatMasker divergence score |

## Selection Criteria

Configured in `config.yaml`:

- Target families: Alu, L1, L2, MIR, ERVL-MaLR, hAT-Charlie
- Well-separated: ≥100kb between loci
- Size range: 200-6000 bp
- Main chromosomes only (chr1-22, X)

## Purpose

This ground truth enables validation by comparing:
- **Detection**: Which TEs were detected by soloTE?
- **Quantification**: Do observed UMI counts match expected?
