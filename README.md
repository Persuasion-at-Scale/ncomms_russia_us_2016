# ncomms_russia_us_2016

[![DOI](https://zenodo.org/badge/536623330.svg)](https://zenodo.org/badge/latestdoi/536623330)

Replication materials for the paper [**Exposure to the Russian Internet Research Agency foreign influence campaign on Twitter in the 2016 US Election and its relationship to attitudes and voting behavior**](https://doi.org/10.1038/s41467-022-35576-9)

## Abstract

There is widespread concern that malicious foreign actors are using social media to interfere in elections worldwide. Yet data have been unavailable to investigate links between exposure to foreign influence campaigns and political behavior. Using longitudinal survey data from US respondents linked to their Twitter feeds, we quantify the relationship between exposure to the Russian foreign influence campaign and attitudes and voting behavior in the 2016 US election. We demonstrate, first, that exposure to Russian foreign influence accounts was heavily concentrated: only 1% of users accounted for 70% of exposures. Second, exposure was concentrated among highly partisan Republicans. Third, exposure to the Russian influence campaign were eclipsed by content from domestic news media and politicians. Finally, we find no relationship between exposure to the Russian foreign influence campaign and changes in attitudes, polarization, or voting behavior. The results have implications for understanding the limits of election interference campaigns on social media.

## Content

This repository is organized as follows:

* [code](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/code) (`./code/`) contains scripts for data wrangling, aggregation and analysis. Script [30_write_up_results.R](https://github.com/tpaskhalis/ncomms_russia_us_2016/blob/main/code/30_write_up_results.R) is the script for producing publication results and figures.

* [data](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/data) (`./data/`) contains raw data for the analysis, which can be shared with privacy concerns in mind and falls under the 100MB GitHub limit.

* [figures](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/figures) (`./figures/`) is a directory for writing out figures for publication.

* [figures_source](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/figures_source) (`./figures_source/`) contains source file for figures in the main manuscript.

* [logs](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/logs) (`./logs/`) contains log files.

* [renv](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/renv) (`./renv/`) is a directory with [renv](https://rstudio.github.io/renv/articles/renv.html) dependency management files  .

* [results](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/results) (`./results/`) is a directory for writing out results from analysis and aggregated datasets for replication.

* [supplementary](https://github.com/tpaskhalis/ncomms_russia_us_2016/tree/main/supplementary) (`./supplementary/`) includes the code and compiled versions of supplementary information.

## Quick Start with Synthetic Data

The underlying Twitter data cannot be shared due to data license and privacy constraints (see [Data Availability](#data-availability) below). However, you can run the full pipeline using synthetic data that matches the aggregate statistical properties of the real dataset:

```bash
# Clone and enter the repo
git clone https://github.com/Persuasion-at-Scale/ncomms_russia_us_2016.git
cd ncomms_russia_us_2016

# Run the full pipeline (generates synthetic data, fits models, produces figures)
make
```

This will:
1. Generate synthetic `Survey_Data.rds` (3,500 rows x 190 columns matching real marginal distributions and correlations)
2. Run the regression analysis (scripts 05-07)
3. Produce all 6 publication figures in `figures/`

If you have access to the real data, place `Survey_Data.rds` in `data/` and `make` will use it instead.

### Data Availability

The synthetic data generator (`code/00_generate_synthetic_data.R`) creates data from aggregate statistics only (means, variances, correlations). No individual-level information is stored or recoverable. Scripts 01-03 are stubs; they document what the original data pipeline did but require private Twitter data to run.

## Logs

Log files are produced by running `R CMD BATCH` on scripts located in `code` folder from the root of the project directory. E.g.:

    R CMD BATCH code/05_regression_analysis.R logs/05_regression_analysis.Rlog
    R CMD BATCH code/30_write_up_results.R logs/30_write_up_results.Rlog

Or use the Makefile:

    make          # Full pipeline: data -> results -> figures
    make data     # Generate synthetic data only
    make results  # Run analysis scripts (05-07)
    make figures  # Generate publication figures
    make clean    # Remove all generated outputs

## Citation

```
@Article{doi:10.1038/s41467-022-35576-9,
    author   = {Eady, Gregory and Paskhalis, Tom and Zilinsky, Jan and Bonneau, Richard and Nagler, Jonathan and Tucker, Joshua A.},
    title    = "{Exposure to the Russian Internet Research Agency foreign influence campaign on Twitter in the 2016 US election and its relationship to attitudes and voting behavior}",
    journal  = {Nature Communications},
    year     = {2023},
    volume   = {14},
    number   = {1},
    pages    = {62},
    doi      = {10.1038/s41467-022-35576-9},
    url      = {https://doi.org/10.1038/s41467-022-35576-9},
}

```

------------------------------------------------------------------------

## License

This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).

[![CC BY-NC-SA 4.0](https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png)](http://creativecommons.org/licenses/by-nc-sa/4.0/)
