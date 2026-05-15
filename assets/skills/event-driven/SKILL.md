---
name: event-driven
description: 事件驱动架构设计与实现。覆盖事件溯源 (Event Sourcing)、CQRS、Saga 模式、事件总线。支持 Kafka/RabbitMQ/Redis Streams 集成，提供 Java/Python/Go 完整代码示例。适用于微服务间的异步通信与最终一致性场景。
---

# Event-Driven Architecture Skill

## When to Use This Skill

- 设计事件驱动的微服务通信架构
- 实现 Event Sourcing（事件溯源）存储业务状态
- 构建 CQRS（命令查询职责分离）读写模型
- 实现 Saga 模式管理分布式事务
- 集成 Kafka / RabbitMQ / Redis Streams 作为事件总线
- 处理事件版本管理、Schema 演进、最终一致性

## Not For / Boundaries

- **不适用于**：简单的 CRUD 应用、同步调用足够满足需求的场景
- **不负责**：消息队列的运维部署（Broker 配置、集群管理）
- **不覆盖**：实时流计算（Flink/Spark Streaming），本 skill 侧重业务事件
- **注意**：Event Sourcing 增加系统复杂度，需评估是否真正需要

---

## Quick Reference

### 架构模式对比

| 模式 | 核心思想 | 适用场景 | 复杂度 |
|------|---------|---------|--------|
| Event Sourcing | 存储事件而非状态 | 需要完整审计轨迹、时序回放 | 高 |
| CQRS | 读写模型分离 | 读写性能差异大、读模型多样化 | 中高 |
| Saga | 分布式事务编排 | 跨服务长事务 | 中 |
| Event Bus | 服务间异步通信 | 解耦服务依赖 | 低中 |

### 1. Event Sourcing 核心实现（Python）

```python
# events.py - 事件定义
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any
import uuid

@dataclass(frozen=True)
class DomainEvent:
    """领域事件基类"""
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    event_type: str = ""
    aggregate_id: str = ""
    aggregate_type: str = ""
    version: int = 0
    timestamp: datetime = field(default_factory=datetime.utcnow)
    data: dict = field(default_factory=dict)
    metadata: dict = field(default_factory=dict)

# 具体事件定义
@dataclass(frozen=True)
class OrderCreated(DomainEvent):
    event_type: str = "order.created"
    aggregate_type: str = "Order"

@dataclass(frozen=True)
class OrderItemAdded(DomainEvent):
    event_type: str = "order.item_added"
    aggregate_type: str = "Order"

@dataclass(frozen=True)
class OrderConfirmed(DomainEvent):
    event_type: str = "order.confirmed"
    aggregate_type: str = "Order"

@dataclass(frozen=True)
class OrderShipped(DomainEvent):
    event_type: str = "order.shipped"
    aggregate_type: str = "Order"

@dataclass(frozen=True)
class OrderCancelled(DomainEvent):
    event_type: str = "order.cancelled"
    aggregate_type: str = "Order"
```

```python
# event_store.py - 事件存储
from typing import List, Optional
import json

class EventStore:
    """
    事件存储 - Event Sourcing 的核心
    只追加 (append-only)，不更新，不删除
    """

    def __init__(self, db_connection):
        self.db = db_connection
        self._init_schema()

    def _init_schema(self):
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS events (
                event_id VARCHAR(36) PRIMARY KEY,
                aggregate_id VARCHAR(36) NOT NULL,
                aggregate_type VARCHAR(100) NOT NULL,
                event_type VARCHAR(100) NOT NULL,
                version INT NOT NULL,
                data JSONB NOT NULL,
                metadata JSONB DEFAULT '{}',
                timestamp TIMESTAMP DEFAULT NOW(),
                UNIQUE(aggregate_id, version)
            )
        """)
        self.db.execute("""
            CREATE INDEX IF NOT EXISTS idx_events_aggregate
            ON events (aggregate_id, version)
        """)
        self.db.execute("""
            CREATE INDEX IF NOT EXISTS idx_events_type
            ON events (event_type, timestamp)
        """)

    def append(self, event: DomainEvent, expected_version: int = -1) -> None:
        """
        追加事件（乐观并发控制）
        expected_version = -1 表示新建聚合
        """
        try:
            if expected_version >= 0:
                # 乐观锁：检查当前版本
                result = self.db.execute(
                    "SELECT MAX(version) FROM events WHERE aggregate_id = %s",
                    (event.aggregate_id,)
                )
                current_version = result.fetchone()[0] or 0
                if current_version != expected_version:
                    raise ConcurrencyError(
                        f"Expected version {expected_version}, got {current_version}"
                    )

            self.db.execute(
                """INSERT INTO events
                   (event_id, aggregate_id, aggregate_type, event_type, version, data, metadata, timestamp)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                (event.event_id, event.aggregate_id, event.aggregate_type,
                 event.event_type, event.version, json.dumps(event.data),
                 json.dumps(event.metadata), event.timestamp)
            )
            self.db.commit()
        except IntegrityError:
            raise ConcurrencyError("Concurrent write detected")

    def get_events(self, aggregate_id: str, from_version: int = 0) -> List[DomainEvent]:
        """获取聚合的所有事件（按版本排序）"""
        rows = self.db.execute(
            """SELECT event_id, aggregate_id, aggregate_type, event_type,
                      version, data, metadata, timestamp
               FROM events
               WHERE aggregate_id = %s AND version > %s
               ORDER BY version ASC""",
            (aggregate_id, from_version)
        ).fetchall()

        return [
            DomainEvent(
                event_id=row[0], aggregate_id=row[1], aggregate_type=row[2],
                event_type=row[3], version=row[4], data=json.loads(row[5]),
                metadata=json.loads(row[6]), timestamp=row[7],
            )
            for row in rows
        ]

    def get_events_by_type(self, event_type: str, since: datetime = None) -> List[DomainEvent]:
        """按事件类型查询（用于投影/快照重建）"""
        query = "SELECT * FROM events WHERE event_type = %s"
        params = [event_type]
        if since:
            query += " AND timestamp > %s"
            params.append(since)
        query += " ORDER BY timestamp ASC"
        rows = self.db.execute(query, params).fetchall()
        return [self._row_to_event(row) for row in rows]

class ConcurrencyError(Exception):
    pass
```

```python
# aggregate.py - 聚合根基类
from typing import List

class AggregateRoot:
    """聚合根基类 - 状态通过事件重放构建"""

    def __init__(self, aggregate_id: str):
        self.id = aggregate_id
        self.version = 0
        self._pending_events: List[DomainEvent] = []

    def raise_event(self, event: DomainEvent) -> None:
        """产生新事件"""
        event = DomainEvent(
            event_id=event.event_id,
            event_type=event.event_type,
            aggregate_id=self.id,
            aggregate_type=event.aggregate_type,
            version=self.version + 1,
            data=event.data,
            metadata=event.metadata,
        )
        self._pending_events.append(event)
        self._apply(event)

    def _apply(self, event: DomainEvent) -> None:
        """应用事件到聚合状态（子类实现）"""
        raise NotImplementedError

    def load_from_history(self, events: List[DomainEvent]) -> None:
        """从历史事件重建聚合状态"""
        for event in events:
            self._apply(event)
            self.version = event.version

    def get_uncommitted_events(self) -> List[DomainEvent]:
        return self._pending_events.copy()

    def clear_uncommitted_events(self):
        self._pending_events.clear()
```

```python
# order_aggregate.py - 订单聚合示例
from enum import Enum

class OrderStatus(Enum):
    DRAFT = "draft"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"

class Order(AggregateRoot):
    """订单聚合 - 状态完全由事件驱动"""

    def __init__(self, order_id: str):
        super().__init__(order_id)
        self.customer_id: str = ""
        self.items: list = []
        self.status: OrderStatus = OrderStatus.DRAFT
        self.total: float = 0.0

    # ===== 命令方法（产生事件） =====

    def create(self, customer_id: str):
        self.raise_event(OrderCreated(
            aggregate_id=self.id,
            data={"customer_id": customer_id, "status": "draft"},
        ))

    def add_item(self, product_id: str, quantity: int, price: float):
        if self.status != OrderStatus.DRAFT:
            raise ValueError("Can only add items to draft orders")
        self.raise_event(OrderItemAdded(
            aggregate_id=self.id,
            data={"product_id": product_id, "quantity": quantity, "price": price},
        ))

    def confirm(self):
        if self.status != OrderStatus.DRAFT:
            raise ValueError("Can only confirm draft orders")
        if not self.items:
            raise ValueError("Cannot confirm empty order")
        self.raise_event(OrderConfirmed(
            aggregate_id=self.id,
            data={"total": self.total},
        ))

    def ship(self):
        if self.status != OrderStatus.CONFIRMED:
            raise ValueError("Can only ship confirmed orders")
        self.raise_event(OrderShipped(
            aggregate_id=self.id,
            data={"shipped_at": datetime.utcnow().isoformat()},
        ))

    def cancel(self, reason: str = ""):
        if self.status in (OrderStatus.SHIPPED, OrderStatus.CANCELLED):
            raise ValueError(f"Cannot cancel order in {self.status} state")
        self.raise_event(OrderCancelled(
            aggregate_id=self.id,
            data={"reason": reason},
        ))

    # ===== 事件应用方法（更新状态） =====

    def _apply(self, event: DomainEvent):
        handler = {
            "order.created": self._apply_created,
            "order.item_added": self._apply_item_added,
            "order.confirmed": self._apply_confirmed,
            "order.shipped": self._apply_shipped,
            "order.cancelled": self._apply_cancelled,
        }.get(event.event_type)
        if handler:
            handler(event)
        self.version = event.version

    def _apply_created(self, event: DomainEvent):
        self.customer_id = event.data["customer_id"]
        self.status = OrderStatus.DRAFT

    def _apply_item_added(self, event: DomainEvent):
        self.items.append(event.data)
        self.total += event.data["quantity"] * event.data["price"]

    def _apply_confirmed(self, event: DomainEvent):
        self.status = OrderStatus.CONFIRMED

    def _apply_shipped(self, event: DomainEvent):
        self.status = OrderStatus.SHIPPED

    def _apply_cancelled(self, event: DomainEvent):
        self.status = OrderStatus.CANCELLED
```

```python
# repository.py - 事件溯源仓储
class EventSourcedRepository:
    """基于事件存储的仓储"""

    def __init__(self, event_store: EventStore, aggregate_class):
        self.event_store = event_store
        self.aggregate_class = aggregate_class

    def load(self, aggregate_id: str) -> AggregateRoot:
        """从事件历史重建聚合"""
        events = self.event_store.get_events(aggregate_id)
        if not events:
            raise NotFoundError(f"Aggregate {aggregate_id} not found")

        aggregate = self.aggregate_class(aggregate_id)
        aggregate.load_from_history(events)
        return aggregate

    def save(self, aggregate: AggregateRoot) -> None:
        """保存未提交的事件"""
        events = aggregate.get_uncommitted_events()
        if not events:
            return

        for event in events:
            self.event_store.append(event, expected_version=event.version - 1)

        aggregate.clear_uncommitted_events()
```

### 2. CQRS 实现

```python
# cqrs.py - 命令查询职责分离
from abc import ABC, abstractmethod

# ==================== 命令端 (Write Side) ====================

class Command(ABC):
    pass

class CreateOrder(Command):
    def __init__(self, order_id: str, customer_id: str):
        self.order_id = order_id
        self.customer_id = customer_id

class AddOrderItem(Command):
    def __init__(self, order_id: str, product_id: str, quantity: int, price: float):
        self.order_id = order_id
        self.product_id = product_id
        self.quantity = quantity
        self.price = price

class CommandHandler(ABC):
    @abstractmethod
    def handle(self, command: Command): pass

class CreateOrderHandler(CommandHandler):
    def __init__(self, repository: EventSourcedRepository):
        self.repository = repository

    def handle(self, command: CreateOrder):
        order = Order(command.order_id)
        order.create(command.customer_id)
        self.repository.save(order)
        return order

class AddOrderItemHandler(CommandHandler):
    def __init__(self, repository: EventSourcedRepository):
        self.repository = repository

    def handle(self, command: AddOrderItem):
        order = self.repository.load(command.order_id)
        order.add_item(command.product_id, command.quantity, command.price)
        self.repository.save(order)
        return order

# ==================== 查询端 (Read Side) ====================

class Query(ABC):
    pass

class GetOrderSummary(Query):
    def __init__(self, order_id: str):
        self.order_id = order_id

class ListOrdersByCustomer(Query):
    def __init__(self, customer_id: str, page: int = 1, size: int = 20):
        self.customer_id = customer_id
        self.page = page
        self.size = size

class QueryHandler(ABC):
    @abstractmethod
    def handle(self, query: Query): pass

class GetOrderSummaryHandler(QueryHandler):
    """查询端从读模型获取数据（投影表）"""
    def __init__(self, read_db):
        self.read_db = read_db

    def handle(self, query: GetOrderSummary) -> dict:
        row = self.read_db.execute(
            "SELECT * FROM order_read_model WHERE order_id = %s",
            (query.order_id,)
        ).fetchone()
        if not row:
            raise NotFoundError(f"Order {query.order_id} not found")
        return dict(row)

# ==================== 投影器 (Projector) ====================

class OrderProjector:
    """
    监听事件，维护读模型
    这是 CQRS 中连接写端和读端的桥梁
    """

    def __init__(self, read_db):
        self.read_db = read_db
        self._init_read_model()

    def _init_read_model(self):
        self.read_db.execute("""
            CREATE TABLE IF NOT EXISTS order_read_model (
                order_id VARCHAR(36) PRIMARY KEY,
                customer_id VARCHAR(36),
                status VARCHAR(20),
                items JSONB DEFAULT '[]',
                total DECIMAL(10,2) DEFAULT 0,
                item_count INT DEFAULT 0,
                created_at TIMESTAMP,
                updated_at TIMESTAMP
            )
        """)

    def project(self, event: DomainEvent):
        """根据事件类型更新读模型"""
        handler = {
            "order.created": self._on_order_created,
            "order.item_added": self._on_item_added,
            "order.confirmed": self._on_order_confirmed,
            "order.shipped": self._on_order_shipped,
            "order.cancelled": self._on_order_cancelled,
        }.get(event.event_type)

        if handler:
            handler(event)

    def _on_order_created(self, event: DomainEvent):
        self.read_db.execute(
            """INSERT INTO order_read_model (order_id, customer_id, status, created_at)
               VALUES (%s, %s, %s, %s)""",
            (event.aggregate_id, event.data["customer_id"], "draft", event.timestamp)
        )

    def _on_item_added(self, event: DomainEvent):
        self.read_db.execute(
            """UPDATE order_read_model
               SET items = items || %s::jsonb,
                   item_count = item_count + 1,
                   total = total + %s,
                   updated_at = %s
               WHERE order_id = %s""",
            (json.dumps(event.data), event.data["quantity"] * event.data["price"],
             event.timestamp, event.aggregate_id)
        )

    def _on_order_confirmed(self, event: DomainEvent):
        self.read_db.execute(
            "UPDATE order_read_model SET status='confirmed', updated_at=%s WHERE order_id=%s",
            (event.timestamp, event.aggregate_id)
        )

    def _on_order_shipped(self, event: DomainEvent):
        self.read_db.execute(
            "UPDATE order_read_model SET status='shipped', updated_at=%s WHERE order_id=%s",
            (event.timestamp, event.aggregate_id)
        )

    def _on_order_cancelled(self, event: DomainEvent):
        self.read_db.execute(
            "UPDATE order_read_model SET status='cancelled', updated_at=%s WHERE order_id=%s",
            (event.timestamp, event.aggregate_id)
        )
```

### 3. Saga 模式（编排式）

```python
# saga.py - 分布式事务编排
from enum import Enum
from typing import Callable, List

class SagaStepStatus(Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    COMPENSATED = "compensated"

@dataclass
class SagaStep:
    name: str
    action: Callable       # 正向操作
    compensation: Callable # 补偿操作（回滚）
    status: SagaStepStatus = SagaStepStatus.PENDING

class SagaOrchestrator:
    """
    Saga 编排器 - 管理跨服务分布式事务
    正向执行，失败时反向补偿
    """

    def __init__(self, saga_id: str):
        self.saga_id = saga_id
        self.steps: List[SagaStep] = []
        self.completed_steps: List[SagaStep] = []
        self.status = "pending"

    def add_step(self, name: str, action: Callable, compensation: Callable):
        self.steps.append(SagaStep(name=name, action=action, compensation=compensation))
        return self

    async def execute(self, context: dict) -> dict:
        """执行 Saga"""
        self.status = "executing"

        for step in self.steps:
            try:
                print(f"[Saga {self.saga_id}] Executing step: {step.name}")
                result = await step.action(context)
                context[f"{step.name}_result"] = result
                step.status = SagaStepStatus.COMPLETED
                self.completed_steps.append(step)
                print(f"[Saga {self.saga_id}] Step {step.name} completed")
            except Exception as e:
                print(f"[Saga {self.saga_id}] Step {step.name} failed: {e}")
                step.status = SagaStepStatus.FAILED
                await self._compensate(context)
                self.status = "failed"
                return {"status": "failed", "failed_step": step.name, "error": str(e)}

        self.status = "completed"
        return {"status": "completed", "context": context}

    async def _compensate(self, context: dict):
        """反向执行补偿操作"""
        print(f"[Saga {self.saga_id}] Starting compensation...")
        for step in reversed(self.completed_steps):
            try:
                print(f"[Saga {self.saga_id}] Compensating step: {step.name}")
                await step.compensation(context)
                step.status = SagaStepStatus.COMPENSATED
                print(f"[Saga {self.saga_id}] Step {step.name} compensated")
            except Exception as e:
                # 补偿失败需要人工介入
                print(f"[Saga {self.saga_id}] CRITICAL: Compensation failed for {step.name}: {e}")
                self.status = "compensation_failed"
                # 记录到死信队列，等待人工处理
                raise

# ==================== 订单创建 Saga 示例 ====================

async def create_order_saga(order_data: dict):
    """
    订单创建 Saga:
    1. 验证库存 → 2. 创建订单 → 3. 扣减库存 → 4. 处理支付 → 5. 确认订单
    失败时反向补偿
    """

    context = {"order_data": order_data}

    saga = SagaOrchestrator(saga_id=f"order-{order_data['order_id']}")

    # Step 1: 验证库存
    saga.add_step(
        name="check_inventory",
        action=lambda ctx: inventory_service.check(
            ctx["order_data"]["items"]
        ),
        compensation=lambda ctx: None,  # 查询无需补偿
    )

    # Step 2: 创建订单（预创建，状态=pending）
    saga.add_step(
        name="create_order",
        action=lambda ctx: order_service.create_pending(
            ctx["order_data"]
        ),
        compensation=lambda ctx: order_service.cancel(
            ctx["order_data"]["order_id"], reason="saga_failed"
        ),
    )

    # Step 3: 扣减库存
    saga.add_step(
        name="reserve_inventory",
        action=lambda ctx: inventory_service.reserve(
            ctx["order_data"]["items"]
        ),
        compensation=lambda ctx: inventory_service.release(
            ctx["order_data"]["items"]
        ),
    )

    # Step 4: 处理支付
    saga.add_step(
        name="process_payment",
        action=lambda ctx: payment_service.charge(
            ctx["order_data"]["customer_id"],
            ctx["order_data"]["total"],
        ),
        compensation=lambda ctx: payment_service.refund(
            ctx["process_payment_result"]["payment_id"]
        ),
    )

    # Step 5: 确认订单
    saga.add_step(
        name="confirm_order",
        action=lambda ctx: order_service.confirm(
            ctx["order_data"]["order_id"]
        ),
        compensation=lambda ctx: order_service.cancel(
            ctx["order_data"]["order_id"], reason="saga_failed"
        ),
    )

    result = await saga.execute(context)
    return result
```

### 4. 事件总线（Go + Kafka）

```go
// event_bus.go - 事件总线
package eventbus

import (
    "context"
    "encoding/json"
    "log"
    "time"

    "github.com/segmentio/kafka-go"
)

type DomainEvent struct {
    EventID       string                 `json:"event_id"`
    EventType     string                 `json:"event_type"`
    AggregateID   string                 `json:"aggregate_id"`
    AggregateType string                 `json:"aggregate_type"`
    Version       int                    `json:"version"`
    Timestamp     time.Time              `json:"timestamp"`
    Data          map[string]interface{} `json:"data"`
    Metadata      map[string]interface{} `json:"metadata"`
}

type EventHandler func(ctx context.Context, event DomainEvent) error

type EventBus struct {
    writers   map[string]*kafka.Writer
    readers   map[string]*kafka.Reader
    handlers  map[string][]EventHandler
}

func NewEventBus(brokers []string) *EventBus {
    return &EventBus{
        writers:  make(map[string]*kafka.Writer),
        readers:  make(map[string]*kafka.Reader),
        handlers: make(map[string][]EventHandler),
    }
}

func (eb *EventBus) Publish(ctx context.Context, topic string, event DomainEvent) error {
    writer, ok := eb.writers[topic]
    if !ok {
        writer = &kafka.Writer{
            Addr:     kafka.TCP("localhost:9092"),
            Topic:    topic,
            Balancer: &kafka.Hash{},
        }
        eb.writers[topic] = writer
    }

    data, err := json.Marshal(event)
    if err != nil {
        return err
    }

    return writer.WriteMessages(ctx, kafka.Message{
        Key:   []byte(event.AggregateID),
        Value: data,
    })
}

func (eb *EventBus) Subscribe(topic string, groupID string, handler EventHandler) {
    reader := kafka.NewReader(kafka.ReaderConfig{
        Brokers:  []string{"localhost:9092"},
        Topic:    topic,
        GroupID:  groupID,
        MinBytes: 1,
        MaxBytes: 10e6,
    })

    eb.handlers[topic] = append(eb.handlers[topic], handler)

    go func() {
        for {
            msg, err := reader.ReadMessage(context.Background())
            if err != nil {
                log.Printf("Error reading message: %v", err)
                continue
            }

            var event DomainEvent
            if err := json.Unmarshal(msg.Value, &event); err != nil {
                log.Printf("Error unmarshaling event: %v", err)
                continue
            }

            for _, h := range eb.handlers[topic] {
                if err := h(context.Background(), event); err != nil {
                    log.Printf("Error handling event %s: %v", event.EventType, err)
                    // 发送到死信队列
                }
            }
        }
    }()
}

// 使用示例
func ExampleUsage() {
    bus := NewEventBus([]string{"localhost:9092"})

    // 订阅订单事件
    bus.Subscribe("order-events", "inventory-service", func(ctx context.Context, event DomainEvent) error {
        switch event.EventType {
        case "order.confirmed":
            // 扣减库存
            return inventoryService.Reserve(ctx, event.Data)
        case "order.cancelled":
            // 释放库存
            return inventoryService.Release(ctx, event.Data)
        }
        return nil
    })

    // 发布事件
    event := DomainEvent{
        EventID:       uuid.New().String(),
        EventType:     "order.confirmed",
        AggregateID:   "order-123",
        AggregateType: "Order",
        Version:       1,
        Timestamp:     time.Now(),
        Data:          map[string]interface{}{"order_id": "order-123", "items": items},
    }
    bus.Publish(ctx, "order-events", event)
}
```

### 5. 事件版本管理与 Schema 演进

```python
# event_versioning.py - 事件版本升级
class EventUpcaster:
    """
    事件上转型 - 将旧版本事件转换为新版本
    支持渐进式 Schema 演进
    """

    def __init__(self):
        self._upcasters = {}  # (event_type, from_version) -> upcast_func

    def register(self, event_type: str, from_version: int, to_version: int, upcast_func):
        self._upcasters[(event_type, from_version)] = {
            "to_version": to_version,
            "upcast": upcast_func,
        }

    def upcast(self, event: DomainEvent) -> DomainEvent:
        """递归上转型到最新版本"""
        current = event
        while True:
            key = (current.event_type, current.version)
            if key not in self._upcasters:
                break
            upcaster = self._upcasters[key]
            current = upcaster["upcast"](current)
        return current

# 示例：订单创建事件从 v1 升级到 v2（增加了 currency 字段）
upcaster = EventUpcaster()

def upcast_order_created_v1_to_v2(event: DomainEvent) -> DomainEvent:
    return DomainEvent(
        event_id=event.event_id,
        event_type=event.event_type,
        aggregate_id=event.aggregate_id,
        aggregate_type=event.aggregate_type,
        version=2,
        timestamp=event.timestamp,
        data={
            **event.data,
            "currency": event.data.get("currency", "CNY"),  # 默认人民币
        },
        metadata=event.metadata,
    )

upcaster.register("order.created", from_version=1, to_version=2, upcast_func=upcast_order_created_v1_to_v2)
```

### 6. Redis Streams 轻量级事件总线（Python）

```python
# redis_event_bus.py
import redis
import json
from typing import Callable

class RedisEventBus:
    """基于 Redis Streams 的轻量级事件总线"""

    def __init__(self, redis_url: str = "redis://localhost:6379"):
        self.redis = redis.from_url(redis_url)

    def publish(self, stream: str, event: DomainEvent) -> str:
        """发布事件到 Stream"""
        event_data = {
            "event_id": event.event_id,
            "event_type": event.event_type,
            "aggregate_id": event.aggregate_id,
            "data": json.dumps(event.data),
            "timestamp": event.timestamp.isoformat(),
        }
        message_id = self.redis.xadd(stream, event_data)
        return message_id

    def subscribe(
        self,
        stream: str,
        group: str,
        consumer: str,
        handler: Callable[[DomainEvent], None],
        count: int = 10,
        block_ms: int = 5000,
    ):
        """消费事件（消费者组模式）"""
        # 创建消费者组（幂等）
        try:
            self.redis.xgroup_create(stream, group, id="0", mkstream=True)
        except redis.ResponseError:
            pass  # 已存在

        while True:
            messages = self.redis.xreadgroup(
                groupname=group,
                consumername=consumer,
                streams={stream: ">"},
                count=count,
                block=block_ms,
            )

            for stream_name, entries in messages:
                for message_id, fields in entries:
                    try:
                        event = DomainEvent(
                            event_id=fields[b"event_id"].decode(),
                            event_type=fields[b"event_type"].decode(),
                            aggregate_id=fields[b"aggregate_id"].decode(),
                            data=json.loads(fields[b"data"]),
                            timestamp=datetime.fromisoformat(fields[b"timestamp"].decode()),
                        )
                        handler(event)
                        # 确认处理完成
                        self.redis.xack(stream, group, message_id)
                    except Exception as e:
                        print(f"Error processing message {message_id}: {e}")
                        # 未确认的消息会在消费者崩溃后重新分配

# 使用示例
bus = RedisEventBus()

# 发布者
bus.publish("order-events", OrderCreated(
    aggregate_id="order-123",
    data={"customer_id": "cust-456", "items": []},
))

# 消费者（在另一个服务中）
def handle_order_event(event: DomainEvent):
    if event.event_type == "order.created":
        print(f"New order: {event.aggregate_id}")

bus.subscribe("order-events", group="inventory-service", consumer="worker-1", handler=handle_order_event)
```

---

## Common Patterns

### 1. 最终一致性处理

```python
# eventual_consistency.py - 处理最终一致性的模式
class EventualConsistencyPatterns:
    """处理事件驱动架构中的最终一致性"""

    # 模式1: 事件溯源重投影
    @staticmethod
    async def rebuild_projection(event_store: EventStore, projector: OrderProjector):
        """重建读模型（当投影逻辑变更时）"""
        # 清空读模型
        projector.truncate()
        # 从头重放所有事件
        events = event_store.get_events_by_type("order.created")
        for event in events:
            projector.project(event)
        # 继续处理后续事件...

    # 模式2: 幂等消费者
    @staticmethod
    def idempotent_handler(event_store, processed_events_table):
        """确保事件只被处理一次"""
        def decorator(handler):
            async def wrapped(event: DomainEvent):
                # 检查是否已处理
                exists = event_store.db.execute(
                    "SELECT 1 FROM processed_events WHERE event_id = %s",
                    (event.event_id,)
                ).fetchone()
                if exists:
                    return  # 跳过重复事件

                # 处理事件
                result = handler(event)

                # 记录已处理
                event_store.db.execute(
                    "INSERT INTO processed_events (event_id, processed_at) VALUES (%s, NOW())",
                    (event.event_id,)
                )
                return result
            return wrapped
        return decorator

    # 模式3: 补偿查询
    @staticmethod
    async def compensate_for_delay(query_service, aggregate_id: str, max_retries: int = 3):
        """当读模型尚未更新时，主动查询"""
        for i in range(max_retries):
            result = await query_service.get(aggregate_id)
            if result:
                return result
            await asyncio.sleep(0.5 * (i + 1))  # 指数退避
        raise TimeoutError("Read model not updated in time")
```

### 2. 事件驱动微服务通信拓扑

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Order     │     │  Inventory  │     │   Payment   │
│   Service   │     │   Service   │     │   Service   │
│             │     │             │     │             │
│ ┌─────────┐ │     │ ┌─────────┐ │     │ ┌─────────┐ │
│ │ Command │ │     │ │ Command │ │     │ │ Command │ │
│ │ Handler │ │     │ │ Handler │ │     │ │ Handler │ │
│ └────┬────┘ │     │ └────┬────┘ │     │ └────┬────┘ │
│      │      │     │      │      │     │      │      │
│ ┌────▼────┐ │     │ ┌────▼────┐ │     │ ┌────▼────┐ │
│ │ Event   │ │     │ │ Event   │ │     │ │ Event   │ │
│ │ Store   │ │     │ │ Store   │ │     │ │ Store   │ │
│ └────┬────┘ │     │ └────┬────┘ │     │ └────┬────┘ │
└──────┼──────┘     └──────┼──────┘     └──────┼──────┘
       │                   │                   │
       ▼                   ▼                   ▼
  ┌─────────────────────────────────────────────────┐
  │              Kafka / RabbitMQ                    │
  │         (order-events / inventory-events)        │
  └─────────────────────────────────────────────────┘
       ▲                   ▲                   ▲
       │                   │                   │
  ┌────┴────┐         ┌────┴────┐         ┌────┴────┐
  │Projector│         │Projector│         │Projector│
  │(Read DB)│         │(Read DB)│         │(Read DB)│
  └─────────┘         └─────────┘         └─────────┘
```

### 3. 事件 Schema 注册表

```python
# schema_registry.py - 事件 Schema 管理
class EventSchemaRegistry:
    """管理事件 Schema 版本，确保上下游兼容"""

    def __init__(self):
        self._schemas = {}  # (event_type, version) -> schema

    def register(self, event_type: str, version: int, schema: dict):
        """注册事件 Schema（JSON Schema 格式）"""
        self._schemas[(event_type, version)] = {
            "schema": schema,
            "registered_at": datetime.utcnow(),
        }

    def validate(self, event: DomainEvent) -> bool:
        """验证事件数据是否符合 Schema"""
        key = (event.event_type, event.version)
        if key not in self._schemas:
            raise SchemaNotFoundError(f"No schema for {event.event_type} v{event.version}")

        schema = self._schemas[key]["schema"]
        jsonschema.validate(event.data, schema)
        return True

    def is_compatible(self, event_type: str, old_version: int, new_version: int) -> bool:
        """检查新版本是否向后兼容"""
        old_schema = self._schemas.get((event_type, old_version), {}).get("schema", {})
        new_schema = self._schemas.get((event_type, new_version), {}).get("schema", {})
        # 新版本不能删除旧版本的必需字段
        old_required = set(old_schema.get("required", []))
        new_properties = set(new_schema.get("properties", {}).keys())
        return old_required.issubset(new_properties)
```

---

## References

- [Event Sourcing (Martin Fowler)](https://martinfowler.com/eaaDev/EventSourcing.html) — 事件溯源经典文章
- [CQRS (Martin Fowler)](https://martinfowler.com/bliki/CQRS.html) — CQRS 模式说明
- [Saga Pattern (Microsoft)](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga) — Saga 模式参考架构
- [Event Sourcing (Greg Young)](https://www.youtube.com/watch?v=8JKjvY4etTY) — Greg Young 事件溯源演讲
- [Kafka Documentation](https://kafka.apache.org/documentation/) — Apache Kafka 官方文档
- [RabbitMQ Tutorials](https://www.rabbitmq.com/getstarted.html) — RabbitMQ 入门教程
- [Redis Streams](https://redis.io/docs/latest/develop/data-types/streams/) — Redis Streams 文档
- [Axon Framework](https://docs.axoniq.io/) — Java 事件溯源框架
- [EventStoreDB](https://developers.eventstore.com/) — 专用事件存储数据库
- [CloudEvents](https://cloudevents.io/) — 事件格式规范
