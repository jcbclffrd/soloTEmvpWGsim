#!/usr/bin/env Rscript
# Renders 07_compare_report.Rmd to REPORT2.html.
# Run from repo root: Rscript analysis/liftover/08_render2.R

library(rmarkdown)

rmd <- file.path("analysis", "liftover", "07_compare_report.Rmd")
out <- file.path("analysis", "liftover", "results")

cat("Rendering REPORT2.html...\n")
render(rmd,
       output_format = "html_document",
       output_dir    = out,
       output_file   = "REPORT2.html",
       quiet         = FALSE)
cat("HTML written to:", file.path(out, "REPORT2.html"), "\n")
