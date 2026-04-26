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

(Additional issues will be documented here as testing continues)

---
