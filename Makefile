# Makefile for Eady et al. (2023) replication
#
# Usage:
#   make          - Generate missing intermediate files, then produce figures
#   make figures  - Generate all 6 publication figures
#   make clean    - Remove generated intermediate files (keeps real data)
#
# The real Survey_Data.rds and pre-computed results (scripts 05-07) ship
# with the repo. This Makefile only generates the intermediate files from
# scripts 01-03 that could not be shared due to Twitter data licensing.

.PHONY: all figures clean help

all: figures

help:
	@echo "Targets:"
	@echo "  make          - Generate missing intermediates + figures"
	@echo "  make figures  - Generate all 6 publication figures"
	@echo "  make clean    - Remove generated intermediates"

# ---- Generate missing intermediate files ----
# Scripts 01-03 require private Twitter data. This rule synthesizes
# the intermediate results they would have produced, using only the
# real Survey_Data.rds that is already public in this repo.
results/02_match_respondents/G1A.csv: data/Survey_Data.rds code/00_generate_missing_intermediates.R
	@echo "==> Generating missing intermediate files..."
	Rscript code/00_generate_missing_intermediates.R

# ---- Figures ----
figures: results/02_match_respondents/G1A.csv
	@echo "==> Generating publication figures (script 30)..."
	Rscript code/30_write_up_results.R
	@echo "==> Done. Figures written to figures/"

# ---- Clean ----
# Only removes generated intermediates. NEVER touches Survey_Data.rds
# or pre-computed results from scripts 05-07.
clean:
	rm -rf results/02_match_respondents
	rm -rf results/03_merge_and_clean_survey
	rm -rf data/comparison_surveys
	rm -f figures/*.pdf
	@echo "Cleaned. Run 'make' to regenerate."
