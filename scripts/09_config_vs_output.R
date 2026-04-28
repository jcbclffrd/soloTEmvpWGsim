#!/usr/bin/env Rscript
################################################################################
# Pipeline Script 9: Config-In vs Pipeline-Out Summary
#
# Answers the simple question: does the pipeline output match what we put in?
# No classifier metrics — just a parameter-by-parameter comparison between
# config.yaml (what we asked for) and the observed pipeline outputs.
#
# Sections:
#   1. Simulation inputs  (what config.yaml requested)
#   2. Read generation    (how many reads were created)
#   3. Alignment          (what STAR did with them)
#   4. TE quantification  (what soloTE recovered for our planted loci)
#   5. Recovery summary   (why counts differ from config, if they do)
################################################################################

suppressPackageStartupMessages({
  library(yaml)
  library(tidyverse)
  library(Matrix)
})

# Tee all message() output to a human-readable report file
output_dir <- "validation_report"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
report_path <- file.path(output_dir, "pipeline_report.txt")
report_con  <- file(report_path, open = "w")
sink(report_con, type = "message")

message("================================================================================")
message("Pipeline Step 9: Config-In vs Pipeline-Out Summary")
message("================================================================================")
message("")

# ==============================================================================
# 1. SIMULATION INPUTS (config.yaml)
# ==============================================================================
config <- yaml::read_yaml("config.yaml")

cfg_cells        <- config$simulation$n_cells
cfg_loci         <- config$simulation$n_te_loci
cfg_reads_cell   <- config$simulation$reads_per_cell
cfg_umi_per_loc  <- as.integer(cfg_reads_cell / cfg_loci)  # derived: reads_per_cell / n_te_loci
cfg_read_len     <- config$simulation$read_length
cfg_cb_len       <- config$simulation$cb_length
cfg_umi_len      <- config$simulation$umi_length
output_prefix    <- config$solote$output_prefix

cfg_total_reads  <- cfg_cells * cfg_reads_cell
cfg_total_umis   <- cfg_cells * cfg_loci * cfg_umi_per_loc  # across all cells & loci

message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
message("SECTION 1 — SIMULATION INPUTS (config.yaml)")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
message(sprintf("  Cells:                     %d", cfg_cells))
message(sprintf("  TE loci (ground truth):    %d", cfg_loci))
message(sprintf("  UMIs per locus per cell:   %d", cfg_umi_per_loc))
message(sprintf("  Reads per cell:            %s", format(cfg_reads_cell, big.mark=",")))
message(sprintf("  Read length:               %d bp", cfg_read_len))
message(sprintf("  ──────────────────────────────────"))
message(sprintf("  Expected total reads:      %s", format(cfg_total_reads, big.mark=",")))
message(sprintf("  Expected total TE UMIs:    %s  (%d cells × %d loci × %d UMIs)",
                format(cfg_total_umis, big.mark=","), cfg_cells, cfg_loci, cfg_umi_per_loc))
message("")

# ==============================================================================
# 2. READ GENERATION
# ==============================================================================
r1 <- "synthetic_data/fastqs/synthetic_10x_S1_L001_R1_001.fastq.gz"
r2 <- "synthetic_data/fastqs/synthetic_10x_S1_L001_R2_001.fastq.gz"

message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
message("SECTION 2 — READ GENERATION (fastq files)")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

if (file.exists(r2)) {
  # Count reads from R2 (the cDNA read — one line per read in 4-line fastq)
  obs_reads_raw <- as.integer(system(
    sprintf("zcat %s | wc -l", r2), intern = TRUE)) %/% 4L
  match_pct <- round(obs_reads_raw / cfg_total_reads * 100, 1)
  flag <- if (obs_reads_raw == cfg_total_reads) "✓" else "△"
  message(sprintf("  %s Generated reads: %s  (config requested %s, %.1f%%)",
                  flag,
                  format(obs_reads_raw, big.mark=","),
                  format(cfg_total_reads, big.mark=","),
                  match_pct))
} else {
  obs_reads_raw <- NA_integer_
  message("  ! Fastq files not found — skipping read count check")
}
message("")

# ==============================================================================
# 3. ALIGNMENT (STARsolo Log.final.out)
# ==============================================================================
star_log <- "synthetic_data/outputs/star_alignment/Log.final.out"

message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
message("SECTION 3 — ALIGNMENT (STARsolo)")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

parse_star_field <- function(log_lines, label) {
  line <- grep(label, log_lines, value = TRUE)[1]
  if (is.na(line)) return(NA_character_)
  trimws(sub(".*\\|", "", line))
}

if (file.exists(star_log)) {
  log_lines <- readLines(star_log)

  star_input     <- as.integer(gsub(",", "", parse_star_field(log_lines, "Number of input reads")))
  star_uniq_n    <- as.integer(gsub(",", "", parse_star_field(log_lines, "Uniquely mapped reads number")))
  star_uniq_pct  <- parse_star_field(log_lines, "Uniquely mapped reads %")
  star_multi_pct <- parse_star_field(log_lines, "% of reads mapped to multiple loci")
  star_tooloci_n <- as.integer(gsub(",", "", parse_star_field(log_lines, "Number of reads mapped to too many loci")))
  star_tooloci_pct <- parse_star_field(log_lines, "% of reads mapped to too many loci")
  star_unmap_short_pct <- parse_star_field(log_lines, "% of reads unmapped: too short")
  star_unmap_other_pct <- parse_star_field(log_lines, "% of reads unmapped: other")

  cfg_flag <- if (!is.na(star_input) && star_input == cfg_total_reads) "✓" else "△"
  message(sprintf("  %s Input reads:         %s  (config requested %s)",
                  cfg_flag,
                  format(star_input, big.mark=","),
                  format(cfg_total_reads, big.mark=",")))
  message(sprintf("  Uniquely mapped:       %s  (%s reads)",
                  star_uniq_pct, format(star_uniq_n, big.mark=",")))
  message(sprintf("  Multi-mapped (kept):   %s", star_multi_pct))
  message(sprintf("  Too many loci (lost):  %s  (%s reads, permanently discarded)",
                  star_tooloci_pct, format(star_tooloci_n, big.mark=",")))
  message(sprintf("  Unmapped (too short):  %s", star_unmap_short_pct))
  message(sprintf("  Unmapped (other):      %s", star_unmap_other_pct))

  usable_pct <- round((star_uniq_n / star_input) * 100, 1)
  message(sprintf("  ──────────────────────────────────"))
  message(sprintf("  Usable (uniquely mapped) reads: %s%%", usable_pct))
  message(sprintf("  Note: TE reads are highly repetitive — multi-mapper loss is expected."))
} else {
  star_input <- NA_integer_
  message("  ! STAR log not found — skipping alignment stats")
}
message("")

# ==============================================================================
# 4. TE QUANTIFICATION (soloTE locustes matrix — ground truth loci only)
# ==============================================================================
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
message("SECTION 4 — TE QUANTIFICATION (soloTE, ground truth loci)")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

ground_truth <- read_tsv("ground_truth/selected_te_loci.tsv", show_col_types = FALSE)
expression_profile <- read_tsv("synthetic_data/transcriptome/expression_profile.tsv", show_col_types = FALSE)

solote_dir   <- sprintf("synthetic_data/outputs/solote/%s_SoloTE_output", output_prefix)
locus_mtx_dir <- file.path(solote_dir, sprintf("%s_locustes_MATRIX", output_prefix))

if (!dir.exists(locus_mtx_dir)) {
  stop(sprintf("soloTE locus matrix not found: %s\nPlease run scripts/07_run_solote.sh", locus_mtx_dir))
}

features <- read_tsv(file.path(locus_mtx_dir, "features.tsv"),
                     col_names = FALSE, show_col_types = FALSE)$X1
barcodes <- read_tsv(file.path(locus_mtx_dir, "barcodes.tsv"),
                     col_names = FALSE, show_col_types = FALSE)$X1
mtx <- readMM(file.path(locus_mtx_dir, "matrix.mtx"))
observed_matrix <- as.matrix(mtx)
rownames(observed_matrix) <- features
colnames(observed_matrix) <- barcodes

obs_cells <- ncol(observed_matrix)
obs_total_features <- nrow(observed_matrix)

message(sprintf("  Cells in output matrix:    %d  (config: %d)", obs_cells, cfg_cells))
message(sprintf("  Total features in matrix:  %d  (GT loci + all other genome TEs)",
                obs_total_features))
message("")

# Match soloTE features to ground truth by coordinate
parse_locus_coords <- function(feature_name) {
  if (grepl("chr[^|]+\\|[0-9]+\\|[0-9]+", feature_name)) {
    clean <- sub("^SoloTE\\|", "", feature_name)
    parts <- str_split(clean, "\\|")[[1]]
    tibble(chr = parts[1], start = as.integer(parts[2]), end = as.integer(parts[3]))
  } else {
    tibble(chr = NA_character_, start = NA_integer_, end = NA_integer_)
  }
}

tol <- 10L
parsed_features <- tibble(feature_name = features) %>%
  mutate(parsed = map(feature_name, parse_locus_coords)) %>%
  unnest(parsed)

matched <- parsed_features %>%
  filter(!is.na(chr)) %>%
  left_join(ground_truth %>% select(locus_id, chr, start, end, te_family),
            by = "chr", relationship = "many-to-many") %>%
  filter(abs(start.x - start.y) <= tol, abs(end.x - end.y) <= tol) %>%
  select(feature_name, locus_id, chr, te_family,
         start = start.x, end = end.x)

n_gt_planted  <- nrow(ground_truth)
n_gt_detected <- length(unique(matched$locus_id))
n_gt_missed   <- n_gt_planted - n_gt_detected

message(sprintf("  Ground truth loci planted: %d  (config: n_te_loci = %d)",
                n_gt_planted, cfg_loci))
message(sprintf("  Ground truth loci found:   %d  (%d missed)",
                n_gt_detected, n_gt_missed))
message("")

if (n_gt_detected > 0) {
  gt_obs   <- observed_matrix[matched$feature_name, , drop = FALSE]
  all_obs  <- observed_matrix

  # Per-locus total UMIs observed
  gt_locus_totals <- rowSums(gt_obs)

  # Expected per locus across all cells
  cfg_expected_per_locus <- cfg_cells * cfg_umi_per_loc

  # Per-(locus,cell) UMI averages
  cfg_expected_per_cell  <- cfg_umi_per_loc
  obs_mean_per_cell      <- mean(as.vector(gt_obs))
  obs_median_per_cell    <- median(as.vector(gt_obs))

  # Recovery rate
  cfg_gt_total_umis <- n_gt_planted * cfg_expected_per_locus
  obs_gt_total_umis <- sum(gt_locus_totals)
  recovery_rate     <- obs_gt_total_umis / cfg_gt_total_umis

  message("  Per-locus UMI counts (observed vs expected):")
  message(sprintf("  %-12s %-12s %-12s %-12s %s",
                  "Locus", "TE family", "Expected", "Observed", "Recovery"))
  message(sprintf("  %-12s %-12s %-12s %-12s %s",
                  "─────────", "─────────", "────────", "────────", "────────"))

  per_locus <- matched %>%
    mutate(
      expected_total = cfg_expected_per_locus,
      observed_total = gt_locus_totals[feature_name],
      recovery_pct   = round(observed_total / expected_total * 100, 1)
    ) %>%
    arrange(locus_id)

  walk(seq_len(nrow(per_locus)), function(i) {
    r <- per_locus[i, ]
    message(sprintf("  %-12s %-12s %8d     %8d     %5.1f%%",
                    r$locus_id, r$te_family,
                    r$expected_total, r$observed_total, r$recovery_pct))
  })

  message("")
  message("  Summary:")
  message(sprintf("    Config UMIs/locus/cell:   %d", cfg_expected_per_cell))
  message(sprintf("    Observed mean/locus/cell: %.1f  (median: %.1f)",
                  obs_mean_per_cell, obs_median_per_cell))
  message(sprintf("    Config total GT UMIs:     %s",
                  format(cfg_gt_total_umis, big.mark=",")))
  message(sprintf("    Observed total GT UMIs:   %s",
                  format(obs_gt_total_umis, big.mark=",")))
  message(sprintf("    Overall recovery rate:    %.1f%%", recovery_rate * 100))

  total_matrix_umis <- sum(all_obs)
  gt_fraction <- obs_gt_total_umis / total_matrix_umis
  message(sprintf("    GT share of all UMIs:     %.1f%%  (%s GT / %s total)",
                  gt_fraction * 100,
                  format(obs_gt_total_umis, big.mark=","),
                  format(total_matrix_umis, big.mark=",")))
} else {
  message("  ! No ground truth loci matched in soloTE output.")
  obs_gt_total_umis <- 0L
  recovery_rate     <- 0
}
message("")

# ==============================================================================
# 5. RECOVERY EXPLANATION
# ==============================================================================
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
message("SECTION 5 — WHY RECOVERY < 100%  (expected losses)")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
message("")
message("  TE sequences are repetitive by definition — the same ~300 bp Alu or L1")
message("  sequence appears in thousands of locations across the genome.  When STAR")
message("  aligns a synthetic read from TE_001, it may find 500 equally valid positions.")
message("  With --outSAMmultNmax 1 --outMultimapperOrder Random, one is chosen at")
message("  random → only ~1/500 reads land back on TE_001, the rest scatter to real")
message("  genome copies of the same repeat.  soloTE then correctly counts UMIs at")
message("  each of those positions, spreading counts across the genome.")
message("")
message("  Observed losses this run:")
if (!is.na(star_input) && star_input > 0) {
  message(sprintf("    Reads lost to 'too many loci' filter:  %s  (STAR drops reads > %d alignments)",
                  star_tooloci_pct, config$alignment$outFilterMultimapNmax))
}
message(sprintf("    Multi-mapping dispersal (estimated):   %.0f%%  of remaining reads scattered",
                (1 - recovery_rate) * 100))
message("")
message("  This is not a pipeline error — it is the expected behaviour of aligning")
message("  short reads from repetitive elements to a complete reference genome.")
message("  A real experiment would show the same pattern; the key validation point")
message("  is that ALL planted loci are DETECTED, even if counts are diluted.")
message("")

# ==============================================================================
# 6. SAVE SUMMARY TABLE
# ==============================================================================
summary_tbl <- tibble(
  parameter = c(
    "n_cells",
    "n_te_loci",
    "total_features_in_matrix",
    "umi_per_locus_per_cell",
    "reads_per_cell",
    "total_reads",
    "total_gt_umis",
    "recovery_rate_pct",
    "gt_share_of_all_umis_pct",
    "gt_loci_missed"
  ),
  config = c(
    cfg_cells,
    cfg_loci,
    cfg_loci,   # planted loci; soloTE will find more via multi-mapping
    cfg_umi_per_loc,
    cfg_reads_cell,
    cfg_total_reads,
    cfg_cells * cfg_loci * cfg_umi_per_loc,
    100,        # expected recovery is 100%
    NA,
    0           # expected: no loci missed
  ),
  observed = c(
    obs_cells,
    n_gt_detected,
    obs_total_features,
    if (n_gt_detected > 0) round(obs_mean_per_cell, 2) else NA,
    NA,         # not directly measurable per-cell from STAR log
    if (!is.na(star_input)) star_input else NA,
    obs_gt_total_umis,
    round(recovery_rate * 100, 2),
    if (n_gt_detected > 0) round(gt_fraction * 100, 2) else NA,
    n_gt_missed
  )
)

write_tsv(summary_tbl, file.path(output_dir, "config_vs_output.tsv"))
message(sprintf("✓ Summary table saved: %s/config_vs_output.tsv", output_dir))
message(sprintf("✓ Report saved:        %s/pipeline_report.txt", output_dir))
message("")
message("================================================================================")
message("Step 9 Complete!")
message("================================================================================")
message("")

# Close the message sink so the final confirmation prints to terminal, not file
sink(type = "message")
close(report_con)
cat(sprintf("\nReport written to: %s/pipeline_report.txt\n", output_dir))
