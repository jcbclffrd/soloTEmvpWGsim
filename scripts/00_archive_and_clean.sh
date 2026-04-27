#!/bin/bash
##############################################################################
# Pipeline Step 0: Archive Current Run and Clean Data Folders
#
# This script archives existing pipeline output data into timestamped archive
# folders (one per data directory), then removes the current data files so
# the next pipeline run starts from a clean state.
#
# This prevents soloTE and other tools from skipping steps because output
# files already exist from a previous run.
#
# Archive structure:
#   <data_folder>/archive/run_YYYYMMDD_HHMMSS/
#
# Usage:
#   bash scripts/00_archive_and_clean.sh
#
# Options:
#   --no-archive    Just delete data, don't archive (faster but irreversible)
#   --keep-N N      Only keep last N archives per folder (default: keep all)
##############################################################################

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

# Parse arguments
ARCHIVE=true
KEEP_N=0  # 0 means keep all
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-archive)
            ARCHIVE=false
            shift
            ;;
        --keep-N)
            KEEP_N=$2
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: bash scripts/00_archive_and_clean.sh [--no-archive] [--keep-N N]"
            exit 1
            ;;
    esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "================================================================================"
echo "Pipeline Step 0: Archive Current Run and Clean Data Folders"
echo "================================================================================"
echo ""
echo "Started: $(date)"
echo "Archive mode: $ARCHIVE"
[[ "$KEEP_N" -gt 0 ]] && echo "Retention: keep last $KEEP_N archives"
echo ""

# ==============================================================================
# Define data folders to clean
# ==============================================================================
# Format: "folder_path|files_to_archive_glob"
# Use "*" to archive all files (excluding archive/ folder and README.md)
DATA_FOLDERS=(
    "synthetic_data/transcriptome"
    "synthetic_data/fastqs"
    "synthetic_data/outputs"
    "validation_report"
)

# Files to ALWAYS preserve (never archive or delete)
PRESERVE_FILES=("README.md")

# ==============================================================================
# Helper: Check if folder has any data to archive
# ==============================================================================
folder_has_data() {
    local folder="$1"
    if [[ ! -d "$folder" ]]; then
        return 1
    fi
    
    # Count items excluding archive/ and preserved files
    local count=0
    for item in "$folder"/* "$folder"/.[!.]*; do
        [[ ! -e "$item" ]] && continue
        local basename=$(basename "$item")
        [[ "$basename" == "archive" ]] && continue
        
        local skip=false
        for preserve in "${PRESERVE_FILES[@]}"; do
            [[ "$basename" == "$preserve" ]] && skip=true && break
        done
        [[ "$skip" == "true" ]] && continue
        
        count=$((count + 1))
    done
    
    [[ $count -gt 0 ]]
}

# ==============================================================================
# Archive and clean each folder
# ==============================================================================
TOTAL_ARCHIVED=0
TOTAL_CLEANED=0

for folder in "${DATA_FOLDERS[@]}"; do
    echo "--------------------------------------------------------------------------------"
    echo "Processing: $folder"
    echo "--------------------------------------------------------------------------------"
    
    if [[ ! -d "$folder" ]]; then
        echo "  Folder does not exist, creating it..."
        mkdir -p "$folder"
        echo "  ✓ Created (nothing to archive)"
        echo ""
        continue
    fi
    
    if ! folder_has_data "$folder"; then
        echo "  No data to archive (folder is empty or only contains preserved files)"
        echo ""
        continue
    fi
    
    # Show what will be processed
    echo "  Current contents:"
    ls -lh "$folder" 2>/dev/null | grep -v "^total" | grep -v " archive$" | head -20 | sed 's/^/    /'
    echo ""
    
    if [[ "$ARCHIVE" == "true" ]]; then
        # Create archive subfolder
        ARCHIVE_DIR="$folder/archive/run_$TIMESTAMP"
        mkdir -p "$ARCHIVE_DIR"
        
        echo "  Archiving to: $ARCHIVE_DIR"
        
        # Move all items except archive/ and preserved files
        for item in "$folder"/* "$folder"/.[!.]*; do
            [[ ! -e "$item" ]] && continue
            local_basename=$(basename "$item")
            
            # Skip the archive folder itself
            [[ "$local_basename" == "archive" ]] && continue
            
            # Skip preserved files
            skip=false
            for preserve in "${PRESERVE_FILES[@]}"; do
                if [[ "$local_basename" == "$preserve" ]]; then
                    skip=true
                    break
                fi
            done
            [[ "$skip" == "true" ]] && continue
            
            # Move to archive
            mv "$item" "$ARCHIVE_DIR/"
        done
        
        # Report archive size
        archive_size=$(du -sh "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
        archive_files=$(find "$ARCHIVE_DIR" -type f | wc -l)
        echo "  ✓ Archived $archive_files files ($archive_size)"
        TOTAL_ARCHIVED=$((TOTAL_ARCHIVED + archive_files))
        
        # Apply retention policy
        if [[ "$KEEP_N" -gt 0 ]]; then
            existing_archives=($(ls -1d "$folder/archive"/run_* 2>/dev/null | sort))
            n_archives=${#existing_archives[@]}
            if [[ $n_archives -gt $KEEP_N ]]; then
                n_to_remove=$((n_archives - KEEP_N))
                echo "  Retention: removing $n_to_remove old archive(s)..."
                for ((i=0; i<n_to_remove; i++)); do
                    echo "    Removing: ${existing_archives[$i]}"
                    rm -rf "${existing_archives[$i]}"
                done
            fi
        fi
    else
        # No archive: just delete
        echo "  Deleting (--no-archive mode)..."
        n_files=0
        for item in "$folder"/* "$folder"/.[!.]*; do
            [[ ! -e "$item" ]] && continue
            local_basename=$(basename "$item")
            [[ "$local_basename" == "archive" ]] && continue
            
            skip=false
            for preserve in "${PRESERVE_FILES[@]}"; do
                if [[ "$local_basename" == "$preserve" ]]; then
                    skip=true
                    break
                fi
            done
            [[ "$skip" == "true" ]] && continue
            
            rm -rf "$item"
            n_files=$((n_files + 1))
        done
        echo "  ✓ Deleted $n_files items"
        TOTAL_CLEANED=$((TOTAL_CLEANED + n_files))
    fi
    
    echo ""
done

# ==============================================================================
# Summary
# ==============================================================================
echo "================================================================================"
echo "Step 0 Complete!"
echo "================================================================================"
echo ""
echo "Finished: $(date)"
echo ""

if [[ "$ARCHIVE" == "true" ]]; then
    echo "Archived $TOTAL_ARCHIVED files across ${#DATA_FOLDERS[@]} folders."
    echo "Archive timestamp: run_$TIMESTAMP"
    echo ""
    echo "Archives stored in:"
    for folder in "${DATA_FOLDERS[@]}"; do
        if [[ -d "$folder/archive/run_$TIMESTAMP" ]]; then
            size=$(du -sh "$folder/archive/run_$TIMESTAMP" 2>/dev/null | cut -f1)
            echo "  $folder/archive/run_$TIMESTAMP ($size)"
        fi
    done
    echo ""
    echo "To restore an archived run:"
    echo "  cp -r <folder>/archive/run_<timestamp>/* <folder>/"
    echo ""
    echo "To list all archives:"
    echo "  ls -la synthetic_data/*/archive/ validation_report/archive/ 2>/dev/null"
else
    echo "Deleted $TOTAL_CLEANED items (--no-archive mode)"
fi

echo ""
echo "Data folders are now clean. Ready to run pipeline."
echo ""
echo "Next step: Run the pipeline"
echo "  bash scripts/run_pipeline.sh"
echo ""
