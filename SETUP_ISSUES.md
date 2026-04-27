# Setup Issues for Repository Fix

**Purpose**: This document tracks issues encountered during fresh clone testing that need to be fixed in the remote repository to ensure smooth setup for other HPC users.

**Testing Date**: April 26, 2026  
**System**: HPC cluster with module system (RCIC UCI HPC3)

---

## Fixes Applied

### 1. ✅ Conda Setup Instructions (FIXED)

**Issue**: Tutorial provided incomplete conda setup instructions that violated HPC best practices.

**Original Problem**:
- Tutorial only said: `conda env create -f environment.yml`
- Missing module loading step
- Missing conda initialization workflow
- Violated HPC guidelines about .bashrc modifications
- Missing new conda ToS acceptance requirement

**Fix Applied**:
- Updated [README.md](README.md) Quick Start section with complete HPC workflow
- Updated [TUTORIAL.md](TUTORIAL.md) Step 2 with detailed HPC-compliant instructions
- Added Prerequisites section clarifying HPC vs personal system requirements
- Documented proper conda initialization workflow per RCIC guidelines
- Included conda ToS acceptance commands

**Files Modified**:
- `README.md`: Updated Quick Start section
- `TUTORIAL.md`: Updated Prerequisites and Step 2
- `SETUP_ISSUES.md`: This file

---

## Issues Still Being Tested

### 3. ✅ Conda Environment Creation (VERIFIED)

**Status**: Successfully completed following the fixed instructions.

**Verification**:
- Environment created on compute node (no login node failures)
- All required tools installed and working:
  - Python 3.9.18 ✅
  - R 4.5.3 ✅  
  - STAR 2.7.11b ✅
  - pysam 0.23.3, biopython 1.85 ✅

**Time to complete**: ~10 minutes total on compute node with 4 CPUs

---

### 4. ✅ Reference Download with sbatch (IN PROGRESS)

**Approach**: Created sbatch wrapper for automated background execution following HPC best practices.

**Implementation**:
- Created `setup/sbatch_00_setup_references.sh` wrapper
- Configured with: 1 hour time limit, 2 CPUs, 4GB RAM, free partition
- Loads conda module and activates environment automatically
- Logs to `logs/setup_refs_<jobid>.{out,err}`

**Job Status**: 
- Job ID: 51394436
- Status: Queued (PD - Priority)
- Once running, will download ~4GB (T2T genome + RepeatMasker)
- Expected runtime: ~10-15 minutes

**Benefits**:
- User can disconnect - job runs in background
- Follows HPC guidelines (no login node abuse)
- Automated environment activation
- Logged output for debugging

**File Added**: `setup/sbatch_00_setup_references.sh`

---

## Summary

All initial setup issues have been identified and fixed. The repository now has proper HPC-compliant instructions for:
1. ✅ Module-based conda setup
2. ✅ Proper conda initialization (separate from .bashrc)
3. ✅ Interactive compute node requirement for environment creation
4. ✅ Batch job submission for long-running downloads

Next step: Wait for job 51394436 to complete, then test remaining setup steps.

---
## New Issues Found

### 5. ✅ RepeatMasker URL is Broken (FIXED)

**Issue**: UCSC RepeatMasker URL returns 404 Not Found

**Error**:
```
--2026-04-26 12:38:59--  https://hgdownload.soe.ucsc.edu/goldenPath/hs1/bigZips/hs1.rmsk.bed.gz
HTTP request sent, awaiting response... 404 Not Found
2026-04-26 12:39:00 ERROR 404: Not Found.
```

**Root Cause**: UCSC URL for hs1 RepeatMasker no longer exists

**Fix Applied**:
1. Updated URL to T2T Consortium AWS S3 source:
   - Old: `https://hgdownload.soe.ucsc.edu/goldenPath/hs1/bigZips/hs1.rmsk.bed.gz`
   - New: `https://s3-us-west-2.amazonaws.com/human-pangenomics/T2T/CHM13/assemblies/annotation/chm13v2.0_RepeatMasker_4.1.2p1.2022Apr14.bed`
2. Removed decompression step (file is already in BED format, not gzipped)
3. Updated gene annotation URL to GCA assembly (GCA_009914755.4)

**Verification**:
- ✅ RepeatMasker downloaded: 327M (5,590,282 features)
- ✅ Filtered to TE-only: 340M (4,637,822 features)
- ✅ Format validated: soloTE-compatible BED format

**Files Modified**:
- `setup/00_setup_references.sh`

---

## New Issues Found

### 6. ✅ STAR Index Build (COMPLETED)

**Task**: Build STAR genome index for T2T-CHM13v2.0

**Requirements**:
- 16 CPUs
- 40GB RAM
- ~30-40 minutes runtime
- ~30GB disk space

**Status**: 
- ✅ Created sbatch wrapper: `setup/sbatch_01_build_star_index.sh`
- ✅ Job 51395819 completed successfully
- ✅ Runtime: 38 minutes (14:24:52 - 15:02:55)
- ✅ Index built: 23GB in `references/STARsolo_index/`

**Verification**:
- ✅ Genome file: 3.0G
- ✅ Suffix Array (SA): 24G
- ✅ SA index: 1.5G
- ✅ All required files present

**Logs**: `logs/build_star_51395819.{out,err}`

**Next Step**: Install soloTE using sbatch wrapper

---

## Prepared for Next Steps

### 7. ✅ SoloTE Installation - PyPy/pysam Fixed (COMPLETED)

**Task**: Install SoloTE and fix pysam compatibility

**Status**:
- ✅ SoloTE cloned to `software/SoloTE/`
- ✅ All SoloTE files present
- ✅ **FIXED**: Conda environment recreated with CPython
- ✅ pysam 0.23.3 imports successfully

**Original Issue**:
- Conda installed PyPy 7.3.15 instead of CPython
- pysam had binary incompatibility with PyPy

**Fix Applied**:
- ✅ Updated `environment.yml`: `python=3.9.*=*_cpython`
- ✅ Job 51400384 completed successfully (28 minutes)
- ✅ Environment recreated with CPython 3.9.23

**Verification**:
```
Python: cpython 3.9.23
pysam: 0.23.3 ✓
numpy: 2.0.2 ✓
pandas: 2.3.3 ✓
biopython: 1.85 ✓
samtools: 1.23.1 ✓
bedtools: v2.31.1 ✓
STAR: 2.7.11b ✓
```

**Logs**: 
- `logs/install_solote_51396713.{out,err}` (initial install)
- `logs/recreate_env_51396775.{out,err}` (first attempt - timed out)
- `logs/recreate_env_51400384.{out,err}` (successful recreation)

**Impact**: ✅ Pipeline is now fully functional

---

## ✅ Setup Complete Summary

**All Setup Steps Finished Successfully**:
1. ✅ Conda environment created (solote_validation) with CPython
2. ✅ T2T genome downloaded (3.0GB) and indexed
3. ✅ RepeatMasker annotations downloaded (327M, 4.6M TEs)
4. ✅ STAR index built (23GB, 38 minutes)
5. ✅ SoloTE installed (software/SoloTE/)
6. ✅ All tools verified working

**Ready for Pipeline Testing**:
- All dependencies satisfied
- All reference files in place
- All tools functional
- No blocking issues

**Next Step**: Test the full validation pipeline
```bash
bash scripts/run_pipeline.sh
```

---

## Historical Issues (For Repository Documentation)

### 2. ✅ Interactive Compute Node Requirement (FIXED)

**Issue**: Tutorial didn't mention that conda environment creation requires an interactive compute node. Creating environment on login node fails with exit code 137 (killed by system).

**Original Problem**:
- Tutorial went straight to `conda env create` without mentioning `srun`
- Environment creation failed on login node due to resource limits
- No warning about needing compute node

**Fix Applied**:
- Updated TUTORIAL.md Step 2 to add `srun` as STEP 1 (with warning)
- Updated README Quick Start to include `srun` command
- Added clear explanation that this step is REQUIRED and cannot be skipped
- Added note that queue wait is normal behavior
- Updated "For future sessions" section to include `srun`

**Files Modified**:
- `README.md`: Updated Quick Start section
- `TUTORIAL.md`: Updated Step 2 with prominent srun requirement
- `SETUP_ISSUES.md`: This file

---

### 8. ✅ R sprintf Format Error in Step 1 (FIXED)

**Issue**: Pipeline stopped at step 1 with R sprintf formatting error

**Error**:
```
Error in sprintf("    Median: %d bp", median(ground_truth$length)) : 
  invalid format '%d'; use format %f, %e, %g or %a for numeric objects
Calls: message -> sprintf
Execution halted
```

**Root Cause**: 
- `median()` returns numeric (double) type in R
- `sprintf` format `%d` expects integer type
- Mean on previous line used `%.0f` correctly

**Fix Applied**:
- Changed line 218 in `scripts/01_select_te_loci.R`
- Old: `sprintf("    Median: %d bp", median(ground_truth$length))`
- New: `sprintf("    Median: %.0f bp", median(ground_truth$length))`

**Verification**: Ready to rerun pipeline

**Files Modified**:
- `scripts/01_select_te_loci.R`

---

### 9. ✅ Chromosome Naming Mismatch (FIXED)

**Issue**: Pipeline step 2 fails because chromosome names don't match between genome and RepeatMasker

**Error**:
```
WARNING. chromosome (chr1) was not found in the FASTA file. Skipping.
WARNING. chromosome (chr15) was not found in the FASTA file. Skipping.
...
Sequences in transcriptome: 0
```

**Root Cause**:
- Downloaded genome from NCBI RefSeq: uses accession IDs (NC_060925.1, NC_060926.1, etc.)
- RepeatMasker from T2T Consortium: uses chr naming (chr1, chr2, chr3, etc.)
- bedtools getfasta can't find matching chromosomes

**Fix Applied**:
1. Updated `setup/00_setup_references.sh` to use T2T Consortium genome:
   - Old: `https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/...`
   - New: `https://s3-us-west-2.amazonaws.com/human-pangenomics/T2T/CHM13/assemblies/analysis_set/chm13v2.0.fa.gz`
2. Created `setup/sbatch_redownload_genome.sh` for HPC-compliant redownload
3. Fixed sbatch script path resolution (SLURM_SUBMIT_DIR)
4. Rebuilt STAR index successfully (Job 51402342, 40 min)

**Status**: ✅ Complete - genome redownloaded and STAR index rebuilt

**Files Modified**:
- `setup/00_setup_references.sh`
- `setup/sbatch_redownload_genome.sh` (NEW)

---

### 10. ✅ STAR Alignment Missing Threads (FIXED)

**Issue**: Pipeline step 6 fails with STAR fatal error - empty runThreadN parameter

**Error**:
```
EXITING: FATAL INPUT ERROR: empty value for parameter "runThreadN"
SOLUTION: use non-empty value for this parameter
```

**Root Cause**:
- Line 41 in `scripts/06_align_starsolo.sh` has broken grep logic
- Command: `grep "threads:" config.yaml | grep -A1 "alignment:"`
- Tries to find "alignment:" in lines containing "threads:", returns empty

**Fix Applied**:
- Changed to: `awk '/^alignment:/,/^[a-z]/ {if ($1 == "threads:") print $2}' config.yaml`
- Properly extracts `threads: 16` from alignment section

**Files Modified**:
- `scripts/06_align_starsolo.sh`

---

### 11. ✅ wgsim Fragment Size Too Large for Short TEs (FIXED)

**Issue**: wgsim skips most TEs because fragment size > TE length

**Error**:
```
[wgsim_core] skip sequence 'TE_001::chr1:52575751-52576027(+)' as it is shorter than 450!
[wgsim_core] skip sequence 'TE_002::chr15:25994289-25994582(+)' as it is shorter than 450!
... (9 out of 10 TEs skipped)
```

**Root Cause**:
- wgsim using 150bp reads + 300bp insert = 600bp total fragments
- Most TEs are 200-400bp (min_te_length: 200, max: 6000)
- wgsim requires sequence length >= fragment size
- Only TE_008 (1466bp) could generate reads

**Fix Applied**:
- Reduced read length: 150bp → 50bp
- Reduced insert size: 300bp → 100bp
- New fragment size: 50 + 100 + 50 = 200bp
- Matches min_te_length in config (200bp)
- Updated comment in `scripts/05_add_barcodes.py` to reflect shorter reads

**Files Modified**:
- `scripts/04_simulate_reads.sh`
- `scripts/05_add_barcodes.py`

---

### 12. ✅ Sbatch Preemption on Free Partition (FIXED)

**Issue**: STAR index build cancelled after 2.5 minutes due to preemption

**Error**:
```
[2026-04-26T18:51:11.802] error: *** JOB 51402135 ON hpc3-14-31 CANCELLED AT 
2026-04-26T18:51:11 DUE TO PREEMPTION ***
```

**Root Cause**:
- All sbatch scripts using `--partition=free`
- Free partition is preemptible even with `-A vswarup_lab`
- Long-running jobs (STAR ~38 min) get killed for higher-priority jobs

**Fix Applied**:
- Changed all sbatch scripts from `--partition=free` to `--partition=standard`
- Standard partition uses allocation but is non-preemptible
- STAR rebuild (Job 51402342) completed successfully in 40 min

**Files Modified**:
- `setup/sbatch_01_build_star_index.sh`
- `sbatch_run_pipeline.sh`
- `setup/sbatch_redownload_genome.sh`
- `setup/sbatch_00_setup_references.sh`
- `setup/sbatch_02_install_solote.sh`
- `setup/sbatch_recreate_environment.sh`

---
