#!/usr/bin/env python3
"""
Pipeline Script 4: Simulate 3' scRNA-seq Reads

Models 10x Chromium 3' chemistry: the oligo-dT primer anneals to the
poly-A tail and cDNA synthesis proceeds toward the 5' end of the transcript.

R2: cDNA read starting near the 3' end of each TE sequence (includes poly-A)
R1: placeholder (CB + UMI are prepended in step 05)

Unlike wgsim, reads are drawn exclusively from the 3' end, matching the
capture mechanism of 3' scRNA-seq protocols.

Input:  synthetic_data/transcriptome/synthetic_transcriptome.fa
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

READ_LENGTH  = config["simulation"]["read_length"]
N_CELLS      = config["simulation"]["n_cells"]
READS_PER_CELL = config["simulation"]["reads_per_cell"]
RANDOM_SEED  = config["simulation"]["random_seed"]

random.seed(RANDOM_SEED)

TOTAL_READS  = N_CELLS * READS_PER_CELL

# How far upstream of the poly-A tail the oligo-dT can prime (bp jitter).
# In real data, the primer anneals at various positions within the poly-A,
# so reads start at slightly different distances from the 3' end.
PRIME_JITTER = 50

print("Configuration:")
print(f"  Read length: {READ_LENGTH}bp")
print(f"  Cells: {N_CELLS}")
print(f"  Reads per cell: {READS_PER_CELL}")
print(f"  Total reads: {TOTAL_READS:,}")
print(f"  Random seed: {RANDOM_SEED}")
print(f"  3'-end priming jitter: {PRIME_JITTER}bp")
print()

# ==============================================================================
# Load Transcriptome FASTA
# ==============================================================================
fasta_file = Path("synthetic_data/transcriptome/synthetic_transcriptome.fa")
if not fasta_file.exists():
    print(f"ERROR: Transcriptome not found: {fasta_file}")
    print("Please run: bash scripts/02_extract_sequences.sh")
    sys.exit(1)

print("Loading transcriptome sequences...")
sequences = {}  # full_header -> sequence
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

# Map locus_id (TE_001) -> (full_header, sequence)
locus_sequences = {}
for header, seq in sequences.items():
    locus_id = header.split("::")[0]
    locus_sequences[locus_id] = (header, seq)

print(f"  Loaded {len(locus_sequences)} TE sequences")
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

# locus_id -> total UMIs across all cells (used as sampling weight)
locus_total_umis = defaultdict(int)
with open(expr_file) as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        locus_total_umis[row["locus_id"]] += int(row["target_umis"])

# Build weighted sampling list: loci weighted by expression level
loci_weighted = []
for locus_id, total in locus_total_umis.items():
    if locus_id in locus_sequences:
        loci_weighted.extend([locus_id] * total)

if not loci_weighted:
    print("ERROR: No loci with expression > 0 found in expression profile")
    sys.exit(1)

n_loci = len(locus_total_umis)
print(f"  {n_loci} expressed loci")
print()

# ==============================================================================
# Generate Reads
# ==============================================================================
print("Generating reads from 3' ends of TE sequences...")
print()

output_dir = Path("synthetic_data/fastqs")
output_dir.mkdir(parents=True, exist_ok=True)

r1_path = output_dir / "synthetic_reads_R1.fastq"
r2_path = output_dir / "synthetic_reads_R2.fastq"

# Quality string — high quality scores for all bases
QUAL = "I" * READ_LENGTH

read_count = 0
too_short_count = 0

with open(r1_path, "w") as r1_out, open(r2_path, "w") as r2_out:
    for cell_idx in range(N_CELLS):
        for _ in range(READS_PER_CELL):
            # Sample a locus proportional to expression
            locus_id = random.choice(loci_weighted)
            full_header, seq = locus_sequences[locus_id]

            seq_len = len(seq)

            # The oligo-dT primer anneals somewhere in the poly-A tail.
            # The read extends upstream by READ_LENGTH from that anchor.
            # jitter=0 → read ends exactly at 3' tip;
            # jitter=PRIME_JITTER → read starts that many bp further upstream.
            jitter = random.randint(0, PRIME_JITTER)
            # The anchor (3' position of read) is seq_len - jitter
            anchor = max(READ_LENGTH, seq_len - jitter)
            start  = anchor - READ_LENGTH
            r2_seq = seq[start:anchor]

            # Pad with A (poly-A continuation) if start < 0 (very short TE)
            if len(r2_seq) < READ_LENGTH:
                too_short_count += 1
                r2_seq = "A" * (READ_LENGTH - len(r2_seq)) + r2_seq

            # R1 is a placeholder; step 05 replaces it with CB + UMI
            r1_seq = "A" * READ_LENGTH

            read_name = f"@{full_header}.{read_count}"
            r1_out.write(f"{read_name}/1\n{r1_seq}\n+\n{QUAL}\n")
            r2_out.write(f"{read_name}/2\n{r2_seq}\n+\n{QUAL}\n")

            read_count += 1

        if (cell_idx + 1) % max(1, N_CELLS // 5) == 0:
            print(f"  Cells processed: {cell_idx + 1}/{N_CELLS}", end="\r")

print(f"  Cells processed: {N_CELLS}/{N_CELLS}")
print()

# ==============================================================================
# Validation
# ==============================================================================
print("Validation:")
print(f"  Total read pairs written: {read_count:,}")
if too_short_count:
    print(f"  Short TE sequences (padded with poly-A): {too_short_count}")

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
