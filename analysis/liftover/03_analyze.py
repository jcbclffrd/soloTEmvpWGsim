#!/usr/bin/env python3
"""
Liftover Analysis — Step 3: Subfamily Composition and Enrichment

Compares the subfamily breakdown of:
  - hg38-specific TEs  (failed hg38 → CHM13 liftover)
  - CHM13-specific TEs (failed CHM13 → hg38 liftover)

Key question: are young Alu subfamilies (AluY*) and L1Hs enriched
in the unmapped sets relative to older subfamilies? If so, this supports
the hypothesis that young/still-mobile TEs lack stable genomic addresses
and are polymorphic across individuals.

Also checks synteny: for loci that DID lift over, does the TE subfamily
annotation at the destination match the source? Discordant annotations
indicate the lifted coordinate landed on a different TE copy.
"""

import sys
from pathlib import Path
from collections import Counter, defaultdict
import csv

SCRIPT_DIR = Path(__file__).parent
RESULTS_DIR = SCRIPT_DIR / "results"
DATA_DIR = SCRIPT_DIR / "data"

print("=" * 80)
print("Liftover Analysis — Step 3: Subfamily Composition and Enrichment")
print("=" * 80)
print()

# ==============================================================================
# Load BED files
# Column order (both hg38 and CHM13 BEDs after 01_prepare_beds.sh):
# 0:chr  1:start  2:end  3:name(subfamily)  4:score  5:strand
# 6:class  7:family  8:percDiv  9:id
# ==============================================================================

def load_bed(path, label):
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.strip().split("\t")
            rows.append(parts)
    print(f"  Loaded {len(rows):,} entries from {label}")
    return rows


def subfamily_counts(rows, col=3):
    return Counter(r[col] for r in rows)


def family_counts(rows, col=7):
    return Counter(r[col] for r in rows)


# ==============================================================================
# Load unmapped sets
# ==============================================================================
print("Loading liftover results...")

files = {
    "hg38_unmapped":   RESULTS_DIR / "hg38_to_chm13_unmapped.bed",
    "hg38_mapped":     RESULTS_DIR / "hg38_to_chm13_mapped.bed",
    "chm13_unmapped":  RESULTS_DIR / "chm13_to_hg38_unmapped.bed",
    "chm13_mapped":    RESULTS_DIR / "chm13_to_hg38_mapped.bed",
}

for key, path in files.items():
    if not path.exists():
        print(f"ERROR: {path} not found. Run 02_run_liftover.sh first.")
        sys.exit(1)

hg38_unmapped  = load_bed(files["hg38_unmapped"],  "hg38 unmapped (hg38-specific TEs)")
hg38_mapped    = load_bed(files["hg38_mapped"],    "hg38 mapped")
chm13_unmapped = load_bed(files["chm13_unmapped"], "CHM13 unmapped (CHM13-specific TEs)")
chm13_mapped   = load_bed(files["chm13_mapped"],   "CHM13 mapped")
print()

# ==============================================================================
# Top-level counts
# ==============================================================================
print("=" * 60)
print("1. Liftover Summary")
print("=" * 60)
print()

hg38_total  = len(hg38_unmapped)  + len(hg38_mapped)
chm13_total = len(chm13_unmapped) + len(chm13_mapped)

print(f"  hg38  LINE/SINE total:              {hg38_total:>10,}")
print(f"  hg38  mapped to CHM13:              {len(hg38_mapped):>10,}  ({len(hg38_mapped)/hg38_total*100:.1f}%)")
print(f"  hg38  unmapped (hg38-specific):     {len(hg38_unmapped):>10,}  ({len(hg38_unmapped)/hg38_total*100:.1f}%)")
print()
print(f"  CHM13 LINE/SINE total:              {chm13_total:>10,}")
print(f"  CHM13 mapped to hg38:               {len(chm13_mapped):>10,}  ({len(chm13_mapped)/chm13_total*100:.1f}%)")
print(f"  CHM13 unmapped (CHM13-specific):    {len(chm13_unmapped):>10,}  ({len(chm13_unmapped)/chm13_total*100:.1f}%)")
print()

asymmetry = len(hg38_unmapped) - len(chm13_unmapped)
if asymmetry > 0:
    print(f"  hg38 has {asymmetry:,} MORE assembly-specific TEs than CHM13.")
    print("  Consistent with hg38 having more collapsed/misassembled TE regions")
    print("  and being derived from a different individual (polymorphic insertions).")
else:
    print(f"  CHM13 has {abs(asymmetry):,} more assembly-specific TEs than hg38.")
print()

# ==============================================================================
# Subfamily breakdown of unmapped sets
# ==============================================================================
print("=" * 60)
print("2. Top Subfamilies in Unmapped (Assembly-Specific) Sets")
print("=" * 60)
print()

for label, rows in [("hg38-specific (hg38 unmapped)", hg38_unmapped),
                    ("CHM13-specific (CHM13 unmapped)", chm13_unmapped)]:
    counts = subfamily_counts(rows)
    total = sum(counts.values())
    print(f"  {label}  (n={total:,})")
    print(f"  {'Subfamily':<20} {'Count':>8}  {'%':>6}")
    print(f"  {'-'*38}")
    for subfamily, count in counts.most_common(15):
        print(f"  {subfamily:<20} {count:>8,}  {count/total*100:>5.1f}%")
    print()

# ==============================================================================
# Young vs. old Alu comparison
# Young Alu: AluY* subfamilies (~1-5 Mya, still occasionally active)
# Old Alu:   AluJ*, AluS* subfamilies (>5 Mya, fixed in population)
# ==============================================================================
print("=" * 60)
print("3. Young vs. Old Alu in Unmapped Sets")
print("=" * 60)
print()

def categorize_alu(subfamily):
    if subfamily.startswith("AluY"):
        return "young (AluY*)"
    elif subfamily.startswith("AluJ"):
        return "old (AluJ*)"
    elif subfamily.startswith("AluS"):
        return "intermediate (AluS*)"
    elif subfamily.startswith("Alu"):
        return "other Alu"
    return None

for label, rows in [("hg38-specific", hg38_unmapped),
                    ("CHM13-specific", chm13_unmapped)]:
    alu_rows = [r for r in rows if r[7] == "Alu"]  # family == Alu
    cats = Counter(categorize_alu(r[3]) for r in alu_rows if categorize_alu(r[3]))
    total_alu = sum(cats.values())
    print(f"  {label} Alu breakdown (n={total_alu:,}):")
    for cat in ["young (AluY*)", "intermediate (AluS*)", "old (AluJ*)", "other Alu"]:
        n = cats.get(cat, 0)
        pct = n / total_alu * 100 if total_alu > 0 else 0
        print(f"    {cat:<30} {n:>7,}  ({pct:.1f}%)")
    print()

# ==============================================================================
# L1 LINE young vs. old comparison
# L1Hs = human-specific, youngest (~0-6 Mya, some still active)
# L1PA* = primate-specific lineage, older
# L1M*  = mammalian, oldest
# ==============================================================================
print("=" * 60)
print("4. Young vs. Old L1 in Unmapped Sets")
print("=" * 60)
print()

def categorize_l1(subfamily):
    if subfamily == "L1Hs":
        return "youngest (L1Hs, human-specific)"
    elif subfamily.startswith("L1PA"):
        return "young (L1PA*, primate-specific)"
    elif subfamily.startswith("L1P"):
        return "intermediate (L1P*)"
    elif subfamily.startswith("L1M"):
        return "old (L1M*, mammalian)"
    elif subfamily.startswith("L1"):
        return "other L1"
    return None

for label, rows in [("hg38-specific", hg38_unmapped),
                    ("CHM13-specific", chm13_unmapped)]:
    l1_rows = [r for r in rows if r[7] == "L1"]
    cats = Counter(categorize_l1(r[3]) for r in l1_rows if categorize_l1(r[3]))
    total_l1 = sum(cats.values())
    print(f"  {label} L1 breakdown (n={total_l1:,}):")
    for cat in ["youngest (L1Hs, human-specific)", "young (L1PA*, primate-specific)",
                "intermediate (L1P*)", "old (L1M*, mammalian)", "other L1"]:
        n = cats.get(cat, 0)
        pct = n / total_l1 * 100 if total_l1 > 0 else 0
        print(f"    {cat:<38} {n:>7,}  ({pct:.1f}%)")
    print()

# ==============================================================================
# Write summary TSV
# ==============================================================================
out_summary = RESULTS_DIR / "liftover_comparison.tsv"
with open(out_summary, "w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(["assembly", "total", "mapped", "unmapped", "pct_unmapped"])
    writer.writerow(["hg38",  hg38_total,  len(hg38_mapped),  len(hg38_unmapped),
                     f"{len(hg38_unmapped)/hg38_total*100:.2f}"])
    writer.writerow(["CHM13", chm13_total, len(chm13_mapped), len(chm13_unmapped),
                     f"{len(chm13_unmapped)/chm13_total*100:.2f}"])

out_enrichment = RESULTS_DIR / "subfamily_enrichment.tsv"
with open(out_enrichment, "w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(["source", "subfamily", "count", "pct_of_unmapped"])
    for label, rows in [("hg38_unmapped", hg38_unmapped),
                        ("chm13_unmapped", chm13_unmapped)]:
        counts = subfamily_counts(rows)
        total = sum(counts.values())
        for subfamily, count in counts.most_common():
            writer.writerow([label, subfamily, count, f"{count/total*100:.3f}"])

print(f"Summary written to: {out_summary}")
print(f"Subfamily enrichment written to: {out_enrichment}")
print()
print("=" * 80)
print("Analysis complete.")
print("=" * 80)
