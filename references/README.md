# References

This directory contains the T2T-CHM13v2.0 reference genome, annotations, and STAR index.

## Setup

Run the setup scripts to populate this directory:

```bash
# Download genome and annotations (~10-15 minutes)
bash setup/00_setup_references.sh

# Build STAR index (~20-30 minutes, requires 32GB RAM)
bash setup/01_build_star_index.sh
```

## Contents (after setup)

```
references/
├── genome/
│   ├── T2T-CHM13v2.0.fa           # T2T genome (~3 GB)
│   └── T2T-CHM13v2.0.fa.fai       # Genome index
├── annotations/
│   ├── T2T-CHM13v2.0_RepeatMasker.bed                   # Full RepeatMasker
│   ├── T2T-CHM13v2.0_RepeatMasker_SoloTE_filtered.bed   # TE-only (for soloTE)
│   └── T2T-CHM13v2.0_RefSeq_Curated_20231005.gff3       # Gene annotations (optional)
└── STARsolo_index/                # STAR index (~30 GB)
    ├── Genome
    ├── SA
    ├── SAindex
    └── ... (other index files)
```

## Disk Usage

- Genome: ~3 GB
- Annotations: ~500 MB
- STAR index: ~30 GB
- **Total**: ~35 GB

## Notes

- These files are excluded from git (see `.gitignore`)
- Each user must run setup scripts after cloning
- Setup is required only once per system
