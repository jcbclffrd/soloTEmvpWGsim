#!/usr/bin/env Rscript
################################################################################
# Pipeline Script 01g: Select Housekeeping Genes
#
# Reads the T2T GFF3, finds the longest transcript for each target gene,
# and writes coordinates to:
#   ground_truth/selected_gene_loci.bed
#   ground_truth/selected_gene_loci.tsv
################################################################################

suppressPackageStartupMessages({
  library(yaml)
  library(tidyverse)
})

message("================================================================================")
message("Pipeline Step 01g: Select Housekeeping Genes")
message("================================================================================")
message("")

config      <- yaml::read_yaml("config.yaml")
gene_cfg    <- config$extensions$gene_selection
gff_path    <- config$references$gene_gtf
target_genes <- gene_cfg$genes
n_genes      <- gene_cfg$n_genes
random_seed  <- config$simulation$random_seed
set.seed(random_seed)

message("Configuration:")
message(sprintf("  GFF3: %s", gff_path))
message(sprintf("  Target genes: %s", paste(target_genes, collapse = ", ")))
message(sprintf("  n_genes: %d", n_genes))
message("")

if (!file.exists(gff_path)) {
  stop(sprintf("ERROR: GFF3 not found: %s\nPlease run setup/00_setup_references.sh", gff_path))
}

# ==============================================================================
# Parse GFF3 — extract mRNA features for target genes
# ==============================================================================
message("Parsing GFF3 (this may take a moment for large files)...")

# Read GFF3, skip comment lines
gff <- read_tsv(
  gff_path,
  col_names = c("seqname","source","feature","start","end","score","strand","frame","attributes"),
  comment   = "#",
  col_types = "ccciicccc",
  progress  = FALSE
)

message(sprintf("  Total GFF3 records: %s", format(nrow(gff), big.mark = ",")))

# Keep only mRNA features (one record per transcript)
mrna <- gff %>% filter(feature == "mRNA")
message(sprintf("  mRNA records: %s", format(nrow(mrna), big.mark = ",")))

# Extract gene name from attributes
# GFF3 attributes look like: ID=rna-NM_001234.5;Parent=gene-GAPDH;Name=GAPDH;...
extract_attr <- function(attrs, key) {
  pattern <- sprintf("(?:^|;)%s=([^;]+)", key)
  m <- regmatches(attrs, regexpr(pattern, attrs, perl = TRUE))
  ifelse(length(m) == 0, NA_character_,
         sub(sprintf("%s=", key), "", sub("^;", "", m)))
}

mrna <- mrna %>%
  mutate(
    gene_name  = map_chr(attributes, ~extract_attr(.x, "gene")),
    tx_id      = map_chr(attributes, ~extract_attr(.x, "ID")),
    tx_length  = end - start + 1L,
    chrom      = seqname
  )

# Filter for target genes on standard chromosomes
std_chroms <- paste0("chr", c(1:22, "X"))
selected <- mrna %>%
  filter(
    gene_name %in% target_genes,
    chrom %in% std_chroms
  ) %>%
  # Pick the longest transcript per gene
  group_by(gene_name) %>%
  slice_max(tx_length, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(gene_name)

found <- unique(selected$gene_name)
missing <- setdiff(target_genes, found)

message(sprintf("  Genes found: %s", paste(found, collapse = ", ")))
if (length(missing) > 0)
  message(sprintf("  WARNING — genes not found in GFF3: %s", paste(missing, collapse = ", ")))

# Limit to n_genes if more were found
if (nrow(selected) > n_genes) {
  selected <- selected %>% slice_head(n = n_genes)
  message(sprintf("  Trimmed to %d genes (n_genes setting)", n_genes))
}

message(sprintf("  Final selection: %d genes", nrow(selected)))
message("")

# ==============================================================================
# Build output tables
# ==============================================================================
selected <- selected %>%
  mutate(
    locus_id   = sprintf("GENE_%03d", row_number()),
    locus_name = sprintf("%s::%s:%d-%d(%s)", locus_id, chrom, start - 1L, end, strand),
    # BED is 0-based half-open
    bed_start  = start - 1L,
    bed_end    = end
  )

bed_out <- selected %>%
  select(chrom, bed_start, bed_end, locus_id, tx_length, strand)

tsv_out <- selected %>%
  select(locus_id, locus_name, gene_name, chrom,
         start = bed_start, end = bed_end, strand, tx_length)

# ==============================================================================
# Write outputs
# ==============================================================================
dir.create("ground_truth", showWarnings = FALSE)

bed_file <- "ground_truth/selected_gene_loci.bed"
tsv_file <- "ground_truth/selected_gene_loci.tsv"

write_tsv(bed_out, bed_file, col_names = FALSE)
write_tsv(tsv_out, tsv_file)

message(sprintf("✓ BED written: %s (%d genes)", bed_file, nrow(bed_out)))
message(sprintf("✓ TSV written: %s", tsv_file))
message("")

# Print summary table
message("Selected genes:")
tsv_out %>%
  mutate(coords = sprintf("%s:%d-%d(%s)", chrom, start, end, strand)) %>%
  select(locus_id, gene_name, coords, tx_length) %>%
  as.data.frame() %>%
  print(row.names = FALSE)

message("")
message("================================================================================")
message("Step 01g Complete!")
message("================================================================================")
message("")
message("Next step: Extract gene transcript sequences")
message("  bash scripts/02g_extract_gene_sequences.sh")
message("")
