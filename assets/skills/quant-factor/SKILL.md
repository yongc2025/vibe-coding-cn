---
name: quant-factor
description: Python量化因子分析技能。覆盖因子挖掘、IC/ICIR分析、多因子组合、因子衰减检验，包含Alpha因子设计、有效性检验与回测框架集成。
---

# Quant Factor - 因子分析

## When to Use This Skill

- 设计和实现Alpha因子
- 检验因子有效性（IC、ICIR、分层回测）
- 多因子组合与加权
- 分析因子衰减和生命周期
- 将因子研究集成到回测框架

## Not For / Boundaries

- **不适用于**策略执行与订单管理（参见backtesting/risk-management技能）
- **不适用于**原始数据获取（参见tushare-akshare/alpaca-polygon技能）
- **不适用于**机器学习模型训练（需专用ML技能，因子研究侧重统计方法）
- 因子有效性不保证未来收益，需持续监控

## Quick Reference

### 因子分析核心框架

```python
import pandas as pd
import numpy as np
from scipy import stats

class FactorAnalyzer:
    """因子分析核心类"""

    def __init__(self, factor_df: pd.DataFrame, returns_df: pd.DataFrame):
        """
        factor_df: MultiIndex (date, stock) 的因子值
        returns_df: MultiIndex (date, stock) 的下期收益率
        """
        self.factor = factor_df
        self.returns = returns_df

    def calc_ic(self, method: str = 'spearman') -> pd.Series:
        """
        计算截面IC（Information Coefficient）
        IC = 因子值与下期收益的截面相关系数
        """
        merged = pd.merge(self.factor, self.returns,
                          left_index=True, right_index=True)
        merged.columns = ['factor', 'return']

        ic_series = merged.groupby(level=0).apply(
            lambda g: g['factor'].corr(g['return'], method=method)
        )
        return ic_series

    def calc_icir(self, method: str = 'spearman') -> float:
        """
        ICIR = IC均值 / IC标准差
        |ICIR| > 0.5 为有效因子，> 1.0 为优秀因子
        """
        ic = self.calc_ic(method)
        return ic.mean() / ic.std() if ic.std() > 0 else 0

    def ic_summary(self) -> dict:
        """IC统计摘要"""
        ic = self.calc_ic()
        return {
            'IC_mean': ic.mean(),
            'IC_std': ic.std(),
            'ICIR': ic.mean() / ic.std() if ic.std() > 0 else 0,
            'IC_positive_rate': (ic > 0).mean(),
            'IC_abs_gt_002': (ic.abs() > 0.02).mean(),
            't_stat': stats.ttest_1samp(ic.dropna(), 0)[0],
            'p_value': stats.ttest_1samp(ic.dropna(), 0)[1]
        }
```

### 因子分层回测（Quantile Analysis）

```python
class QuantileBacktest:
    """因子分层回测 - 检验因子单调性"""

    def __init__(self, n_groups: int = 5):
        self.n_groups = n_groups

    def run(self, factor_df: pd.DataFrame, returns_df: pd.DataFrame) -> pd.DataFrame:
        """
        将股票按因子值分N组，计算每组平均收益
        理想情况：因子有效时各组收益呈单调递增/递减
        """
        merged = pd.merge(factor_df, returns_df,
                          left_index=True, right_index=True)
        merged.columns = ['factor', 'return']

        def assign_group(g):
            try:
                return pd.qcut(g['factor'], self.n_groups, labels=False, duplicates='drop')
            except ValueError:
                return pd.Series(np.nan, index=g.index)

        merged['group'] = merged.groupby(level=0).apply(
            lambda g: assign_group(g)
        ).droplevel(0)

        # 每组平均收益
        group_returns = merged.groupby(['date', 'group'])['return'].mean().unstack()
        group_returns.columns = [f'Q{i+1}' for i in range(group_returns.shape[1])]

        # 多空收益（Top组 - Bottom组）
        group_returns['long_short'] = group_returns.iloc[:, -1] - group_returns.iloc[:, 0]

        return group_returns

    def monotonicity_score(self, group_returns: pd.DataFrame) -> float:
        """单调性得分：完美单调为1，完全无序为0"""
        avg_returns = group_returns.mean()
        avg_returns = avg_returns.drop('long_short', errors='ignore')
        ranks = np.arange(len(avg_returns))
        corr, _ = stats.spearmanr(ranks, avg_returns.values)
        return abs(corr)
```

### 常用Alpha因子实现

```python
class AlphaFactors:
    """常用Alpha因子库"""

    @staticmethod
    def momentum(close: pd.DataFrame, lookback: int = 20) -> pd.DataFrame:
        """动量因子：过去N日收益率"""
        return close.pct_change(lookback)

    @staticmethod
    def reversal(close: pd.DataFrame, lookback: int = 5) -> pd.DataFrame:
        """反转因子：短期收益率取反"""
        return -close.pct_change(lookback)

    @staticmethod
    def volatility(close: pd.DataFrame, window: int = 20) -> pd.DataFrame:
        """波动率因子：过去N日收益率标准差"""
        return close.pct_change().rolling(window).std()

    @staticmethod
    def volume_ratio(volume: pd.DataFrame, short: int = 5,
                     long: int = 20) -> pd.DataFrame:
        """量比因子：短期均量/长期均量"""
        return volume.rolling(short).mean() / volume.rolling(long).mean()

    @staticmethod
    def price_volume_corr(close: pd.DataFrame, volume: pd.DataFrame,
                          window: int = 20) -> pd.DataFrame:
        """量价相关性因子"""
        return close.rolling(window).corr(volume)

    @staticmethod
    def turnover_rate(volume: pd.DataFrame, shares: pd.Series,
                      window: int = 20) -> pd.DataFrame:
        """换手率因子"""
        daily_turnover = volume.div(shares, axis=1)
        return daily_turnover.rolling(window).mean()

    @staticmethod
    def book_to_market(book_value: pd.Series, market_cap: pd.Series) -> pd.Series:
        """市净率倒数（BM因子）"""
        return book_value / market_cap

    @staticmethod
    def roe_stability(roe_df: pd.DataFrame, periods: int = 4) -> pd.Series:
        """ROE稳定性因子：过去N期ROE标准差取反"""
        return -roe_df.rolling(periods).std()

    @staticmethod
    def earnings_surprise(actual_eps: pd.Series,
                          expected_eps: pd.Series) -> pd.Series:
        """盈利超预期因子（SUE）"""
        surprise = actual_eps - expected_eps
        return surprise / expected_eps.abs().replace(0, np.nan)
```

### 多因子组合

```python
class MultiFactorCombiner:
    """多因子组合方法"""

    @staticmethod
    def equal_weight(factors: dict) -> pd.DataFrame:
        """等权组合"""
        factor_list = list(factors.values())
        # 标准化后等权平均
        standardized = [(f - f.mean()) / f.std() for f in factor_list]
        return sum(standardized) / len(standardized)

    @staticmethod
    def ic_weighted(factors: dict, returns: pd.DataFrame,
                    lookback: int = 20) -> pd.DataFrame:
        """
        IC加权组合：根据因子最近IC动态调整权重
        IC高的因子获得更大权重
        """
        ic_values = {}
        for name, factor in factors.items():
            analyzer = FactorAnalyzer(factor, returns)
            ic_series = analyzer.calc_ic()
            ic_values[name] = ic_series.rolling(lookback).mean().iloc[-1]

        # 归一化权重
        total = sum(abs(v) for v in ic_values.values())
        weights = {k: abs(v) / total for k, v in ic_values.items()}

        combined = sum(
            factors[name] * weights[name] for name in factors
        )
        return combined

    @staticmethod
    def optimize_icir(factors: dict, returns: pd.DataFrame) -> dict:
        """
        最大化ICIR的因子权重优化
        使用矩阵方法求解最优权重
        """
        from scipy.optimize import minimize

        # 计算因子IC序列
        ic_matrix = pd.DataFrame()
        for name, factor in factors.items():
            analyzer = FactorAnalyzer(factor, returns)
            ic_matrix[name] = analyzer.calc_ic()

        # 优化目标：最大化ICIR（等价于最小化负ICIR）
        def neg_icir(weights):
            combined_ic = (ic_matrix * weights).sum(axis=1)
            return -(combined_ic.mean() / combined_ic.std())

        n = len(factors)
        result = minimize(
            neg_icir,
            x0=np.ones(n) / n,
            method='SLSQP',
            bounds=[(0, 1)] * n,
            constraints={'type': 'eq', 'fun': lambda w: w.sum() - 1}
        )

        return dict(zip(factors.keys(), result.x))
```

### 因子衰减分析

```python
class FactorDecay:
    """因子衰减分析 - 检验因子预测能力随时间的衰减"""

    @staticmethod
    def holding_period_ic(factor_df: pd.DataFrame, close_df: pd.DataFrame,
                          max_periods: int = 20) -> pd.DataFrame:
        """
        计算不同持有期的IC
        用于判断因子的最优持仓周期和衰减速度
        """
        results = []
        for period in range(1, max_periods + 1):
            forward_returns = close_df.pct_change(period).shift(-period)
            analyzer = FactorAnalyzer(factor_df, forward_returns)
            ic_summary = analyzer.ic_summary()
            ic_summary['holding_period'] = period
            results.append(ic_summary)

        return pd.DataFrame(results).set_index('holding_period')

    @staticmethod
    def decay_rate(ic_by_period: pd.DataFrame) -> float:
        """
        计算因子衰减率
        IC衰减到一半所需的持有期
        """
        ic_values = ic_by_period['IC_mean'].abs()
        initial_ic = ic_values.iloc[0]

        if initial_ic == 0:
            return 0

        half_life = initial_ic / 2
        for period, ic in ic_values.items():
            if ic <= half_life:
                return period

        return len(ic_values)  # 未衰减到一半
```

### 与回测框架集成

```python
import backtrader as bt

class FactorStrategy(bt.Strategy):
    """基于因子的策略 - 集成到backtrader"""

    params = (
        ('rebalance_days', 20),    # 调仓周期
        ('top_n', 10),             # 选股数量
    )

    def __init__(self):
        self.day_count = 0
        self.factor_values = {}

    def next(self):
        self.day_count += 1

        # 每N天调仓
        if self.day_count % self.p.rebalance_days != 0:
            return

        # 计算所有股票的因子值
        scores = {}
        for i, d in enumerate(self.datas):
            if len(d) < 20:
                continue
            # 示例：动量因子
            ret_20 = (d.close[0] - d.close[-20]) / d.close[-20]
            scores[d._name] = ret_20

        # 选择因子值Top N
        sorted_stocks = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        selected = [s[0] for s in sorted_stocks[:self.p.top_n]]

        # 平仓不在选中列表的持仓
        for d in self.datas:
            if d._name not in selected and self.getposition(d).size > 0:
                self.close(d)

        # 等权买入选中股票
        if selected:
            weight = 0.95 / len(selected)
            for d in self.datas:
                if d._name in selected:
                    target_value = self.broker.getvalue() * weight
                    current_price = d.close[0]
                    target_size = int(target_value / current_price)
                    current_size = self.getposition(d).size
                    diff = target_size - current_size
                    if diff > 0:
                        self.buy(d, size=diff)
                    elif diff < 0:
                        self.sell(d, size=abs(diff))
```

## Common Patterns

### 1. 因子预处理管道

```python
def preprocess_factor(raw_factor: pd.DataFrame) -> pd.DataFrame:
    """因子预处理：去极值 + 标准化 + 中性化"""
    # MAD去极值
    median = raw_factor.median()
    mad = (raw_factor - median).abs().median()
    upper = median + 5 * 1.4826 * mad
    lower = median - 5 * 1.4826 * mad
    factor = raw_factor.clip(lower, upper, axis=1)

    # Z-score标准化
    factor = (factor - factor.mean()) / factor.std()

    return factor
```

### 2. 因子正交化

```python
def orthogonalize(target_factor: pd.DataFrame,
                  control_factors: list) -> pd.DataFrame:
    """对目标因子做正交化，剔除控制因子的影响"""
    from sklearn.linear_model import LinearRegression

    residuals = target_factor.copy()
    X = pd.concat(control_factors, axis=1)

    for date in target_factor.index:
        y = target_factor.loc[date].dropna()
        x = X.loc[date].reindex(y.index).dropna()
        common = y.index.intersection(x.index)

        if len(common) < 10:
            continue

        reg = LinearRegression().fit(x.loc[common], y.loc[common])
        residuals.loc[date, common] = y.loc[common] - reg.predict(x.loc[common])

    return residuals
```

### 3. 因子报告生成

```python
def factor_report(factor_name: str, factor_df: pd.DataFrame,
                  returns_df: pd.DataFrame) -> str:
    """生成因子研究报告"""
    analyzer = FactorAnalyzer(factor_df, returns_df)
    summary = analyzer.ic_summary()

    qt = QuantileBacktest(5)
    group_returns = qt.run(factor_df, returns_df)
    mono_score = qt.monotonicity_score(group_returns)

    lines = [
        f"# 因子研究报告: {factor_name}",
        f"",
        f"## IC分析",
        f"- IC均值: {summary['IC_mean']:.4f}",
        f"- IC标准差: {summary['IC_std']:.4f}",
        f"- ICIR: {summary['ICIR']:.4f}",
        f"- IC>0占比: {summary['IC_positive_rate']:.1%}",
        f"- t统计量: {summary['t_stat']:.2f}",
        f"- p值: {summary['p_value']:.4f}",
        f"",
        f"## 分层回测",
        f"- 单调性得分: {mono_score:.4f}",
        f"- 多空年化收益: {group_returns['long_short'].mean() * 252:.2%}",
        f"- 多空夏普: {group_returns['long_short'].mean() / group_returns['long_short'].std() * np.sqrt(252):.2f}",
    ]

    # 评级
    if abs(summary['ICIR']) > 1.0 and mono_score > 0.8:
        rating = "⭐⭐⭐ 优秀"
    elif abs(summary['ICIR']) > 0.5 and mono_score > 0.6:
        rating = "⭐⭐ 良好"
    else:
        rating = "⭐ 一般"
    lines.append(f"\n## 综合评级: {rating}")

    return '\n'.join(lines)
```

## References

- 《Active Portfolio Management》 - Grinold & Kahn
- 《Quantitative Equity Portfolio Management》 - Chincarini & Kim
- [WorldQuant 101 Alphas](https://arxiv.org/abs/1601.00991)
- [QuantLib - 开源量化库](https://www.quantlib.org/)
- [MlfinBar - 金融机器学习库](https://github.com/hudson-and-thames/mlfinlab)
- [qlib 因子研究文档](https://qlib.readthedocs.io/en/latest/advanced/alpha.html)
