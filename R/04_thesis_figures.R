# =============================================================================
# 04_thesis_figures.R  —  Macro Shock Analyser
# -----------------------------------------------------------------------------
# PURPOSE
#   The THREE figures that argue the thesis directly ("DB's sensitivity to the
#   sovereign credit spread is steeper in recession than in expansion"). These
#   go FRONT AND CENTRE in the write-up. The actual-vs-predicted scatter is a
#   diagnostic only and belongs in an appendix — it answers "is this a good
#   forecaster?", which is not our question.
#
#   Figure 1 — the betas themselves: expansion vs recession spread beta, each
#              with a 95% HAC confidence interval. One look = the thesis.
#   Figure 2 — the betas turned into money: predicted DB monthly move for the
#              SAME spread shock (+25bp, +100bp) under each regime.
#   Figure 3 — the raw evidence: spread change vs DB return, split by regime,
#              each panel with its own fitted line (recession line is steeper).
#
# INPUT   data/processed/monthly_dataset.csv   (built by 01_load_data.R)
# OUTPUT  output/fig1_betas.png, fig2_shock.png, fig3_regime_scatter.png
# RUN     working directory = project root, then source this file.
# NOTE    standard errors are Newey-West HAC, the same honest basis as 02_models.R.
# =============================================================================

library(tidyverse)   # ggplot2 + dplyr
library(sandwich)    # NeweyWest() HAC covariance
library(lmtest)      # coefci(): confidence intervals using the HAC covariance
library(broom)       # tidy(): turn model output into a clean data frame

df <- readr::read_csv("data/processed/monthly_dataset.csv", show_col_types = FALSE)
df <- df |> mutate(expansion = 1L - recession)   # the flipped dummy (see 02_models.R)

# Same HAC covariance helper used everywhere in the project.
hac_vcov <- function(m) NeweyWest(m, prewhite = FALSE, adjust = TRUE)

# -----------------------------------------------------------------------------
# Re-fit Model A regime-split TWICE, dummy flipped, exactly like 02_models.R:
#   * base = expansion  -> the main-effect betas ARE the EXPANSION betas
#   * base = recession  -> the main-effect betas ARE the RECESSION betas
# We pull the SPREAD beta + its 95% HAC confidence interval from each.
# -----------------------------------------------------------------------------
m_exp_base <- lm(db_ret ~ recession * (d_sov_spread_bp + d_slope), data = df)
m_rec_base <- lm(db_ret ~ expansion * (d_sov_spread_bp + d_slope), data = df)

# coefci() gives the [lower, upper] 95% interval using OUR HAC covariance.
ci_exp <- coefci(m_exp_base, vcov. = hac_vcov(m_exp_base))["d_sov_spread_bp", ]
ci_rec <- coefci(m_rec_base, vcov. = hac_vcov(m_rec_base))["d_sov_spread_bp", ]

betas <- tibble(
  regime = factor(c("Expansion", "Recession"), levels = c("Expansion", "Recession")),
  beta   = c(coef(m_exp_base)["d_sov_spread_bp"], coef(m_rec_base)["d_sov_spread_bp"]),
  lo     = c(ci_exp[1], ci_rec[1]),
  hi     = c(ci_exp[2], ci_rec[2])
)

# =============================================================================
# FIGURE 1 — expansion vs recession spread beta, with 95% HAC CIs
# -----------------------------------------------------------------------------
# Read it: each dot is the beta (return per +1bp spread move). The whisker is
# the 95% range we're confident the true beta lives in. The recession dot sits
# LOWER (more negative) = bigger hit per basis point. The whiskers overlap a
# little, but the formal interaction test (gamma, p=0.038 in 02_models.R) says
# the GAP is significant — overlap of two separate CIs is a weaker check than
# testing the difference directly, which we already did.
# =============================================================================
fig1 <- ggplot(betas, aes(regime, beta, colour = regime)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.8) +
  geom_point(size = 4) +
  scale_colour_manual(values = c(Expansion = "#378ADD", Recession = "#D85A30")) +
  labs(title = "Spread beta steepens in recession",
       subtitle = "DB monthly return per +1bp move in the sovereign spread (95% Newey-West CI)",
       x = NULL, y = "Beta on d_sov_spread_bp") +
  theme_minimal(base_size = 13) + theme(legend.position = "none")

ggsave("output/fig1_betas.png", fig1, width = 6, height = 4.5, dpi = 150)

# =============================================================================
# FIGURE 2 — same shock, two regimes: predicted DB move
# -----------------------------------------------------------------------------
# Take each regime's spread beta and multiply by a shock size. +25bp is a
# realistic monthly stress; +100bp is a severe, clearly-hypothetical stress
# (and an EXTRAPOLATION beyond most of the data, so labelled as such).
# =============================================================================
shock_grid <- expand_grid(
  regime = factor(c("Expansion", "Recession"), levels = c("Expansion", "Recession")),
  shock_bp = c(25, 100)
) |>
  left_join(betas |> select(regime, beta), by = "regime") |>
  mutate(pred_pct = 100 * beta * shock_bp,                  # predicted DB move, %
         shock_lab = factor(paste0("+", shock_bp, "bp")))

fig2 <- ggplot(shock_grid, aes(shock_lab, pred_pct, fill = regime)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_text(aes(label = sprintf("%.1f%%", pred_pct)),
            position = position_dodge(width = 0.7), vjust = 1.2, size = 3.5) +
  scale_fill_manual(values = c(Expansion = "#378ADD", Recession = "#D85A30")) +
  labs(title = "Same spread shock hits harder in recession",
       subtitle = "Predicted DB monthly return; +100bp is a hypothetical stress (extrapolation)",
       x = "Sovereign-spread shock", y = "Predicted DB return (%)", fill = NULL) +
  theme_minimal(base_size = 13)

ggsave("output/fig2_shock.png", fig2, width = 6.5, height = 4.5, dpi = 150)

# =============================================================================
# FIGURE 3 — the raw evidence: spread change vs DB return, split by regime
# -----------------------------------------------------------------------------
# geom_smooth(method = "lm") fits a SIMPLE one-variable line inside each panel,
# so these slopes (~ -0.0028 expansion, ~ -0.0046 recession) are slightly
# different from the headline betas above (which control for the slope factor).
# Same story, teaching version. The recession panel's line is visibly steeper.
# =============================================================================
plot_df <- df |>
  filter(!is.na(db_ret), !is.na(d_sov_spread_bp)) |>
  mutate(regime = factor(if_else(recession == 1, "Recession", "Expansion"),
                         levels = c("Expansion", "Recession")))

fig3 <- ggplot(plot_df, aes(d_sov_spread_bp, db_ret, colour = regime)) +
  geom_hline(yintercept = 0, colour = "grey85") +
  geom_vline(xintercept = 0, colour = "grey85") +
  geom_point(alpha = 0.5, size = 1.6) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1.1) +
  scale_colour_manual(values = c(Expansion = "#378ADD", Recession = "#D85A30")) +
  facet_wrap(~ regime) +
  labs(title = "Spread widens, DB falls — and the slope is steeper in recession",
       subtitle = "Each dot = one month; line = fitted regression within the regime",
       x = "Monthly change in sovereign spread (bp)", y = "DB monthly return") +
  theme_minimal(base_size = 13) + theme(legend.position = "none")

ggsave("output/fig3_regime_scatter.png", fig3, width = 8, height = 4.5, dpi = 150)

# =============================================================================
message("Saved: output/fig1_betas.png, output/fig2_shock.png, output/fig3_regime_scatter.png")
message("Front-and-centre figures done. Actual-vs-predicted scatter stays a diagnostic (appendix).")
