#!/usr/bin/env Rscript
# Renders 05_render_report.Rmd to HTML (and PDF if LaTeX available).
# Run from repo root: Rscript analysis/liftover/06_render.R

library(rmarkdown)

rmd  <- file.path("analysis", "liftover", "05_render_report.Rmd")
out  <- file.path("analysis", "liftover", "results")

cat("Rendering HTML report...\n")
render(rmd,
       output_format = "html_document",
       output_dir    = out,
       output_file   = "REPORT.html",
       quiet         = FALSE)
cat("HTML written to:", file.path(out, "REPORT.html"), "\n")

# PDF requires LaTeX — try but don't fail the script if unavailable
tryCatch({
  cat("Rendering PDF report...\n")
  render(rmd,
         output_format = "pdf_document",
         output_dir    = out,
         output_file   = "REPORT.pdf",
         quiet         = FALSE)
  cat("PDF written to:", file.path(out, "REPORT.pdf"), "\n")
}, error = function(e) {
  cat("PDF rendering skipped (LaTeX not available):", conditionMessage(e), "\n")
})
