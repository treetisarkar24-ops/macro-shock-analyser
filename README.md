# Macro Shock Analyser

### 📊 [**View the live report →**](https://treetisarkar24-ops.github.io/macro-shock-analyser/report.html)

_The full styled analysis, rendered as a web page._

---

**Does Deutsche Bank's macro beta change with the economic regime?**

A small, defensible econometric study, built in R, of how Deutsche Bank's monthly
equity return responds to euro-area macro shocks — and whether that sensitivity is
different in recession than in expansion.

> **Thesis: static beta lies; condition on the regime.**
> A single beta estimated over two decades is an average across very different
> worlds, and that average is misleading. Estimated *inside* each regime, DB's
> sensitivity to the euro sovereign credit spread is materially steeper in
> recession than in expansion — roughly twice as steep.

This is an **explanatory** study of *sensitivity*, not a forecasting model. The
mechanism is named before estimation, so it is a hypothesis test rather than a
data-mine: in a recession, defaults rise and investors demand more compensation
for credit risk, so sovereign spreads widen; Deutsche Bank — a lender holding
euro-area government debt and implicitly backstopped by its sovereign (the
bank–sovereign "doom loop") — is mechanically exposed to exactly that repricing,
and leverage amplifies it. The same spread move in calm times carries no such
threat, so the beta should bite harder in recession.

---

## Headline result

For Deutsche Bank over **~Sept 2004 – Jun 2026** (261 monthly observations):

- The spread beta is about **2× steeper in recession** than in expansion.
- The difference (the recession × spread interaction, γ) is **significant under
  Newey-West HAC standard errors**, p < 0.05 — the direct test of "are the two
  betas different."
- A joint Wald test that *all* recession interactions are zero **corroborates it
  at the 5% borderline** (significant at 10%).
- The robustness model (long rate in place of the slope) **preserves the
  direction but not the joint significance** — reported openly, not hidden.

The conclusion stands behind the headline model with the robustness caveat
attached, and treats the recession beta as **directional** given only three
recession episodes in the sample.

---

## What this project is — and is not

- **Is:** one asset, deep; a lean multi-factor regression with a real thesis;
  a formal regime split with a significance test; every choice documented and
  every series traced to source.
- **Is not:** a price forecaster; a multi-asset portfolio risk tool; a
  kitchen-sink factor model; a black box; or built on any invented numbers.

---

## Data

| | |
|---|---|
| **Asset** | Deutsche Bank (DBK.DE, Xetra, EUR), monthly total return |
| **Sample** | ~Sept 2004 → Jun 2026, monthly, 261 observations |
| **Recessions** | 3 episodes (GFC 2008–09, euro sovereign 2011–13, COVID 2020), 39 months |
| **Macro source** | ECB Data Portal (euro-area yield curve), manual frozen CSVs |
| **Price source** | Yahoo Finance (split- and dividend-adjusted) |
| **Regime dating** | CEPR-EABCN euro-area business-cycle committee |

Factors are built from the ECB yield curve and **first-differenced** (monthly
*changes*, not levels):

- **`d_sov_spread_bp`** — change in the euro sovereign credit spread
  (all-issuer euro 10Y − AAA 10Y, in bp). The credit factor and heart of the thesis.
- **`d_slope`** — change in the yield-curve slope (10Y − 2Y). *Model A.*
- **`d_long_rate`** — change in the 10Y rate. *Model B (robustness).*

Full provenance for every series — source, ID, frequency, date range, vintage —
is in [`DATA_SOURCES.md`](DATA_SOURCES.md).

---

## Method

Ordinary least squares; the point of view is the **regime split**.

**Full sample (the average everyone quotes):**

```
r_DB = α + β1·Δspread + β2·Δslope + ε
```

**Regime split (the thesis):** interact every factor with a recession dummy. The
interaction coefficient **γ = (recession beta − expansion beta)** *is* the thesis
in one number; a significantly negative γ means the spread beta is steeper in
recession.

```
r_DB = α + β·Δspread + γ·(recession × Δspread) + (same for slope) + ε
```

Two design points that keep this honest:

- **Two lean models, not one kitchen sink.** Model A pairs the spread with the
  yield-curve slope (the bank-specific lending-margin channel); Model B swaps the
  slope for the long rate. Slope and rate level overlap, so splitting them into
  two models avoids multicollinearity *and* turns "which rate measure?" into a
  robustness question. The broad market return is deliberately excluded so the
  study measures **total** macro sensitivity, not the market-adjusted residual.
- **Newey-West HAC standard errors throughout** — every p-value and confidence
  interval is robust to heteroskedasticity and serial correlation, on the same
  basis in the scripts and the report.

The full reasoning behind each choice (D1–D11), the econometric defensibility
(stationarity, HAC, small-sample, look-ahead, R²), the scenario design, and the
stated limitations are in **[`METHODOLOGY.docx`](METHODOLOGY.docx)**.

---

## Repository structure

```
macro-shock-analyser/
├── README.md              ← you are here
├── METHODOLOGY.docx       ← full methodology & defensibility (D1–D11, caveats)
├── DATA_SOURCES.md        ← data provenance ledger (source, ID, vintage)
├── report.Rmd             ← the analysis as R Markdown (recomputes everything live)
├── report.html            ← knitted report (open this to read the analysis)
├── R/
│   ├── 00_install_packages.R   environment
│   ├── 01_load_data.R          raw ECB + Yahoo CSVs → processed monthly dataset
│   ├── 02_models.R             full-sample + regime-split models (HAC)
│   ├── 03_defensibility.R      ADF / KPSS stationarity tests
│   ├── 04_thesis_figures.R     the three thesis figures (PNG)
│   └── 05_scenarios.R          data-driven shock scenarios
├── scripts/
│   └── get_stock_data.py       helper used to assemble the DB price series
├── data/
│   ├── raw/                    ECB yield-curve CSVs + DB price CSV (frozen vintages)
│   └── processed/
│       └── monthly_dataset.csv the single dataset every script and the report use
└── output/                     generated figures (created on run)
```

---

## Reproduce

Requires R (≥ 4.x). From the repository root:

```r
# 1. Install dependencies (tidyverse, sandwich, lmtest, broom, tseries, ...)
source("R/00_install_packages.R")

# 2. Build the processed dataset from the frozen raw CSVs
source("R/01_load_data.R")

# 3. Models, diagnostics, figures, scenarios
source("R/02_models.R")
source("R/03_defensibility.R")
source("R/04_thesis_figures.R")
source("R/05_scenarios.R")

# 4. Or knit the whole analysis to HTML (recomputes every number live)
rmarkdown::render("report.Rmd")
```

Macro data is committed as **frozen CSVs** rather than pulled live: for an
explanatory study you want a fixed vintage so the analysis reproduces exactly,
even though macro series get revised. Every file is logged in `DATA_SOURCES.md`
with its pull date.

---

## Limitations (stated up front)

- **Only three recession episodes** — the binding constraint is the number of
  distinct episodes, not the row count, so the recession and γ betas carry wide
  error bars and are read as directional.
- **Look-ahead in the regime dummy** — CEPR dates are revised and published with
  a lag, so the dummy is correct for an explanatory question but is not a
  real-time trading signal.
- **Sovereign, not corporate, spread** — used as the best free, full-history
  proxy for euro credit-risk conditions; the doom-loop channel is exactly why it
  is a defensible proxy for a bank.
- **Low R²** — expected for single-stock monthly returns; this is a sensitivity
  model, not a forecaster.

See `METHODOLOGY.docx` for how each of these is handled.
