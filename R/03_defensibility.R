# =============================================================================
# 03_defensibility.R  —  Macro Shock Analyser
# -----------------------------------------------------------------------------
# PURPOSE
#   Prove (don't just assert) that the way we built the model is sound. Two
#   things an interviewer will probe:
#
#   (1) STATIONARITY. We regressed RETURNS on CHANGES, not levels. Why? Because
#       yield LEVELS wander over time (non-stationary), and regressing one
#       wandering series on another produces "spurious" relationships — high
#       R-squared, significant betas, all fake. First-differencing (this month
#       minus last) removes the wandering and leaves a stationary series, where
#       regression betas are trustworthy. Here we TEST that:
#         - ADF test  : null hypothesis = "has a unit root" (NON-stationary).
#                        small p (<0.05) => REJECT null => stationary. GOOD.
#         - KPSS test : null hypothesis = "is stationary" (opposite framing).
#                        large p (>0.05) => fail to reject => stationary. GOOD.
#       The two tests have OPPOSITE nulls on purpose — agreeing from both sides
#       is stronger evidence than either alone.
#       Expectation: LEVELS look non-stationary, CHANGES/returns look stationary
#       — which is exactly what justifies differencing.
#
#   (2) SMALL SAMPLE. Only 3 recession episodes exist in the window. We print
#       the episode/month counts so the caveat is grounded in the actual data:
#       the recession and gamma betas are DIRECTIONAL, not pinpoint.
#
# INPUT   data/processed/monthly_dataset.csv
# RUN     working directory = project root, then source this file.
# NOTE    needs the `tseries` package — run 00_install_packages.R first if
#         you see "there is no package called 'tseries'".
# =============================================================================

library(tidyverse)
library(tseries)   # adf.test(), kpss.test()

df <- readr::read_csv("data/processed/monthly_dataset.csv", show_col_types = FALSE)

# ADF and KPSS print warnings like "p-value smaller/greater than printed" when
# the true p-value is past the table's edge (e.g. <0.01 or >0.10). That is
# normal and is actually the strong-result case; we suppress the warning text
# for a clean table but the capped p-value still tells the story.
adf_p  <- function(x) suppressWarnings(adf.test(x)$p.value)
kpss_p <- function(x) suppressWarnings(kpss.test(x, null = "Level")$p.value)

# Build a tidy verdict table for a set of named series.
stationarity_table <- function(series_list, group_label) {
  tibble(series = names(series_list)) |>
    mutate(
      adf_p  = map_dbl(series_list, adf_p),
      kpss_p = map_dbl(series_list, kpss_p),
      # stationary if ADF rejects its unit-root null AND KPSS does NOT reject
      # its stationarity null.
      adf_says  = if_else(adf_p  < 0.05, "stationary", "NON-stationary"),
      kpss_says = if_else(kpss_p > 0.05, "stationary", "NON-stationary"),
      verdict   = if_else(adf_says == "stationary" & kpss_says == "stationary",
                          "STATIONARY", "non-stationary / mixed")
    ) |>
    mutate(group = group_label, .before = series)
}

# --- the LEVELS we deliberately did NOT regress on (expect non-stationary) ---
levels_list <- list(
  long_rate     = df$long_rate,
  slope         = df$slope,
  sov_spread_bp = df$sov_spread_bp
)

# --- the returns/CHANGES we actually used as variables (expect stationary) ---
changes_list <- list(
  db_ret          = df$db_ret,
  d_long_rate     = df$d_long_rate,
  d_slope         = df$d_slope,
  d_sov_spread_bp = df$d_sov_spread_bp
)

levels_tbl  <- stationarity_table(levels_list,  "LEVELS (not used directly)")
changes_tbl <- stationarity_table(changes_list, "CHANGES / RETURNS (used in models)")

# =============================================================================
# Print results
# =============================================================================
cat("\n=================== STATIONARITY TESTS ===================\n")
cat("ADF  null = unit root (non-stationary): small p (<.05) = stationary = GOOD\n")
cat("KPSS null = stationary               : large p (>.05) = stationary = GOOD\n")

cat("\n--- LEVELS (we did NOT regress on these; expect NON-stationary) ---\n")
print(levels_tbl |> select(series, adf_p, kpss_p, adf_says, kpss_says, verdict))

cat("\n--- CHANGES / RETURNS (the actual model variables; expect STATIONARY) ---\n")
print(changes_tbl |> select(series, adf_p, kpss_p, adf_says, kpss_says, verdict))

cat("\nReading it: if the levels come back non-stationary and the changes come\n")
cat("back stationary, that is the empirical justification for first-differencing\n")
cat("— it confirms the C1/C2 reasoning instead of just asserting it.\n")

# =============================================================================
# Small-sample caveat — grounded in the actual recession counts
# =============================================================================
episodes <- df |>
  filter(recession == 1) |>
  mutate(episode = case_when(
    date <= as.Date("2009-06-01") ~ "2008-09 GFC",
    date <= as.Date("2013-03-01") ~ "2011-13 sovereign-debt",
    TRUE                          ~ "2020 COVID"
  )) |>
  count(episode, name = "months")

cat("\n=================== SMALL-SAMPLE CAVEAT ===================\n")
cat("Recession months:", sum(df$recession), "of", nrow(df),
    "(", round(100 * mean(df$recession), 1), "% of the window )\n")
cat("Distinct recession EPISODES: 3\n\n")
print(episodes)
cat("\nThe binding constraint is the number of distinct episodes (3), not the\n")
cat("row count. The regime we care about most (recession) is the rarest, so its\n")
cat("betas carry the widest error bars. Present recession / gamma betas as\n")
cat("DIRECTIONAL, not pinpoint; claim only what survives the HAC standard errors.\n")
cat("==========================================================\n")
