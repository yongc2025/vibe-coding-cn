---
name: tushare-akshare
description: Python A股数据源获取技能。覆盖tushare pro、akshare、聚宽JQData，包含API配置、日线/分钟线/财务数据获取、数据清洗与质量校验。
---

# Tushare & AkShare - A股数据源

## When to Use This Skill

- 获取A股行情数据（日线、分钟线、Tick数据）
- 获取财务报表、估值、分红等基本面数据
- 在tushare、akshare、JQData之间做选型
- 数据清洗、存储与质量校验
- 构建本地量化数据库

## Not For / Boundaries

- **不适用于**美股/港股数据（参见alpaca-polygon技能）
- **不适用于**实时高频行情推送（需专用Level-2数据源）
- **不适用于**策略回测逻辑（参见backtesting技能）
- tushare pro需要积分，部分高级接口需付费

## Quick Reference

### 数据源对比

| 数据源 | 费用 | 数据覆盖 | 优势 | 劣势 |
|--------|------|---------|------|------|
| **tushare pro** | 免费+积分制 | 全市场行情+财务+另类 | 数据全、API规范 | 高级接口需积分 |
| **akshare** | 完全免费 | 行情+新闻+宏观 | 免费无限制 | 数据源不稳定 |
| **JQData** | 付费 | 全市场+因子 | 质量高、有因子库 | 需聚宽账号 |

### tushare pro 使用

```python
import tushare as ts

# 初始化（需要注册获取token）
ts.set_token('YOUR_TOKEN_HERE')
pro = ts.pro_api()

# === 行情数据 ===

# 日线行情
df = pro.daily(ts_code='000001.SZ', start_date='20240101', end_date='20241231')
# 字段: ts_code, trade_date, open, high, low, close, vol, amount

# 周线行情
df = pro.weekly(ts_code='000001.SZ', start_date='20240101')

# 复权因子
df = pro.adj_factor(ts_code='000001.SZ', start_date='20240101')

# 全市场日线快照（每日批量）
df = pro.daily(trade_date='20241231')

# 分钟线（需500积分以上）
df = pro.stk_mins(ts_code='000001.SZ', freq='5min', start_date='20241201 09:30:00')

# === 基本面数据 ===

# 财务指标（利润表）
df = pro.fina_indicator(ts_code='000001.SZ', period='20240331')

# 资产负债表
df = pro.balancesheet(ts_code='000001.SZ', period='20240331')

# 现金流量表
df = pro.cashflow(ts_code='000001.SZ', period='20240331')

# 估值数据
df = pro.daily_basic(ts_code='000001.SZ', trade_date='20241231')
# 包含: pe, pb, ps, total_mv, circ_mv 等

# 分红送股
df = pro.dividend(ts_code='000001.SZ')

# === 基础信息 ===

# 股票列表
df = pro.stock_basic(exchange='', list_status='L',
                     fields='ts_code,symbol,name,area,industry,list_date')

# 交易日历
df = pro.trade_cal(exchange='SSE', start_date='20240101', end_date='20241231')
```

### akshare 使用

```python
import akshare as ak

# === 行情数据 ===

# 个股日线（东方财富源）
df = ak.stock_zh_a_hist(symbol="000001", period="daily",
                        start_date="20240101", end_date="20241231",
                        adjust="qfq")  # qfq=前复权, hfq=后复权

# 个股分钟线
df = ak.stock_zh_a_hist_min_em(symbol="000001", period="5",
                                start_date="2024-12-01 09:30:00",
                                adjust="qfq")

# 实时行情
df = ak.stock_zh_a_spot_em()  # 全市场实时快照

# 板块行情
df = ak.stock_board_industry_hist_em(symbol="银行", start_date="20240101")

# === 财务数据 ===

# 财务指标
df = ak.stock_financial_analysis_indicator(symbol="000001")

# 利润表
df = ak.stock_profit_sheet_by_report_em(symbol="000001")

# 资产负债表
df = ak.stock_balance_sheet_by_report_em(symbol="000001")

# 机构持仓
df = ak.stock_institute_hold_detail_em(symbol="000001")

# === 另类数据 ===

# 新闻
df = ak.stock_news_em(symbol="000001")

# 龙虎榜
df = ak.stock_lhb_detail_em(start_date="20241201", end_date="20241231")

# 融资融券
df = ak.stock_margin_detail_szse(date="20241201")
```

### JQData 使用

```python
from jqdatasdk import *

# 认证
auth('YOUR_ACCOUNT', 'YOUR_PASSWORD')

# 获取行情
df = get_price('000001.XSHE', start_date='2024-01-01',
               end_date='2024-12-31', frequency='daily',
               fields=['open', 'high', 'low', 'close', 'volume', 'money'])

# 分钟线
df = get_price('000001.XSHE', start_date='2024-12-01 09:30:00',
               end_date='2024-12-01 15:00:00', frequency='minute')

# 财务数据
q = query(
    valuation.code, valuation.pe_ratio, valuation.pb_ratio,
    valuation.market_cap
).filter(
    valuation.code == '000001.XSHE'
)
df = get_fundamentals(q, date='2024-12-31')

# 获取股票列表
stocks = get_all_securities(types=['stock'], date='2024-12-31')
```

### 数据清洗与存储

```python
import pandas as pd
from sqlalchemy import create_engine

class AShareDataCleaner:
    """A股数据清洗工具"""

    @staticmethod
    def clean_daily(df: pd.DataFrame) -> pd.DataFrame:
        """清洗日线数据"""
        df = df.copy()

        # 标准化日期列
        date_col = 'trade_date' if 'trade_date' in df.columns else '日期'
        df[date_col] = pd.to_datetime(df[date_col])
        df = df.sort_values(date_col).reset_index(drop=True)

        # 去除停牌日（成交量为0）
        vol_col = 'vol' if 'vol' in df.columns else '成交量'
        df = df[df[vol_col] > 0]

        # 去除涨跌停（开盘=收盘=最高=最低）
        close_col = 'close' if 'close' in df.columns else '收盘'
        open_col = 'open' if 'open' in df.columns else '开盘'
        df = df[~((df[open_col] == df[close_col]) &
                  (df[close_col] == df.get('high', df[close_col])))]

        # 处理缺失值
        df = df.dropna(subset=[close_col])

        return df

    @staticmethod
    def adjust_price(df: pd.DataFrame, adj_factor: pd.DataFrame) -> pd.DataFrame:
        """前复权价格计算"""
        merged = df.merge(adj_factor, on=['ts_code', 'trade_date'])
        latest_factor = merged['adj_factor'].iloc[-1]

        for col in ['open', 'high', 'low', 'close']:
            if col in merged.columns:
                merged[f'{col}_adj'] = merged[col] * merged['adj_factor'] / latest_factor

        return merged


class DataStorage:
    """数据存储管理"""

    def __init__(self, db_path: str = 'sqlite:///ashare.db'):
        self.engine = create_engine(db_path)

    def save(self, df: pd.DataFrame, table_name: str, if_exists: str = 'append'):
        """保存到数据库"""
        df.to_sql(table_name, self.engine, if_exists=if_exists, index=False)

    def load(self, table_name: str, ts_code: str = None,
             start_date: str = None) -> pd.DataFrame:
        """从数据库读取"""
        query = f"SELECT * FROM {table_name}"
        conditions = []
        if ts_code:
            conditions.append(f"ts_code='{ts_code}'")
        if start_date:
            conditions.append(f"trade_date>='{start_date}'")
        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        return pd.read_sql(query, self.engine)
```

### 数据质量校验

```python
def validate_data(df: pd.DataFrame, data_type: str = 'daily') -> dict:
    """数据质量校验"""
    issues = []

    # 1. 完整性检查
    null_counts = df.isnull().sum()
    if null_counts.any():
        issues.append(f"存在空值: {null_counts[null_counts > 0].to_dict()}")

    # 2. 连续性检查（交易日缺失）
    if 'trade_date' in df.columns:
        dates = pd.to_datetime(df['trade_date'])
        business_days = pd.bdate_range(dates.min(), dates.max())
        missing = set(business_days) - set(dates)
        if missing:
            issues.append(f"缺失{len(missing)}个交易日")

    # 3. 价格合理性检查
    if 'close' in df.columns:
        pct_change = df['close'].pct_change().abs()
        extreme = pct_change[pct_change > 0.11]  # A股涨跌停10%
        if len(extreme) > 0:
            issues.append(f"发现{len(extreme)}条超过10%的价格变动")

    # 4. 量价一致性
    if all(c in df.columns for c in ['close', 'vol']):
        zero_vol_price_change = df[(df['vol'] == 0) & (df['close'] != df['close'].shift(1))]
        if len(zero_vol_price_change) > 0:
            issues.append(f"发现{len(zero_vol_price_change)}条零成交量但价格变动")

    return {
        'total_rows': len(df),
        'date_range': f"{df['trade_date'].min()} ~ {df['trade_date'].max()}" if 'trade_date' in df.columns else 'N/A',
        'issues': issues,
        'quality_score': max(0, 100 - len(issues) * 15)
    }
```

## Common Patterns

### 1. 多数据源融合

```python
def get_daily_with_fallback(ts_code: str, start_date: str, end_date: str) -> pd.DataFrame:
    """多数据源回退策略：tushare → akshare"""
    try:
        df = pro.daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
        if df is not None and len(df) > 0:
            return df
    except Exception:
        pass

    symbol = ts_code.split('.')[0]
    return ak.stock_zh_a_hist(symbol=symbol, period="daily",
                               start_date=start_date, end_date=end_date, adjust="")
```

### 2. 增量更新

```python
def incremental_update(storage: DataStorage, table: str, ts_code: str, fetch_fn):
    """增量更新：只获取本地缺失的日期"""
    local = storage.load(table, ts_code=ts_code)
    if len(local) > 0:
        last_date = local['trade_date'].max()
        new_data = fetch_fn(ts_code, start_date=last_date)
        new_data = new_data[new_data['trade_date'] > last_date]
    else:
        new_data = fetch_fn(ts_code)

    if len(new_data) > 0:
        storage.save(new_data, table)
    return len(new_data)
```

### 3. 批量获取限流

```python
import time

def batch_fetch(symbols: list, fetch_fn, delay: float = 0.3):
    """带限流的批量获取"""
    results = {}
    for i, sym in enumerate(symbols):
        try:
            results[sym] = fetch_fn(sym)
        except Exception as e:
            print(f"[{i+1}/{len(symbols)}] {sym} 失败: {e}")

        if (i + 1) % 50 == 0:
            print(f"已完成 {i+1}/{len(symbols)}")
            time.sleep(1)  # 每50个暂停1秒
        else:
            time.sleep(delay)

    return results
```

## References

- [Tushare Pro 官方文档](https://tushare.pro/document/1)
- [AkShare 官方文档](https://akshare.akfamily.xyz/)
- [聚宽 JQData 文档](https://www.joinquant.com/help/api/help#api:JQData)
- [Tushare GitHub](https://github.com/waditu/tushare)
- [AkShare GitHub](https://github.com/akfamily/akshare)
