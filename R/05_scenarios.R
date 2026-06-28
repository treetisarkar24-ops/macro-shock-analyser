# =============================================================================
# 05_scenarios.R  —  Macro Shock Analyser
# -----------------------------------------------------------------------------
# PURPOSE
#   Translate the regime betas into something an interviewer feels in their gut:
#   "if the sovereign spread jumps by X basis points, how much is DB predicted
#   to move — and how much WORSE is that in a recession?"
#
#   The whole credibility of this stage rests on WHERE the shock sizes come
#   from. We do NOT invent round numbers. We measure the actual monthly
#   spread-change distribution and read the shock sizes straight off it:
#
#     * TYPICAL  (+10bp) ~ 1 standard deviation of monthly moves (~9.4bp).
#                         The SD is a fair ruler for an ordinary month.
#     * ADVERSE  (+20bp) ~ the 95th percentile of the ABSOLUTE monthly move
#                         (~20.8bp). Only ~5% of months ever moved more.
#     * SEVERE   (+45bp) = the single worst month in 21 years (45.5bp).
#                         Stronger than a made-up stress: it actually happened.
#
#   WHY READ PERCENTILE + MAX, NOT JUST "2-SIGMA / 3-SIGMA"?
#     Because the distribution is NOT normal. It is fat-tailed (excess
#     kurtosis ~4.7; a bell curve is 0) and right-skewed (~+0.87: spreads blow
#     out faster than they tighten). On a fat-tailed series the bell-curve
#     shortcuts ("2 SD = 95%") understate the tails. The 95th percentile and the
#     historical max are read directly off the sorted data, so they are honest
#     regardless of shape. We only lean on SD for the mild "typical" case.
#
#   WHY HOLD THE SHOCK SIZE FIXED ACROSS REGIMES?
#     The thesis is "SAME shock, BIGGER hit in recession." For that claim to be
#     clean, the only thing allowed to differ between the two bars is the BETA.
#     (It is also true that recession MONTHS have ~2x bigger moves — SD ~15bp vs
#     ~8bp — but that is a separate fact; baking it into the shock size would
#     conflate "shocks are bigger" with "DB is more sensitive". We keep them
#     apart: shock fixed here, the bigger-moves fact noted in the write-up.)
#
# INPUT   data/processed/monthly_dataset.csv
# OUTPUT  output/fig5_scenarios.png  + a printed scenario table
# RUN     working directory = project root, then source this file.
# NOTE    standard errors are Newey-West HAC, same honest basis as everywhere.
# =============================================================================

library(tidyverse)   # dplyr + ggplot2
library(sandwich)    # NeweyWest() HAC covariance
library(lmtest)      # coefci(): confidence intervals on the HAC basis

df <- readr::read_csv("data/processed/monthly_dataset.csv", show_col_types = FALSE)
df <- df |> mutate(expansion = 1L - recession)

# =============================================================================
# 1. DERIVE the shock sizes from the data (do not hard-code the reasoning away)
# -----------------------------------------------------------------------------
# We print these so the choice is reproducible and defensible on the spot.
# =============================================================================
x <- df$d_sov_spread_bp[!is.na(df$d_sov_spread_bp)]   # monthly spread change, bp

sd_move  <- sd(x)                    # ~9.4  -> typical month (1 SD)
p95_move <- quantile(abs(x), 0.95)   # ~20.8 -> adverse month (95th-pct move)
max_move <- max(abs(x))              # ~45.5 -> severe (worst month on record)

cat("\n=================== SPREAD-CHANGE DISTRIBUTION ===================\n")
cat(sprintf("monthly moves: mean %.2f  sd %.2f  min %.2f  max %.2f (bp)\n",
            mean(x), sd(x), min(x), max(x)))
cat(sprintf("95th-pct |move| %.2f bp   worst |move| %.2f bp\n", p95_move, max_move))

# Rounded, data-anchored shock sizes used for the scenarios.
shocks <- tibble(
  scenario = factor(c("Typical (+10bp)", "Adverse (+20bp)", "Severe (+45bp)"),
                    levels = c("Typical (+10bp)", "Adverse (+20bp)", "Severe (+45bp)")),
  shock_bp = c(10, 20, 45)
)

# =============================================================================
# 2. GET the regime spread betas + 95% HAC confidence intervals
# -----------------------------------------------------------------------------
# Same dummy-flip trick as 02_models.R: fit Model A regime-split twice so each
# regime's spread beta prints with its own HAC error bar.
# =============================================================================
hac_vcov <- function(m) NeweyWest(m, prewhite = FALSE, adjust = TRUE)

m_exp_base <- lm(db_ret ~ recession * (d_sov_spread_bp + d_slope), data = df)  # base = expansion
m_rec_base <- lm(db_ret ~ expansion * (d_sov_spread_bp + d_slope), data = df)  # base = recession

ci_exp <- coefci(m_exp_base, vcov. = hac_vcov(m_exp_base))["d_sov_spread_bp", ]
ci_rec <- coefci(m_rec_base, vcov. = hac_vcov(m_rec_base))["d_sov_spread_bp", ]

betas <- tibble(
  regime = factor(c("Expansion", "Recession"), levels = c("Expansion", "Recession")),
  beta   = c(coef(m_exp_base)["d_sov_spread_bp"], coef(m_rec_base)["d_sov_spread_bp"]),
  lo     = c(ci_exp[1], ci_rec[1]),
  hi     = c(ci_exp[2], ci_rec[2])
)

# =============================================================================
# 3. BUILD the scenario table: predicted DB move = beta * shock
# -----------------------------------------------------------------------------
# Because the prediction is just (beta * shock), the confidence interval scales
# the same way: multiply the beta's CI endpoints by the shock size. Reported in
# % (the betas are per-bp return changes, so *100 turns them into percent).
# =============================================================================
scen <- tidyr::crossing(betas, shocks) |>
  mutate(
    pred_pct = 100 * beta * shock_bp,
    lo_pct   = 100 * lo   * shock_bp,
    hi_pct   = 100 * hi   * shock_bp
  )

cat("\n=================== SCENARIO RESULTS (predicted DB monthly return) ===================\n")
print(scen |>
        transmute(scenario, regime,
                  predicted = sprintf("%.1f%%", pred_pct),
                  ci_95 = sprintf("[%.1f%%, %.1f%%]", hi_pct, lo_pct)),  # hi/lo: more/less negative
      n = 100)

# =============================================================================
# 4. FIGURE — predicted DB move per scenario, expansion vs recession, with CIs
# -----------------------------------------------------------------------------
# Read it: within each shock size, the recession bar drops further than the
# expansion bar — same input, bigger hit. The whiskers (95% HAC CI) are wide,
# especially in recession (only 3 episodes), so read magnitudes as DIRECTIONAL.
# =============================================================================
fig5 <- ggplot(scen, aes(scenario, pred_pct, fill = regime)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_col(position = position_dodge(width = 0.75), width = 0.65) +
  geom_errorbar(aes(ymin = lo_pct, ymax = hi_pct),
                position = position_dodge(width = 0.75), width = 0.18, linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.1f%%", pred_pct)),
            position = position_dodge(width = 0.75), vjust = 1.25, size = 3.2) +
  scale_fill_manual(values = c(Expansion = "#378ADD", Recession = "#D85A30")) +
  labs(title = "Same spread shock, bigger hit in recession",
       subtitle = "Predicted DB monthly return; shock sizes from the actual move distribution (1 SD / 95th pct / worst month). 95% Newey-West CI.",
       x = "Sovereign-spread shock scenario", y = "Predicted DB return (%)", fill = NULL) +
  theme_minimal(base_size = 13)

ggsave("output/fig5_scenarios.png", fig5, width = 8, height = 5, dpi = 150)

message("Saved: output/fig5_scenarios.png")
message("Shock sizes derived from the data (1 SD / 95th pct / historical max), not invented.")
