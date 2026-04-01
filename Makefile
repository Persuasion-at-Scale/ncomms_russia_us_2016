# Makefile for Eady et al. (2023) replication
#
# Usage:
#   make          - Generate all figures (synthesizes data if needed)
#   make data     - Generate synthetic data only
#   make results  - Run analysis scripts (05-07)
#   make figures  - Generate publication figures (script 30)
#   make clean    - Remove generated files (keeps real data if present)
#
# If you have access to the real data, place Survey_Data.rds in data/
# and the pipeline will use it instead of generating synthetic data.

.PHONY: all data results figures clean help

all: figures

help:
	@echo "Targets:"
	@echo "  make          - Full pipeline: data -> results -> figures"
	@echo "  make data     - Generate synthetic data (if real data is absent)"
	@echo "  make results  - Run regression analysis (scripts 05-07)"
	@echo "  make figures  - Generate all 6 publication figures"
	@echo "  make clean    - Remove all generated outputs"

# ---- Data layer ----
# If data/Survey_Data.rds doesn't exist, generate synthetic version
data/Survey_Data.rds:
	@echo "==> Real data not found. Generating synthetic data..."
	Rscript code/00_generate_synthetic_data.R

data: data/Survey_Data.rds

# ---- Results layer ----
# Script 05: core regression analysis (167 models)
results/05_regression_analysis/.done: data/Survey_Data.rds code/05_regression_analysis.R
	@echo "==> Running regression analysis (script 05)..."
	Rscript code/05_regression_analysis.R
	@touch $@

# Script 06: survey comparison
results/06_survey_comparison/.done: data/Survey_Data.rds code/06_survey_comparison.R
	@echo "==> Running survey comparison (script 06)..."
	Rscript code/06_survey_comparison.R
	@touch $@

# Script 07: equivalence tests
results/07_equivalence_tests/.done: data/Survey_Data.rds code/07_equivalence_tests.R
	@echo "==> Running equivalence tests (script 07)..."
	Rscript code/07_equivalence_tests.R
	@touch $@

results: results/05_regression_analysis/.done results/06_survey_comparison/.done results/07_equivalence_tests/.done

# ---- Figures layer ----
figures: results results/02_match_respondents/G1A.csv
	@echo "==> Generating publication figures (script 30)..."
	Rscript code/30_write_up_results.R
	@echo "==> Done. Figures written to figures/"

# G1A.csv is created by the synthetic generator; this rule ensures it exists
results/02_match_respondents/G1A.csv: data/Survey_Data.rds
	@test -f $@ || (echo "Missing $@; re-run: make clean && make data" && exit 1)

# ---- Clean ----
clean:
	rm -f data/Survey_Data.rds
	rm -rf results/02_match_respondents
	rm -rf results/03_merge_and_clean_survey
	rm -f results/05_regression_analysis/.done
	rm -f results/06_survey_comparison/.done
	rm -f results/07_equivalence_tests/.done
	rm -rf results/05_regression_analysis/*.rds results/05_regression_analysis/*.csv
	rm -rf results/06_survey_comparison/*.csv
	rm -rf results/07_equivalence_tests/*.csv
	rm -f figures/*.pdf
	rm -rf data/comparison_surveys
	@echo "Cleaned. Run 'make' to regenerate from scratch."
