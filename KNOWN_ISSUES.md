# Known Issues

Status as of commit following `v0.1-hpc-uci` tag (UCI HPC3, T2T-CHM13v2.0, STAR 2.7.11b, soloTE v1.10).

---

## Issue #1: STAR index built without real gene annotation (ROOT CAUSE of poor validation metrics)

### Symptoms

After applying the UMI-generation fixes (commit `33fbc91`), pipeline run `51492015` produced:

- ✅ Recall: 100% (all 10 ground-truth TEs detected)
- ❌ Precision: 0.4% (2,468 detected loci vs. 10 expected → 2,458 false positives)
- ❌ Per-locus undercounting: observed 600–3,798 UMIs/locus vs. expected 10,000 (62–94 % error)
- Correlation metrics: NA (not computable with this distribution)

See [validation_report/validation_metrics.tsv](validation_report/validation_metrics.tsv) and
[validation_report/per_locus_accuracy.tsv](validation_report/per_locus_accuracy.tsv).

### Root cause

The STARsolo index in [references/STARsolo_index/](references/STARsolo_index/) was built with
`references/annotations/selected_te_loci.gtf` — a GTF containing **only the 10 selected TE loci
treated as "gene" features**. There is no real gene annotation in the index.

soloTE's pipeline ([software/SoloTE/SoloTE_pipeline.py](software/SoloTE/SoloTE_pipeline.py))
relies on STARsolo's `GN` (gene name) BAM tag to partition reads:

1. Reads aligned to a feature in the index GTF receive a `GN` tag → routed to `_genes.bam`
   and counted as **genes** in the final matrix (line 243 onwards).
2. Reads with no `GN` tag → routed to `_nogenes.bam`, then intersected against the full
   RepeatMasker BED (4.6 M loci) and counted as **TE loci** (locus / subfamily / family levels).

In the current setup:

- Reads from our 10 ground-truth TEs land on the GTF features → tagged with `GN=TE_001..TE_010`
  → **counted as genes, not as TE loci**. This is the source of the per-locus undercounting:
  the `*_locustes_MATRIX/` only sees the multi-mapping spillover, not the primary signal.
- Reads that multi-map to other Alu / L1 / L2 loci elsewhere in the genome have no GTF feature
  there → no `GN` tag → fed into the TE annotation step → smeared across thousands of
  RepeatMasker entries. This is the source of the 2,458 false-positive loci.

### Why one bug explains both symptoms

Same misconfiguration drives both:

| Observation | Mechanism |
|---|---|
| 90 % of UMIs at subfamily / family level | Primary reads tagged `GN` and removed from TE pipeline; only multi-mapper spill remains |
| 2,468 false-positive loci | Multi-mappers to genomic Alu/L1 copies are untagged and re-annotated against the full RepeatMasker BED |
| Locus counts 600–3,798 instead of 10,000 | Locus-level matrix only catches the leftover non-genic alignments |

### Fix (not yet applied — requires compute budget)

Rebuild the STAR index using a **real gene GTF** for T2T-CHM13v2.0
(e.g. CHM13 GENCODE/RefSeq liftover) instead of `selected_te_loci.gtf`. Then soloTE's
gene-vs-TE partition behaves as designed:

- Real gene reads → gene counts.
- Reads on selected TE loci → no overlapping gene feature → routed through TE annotation →
  counted at locus / family / subfamily resolution against the RepeatMasker BED.

Estimated cost on UCI HPC3: ~22 SU (16 CPU × ~80 min) for the rebuild plus one validation run.

### Workarounds considered

- **Run with `--dual` flag in soloTE**: would also count genic reads as TEs, but does not solve
  the locus-resolution problem because the underlying GTF is still wrong.
- **Drop the GTF from STAR index**: would lose splice-junction awareness; STARsolo still requires
  a GTF for `--soloFeatures Gene`. Would need to also drop `--soloFeatures Gene`.
- **Filter the RepeatMasker BED** to just our 10 loci before soloTE: would reduce false positives
  but would mask the actual scientific question (how does soloTE perform genome-wide?).

The clean fix is to rebuild with a real gene GTF.

---

## Issue #2: Synthetic FASTQ contains TE reads only (no gene reads)

`scripts/02_extract_sequences.sh` builds the synthetic transcriptome from
`ground_truth/selected_te_loci.bed` only, and `wgsim` simulates reads only from those 10 TE
sequences. This is a *harder* case than real scRNA-seq (where genes dominate ~90 %+ of reads),
and it interacts badly with Issue #1.

Not necessarily a bug — TE-only is a reasonable controlled-experiment design — but worth
recording. If Issue #1 is fixed, the validation should still pass on TE-only input.

---

## Issue #3: soloTE locus resolution limit on highly repetitive families (expected behavior)

Even with Issue #1 fixed, perfect locus-level recovery is unlikely for Alu / L1 because
identical / near-identical paralogs cannot be distinguished by short reads. Expect aggregation
at subfamily/family level for these. Validation thresholds in `scripts/08_validate_results.R`
may need to be relaxed to per-family rather than per-locus accuracy for these families.
