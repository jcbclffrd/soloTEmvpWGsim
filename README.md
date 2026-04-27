# soloTEmvpWGsim

**Synthetic Validation Pipeline for soloTE Locus-Level TE Quantification**

A standalone, HPC-ready pipeline for validating soloTE's accuracy using synthetic single-cell RNA-seq data with known ground truth transposable element (TE) expression.

---

## 🚀 Quick Start (HPC)

**Designed for SLURM-based HPC systems like UCI HPC3**

```bash
# 1. Clone repository
git clone https://github.com/jcbclffrd/soloTEmvpWGsim.git
cd soloTEmvpWGsim

# 2. Run automated setup
bash hpc_quick_start.sh

# OR manually configure and submit jobs
bash configure_hpc_account.sh
cd setup && sbatch sbatch_00_setup_references.sh
```

**📖 Complete Guide**: See [HPC_SETUP.md](HPC_SETUP.md) for detailed HPC instructions

**📊 Pipeline Results**: See [PIPELINE_STATUS.md](PIPELINE_STATUS.md) for validation findings

---

## Overview

This pipeline creates synthetic 10x Chromium single-cell RNA-seq data containing known TE loci, runs it through the soloTE quantification workflow, and validates the results against ground truth. It provides a controlled testbed for assessing soloTE's locus-level TE detection accuracy.

### Key Features

- **HPC-Ready**: SLURM batch scripts with job dependencies included
- **Reproducible**: Clone and run - no hardcoded paths
- **Standalone**: Complete setup scripts download all references and build indices
- **Configurable**: All parameters controlled through `config.yaml`
- **Ground truth validation**: Known TE expression enables precision/recall metrics
- **Documented**: Comprehensive guides for HPC setup and results interpretation

### Repository Contents

| File/Directory | Purpose |
|----------------|---------|
| `hpc_quick_start.sh` | 🚀 Automated HPC setup wizard |
| `configure_hpc_account.sh` | Configure SLURM account name |
| `HPC_SETUP.md` | 📖 Complete HPC setup guide |
| `PIPELINE_STATUS.md` | 📊 Validation results and findings |
| `sbatch_run_pipeline.sh` | Main pipeline SLURM script |
| `setup/sbatch_*.sh` | Setup job scripts (references, index, software) |
| `submit_pipeline_after_index.sh` | Chain jobs with dependencies |
| `scripts/` | Pipeline step scripts (R, Python, bash) |
| `config.yaml` | Configuration parameters |

---

## Quick Start (Interactive/Local)

For non-HPC or interactive use:

```bash
# 1. Clone repository
git clone <repo-url> soloTEmvpWGsim
cd soloTEmvpWGsim

# 2. Setup conda environment (HPC systems - first time only)
# IMPORTANT: Get interactive compute node first (required on HPC)
srun -c 4 -p free --pty /bin/bash -i

# Then setup conda (wait for node allocation first)
module load miniconda3/25.11.1  # Or latest version available
conda init bash
# Move conda initialization lines from ~/.bashrc to ~/.mycondainit-25.11.1
# (lines between ">>> conda initialize >>>" and "<<< conda initialize <<<")
. ~/.mycondainit-25.11.1

# Accept conda Terms of Service (one-time)
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create environment
conda env create -f environment.yml
conda activate solote_validation

# 3. Run setup (downloads ~4GB, builds STAR index ~30GB, ~30-40 min total)
bash setup/00_setup_references.sh
bash setup/01_build_star_index.sh
bash setup/02_install_solote.sh

# 4. Run validation pipeline (~30-60 min)
bash scripts/run_pipeline.sh

# 5. Check results
cat validation_report/validation_metrics.tsv
```

**Note for HPC users**: See [TUTORIAL.md](TUTORIAL.md) for detailed conda setup instructions following HPC best practices.

See [TUTORIAL.md](TUTORIAL.md) for detailed step-by-step instructions.

---

## What This Pipeline Does

### Workflow

1. **Select TE Loci** (`01_select_te_loci.R`)  
   Selects ~10 well-separated TE loci from T2T RepeatMasker annotations (Alu, L1, L2, MIR families)

2. **Extract Sequences** (`02_extract_sequences.sh`)  
   Extracts TE sequences from T2T genome using bedtools

3. **Create Expression Profile** (`03_create_expression_profile.R`)  
   Defines expected UMI counts per locus per cell (uniform: 100 UMIs/locus/cell)

4. **Simulate Reads** (`04_simulate_reads.sh`)  
   Generates synthetic paired-end reads using wgsim (50K reads/cell x 100 cells)

5. **Add Barcodes** (`05_add_barcodes.py`)  
   Prepends 10x Chromium v3 cell barcodes (16bp) + UMIs (12bp) to R1 reads

6. **Align with STARsolo** (`06_align_starsolo.sh`)  
   Aligns to T2T genome using production parameters (`--outFilterMultimapNmax 100`)

7. **Run soloTE** (`07_run_solote.sh`)  
   Quantifies TEs at locus-level (unique mappers) and family-level (multi-mappers)

8. **Validate Results** (`08_validate_results.R`)  
   Compares soloTE output vs. ground truth: precision, recall, count accuracy

### Validation Metrics

- **Precision**: % of detected TEs that are true positives (target: ≥95%)
- **Recall**: % of true TEs that were detected (target: ≥95%)
- **Count Accuracy**: Pearson correlation of observed vs. expected UMIs (target: r ≥0.90)

---

## Repository Structure

```
soloTEmvpWGsim/
├── README.md                   # This file
├── TUTORIAL.md                 # Detailed walkthrough
├── config.yaml                 # Configuration parameters (EDIT THIS)
├── environment.yml             # Conda environment
├── .gitignore                  # Git ignore patterns
│
├── setup/                      # One-time setup scripts
│   ├── 00_setup_references.sh      # Download T2T genome + annotations
│   ├── 01_build_star_index.sh      # Build STAR index
│   └── 02_install_solote.sh        # Install soloTE
│
├── scripts/                    # Pipeline scripts
│   ├── run_pipeline.sh             # Master runner (all steps)
│   ├── 01_select_te_loci.R         # Select TE loci
│   ├── 02_extract_sequences.sh     # Extract sequences
│   ├── 03_create_expression_profile.R  # Create expression
│   ├── 04_simulate_reads.sh        # Simulate reads
│   ├── 05_add_barcodes.py          # Add barcodes
│   ├── 06_align_starsolo.sh        # STARsolo alignment
│   ├── 07_run_solote.sh            # soloTE quantification
│   └── 08_validate_results.R       # Validate results
│
├── references/                 # Empty - populated by setup
│   ├── genome/                     # T2T-CHM13v2.0 genome
│   ├── annotations/                # RepeatMasker annotations
│   └── STARsolo_index/             # STAR index
│
├── ground_truth/               # Selected TE loci metadata
├── synthetic_data/             # Generated by pipeline
│   ├── transcriptome/              # TE sequences + expression
│   ├── fastqs/                     # Synthetic reads
│   └── outputs/                    # Alignment + soloTE outputs
│
└── validation_report/          # Validation results
    ├── validation_metrics.tsv      # Pass/fail metrics
    ├── validation_plots.pdf        # Visualizations
    └── per_locus_accuracy.tsv      # Per-locus accuracy
```

---

## Configuration

Edit `config.yaml` to customize:

- **Simulation parameters**: Number of cells, reads per cell, UMIs per locus
- **TE selection**: Target families, size range, chromosome filter
- **Alignment parameters**: Threads, multimapper handling
- **Validation thresholds**: Minimum precision/recall/correlation

Example:
```yaml
simulation:
  n_cells: 100           # Number of synthetic cells
  n_te_loci: 10          # Number of TE loci in ground truth
  reads_per_cell: 50000  # Sequencing depth
  umi_per_locus: 100     # Target UMI count per TE per cell
```

---

## Requirements

### Software (via conda environment)
- Python 3.9+
- R 4.1+
- STAR 2.7.10a+
- samtools 1.15+
- bedtools 2.30+
- wgsim (from samtools)
- soloTE (installed by setup script)

### Computational Resources
- **Disk space**: ~35 GB (genome + index + outputs)
- **Memory**: 32 GB RAM recommended (STAR index build)
- **Runtime**: ~1 hour (30-40 min setup + 30-60 min pipeline)

---

## Extension Points

The pipeline is designed to be easily extended for more complex testing:

### 1. Gene Contamination Testing
**Modify**: `01_select_te_loci.R` to select intronic TEs  
**Purpose**: Test if soloTE correctly separates TE reads from gene reads

### 2. Multi-mapper Testing
**Modify**: `01_select_te_loci.R` to select young Alu subfamilies  
**Purpose**: Test soloTE's handling of highly similar TE copies

### 3. Expression Heterogeneity
**Modify**: `03_create_expression_profile.R` for zero-inflated distributions  
**Purpose**: Test realistic dropout and cell-type-specific patterns

### 4. Larger Datasets
**Modify**: `config.yaml` to increase cells/loci  
**Purpose**: Test scalability and accuracy at production scale

See script comments marked with `# EXTENSION POINT:` for implementation details.

---

## Citations

- **T2T-CHM13**: Nurk et al. (2022) The complete sequence of a human genome. *Science*
- **soloTE**: Valdebenit et al. (2023) soloTE: Locus-level TE quantification in scRNA-seq
- **STAR**: Dobin et al. (2013) STAR: ultrafast universal RNA-seq aligner

---

## License

This pipeline is provided as-is for validation and testing purposes.

---

## Troubleshooting

### Setup Issues

**STAR index build fails with memory error**  
→ Increase available RAM or reduce thread count in `01_build_star_index.sh`

**soloTE not found after installation**  
→ Ensure conda environment is activated: `conda activate solote_validation`

### Pipeline Issues

**No TEs detected by soloTE**  
→ Check if synthetic reads aligned: `samtools view -c synthetic_data/outputs/star_alignment/Aligned.sortedByCoord.out.bam`

**Validation fails (low precision/recall)**  
→ Check soloTE output format matches expected coordinate parsing in `08_validate_results.R`

**Out of disk space**  
→ Pipeline needs ~35GB. Clean up with: `rm -rf synthetic_data/` (regenerates quickly)

### Getting Help

For issues with:
- **soloTE**: https://github.com/bvaldebenitom/SoloTE/issues
- **STAR**: https://github.com/alexdobin/STAR/issues
- **This pipeline**: [Create an issue on GitHub]

---

## Development

To contribute or modify this pipeline:

1. Fork the repository
2. Create a feature branch
3. Make changes with clear commit messages
4. Test with `bash scripts/run_pipeline.sh`
5. Submit a pull request

All scripts include detailed comments and extension points for future work.
