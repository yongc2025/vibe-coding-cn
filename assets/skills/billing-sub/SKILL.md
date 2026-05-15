---
name: billing-sub
description: SaaS 计费与订阅系统设计与实现。覆盖 Stripe API 集成、订阅管理、发票生成、用量计费、套餐管理、退款处理。支持按量/包月/阶梯等多种计费模型。支持 Python/Node.js。
---

# Billing & Subscription Skill

## When to Use This Skill

- 集成 Stripe / Paddle / LemonSqueezy 等支付网关
- 设计订阅生命周期管理（创建、升级、降级、取消、续费）
- 实现按量计费（Usage-based Billing）或阶梯计费
- 生成发票、处理退款、管理套餐（Plan / Price）
- 处理 Webhook 事件（支付成功、订阅更新、支付失败等）
- 设计计费系统的数据库模型和 API

## Not For / Boundaries

- **不适用于**：加密货币支付、线下支付、纯广告变现模式
- **不负责**：用户认证（见 oauth-sso skill）、多租户隔离（见 multi-tenant skill）
- **不覆盖**：税务合规（VAT/GST）的详细法律咨询，仅提供技术实现参考
- **注意**：支付涉及真实资金，上线前务必在测试环境充分验证

---

## Quick Reference

### 计费模型对比

| 模型 | 适用场景 | Stripe 实现 |
|------|---------|------------|
| 固定包月 | SaaS 基础套餐 | `recurring` price + `subscription` |
| 按量计费 | API 调用、存储用量 | `metered` price + `usage_record` |
| 阶梯计费 | 用量越大单价越低 | `tiered` pricing |
| 免费试用 | 获客转化 | `trial_period_days` |
| 混合模式 | 基础费 + 用量费 | 多个 line item |

### 1. Stripe 集成基础（Python）

```python
# stripe_config.py
import stripe
from dataclasses import dataclass

stripe.api_key = "sk_test_xxx"  # 从环境变量读取

@dataclass
class PriceConfig:
    """价格配置"""
    stripe_price_id: str
    name: str
    amount: int          # 分为单位
    currency: str = "usd"
    interval: str = "month"  # month / year
    tier: str = "pro"

PLANS = {
    "free": PriceConfig("price_free", "Free", 0, tier="free"),
    "pro_monthly": PriceConfig("price_pro_monthly", "Pro Monthly", 2900, tier="pro"),
    "pro_yearly": PriceConfig("price_pro_yearly", "Pro Yearly", 29000, tier="pro"),
    "enterprise": PriceConfig("price_enterprise", "Enterprise", 9900, tier="enterprise"),
}
```

```python
# subscription_service.py - 订阅管理服务
import stripe
from datetime import datetime, timezone

class SubscriptionService:
    """订阅生命周期管理"""

    def create_customer(self, user_id: str, email: str, tenant_id: str = None) -> str:
        """创建 Stripe Customer"""
        metadata = {"user_id": user_id}
        if tenant_id:
            metadata["tenant_id"] = tenant_id

        customer = stripe.Customer.create(
            email=email,
            metadata=metadata,
            description=f"User {user_id}",
        )
        return customer.id

    def create_checkout_session(
        self,
        customer_id: str,
        price_id: str,
        success_url: str,
        cancel_url: str,
        trial_days: int = 0,
    ) -> str:
        """创建 Stripe Checkout 会话（推荐方式）"""
        params = {
            "customer": customer_id,
            "payment_method_types": ["card"],
            "line_items": [{"price": price_id, "quantity": 1}],
            "mode": "subscription",
            "success_url": success_url,
            "cancel_url": cancel_url,
            "metadata": {"initiated_by": "checkout"},
        }
        if trial_days > 0:
            params["subscription_data"] = {"trial_period_days": trial_days}

        session = stripe.checkout.Session.create(**params)
        return session.url

    def upgrade_subscription(self, subscription_id: str, new_price_id: str) -> dict:
        """升级/降级订阅（立即生效）"""
        sub = stripe.Subscription.retrieve(subscription_id)
        updated = stripe.Subscription.modify(
            subscription_id,
            items=[{
                "id": sub["items"]["data"][0].id,
                "price": new_price_id,
            }],
            proration_behavior="always_invoice",  # 立即按比例计费
            payment_behavior="error_if_incomplete",
        )
        return {
            "subscription_id": updated.id,
            "status": updated.status,
            "current_period_end": datetime.fromtimestamp(
                updated.current_period_end, tz=timezone.utc
            ).isoformat(),
        }

    def cancel_subscription(self, subscription_id: str, immediate: bool = False) -> dict:
        """取消订阅"""
        if immediate:
            result = stripe.Subscription.delete(subscription_id)
        else:
            # 当期结束后取消
            result = stripe.Subscription.modify(
                subscription_id,
                cancel_at_period_end=True,
            )
        return {
            "subscription_id": result.id,
            "status": result.status,
            "cancel_at": getattr(result, "cancel_at", None),
        }

    def get_subscription(self, subscription_id: str) -> dict:
        """获取订阅详情"""
        sub = stripe.Subscription.retrieve(subscription_id)
        return {
            "id": sub.id,
            "status": sub.status,
            "current_period_start": sub.current_period_start,
            "current_period_end": sub.current_period_end,
            "plan": sub["items"]["data"][0].price.id,
            "cancel_at_period_end": sub.cancel_at_period_end,
            "trial_end": sub.trial_end,
        }
```

### 2. 用量计费（Usage-based Billing）

```python
# usage_service.py - 用量记录与计费
import stripe
import time
from datetime import datetime

class UsageService:
    """用量计费服务"""

    def record_usage(
        self,
        subscription_item_id: str,
        quantity: int,
        timestamp: int = None,
        action: str = "increment",  # increment / set
    ) -> dict:
        """记录用量（如 API 调用次数、存储 GB 等）"""
        if timestamp is None:
            timestamp = int(time.time())

        usage = stripe.SubscriptionItem.create_usage_record(
            subscription_item_id,
            quantity=quantity,
            timestamp=timestamp,
            action=action,
        )
        return {
            "usage_id": usage.id,
            "quantity": quantity,
            "timestamp": timestamp,
        }

    def get_usage_summary(self, subscription_item_id: str) -> dict:
        """获取当期用量汇总"""
        summaries = stripe.SubscriptionItem.list_usage_record_summaries(
            subscription_item_id,
            limit=100,
        )
        total = sum(s.total_usage for s in summaries.data)
        return {
            "total_usage": total,
            "periods": [
                {
                    "start": s.period.start,
                    "end": s.period.end,
                    "usage": s.total_usage,
                }
                for s in summaries.data
            ],
        }

# middleware 中集成用量记录
class UsageTracker:
    """请求中间件中自动追踪 API 用量"""

    def __init__(self, usage_service: UsageService, db):
        self.usage_service = usage_service
        self.db = db

    async def track_api_call(self, tenant_id: str, endpoint: str):
        """记录一次 API 调用"""
        # 获取租户的用量计费订阅项
        sub_item = self.db.query(SubscriptionItem).filter(
            SubscriptionItem.tenant_id == tenant_id,
            SubscriptionItem.billing_type == "metered",
        ).first()

        if sub_item:
            self.usage_service.record_usage(
                subscription_item_id=sub_item.stripe_subscription_item_id,
                quantity=1,
                action="increment",
            )

        # 同时记录到本地数据库用于分析
        self.db.add(UsageRecord(
            tenant_id=tenant_id,
            endpoint=endpoint,
            quantity=1,
            recorded_at=datetime.utcnow(),
        ))
        self.db.commit()
```

### 3. Webhook 处理

```python
# webhook_handler.py - Stripe Webhook 处理
import stripe
from flask import Flask, request, jsonify

app = Flask(__name__)
WEBHOOK_SECRET = "whsec_xxx"  # 从环境变量读取

@app.route("/webhooks/stripe", methods=["POST"])
def stripe_webhook():
    payload = request.get_data()
    sig_header = request.headers.get("Stripe-Signature")

    try:
        event = stripe.Webhook.construct_event(payload, sig_header, WEBHOOK_SECRET)
    except ValueError:
        return "Invalid payload", 400
    except stripe.error.SignatureVerificationError:
        return "Invalid signature", 400

    handler = WEBHOOK_HANDLERS.get(event["type"])
    if handler:
        handler(event["data"]["object"])
    else:
        print(f"Unhandled event type: {event['type']}")

    return jsonify({"status": "ok"}), 200

# Webhook 事件处理器映射
WEBHOOK_HANDLERS = {}

def webhook_handler(event_type: str):
    """装饰器注册 webhook 处理器"""
    def decorator(func):
        WEBHOOK_HANDLERS[event_type] = func
        return func
    return decorator

@webhook_handler("checkout.session.completed")
def handle_checkout_completed(session):
    """Checkout 完成 → 激活订阅"""
    customer_id = session["customer"]
    subscription_id = session["subscription"]
    print(f"Checkout completed: customer={customer_id}, sub={subscription_id}")
    # 更新本地数据库订阅状态
    # db.update_subscription(customer_id, subscription_id, status="active")

@webhook_handler("invoice.payment_succeeded")
def handle_payment_succeeded(invoice):
    """支付成功 → 续期确认"""
    subscription_id = invoice["subscription"]
    print(f"Payment succeeded for subscription: {subscription_id}")
    # 确认订阅续期，更新到期时间

@webhook_handler("invoice.payment_failed")
def handle_payment_failed(invoice):
    """支付失败 → 通知用户"""
    customer_id = invoice["customer"]
    subscription_id = invoice["subscription"]
    print(f"Payment failed: customer={customer_id}, sub={subscription_id}")
    # 发送支付失败邮件
    # 进入 dunning（催收）流程

@webhook_handler("customer.subscription.updated")
def handle_subscription_updated(subscription):
    """订阅更新（升级/降级/取消）"""
    print(f"Subscription updated: {subscription['id']}, status={subscription['status']}")

@webhook_handler("customer.subscription.deleted")
def handle_subscription_deleted(subscription):
    """订阅删除 → 降级到 Free"""
    print(f"Subscription deleted: {subscription['id']}")
    # 将用户降级到免费套餐
```

### 4. Node.js (Stripe + Express) 示例

```javascript
// subscription.controller.ts
import Stripe from 'stripe';
import express from 'express';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const router = express.Router();

// 创建 Checkout Session
router.post('/subscriptions/checkout', async (req, res) => {
  const { priceId, userId, tenantId } = req.body;

  // 查找或创建 Customer
  let customer;
  const existing = await stripe.customers.search({
    query: `metadata["user_id"]:"${userId}"`,
  });
  if (existing.data.length > 0) {
    customer = existing.data[0];
  } else {
    customer = await stripe.customers.create({
      email: req.user.email,
      metadata: { user_id: userId, tenant_id: tenantId },
    });
  }

  const session = await stripe.checkout.sessions.create({
    customer: customer.id,
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    mode: 'subscription',
    success_url: `${process.env.APP_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.APP_URL}/billing/cancel`,
    subscription_data: {
      trial_period_days: 14,
      metadata: { tenant_id: tenantId },
    },
  });

  res.json({ url: session.url });
});

// Webhook 处理
router.post('/webhooks/stripe',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    let event;

    try {
      event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;
        await activateSubscription(session.customer, session.subscription);
        break;
      }
      case 'invoice.payment_failed': {
        const invoice = event.data.object;
        await handleFailedPayment(invoice.customer, invoice.subscription);
        break;
      }
      case 'customer.subscription.deleted': {
        const subscription = event.data.object;
        await downgradeToFree(subscription.customer);
        break;
      }
    }

    res.json({ received: true });
  }
);

// 用量上报
router.post('/usage', async (req, res) => {
  const { subscriptionItemId, quantity } = req.body;

  const usageRecord = await stripe.subscriptionItems.createUsageRecord(
    subscriptionItemId,
    {
      quantity,
      timestamp: Math.floor(Date.now() / 1000),
      action: 'increment',
    }
  );

  res.json({ usageId: usageRecord.id, quantity });
});

export default router;
```

### 5. 阶梯计费实现

```python
# tiered_pricing.py - 阶梯计费
class TieredPricing:
    """
    阶梯计费示例：
    0-1000 次:    免费
    1001-10000 次: $0.01/次
    10001-100000 次: $0.005/次
    100000+ 次:   $0.001/次
    """

    TIERS = [
        {"up_to": 1000,    "unit_price": 0},
        {"up_to": 10000,   "unit_price": 0.01},
        {"up_to": 100000,  "unit_price": 0.005},
        {"up_to": None,    "unit_price": 0.001},  # None = 无上限
    ]

    @classmethod
    def calculate(cls, quantity: int) -> float:
        total = 0.0
        remaining = quantity

        for tier in cls.TIERS:
            if remaining <= 0:
                break

            cap = tier["up_to"] or remaining
            tier_quantity = min(remaining, cap)
            total += tier_quantity * tier["unit_price"]
            remaining -= tier_quantity

        return round(total, 2)

# Stripe 中配置阶梯价格（通过 API 创建）
def create_tiered_price():
    return stripe.Price.create(
        currency="usd",
        recurring={"interval": "month", "usage_type": "metered"},
        billing_scheme="tiered",
        tiers_mode="graduated",  # graduated = 阶梯递减
        tiers=[
            {"up_to": 1000, "unit_amount": 0},
            {"up_to": 10000, "unit_amount": 1},      # $0.01
            {"up_to": 100000, "unit_amount": 50},     # $0.50 (注意: Stripe 用分为单位)
            {"up_to": "inf", "unit_amount": 10},      # $0.10
        ],
        product="prod_xxx",
    )
```

### 6. 发票生成

```python
# invoice_service.py
import stripe
from datetime import datetime

class InvoiceService:
    def create_invoice_item(self, customer_id: str, amount: int, description: str):
        """添加自定义发票项（如一次性费用）"""
        stripe.InvoiceItem.create(
            customer=customer_id,
            amount=amount,  # 分为单位
            currency="usd",
            description=description,
        )

    def create_and_finalize_invoice(self, customer_id: str) -> str:
        """创建并发送发票"""
        invoice = stripe.Invoice.create(
            customer=customer_id,
            auto_advance=True,  # 自动尝试支付
            collection_method="charge_automatically",
            metadata={"generated_by": "system"},
        )
        invoice = stripe.Invoice.finalize_invoice(invoice.id)
        return invoice.hosted_invoice_url

    def upcoming_invoice(self, customer_id: str) -> dict:
        """预览下次发票（用于显示升级费用）"""
        invoice = stripe.Invoice.upcoming(customer_id=customer_id)
        return {
            "amount_due": invoice.amount_due,
            "period_start": invoice.period_start,
            "period_end": invoice.period_end,
            "lines": [
                {
                    "description": line.description,
                    "amount": line.amount,
                    "quantity": line.quantity,
                }
                for line in invoice.lines.data
            ],
        }
```

---

## Common Patterns

### 1. 订阅状态机

```
                    ┌─────────────┐
                    │   created   │
                    └──────┬──────┘
                           │ checkout.session.completed
                    ┌──────▼──────┐
           ┌───────►│   active    │◄──────┐
           │        └──────┬──────┘       │
           │               │              │
           │    ┌──────────┼──────────┐   │
           │    │          │          │   │
    payment_ok  │   cancel │  upgrade │   │
           │    │          │          │   │
           │    ▼          ▼          │   │
           │ ┌──────┐ ┌──────────┐   │   │
           │ │ past │ │ canceling│   │   │
           │ │ due  │ │(at end)  │   │   │
           │ └──┬───┘ └────┬─────┘   │   │
           │    │          │         │   │
           │    │     period_end     │   │
           │    │          │         │   │
           │    │          ▼         │   │
           │    │    ┌──────────┐    │   │
           │    └───►│ canceled │    │   │
           │         └──────────┘    │   │
           │                         │   │
           └─────────────────────────┘   │
                                         │
                reactivate ──────────────┘
```

### 2. 幂等性设计

```python
# 幂等性是计费系统的核心要求
class IdempotentBilling:
    def __init__(self, db):
        self.db = db

    def charge_with_idempotency(self, customer_id: str, amount: int, idempotency_key: str):
        """带幂等键的扣费"""
        # 先检查是否已处理
        existing = self.db.query(IdempotencyRecord).filter_by(key=idempotency_key).first()
        if existing:
            return existing.result  # 返回之前的结果

        # 创建 Stripe PaymentIntent
        intent = stripe.PaymentIntent.create(
            customer=customer_id,
            amount=amount,
            currency="usd",
            idempotency_key=idempotency_key,
        )

        # 记录幂等结果
        record = IdempotencyRecord(key=idempotency_key, result=intent)
        self.db.add(record)
        self.db.commit()

        return intent
```

### 3. 套餐特性门控（Feature Gating）

```python
# feature_gate.py
from functools import wraps

PLAN_FEATURES = {
    "free": {"api_calls": 1000, "users": 5, "storage_gb": 1, "sso": False, "audit_log": False},
    "pro": {"api_calls": 100000, "users": 50, "storage_gb": 100, "sso": True, "audit_log": True},
    "enterprise": {"api_calls": -1, "users": -1, "storage_gb": -1, "sso": True, "audit_log": True},
}

def require_feature(feature_name: str):
    """装饰器：检查当前租户是否有权使用某功能"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            tenant_id = get_tenant()
            plan = get_tenant_plan(tenant_id)
            features = PLAN_FEATURES.get(plan, PLAN_FEATURES["free"])

            if not features.get(feature_name, False):
                raise PermissionError(
                    f"Feature '{feature_name}' requires {plan} plan or higher"
                )
            return await func(*args, **kwargs)
        return wrapper
    return decorator

# 使用
@require_feature("sso")
async def configure_sso(tenant_id: str, sso_config: dict):
    """配置 SSO（仅 Pro 及以上套餐）"""
    pass

@require_feature("audit_log")
async def get_audit_logs(tenant_id: str):
    """获取审计日志（仅 Pro 及以上套餐）"""
    pass
```

### 4. 试用期转化流程

```python
# trial_flow.py
class TrialManager:
    async def start_trial(self, user_id: str, plan: str = "pro", days: int = 14):
        """开始免费试用"""
        customer = await self.create_stripe_customer(user_id)
        subscription = stripe.Subscription.create(
            customer=customer.id,
            items=[{"price": PLANS[plan].stripe_price_id}],
            trial_period_days=days,
            metadata={"trial": "true"},
        )
        # 记录试用开始
        await self.db.update_user(user_id, {
            "subscription_status": "trialing",
            "trial_end": datetime.fromtimestamp(subscription.trial_end),
        })
        return subscription

    async def convert_trial(self, user_id: str, payment_method_id: str):
        """试用转付费"""
        subscription = await self.get_user_subscription(user_id)
        stripe.Subscription.modify(
            subscription.id,
            default_payment_method=payment_method_id,
            trial_end="now",  # 立即结束试用
        )
        await self.db.update_user(user_id, {
            "subscription_status": "active",
        })
```

---

## References

- [Stripe API Reference](https://stripe.com/docs/api) — 完整的 Stripe API 文档
- [Stripe Checkout](https://stripe.com/docs/payments/checkout) — 预构建支付页面
- [Stripe Billing](https://stripe.com/docs/billing) — 订阅与计费文档
- [Stripe Webhooks](https://stripe.com/docs/webhooks) — Webhook 事件与验证
- [Stripe Testing](https://stripe.com/docs/testing) — 测试卡号与模拟场景
- [Paddle API](https://developer.paddle.com/) — 替代支付网关（MoR 模式）
- [LemonSqueezy API](https://docs.lemonsqueezy.com/) — 轻量级支付网关
- [Subscription Billing Best Practices](https://stripe.com/docs/billing/subscriptions/overview) — 订阅计费最佳实践
