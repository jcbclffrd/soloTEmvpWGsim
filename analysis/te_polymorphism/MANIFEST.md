# TE Polymorphism Cross-Reference — Download Manifest

**Goal:** Determine what fraction of the ~6,600 gap-distal hg38-specific LINE/SINE
loci (those >50 kb from any hg38 assembly gap) represent genuine polymorphic TE
insertions versus other explanations (segmental duplication errors, annotation
version differences, etc.).

**Input:** `analysis/liftover/results/hg38_to_chm13_unmapped.bed` — 36,480 hg38-specific
LINE/SINE loci filtered from the hg38→CHM13 liftover. The gap-distal subset (~6,600)
is produced by step 01 of this pipeline.

---

## Reference Databases

### 1000 Genomes Phase 3 Mobile Element Insertions (MEI)

| File | Source URL | Size (approx) | Purpose |
|------|-----------|---------------|---------|
| `data/1000g_mei.vcf.gz` | ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/integrated_sv_map/ALL.wgs.mergedSV.v8.20130502.svs.genotypes.vcf.gz | ~1.5 GB | Full SV callset (includes MEI: ALU, LINE1, SVA) |
| `data/1000g_mei_alu.bed` | derived from above | ~5 MB | Alu MEIs only, BED format |
| `data/1000g_mei_line1.bed` | derived from above | ~1 MB | LINE-1 MEIs only, BED format |

**Note:** Filter VCF for SVTYPE=ALU, SVTYPE=LINE1, SVTYPE=SVA.
These represent insertions present in at least one of the 2,504 individuals
from 26 populations. High-frequency insertions (AF > 0.5) are likely in hg38
by design; low-frequency ones (AF < 0.05) are the most interesting candidates.

### dbRIP — Database of Retrotransposon Insertion Polymorphisms

**dbRIP** (database of **R**etrotransposon **I**nsertion **P**olymorphisms) is a
curated database of human-specific TE insertions with known population frequencies.
It focuses on Alu, LINE-1, and SVA elements that are polymorphic (present in some
individuals but not others).

| File | Source URL | Size (approx) | Purpose |
|------|-----------|---------------|---------|
| `data/dbRIP.bed` | http://dbrip.brocku.ca/downloads/ | ~2 MB | All dbRIP MEI loci, BED format |

**Status:** dbRIP site (brocku.ca) may be intermittently unavailable. The 1000G
dataset is the more comprehensive and actively maintained resource.

### gnomAD-SV (optional, most comprehensive)

| File | Source URL | Size (approx) | Purpose |
|------|-----------|---------------|---------|
| `data/gnomad_sv_v4.vcf.gz` | https://gnomad.broadinstitute.org/downloads | ~2 GB | gnomAD v4 SV calls |

---

## Pipeline Steps

| Script | Purpose |
|--------|---------|
| `00_download.sh` | Download 1000G MEI VCF and (optionally) dbRIP BED |
| `01_extract_gap_distal.sh` | Filter hg38-specific unmapped loci to >50 kb from gaps |
| `02_extract_mei.sh` | Extract ALU/LINE1/SVA entries from 1000G VCF → BED |
| `03_intersect.sh` | Intersect gap-distal hg38-specific loci with MEI databases |
| `04_analyze.py` | Summarize overlap: what fraction are known polymorphic insertions? |

---

## Expected Outputs

- Fraction of gap-distal hg38-specific loci overlapping known 1000G MEI calls
- Breakdown by TE class (Alu vs LINE-1 vs other)
- Allele frequency distribution of matching MEIs
- Residual loci with no polymorphism evidence (potential segdup artifacts or
  private insertions)

---

## Cleanup

```bash
rm -rf analysis/te_polymorphism/data/ analysis/te_polymorphism/results/
```
