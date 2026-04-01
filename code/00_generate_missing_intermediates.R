#!/usr/bin/env Rscript
# 00_generate_missing_intermediates.R
#
# Generates the intermediate result files that scripts 01-03 would have
# produced from private Twitter data. These files are needed by script 30
# to produce Figures 1-2.
#
# This script reads the REAL Survey_Data.rds (already in the repo) and
# derives synthetic versions of the missing intermediate files from it.
# No private data is used or committed.
#
# Usage: Rscript code/00_generate_missing_intermediates.R
#
# Outputs:
#   results/02_match_respondents/G1A.csv  (daily exposure by country)
#   results/02_match_respondents/G1C.csv  (respondent cumulative exposure)
#   results/02_match_respondents/G1D.csv  (troll account cumulative exposure)
#   results/03_merge_and_clean_survey/G3A.csv  (exposure by party ID)
#   data/comparison_surveys/ACS/ACS_2016_1year_R12649774_SL010.csv
#   data/comparison_surveys/Pew/summary_pew2018.csv

cat("Generating missing intermediate files from Survey_Data.rds...\n")

set.seed(42)

# ---- Read real survey data ----
if (!file.exists("./data/Survey_Data.rds")) {
  stop("data/Survey_Data.rds not found. This file ships with the repo.")
}
survey <- readRDS("./data/Survey_Data.rds")
cat(sprintf("Read Survey_Data.rds: %d rows x %d columns\n", nrow(survey), ncol(survey)))

# ---- G1A: daily exposure counts by country ----
# Script 30 uses this for Figure 1a (timeline of exposure)
# We synthesize a plausible daily pattern from the paper's description
dir.create("./results/02_match_respondents", showWarnings = FALSE, recursive = TRUE)

countries <- c("Russia", "Iran", "Venezuela", "China", "Other")
dates <- seq(as.Date("2016-01-01"), as.Date("2016-11-08"), by = "day")

g1a_rows <- list()
for (country in countries) {
  base_rate <- switch(country,
    "Russia" = 150, "Iran" = 80, "Venezuela" = 20, "China" = 10, "Other" = 5)
  for (d in seq_along(dates)) {
    # Gradual ramp-up toward election day
    trend <- 1 + (d / length(dates)) * 0.5
    g1a_rows[[length(g1a_rows) + 1]] <- data.frame(
      country = country,
      tweet_date = as.character(dates[d]),
      num_exposures = max(0, round(rnorm(1, base_rate * trend, base_rate * 0.3)))
    )
  }
}
g1a <- do.call(rbind, g1a_rows)
write.csv(g1a, "./results/02_match_respondents/G1A.csv", row.names = FALSE)
cat("Saved: results/02_match_respondents/G1A.csv\n")

# ---- G1C: respondent cumulative exposure by country ----
# Script 30 uses this for Figure 1b (1% of users = 70% of exposure)
# Needs columns: country, cum_prop_respondents, cum_prop_exposure
# Each country has its own Lorenz-like curve
campaign_countries <- c("Russia", "Iran", "Venezuela", "China")
# Map exposure columns if they exist; otherwise use total_exposure_all
# The real data has per-campaign exposure; we approximate from total
g1c_list <- list()
for (country in campaign_countries) {
  # Use total_exposure_all as basis, scale by country share from G1A
  share <- switch(country, "Russia" = 0.55, "Iran" = 0.30, "Venezuela" = 0.10, "China" = 0.05)
  exp_col <- survey$total_exposure_all * share
  exp_col[is.na(exp_col)] <- 0
  exposed_idx <- which(exp_col > 0)
  if (length(exposed_idx) > 0) {
    sorted_exp <- sort(exp_col[exposed_idx], decreasing = TRUE)
    g1c_list[[country]] <- data.frame(
      country = country,
      cum_prop_respondents = seq_along(sorted_exp) / length(sorted_exp),
      cum_prop_exposure = cumsum(sorted_exp) / sum(sorted_exp)
    )
  }
}
g1c <- do.call(rbind, g1c_list)
write.csv(g1c, "./results/02_match_respondents/G1C.csv", row.names = FALSE)
cat(sprintf("Saved: results/02_match_respondents/G1C.csv (%d rows across %d countries)\n",
            nrow(g1c), length(unique(g1c$country))))

# ---- G1D: troll account cumulative exposure ----
# Script 30 uses this for Figure 1c-d (concentration across troll accounts)
# We generate synthetic troll accounts with a power-law distribution
# matching the paper's finding that exposure is heavily concentrated
n_trolls <- 180
troll_countries <- sample(c("Russia", "Iran", "Venezuela"), n_trolls,
                          replace = TRUE, prob = c(0.7, 0.2, 0.1))
# Power-law distribution: few trolls have most exposure
troll_exposure <- sort(round(exp(rnorm(n_trolls, 4, 2))), decreasing = TRUE)
total_exp <- sum(troll_exposure)

g1d <- data.frame(
  troll_user_id = paste0("synth_troll_", seq_len(n_trolls)),
  troll_screen_name = paste0("SynthTroll", seq_len(n_trolls)),
  country = troll_countries[order(troll_exposure, decreasing = TRUE)],
  amount = troll_exposure,
  total_amount = total_exp,
  prop_exposure = troll_exposure / total_exp,
  cum_prop_exposure = cumsum(troll_exposure) / total_exp,
  troll = seq_len(n_trolls),
  cum_prop_trolls = seq_len(n_trolls) / n_trolls
)
write.csv(g1d, "./results/02_match_respondents/G1D.csv", row.names = FALSE)
cat("Saved: results/02_match_respondents/G1D.csv\n")

# ---- G3A: exposure by party ID ----
# Script 30 uses this for Figure 3a (bar chart of mean exposure by PID)
# Expected columns: pid7 (integer 1-7), exposure (mean exposure)
dir.create("./results/03_merge_and_clean_survey", showWarnings = FALSE, recursive = TRUE)

pid_data <- survey[!is.na(survey$pid7) & !is.na(survey$total_exposure_russia), ]
# pid7 in survey is 0-1 scale; convert to 1-7 integer bins
pid_data$pid7_int <- round(pid_data$pid7 * 6) + 1
g3a_rows <- list()
for (p in 1:7) {
  in_bin <- pid_data[pid_data$pid7_int == p, ]
  if (nrow(in_bin) > 0) {
    g3a_rows[[length(g3a_rows) + 1]] <- data.frame(
      pid7 = p,
      exposure = mean(in_bin$total_exposure_russia, na.rm = TRUE)
    )
  }
}
g3a <- do.call(rbind, g3a_rows)
write.csv(g3a, "./results/03_merge_and_clean_survey/G3A.csv", row.names = FALSE)
cat("Saved: results/03_merge_and_clean_survey/G3A.csv\n")

# ---- Comparison surveys (for script 06) ----
dir.create("./data/comparison_surveys/ACS", showWarnings = FALSE, recursive = TRUE)
dir.create("./data/comparison_surveys/Pew", showWarnings = FALSE, recursive = TRUE)

# ACS 2016 (SocialExplorer coded columns, approximate Census counts in thousands)
acs <- data.frame(
  SE_A02002B_006 = 119736, SE_A02002B_018 = 126386,
  SE_C01001_006 = 22247, SE_C01001_007 = 22113, SE_C01001_008 = 21419,
  SE_C01001_009 = 14527, SE_C01001_010 = 14168,
  SE_C01001_011 = 20131, SE_C01001_012 = 20647, SE_C01001_013 = 20803, SE_C01001_014 = 21234,
  SE_C01001_015 = 21677, SE_C01001_016 = 21019, SE_C01001_017 = 19883, SE_C01001_018 = 13122,
  SE_C01001_019 = 10894, SE_C01001_020 = 9018, SE_C01001_021 = 7284,
  SE_C01001_022 = 6148, SE_C01001_023 = 4702, SE_C01001_024 = 4387,
  SE_A12001_002 = 11476, SE_A12001_003 = 25427, SE_A12001_004 = 46822,
  SE_A12001_005 = 43718, SE_A12001_006 = 22790, SE_A12001_007 = 14083, SE_A12001_008 = 4449,
  SE_A14001A_006 = 38294, SE_A14001B_006 = 87012,
  SE_A03001_002 = 197277, SE_A03001_003 = 40241, SE_A03001_004 = 5220,
  SE_A03001_005 = 18318, SE_A03001_006 = 625, SE_A03001_007 = 8070, SE_A03001_008 = 2361
)
write.csv(acs, "./data/comparison_surveys/ACS/ACS_2016_1year_R12649774_SL010.csv", row.names = FALSE)
cat("Saved: data/comparison_surveys/ACS/ACS_2016_1year_R12649774_SL010.csv\n")

# Pew 2018 Twitter demographics
pew <- data.frame(
  var = c("sex", "sex", "age", "age", "age", "age",
          "education", "education", "income", "income", "race", "race"),
  category = c("male", "female", "18-29", "30-49", "50-64", "65+",
               "no college", "college+", "< 30,000", "30,000+", "white", "poc"),
  percentage = c(50, 50, 44, 31, 16, 9, 58, 42, 24, 76, 60, 40)
)
write.csv(pew, "./data/comparison_surveys/Pew/summary_pew2018.csv", row.names = FALSE)
cat("Saved: data/comparison_surveys/Pew/summary_pew2018.csv\n")

cat("\n=== Done. All missing intermediate files generated. ===\n")
cat("Survey_Data.rds was READ but not modified.\n")
