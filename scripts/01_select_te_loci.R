#!/usr/bin/env Rscript
################################################################################
# Pipeline Script 1: Select TE Loci for Ground Truth
#
# This script selects well-separated TE loci from RepeatMasker annotations
# to create a ground truth dataset for validation.
#
# Selection criteria:
#   - Target TE families (Alu, L1, L2, MIR, ERVL-MaLR, hAT-Charlie)
#   - Well-separated (min distance between loci)
#   - Appropriate size range
#   - From main chromosomes (no unplaced/alt contigs)
#
# Output: ground_truth/selected_te_loci.tsv
#
# EXTENSION POINT: Modify selection logic here to test gene contamination
#                  or multi-mapper scenarios in future.
################################################################################

suppressPackageStartupMessages({
  library(yaml)
  library(tidyverse)
  library(GenomicRanges)
  library(rtracklayer)
})

message("================================================================================")
message("Pipeline Step 1: Select TE Loci for Ground Truth")
message("================================================================================")
message("")

# ==============================================================================
# Load Configuration
# ==============================================================================
config <- yaml::read_yaml("config.yaml")

# Extract parameters
repeatmasker_bed <- config$references$repeatmasker_bed
n_te_loci <- config$simulation$n_te_loci
target_families <- config$te_selection$families
min_distance <- config$te_selection$min_distance_between_loci
min_length <- config$te_selection$min_te_length
max_length <- config$te_selection$max_te_length
target_chroms <- config$te_selection$chromosomes
random_seed <- config$simulation$random_seed

message("Configuration:")
message(sprintf("  RepeatMasker BED: %s", repeatmasker_bed))
message(sprintf("  Target TE loci: %d", n_te_loci))
message(sprintf("  Target families: %s", paste(target_families, collapse=", ")))
message(sprintf("  Min distance between loci: %d bp", min_distance))
message(sprintf("  TE length range: %d-%d bp", min_length, max_length))
message(sprintf("  Random seed: %d", random_seed))
message("")

# Set random seed for reproducibility
set.seed(random_seed)

# ==============================================================================
# Load RepeatMasker Annotations
# ==============================================================================
message("Loading RepeatMasker annotations...")

# Check if file exists
if (!file.exists(repeatmasker_bed)) {
  stop(sprintf("ERROR: RepeatMasker file not found: %s\nPlease run setup/00_setup_references.sh first", repeatmasker_bed))
}

# Read BED file (6 columns)
# Format: chr start end name score strand
# Name field: chr|start|end|family:subfamily:class|score|strand
rmsk <- read_tsv(repeatmasker_bed, 
                 col_names = c("chr", "start", "end", "name", "score", "strand"),
                 col_types = "ciicdc",
                 show_col_types = FALSE)

message(sprintf("  Loaded %s TE features", format(nrow(rmsk), big.mark=",")))
message("")

# ==============================================================================
# Parse TE Annotations
# ==============================================================================
message("Parsing TE family information...")

# Extract family/class from name field
# Format: chr|start|end|name:family:class|score|strand
rmsk <- rmsk %>%
  mutate(
    # Split the name field
    name_parts = str_split(name, "\\|"),
    te_info = map_chr(name_parts, ~.x[4]),  # Get name:family:class
    
    # Parse TE info
    te_name = str_split(te_info, ":") %>% map_chr(~.x[1]),
    te_family = str_split(te_info, ":") %>% map_chr(~.x[2]),
    te_class = str_split(te_info, ":") %>% map_chr(~.x[3]),
    
    # Calculate length
    length = end - start
  ) %>%
  select(-name_parts, -te_info)

message(sprintf("  Parsed %d TE families", n_distinct(rmsk$te_family)))
message(sprintf("  Parsed %d TE classes", n_distinct(rmsk$te_class)))
message("")

# ==============================================================================
# Filter to Selection Criteria
# ==============================================================================
message("Applying selection criteria...")
message("")

# Filter to target chromosomes
rmsk_filtered <- rmsk %>%
  filter(chr %in% target_chroms)
message(sprintf("  After chromosome filter: %s features", format(nrow(rmsk_filtered), big.mark=",")))

# Filter to target families
rmsk_filtered <- rmsk_filtered %>%
  filter(te_family %in% target_families)
message(sprintf("  After family filter: %s features", format(nrow(rmsk_filtered), big.mark=",")))

# Filter to length range
rmsk_filtered <- rmsk_filtered %>%
  filter(length >= min_length, length <= max_length)
message(sprintf("  After length filter: %s features", format(nrow(rmsk_filtered), big.mark=",")))

if (nrow(rmsk_filtered) == 0) {
  stop("ERROR: No TEs remaining after filtering. Adjust criteria in config.yaml")
}

message("")

# ==============================================================================
# Select Well-Separated TEs
# ==============================================================================
message("Selecting well-separated TE loci...")
message("")

# Convert to GRanges
rmsk_gr <- makeGRangesFromDataFrame(rmsk_filtered, 
                                     keep.extra.columns = TRUE,
                                     starts.in.df.are.0based = FALSE)

# Initialize selected loci
selected_loci <- list()
remaining_gr <- rmsk_gr

# Iteratively select loci ensuring minimum distance
for (i in 1:n_te_loci) {
  if (length(remaining_gr) == 0) {
    warning(sprintf("Only %d TEs could be selected (target was %d)", i-1, n_te_loci))
    break
  }
  
  # Sample one TE randomly from remaining
  idx <- sample(length(remaining_gr), 1)
  selected <- remaining_gr[idx]
  selected_loci[[i]] <- selected
  
  # Remove TEs within min_distance of selected TE
  # Create exclusion zone
  exclude_zone <- resize(selected, width = width(selected) + 2*min_distance, fix = "center")
  
  # Find overlaps and remove
  overlaps <- findOverlaps(exclude_zone, remaining_gr)
  if (length(overlaps) > 0) {
    remaining_gr <- remaining_gr[-subjectHits(overlaps)]
  }
  
  message(sprintf("  Selected locus %d: %s (%s, %d bp)", 
                  i, 
                  as.character(seqnames(selected)),
                  as.data.frame(selected)$te_family,
                  width(selected)))
}

message("")

# Combine selected loci
selected_gr <- do.call(c, selected_loci)

# ==============================================================================
# Create Ground Truth Table
# ==============================================================================
message("Creating ground truth table...")

ground_truth <- as.data.frame(selected_gr) %>%
  as_tibble() %>%
  select(chr = seqnames, start, end, strand, 
         te_name, te_family, te_class, length, score) %>%
  mutate(
    locus_id = sprintf("TE_%03d", row_number()),
    locus_name = sprintf("%s:%d-%d(%s)", chr, start, end, strand)
  ) %>%
  select(locus_id, locus_name, chr, start, end, strand, 
         te_name, te_family, te_class, length, score)

message("")
message("Selected TE loci summary:")
message(sprintf("  Total loci: %d", nrow(ground_truth)))
message("")
message("  By family:")
family_counts <- ground_truth %>% count(te_family, sort = TRUE)
walk2(family_counts$te_family, family_counts$n, 
      ~message(sprintf("    %s: %d", .x, .y)))
message("")
message("  By class:")
class_counts <- ground_truth %>% count(te_class, sort = TRUE)
walk2(class_counts$te_class, class_counts$n, 
      ~message(sprintf("    %s: %d", .x, .y)))
message("")
message("  Length statistics:")
message(sprintf("    Min: %d bp", min(ground_truth$length)))
message(sprintf("    Max: %d bp", max(ground_truth$length)))
message(sprintf("    Mean: %.0f bp", mean(ground_truth$length)))
message(sprintf("    Median: %d bp", median(ground_truth$length)))
message("")

# ==============================================================================
# Save Ground Truth
# ==============================================================================
output_dir <- "ground_truth"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

output_file <- file.path(output_dir, "selected_te_loci.tsv")
write_tsv(ground_truth, output_file)

message(sprintf("✓ Ground truth saved: %s", output_file))
message("")

# Also save BED format for bedtools
bed_file <- file.path(output_dir, "selected_te_loci.bed")
ground_truth %>%
  mutate(name = locus_id, score = 0) %>%
  select(chr, start, end, name, score, strand) %>%
  write_tsv(bed_file, col_names = FALSE)

message(sprintf("✓ BED format saved: %s", bed_file))
message("")

message("================================================================================")
message("Step 1 Complete!")
message("================================================================================")
message("")
message("Next step: Extract TE sequences from genome")
message("  bash scripts/02_extract_sequences.sh")
message("")

# EXTENSION POINT: Gene Contamination Testing
# --------------------------------------------
# To test intronic TEs overlapping genes, add this section:
#
# if (config$extensions$include_genes) {
#   gene_gtf <- config$references$gene_gtf
#   genes_gr <- import(gene_gtf)
#   
#   # Filter to introns
#   introns_gr <- genes_gr[genes_gr$type == "intron"]
#   
#   # Find TEs overlapping introns
#   intronic_tes <- subsetByOverlaps(rmsk_gr, introns_gr)
#   
#   # Select from intronic TEs instead
#   # ... rest of selection logic
# }

# EXTENSION POINT: Multi-mapper Testing
# -------------------------------------
# To test highly similar TEs, modify the family filter:
#
# if (config$extensions$include_multimappers) {
#   # Select young Alu subfamilies with high sequence similarity
#   young_alu_subfamilies <- c("AluYa5", "AluYb8", "AluYb9", "AluYc")
#   
#   rmsk_filtered <- rmsk_filtered %>%
#     filter(te_name %in% young_alu_subfamilies)
#   
#   # Reduce min_distance to allow nearby similar TEs
#   # ... rest of selection logic
# }
