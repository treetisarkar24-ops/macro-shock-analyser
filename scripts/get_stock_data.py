"""
get_stock_data.py — reusable stock price downloader (yfinance)
================================================================

WHAT THIS DOES
    Downloads price history (Open, High, Low, Close, Adj Close, Volume)
    for ONE company from Yahoo Finance and saves it as a CSV.

    To reuse for a different company, change TWO things below:
        1. TICKER   — the Yahoo ticker symbol
        2. INTERVAL — "1mo" (monthly), "1wk" (weekly), or "1d" (daily)
    ...then run the file again. Nothing else needs to change.

ONE-TIME SETUP (do this once per computer)
    Open the VS Code terminal (Terminal -> New Terminal) and run:
        pip install yfinance pandas
    (On a Mac you may need:  pip3 install yfinance pandas )

HOW TO RUN
    Press the Run button in VS Code, or in the terminal run:
        python get_stock_data.py
    The CSV lands in the same folder as this script.

FINDING A TICKER
    Look the company up on https://finance.yahoo.com — the symbol in
    the search bar is the ticker. Note the exchange suffix:
        DBK.DE   Deutsche Bank   (XETRA, Germany)
        AAPL     Apple           (US — no suffix)
        BARC.L   Barclays        (London)
        ASML.AS  ASML            (Amsterdam)
        NESN.SW  Nestle          (Switzerland)

NOTE ON Adj Close
    auto_adjust=False below keeps BOTH "Close" and "Adj Close".
    Use Adj Close to compute returns: it adds back dividends and
    corrects for stock splits, so returns are true total returns
    with no fake jumps. Raw Close ignores both.
"""

import yfinance as yf

# ============================================================
# CHANGE THESE TWO LINES TO REUSE FOR ANY COMPANY
# ============================================================
TICKER   = "DBK.DE"   # Yahoo ticker symbol (see notes above)
INTERVAL = "1mo"      # "1mo" monthly | "1wk" weekly | "1d" daily
# ============================================================

# Date range. START as far back as you want; leave END as None for "up to today".
START = "1996-01-01"
END   = None

print(f"Downloading {TICKER} ({INTERVAL}) ...")

data = yf.download(
    TICKER,
    start=START,
    end=END,
    interval=INTERVAL,
    # auto_adjust=False keeps BOTH "Close" and "Adj Close".
    # Compute returns from Adj Close: it adds back dividends and corrects
    # for stock splits, so returns are true total returns with no fake
    # jumps. Raw Close ignores both. (Same rule we locked for Deutsche Bank.)
    auto_adjust=False,
    progress=False,
)

# REPRODUCIBILITY NOTE (read before using this in a serious study):
# This is a convenience tool for future projects. A live yfinance pull
# fetches whatever Yahoo has TODAY, and Yahoo quietly revises history, so
# two runs on different days can disagree. The Macro Shock Analyser
# deliberately uses a frozen, manually-saved CSV (decision D10) so the
# numbers reproduce exactly. Don't swap a live pull into that project.

if data.empty:
    raise SystemExit(
        f"No data returned for '{TICKER}'. "
        "Check the ticker spelling / exchange suffix on finance.yahoo.com."
    )

# yfinance returns a multi-level column header when one ticker is requested;
# flatten it so the CSV has plain column names.
if hasattr(data.columns, "nlevels") and data.columns.nlevels > 1:
    data.columns = data.columns.get_level_values(0)

# Save. Filename is built from the ticker so each company gets its own file.
safe_name = TICKER.replace(".", "_").replace("^", "")
outfile = f"{safe_name}_{INTERVAL}.csv"
data.to_csv(outfile)

print(f"Done. {len(data)} rows saved to: {outfile}")
print(data.tail())
