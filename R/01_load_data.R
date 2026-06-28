# =============================================================================
# 01_load_data.R  —  Macro Shock Analyser
# -----------------------------------------------------------------------------
# PURPOSE
#   Turn the 5 raw files in data/raw/ into ONE clean monthly dataset that the
#   regression scripts can use. Output: data/processed/monthly_dataset.csv
#
# WHAT GOES IN  (all logged in Sources.md)
#   ecb_aaa_10y.csv        AAA (German) 10Y spot yield, daily, % p.a.
#   ecb_aaa_2y.csv         AAA (German) 2Y  spot yield, daily, % p.a.
#   ecb_allissuer_10y.csv  All-euro-area 10Y spot yield, daily, % p.a.
#   ecb_slope_10y_2y.csv   ECB's pre-built 10Y-2Y slope (cross-check only)
#   db_price.csv           Deutsche Bank monthly price, EUR (use AdjClose)
#
# WHAT COMES OUT  (one row per month)
#   date              first-of-month label for the month
#   recession         1 if the month is in a CEPR-EABCN euro-area recession, else 0
#   db_adjclose       month-end adjusted close (dividends + splits handled)
#   db_ret            DB monthly simple return = AdjClose_t / AdjClose_{t-1} - 1
#   long_rate         AAA 10Y yield, month-end level (% p.a.)        [Model B factor in LEVEL]
#   slope             AAA 10Y - AAA 2Y, month-end (% p.a. / "pp")    [Model A factor in LEVEL]
#   sov_spread_bp     (all-issuer 10Y - AAA 10Y) in basis points    [credit factor in LEVEL]
#   d_long_rate       monthly change in long_rate     (pp)          <-- Model B regressor
#   d_slope           monthly change in slope         (pp)          <-- Model A regressor
#   d_sov_spread_bp   monthly change in sov_spread_bp (bp)          <-- credit regressor (both models)
#
# WHY "changes" not "levels" for the regressors:
#   Yield levels wander (non-stationary). Regressing returns on levels gives
#   spurious results. First differences (this month minus last month) are
#   stationary, so the betas are trustworthy. (Concept C1/C2.)
#
# HOW TO RUN
#   Set the working directory to the PROJECT ROOT (the folder that contains
#   data/ and R/), then run this file. In RStudio: Session > Set Working
#   Directory > To Project Directory. From a terminal: Rscript R/01_load_data.R
# =============================================================================

library(tidyverse)   # readr + dplyr + tidyr + ggplot2 ...
library(lubridate)   # floor_date(), day(), ymd()

# ---- paths (relative to project root) ---------------------------------------
raw_dir  <- "data/raw"
proc_dir <- "data/processed"
if (!dir.exists(proc_dir)) dir.create(proc_dir, recursive = TRUE)

# =============================================================================
# 1. ECB daily yields -> monthly (month-end value)
# -----------------------------------------------------------------------------
# Each ECB CSV looks like:
#   "DATE","TIME PERIOD","<long series name> (SERIES_ID)"
#   "2004-09-06","06 Sep 2004","4.209220"
# We only need column 1 (the date) and column 3 (the yield).
#
# We aggregate to MONTHLY by taking the LAST available business day in each
# calendar month ("month-end"). Why month-end and not the monthly average?
# Because the DB price is a month-end close, so a month-end yield lines up with
# it: both describe the state of the world at the end of that month. That makes
# "DB return over month t" and "change in the factor over month t" cover the
# exact same window.
# -----------------------------------------------------------------------------
load_ecb_monthly <- function(file, value_name) {
  raw <- readr::read_csv(file.path(raw_dir, file), show_col_types = FALSE)
  # the CSV has 3 cols: DATE, TIME PERIOD (text), <long series name>.
  # rename col 1 and col 3 to fixed names so we don't depend on the long name.
  names(raw)[1] <- "d_raw"
  names(raw)[3] <- "val_raw"
  raw |>
    transmute(
      d     = as.Date(d_raw),
      value = as.numeric(val_raw)
    ) |>
    filter(!is.na(d), !is.na(value)) |>
    mutate(date = floor_date(d, "month")) |>     # tag each day with its month
    group_by(date) |>
    slice_max(d, n = 1, with_ties = FALSE) |>     # keep the last day of the month
    ungroup() |>
    transmute(date, !!value_name := value)
}

aaa_10y   <- load_ecb_monthly("ecb_aaa_10y.csv",       "aaa_10y")
aaa_2y    <- load_ecb_monthly("ecb_aaa_2y.csv",        "aaa_2y")
all_10y   <- load_ecb_monthly("ecb_allissuer_10y.csv", "all_10y")
slope_chk <- load_ecb_monthly("ecb_slope_10y_2y.csv",  "slope_ecb")  # cross-check only

# =============================================================================
# 2. Deutsche Bank price -> monthly return
# -----------------------------------------------------------------------------
# db_price.csv is already monthly (one row per month, dated first-of-month),
# EXCEPT the very last row "2026-06-26" which is a partial, month-to-date row
# sitting alongside the full "2026-06-01" June row. We drop the partial by
# keeping only first-of-month rows.
#
# We use AdjClose (adjusted close), NOT Close: AdjClose adds dividends back and
# corrects for splits, so the return is a true total return with no fake jumps.
# -----------------------------------------------------------------------------
db <- readr::read_csv(file.path(raw_dir, "db_price.csv"), show_col_types = FALSE) |>
  mutate(Date = as.Date(Date)) |>
  filter(day(Date) == 1) |>                 # drop the partial 2026-06-26 row
  transmute(date = floor_date(Date, "month"),
            db_adjclose = as.numeric(AdjClose)) |>
  arrange(date)

# =============================================================================
# 3. Join everything on the month, then build factors + changes
# -----------------------------------------------------------------------------
# inner_join keeps only months present in BOTH the ECB series and DB. Since the
# ECB curve starts Sept 2004, this automatically trims DB (which goes back to
# 1996) to the >= Sept 2004 window. No manual date filter needed.
# -----------------------------------------------------------------------------
monthly <- aaa_10y |>
  inner_join(aaa_2y,    by = "date") |>
  inner_join(all_10y,   by = "date") |>
  inner_join(slope_chk, by = "date") |>
  inner_join(db,        by = "date") |>
  arrange(date) |>
  mutate(
    # ---- factor LEVELS ----
    long_rate     = aaa_10y,                       # Model B factor (in level)
    slope         = aaa_10y - aaa_2y,              # Model A factor (in level), pp
    sov_spread_bp = (all_10y - aaa_10y) * 100,     # credit factor, basis points
    # ---- DB monthly return from AdjClose ----
    db_ret        = db_adjclose / lag(db_adjclose) - 1,
    # ---- factor CHANGES (the actual regressors) ----
    d_long_rate     = long_rate     - lag(long_rate),       # pp
    d_slope         = slope         - lag(slope),           # pp
    d_sov_spread_bp = sov_spread_bp - lag(sov_spread_bp)    # bp
  )

# =============================================================================
# 4. Recession dummy  (CEPR-EABCN euro-area chronology)
# -----------------------------------------------------------------------------
# Source: eabcn.org/dbc/peaksandtroughs/chronology-euro-area-business-cycles
# Committee convention: "if a peak occurs in quarter P and a trough in quarter
# T, the recession starts at P+1 and runs through T." So recession months are
# the months from the quarter AFTER the peak through the trough quarter:
#
#   Peak 2008 Q1 -> Trough 2009 Q2   =>  2008-04 .. 2009-06
#   Peak 2011 Q3 -> Trough 2013 Q1   =>  2011-10 .. 2013-03
#   Peak 2019 Q4 -> Trough 2020 Q2   =>  2020-01 .. 2020-06
#
# Caveat (logged in Decisions.md D7): these are the committee's FINAL revised
# dates, announced with a lag. We are NOT reconstructing what was known in real
# time. The dummy answers "with hindsight, was month X a recession", which is
# the right question for measuring regime-conditional betas.
# -----------------------------------------------------------------------------
in_range <- function(d, start, end) d >= ymd(start) & d <= ymd(end)

monthly <- monthly |>
  mutate(
    recession = as.integer(
      in_range(date, "2008-04-01", "2009-06-01") |
      in_range(date, "2011-10-01", "2013-03-01") |
      in_range(date, "2020-01-01", "2020-06-01")
    )
  )

# =============================================================================
# 5. Final tidy + write
# -----------------------------------------------------------------------------
# Drop the first row: differencing/lagging makes db_ret and the d_* columns NA
# in the first month (no prior month to compare against).
# -----------------------------------------------------------------------------
out <- monthly |>
  filter(!is.na(db_ret), !is.na(d_long_rate)) |>
  select(date, recession,
         db_adjclose, db_ret,
         long_rate, slope, sov_spread_bp,
         d_long_rate, d_slope, d_sov_spread_bp)

readr::write_csv(out, file.path(proc_dir, "monthly_dataset.csv"))

# =============================================================================
# 6. Verification printout  (eyeball this every run)
# =============================================================================
cat("\n========== 01_load_data.R verification ==========\n")
cat("Rows written      :", nrow(out), "\n")
cat("Date range        :", format(min(out$date)), "->", format(max(out$date)), "\n")
cat("Recession months  :", sum(out$recession), "of", nrow(out), "\n")

cat("\nRecession months per episode:\n")
out |>
  filter(recession == 1) |>
  mutate(episode = case_when(
    date <= ymd("2009-06-01") ~ "2008-09 GFC",
    date <= ymd("2013-03-01") ~ "2011-13 sovereign",
    TRUE                      ~ "2020 COVID"
  )) |>
  count(episode) |>
  print()

# Slope cross-check: our computed slope should equal ECB's pre-built slope.
slope_gap <- max(abs(monthly$slope - monthly$slope_ecb), na.rm = TRUE)
cat("\nSlope cross-check (max |computed - ECB pre-built|):", round(slope_gap, 6),
    if (slope_gap < 1e-4) "  OK\n" else "  <-- CHECK THIS\n")

# NA check on the columns the models will actually use
key <- c("db_ret","d_long_rate","d_slope","d_sov_spread_bp","recession")
cat("\nNA count in key model columns:\n")
print(colSums(is.na(out[key])))

cat("\nFirst 3 rows:\n");  print(head(out, 3))
cat("\nLast 3 rows:\n");   print(tail(out, 3))
cat("\nSummary of regressors + return:\n")
print(summary(out[c("db_ret","d_long_rate","d_slope","d_sov_spread_bp")]))
cat("=================================================\n")
