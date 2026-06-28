# 00_install_packages.R
# Run this ONCE to install everything the Macro Shock Analyser build needs.
# In VS Code: open this file, then run it (Ctrl/Cmd+Shift+S "source"), or run
# line-by-line. Re-running is safe — it skips packages you already have.
#
# Each package is here for a specific reason in this project. No kitchen sink.

# Use a fixed download mirror so this runs without asking you to pick one.
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Packages this project depends on, and WHY each one is here:
required <- c(
  "tidyverse",   # data wrangling + ggplot2 charts (dplyr, tidyr, readr, ggplot2)
  "tidyquant",   # pull Deutsche Bank share price from Yahoo Finance, tidy-friendly
  "fredr",       # pull European macro series mirrored on FRED (rates, credit spread)
  "lubridate",   # clean handling of monthly dates (part of tidyverse, listed for clarity)
  "sandwich",    # HAC / Newey-West standard errors (fixes autocorrelated monthly errors)
  "lmtest",      # coeftest(): apply the HAC errors to the regression and re-test betas
  "tseries",     # ADF + KPSS stationarity tests (Stage 4: prove differencing was right)
  "broom",       # tidy(): turn messy lm() output into a clean coef/SE/t/p table
  "rmarkdown",   # knit the final report at Stage 6 (build stays in plain .R until then)
  "knitr"        # engine rmarkdown uses to run code chunks
)

# Install only the ones that are missing.
to_install <- required[!(required %in% installed.packages()[, "Package"])]
if (length(to_install) > 0) {
  message("Installing: ", paste(to_install, collapse = ", "))
  install.packages(to_install)
} else {
  message("All required packages already installed.")
}

# Sanity check: load them all. If this block runs with no error, you're ready.
invisible(lapply(required, library, character.only = TRUE))
message("R version: ", R.version.string)
message("All packages loaded OK. Stage 1 environment is ready.")

# NOTE on fredr: it needs a free FRED API key (we set that up at Stage 2,
# the data-pull step — not now). Installing the package today is enough.
