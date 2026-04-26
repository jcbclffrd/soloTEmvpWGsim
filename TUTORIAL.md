# soloTEmvpWGsim Tutorial

**Step-by-step guide for running the soloTE validation pipeline**

This tutorial walks you through the complete workflow from setup to validation results, explaining what each step does and what to expect.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup](#setup)
3. [Running the Pipeline](#running-the-pipeline)
4. [Understanding the Results](#understanding-the-results)
5. [Customization](#customization)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

- **Operating System**: Linux (tested on Ubuntu 20.04+, CentOS 7+, Rocky Linux 8+)
- **Memory**: 32 GB RAM minimum (for STAR index build)
- **Disk Space**: 35 GB free space
  - T2T genome: ~3 GB
  - STAR index: ~30 GB
  - Pipeline outputs: ~2 GB
- **Internet**: For downloading references and software

### Software Requirements

**For HPC systems (e.g., RCIC UCI HPC3)**:
- Access to environment modules system
- Conda/miniconda available as a module (e.g., `module load miniconda3/25.11.1`)
- No need to install conda yourself

**For personal systems**:
- Conda or Miniconda pre-installed ([installation guide](https://docs.conda.io/en/latest/miniconda.html))

### Required Knowledge

- Basic command line usage (bash)
- Familiarity with conda/bioconda
- Understanding of single-cell RNA-seq concepts (helpful but not required)
- **HPC users**: Familiarity with environment modules (`module load` commands)

---

## Setup

### Step 1: Clone Repository

```bash
# Clone the repository
git clone <repo-url> soloTEmvpWGsim
cd soloTEmvpWGsim

# Check directory structure
ls -lh
```

You should see:
- `config.yaml` - Configuration file
- `environment.yml` - Conda environment
- `setup/` - Setup scripts
- `scripts/` - Pipeline scripts
- `references/` - Empty (will be populated)

### Step 2: Create Conda Environment

**For HPC Systems (RCIC UCI)**: Follow these steps to comply with HPC best practices:

```bash
# Load conda module
module load miniconda3/25.11.1  # Or latest available version

# Initialize conda for bash (one-time setup)
conda init bash

# IMPORTANT: Move conda initialization lines from ~/.bashrc
# Edit ~/.bashrc and move ALL lines between:
#   ">>> conda initialize >>>" and "<<< conda initialize <<<"
# to a new file: ~/.mycondainit-25.11.1
# This prevents conda from interfering with other software modules.

# Source the conda initialization file
. ~/.mycondainit-25.11.1

# Accept conda Terms of Service (required as of 2025+)
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create environment (takes ~5-10 minutes)
conda env create -f environment.yml

# Activate environment
conda activate solote_validation

# Verify installation
python --version   # Should show Python 3.9+
R --version        # Should show R 4.1+
STAR --version     # Should show STAR 2.7.10a+
```

**For future sessions**, you only need:
```bash
module load miniconda3/25.11.1
. ~/.mycondainit-25.11.1
conda activate solote_validation
```

**Note**: Always activate this environment before running any pipeline commands.

**For non-HPC systems** (personal conda installation):
```bash
conda env create -f environment.yml
conda activate solote_validation
```

### Step 3: Download T2T Reference Genome and Annotations

```bash
bash setup/00_setup_references.sh
```

**What this does**:
- Downloads T2T-CHM13v2.0 genome from NCBI (~1 GB compressed, ~3 GB uncompressed)
- Downloads RepeatMasker annotations from UCSC (~300 MB)
- Filters RepeatMasker to TE classes only (LINE, SINE, LTR, DNA, RC)
- Creates genome index with samtools faidx

**Runtime**: ~10-15 minutes (depends on internet speed)

**Output**: You should see:
```
references/genome/T2T-CHM13v2.0.fa
references/genome/T2T-CHM13v2.0.fa.fai
references/annotations/T2T-CHM13v2.0_RepeatMasker.bed
references/annotations/T2T-CHM13v2.0_RepeatMasker_SoloTE_filtered.bed
```

### Step 4: Build STAR Index

```bash
bash setup/01_build_star_index.sh
```

**What this does**:
- Builds STAR genome index for T2T-CHM13v2.0
- Uses default parameters optimized for human genome

**Runtime**: ~20-30 minutes  
**Memory**: Uses ~30 GB RAM  
**Disk**: Creates ~30 GB of index files

**Output**: `references/STARsolo_index/` with multiple index files

**Tip**: If memory is limited, you can reduce threads by setting:
```bash
export THREADS=8  # Default is 16
bash setup/01_build_star_index.sh
```

### Step 5: Install soloTE

```bash
bash setup/02_install_solote.sh
```

**What this does**:
- Clones soloTE from GitHub
- Verifies Python dependencies (pysam, numpy, pandas)

**Runtime**: ~1-2 minutes

**Output**: `software/SoloTE/` with soloTE scripts

**Verification**:
```bash
ls software/SoloTE/SoloTE_pipeline.py
# Should show the main soloTE script
```

### Setup Complete!

At this point you should have:
- Conda environment activated
- T2T genome and annotations downloaded
- STAR index built
- soloTE installed

**Disk usage check**:
```bash
du -sh references/*
# genome: ~3 GB
# annotations: ~500 MB
# STARsolo_index: ~30 GB
```

---

## Running the Pipeline

You can run the entire pipeline with one command, or step-by-step for more control.

### Option A: Run Complete Pipeline (Recommended)

```bash
bash scripts/run_pipeline.sh
```

This runs all 8 steps sequentially (~30-60 minutes total).

### Option B: Run Individual Steps

For more control or to resume after interruption:

#### Step 1: Select TE Loci (~1 minute)

```bash
Rscript scripts/01_select_te_loci.R
```

**What happens**:
- Randomly selects 10 well-separated TE loci from RepeatMasker
- Ensures loci are from target families (Alu, L1, L2, MIR, etc.)
- Creates ground truth table

**Output**:
```
ground_truth/selected_te_loci.tsv      # Ground truth metadata
ground_truth/selected_te_loci.bed      # BED format for bedtools
```

**Expected output**:
```
Selected TE loci summary:
  Total loci: 10
  By family:
    Alu: 3
    L1: 2
    L2: 2
    MIR: 2
    ERVL-MaLR: 1
```

#### Step 2: Extract TE Sequences (~1 minute)

```bash
bash scripts/02_extract_sequences.sh
```

**What happens**:
- Uses bedtools getfasta to extract selected TE sequences from genome
- Creates synthetic transcriptome FASTA

**Output**:
```
synthetic_data/transcriptome/synthetic_transcriptome.fa
synthetic_data/transcriptome/synthetic_transcriptome.fa.fai
```

**Verification**:
```bash
grep -c "^>" synthetic_data/transcriptome/synthetic_transcriptome.fa
# Should show: 10
```

#### Step 3: Create Expression Profile (~1 minute)

```bash
Rscript scripts/03_create_expression_profile.R
```

**What happens**:
- Generates 100 synthetic cell barcodes
- Assigns uniform expression (100 UMIs per TE per cell)
- Creates expression profile table

**Output**:
```
synthetic_data/transcriptome/expression_profile.tsv
synthetic_data/transcriptome/cell_barcodes.txt
synthetic_data/transcriptome/expression_summary.txt
```

**Key values**:
- 100 cells
- 10 TE loci
- 100 UMIs per locus per cell
- 1,000 total UMIs per cell

#### Step 4: Simulate Reads (~5-10 minutes)

```bash
bash scripts/04_simulate_reads.sh
```

**What happens**:
- Uses wgsim to generate 5 million paired-end reads (50K reads/cell x 100 cells)
- 150bp read length, 0.1% error rate
- No barcodes yet (added in next step)

**Output**:
```
synthetic_data/fastqs/synthetic_reads_R1.fastq
synthetic_data/fastqs/synthetic_reads_R2.fastq
```

**File sizes**: ~1-2 GB each (uncompressed)

#### Step 5: Add 10x Barcodes (~2-5 minutes)

```bash
python scripts/05_add_barcodes.py
```

**What happens**:
- Prepends 16bp cell barcode + 12bp UMI to R1 reads
- Assigns reads evenly across 100 cells (500 reads/cell)
- Compresses output files

**Output**:
```
synthetic_data/fastqs/synthetic_10x_S1_L001_R1_001.fastq.gz
synthetic_data/fastqs/synthetic_10x_S1_L001_R2_001.fastq.gz
```

**R1 format**: `[16bp CB][12bp UMI][remaining sequence]`

#### Step 6: Align with STARsolo (~5-15 minutes)

```bash
bash scripts/06_align_starsolo.sh
```

**What happens**:
- Aligns synthetic reads to T2T genome using STARsolo
- Uses production parameters: `--outFilterMultimapNmax 100`
- Generates cell x gene UMI count matrices

**Output**:
```
synthetic_data/outputs/star_alignment/Aligned.sortedByCoord.out.bam
synthetic_data/outputs/star_alignment/Solo.out/
```

**Alignment stats**:
```bash
samtools flagstat synthetic_data/outputs/star_alignment/Aligned.sortedByCoord.out.bam
```

Expected: ~5 million reads, >90% mapped

#### Step 7: Run soloTE (~10-20 minutes)

```bash
bash scripts/07_run_solote.sh
```

**What happens**:
- Runs soloTE on aligned BAM
- Quantifies TEs at multiple levels:
  - **Locus-level** (unique mappers, MAPQ ≥ 255)
  - Family-level (multi-mappers, MAPQ < 255)
  - Subfamily-level
  - Class-level

**Output**:
```
synthetic_data/outputs/solote/synthetic_validation_SoloTE_output/
  ├── synthetic_validation_locustes_MATRIX/    # Locus-level (KEY OUTPUT)
  ├── synthetic_validation_familytes_MATRIX/
  ├── synthetic_validation_subfamilytes_MATRIX/
  └── synthetic_validation_classtes_MATRIX/
```

Each matrix directory contains:
- `barcodes.tsv` - Cell barcodes
- `features.tsv` - TE features
- `matrix.mtx` - Sparse count matrix

#### Step 8: Validate Results (~1-2 minutes)

```bash
Rscript scripts/08_validate_results.R
```

**What happens**:
- Compares soloTE output vs. ground truth
- Calculates precision, recall, correlation
- Generates validation plots

**Output**:
```
validation_report/validation_metrics.tsv
validation_report/validation_plots.pdf
validation_report/matched_loci.tsv
validation_report/per_locus_accuracy.tsv
```

---

## Understanding the Results

### Validation Metrics

Open `validation_report/validation_metrics.tsv`:

```bash
cat validation_report/validation_metrics.tsv
```

**Key metrics**:

| Metric | Expected | Meaning |
|--------|----------|---------|
| `precision` | ≥ 0.95 | % of detected TEs that are true positives |
| `recall` | ≥ 0.95 | % of true TEs that were detected |
| `pearson_r` | ≥ 0.90 | Correlation of observed vs. expected UMI counts |
| `overall_pass` | TRUE | All thresholds met |

### Interpreting Results

**✓ VALIDATION PASSED** (precision ≥0.95, recall ≥0.95, r ≥0.90)
→ soloTE accurately detects and quantifies synthetic TE loci  
→ Ready for use on real data

**✗ VALIDATION FAILED**
→ Check `validation_report/per_locus_accuracy.tsv` for which TEs failed  
→ Review detection issues in `validation_report/matched_loci.tsv`  
→ May need to adjust simulation parameters or soloTE settings

### Validation Plots

View `validation_report/validation_plots.pdf`:

1. **Detection Accuracy**: Bar chart of precision/recall/F1
2. **Expected vs Observed**: Scatter plot of UMI counts
3. **Per-Locus Error**: Bar chart showing error for each TE

---

## Customization

### Changing Simulation Parameters

Edit `config.yaml`:

```yaml
simulation:
  n_cells: 200           # Increase to 200 cells
  n_te_loci: 20          # Increase to 20 TEs
  reads_per_cell: 100000 # More sequencing depth
  umi_per_locus: 200     # Higher expression
```

Then re-run:
```bash
bash scripts/run_pipeline.sh
```

### Selecting Different TE Families

Edit `config.yaml`:

```yaml
te_selection:
  families:
    - Alu
    - L1
    - SVA      # Add SVA elements
    - HERVK     # Add endogenous retroviruses
```

### Testing Different Scenarios

See `# EXTENSION POINT:` comments in scripts for:
- Gene contamination testing (`01_select_te_loci.R`)
- Multi-mapper scenarios (`01_select_te_loci.R`)
- Expression heterogeneity (`03_create_expression_profile.R`)

---

## Troubleshooting

### Common Issues

**Issue**: `ERROR: STAR index not found`  
**Solution**: Run `bash setup/01_build_star_index.sh`

**Issue**: `ERROR: soloTE not found`  
**Solution**: Activate conda environment: `conda activate solote_validation`

**Issue**: STAR index build fails with "cannot allocate memory"  
**Solution**: Reduce threads or increase system RAM

**Issue**: Validation fails with low recall  
**Solution**: Check if soloTE detected any TEs:
```bash
wc -l synthetic_data/outputs/solote/*/synthetic_validation_locustes_MATRIX/features.tsv
```

**Issue**: Out of disk space  
**Solution**: Clean up synthetic data (regenerates quickly):
```bash
rm -rf synthetic_data/
```

### Getting Detailed Logs

Run individual steps with verbose output:

```bash
bash -x scripts/06_align_starsolo.sh 2>&1 | tee align.log
```

---

## Next Steps

After successful validation:

1. **Understand the workflow**: Review how soloTE handles unique vs. multi-mapper reads
2. **Test on real data**: Apply soloTE to your single-cell RNA-seq datasets
3. **Extend the pipeline**: Implement gene contamination or multi-mapper testing
4. **Compare references**: Run validation with hg38 vs. T2T to quantify differences

---

## Additional Resources

- **soloTE Documentation**: https://github.com/bvaldebenitom/SoloTE
- **STAR Manual**: https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf
- **T2T Consortium**: https://github.com/marbl/CHM13
- **10x Genomics Resources**: https://www.10xgenomics.com/support

---

## Citation

If you use this pipeline, please cite:

- **soloTE**: Valdebenit et al. (2023) soloTE: Locus-level TE quantification
- **T2T-CHM13**: Nurk et al. (2022) The complete sequence of a human genome
- **STAR**: Dobin et al. (2013) STAR: ultrafast universal RNA-seq aligner
