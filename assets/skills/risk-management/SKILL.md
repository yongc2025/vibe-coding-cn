---
name: risk-management
description: Python量化交易风控模块技能。覆盖仓位管理(Kelly/固定比例/ATR)、止损策略、最大回撤控制、风险敞口管理与熔断机制。
---

# Risk Management - 风控模块

## When to Use This Skill

- 设计或实现量化交易系统的风控模块
- 需要仓位管理策略（Kelly公式、固定比例、ATR法）
- 设计止损/止盈策略（固定、追踪、波动率止损）
- 控制组合最大回撤、风险敞口
- 实现交易熔断机制

## Not For / Boundaries

- **不适用于**策略信号生成（参见因子分析/回测技能）
- **不适用于**订单执行与撮合（参见实盘交易技能）
- **不适用于**合规监管报告（需专用合规系统）
- 风控模块不能消除市场风险，只能管理风险敞口

## Quick Reference

### 仓位管理

```python
import numpy as np

class PositionSizer:
    """仓位管理器"""

    @staticmethod
    def fixed_ratio(capital: float, risk_per_trade: float = 0.02) -> float:
        """固定比例法 - 每笔交易风险不超过总资金的固定比例"""
        return capital * risk_per_trade

    @staticmethod
    def kelly(win_rate: float, win_loss_ratio: float) -> float:
        """
        Kelly公式 - 最优仓位比例
        f* = (p * b - q) / b
        p=胜率, q=败率, b=盈亏比
        """
        q = 1 - win_rate
        f = (win_rate * win_loss_ratio - q) / win_loss_ratio
        return max(0, min(f, 0.25))  # 上限25%防止单次过度暴露

    @staticmethod
    def atr_based(capital: float, atr: float, risk_pct: float = 0.02,
                  atr_multiplier: float = 2.0) -> dict:
        """
        ATR仓位法 - 基于波动率动态调整仓位
        每笔交易的风险 = 资金 × 风险比例
        仓位 = 风险金额 / (ATR × 倍数)
        """
        risk_amount = capital * risk_pct
        stop_distance = atr * atr_multiplier
        position_size = int(risk_amount / stop_distance)
        return {
            'position_size': position_size,
            'stop_distance': stop_distance,
            'risk_amount': risk_amount
        }

    @staticmethod
    def equal_weight(num_assets: int, capital: float) -> float:
        """等权分配"""
        return capital / num_assets

    @staticmethod
    def risk_parity(returns_list: list, capital: float) -> list:
        """
        风险平价 - 每个资产贡献相同风险
        权重 ∝ 1/波动率
        """
        vols = [np.std(r) for r in returns_list]
        inv_vols = [1.0 / v for v in vols]
        total = sum(inv_vols)
        weights = [iv / total for iv in inv_vols]
        return [w * capital for w in weights]
```

### 止损策略

```python
class StopLoss:
    """止损策略集合"""

    @staticmethod
    def fixed_pct(entry_price: float, pct: float = 0.05) -> float:
        """固定百分比止损"""
        return entry_price * (1 - pct)

    @staticmethod
    def trailing(current_price: float, highest_since_entry: float,
                 trail_pct: float = 0.05) -> float:
        """
        追踪止损 - 价格创新高时上移止损位
        止损价 = 最高价 × (1 - 追踪比例)
        """
        stop = highest_since_entry * (1 - trail_pct)
        return max(stop, current_price * 0.9)  # 保底10%止损

    @staticmethod
    def volatility_based(entry_price: float, atr: float,
                         multiplier: float = 2.0) -> float:
        """
        波动率止损 - 基于ATR动态止损
        适应不同波动率环境，高波动时止损更宽
        """
        return entry_price - atr * multiplier

    @staticmethod
    def chandelier(high: float, atr: float, multiplier: float = 3.0) -> float:
        """吊灯止损 - 经典的趋势跟踪止损"""
        return high - atr * multiplier

    @staticmethod
    def time_based(entry_date, current_date, max_holding_days: int = 20) -> bool:
        """时间止损 - 超过最大持仓天数强制平仓"""
        return (current_date - entry_date).days >= max_holding_days
```

### 最大回撤控制

```python
class DrawdownControl:
    """回撤控制系统"""

    def __init__(self, max_drawdown: float = 0.15, warning_level: float = 0.10):
        self.max_drawdown = max_drawdown
        self.warning_level = warning_level
        self.peak_equity = 0
        self.current_equity = 0

    def update(self, equity: float) -> dict:
        """更新净值并检查回撤状态"""
        self.current_equity = equity
        self.peak_equity = max(self.peak_equity, equity)

        drawdown = (self.peak_equity - equity) / self.peak_equity if self.peak_equity > 0 else 0

        status = 'NORMAL'
        action = None

        if drawdown >= self.max_drawdown:
            status = 'BREACH'
            action = 'CLOSE_ALL'  # 触发全部平仓
        elif drawdown >= self.warning_level:
            status = 'WARNING'
            action = 'REDUCE_POSITION'  # 降低仓位

        return {
            'drawdown': drawdown,
            'status': status,
            'action': action,
            'position_scale': max(0, 1 - drawdown / self.max_drawdown)
        }

    def dynamic_scale(self, drawdown: float) -> float:
        """
        动态仓位缩放 - 回撤越大仓位越小
        线性衰减：回撤从0到max时，仓位从1到0
        """
        return max(0, 1 - drawdown / self.max_drawdown)
```

### 风险敞口管理

```python
class RiskExposure:
    """风险敞口管理"""

    def __init__(self, max_single_pct: float = 0.10,
                 max_sector_pct: float = 0.30,
                 max_total_exposure: float = 1.0):
        self.max_single_pct = max_single_pct      # 单票最大占比
        self.max_sector_pct = max_sector_pct       # 单行业最大占比
        self.max_total_exposure = max_total_exposure  # 最大总仓位

    def check_position(self, position_value: float, total_capital: float,
                       sector_exposures: dict = None) -> dict:
        """检查持仓是否符合风控要求"""
        violations = []

        # 单票占比检查
        single_pct = position_value / total_capital
        if single_pct > self.max_single_pct:
            violations.append(f'单票占比{single_pct:.1%}超过限制{self.max_single_pct:.1%}')

        # 行业占比检查
        if sector_exposures:
            for sector, exposure in sector_exposures.items():
                pct = exposure / total_capital
                if pct > self.max_sector_pct:
                    violations.append(f'{sector}行业占比{pct:.1%}超过限制')

        return {
            'compliant': len(violations) == 0,
            'violations': violations,
            'allowed_value': total_capital * self.max_single_pct
        }

    def portfolio_beta(self, positions: list, betas: list, total_capital: float) -> float:
        """计算组合Beta（市场风险敞口）"""
        weighted_beta = sum(
            (p / total_capital) * b for p, b in zip(positions, betas)
        )
        return weighted_beta
```

### 熔断机制

```python
from datetime import datetime, timedelta

class CircuitBreaker:
    """交易熔断机制"""

    def __init__(self, daily_loss_limit: float = 0.03,
                 consecutive_loss_limit: int = 5,
                 cooldown_hours: int = 4):
        self.daily_loss_limit = daily_loss_limit
        self.consecutive_loss_limit = consecutive_loss_limit
        self.cooldown_hours = cooldown_hours

        self.daily_pnl = 0.0
        self.consecutive_losses = 0
        self.last_break_time = None
        self.is_active = False
        self.daily_start_equity = 0.0

    def start_day(self, equity: float):
        """每日初始化"""
        self.daily_pnl = 0.0
        self.daily_start_equity = equity
        self.is_active = False

    def record_trade(self, pnl: float):
        """记录交易结果"""
        self.daily_pnl += pnl
        if pnl < 0:
            self.consecutive_losses += 1
        else:
            self.consecutive_losses = 0

    def check(self) -> dict:
        """检查是否触发熔断"""
        now = datetime.now()
        reasons = []

        # 冷却期检查
        if self.last_break_time:
            if now < self.last_break_time + timedelta(hours=self.cooldown_hours):
                return {'triggered': True, 'reason': '冷却期内'}

        # 日亏损限额
        daily_loss_pct = self.daily_pnl / self.daily_start_equity if self.daily_start_equity > 0 else 0
        if daily_loss_pct < -self.daily_loss_limit:
            reasons.append(f'日亏损{daily_loss_pct:.2%}超过限制')

        # 连续亏损
        if self.consecutive_losses >= self.consecutive_loss_limit:
            reasons.append(f'连续亏损{self.consecutive_losses}次')

        if reasons:
            self.is_active = True
            self.last_break_time = now
            return {'triggered': True, 'reason': '; '.join(reasons)}

        return {'triggered': False, 'reason': None}

    def should_trade(self) -> bool:
        """是否允许交易"""
        return not self.is_active
```

## Common Patterns

### 1. 综合风控管道

```python
class RiskPipeline:
    """风控检查管道 - 交易前依次检查所有风控规则"""

    def __init__(self):
        self.rules = []

    def add_rule(self, name: str, check_fn):
        self.rules.append((name, check_fn))

    def pre_trade_check(self, trade_request: dict) -> dict:
        for name, check_fn in self.rules:
            result = check_fn(trade_request)
            if not result['passed']:
                return {'allowed': False, 'blocked_by': name, 'reason': result['reason']}
        return {'allowed': True}

# 使用示例
pipeline = RiskPipeline()
pipeline.add_rule('position_limit', lambda t: check_position_limit(t))
pipeline.add_rule('drawdown', lambda t: check_drawdown(t))
pipeline.add_rule('circuit_breaker', lambda t: check_circuit_breaker(t))
```

### 2. 动态仓位缩放

```python
def scale_position(base_size: int, drawdown: float, volatility: float,
                   target_vol: float = 0.15) -> int:
    """根据回撤和波动率动态调整仓位"""
    vol_scale = target_vol / volatility if volatility > 0 else 1.0
    dd_scale = max(0.2, 1 - drawdown / 0.15)
    return int(base_size * vol_scale * dd_scale)
```

### 3. 多层级止损

```python
def multi_level_stop(entry: float, atr: float) -> dict:
    """多层级止损：硬止损 + 追踪止损 + 时间止损"""
    return {
        'hard_stop': entry * 0.95,
        'atr_stop': entry - 2 * atr,
        'trailing_pct': 0.08,
        'max_days': 30
    }
```

## References

- [Kelly Criterion - Wikipedia](https://en.wikipedia.org/wiki/Kelly_criterion)
- 《Quantitative Risk Management》 - Alexander J. McNeil
- 《Algorithmic Trading》 - Ernest Chan (Chapter: Risk Management)
- [vnpy Risk Management Module](https://www.vnpy.com/docs/cn/index.html)
- 《The Man Who Solved the Market》 - Gregory Zuckerman
