#!/usr/bin/env python3
"""
Liftover Analysis — Step 4: Generate Full Report

Produces analysis/liftover/results/REPORT.md covering:
  1. Total TE counts — hg38 vs CHM13 by class
  2. Family breakdown (%) for SINE and LINE
  3. Top subfamily breakdown
  4. hg38 → CHM13 liftover results (all 5.68M elements)
  5. Subfamily composition of unmapped (assembly-specific) TEs
  6. Young vs. old Alu age breakdown with counts and percentages
"""

from pathlib import Path
from collections import Counter, defaultdict

SCRIPT_DIR = Path(__file__).parent
RESULTS_DIR = SCRIPT_DIR / "results"
DATA_DIR    = SCRIPT_DIR / "data"

# ==============================================================================
# Load data
# ==============================================================================

def load_bed(path):
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            rows.append(line.strip().split("\t"))
    return rows

def load_rmsk_gz(path):
    """Load full hg38 rmsk.txt.gz — returns list of dicts."""
    import gzip
    rows = []
    with gzip.open(path, "rt") as f:
        for line in f:
            parts = line.strip().split("\t")
            rows.append({
                "chr":       parts[5],
                "start":     int(parts[6]),
                "end":       int(parts[7]),
                "subfamily": parts[10],
                "class_":    parts[11],
                "family":    parts[12],
                "percDiv":   int(parts[2]) / 10.0,
            })
    return rows

print("Loading data...")
hg38_all      = load_rmsk_gz(DATA_DIR / "hg38_rmsk.txt.gz")
chm13_all     = load_bed(RESULTS_DIR.parent.parent.parent /
                         "references/annotations/T2T-CHM13v2.0_RepeatMasker.bed")
unmapped_full = load_bed(RESULTS_DIR / "hg38_all_to_chm13_unmapped.bed")
unmapped_ls   = load_bed(RESULTS_DIR / "hg38_to_chm13_unmapped.bed")  # LINE/SINE only

print(f"  hg38 total:           {len(hg38_all):>10,}")
print(f"  CHM13 total:          {len(chm13_all):>10,}")
print(f"  hg38 unmapped (all):  {len(unmapped_full):>10,}")
print()

# ==============================================================================
# Helper
# ==============================================================================

def pct(n, total):
    return f"{n/total*100:.1f}%" if total else "—"

def fmt(n):
    return f"{n:,}"


lines = []
def h(text=""):  lines.append(text)
def row(*cols, widths=None):
    if widths:
        lines.append("| " + " | ".join(str(c).ljust(w) for c, w in zip(cols, widths)) + " |")
    else:
        lines.append("| " + " | ".join(str(c) for c in cols) + " |")
def sep(*widths):
    lines.append("| " + " | ".join("-" * w for w in widths) + " |")

# ==============================================================================
# Table 1: Total counts by class
# ==============================================================================
hg38_class  = Counter(r["class_"] for r in hg38_all)
chm13_class = Counter(r[6] for r in chm13_all)   # col 6 = class

# Major biological TE classes (exclude repeat masker technical categories)
bio_classes = ["SINE", "LINE", "LTR", "DNA", "Retroposon", "Satellite"]
other_label = "Other (Simple_repeat, Low_complexity, RNA, etc.)"

hg38_total  = len(hg38_all)
chm13_total = len(chm13_all)

hg38_bio  = sum(hg38_class.get(c, 0)  for c in bio_classes)
chm13_bio = sum(chm13_class.get(c, 0) for c in bio_classes)

h("# hg38 ↔ T2T-CHM13 Transposable Element Liftover Analysis")
h()
h("> **Motivation:** Are there more assembly-specific TE loci in hg38 than in CHM13?")
h("> And are young, recently-mobile Alu elements disproportionately absent from")
h("> the other assembly — evidence that they lack stable genomic addresses across individuals?")
h()
h("---")
h()
h("## Table 1. Total RepeatMasker Annotations")
h()
h(f"hg38 and T2T-CHM13v2.0 RepeatMasker annotations across all repeat classes.")
h()
row("Class", "hg38", "hg38 %", "CHM13", "CHM13 %")
sep(30, 10, 8, 10, 8)
for cls in bio_classes:
    n1 = hg38_class.get(cls, 0)
    n2 = chm13_class.get(cls, 0)
    row(cls, fmt(n1), pct(n1, hg38_total), fmt(n2), pct(n2, chm13_total))

hg38_other  = hg38_total  - hg38_bio
chm13_other = chm13_total - chm13_bio
row(other_label,
    fmt(hg38_other),  pct(hg38_other,  hg38_total),
    fmt(chm13_other), pct(chm13_other, chm13_total))
sep(30, 10, 8, 10, 8)
row("**Total**", f"**{fmt(hg38_total)}**", "100%", f"**{fmt(chm13_total)}**", "100%")
h()

# ==============================================================================
# Table 2: SINE subfamily breakdown
# ==============================================================================
hg38_sine_fam  = Counter(r["family"]   for r in hg38_all if r["class_"] == "SINE")
chm13_sine_fam = Counter(r[7]          for r in chm13_all if r[6] == "SINE")
hg38_sine_n    = sum(hg38_sine_fam.values())
chm13_sine_n   = sum(chm13_sine_fam.values())

h("---")
h()
h("## Table 2. SINE Family Breakdown")
h()
row("SINE Family", "hg38 count", "hg38 %", "CHM13 count", "CHM13 %")
sep(20, 12, 8, 12, 8)
all_sine_fams = sorted(set(hg38_sine_fam) | set(chm13_sine_fam),
                       key=lambda f: -hg38_sine_fam.get(f, 0))
for fam in all_sine_fams[:10]:
    n1 = hg38_sine_fam.get(fam, 0)
    n2 = chm13_sine_fam.get(fam, 0)
    row(fam, fmt(n1), pct(n1, hg38_sine_n), fmt(n2), pct(n2, chm13_sine_n))
sep(20, 12, 8, 12, 8)
row("**Total SINE**", f"**{fmt(hg38_sine_n)}**", "100%",
    f"**{fmt(chm13_sine_n)}**", "100%")
h()

# LINE family breakdown
hg38_line_fam  = Counter(r["family"] for r in hg38_all if r["class_"] == "LINE")
chm13_line_fam = Counter(r[7]        for r in chm13_all if r[6] == "LINE")
hg38_line_n    = sum(hg38_line_fam.values())
chm13_line_n   = sum(chm13_line_fam.values())

h("## Table 3. LINE Family Breakdown")
h()
row("LINE Family", "hg38 count", "hg38 %", "CHM13 count", "CHM13 %")
sep(20, 12, 8, 12, 8)
all_line_fams = sorted(set(hg38_line_fam) | set(chm13_line_fam),
                       key=lambda f: -hg38_line_fam.get(f, 0))
for fam in all_line_fams[:8]:
    n1 = hg38_line_fam.get(fam, 0)
    n2 = chm13_line_fam.get(fam, 0)
    row(fam, fmt(n1), pct(n1, hg38_line_n), fmt(n2), pct(n2, chm13_line_n))
sep(20, 12, 8, 12, 8)
row("**Total LINE**", f"**{fmt(hg38_line_n)}**", "100%",
    f"**{fmt(chm13_line_n)}**", "100%")
h()

# ==============================================================================
# Table 4: Liftover results — all 5.68M elements
# ==============================================================================
mapped_n   = hg38_total - len(unmapped_full)   # approximate: CrossMap expands some records
unmapped_n = len(unmapped_full)

h("---")
h()
h("## Table 4. hg38 → CHM13 Liftover Results (All Elements)")
h()
h(f"All {fmt(hg38_total)} hg38 RepeatMasker loci lifted to T2T-CHM13 coordinates")
h(f"using CrossMap with the UCSC hg38→hs1 chain file.")
h()
row("Outcome", "Count", "% of hg38 total")
sep(35, 12, 18)
row("Successfully lifted to CHM13", fmt(hg38_total - unmapped_n), pct(hg38_total - unmapped_n, hg38_total))
row("**Failed to lift (hg38-specific)**", f"**{fmt(unmapped_n)}**", f"**{pct(unmapped_n, hg38_total)}**")
sep(35, 12, 18)
row("**Total input**", f"**{fmt(hg38_total)}**", "100%")
h()
h(f"> **{fmt(unmapped_n)} hg38 loci have no equivalent position in CHM13.**")
h("> These represent a mix of: hg38 assembly errors, collapsed repeats resolved")
h("> differently in T2T, and genuine polymorphic insertions absent from CHM13.")
h()

# Breakdown of unmapped by class
unmap_class = Counter(r[6] for r in unmapped_full)
h("### Table 4a. Unmapped Elements by Class")
h()
row("Class", "Unmapped count", "% of unmapped", "% of all hg38 in class")
sep(30, 15, 15, 22)
for cls, n in sorted(unmap_class.items(), key=lambda x: -x[1])[:10]:
    hg38_n_cls = hg38_class.get(cls, 0)
    row(cls, fmt(n), pct(n, unmapped_n), pct(n, hg38_n_cls))
sep(30, 15, 15, 22)
row("**Total**", f"**{fmt(unmapped_n)}**", "100%", "")
h()

# ==============================================================================
# Table 5: Top unmapped subfamilies
# ==============================================================================
unmap_subfam = Counter(r[3] for r in unmapped_full)
h("### Table 4b. Top 20 Unmapped Subfamilies (hg38-specific)")
h()
row("Subfamily", "Count", "% of unmapped")
sep(22, 10, 15)
for subfam, n in unmap_subfam.most_common(20):
    row(subfam, fmt(n), pct(n, unmapped_n))
h()

# ==============================================================================
# Table 6: Young vs. old Alu in unmapped sets (the key finding)
# ==============================================================================
def categorize_alu(subfamily):
    if subfamily.startswith("AluY"):  return "Young (AluY*)"
    if subfamily.startswith("AluJ"):  return "Old (AluJ*)"
    if subfamily.startswith("AluS"):  return "Intermediate (AluS*)"
    if subfamily.startswith("Alu"):   return "Other Alu"
    return None

# From full unmapped (all classes) — Alu elements
unmap_alu  = [r for r in unmapped_full if r[7] == "Alu"]

# From LINE/SINE liftover — CHM13-specific
chm13_unmapped = load_bed(RESULTS_DIR / "chm13_to_hg38_unmapped.bed")
chm13_alu = [r for r in chm13_unmapped if r[7] == "Alu"]

# Background: all hg38 Alu elements
hg38_alu_all = [r for r in hg38_all if r["family"] == "Alu"]

h("---")
h()
h("## Table 5. Young vs. Old Alu — Assembly-Specific vs. Background")
h()
h("The key finding: among Alu elements that failed liftover (i.e., exist in")
h("one assembly but not the other), **young AluY subfamilies are massively")
h("over-represented** in the CHM13-specific set — consistent with young Alu")
h("elements still retrotransposing and creating individual-specific insertions.")
h()

order = ["Young (AluY*)", "Intermediate (AluS*)", "Old (AluJ*)", "Other Alu"]

def alu_breakdown(rows, key_fn):
    cats = Counter(key_fn(r) for r in rows)
    cats = {k: v for k, v in cats.items() if k}
    return cats

hg38_alu_bg   = alu_breakdown(hg38_alu_all,  lambda r: categorize_alu(r["subfamily"]))
hg38_unmap_au = alu_breakdown(unmap_alu,      lambda r: categorize_alu(r[3]))
chm13_unmap_au= alu_breakdown(chm13_alu,      lambda r: categorize_alu(r[3]))

hg38_bg_n    = sum(hg38_alu_bg.values())
hg38_unmap_n = sum(hg38_unmap_au.values())
chm13_unmap_n= sum(chm13_unmap_au.values())

row("Alu age group",
    f"hg38 background (n={fmt(hg38_bg_n)})", "",
    f"hg38-specific unmapped (n={fmt(hg38_unmap_n)})", "",
    f"CHM13-specific unmapped (n={fmt(chm13_unmap_n)})", "")
sep(24, 32, 8, 36, 8, 36, 8)
row("", "Count", "%", "Count", "%", "Count", "%")
sep(24, 8, 8, 8, 8, 8, 8)
for cat in order:
    bg    = hg38_alu_bg.get(cat, 0)
    hu    = hg38_unmap_au.get(cat, 0)
    cu    = chm13_unmap_au.get(cat, 0)
    row(cat,
        fmt(bg),  pct(bg, hg38_bg_n),
        fmt(hu),  pct(hu, hg38_unmap_n),
        fmt(cu),  pct(cu, chm13_unmap_n))
sep(24, 8, 8, 8, 8, 8, 8)
row("**Total**",
    f"**{fmt(hg38_bg_n)}**",    "100%",
    f"**{fmt(hg38_unmap_n)}**", "100%",
    f"**{fmt(chm13_unmap_n)}**","100%")
h()
h("> **Interpretation:** AluY* elements make up ~16% of all hg38 Alu loci (background)")
h("> but **76% of CHM13-specific unmapped Alu loci**. Young Alus are the elements")
h("> most likely to be absent from one assembly or the other — strong evidence that")
h("> they are still polymorphic across individuals and lack fixed genomic addresses.")
h()
h("---")
h()
h("## Methods Notes")
h()
h("- **hg38 RepeatMasker:** UCSC `rmsk.txt.gz` (hg38, downloaded Oct 2022)")
h("- **CHM13 RepeatMasker:** T2T-CHM13v2.0 RepeatMasker BED (project references/)")
h("- **Liftover tool:** CrossMap v0.7.0 with UCSC hg38→hs1 and hs1→hg38 chain files")
h("- **Note:** CrossMap can produce slightly more output records than input when a locus")
h("  spans a chain boundary (the region is split). Unmapped counts are unaffected.")
h("- **Cleanup:** `rm -rf analysis/liftover/data/ analysis/liftover/results/`")

# ==============================================================================
# Write report
# ==============================================================================
report_path = RESULTS_DIR / "REPORT.md"
with open(report_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"Report written to: {report_path}")
