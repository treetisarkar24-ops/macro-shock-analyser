# =============================================================================
# 02_models.R  —  Macro Shock Analyser
# -----------------------------------------------------------------------------
# PURPOSE
#   Estimate how Deutsche Bank's monthly return responds to macro shocks, and
#   test the project's thesis: that the response (beta) CHANGES between
#   recession and expansion. A single beta over 21 years is an average across
#   very different worlds; we want to see the regimes separately.
#
#   Two models, each sharing the credit-spread factor:
#     Model A (headline)   : db_ret ~ d_sov_spread_bp + d_slope
#     Model B (robustness) : db_ret ~ d_sov_spread_bp + d_long_rate
#
#   For each model we run:
#     (1) FULL SAMPLE   — one beta per factor across all 261 months.
#     (2) REGIME SPLIT  — a recession dummy interacted with each factor, so
#         every factor gets an EXPANSION beta and a RECESSION beta. The
#         interaction term is gamma = recession beta - expansion beta. Testing
#         gamma != 0 is the whole point: does sensitivity actually shift?
#
#   All standard errors are Newey-West HAC (heteroskedasticity- and
#   autocorrelation-consistent). Monthly financial returns have mild serial
#   correlation and changing variance; plain OLS SEs would understate
#   uncertainty and make us over-confident. HAC fixes the SEs without changing
#   the beta estimates. (This is the Stage-4 "defensibility" requirement, done
#   here because you can't read significance honestly without it.)
#
# INPUT   data/processed/monthly_dataset.csv   (built by 01_load_data.R)
# RUN     working directory = project root, then source this file.
# =============================================================================

library(tidyverse)   # read_csv, dplyr
library(sandwich)    # NeweyWest() HAC covariance matrix
library(lmtest)      # coeftest(), waldtest()

df <- readr::read_csv("data/processed/monthly_dataset.csv", show_col_types = FALSE)

# Newey-West HAC covariance. prewhite = FALSE keeps it simple/transparent;
# bandwidth is chosen automatically (Newey-West 1994 plug-in). We reuse this
# everywhere so significance is judged on the same, honest, basis.
hac_vcov <- function(m) NeweyWest(m, prewhite = FALSE, adjust = TRUE)

# Pretty-print a fitted model with HAC standard errors + fit stats.
report <- function(m, label) {
  cat("\n========== ", label, " ==========\n", sep = "")
  print(coeftest(m, vcov. = hac_vcov(m)))
  s <- summary(m)
  cat(sprintf("R-squared: %.4f   Adj R-squared: %.4f   n: %d\n",
              s$r.squared, s$adj.r.squared, nobs(m)))
}

# =============================================================================
# 1. FULL-SAMPLE MODELS  (one beta per factor, all months pooled)
# =============================================================================
A_full <- lm(db_ret ~ d_sov_spread_bp + d_slope,     data = df)
B_full <- lm(db_ret ~ d_sov_spread_bp + d_long_rate, data = df)

report(A_full, "MODEL A — full sample (spread + slope)")
report(B_full, "MODEL B — full sample (spread + long rate)")

# =============================================================================
# 2. REGIME-SPLIT MODELS
# -----------------------------------------------------------------------------
# We fit the interaction model TWICE with the dummy flipped, which is a clean
# trick to read off both regimes' betas WITH their own HAC standard errors:
#
#   * with `recession` (0 in expansion): the main-effect betas ARE the
#     EXPANSION betas; the interaction terms are gamma (recession - expansion).
#   * with `expansion = 1 - recession`: the main-effect betas ARE the
#     RECESSION betas. (Same model, just re-based, so gamma is unchanged.)
#
# So: expansion betas + gamma come from fit #1; recession betas come from fit
# #2; and gamma's significance (fit #1 interaction p-value, HAC) is the headline
# test of "does the beta differ by regime?".
# =============================================================================
df <- df |> mutate(expansion = 1L - recession)

regime_report <- function(rhs, model_label) {
  f_rec <- as.formula(paste("db_ret ~ recession *", rhs))   # base = expansion
  f_exp <- as.formula(paste("db_ret ~ expansion *", rhs))   # base = recession

  m_rec <- lm(f_rec, data = df)   # main effects = EXPANSION betas
  m_exp <- lm(f_exp, data = df)   # main effects = RECESSION betas

  cat("\n##########  ", model_label, "  ##########\n", sep = "")
  cat("\n--- EXPANSION betas + gamma (interaction = recession - expansion) ---\n")
  print(coeftest(m_rec, vcov. = hac_vcov(m_rec)))
  cat("\n--- RECESSION betas (same model, dummy flipped) ---\n")
  print(coeftest(m_exp, vcov. = hac_vcov(m_exp)))

  # Joint Wald test (HAC): are ALL the interaction terms zero together?
  # i.e. is the whole regime split statistically real, not just one factor?
  rhs_terms <- trimws(strsplit(rhs, "\\+")[[1]])
  f_noint <- as.formula(paste("db_ret ~ recession +", paste(rhs_terms, collapse = " + ")))
  m_noint <- lm(f_noint, data = df)
  cat("\n--- Joint test: all interactions = 0? (Newey-West HAC Wald) ---\n")
  print(waldtest(m_noint, m_rec, vcov = hac_vcov, test = "Chisq"))

  s <- summary(m_rec)
  cat(sprintf("Regime-split fit  R-squared: %.4f   Adj R-squared: %.4f   n: %d\n",
              s$r.squared, s$adj.r.squared, nobs(m_rec)))
}

regime_report("(d_sov_spread_bp + d_slope)",     "MODEL A — regime split (spread + slope)")
regime_report("(d_sov_spread_bp + d_long_rate)", "MODEL B — regime split (spread + long rate)")

# =============================================================================
# 3. HOW TO READ THIS
# -----------------------------------------------------------------------------
#   * d_sov_spread_bp beta: return change per +1 bp move in the sovereign
#     spread. Expect NEGATIVE (spread widens -> DB falls), and MORE negative in
#     recession (the default-risk channel, concept C5).
#   * gamma (the `recession:` interaction row): recession beta minus expansion
#     beta. Its HAC p-value is the formal test of the thesis. A significant,
#     more-negative gamma on the spread = "static beta lies; condition on regime".
#   * Small-sample caveat (concept C4): only 3 recession episodes -> wide error
#     bars on the recession/gamma terms. Read them as DIRECTIONAL, not pinpoint;
#     claim only what survives the HAC standard errors.
# =============================================================================
