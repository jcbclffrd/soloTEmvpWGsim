#!/usr/bin/env python3
"""
Summarize the polymorphism cross-reference results.

Reads intersection outputs from step 03 and produces:
  - Console report of overlap fractions
  - results/polymorphism_summary.tsv  — machine-readable summary
  - results/af_distribution.tsv       — allele-frequency histogram of MEI hits

Run from repo root:
    python analysis/te_polymorphism/04_analyze.py
"""
import sys
import csv
from pathlib import Path
from collections import Counter, defaultdict

SCRIPT_DIR = Path(__file__).parent
RESULTS = SCRIPT_DIR / "results"

def load_bed(path: Path, name_col: int | None = None) -> list[dict]:
    rows = []
    with open(path) as fh:
        for line in fh:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            rows.append(parts)
    return rows


def parse_af(af_str: str) -> float | None:
    try:
        return float(af_str)
    except (ValueError, TypeError):
        return None


def af_bin(af: float | None) -> str:
    if af is None:
        return "unknown"
    if af < 0.01:
        return "<0.01  (rare)"
    if af < 0.05:
        return "0.01–0.05 (low)"
    if af < 0.10:
        return "0.05–0.10"
    if af < 0.50:
        return "0.10–0.50 (common)"
    return "≥0.50  (high/fixed)"


def main():
    # ── Load files ────────────────────────────────────────────────────────────
    cand_path = RESULTS / "hg38_specific_gap_distal.bed"
    hits_path = RESULTS / "hits_1000g_any.bed"
    nohit_path = RESULTS / "no_mei_overlap.bed"
    summary_tsv = RESULTS / "intersection_summary.tsv"

    if not cand_path.exists():
        sys.exit(f"ERROR: {cand_path} not found. Run steps 01–03 first.")
    if not hits_path.exists():
        sys.exit(f"ERROR: {hits_path} not found. Run step 03 first.")

    candidates = load_bed(cand_path)
    hits_raw   = load_bed(hits_path)
    no_hits    = load_bed(nohit_path) if nohit_path.exists() else []

    n_cand = len(candidates)

    # Deduplicate hits by candidate locus (cols 0-5)
    seen: set[tuple] = set()
    hits_dedup: list[list[str]] = []
    for row in hits_raw:
        key = tuple(row[:6])
        if key not in seen:
            seen.add(key)
            hits_dedup.append(row)

    n_hits = len(hits_dedup)

    # ── AF distribution ───────────────────────────────────────────────────────
    # hits_1000g_any.bed layout:
    #   cols 0-5  = candidate (chr, start, end, name, score, strand)
    #   cols 6-11 = MEI (chr, start, end, id, AF, SVTYPE)
    af_col = 10  # 0-based index for AF in combined row
    svtype_col = 11

    af_bins: Counter[str] = Counter()
    svtype_counts: Counter[str] = Counter()
    af_values: list[float] = []

    for row in hits_raw:
        af_raw = row[af_col] if len(row) > af_col else "NA"
        af = parse_af(af_raw)
        af_bins[af_bin(af)] += 1
        if af is not None:
            af_values.append(af)
        svt = row[svtype_col] if len(row) > svtype_col else "?"
        svtype_counts[svt] += 1

    # ── Per-class (candidate TE type) breakdown ───────────────────────────────
    # Candidate col 3 = name (e.g. "AluSx:SINE:Alu" or similar from rmsk)
    # Col 4 of the candidate block contains the repeat class
    # Adjust if rmsk BED has a different column layout; col 3 is repeat name
    cand_te_col = 3

    class_hit: Counter[str] = Counter()
    class_total: Counter[str] = Counter()

    for row in candidates:
        te_name = row[cand_te_col] if len(row) > cand_te_col else "unknown"
        class_total[te_name] += 1

    for row in hits_dedup:
        te_name = row[cand_te_col] if len(row) > cand_te_col else "unknown"
        class_hit[te_name] += 1

    # Collapse to broad family (first token before colon or underscore)
    def broad_family(name: str) -> str:
        for sep in (":", "_", "/"):
            if sep in name:
                return name.split(sep)[0]
        return name

    family_hit: Counter[str] = Counter()
    family_total: Counter[str] = Counter()
    for name, n in class_total.items():
        family_total[broad_family(name)] += n
    for name, n in class_hit.items():
        family_hit[broad_family(name)] += n

    # ── Print report ──────────────────────────────────────────────────────────
    pct = lambda a, b: f"{a*100/b:.1f}%" if b else "—"

    print("=" * 60)
    print("TE POLYMORPHISM CROSS-REFERENCE SUMMARY")
    print("=" * 60)
    print(f"\nGap-distal hg38-specific LINE/SINE candidates: {n_cand:,}")
    print(f"Overlap any 1000G MEI:  {n_hits:,}  ({pct(n_hits, n_cand)})")
    print(f"No MEI overlap:         {len(no_hits):,}  ({pct(len(no_hits), n_cand)})")

    print("\n── Allele-frequency distribution of MEI hits ──")
    for label in ["<0.01  (rare)", "0.01–0.05 (low)", "0.05–0.10",
                  "0.10–0.50 (common)", "≥0.50  (high/fixed)", "unknown"]:
        n = af_bins[label]
        if n:
            print(f"  {label:30s} {n:6,}  ({pct(n, sum(af_bins.values()))})")

    if af_values:
        af_values.sort()
        median = af_values[len(af_values) // 2]
        print(f"\n  Median AF of matched MEIs: {median:.4f}")

    print("\n── MEI class breakdown (hits) ──")
    for svt, n in svtype_counts.most_common():
        print(f"  {svt:10s}  {n:6,}")

    print("\n── Top candidate TE families with MEI overlap ──")
    top = sorted(family_hit.keys(),
                 key=lambda f: family_hit[f] / max(family_total[f], 1),
                 reverse=True)[:10]
    print(f"  {'Family':20s}  {'Hits':>6}  {'Total':>6}  {'Overlap%':>9}")
    for fam in top:
        h = family_hit[fam]
        t = family_total[fam]
        print(f"  {fam:20s}  {h:6,}  {t:6,}  {pct(h,t):>9}")

    # ── Write machine-readable outputs ────────────────────────────────────────
    out_summary = RESULTS / "polymorphism_summary.tsv"
    with open(out_summary, "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["metric", "value"])
        w.writerow(["n_candidates", n_cand])
        w.writerow(["n_mei_overlap", n_hits])
        w.writerow(["pct_mei_overlap", f"{n_hits*100/n_cand:.2f}"])
        w.writerow(["n_no_overlap", len(no_hits)])
        w.writerow(["pct_no_overlap", f"{len(no_hits)*100/n_cand:.2f}"])
        if af_values:
            w.writerow(["median_af_of_hits", f"{median:.4f}"])
    print(f"\nSummary written: {out_summary}")

    out_af = RESULTS / "af_distribution.tsv"
    with open(out_af, "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["af_bin", "count"])
        for label, n in af_bins.most_common():
            w.writerow([label, n])
    print(f"AF distribution written: {out_af}")


if __name__ == "__main__":
    main()
