---
name: message-queue
description: "消息队列设计与实现。覆盖 RabbitMQ、Apache Kafka、Redis Stream、RocketMQ，支持 Java/Python/Go。适用于异步解耦、削峰填谷、事件驱动架构、分布式事务消息。"
---

# 消息队列

## When to Use This Skill

- 系统异步解耦（订单→库存→支付→通知）
- 流量削峰填谷（秒杀、抢购场景）
- 事件驱动架构（Event Sourcing / CQRS）
- 分布式事务最终一致性（事务消息）
- 日志收集与流处理（Kafka）
- 延迟任务处理（延迟队列、定时消息）
- 消息队列选型与性能调优

## Not For / Boundaries

- ❌ 不适用于实时 RPC 调用（用 gRPC / HTTP）
- ❌ 不处理消息的业务语义（幂等性由消费端保证）
- ❌ 不涉及消息队列集群的运维部署
- ❌ 不替代数据库的数据持久化
- ❌ 不适用于需要强一致性的场景（用分布式事务框架）

---

## Quick Reference

### 1. 引擎选型对比

| 特性 | RabbitMQ | Kafka | RocketMQ | Redis Stream |
|------|----------|-------|----------|--------------|
| 模型 | 队列 | 分区日志 | 队列+日志 | 内存日志 |
| 吞吐 | 万级/秒 | 百万级/秒 | 十万级/秒 | 十万级/秒 |
| 延迟 | 微秒级 | 毫秒级 | 毫秒级 | 微秒级 |
| 顺序性 | 单队列保证 | 分区内保证 | 队列内保证 | 单 Stream 保证 |
| 事务 | 支持 | 支持 | 支持(半消息) | 不支持 |
| 延迟消息 | 插件支持 | 不原生支持 | ✅ 原生支持 | 不原生支持 |
| 死信队列 | ✅ | 需自建 | ✅ | 需自建 |
| 消息回溯 | ❌ | ✅ | ✅ | ✅ |
| 适用场景 | 企业应用 | 大数据/日志 | 电商/金融 | 轻量级/缓存 |

### 2. RabbitMQ（Java - Spring AMQP）

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

```yaml
# application.yml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest
    virtual-host: /
    listener:
      simple:
        acknowledge-mode: manual  # 手动 ACK
        prefetch: 10              # 预取数量
        retry:
          enabled: true
          initial-interval: 1000
          max-attempts: 3
          multiplier: 2
```

```java
// 配置交换机、队列、绑定
@Configuration
public class RabbitConfig {

    // 死信交换机
    @Bean
    public DirectExchange dlxExchange() {
        return new DirectExchange("order.dlx.exchange");
    }

    @Bean
    public Queue dlxQueue() {
        return QueueBuilder.durable("order.dlx.queue").build();
    }

    @Bean
    public Binding dlxBinding() {
        return BindingBuilder.bind(dlxQueue()).to(dlxExchange()).with("order.dlx");
    }

    // 业务交换机
    @Bean
    public DirectExchange orderExchange() {
        return new DirectExchange("order.exchange");
    }

    @Bean
    public Queue orderQueue() {
        return QueueBuilder.durable("order.queue")
            .withArgument("x-dead-letter-exchange", "order.dlx.exchange")
            .withArgument("x-dead-letter-routing-key", "order.dlx")
            .withArgument("x-message-ttl", 300000)  // 5分钟 TTL
            .build();
    }

    @Bean
    public Binding orderBinding() {
        return BindingBuilder.bind(orderQueue()).to(orderExchange()).with("order.created");
    }
}

// 生产者
@Service
public class OrderProducer {
    @Autowired
    private RabbitTemplate rabbitTemplate;

    public void sendOrderCreated(Order order) {
        rabbitTemplate.convertAndSend("order.exchange", "order.created", order, message -> {
            message.getMessageProperties().setMessageId(UUID.randomUUID().toString());
            message.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
            return message;
        });
    }
}

// 消费者（手动 ACK + 幂等）
@Component
public class OrderConsumer {
    @Autowired
    private IdempotentService idempotentService;

    @RabbitListener(queues = "order.queue")
    public void handleOrder(Message message, Channel channel,
                             @Payload Order order) throws IOException {
        String msgId = message.getMessageProperties().getMessageId();
        long deliveryTag = message.getMessageProperties().getDeliveryTag();

        try {
            // 幂等检查
            if (idempotentService.isProcessed(msgId)) {
                channel.basicAck(deliveryTag, false);
                return;
            }

            // 业务处理
            processOrder(order);

            // 标记已处理
            idempotentService.markProcessed(msgId);
            channel.basicAck(deliveryTag, false);

        } catch (Exception e) {
            // 重试3次后进入死信队列
            channel.basicNack(deliveryTag, false, false);
        }
    }
}
```

### 3. Apache Kafka（Java - Spring Kafka）

```yaml
# application.yml
spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all
      retries: 3
      properties:
        enable.idempotence: true    # 幂等生产者
        max.in.flight.requests.per.connection: 5
    consumer:
      group-id: order-service
      auto-offset-reset: earliest
      enable-auto-commit: false
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "com.example.dto"
```

```java
// Kafka 生产者
@Service
public class KafkaOrderProducer {
    @Autowired
    private KafkaTemplate<String, Object> kafkaTemplate;

    // 发送消息（带回调）
    public void sendOrderEvent(String topic, OrderEvent event) {
        kafkaTemplate.send(topic, event.getOrderId(), event)
            .addCallback(
                result -> log.info("消息发送成功: offset={}", result.getRecordMetadata().offset()),
                ex -> log.error("消息发送失败", ex)
            );
    }

    // 事务消息（Kafka 事务）
    @Transactional
    public void sendTransactional(String topic, OrderEvent event, Order order) {
        orderRepository.save(order);  // 本地事务
        kafkaTemplate.send(topic, event.getOrderId(), event);  // 同一事务
    }
}

// Kafka 消费者（手动提交 + 分区顺序）
@Component
public class KafkaOrderConsumer {

    @KafkaListener(topics = "order-events", groupId = "order-service")
    public void handleOrderEvent(
            @Payload OrderEvent event,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment ack) {

        try {
            // 幂等处理
            String idempotentKey = "order:" + event.getOrderId() + ":" + event.getEventType();
            if (idempotentService.isProcessed(idempotentKey)) {
                ack.acknowledge();
                return;
            }

            processEvent(event);
            idempotentService.markProcessed(idempotentKey);
            ack.acknowledge();

        } catch (Exception e) {
            // 发送到重试 topic
            kafkaTemplate.send("order-events-retry", event.getOrderId(), event);
            ack.acknowledge();  // 跳过当前消息
        }
    }
}
```

### 4. RocketMQ（Java）

```java
// 生产者（事务消息）
@Service
public class RocketMQTransactionProducer {

    @Autowired
    private RocketMQTemplate rocketMQTemplate;

    public void sendTransactionMessage(Order order) {
        Message<Order> msg = MessageBuilder.withPayload(order)
            .setHeader("KEYS", order.getOrderId())
            .build();

        // 发送半消息
        rocketMQTemplate.sendMessageInTransaction(
            "order-tx-producer-group",
            "order-topic:tag-create",
            msg,
            order  // 传递给本地事务执行器
        );
    }
}

// 事务消息监听器
@RocketMQTransactionListener
public class OrderTransactionListener implements RocketMQLocalTransactionListener {

    @Autowired
    private OrderRepository orderRepository;

    @Override
    public RocketMQLocalTransactionState executeLocalTransaction(Message msg, Object arg) {
        try {
            Order order = (Order) arg;
            orderRepository.save(order);  // 执行本地事务
            return RocketMQLocalTransactionState.COMMIT;
        } catch (Exception e) {
            return RocketMQLocalTransactionState.ROLLBACK;
        }
    }

    @Override
    public RocketMQLocalTransactionState checkLocalTransaction(Message msg) {
        // 回查本地事务状态
        String orderId = msg.getHeaders().get("KEYS", String.class);
        Order order = orderRepository.findById(orderId).orElse(null);
        if (order != null) {
            return RocketMQLocalTransactionState.COMMIT;
        }
        return RocketMQLocalTransactionState.UNKNOWN;
    }
}

// 延迟消息
@Service
public class DelayMessageProducer {
    @Autowired
    private RocketMQTemplate rocketMQTemplate;

    public void sendDelayMessage(String topic, Object payload, int delayLevel) {
        // delayLevel: 1=1s, 2=5s, 3=10s, 4=30s, 5=1m, 6=2m, 7=3m, 8=4m, 9=5m...
        Message<Object> msg = MessageBuilder.withPayload(payload)
            .build();
        rocketMQTemplate.syncSend(topic, msg, 3000, delayLevel);
    }
}
```

### 5. Redis Stream（Python）

```python
# pip install redis

import redis
import json
import time
import threading

r = redis.Redis(host='localhost', port=6379, decode_responses=True)
STREAM_KEY = 'order:events'
GROUP_NAME = 'order-consumers'

# 创建消费者组
def create_group():
    try:
        r.xgroup_create(STREAM_KEY, GROUP_NAME, id='0', mkstream=True)
    except redis.exceptions.ResponseError:
        pass  # 已存在

# 生产者
def produce(order_data: dict):
    msg_id = r.xadd(STREAM_KEY, {
        'order_id': order_data['order_id'],
        'action': order_data['action'],
        'data': json.dumps(order_data),
        'timestamp': str(time.time())
    })
    print(f"消息已发送: {msg_id}")
    return msg_id

# 消费者（消费者组模式）
def consume(consumer_name: str):
    while True:
        try:
            # 读取新消息，阻塞 5 秒
            messages = r.xreadgroup(
                GROUP_NAME, consumer_name,
                {STREAM_KEY: '>'},
                count=10,
                block=5000
            )
            if not messages:
                continue

            for stream, entries in messages:
                for msg_id, fields in entries:
                    try:
                        # 处理消息
                        process_order(json.loads(fields['data']))
                        # 确认消息
                        r.xack(STREAM_KEY, GROUP_NAME, msg_id)
                        print(f"消息已处理: {msg_id}")
                    except Exception as e:
                        print(f"处理失败: {msg_id}, {e}")
                        # 转入 Pending 列表等待重试

        except Exception as e:
            print(f"消费异常: {e}")
            time.sleep(1)

# 死信处理（处理 Pending 列表中超时消息）
def handle_pending(consumer_name: str):
    while True:
        # 获取 pending 列表
        pending = r.xpending_range(STREAM_KEY, GROUP_NAME, min='-', max='+', count=10)
        for item in pending:
            msg_id, idle_ms = item['message_id'], item['time_since_delivered']
            if idle_ms > 60000:  # 超过1分钟未确认
                # 转移消息到自己名下
                claimed = r.xclaim(STREAM_KEY, GROUP_NAME, consumer_name,
                                   min_idle_time=60000, message_ids=[msg_id])
                for mid, fields in claimed:
                    try:
                        process_order(json.loads(fields['data']))
                        r.xack(STREAM_KEY, GROUP_NAME, mid)
                    except:
                        pass  # 多次失败则记录到死信表
        time.sleep(30)

# 启动
create_group()
producer = threading.Thread(target=produce, args=({'order_id': 'O001', 'action': 'create'},))
consumer = threading.Thread(target=consume, args=('worker-1',))
producer.start()
consumer.start()
```

### 6. 幂等性实现（通用方案）

```java
// 基于 Redis 的幂等性检查
@Service
public class IdempotentService {
    @Autowired
    private StringRedisTemplate redisTemplate;

    private static final String IDEMPOTENT_PREFIX = "idempotent:";
    private static final Duration TTL = Duration.ofHours(24);

    /**
     * 检查并标记消息已处理（原子操作）
     * @return true 如果是新消息，false 如果已处理过
     */
    public boolean tryProcess(String messageId) {
        String key = IDEMPOTENT_PREFIX + messageId;
        // SETNX 原子操作：不存在则设置，返回是否成功
        Boolean success = redisTemplate.opsForValue()
            .setIfAbsent(key, "1", TTL);
        return Boolean.TRUE.equals(success);
    }

    public boolean isProcessed(String messageId) {
        return Boolean.TRUE.equals(
            redisTemplate.hasKey(IDEMPOTENT_PREFIX + messageId));
    }

    public void markProcessed(String messageId) {
        redisTemplate.opsForValue()
            .set(IDEMPOTENT_PREFIX + messageId, "1", TTL);
    }
}

// 消费端幂等封装
public abstract class IdempotentMessageHandler<T> {
    @Autowired
    private IdempotentService idempotentService;

    public void handle(String messageId, T payload) {
        if (!idempotentService.tryProcess(messageId)) {
            log.info("重复消息，跳过: {}", messageId);
            return;
        }
        try {
            doHandle(payload);
        } catch (Exception e) {
            // 失败时删除幂等标记，允许重试
            idempotentService.markProcessed(messageId);
            throw e;
        }
    }

    protected abstract void doHandle(T payload);
}
```

### 7. 死信队列处理（Go - RabbitMQ）

```go
package main

import (
	"encoding/json"
	"log"
	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, _ := amqp.Dial("amqp://guest:guest@localhost:5672/")
	defer conn.Close()
	ch, _ := conn.Channel()
	defer ch.Close()

	// 声明死信队列
	ch.QueueDeclare("order.dlx.queue", true, false, false, false, nil)

	// 声明业务队列（绑定死信）
	ch.QueueDeclare("order.queue", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "order.dlx.exchange",
		"x-dead-letter-routing-key": "order.dlx",
		"x-message-ttl":             300000,
	})

	// 消费死信队列
	msgs, _ := ch.Consume("order.dlx.queue", "dlx-consumer", false, false, false, false, nil)

	for msg := range msgs {
		// 解析原始消息
		var order Order
		json.Unmarshal(msg.Body, &order)

		// 获取死亡原因
		xDeath, _ := msg.Headers["x-death"].([]interface{})
		reason := ""
		if len(xDeath) > 0 {
		 death := xDeath[0].(amqp.Table)
			reason = death["reason"].(string)
		}

		log.Printf("死信消息: orderId=%s, reason=%s, retryCount=%d",
			order.ID, reason, len(xDeath))

		switch reason {
		case "expired":
			// 超时未处理 → 人工介入
			notifyAdmin(order)
		case "rejected":
			// 多次拒绝 → 记录失败
			recordFailure(order)
		}

		msg.Ack(false)
	}
}
```

---

## Common Patterns

### 模式 1：消息确认机制

```
RabbitMQ:
  - auto   → 消息发出即确认（可能丢失）
  - manual → 业务处理成功后手动 ACK（推荐）

Kafka:
  - enable.auto.commit=true  → 自动提交 offset（可能重复）
  - enable.auto.commit=false → 手动 ack（推荐）

通用原则:
  宁可重复消费，不可丢失消息 → 消费端做幂等
```

### 模式 2：顺序消费

```
Kafka:  同一 partition 的消息有序 → 用 orderId 作 key
RabbitMQ: 单队列有序 → 不要用多个 consumer
RocketMQ: 同一 queue 有序 → MessageQueueSelector

关键：发送端保证同一业务 key 进入同一队列
```

### 模式 3：延迟消息方案

```
RabbitMQ: x-message-ttl + 死信转发
Kafka:    外部调度 + 定时轮询（或 Redpanda 延迟队列）
RocketMQ: 原生延迟级别（1s ~ 2h）
Redis:    ZSET + 定时扫描（score=执行时间戳）

Redis 延迟队列实现:
  ZADD delay_queue <timestamp> <message>
  定时任务: ZRANGEBYSCORE delay_queue 0 <now> 取出执行
```

### 模式 4：消息重试策略

```
指数退避 + 最大重试次数:
  重试1: 1s 后
  重试2: 5s 后
  重试3: 30s 后
  重试4: 2min 后
  超过次数 → 进入死信队列 → 人工处理
```

### 模式 5：消息积压处理

```
1. 紧急扩容 consumer 数量
2. 临时将消息转发到更多队列
3. consumer 批量处理（提高吞吐）
4. 非核心逻辑降级（如日志暂不处理）
5. 积压恢复后，逐步恢复原消费逻辑
```

### 模式 6：事件驱动架构（Event Sourcing）

```
Producer → Event Store (Kafka) → Consumer A (写读模型)
                                → Consumer B (通知服务)
                                → Consumer C (数据分析)

每个 Consumer 维护自己的 offset，独立消费
Event 不可变，支持回溯重放
```

---

## References

- [RabbitMQ 官方文档](https://www.rabbitmq.com/documentation.html)
- [Apache Kafka 文档](https://kafka.apache.org/documentation/)
- [RocketMQ 文档](https://rocketmq.apache.org/docs/)
- [Redis Streams 文档](https://redis.io/docs/data-types/streams/)
- [Spring AMQP](https://spring.io/projects/spring-amqp)
- [Spring Kafka](https://spring.io/projects/spring-kafka)
- [Kafka 幂等生产者](https://kafka.apache.org/documentation/#producerconfigs_enable.idempotence)
- [企业集成模式 (EIP)](https://www.enterpriseintegrationpatterns.com/)
- [事件驱动架构 - Martin Fowler](https://martinfowler.com/articles/201701-event-driven.html)
