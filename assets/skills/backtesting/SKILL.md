---
name: backtesting
description: Python量化策略回测引擎技能。覆盖backtrader、vnpy、zipline、qlib等主流框架，包含策略开发、数据准备、绩效评估、参数优化与防过拟合。
---

# Backtesting - 回测引擎

## When to Use This Skill

- 用户需要对量化交易策略进行历史数据回测
- 选择或搭建回测框架（backtrader/vnpy/zipline/qlib）
- 评估策略绩效指标（夏普比率、最大回撤、胜率等）
- 进行参数优化或网格搜索
- 需要防止过拟合的策略验证方法

## Not For / Boundaries

- **不适用于**实盘交易执行（参见实盘交易技能）
- **不适用于**高频交易（毫秒级延迟需求超出回测框架能力）
- **不适用于**期权定价等复杂衍生品定价（需专用量化库）
- 回测结果不等于未来收益，需明确提示用户

## Quick Reference

### 框架选型对比

| 框架 | 适用场景 | 优势 | 劣势 |
|------|---------|------|------|
| **backtrader** | 通用策略回测 | 文档丰富、事件驱动、可视化好 | 性能一般 |
| **vnpy** | A股/期货回测+实盘 | 国内市场支持好、可直接对接实盘 | 学习曲线陡 |
| **zipline** | 美股回测 | Quantopian出品、pipeline强大 | 维护停滞 |
| **qlib** | 因子研究+回测 | 微软出品、ML集成好 | 偏因子研究 |

### backtrader 快速开始

```python
import backtrader as bt
import datetime

class DualMA(bt.Strategy):
    """双均线策略示例"""
    params = (('fast', 10), ('slow', 30),)

    def __init__(self):
        self.fast_ma = bt.indicators.SMA(period=self.p.fast)
        self.slow_ma = bt.indicators.SMA(period=self.p.slow)
        self.crossover = bt.indicators.CrossOver(self.fast_ma, self.slow_ma)

    def next(self):
        if not self.position:
            if self.crossover > 0:
                self.buy()
        elif self.crossover < 0:
            self.close()

# 回测引擎配置
cerebro = bt.Cerebro()
cerebro.addstrategy(DualMA)
cerebro.broker.setcash(1000000)
cerebro.broker.setcommission(commission=0.001)

# 加载数据
data = bt.feeds.GenericCSVData(
    dataname='data/000001.csv',
    fromdate=datetime.datetime(2020, 1, 1),
    todate=datetime.datetime(2024, 12, 31),
    dtformat='%Y-%m-%d',
    openinterest=-1
)
cerebro.adddata(data)

# 添加分析器
cerebro.addanalyzer(bt.analyzers.SharpeRatio, _name='sharpe')
cerebro.addanalyzer(bt.analyzers.DrawDown, _name='drawdown')
cerebro.addanalyzer(bt.analyzers.Returns, _name='returns')
cerebro.addanalyzer(bt.analyzers.TradeAnalyzer, _name='trades')

# 运行回测
results = cerebro.run()
strat = results[0]

# 输出绩效
print(f"最终资金: {cerebro.broker.getvalue():.2f}")
print(f"夏普比率: {strat.analyzers.sharpe.get_analysis()['sharperatio']:.4f}")
print(f"最大回撤: {strat.analyzers.drawdown.get_analysis()['max']['drawdown']:.2f}%")

cerebro.plot(style='candle')
```

### 绩效评估指标计算

```python
import numpy as np
import pandas as pd

class PerformanceMetrics:
    """策略绩效评估工具"""

    @staticmethod
    def sharpe_ratio(returns: pd.Series, rf: float = 0.03, periods: int = 252) -> float:
        """年化夏普比率"""
        excess = returns - rf / periods
        return np.sqrt(periods) * excess.mean() / excess.std()

    @staticmethod
    def max_drawdown(equity_curve: pd.Series) -> float:
        """最大回撤"""
        peak = equity_curve.cummax()
        drawdown = (equity_curve - peak) / peak
        return drawdown.min()

    @staticmethod
    def win_rate(trades: list) -> float:
        """胜率"""
        wins = sum(1 for t in trades if t['pnl'] > 0)
        return wins / len(trades) if trades else 0.0

    @staticmethod
    def profit_factor(trades: list) -> float:
        """盈亏比"""
        gross_profit = sum(t['pnl'] for t in trades if t['pnl'] > 0)
        gross_loss = abs(sum(t['pnl'] for t in trades if t['pnl'] < 0))
        return gross_profit / gross_loss if gross_loss > 0 else float('inf')

    @staticmethod
    def annual_return(equity_curve: pd.Series, periods: int = 252) -> float:
        """年化收益率"""
        total_return = equity_curve.iloc[-1] / equity_curve.iloc[0] - 1
        years = len(equity_curve) / periods
        return (1 + total_return) ** (1 / years) - 1
```

### 参数优化与防过拟合

```python
import itertools
from sklearn.model_selection import TimeSeriesSplit

def walk_forward_optimization(strategy_cls, data, param_grid, n_splits=5):
    """
    Walk-Forward优化 - 防止过拟合的核心方法
    滚动窗口训练+测试，确保参数在样本外有效
    """
    tscv = TimeSeriesSplit(n_splits=n_splits)
    best_params_list = []

    for train_idx, test_idx in tscv.split(data):
        train_data = data.iloc[train_idx]
        test_data = data.iloc[test_idx]

        # 在训练集上网格搜索
        best_sharpe = -np.inf
        best_params = None

        keys = list(param_grid.keys())
        for values in itertools.product(*param_grid.values()):
            params = dict(zip(keys, values))

            cerebro = bt.Cerebro()
            cerebro.addstrategy(strategy_cls, **params)
            cerebro.adddata(bt.feeds.PandasData(dataname=train_data))
            cerebro.addanalyzer(bt.analyzers.SharpeRatio, _name='sharpe')

            results = cerebro.run()
            sharpe = results[0].analyzers.sharpe.get_analysis().get('sharperatio', 0) or 0

            if sharpe > best_sharpe:
                best_sharpe = sharpe
                best_params = params

        # 在测试集上验证最优参数
        cerebro = bt.Cerebro()
        cerebro.addstrategy(strategy_cls, **best_params)
        cerebro.adddata(bt.feeds.PandasData(dataname=test_data))
        cerebro.addanalyzer(bt.analyzers.SharpeRatio, _name='sharpe')

        results = cerebro.run()
        test_sharpe = results[0].analyzers.sharpe.get_analysis().get('sharperatio', 0) or 0

        best_params_list.append({
            'params': best_params,
            'train_sharpe': best_sharpe,
            'test_sharpe': test_sharpe
        })

    return best_params_list

# 防过拟合检查
def overfitting_score(results: list) -> dict:
    """计算过拟合风险评分"""
    train_sharpes = [r['train_sharpe'] for r in results]
    test_sharpes = [r['test_sharpe'] for r in results]

    degradation = np.mean(train_sharpes) - np.mean(test_sharpes)
    consistency = sum(1 for t in test_sharpes if t > 0) / len(test_sharpes)

    return {
        'degradation': degradation,        # >0.5 高风险
        'consistency': consistency,         # <0.6 低一致性
        'risk_level': 'HIGH' if degradation > 0.5 or consistency < 0.6 else 'LOW'
    }
```

### qlib 回测示例

```python
import qlib
from qlib.config import REG_CN
from qlib.contrib.evaluate import backtest_daily, risk_analysis

# 初始化qlib
qlib.init(provider_uri='~/.qlib/qlib_data/cn_data', region=REG_CN)

# 定义回测配置
backtest_config = {
    "start_time": "2020-01-01",
    "end_time": "2024-12-31",
    "account": 1000000,
    "benchmark": "SH000300",
    "exchange_kwargs": {
        "freq": "day",
        "limit_threshold": 0.095,
        "deal_price": "close",
        "open_cost": 0.0005,
        "close_cost": 0.0015,
        "min_cost": 5,
    },
}

# 执行回测并分析
report_normal, positions = backtest_daily(pred, **backtest_config)
analysis = risk_analysis(report_normal)
print(analysis)
```

## Common Patterns

### 1. 多品种回测

```python
# 批量加载多只股票
symbols = ['000001.SZ', '600519.SH', '000858.SZ']
for sym in symbols:
    data = bt.feeds.GenericCSVData(dataname=f'data/{sym}.csv', ...)
    cerebro.adddata(data, name=sym)
```

### 2. 滑点与手续费模拟

```python
cerebro.broker.setcommission(commission=0.001)  # 万分之十
cerebro.broker.set_slippage_perc(0.001)          # 0.1%滑点
```

### 3. 基准对比

```python
cerebro.addanalyzer(bt.analyzers.TimeReturn, _name='benchmark', timeframe=bt.TimeFrame.Days)
# 或手动计算超额收益
```

### 4. 结果持久化

```python
import json
with open('backtest_result.json', 'w') as f:
    json.dump({
        'params': strat.params._getpairs(),
        'metrics': {
            'sharpe': strat.analyzers.sharpe.get_analysis(),
            'drawdown': strat.analyzers.drawdown.get_analysis(),
        }
    }, f, indent=2, default=str)
```

## References

- [backtrader 官方文档](https://www.backtrader.com/docu/)
- [vnpy 官方文档](https://www.vnpy.com/docs/)
- [Microsoft Qlib GitHub](https://github.com/microsoft/qlib)
- [Zipline GitHub](https://github.com/stefan-jansen/zipline-reloaded)
- [QuantConnect - 开源回测平台](https://www.quantconnect.com/)
- 《Advances in Financial Machine Learning》 - Marcos López de Prado
