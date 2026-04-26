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
