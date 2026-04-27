# DGX Spark Porting Guide

Handoff document for a coding agent (or future-you) bringing this pipeline up on
an **NVIDIA DGX Spark** workstation, after development on UCI HPC3 (SLURM).

Reference snapshot: tag `v0.1-hpc-uci` (commit `67d2d9f`).

---

## TL;DR

1. **Do NOT install SLURM on the DGX Spark.** It's a single-node workstation; SLURM
   is overkill and adds maintenance burden. All the SLURM wrappers in this repo are
   thin `sbatch` launchers around plain `bash` scripts — just call the bash scripts
   directly.
2. **Verify ARM64 (`aarch64`) compatibility** of the bioinformatics stack before
   trying to recreate the conda env — DGX Spark uses NVIDIA's GB10 (Arm Neoverse).
   Bioconda has spotty ARM support and this is the most likely blocker.
3. **You are inheriting a known root-cause bug** (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md) Issue #1):
   the STAR index needs to be rebuilt with a real gene GTF, not the TE-only GTF
   currently in the repo. Plan to do this on the DGX before re-running validation.

---

## Should I install SLURM on the DGX Spark?

**Recommendation: No.** Reasons:

- DGX Spark is one node. SLURM's value is multi-node scheduling, fair-share queues,
  and resource accounting across users. None of that applies on a single workstation.
- Single-node SLURM (slurmctld + slurmd on localhost) is possible but ~hours of
  config work, then you still have to fight munge keys, cgroup setup, and updates.
- The repo's SLURM wrappers (`sbatch_*.sh`, `setup/sbatch_*.sh`) are 5–15 lines of
  `#SBATCH` directives followed by a single `bash scripts/X.sh` call. They are
  trivially replaceable.

**Better alternatives on a single workstation:**

| Need | Tool |
|---|---|
| Run a long job in the background | `nohup`, `tmux`, `screen` |
| Queue several jobs serially | A simple bash script: `bash a.sh && bash b.sh && bash c.sh` |
| Limit CPU/memory of a job | `systemd-run --scope -p MemoryMax=64G -p CPUQuota=800% bash run.sh` or `nice` |
| Track runtime / resources | `/usr/bin/time -v`, or `cgroups`-based tools |
| Reproducible env per job | `conda activate` inside the script (already in `run_pipeline.sh`) |

If you really want a job-queue feel, lightweight options are **`task-spooler` (`tsp`)**
or **`pueue`** — both install in seconds and require no daemon configuration.

---

## What this pipeline actually does (so you don't have to read every script)

End-to-end, single-cell-RNA-seq style validation of soloTE on synthetic TE reads:

1. `01_select_te_loci.R` — pick 10 TE loci from RepeatMasker → `ground_truth/`
2. `02_extract_sequences.sh` — `bedtools getfasta` to build `synthetic_transcriptome.fa`
3. `03_create_expression_profile.R` — define UMIs per cell × locus
4. `04_simulate_reads.sh` — `wgsim` simulates reads from the TE FASTA
5. `05_add_barcodes.py` — adds 16-bp 10x cell barcodes + 12-bp UMIs (with PCR duplication)
6. `06_align_starsolo.sh` — `STAR --runMode alignReads` in STARsolo mode
7. `07_run_solote.sh` — runs `software/SoloTE/SoloTE_pipeline.py` on the BAM
8. `08_validate_results.R` — compares observed counts to ground truth, writes
   `validation_report/`

`scripts/run_pipeline.sh` orchestrates all eight (with archiving via
`scripts/00_archive_and_clean.sh`).

---

## Porting checklist

### 1. Repository

```bash
git clone https://github.com/jcbclffrd/soloTEmvpWGsim.git
cd soloTEmvpWGsim
git checkout v0.1-hpc-uci   # known-good HPC3 snapshot, then branch from here
git switch -c dgx-spark-port
```

### 2. Architecture sanity check

```bash
uname -m   # expect: aarch64
```

If `aarch64`, **stop and verify each tool's ARM64 availability** before recreating
the env. Critical tools:

| Tool | Notes for ARM64 |
|---|---|
| **STAR** | No official aarch64 binary. May need to compile from source (`make STAR`) — straightforward but not free. Verify it builds. |
| **samtools / htslib / bedtools** | Have ARM64 conda packages on `bioconda` — usually fine. |
| **wgsim** | Tiny C program, will compile from source in seconds if no package. |
| **R + tidyverse** | Available on `conda-forge` for ARM64. Slow first install. |
| **soloTE** | Pure Python (`software/SoloTE/SoloTE_pipeline.py`); only depends on `pysam`, `pandas`, `numpy` — all ARM-friendly. |

If `x86_64` (e.g. you're using Spark in an x86 emulation mode), use the existing
`environment.yml` directly.

### 3. Recreate the environment

```bash
# Install miniconda for aarch64 if not already present:
#   https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh

conda env create -f environment.yml -n solote_validation
conda activate solote_validation

# Verify the critical binaries:
STAR --version
samtools --version | head -1
bedtools --version
wgsim 2>&1 | head -1
Rscript -e 'cat(R.version.string, "\n")'
python -c "import pysam, pandas, numpy; print('ok')"
```

If `STAR` is missing for ARM64, build it:

```bash
git clone https://github.com/alexdobin/STAR.git
cd STAR/source && make STAR
# Place the resulting STAR binary on PATH (e.g. cp into the conda env's bin/)
```

### 4. References

T2T-CHM13v2.0 genome (~3 GB) and the STAR index (~22 GB) are **not in git**. Two options:

- **Option A — rebuild on DGX** (recommended; addresses [KNOWN_ISSUES.md](KNOWN_ISSUES.md) Issue #1):
  1. Download genome: `bash setup/00_setup_references.sh`
  2. **Replace `selected_te_loci.gtf` with a real gene GTF** for T2T-CHM13v2.0
     before building the index. Suggested source: T2T CHM13 GENCODE/RefSeq liftover
     (e.g. `chm13v2.0_RefSeq_Liftoff_v5.1.gff3` from
     `https://github.com/marbl/CHM13/`). Convert to GTF if needed.
  3. Edit `setup/01_build_star_index.sh` to point `GTF_FILE` at the real gene GTF.
  4. Run `bash setup/01_build_star_index.sh` (no `sbatch` wrapper needed).

- **Option B — copy from HPC3** (if you have access and want a faster start):
  ```bash
  rsync -av --progress hpc3.rcic.uci.edu:/dfs7/swaruplab/jcliffo1/soloTEmvpWGsim/references/ ./references/
  ```
  But note: the index from HPC3 has the broken TE-only GTF. You will reproduce
  the same poor validation metrics.

### 5. Run the pipeline (no SLURM)

```bash
# All scripts already use $SCRIPT_DIR/$REPO_ROOT — no path edits needed.
bash scripts/run_pipeline.sh
```

The orchestrator handles archiving, conda activation, and step ordering.
For long runs, use `tmux` or `nohup`:

```bash
tmux new -s solote
bash scripts/run_pipeline.sh 2>&1 | tee logs/dgx_pipeline_$(date +%Y%m%d_%H%M%S).log
# Detach: Ctrl-b d   |   Reattach: tmux attach -t solote
```

### 6. SLURM wrapper scripts — what to ignore

These are HPC3-specific and have **no value on the DGX**:

```
sbatch_run_pipeline.sh
sbatch_validate_only.sh
setup/sbatch_00_setup_references.sh
setup/sbatch_01_build_star_index.sh
setup/sbatch_02_install_solote.sh
setup/sbatch_recreate_environment.sh
setup/sbatch_redownload_genome.sh
```

Just call the underlying non-`sbatch_*` script of the same name. Do not delete them
— they are still useful if you ever return to HPC3.

### 7. Resource considerations on DGX Spark

- **Memory**: STAR genome generation needs ~32 GB RAM; alignment needs ~30 GB. The
  Spark's 128 GB unified memory is plenty, but watch for GPU contention if other
  users are running CUDA jobs.
- **Disk**: Plan for ~30 GB for refs + ~5 GB per pipeline run (archived outputs).
- **CPUs**: STAR's `--runThreadN` is currently set to 16 in
  [setup/01_build_star_index.sh](setup/01_build_star_index.sh) and
  [scripts/06_align_starsolo.sh](scripts/06_align_starsolo.sh). The Spark's GB10
  has 20 Arm cores — leave headroom for I/O and use `--runThreadN 16` or `--runThreadN 18`.
- **GPU**: This pipeline does **not** use the GPU. STAR is CPU-only. If you want GPU
  acceleration for the alignment step, look at NVIDIA's `Parabricks` (`fq2bam`) — but
  it's a different aligner (BWA/STAR-via-CUDA) and would need new validation.

---

## Open work for the DGX agent

In priority order:

1. **Rebuild STAR index with a real T2T-CHM13 gene GTF.** This is the single most
   important fix. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) Issue #1 for full mechanism.
   Until this is done, validation metrics will look broken (0.4 % precision,
   60–94 % undercounting) regardless of any other change.
2. **Re-run the pipeline** with the rebuilt index and confirm Issue #1 symptoms
   are resolved.
3. **Investigate Issue #3** (soloTE locus resolution on Alu/L1) only after #1 is
   fixed and you have a clean baseline.
4. **(Optional)** Add a small set of housekeeping-gene reads to the synthetic FASTQ
   ([scripts/04_simulate_reads.sh](scripts/04_simulate_reads.sh)) to better mimic
   real scRNA-seq library composition.

---

## Files an agent will want to read first

- [README.md](README.md) — high-level overview
- [TUTORIAL.md](TUTORIAL.md) — step-by-step walkthrough
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md) — current bugs and root-cause analysis
- [config.yaml](config.yaml) — all tunable parameters in one place
- [scripts/run_pipeline.sh](scripts/run_pipeline.sh) — the orchestrator
- [environment.yml](environment.yml) — conda dependencies

Skip on first read: the `sbatch_*.sh` wrappers (HPC3-specific) and `software/SoloTE/`
(third-party, vendored).
