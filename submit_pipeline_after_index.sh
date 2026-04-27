#!/bin/bash
##############################################################################
# Submit pipeline with dependency on STAR index build completion
#
# Usage: bash submit_pipeline_after_index.sh <index_job_id>
# Example: bash submit_pipeline_after_index.sh 51404876
##############################################################################

if [ $# -eq 0 ]; then
    echo "Usage: $0 <index_build_job_id>"
    echo ""
    echo "Submit pipeline to run after STAR index build completes"
    echo ""
    echo "Example:"
    echo "  $0 51404876"
    exit 1
fi

INDEX_JOB_ID=$1

echo "============================================"
echo "Submit Pipeline with Dependency"
echo "============================================"
echo ""
echo "Pipeline will start after job $INDEX_JOB_ID completes successfully"
echo ""

# Submit with dependency
PIPELINE_JOB_ID=$(sbatch --dependency=afterok:$INDEX_JOB_ID sbatch_run_pipeline.sh | awk '{print $4}')

echo "✓ Pipeline job submitted: $PIPELINE_JOB_ID"
echo ""
echo "Job dependency: afterok:$INDEX_JOB_ID"
echo ""
echo "Check status:"
echo "  squeue -u \$USER"
echo ""
echo "The pipeline will automatically start when the index build succeeds."
echo "If the index build fails, the pipeline job will be cancelled."
echo ""
