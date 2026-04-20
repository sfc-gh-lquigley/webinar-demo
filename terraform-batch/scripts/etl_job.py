import os
import sys
import time
import random
import uuid
from datetime import datetime, timezone

portfolio = os.environ.get("PORTFOLIO", "equity_derivatives")
pipeline  = os.environ.get("BATCH_PIPELINE", "trade-pricing")
attempt   = int(os.environ.get("AWS_BATCH_JOB_ATTEMPT", "0"))

random.seed(os.environ.get("AWS_BATCH_JOB_ID", "local"))

pricing_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

def log(level, module, message):
    print(f"{level}:{module}:{message}", flush=True)

INSTRUMENTS = {
    "equity_derivatives": [
        "TERMS.EQ.USD.EURO-STOXX_USD-EQUITY-6M",
        "TERMS.EQ.GBP.FTSE-INDEX_GBP-EQUITY-2Y",
        "TERMS.EQ.USD.SP-INDEX_USD-EQUITY-1Y",
        "TERMS.EQ.EUR.DAX-INDEX_EUR-EQUITY-3M",
        "TERMS.EQ.USD.NASDAQ-INDEX_USD-EQUITY-9M",
        "TERMS.EQ.EUR.EURO-STOXX_EUR-EQUITY-1Y",
        "TERMS.EQ.USD.RUSSELL-INDEX_USD-EQUITY-6M",
    ],
    "fx_options": [
        "TERMS.EQ.USD.EUR-USD_USD-FX-1M",
        "TERMS.EQ.USD.GBP-USD_USD-FX-3M",
        "TERMS.EQ.JPY.USD-JPY_JPY-FX-6M",
        "TERMS.EQ.EUR.USD-EUR_EUR-FX-1Y",
        "TERMS.EQ.CHF.EUR-CHF_CHF-FX-2Y",
        "TERMS.EQ.USD.AUD-USD_USD-FX-3M",
        "TERMS.EQ.SGD.USD-SGD_SGD-FX-6M",
    ],
    "interest_rate_swaps": [
        "TERMS.EQ.USD.SOFR-OVERNIGHT_USD-RATES-5Y",
        "TERMS.EQ.USD.LIBOR-TERM_USD-RATES-3M",
        "TERMS.EQ.EUR.EURIBOR-TERM_EUR-RATES-6M",
        "TERMS.EQ.GBP.SONIA-OVERNIGHT_GBP-RATES-1Y",
        "TERMS.EQ.JPY.TONAR-OVERNIGHT_JPY-RATES-2Y",
        "TERMS.EQ.USD.SOFR-OVERNIGHT_USD-RATES-10Y",
        "TERMS.EQ.EUR.EURIBOR-TERM_EUR-RATES-2Y",
    ],
}

log("INFO", "BatchRunner",
    f"Starting trade pricing job | portfolio={portfolio} pipeline={pipeline} attempt={attempt}")

log("INFO", "MarketDataLoader", f"Loading market data for pricing date {pricing_date}")
time.sleep(random.uniform(0.3, 1.0))
num_curves   = random.randint(800, 2500)
num_surfaces = random.randint(200, 600)
log("INFO", "MarketDataLoader",
    f"Market data loaded: {num_curves} curves, {num_surfaces} vol surfaces")

num_trades = random.randint(80, 400)
log("INFO", "PortfolioManager", f"Loading portfolio {portfolio}, {num_trades} trades")
time.sleep(random.uniform(0.1, 0.4))
log("INFO", "PortfolioManager", f"Portfolio loaded: {num_trades} active instruments")

instruments    = INSTRUMENTS.get(portfolio, INSTRUMENTS["equity_derivatives"])
output_prefix  = f"/output/{portfolio}/{pricing_date}"

total_elapsed     = 0.0
successful        = 0
failed            = 0
batch_start       = 0.0
trades_in_batch   = 0
batch_size        = random.randint(8, 20)

for i in range(num_trades):
    trade_id    = str(uuid.uuid4())
    second_uuid = str(uuid.uuid4())
    instrument  = random.choice(instruments)
    calc_dur    = random.uniform(0.05, 2.5)
    total_elapsed += calc_dur
    trades_in_batch += 1

    if random.random() < 0.12:
        failed += 1
        log("ERROR", "TradePricing",
            f"Instance {instrument} did not successfully calculate.")
    else:
        successful += 1
        log("INFO", "TradePricing",
            f"Calc finished in {calc_dur:.3f}s, Total time elapsed: {total_elapsed:.3f}s")
        file_type = random.choice(["NPV", "Greeks", "Sensitivities", "CashFlow"])
        log("INFO", "FileUtil",
            f"Written {file_type} file {pricing_date}/{trade_id}/{second_uuid}/")

    if trades_in_batch >= batch_size or i == num_trades - 1:
        batch_dur = total_elapsed - batch_start
        log("DEBUG", "TradePricing",
            f"Processed results in {batch_dur:.3f}s, Total time elapsed: {total_elapsed:.3f}s")
        batch_start     = total_elapsed
        trades_in_batch = 0
        batch_size      = random.randint(8, 20)
        time.sleep(random.uniform(0.05, 0.15))

log("INFO", "RiskAggregator",
    f"Aggregating portfolio risk across {successful} priced trades")
time.sleep(random.uniform(0.1, 0.4))

log("INFO", "TradePricing", f"Total execution time {total_elapsed:.2f}")
log("INFO", "BatchRunner",
    f"Pricing complete: {successful} successful, {failed} failed, {num_trades} total trades")

failure_rate = failed / max(num_trades, 1)
if failure_rate > 0.25:
    log("ERROR", "BatchRunner",
        f"Failure rate {failure_rate:.1%} exceeded threshold, marking job FAILED")
    sys.exit(1)

log("INFO", "BatchRunner", "Job finished successfully")
