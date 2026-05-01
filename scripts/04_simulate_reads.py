#!/usr/bin/env python3
"""
Pipeline Script 4: Simulate 3' scRNA-seq Reads

Models 10x Chromium 3' chemistry: the oligo-dT primer anneals to the
poly-A tail and cDNA synthesis proceeds toward the 5' end of the transcript.

R2: cDNA read starting near the 3' end of each sequence (includes poly-A)
R1: placeholder (CB + UMI are prepended in step 05)

When include_genes=true, reads from combined_transcriptome.fa; total reads
per cell are derived from the expression profile (sum of target_umis per cell).
TE reads and gene reads are mixed proportionally to their expression levels.

Input:  synthetic_data/transcriptome/combined_transcriptome.fa  (or synthetic_transcriptome.fa)
        synthetic_data/transcriptome/expression_profile.tsv
Output: synthetic_data/fastqs/synthetic_reads_R1.fastq
        synthetic_data/fastqs/synthetic_reads_R2.fastq
"""

import sys
import random
from pathlib import Path
from collections import defaultdict
import csv
import yaml

print("=" * 80)
print("Pipeline Step 4: Simulate 3' scRNA-seq Reads")
print("=" * 80)
print()

# ==============================================================================
# Load Configuration
# ==============================================================================
with open("config.yaml") as f:
    config = yaml.safe_load(f)

READ_LENGTH    = config["simulation"]["read_length"]
N_CELLS        = config["simulation"]["n_cells"]
READS_PER_CELL = config["simulation"]["reads_per_cell"]
RANDOM_SEED    = config["simulation"]["random_seed"]
INCLUDE_GENES  = config.get("extensions", {}).get("include_genes", False)

random.seed(RANDOM_SEED)

# Variation in where the oligo-dT primer anneals within the poly-A tail.
# The primer always lands IN the poly-A, so the read always ends within
# the poly-A region. Keep this smaller than the typical poly-A tail length
# (~15-25bp for Alu/L1) so every read captures at least some poly-A.
PRIME_JITTER = 10

print("Configuration:")
print(f"  Read length: {READ_LENGTH}bp")
print(f"  Cells: {N_CELLS}")
print(f"  Include genes: {INCLUDE_GENES}")
print(f"  Random seed: {RANDOM_SEED}")
print(f"  3'-end priming jitter: {PRIME_JITTER}bp")
print()

# ==============================================================================
# Load Transcriptome FASTA
# ==============================================================================
# Use combined (TE + gene) when include_genes=true, TE-only otherwise.
combined_fa = Path("synthetic_data/transcriptome/combined_transcriptome.fa")
te_only_fa  = Path("synthetic_data/transcriptome/synthetic_transcriptome.fa")

if INCLUDE_GENES and combined_fa.exists():
    fasta_file = combined_fa
elif te_only_fa.exists():
    fasta_file = te_only_fa
else:
    print("ERROR: No transcriptome FASTA found.")
    print("Run scripts/02_extract_sequences.sh (and 02g/03 if using genes).")
    sys.exit(1)

print(f"Loading transcriptome: {fasta_file}")
sequences = {}
with open(fasta_file) as f:
    name, parts = None, []
    for line in f:
        line = line.strip()
        if line.startswith(">"):
            if name:
                sequences[name] = "".join(parts)
            name, parts = line[1:], []
        else:
            parts.append(line)
    if name:
        sequences[name] = "".join(parts)

# Map locus_id (TE_001 or GENE_001) -> (full_header, sequence)
locus_sequences = {}
for header, seq in sequences.items():
    locus_id = header.split("::")[0]
    locus_sequences[locus_id] = (header, seq)

n_te   = sum(1 for k in locus_sequences if k.startswith("TE_"))
n_gene = sum(1 for k in locus_sequences if k.startswith("GENE_"))
print(f"  TE sequences:   {n_te}")
print(f"  Gene sequences: {n_gene}")
print()

# ==============================================================================
# Load Expression Profile (for locus weights)
# ==============================================================================
expr_file = Path("synthetic_data/transcriptome/expression_profile.tsv")
if not expr_file.exists():
    print(f"ERROR: Expression profile not found: {expr_file}")
    print("Please run: Rscript scripts/03_create_expression_profile.R")
    sys.exit(1)

print("Loading expression profile...")

# locus_id -> (total_umis_across_cells, feature_type)
locus_total_umis: dict[str, int] = defaultdict(int)
locus_feature_type: dict[str, str] = {}

with open(expr_file) as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        lid = row["locus_id"]
        locus_total_umis[lid] += int(row["target_umis"])
        locus_feature_type[lid] = row.get("feature_type", "te")

# Build weighted sampling list; total reads per cell derived from expression profile
loci_weighted = []
for locus_id, total in locus_total_umis.items():
    if locus_id in locus_sequences:
        loci_weighted.extend([locus_id] * total)

if not loci_weighted:
    print("ERROR: No loci with expression > 0 found")
    sys.exit(1)

# Reads per cell = total UMIs summed across all loci for one cell
# (all cells identical in uniform model)
first_cell_umis = sum(
    int(row["target_umis"])
    for row in csv.DictReader(open(expr_file), delimiter="\t")  # type: ignore[arg-type]
    if row["cell_id"] == "CELL_001"
)
reads_per_cell_actual = first_cell_umis if first_cell_umis > 0 else READS_PER_CELL

n_te_loci   = sum(1 for k, v in locus_feature_type.items() if v == "te")
n_gene_loci = sum(1 for k, v in locus_feature_type.items() if v == "gene")
print(f"  TE loci in profile:   {n_te_loci}")
print(f"  Gene loci in profile: {n_gene_loci}")
print(f"  Reads per cell: {reads_per_cell_actual:,}")
print()

# ==============================================================================
# Generate Reads
# ==============================================================================
print("Generating reads from 3' ends of sequences...")
print()

output_dir = Path("synthetic_data/fastqs")
output_dir.mkdir(parents=True, exist_ok=True)

r1_path = output_dir / "synthetic_reads_R1.fastq"
r2_path = output_dir / "synthetic_reads_R2.fastq"

QUAL = "I" * READ_LENGTH

read_count = 0
too_short_count = 0
te_read_count = 0
gene_read_count = 0

with open(r1_path, "w") as r1_out, open(r2_path, "w") as r2_out:
    for cell_idx in range(N_CELLS):
        for _ in range(reads_per_cell_actual):
            locus_id = random.choice(loci_weighted)
            full_header, seq = locus_sequences[locus_id]
            feat = locus_feature_type.get(locus_id, "te")

            seq_len = len(seq)
            jitter = random.randint(0, PRIME_JITTER)
            anchor = max(READ_LENGTH, seq_len - jitter)
            start  = anchor - READ_LENGTH
            r2_seq = seq[start:anchor]

            if len(r2_seq) < READ_LENGTH:
                too_short_count += 1
                r2_seq = "A" * (READ_LENGTH - len(r2_seq)) + r2_seq

            r1_seq = "A" * READ_LENGTH

            # Embed feature_type in read name so validation can identify origin
            read_name = f"@{full_header}.{feat}.{read_count}"
            r1_out.write(f"{read_name}/1\n{r1_seq}\n+\n{QUAL}\n")
            r2_out.write(f"{read_name}/2\n{r2_seq}\n+\n{QUAL}\n")

            read_count += 1
            if feat == "te":
                te_read_count += 1
            else:
                gene_read_count += 1

        if (cell_idx + 1) % max(1, N_CELLS // 5) == 0:
            print(f"  Cells processed: {cell_idx + 1}/{N_CELLS}", end="\r")

print(f"  Cells processed: {N_CELLS}/{N_CELLS}")
print()

# ==============================================================================
# Validation
# ==============================================================================
print("Validation:")
print(f"  Total read pairs written: {read_count:,}")
print(f"    TE reads:   {te_read_count:,}  ({100*te_read_count/read_count:.1f}%)")
print(f"    Gene reads: {gene_read_count:,}  ({100*gene_read_count/read_count:.1f}%)")
if too_short_count:
    print(f"  Short sequences (padded with poly-A): {too_short_count}")

# Verify read counts from file
r1_count = sum(1 for line in open(r1_path) if line.startswith("@"))
r2_count = sum(1 for line in open(r2_path) if line.startswith("@"))
print(f"  R1 reads verified: {r1_count:,}")
print(f"  R2 reads verified: {r2_count:,}")
print()

# Show first R2 read (should end with poly-A from the TE)
print("  Example R2 read (first read):")
with open(r2_path) as f:
    for line in [f.readline(), f.readline(), f.readline(), f.readline()]:
        print(f"    {line.rstrip()}")
print()

import os
r1_mb = os.path.getsize(r1_path) / (1024 ** 2)
r2_mb = os.path.getsize(r2_path) / (1024 ** 2)
print(f"  File sizes:")
print(f"    R1: {r1_mb:.1f} MB")
print(f"    R2: {r2_mb:.1f} MB")
print()

# ==============================================================================
# Summary
# ==============================================================================
print("=" * 80)
print("Step 4 Complete!")
print("=" * 80)
print()
print("Reads generated (10x 3' chemistry model):")
print(f"  R1: {r1_path}  (placeholder — replaced in step 05)")
print(f"  R2: {r2_path}  (cDNA from 3' end, includes poly-A tail)")
print(f"  Total read pairs: {read_count:,}")
print()
print("NOTE: R1 placeholder sequences are replaced in the next step.")
print("      R2 reads come from the 3' end of TE sequences (poly-A inclusive).")
print()
print("Next step: Add 10x cell barcodes and UMIs")
print("  python scripts/05_add_barcodes.py")
print()
