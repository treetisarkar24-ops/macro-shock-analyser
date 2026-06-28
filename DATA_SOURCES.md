# Data sources & provenance

Every series used in the study is logged here with its source, identifier,
frequency, date range, and vintage (when it was pulled). Macro data is committed
as **frozen CSVs** rather than pulled live, so the analysis reproduces exactly
even though macro series get revised over time.

_Data pulled 2026-06-26; macro series through 24 Jun 2026, price through Jun 2026._

---

## Source decisions

- **All macro series come from the ECB Data Portal** as manually downloaded CSVs.
  The euro-area yield curve is published free, with no API key and full history,
  and is the primary euro-area source. (An earlier plan to mirror ICE BofA euro
  spreads via FRED was dropped after FRED truncated all ICE BofA OAS spread series
  to a rolling ~3-year window as of April 2026 — no full history over the sample.)
- **The credit factor is the euro sovereign spread** — all-issuer euro 10Y minus
  AAA (German) 10Y, in basis points — because no free, maintained euro *corporate*
  spread survived the FRED truncation. The sovereign spread keeps a clean
  basis-point interpretation and has a named bank-specific mechanism (the
  bank–sovereign doom loop). See `METHODOLOGY.docx` for the full rationale.
- **The DB share price comes from Yahoo Finance** (split- and dividend-adjusted),
  using the **Adjusted Close** so returns include dividends and splits.

---

## Committed series

| Series | Source | ID | Frequency | Date range | File | Used for |
|---|---|---|---|---|---|---|
| Euro-area AAA-govt 10Y spot yield | ECB Data Portal (yield curve) | `YC.B.U2.EUR.4F.G_N_A.SV_C_YM.SR_10Y` | daily, % p.a. | 2004-09-06 → 2026-06-24 | `data/raw/ecb_aaa_10y.csv` | long rate (Model B) + AAA leg of sovereign spread |
| Euro-area AAA-govt 2Y spot yield | ECB Data Portal (yield curve) | `YC.B.U2.EUR.4F.G_N_A.SV_C_YM.SR_2Y` | daily, % p.a. | 2004-09-06 → 2026-06-24 | `data/raw/ecb_aaa_2y.csv` | slope = 10Y − 2Y (Model A) |
| Euro-area ALL-issuer 10Y spot yield | ECB Data Portal (yield curve) | `YC.B.U2.EUR.4F.G_N_C.SV_C_YM.SR_10Y` | daily, % p.a. | 2004-09-06 → 2026-06-24 | `data/raw/ecb_allissuer_10y.csv` | all-issuer leg of sovereign spread |
| Euro-area pre-built slope 10Y−2Y | ECB Data Portal (yield curve) | `YC.B.U2.EUR.4F.G_N_A.SV_C_YM.SRS_10Y_2Y` | daily, % p.a. | 2004-09-06 → 2026-06-24 | (cross-check) | slope cross-check (matches computed 10Y−2Y exactly) |
| **Sovereign spread (derived)** | computed | all-issuer 10Y − AAA 10Y, bp | monthly | from the two 10Y series above | built in `01_load_data.R` | **credit factor, both models** |
| Deutsche Bank share price | Yahoo Finance (Xetra), EUR | `DBK.DE` | monthly | 1996-11 → 2026-06 | `data/raw/db_price.csv` | DB monthly return (dependent variable) — uses Adjusted Close |
| Euro-area recession dummy | CEPR-EABCN chronology | committee peak/trough dates → monthly 0/1 | monthly | — | built in `01_load_data.R` | regime split |

**Verification (2026-06-26):** all four ECB CSVs confirmed on download — correct
series ID in each header, 5,572 daily observations each over an identical
2004-09-06 → 2026-06-24 span. Cross-checks passed: AAA 10Y − AAA 2Y equals the
pre-built slope value exactly on the first date; the all-issuer 10Y exceeds the
AAA 10Y throughout (a positive sovereign spread, as expected). Files are left raw
as downloaded.

**DB price handling:** the price series is monthly Adjusted Close. The partial
final month-to-date row is dropped at load so only complete months enter the
model, and the series is trimmed to ≥ Sept 2004 to align with the ECB series.

---

## Considered and rejected

| Series | Source | Why not used |
|---|---|---|
| ICE BofA Euro High Yield OAS | FRED (ICE BofA mirror) | FRED truncated all ICE BofA OAS spreads to a rolling ~3-yr window (Apr 2026) → no full history over the sample. Prompted the move to ECB + a sovereign spread. |
| CISS systemic-stress index | ECB Data Portal (`CISS.D.U2.Z0Z.4F.EC.SS_CIN.IDX`) | A 0–1 index, not a basis-point price, so it breaks the "spread +Xbp" scenario framing and blends non-credit stress. Kept only as optional robustness. |
