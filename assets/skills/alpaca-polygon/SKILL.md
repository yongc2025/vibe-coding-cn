---
name: alpaca-polygon
description: Python美股数据源获取技能。覆盖Alpaca Markets API、Polygon.io、yfinance、Alpha Vantage，包含API认证、实时行情、历史数据与基本面获取。
---

# Alpaca & Polygon - 美股数据源

## When to Use This Skill

- 获取美股行情数据（实时/历史日线/分钟线）
- 获取公司基本面数据（财报、估值、分红）
- 在Alpaca、Polygon、yfinance、Alpha Vantage之间做选型
- 构建美股量化交易数据管道
- 需要免费或低成本的美股数据方案

## Not For / Boundaries

- **不适用于**A股数据（参见tushare-akshare技能）
- **不适用于**策略回测逻辑（参见backtesting技能）
- **不适用于**订单执行（参见实盘交易技能，虽然Alpaca支持交易）
- 免费API通常有请求频率限制，需注意限流

## Quick Reference

### 数据源对比

| 数据源 | 费用 | 实时数据 | 历史数据 | 基本面 | 优势 |
|--------|------|---------|---------|--------|------|
| **Alpaca** | 免费(需注册) | ✅ IEX | ✅ | 有限 | 同时支持交易 |
| **Polygon.io** | 免费+付费 | ✅ | ✅ 全量 | ✅ | 数据最全面 |
| **yfinance** | 免费 | ❌ 延迟 | ✅ | ✅ | 无需注册 |
| **Alpha Vantage** | 免费+付费 | ✅ | ✅ | ✅ | 全球市场 |

### Alpaca Markets API

```python
from alpaca.data.historical import StockHistoricalDataClient
from alpaca.data.requests import (
    StockBarsRequest, StockLatestQuoteRequest,
    StockSnapshotRequest
)
from alpaca.data.timeframe import TimeFrame
from datetime import datetime

# 初始化（免费注册获取key）
client = StockHistoricalDataClient("API_KEY", "SECRET_KEY")

# === 历史K线 ===

# 日线数据
request = StockBarsRequest(
    symbol_or_symbols=["AAPL", "MSFT", "GOOGL"],
    timeframe=TimeFrame.Day,
    start=datetime(2024, 1, 1),
    end=datetime(2024, 12, 31)
)
bars = client.get_stock_bars(request)
df = bars.df  # MultiIndex DataFrame: (symbol, timestamp)

# 分钟线
request = StockBarsRequest(
    symbol_or_symbols=["AAPL"],
    timeframe=TimeFrame(5, "Min"),  # 5分钟
    start=datetime(2024, 12, 1),
    end=datetime(2024, 12, 31)
)
bars = client.get_stock_bars(request)

# === 实时快照 ===

# 最新报价
request = StockLatestQuoteRequest(symbol_or_symbols=["AAPL", "MSFT"])
quotes = client.get_stock_latest_quote(request)

# 市场快照（包含日K、最新价、分钟K）
request = StockSnapshotRequest(symbol_or_symbols=["AAPL"])
snapshots = client.get_stock_snapshot(request)

# === Alpaca Trading API（交易功能） ===
from alpaca.trading.client import TradingClient
from alpaca.trading.requests import GetOrdersRequest
from alpaca.trading.enums import OrderSide, TimeInForce

trading_client = TradingClient("API_KEY", "SECRET_KEY", paper=True)  # 模拟盘

# 获取账户信息
account = trading_client.get_account()
print(f"购买力: ${account.buying_power}")

# 获取持仓
positions = trading_client.get_all_positions()
for pos in positions:
    print(f"{pos.symbol}: {pos.qty}股, P&L: {pos.unrealized_pl}")
```

### Polygon.io

```python
from polygon import RESTClient
from datetime import date

# 初始化（免费注册，每分钟5次请求）
client = RESTClient("YOUR_API_KEY")

# === 历史行情 ===

# 日线聚合（Aggregates）
aggs = client.get_aggs(
    ticker="AAPL",
    multiplier=1,       # 1根K线
    timespan="day",     # 日线
    from_="2024-01-01",
    to="2024-12-31",
    adjusted=True,
    sort="asc"
)
# aggs 每个元素: open, high, low, close, volume, vwap, timestamp

# 分钟线
aggs = client.get_aggs(
    ticker="AAPL",
    multiplier=5,
    timespan="minute",
    from_="2024-12-01",
    to="2024-12-31"
)

# 前复权日线
aggs = client.get_aggs("AAPL", 1, "day", "2024-01-01", "2024-12-31", adjusted=True)

# === 市场概览 ===

# 全市场涨跌概况
market_status = client.get_market_status()

# 热门股票
tickers = client.get_tickers(market="stocks", active=True, sort="ticker")

# === 公司基本面 ===

# 公司详情
details = client.get_ticker_details("AAPL")

# 财务数据
financials = client.vx.reference.stock_financials(
    ticker="AAPL",
    filing_date_gte="2024-01-01",
    limit=4
)

# 分红历史
dividends = client.list_dividends("AAPL", limit=50)

# 拆股历史
splits = client.list_splits("AAPL", limit=20)
```

### yfinance 使用

```python
import yfinance as yf

# === 单只股票 ===

aapl = yf.Ticker("AAPL")

# 历史行情
hist = aapl.history(period="1y")          # 最近1年
hist = aapl.history(start="2024-01-01", end="2024-12-31")

# 公司信息
info = aapl.info
print(f"公司: {info['longName']}")
print(f"市值: ${info['marketCap']/1e9:.1f}B")
print(f"PE: {info.get('trailingPE', 'N/A')}")
print(f"行业: {info['sector']}")

# 财务报表
income = aapl.income_stmt          # 利润表（年度）
income_q = aapl.quarterly_income_stmt  # 利润表（季度）
balance = aapl.balance_sheet       # 资产负债表
cashflow = aapl.cashflow           # 现金流量表

# 分析师推荐
recommendations = aapl.recommendations

# 分红
dividends = aapl.dividends

# 期权链
options_dates = aapl.options
chain = aapl.option_chain(options_dates[0])  # calls & puts

# === 批量下载 ===

# 同时获取多只股票
data = yf.download(["AAPL", "MSFT", "GOOGL", "AMZN"],
                   start="2024-01-01", end="2024-12-31",
                   group_by="ticker")
# data['AAPL']['Close'] 获取单只股票收盘价

# 全市场扫描（S&P 500）
import pandas as pd
sp500 = pd.read_html('https://en.wikipedia.org/wiki/List_of_S%26P_500_companies')[0]
tickers = sp500['Symbol'].tolist()
# 批量下载（注意限流）
```

### Alpha Vantage

```python
from alpha_vantage.timeseries import TimeSeries
from alpha_vantage.fundamentaldata import FundamentalData

# 初始化（免费key：每天500次）
ts = TimeSeries(key='YOUR_API_KEY', output_format='pandas')
fd = FundamentalData(key='YOUR_API_KEY', output_format='pandas')

# === 行情数据 ===

# 日线（完整历史）
data, meta = ts.get_daily(symbol='AAPL', outputsize='full')
# 列名: 1. open, 2. high, 3. low, 4. close, 5. volume

# 分钟线（最近一个月）
data, meta = ts.get_intraday(symbol='AAPL', interval='5min', outputsize='full')

# 周线
data, meta = ts.get_weekly(symbol='AAPL')

# === 基本面 ===

# 公司概况
overview = fd.get_company_overview('AAPL')

# 利润表
income = fd.get_income_statement_annual('AAPL')

# 资产负债表
balance = fd.get_balance_sheet_annual('AAPL')

# 现金流量表
cashflow = fd.get_cash_flow_annual('AAPL')

# 盈利数据
earnings = fd.get_earnings('AAPL')
```

### 统一数据接口

```python
class USMarketData:
    """美股数据统一接口"""

    def __init__(self, alpaca_key=None, alpaca_secret=None, polygon_key=None):
        self.clients = {}
        if alpaca_key:
            from alpaca.data.historical import StockHistoricalDataClient
            self.clients['alpaca'] = StockHistoricalDataClient(alpaca_key, alpaca_secret)
        if polygon_key:
            from polygon import RESTClient
            self.clients['polygon'] = RESTClient(polygon_key)

    def get_daily(self, symbol: str, start: str, end: str,
                  source: str = 'yfinance') -> 'pd.DataFrame':
        """统一获取日线数据"""
        if source == 'yfinance':
            import yfinance as yf
            return yf.Ticker(symbol).history(start=start, end=end)

        elif source == 'alpaca':
            from alpaca.data.requests import StockBarsRequest
            from alpaca.data.timeframe import TimeFrame
            request = StockBarsRequest(
                symbol_or_symbols=symbol,
                timeframe=TimeFrame.Day,
                start=datetime.fromisoformat(start),
                end=datetime.fromisoformat(end)
            )
            return self.clients['alpaca'].get_stock_bars(request).df

        elif source == 'polygon':
            aggs = self.clients['polygon'].get_aggs(
                symbol, 1, "day", start, end, adjusted=True
            )
            import pandas as pd
            return pd.DataFrame([{
                'Open': a.open, 'High': a.high, 'Low': a.low,
                'Close': a.close, 'Volume': a.volume
            } for a in aggs])

    def get_fundamentals(self, symbol: str) -> dict:
        """获取基本面数据（yfinance）"""
        import yfinance as yf
        ticker = yf.Ticker(symbol)
        info = ticker.info
        return {
            'name': info.get('longName'),
            'sector': info.get('sector'),
            'industry': info.get('industry'),
            'market_cap': info.get('marketCap'),
            'pe_ratio': info.get('trailingPE'),
            'pb_ratio': info.get('priceToBook'),
            'dividend_yield': info.get('dividendYield'),
            'revenue': info.get('totalRevenue'),
            'profit_margin': info.get('profitMargins'),
            'beta': info.get('beta'),
        }
```

## Common Patterns

### 1. 限流处理

```python
import time
from functools import wraps

def rate_limit(calls_per_minute: int = 5):
    """API限流装饰器"""
    min_interval = 60.0 / calls_per_minute
    last_call = [0]

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            elapsed = time.time() - last_call[0]
            if elapsed < min_interval:
                time.sleep(min_interval - elapsed)
            result = fn(*args, **kwargs)
            last_call[0] = time.time()
            return result
        return wrapper
    return decorator
```

### 2. 数据缓存

```python
import os
import pickle
from datetime import datetime

def cached_fetch(symbol: str, start: str, end: str, cache_dir: str = 'cache'):
    """带本地缓存的数据获取"""
    os.makedirs(cache_dir, exist_ok=True)
    cache_file = f"{cache_dir}/{symbol}_{start}_{end}.pkl"

    if os.path.exists(cache_file):
        with open(cache_file, 'rb') as f:
            return pickle.load(f)

    import yfinance as yf
    data = yf.Ticker(symbol).history(start=start, end=end)

    with open(cache_file, 'wb') as f:
        pickle.dump(data, f)

    return data
```

### 3. 时区处理

```python
def convert_to_eastern(df, tz_col='timestamp'):
    """将UTC时间转换为美东时间"""
    if df.index.tz is None:
        df.index = df.index.tz_localize('UTC')
    return df.index.tz_convert('US/Eastern')
```

## References

- [Alpaca Markets API 文档](https://alpaca.markets/docs/)
- [Polygon.io API 文档](https://polygon.io/docs/)
- [yfinance GitHub](https://github.com/ranaroussi/yfinance)
- [Alpha Vantage 文档](https://www.alphavantage.co/documentation/)
- [Alpaca Python SDK](https://github.com/alpacahq/alpaca-py)
- [Polygon Python Client](https://github.com/polygon-io/client-python)
