#!/usr/bin/env Rscript
################################################################################
# Pipeline Script 3: Create Expression Profile
#
# This script defines the expected expression level (UMI counts) for each
# TE locus in each synthetic cell.
#
# Initial implementation: Uniform expression (same UMI count per locus per cell)
#
# Output: synthetic_data/transcriptome/expression_profile.tsv
#
# EXTENSION POINT: Modify this script to test expression heterogeneity,
#                  dropout, or cell-type-specific patterns.
################################################################################

suppressPackageStartupMessages({
  library(yaml)
  library(tidyverse)
})

message("================================================================================")
message("Pipeline Step 3: Create Expression Profile")
message("================================================================================")
message("")

# ==============================================================================
# Load Configuration
# ==============================================================================
config <- yaml::read_yaml("config.yaml")

n_cells <- config$simulation$n_cells
umi_per_locus <- config$simulation$umi_per_locus
random_seed <- config$simulation$random_seed
expression_model <- config$extensions$expression_model

message("Configuration:")
message(sprintf("  Number of cells: %d", n_cells))
message(sprintf("  UMIs per locus per cell: %d", umi_per_locus))
message(sprintf("  Expression model: %s", expression_model))
message(sprintf("  Random seed: %d", random_seed))
message("")

set.seed(random_seed)

# ==============================================================================
# Load Ground Truth TE Loci
# ==============================================================================
message("Loading ground truth TE loci...")

ground_truth_file <- "ground_truth/selected_te_loci.tsv"
if (!file.exists(ground_truth_file)) {
  stop(sprintf("ERROR: Ground truth file not found: %s\nPlease run: Rscript scripts/01_select_te_loci.R", ground_truth_file))
}

ground_truth <- read_tsv(ground_truth_file, show_col_types = FALSE)
n_loci <- nrow(ground_truth)

message(sprintf("  Loaded %d TE loci", n_loci))
message("")

# ==============================================================================
# Generate Cell Barcodes
# ==============================================================================
message("Generating synthetic cell barcodes...")

# Generate valid 10x-style barcodes (16bp, A/C/G/T)
generate_barcode <- function() {
  paste(sample(c("A", "C", "G", "T"), 16, replace = TRUE), collapse = "")
}

cell_barcodes <- replicate(n_cells, generate_barcode())

# Ensure uniqueness
while (any(duplicated(cell_barcodes))) {
  duplicated_idx <- which(duplicated(cell_barcodes))
  cell_barcodes[duplicated_idx] <- replicate(length(duplicated_idx), generate_barcode())
}

cell_ids <- sprintf("CELL_%03d", 1:n_cells)

message(sprintf("  Generated %d unique cell barcodes", n_cells))
message(sprintf("  Example: %s", cell_barcodes[1]))
message("")

# ==============================================================================
# Create Expression Matrix
# ==============================================================================
message("Creating expression profile...")

if (expression_model == "uniform") {
  # Uniform expression: same UMI count for all loci in all cells
  message("  Using uniform expression model")
  message(sprintf("  All loci will have %d UMIs per cell", umi_per_locus))
  
  # Create expression matrix (loci x cells)
  expr_matrix <- matrix(umi_per_locus, 
                        nrow = n_loci, 
                        ncol = n_cells,
                        dimnames = list(ground_truth$locus_id, cell_ids))
  
} else if (expression_model == "variable") {
  # Variable expression: use distribution from config
  # EXTENSION POINT: Add dropout, cell-type patterns, etc.
  message("  Using variable expression model")
  
  # This is a placeholder for future implementation
  warning("Variable expression model not yet implemented. Using uniform instead.")
  
  expr_matrix <- matrix(umi_per_locus, 
                        nrow = n_loci, 
                        ncol = n_cells,
                        dimnames = list(ground_truth$locus_id, cell_ids))
  
} else {
  stop(sprintf("Unknown expression model: %s", expression_model))
}

message("")

# ==============================================================================
# Create Expression Profile Table
# ==============================================================================
message("Formatting expression profile...")

# Convert matrix to long format
expr_profile <- as_tibble(expr_matrix, rownames = "locus_id") %>%
  pivot_longer(-locus_id, names_to = "cell_id", values_to = "target_umis") %>%
  left_join(
    tibble(cell_id = cell_ids, cell_barcode = cell_barcodes),
    by = "cell_id"
  ) %>%
  left_join(
    ground_truth %>% select(locus_id, locus_name, te_family, te_class),
    by = "locus_id"
  ) %>%
  select(cell_id, cell_barcode, locus_id, locus_name, 
         te_family, te_class, target_umis)

message(sprintf("  Expression profile: %s entries", format(nrow(expr_profile), big.mark=",")))
message("")

# ==============================================================================
# Summary Statistics
# ==============================================================================
message("Expression profile summary:")
message("")
message("  Per cell:")
total_umis_per_cell <- expr_profile %>%
  group_by(cell_id) %>%
  summarize(total_umis = sum(target_umis), .groups = "drop")

message(sprintf("    Total UMIs per cell: %d (all cells identical in uniform model)", 
                unique(total_umis_per_cell$total_umis)))
message("")

message("  Per TE locus:")
total_umis_per_locus <- expr_profile %>%
  group_by(locus_id, te_family) %>%
  summarize(total_umis = sum(target_umis), .groups = "drop") %>%
  arrange(desc(total_umis))

message(sprintf("    UMIs per locus (across all cells):"))
walk2(total_umis_per_locus$locus_id, 
      total_umis_per_locus$total_umis,
      ~message(sprintf("      %s: %d", .x, .y)))
message("")

# ==============================================================================
# Save Expression Profile
# ==============================================================================
output_dir <- "synthetic_data/transcriptome"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Save full expression profile
expr_profile_file <- file.path(output_dir, "expression_profile.tsv")
write_tsv(expr_profile, expr_profile_file)
message(sprintf("✓ Expression profile saved: %s", expr_profile_file))
message("")

# Save cell barcode list (for downstream use)
cell_barcode_file <- file.path(output_dir, "cell_barcodes.txt")
write_lines(cell_barcodes, cell_barcode_file)
message(sprintf("✓ Cell barcodes saved: %s", cell_barcode_file))
message("")

# Save summary for validation
summary_file <- file.path(output_dir, "expression_summary.txt")
sink(summary_file)
cat("Synthetic Expression Profile Summary\n")
cat("====================================\n\n")
cat(sprintf("Number of cells: %d\n", n_cells))
cat(sprintf("Number of TE loci: %d\n", n_loci))
cat(sprintf("Expression model: %s\n", expression_model))
cat(sprintf("UMIs per locus per cell: %d\n", umi_per_locus))
cat(sprintf("Total UMIs per cell: %d\n", unique(total_umis_per_cell$total_umis)))
cat(sprintf("Total UMIs across all cells: %d\n", sum(expr_profile$target_umis)))
cat("\n")
cat("TE families represented:\n")
for (fam in unique(ground_truth$te_family)) {
  n <- sum(ground_truth$te_family == fam)
  cat(sprintf("  %s: %d loci\n", fam, n))
}
sink()

message(sprintf("✓ Summary saved: %s", summary_file))
message("")

message("================================================================================")
message("Step 3 Complete!")
message("================================================================================")
message("")
message("Next step: Simulate reads from transcriptome")
message("  bash scripts/04_simulate_reads.sh")
message("")

# EXTENSION POINT: Variable Expression
# -------------------------------------
# To implement variable expression with dropout:
#
# if (expression_model == "variable") {
#   # Load parameters from config
#   dropout_rate <- config$extensions$variable_expression$dropout_rate
#   shape <- config$extensions$variable_expression$shape
#   scale <- config$extensions$variable_expression$scale
#   
#   # Sample from gamma distribution
#   expr_values <- rgamma(n_loci * n_cells, shape = shape, scale = scale)
#   expr_matrix <- matrix(expr_values, nrow = n_loci, ncol = n_cells)
#   
#   # Apply dropout
#   dropout_mask <- matrix(runif(n_loci * n_cells) > dropout_rate, 
#                          nrow = n_loci, ncol = n_cells)
#   expr_matrix <- expr_matrix * dropout_mask
#   
#   # Round to integer UMI counts
#   expr_matrix <- round(expr_matrix)
# }

# EXTENSION POINT: Cell-Type-Specific Expression
# ----------------------------------------------
# To implement cell type patterns:
#
# # Assign cells to types
# n_celltypes <- 3
# cells_per_type <- ceiling(n_cells / n_celltypes)
# cell_types <- rep(1:n_celltypes, length.out = n_cells)
#
# # Create type-specific expression
# for (celltype in 1:n_celltypes) {
#   type_cells <- which(cell_types == celltype)
#   # Upregulate specific TE families for this cell type
#   # expr_matrix[family_indices, type_cells] <- expr_matrix[...] * fold_change
# }
