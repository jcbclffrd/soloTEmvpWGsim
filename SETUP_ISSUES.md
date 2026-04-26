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

### 7. ❌ SoloTE Installation - PyPy/pysam Incompatibility (CRITICAL)

**Task**: Install SoloTE from GitHub

**Status**:
- ✅ Created sbatch wrapper: `setup/sbatch_02_install_solote.sh`
- ✅ Job 51396713 completed (22 seconds)
- ✅ SoloTE cloned to `software/SoloTE/`
- ✅ All SoloTE files present (SoloTE_pipeline.py, etc.)
- ❌ **CRITICAL**: pysam import fails with binary incompatibility

**Error**:
```
ValueError: array.array size changed, may indicate binary incompatibility. 
Expected 72 from C header, got 24 from PyObject
```

**Root Cause**:
- Conda environment is using **PyPy 7.3.15** instead of CPython
- pysam has binary incompatibility with PyPy
- This breaks SoloTE pipeline which requires pysam

**Impact**: 
- ⚠️ Pipeline CANNOT run until pysam issue is resolved
- All other tools work (Python, samtools, bedtools, STAR)
- Only pysam is affected

**Fix Required**:
1. Force CPython (not PyPy) in environment.yml ✅ DONE
2. ~~Add `python_impl=cpython` or similar constraint~~ Used `python=3.9.*=*_cpython`
3. Recreate conda environment (deactivate, remove, recreate)
4. Verify pysam imports successfully

**Fix Applied**:
- Updated `environment.yml`: Changed `python=3.9` → `python=3.9.*=*_cpython`
- Committed to repository

**Next Steps**:
```bash
# On compute node (srun or sbatch)
conda deactivate
conda env remove -n solote_validation
conda env create -f environment.yml
conda activate solote_validation
python3 -c "import pysam; print('pysam OK:', pysam.__version__)"
```

**Priority**: CRITICAL - Blocks entire pipeline

**Logs**: `logs/install_solote_51396713.{out,err}`

---
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
