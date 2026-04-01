#!/usr/bin/env Rscript
# 00_generate_synthetic_data.R
#
# Generates synthetic (fake but statistically comparable) data so the full
# analysis pipeline can run end-to-end without access to the private
# Twitter/survey linkage data.
#
# The synthetic data matches the marginal distributions and key correlations
# of the real data, but contains NO real individual-level information.
#
# Usage: Rscript code/00_generate_synthetic_data.R
# Output: data/Survey_Data.rds
#         results/02_match_respondents/G1A.csv
#         results/02_match_respondents/G1C.csv
#         results/02_match_respondents/G1D.csv
#         results/03_merge_and_clean_survey/G3A.csv
#         data/comparison_surveys/ACS/ACS_2016_1year_R12649774_SL010.csv
#         data/comparison_surveys/Pew/summary_pew2018.csv

cat("Generating synthetic data from aggregate profile...\n")

suppressPackageStartup <- function(...) invisible(NULL)
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite", repos = "https://cloud.r-project.org")
}
if (!requireNamespace("MASS", quietly = TRUE)) {
  install.packages("MASS", repos = "https://cloud.r-project.org")
}

library(jsonlite)
library(MASS)

set.seed(42)  # Reproducibility

# ---- Read profile ----
profile <- fromJSON("./code/00_data_profile.json", simplifyVector = FALSE)
n <- profile$n  # 3500

cat(sprintf("Target: %d rows, %d columns\n", n, length(profile$columns)))

# ---- Step 1: Generate correlated numeric columns via multivariate normal ----
num_cols <- unlist(profile$numeric_columns)
means <- as.numeric(unlist(profile$mean_vector))
cov_mat <- matrix(as.numeric(unlist(profile$cov_matrix)),
                  nrow = length(num_cols), byrow = TRUE)

# Make covariance matrix positive definite (numerical issues from rounding)
eig <- eigen(cov_mat)
eig$values[eig$values < 1e-10] <- 1e-10
cov_mat_pd <- eig$vectors %*% diag(eig$values) %*% t(eig$vectors)

cat(sprintf("Generating %d correlated numeric columns...\n", length(num_cols)))
raw_numeric <- mvrnorm(n = n, mu = means, Sigma = cov_mat_pd)
colnames(raw_numeric) <- num_cols
raw_df <- as.data.frame(raw_numeric)

# ---- Step 2: Post-process each column to match constraints ----
# Build column info lookup
col_info <- list()
for (ci in profile$columns) {
  col_info[[ci$name]] <- ci
}

for (cname in num_cols) {
  ci <- col_info[[cname]]
  if (is.null(ci)) next

  # Clamp to observed range
  if (!is.null(ci$min)) raw_df[[cname]] <- pmax(raw_df[[cname]], ci$min)
  if (!is.null(ci$max)) raw_df[[cname]] <- pmin(raw_df[[cname]], ci$max)

  # For binary columns (0/1), threshold at the observed proportion
  uv <- if (!is.null(ci$unique_values)) as.numeric(unlist(ci$unique_values)) else NULL
  if (!is.null(uv) && length(uv) == 2 && all(uv %in% c(0, 1))) {
    vp <- ci$value_proportions
    prop_1 <- vp[["1.0"]]
    if (is.null(prop_1)) prop_1 <- vp[["1"]]
    if (!is.null(prop_1)) {
      prop_1 <- as.numeric(prop_1)
      raw_df[[cname]] <- as.numeric(raw_df[[cname]] > quantile(raw_df[[cname]], 1 - prop_1, na.rm = TRUE))
    }
  }

  # For ordinal columns with few values, round to nearest observed value
  if (!is.null(uv) && length(uv) > 2 && length(uv) <= 20) {
    vals <- sort(uv)
    raw_df[[cname]] <- vals[findInterval(raw_df[[cname]],
                                          (vals[-length(vals)] + vals[-1]) / 2) + 1]
  }

  # Inject missing values at observed rate
  if (!is.null(ci$n_missing) && ci$n_missing > 0) {
    miss_idx <- sample(n, ci$n_missing)
    raw_df[[cname]][miss_idx] <- NA
  }
}

# ---- Step 3: Generate categorical columns ----
cat("Generating categorical columns...\n")
for (cname in names(col_info)) {
  ci <- col_info[[cname]]
  if (is.null(ci$type) || ci$type != "categorical") next

  props <- ci$proportions
  # Remove NA entries and handle separately
  na_count <- 0
  na_keys <- intersect(names(props), c("nan", "NaN", "NA", "None"))
  if (length(na_keys) > 0) {
    na_count <- round(sum(as.numeric(sapply(na_keys, function(k) props[[k]]))) * n)
    for (k in na_keys) props[[k]] <- NULL
  }

  cats <- names(props)
  probs <- as.numeric(unlist(props))
  # Guard against NA or zero probabilities
  probs[is.na(probs)] <- 0
  if (length(cats) == 0 || sum(probs) == 0) next
  probs <- probs / sum(probs)  # renormalize

  vals <- sample(cats, n, replace = TRUE, prob = probs)
  if (na_count > 0) {
    vals[sample(n, na_count)] <- NA
  }

  cat_levels <- unlist(ci$categories)
  raw_df[[cname]] <- factor(vals, levels = cat_levels)
}

# ---- Step 4: Enforce key constraints ----
# Exposure variables should be consistent:
# total = direct + indirect
# binary = (total > 0)
# log = log(total + 1)
for (prefix in c("russia", "all")) {
  total_col <- paste0("total_exposure_", prefix)
  binary_col <- paste0("total_exposure_", prefix, "_binary")
  log_col <- paste0("total_exposure_", prefix, "_log")
  direct_col <- paste0("direct_exposure_", prefix)
  indirect_col <- paste0("indirect_exposure_", prefix)

  if (all(c(total_col, direct_col, indirect_col) %in% names(raw_df))) {
    # Make exposure counts non-negative integers
    raw_df[[direct_col]] <- pmax(0, round(raw_df[[direct_col]]))
    raw_df[[indirect_col]] <- pmax(0, round(raw_df[[indirect_col]]))
    raw_df[[total_col]] <- raw_df[[direct_col]] + raw_df[[indirect_col]]
  }
  if (all(c(total_col, binary_col) %in% names(raw_df))) {
    raw_df[[binary_col]] <- as.numeric(raw_df[[total_col]] > 0)
  }
  if (all(c(total_col, log_col) %in% names(raw_df))) {
    raw_df[[log_col]] <- log(raw_df[[total_col]] + 1)
  }
}

# total_tweets and total_tweets_log consistency
if (all(c("total_tweets", "total_tweets_log") %in% names(raw_df))) {
  raw_df$total_tweets <- pmax(0, round(raw_df$total_tweets))
  raw_df$total_tweets_log <- log(raw_df$total_tweets + 1)
}

# Ensure column order matches original
all_col_names <- names(col_info)
final_df <- raw_df[, intersect(all_col_names, names(raw_df))]

cat(sprintf("Final synthetic data: %d rows x %d columns\n", nrow(final_df), ncol(final_df)))

# ---- Step 5: Save Survey_Data.rds ----
dir.create("./data", showWarnings = FALSE, recursive = TRUE)
saveRDS(final_df, "./data/Survey_Data.rds")
cat("Saved: data/Survey_Data.rds\n")

# ---- Step 6: Generate results/02_match_respondents/ files ----
dir.create("./results/02_match_respondents", showWarnings = FALSE, recursive = TRUE)

# G1A.csv: daily exposure counts by country
# Real data has columns: country, tweet_date, num_exposures
countries <- c("Russia", "Iran", "Venezuela", "China", "Other")
dates <- seq(as.Date("2016-01-01"), as.Date("2016-11-08"), by = "day")
g1a_rows <- list()
for (country in countries) {
  base_rate <- switch(country,
    "Russia" = 150, "Iran" = 80, "Venezuela" = 20, "China" = 10, "Other" = 5)
  for (d in as.character(dates)) {
    g1a_rows[[length(g1a_rows) + 1]] <- data.frame(
      country = country,
      tweet_date = d,
      num_exposures = max(0, round(rnorm(1, base_rate, base_rate * 0.3)))
    )
  }
}
g1a <- do.call(rbind, g1a_rows)
write.csv(g1a, "./results/02_match_respondents/G1A.csv", row.names = FALSE)
cat("Saved: results/02_match_respondents/G1A.csv\n")

# G1C.csv: individual cumulative exposure (respondent-level)
# Columns: smapp_original_user_id, cum_prop_respondents, cum_prop_exposure
exposed <- final_df[!is.na(final_df$total_exposure_all) & final_df$total_exposure_all > 0, ]
n_exposed <- nrow(exposed)
if (n_exposed > 0) {
  sorted_exp <- sort(exposed$total_exposure_all, decreasing = TRUE)
  g1c <- data.frame(
    smapp_original_user_id = paste0("synth_", seq_len(n_exposed)),
    total_exposure = sorted_exp,
    cum_prop_respondents = seq_len(n_exposed) / n_exposed,
    cum_prop_exposure = cumsum(sorted_exp) / sum(sorted_exp)
  )
} else {
  g1c <- data.frame(smapp_original_user_id = character(0),
                    total_exposure = numeric(0),
                    cum_prop_respondents = numeric(0),
                    cum_prop_exposure = numeric(0))
}
write.csv(g1c, "./results/02_match_respondents/G1C.csv", row.names = FALSE)
cat("Saved: results/02_match_respondents/G1C.csv\n")

# G1D.csv: troll account exposure concentration
# Columns: troll_user_id, troll_screen_name, country, amount, total_amount,
#          prop_exposure, cum_prop_exposure, troll, cum_prop_trolls
n_trolls <- 180
troll_countries <- sample(c("Russia", "Iran", "Venezuela"), n_trolls,
                          replace = TRUE, prob = c(0.7, 0.2, 0.1))
# Power-law-ish distribution: few trolls have most exposure
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

# ---- Step 7: Generate results/03_merge_and_clean_survey/G3A.csv ----
dir.create("./results/03_merge_and_clean_survey", showWarnings = FALSE, recursive = TRUE)

# G3A.csv is used in script 30 for Figure 3a (exposure by party ID)
# Columns: pid7_bin, mean_exposure, se_exposure
pid7_bins <- seq(0, 1, by = 1/6)
g3a_rows <- list()
for (i in seq_along(pid7_bins)) {
  pid_val <- pid7_bins[i]
  # Exposure increases with Republican ID
  mean_exp <- exp(pid_val * 3) * 2
  g3a_rows[[i]] <- data.frame(
    pid7 = pid_val,
    mean_total_exposure_russia = mean_exp,
    se_total_exposure_russia = mean_exp * 0.3
  )
}
g3a <- do.call(rbind, g3a_rows)
write.csv(g3a, "./results/03_merge_and_clean_survey/G3A.csv", row.names = FALSE)
cat("Saved: results/03_merge_and_clean_survey/G3A.csv\n")

# ---- Step 8: Generate comparison survey data ----
dir.create("./data/comparison_surveys/ACS", showWarnings = FALSE, recursive = TRUE)
dir.create("./data/comparison_surveys/Pew", showWarnings = FALSE, recursive = TRUE)

# ACS 2016 demographics (SocialExplorer format with coded column names)
# Values are approximate US adult population counts (in thousands)
acs <- data.frame(
  # Sex (18+)
  SE_A02002B_006 = 119736,  # Male 18+
  SE_A02002B_018 = 126386,  # Female 18+
  # Age (detailed brackets from Census)
  SE_C01001_006 = 22247, SE_C01001_007 = 22113, SE_C01001_008 = 21419, SE_C01001_009 = 14527, SE_C01001_010 = 14168,  # 18-29
  SE_C01001_011 = 20131, SE_C01001_012 = 20647, SE_C01001_013 = 20803, SE_C01001_014 = 21234,  # 30-49
  SE_C01001_015 = 21677, SE_C01001_016 = 21019, SE_C01001_017 = 19883, SE_C01001_018 = 13122,  # 50-64
  SE_C01001_019 = 10894, SE_C01001_020 = 9018, SE_C01001_021 = 7284, SE_C01001_022 = 6148, SE_C01001_023 = 4702, SE_C01001_024 = 4387,  # 65+
  # Education (25+)
  SE_A12001_002 = 11476, SE_A12001_003 = 25427, SE_A12001_004 = 46822,  # No college
  SE_A12001_005 = 43718, SE_A12001_006 = 22790, SE_A12001_007 = 14083, SE_A12001_008 = 4449,  # College+
  # Household income
  SE_A14001A_006 = 38294,  # < 30K
  SE_A14001B_006 = 87012,  # 30K+
  # Race
  SE_A03001_002 = 197277,  # White alone
  SE_A03001_003 = 40241, SE_A03001_004 = 5220, SE_A03001_005 = 18318,
  SE_A03001_006 = 625, SE_A03001_007 = 8070, SE_A03001_008 = 2361  # POC categories
)
write.csv(acs, "./data/comparison_surveys/ACS/ACS_2016_1year_R12649774_SL010.csv", row.names = FALSE)
cat("Saved: data/comparison_surveys/ACS/ACS_2016_1year_R12649774_SL010.csv\n")

# Pew 2018 Twitter demographics (var_category format matching script 06)
pew <- data.frame(
  var = c("sex", "sex", "age", "age", "age", "age",
          "education", "education", "income", "income", "race", "race"),
  category = c("male", "female", "18-29", "30-49", "50-64", "65+",
               "no college", "college+", "< 30,000", "30,000+", "white", "poc"),
  percentage = c(50, 50, 44, 31, 16, 9, 58, 42, 24, 76, 60, 40)
)
write.csv(pew, "./data/comparison_surveys/Pew/summary_pew2018.csv", row.names = FALSE)
cat("Saved: data/comparison_surveys/Pew/summary_pew2018.csv\n")

cat("\n=== Synthetic data generation complete ===\n")
cat("All files generated from aggregate statistics only.\n")
cat("No individual-level data from the original study was used.\n")
