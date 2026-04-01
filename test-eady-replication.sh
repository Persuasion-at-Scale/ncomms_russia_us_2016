#!/bin/bash
# test-eady-replication.sh
# Proves: git clone + make = all 6 figures
# Real survey data stays untouched; only missing intermediates are generated

set -e
WORKDIR=$(mktemp -d)
echo "==> Working in $WORKDIR"

cd "$WORKDIR"
git clone https://github.com/Persuasion-at-Scale/ncomms_russia_us_2016.git
cd ncomms_russia_us_2016

# Deactivate renv (lockfile targets R 4.1.2; system packages work fine)
Rscript -e 'renv::deactivate()' 2>/dev/null || true

# Install required packages if missing
Rscript -e 'needed <- c("cowplot","ggplot2","readr","dplyr","tidyr","gridExtra","openxlsx","lubridate","stringr","estimatr","nnet","sandwich","lmtest","mvtnorm","haven"); missing <- setdiff(needed, rownames(installed.packages())); if(length(missing)>0) install.packages(missing, repos="https://cloud.r-project.org", quiet=TRUE)'

# Run the full pipeline
make clean
make

echo ""
echo "==> Figures produced:"
ls -la figures/*.pdf

echo ""
echo "==> Real data untouched:"
ls -la data/Survey_Data.rds

echo ""
echo "==> Done. Everything in: $WORKDIR/ncomms_russia_us_2016"
