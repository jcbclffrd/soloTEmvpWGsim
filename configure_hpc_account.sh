#!/bin/bash
##############################################################################
# Configure HPC Account for This Repository
#
# This script updates all sbatch scripts with your HPC account/lab name
# Run this once after cloning the repository
##############################################################################

echo "============================================"
echo "Configure HPC Account for soloTEmvpWGsim"
echo "============================================"
echo ""

# Get current account from scripts
CURRENT_ACCOUNT=$(grep "#SBATCH -A" sbatch_run_pipeline.sh | awk '{print $3}')
echo "Current account in scripts: $CURRENT_ACCOUNT"
echo ""

# Prompt for new account
read -p "Enter your HPC account/lab name (e.g., yourlab_lab): " NEW_ACCOUNT

if [ -z "$NEW_ACCOUNT" ]; then
    echo "ERROR: No account name provided"
    exit 1
fi

echo ""
echo "Updating account from '$CURRENT_ACCOUNT' to '$NEW_ACCOUNT'..."
echo ""

# Find all sbatch scripts
SBATCH_FILES=$(find . -name "sbatch*.sh" | grep -v ".git")

# Update each file
for file in $SBATCH_FILES; do
    if grep -q "#SBATCH -A" "$file"; then
        sed -i "s/#SBATCH -A $CURRENT_ACCOUNT/#SBATCH -A $NEW_ACCOUNT/g" "$file"
        echo "✓ Updated: $file"
    fi
done

echo ""
echo "Verification:"
echo ""
grep "#SBATCH -A" $SBATCH_FILES

echo ""
echo "============================================"
echo "Configuration Complete!"
echo "============================================"
echo ""
echo "All sbatch scripts now use account: $NEW_ACCOUNT"
echo ""
echo "Next steps:"
echo "  1. Review sbatch scripts to ensure settings match your HPC"
echo "  2. Run setup: cd setup && sbatch sbatch_00_setup_references.sh"
echo "  3. See HPC_SETUP.md for complete instructions"
echo ""
