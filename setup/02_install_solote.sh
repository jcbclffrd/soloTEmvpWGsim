#!/bin/bash
##############################################################################
# Setup Script 2: Install SoloTE
#
# This script clones and sets up SoloTE from GitHub.
#
# Requirements:
#   - Python 3.x
#   - Git
#   - Conda environment with dependencies (samtools, pysam, bedtools)
#
# Runtime: ~1-2 minutes
##############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "============================================"
echo "Setup Step 2: Install SoloTE"
echo "============================================"
echo ""
echo "Repository root: $REPO_ROOT"
echo "Date: $(date)"
echo ""

# Check dependencies
echo "Checking dependencies..."
echo ""

MISSING_DEPS=()

if ! command -v python3 &> /dev/null; then
    MISSING_DEPS+=("python3")
fi

if ! command -v git &> /dev/null; then
    MISSING_DEPS+=("git")
fi

if ! command -v samtools &> /dev/null; then
    MISSING_DEPS+=("samtools")
fi

if ! command -v bedtools &> /dev/null; then
    MISSING_DEPS+=("bedtools")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "ERROR: Missing required dependencies:"
    printf '  - %s\n' "${MISSING_DEPS[@]}"
    echo ""
    echo "Please activate the conda environment first:"
    echo "  conda activate solote_validation"
    echo ""
    echo "If not yet created, run:"
    echo "  conda env create -f environment.yml"
    exit 1
fi

echo "✓ Python version: $(python3 --version)"
echo "✓ Git version: $(git --version)"
echo "✓ Samtools version: $(samtools --version | head -1)"
echo "✓ Bedtools version: $(bedtools --version)"
echo ""

# ==============================================================================
# Clone SoloTE Repository
# ==============================================================================
SOFTWARE_DIR="$REPO_ROOT/software"
SOLOTE_DIR="$SOFTWARE_DIR/SoloTE"

mkdir -p "$SOFTWARE_DIR"

if [[ -d "$SOLOTE_DIR" ]] && [[ -f "$SOLOTE_DIR/SoloTE_pipeline.py" ]]; then
    echo "============================================"
    echo "SoloTE Already Installed"
    echo "============================================"
    echo ""
    echo "Found existing SoloTE installation: $SOLOTE_DIR"
    echo ""
    
    # Check for updates
    cd "$SOLOTE_DIR"
    echo "Checking for updates..."
    git fetch origin
    
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    
    if [[ "$LOCAL" == "$REMOTE" ]]; then
        echo "✓ SoloTE is up to date"
    else
        echo ""
        echo "Updates available for SoloTE"
        read -p "Update to latest version? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git pull origin main
            echo "✓ SoloTE updated"
        fi
    fi
    
    cd "$REPO_ROOT"
else
    echo "============================================"
    echo "Cloning SoloTE from GitHub"
    echo "============================================"
    echo ""
    echo "Repository: https://github.com/bvaldebenitom/SoloTE"
    echo "Target directory: $SOLOTE_DIR"
    echo ""
    
    git clone https://github.com/bvaldebenitom/SoloTE.git "$SOLOTE_DIR"
    
    echo ""
    echo "✓ SoloTE cloned successfully"
fi

echo ""

# ==============================================================================
# Verify Installation
# ==============================================================================
echo "============================================"
echo "Verifying SoloTE Installation"
echo "============================================"
echo ""

if [[ ! -f "$SOLOTE_DIR/SoloTE_pipeline.py" ]]; then
    echo "ERROR: SoloTE_pipeline.py not found"
    echo "Installation may have failed"
    exit 1
fi

echo "✓ Found SoloTE_pipeline.py"
echo ""

# Test Python dependencies
echo "Testing Python dependencies..."
python3 -c "
import sys
import importlib

required = ['pysam', 'numpy', 'pandas']
missing = []

for module in required:
    try:
        importlib.import_module(module)
    except ImportError:
        missing.append(module)

if missing:
    print('ERROR: Missing Python packages:')
    for m in missing:
        print(f'  - {m}')
    print()
    print('Install missing packages with:')
    print('  conda install -c conda-forge ' + ' '.join(missing))
    sys.exit(1)
else:
    print('✓ All Python dependencies available')
"

echo ""

# Show SoloTE version/commit
cd "$SOLOTE_DIR"
SOLOTE_COMMIT=$(git rev-parse --short HEAD)
SOLOTE_DATE=$(git log -1 --format=%cd --date=short)
echo "SoloTE installation details:"
echo "  Commit: $SOLOTE_COMMIT"
echo "  Date: $SOLOTE_DATE"
echo "  Location: $SOLOTE_DIR"
echo ""

cd "$REPO_ROOT"

# ==============================================================================
# Summary
# ==============================================================================
echo "============================================"
echo "Setup Complete!"
echo "============================================"
echo ""
echo "All setup steps finished successfully:"
echo "  ✓ T2T genome and annotations downloaded"
echo "  ✓ STAR index built"
echo "  ✓ SoloTE installed"
echo ""
echo "You can now run the validation pipeline:"
echo "  bash scripts/run_pipeline.sh"
echo ""
echo "Or run individual steps:"
echo "  bash scripts/01_select_te_loci.sh"
echo "  bash scripts/02_extract_sequences.sh"
echo "  ... etc"
echo ""
echo "See TUTORIAL.md for detailed instructions"
echo ""
