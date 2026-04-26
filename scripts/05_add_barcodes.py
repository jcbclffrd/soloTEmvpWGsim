#!/usr/bin/env python3
"""
Pipeline Script 5: Add 10x Cell Barcodes and UMIs to Reads

This script prepends cell barcodes (16bp) and UMIs (12bp) to R1 reads
to create properly formatted 10x Chromium v3 fastq files.

10x Chromium v3 format:
    R1: [Cell Barcode 16bp][UMI 12bp][Poly-T sequence]
    R2: [cDNA sequence - actual transcript]

Input:  synthetic_data/fastqs/synthetic_reads_R1.fastq
        synthetic_data/fastqs/synthetic_reads_R2.fastq
        synthetic_data/transcriptome/cell_barcodes.txt
        synthetic_data/transcriptome/expression_profile.tsv
Output: synthetic_data/fastqs/synthetic_10x_S1_L001_R1_001.fastq.gz
        synthetic_data/fastqs/synthetic_10x_S1_L001_R2_001.fastq.gz
"""

import sys
import gzip
import random
import argparse
from pathlib import Path
from collections import defaultdict
import yaml

print("=" * 80)
print("Pipeline Step 5: Add 10x Cell Barcodes and UMIs")
print("=" * 80)
print()

# ==============================================================================
# Load Configuration
# ==============================================================================
with open("config.yaml") as f:
    config = yaml.safe_load(f)

CB_LENGTH = config["simulation"]["cb_length"]
UMI_LENGTH = config["simulation"]["umi_length"]
N_CELLS = config["simulation"]["n_cells"]
READS_PER_CELL = config["simulation"]["reads_per_cell"]
RANDOM_SEED = config["simulation"]["random_seed"]

random.seed(RANDOM_SEED)

print("Configuration:")
print(f"  Cell barcode length: {CB_LENGTH}bp")
print(f"  UMI length: {UMI_LENGTH}bp")
print(f"  Number of cells: {N_CELLS}")
print(f"  Reads per cell: {READS_PER_CELL}")
print(f"  Random seed: {RANDOM_SEED}")
print()

# ==============================================================================
# Load Cell Barcodes
# ==============================================================================
print("Loading cell barcodes...")

barcode_file = Path("synthetic_data/transcriptome/cell_barcodes.txt")
if not barcode_file.exists():
    print(f"ERROR: Cell barcode file not found: {barcode_file}")
    print("Please run: Rscript scripts/03_create_expression_profile.R")
    sys.exit(1)

with open(barcode_file) as f:
    cell_barcodes = [line.strip() for line in f]

print(f"  Loaded {len(cell_barcodes)} cell barcodes")
print(f"  Example: {cell_barcodes[0]}")
print()

# ==============================================================================
# Helper Functions
# ==============================================================================

def generate_umi():
    """Generate a random UMI sequence."""
    return ''.join(random.choices('ACGT', k=UMI_LENGTH))


def parse_fastq(filename):
    """Parse FASTQ file (uncompressed or gzipped)."""
    if str(filename).endswith('.gz'):
        f = gzip.open(filename, 'rt')
    else:
        f = open(filename, 'r')
    
    while True:
        header = f.readline().strip()
        if not header:
            break
        seq = f.readline().strip()
        plus = f.readline().strip()
        qual = f.readline().strip()
        yield (header, seq, plus, qual)
    
    f.close()


def write_fastq_record(f, header, seq, qual):
    """Write a FASTQ record."""
    f.write(f"{header}\n")
    f.write(f"{seq}\n")
    f.write("+\n")
    f.write(f"{qual}\n")

# ==============================================================================
# Process Reads and Add Barcodes
# ==============================================================================
print("Processing reads and adding barcodes...")
print()

# Input files
r1_input = Path("synthetic_data/fastqs/synthetic_reads_R1.fastq")
r2_input = Path("synthetic_data/fastqs/synthetic_reads_R2.fastq")

if not r1_input.exists() or not r2_input.exists():
    print(f"ERROR: Input fastq files not found")
    print("Please run: bash scripts/04_simulate_reads.sh")
    sys.exit(1)

# Output files (10x naming convention)
output_dir = Path("synthetic_data/fastqs")
r1_output = output_dir / "synthetic_10x_S1_L001_R1_001.fastq.gz"
r2_output = output_dir / "synthetic_10x_S1_L001_R2_001.fastq.gz"

print(f"  Input R1: {r1_input}")
print(f"  Input R2: {r2_input}")
print(f"  Output R1: {r1_output}")
print(f"  Output R2: {r2_output}")
print()
print("Adding cell barcodes and UMIs to reads...")
print()

# Track reads per cell
reads_per_cell_counter = defaultdict(int)
current_cell_idx = 0
reads_in_current_cell = 0

# Process reads
with gzip.open(r1_output, 'wt') as r1_out, \
     gzip.open(r2_output, 'wt') as r2_out:
    
    r1_parser = parse_fastq(r1_input)
    r2_parser = parse_fastq(r2_input)
    
    read_count = 0
    
    for (r1_header, r1_seq, r1_plus, r1_qual), \
        (r2_header, r2_seq, r2_plus, r2_qual) in zip(r1_parser, r2_parser):
        
        # Assign to cells in order (simulate READS_PER_CELL reads per cell)
        if reads_in_current_cell >= READS_PER_CELL:
            current_cell_idx += 1
            reads_in_current_cell = 0
            
            if current_cell_idx >= N_CELLS:
                current_cell_idx = 0  # Wrap around if more reads than expected
        
        # Get cell barcode
        cell_barcode = cell_barcodes[current_cell_idx]
        
        # Generate UMI
        umi = generate_umi()
        
        # Create new R1 read: [Cell Barcode][UMI][original R1 seq (truncated)]
        # Prepend CB+UMI to R1, truncate original sequence to maintain read length
        # Total R1 length should be 28bp (CB) + 12bp (UMI) + remaining sequence
        barcode_umi = cell_barcode + umi
        barcode_umi_qual = 'I' * len(barcode_umi)  # High quality scores for barcodes
        
        # Truncate original R1 sequence to fit
        max_original_len = 150 - len(barcode_umi)  # Assuming 150bp total read length
        r1_seq_truncated = r1_seq[:max_original_len]
        r1_qual_truncated = r1_qual[:max_original_len]
        
        # New R1: barcode+UMI+truncated original
        new_r1_seq = barcode_umi + r1_seq_truncated
        new_r1_qual = barcode_umi_qual + r1_qual_truncated
        
        # Write R1 (with barcodes)
        write_fastq_record(r1_out, r1_header, new_r1_seq, new_r1_qual)
        
        # Write R2 (unchanged - this is the actual cDNA)
        write_fastq_record(r2_out, r2_header, r2_seq, r2_qual)
        
        reads_in_current_cell += 1
        reads_per_cell_counter[current_cell_idx] += 1
        read_count += 1
        
        if read_count % 100000 == 0:
            print(f"  Processed {read_count:,} read pairs...", end='\r')
    
    print(f"  Processed {read_count:,} read pairs... Done!")

print()
print("✓ Barcode addition complete")
print()

# ==============================================================================
# Validation
# ==============================================================================
print("Validation:")
print()

print(f"  Total read pairs processed: {read_count:,}")
print(f"  Cells with reads: {len(reads_per_cell_counter)}")
print()

print("  Reads per cell (first 10 cells):")
for i in range(min(10, len(reads_per_cell_counter))):
    print(f"    Cell {i+1}: {reads_per_cell_counter[i]:,} reads")
print()

# Check R1 format
print("  Checking R1 format (first read):")
with gzip.open(r1_output, 'rt') as f:
    header = f.readline().strip()
    seq = f.readline().strip()
    
    print(f"    Read length: {len(seq)}bp")
    print(f"    First 28bp (CB): {seq[:16]}")
    print(f"    Next 12bp (UMI): {seq[16:28]}")
    print(f"    Remaining: {seq[28:48]}...")

print()

# File sizes
import os
r1_size = os.path.getsize(r1_output) / (1024**2)  # MB
r2_size = os.path.getsize(r2_output) / (1024**2)  # MB

print(f"  Output file sizes:")
print(f"    R1: {r1_size:.1f} MB")
print(f"    R2: {r2_size:.1f} MB")
print()

# ==============================================================================
# Summary
# ==============================================================================
print("=" * 80)
print("Step 5 Complete!")
print("=" * 80)
print()
print("10x-formatted fastq files created:")
print(f"  R1: {r1_output}")
print(f"  R2: {r2_output}")
print()
print("Files are ready for STARsolo alignment.")
print()
print("Next step: Align reads with STARsolo")
print("  bash scripts/06_align_starsolo.sh")
print()

# EXTENSION POINT: UMI Collisions
# --------------------------------
# Current implementation generates random UMIs. For more realistic simulation,
# could implement:
# 1. UMI PCR amplification (duplicate UMIs for same molecule)
# 2. UMI synthesis errors
# 3. UMI collision rates based on library complexity
#
# Example:
# if config.get("extensions", {}).get("realistic_umis", False):
#     # Simulate PCR amplification: duplicate some reads with same UMI
#     pcr_rate = 0.3  # 30% of molecules get PCR duplicated
#     if random.random() < pcr_rate:
#         umi = previous_umi  # Reuse UMI from previous read (same molecule)
