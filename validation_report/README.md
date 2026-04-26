# Validation Report

This directory contains validation results comparing soloTE output against ground truth.

## Generated Files

After running `Rscript scripts/08_validate_results.R`:

- `validation_metrics.tsv` - Pass/fail metrics
- `validation_plots.pdf` - Visualizations
- `matched_loci.tsv` - Detected TEs matched to ground truth
- `per_locus_accuracy.tsv` - Per-locus count accuracy

## validation_metrics.tsv

Key metrics:

| Metric | Description | Threshold |
|--------|-------------|-----------|
| `precision` | % of detected TEs that are true positives | ≥ 0.95 |
| `recall` | % of true TEs that were detected | ≥ 0.95 |
| `f1_score` | Harmonic mean of precision and recall | - |
| `pearson_r` | Correlation of observed vs. expected UMIs | ≥ 0.90 |
| `overall_pass` | TRUE if all thresholds met | TRUE |

## Interpreting Results

**✓ VALIDATION PASSED** (`overall_pass = TRUE`)
- soloTE accurately detects and quantifies synthetic TE loci
- Ready for use on real single-cell RNA-seq data

**✗ VALIDATION FAILED** (`overall_pass = FALSE`)
- Check `per_locus_accuracy.tsv` to identify problematic TEs
- Review `matched_loci.tsv` for detection issues
- Consider adjusting simulation parameters or investigating soloTE behavior

## validation_plots.pdf

Contains three plots:

1. **Detection Accuracy**: Bar chart of precision, recall, F1 score
2. **Count Accuracy**: Scatter plot of expected vs. observed UMI counts
3. **Per-Locus Error**: Bar chart showing percent error for each TE locus

## Notes

- Results validate soloTE's locus-level TE quantification accuracy
- Ground truth enables controlled testing impossible with real data
- Extension points in scripts allow testing gene contamination, multi-mappers, etc.
