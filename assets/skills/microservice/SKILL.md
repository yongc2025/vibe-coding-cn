---
name: microservice
description: "微服务架构设计与实现。覆盖 Spring Cloud、gRPC、Dubbo、服务注册发现、配置中心、链路追踪、限流熔断、分布式事务、API 网关、可观测性。适用于 Java/Go 企业级微服务系统。"
---

# 微服务架构

## When to Use This Skill

- 单体应用拆分为微服务
- 设计服务间通信（REST / gRPC / Dubbo）
- 集成 Spring Cloud 生态（Nacos、Sentinel、Gateway）
- 服务注册与发现、配置中心
- 限流、熔断、降级（Sentinel / Resilience4j / Hystrix）
- 分布式事务（Seata / Saga / TCC）
- API 网关设计与实现
- 链路追踪与可观测性（SkyWalking / Zipkin / OpenTelemetry）
- 服务网格（Istio）基础集成

## Not For / Boundaries

- ❌ 不处理单体应用的内部模块划分
- ❌ 不涉及 Kubernetes 集群运维（仅应用层配置）
- ❌ 不替代数据库的分库分表中间件
- ❌ 不涉及 CI/CD 流水线搭建
- ❌ 不处理前端 BFF 层的完整实现

---

## Quick Reference

### 1. 微服务拆分原则

```
单一职责：每个服务只负责一个业务领域
高内聚低耦合：服务内部紧密关联，服务间松散依赖
数据自治：每个服务拥有独立数据库
限界上下文：按 DDD 限界上下文划分服务边界

拆分维度:
  - 按业务域: 订单服务、用户服务、库存服务
  - 按变更频率: 核心服务 vs 支撑服务
  - 按团队结构: 康威定律 - 组织架构≈系统架构

反模式（避免）:
  ❌ 按技术层拆分（Controller服务、Service服务、DAO服务）
  ❌ 过度拆分（纳米服务）
  ❌ 共享数据库
```

### 2. Spring Cloud + Nacos（Java）

```xml
<!-- pom.xml 核心依赖 -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>2023.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>2023.0.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

```yaml
# application.yml - 服务配置
spring:
  application:
    name: order-service
  cloud:
    nacos:
      discovery:
        server-addr: nacos:8848
        namespace: dev
        group: DEFAULT_GROUP
      config:
        server-addr: nacos:8848
        file-extension: yml
        shared-configs:
          - data-id: common.yml
            group: SHARED
            refresh: true
  profiles:
    active: dev
server:
  port: 8081
```

```java
// 服务注册 + 启动
@SpringBootApplication
@EnableDiscoveryClient
@EnableFeignClients
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}

// OpenFeign 声明式调用
@FeignClient(name = "user-service", fallbackFactory = UserServiceFallbackFactory.class)
public interface UserServiceClient {
    @GetMapping("/api/users/{id}")
    Result<UserDTO> getUser(@PathVariable("id") Long id);

    @PostMapping("/api/users/batch")
    Result<List<UserDTO>> getUsersByIds(@RequestBody List<Long> ids);
}

// Fallback 降级
@Component
public class UserServiceFallbackFactory implements FallbackFactory<UserServiceClient> {
    @Override
    public UserServiceClient create(Throwable cause) {
        return new UserServiceClient() {
            @Override
            public Result<UserDTO> getUser(Long id) {
                return Result.fail("用户服务不可用: " + cause.getMessage());
            }
            @Override
            public Result<List<UserDTO>> getUsersByIds(List<Long> ids) {
                return Result.fail("用户服务不可用");
            }
        };
    }
}

// 服务间调用（注入使用）
@Service
public class OrderService {
    @Autowired
    private UserServiceClient userClient;

    public OrderDTO getOrderDetail(Long orderId) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        // 调用用户服务获取用户信息
        UserDTO user = userClient.getUser(order.getUserId()).getData();
        OrderDTO dto = convertToDTO(order);
        dto.setUserName(user.getName());
        return dto;
    }
}
```

### 3. gRPC 服务通信（Go）

```protobuf
// proto/order.proto
syntax = "proto3";
package order;
option go_package = "pb/order";

service OrderService {
    rpc CreateOrder(CreateOrderRequest) returns (OrderResponse);
    rpc GetOrder(GetOrderRequest) returns (OrderResponse);
    rpc WatchOrderStatus(WatchOrderRequest) returns (stream OrderStatusEvent); // 服务端流
}

message CreateOrderRequest {
    string user_id = 1;
    repeated OrderItem items = 2;
}

message OrderItem {
    string product_id = 1;
    int32 quantity = 2;
    int64 price = 3; // 分为单位
}

message GetOrderRequest {
    string order_id = 1;
}

message OrderResponse {
    string order_id = 1;
    string user_id = 2;
    repeated OrderItem items = 3;
    int64 total_amount = 4;
    string status = 5;
    int64 created_at = 6;
}

message WatchOrderRequest {
    string order_id = 1;
}

message OrderStatusEvent {
    string order_id = 1;
    string status = 2;
    int64 timestamp = 3;
}
```

```go
// server/main.go - gRPC 服务端
package main

import (
	"context"
	"log"
	"net"
	"sync"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/status"
	pb "pb/order"
)

type orderServer struct {
	pb.UnimplementedOrderServiceServer
	mu     sync.RWMutex
	orders map[string]*pb.OrderResponse
}

func (s *orderServer) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.OrderResponse, error) {
	if len(req.Items) == 0 {
		return nil, status.Error(codes.InvalidArgument, "订单商品不能为空")
	}

	var total int64
	for _, item := range req.Items {
		total += item.Price * int64(item.Quantity)
	}

	orderID := generateOrderID()
	resp := &pb.OrderResponse{
		OrderId:     orderID,
		UserId:      req.UserId,
		Items:       req.Items,
		TotalAmount: total,
		Status:      "CREATED",
		CreatedAt:   time.Now().Unix(),
	}

	s.mu.Lock()
	s.orders[orderID] = resp
	s.mu.Unlock()

	return resp, nil
}

func (s *orderServer) WatchOrderStatus(req *pb.WatchOrderRequest, stream pb.OrderService_WatchOrderStatusServer) error {
	// 实时推送订单状态变更
	ch := s.subscribeOrderStatus(req.OrderId)
	defer s.unsubscribe(req.OrderId, ch)

	for event := range ch {
		if err := stream.Send(event); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	lis, _ := net.Listen("tcp", ":50051")
	s := grpc.NewServer(
		grpc.UnaryInterceptor(loggingInterceptor),
		grpc.ChainStreamInterceptor(recoveryStreamInterceptor, loggingStreamInterceptor),
	)
	pb.RegisterOrderServiceServer(s, &orderServer{
		orders: make(map[string]*pb.OrderResponse),
	})
	// 健康检查
	grpc_health_v1.RegisterHealthServer(s, health.NewServer())
	log.Println("gRPC server listening on :50051")
	s.Serve(lis)
}

// 日志拦截器
func loggingInterceptor(ctx context.Context, req interface{},
	info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	start := time.Now()
	resp, err := handler(ctx, req)
	log.Printf("method=%s duration=%s err=%v", info.FullMethod, time.Since(start), err)
	return resp, err
}
```

```go
// client/main.go - gRPC 客户端
package main

import (
	"context"
	"log"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/resolver"
	pb "pb/order"
)

func main() {
	// 服务发现（自定义 resolver）
	resolver.Register(&nacosResolver{})

	conn, _ := grpc.Dial(
		"nacos:///order-service",
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithDefaultServiceConfig(`{"loadBalancingPolicy":"round_robin"}`),
		grpc.WithUnaryInterceptor(retryInterceptor(3)),
	)
	defer conn.Close()

	client := pb.NewOrderServiceClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resp, _ := client.CreateOrder(ctx, &pb.CreateOrderRequest{
		UserId: "U001",
		Items: []*pb.OrderItem{
			{ProductId: "P001", Quantity: 2, Price: 9900},
		},
	})
	log.Printf("订单创建成功: %s, 金额: %d", resp.OrderId, resp.TotalAmount)
}
```

### 4. Sentinel 限流熔断降级（Java）

```yaml
# application.yml
spring:
  cloud:
    sentinel:
      transport:
        dashboard: sentinel:8080
      eager: true
```

```java
// 限流规则配置
@Configuration
public class SentinelConfig {
    @PostConstruct
    public void initFlowRules() {
        // QPS 限流
        FlowRule rule1 = new FlowRule();
        rule1.setResource("createOrder");
        rule1.setGrade(RuleConstant.FLOW_GRADE_QPS);
        rule1.setCount(100);  // QPS 上限 100
        rule1.setControlBehavior(RuleConstant.CONTROL_BEHAVIOR_WARM_UP);
        rule1.setWarmUpPeriodSec(10); // 预热时长

        // 并发线程数限流
        FlowRule rule2 = new FlowRule();
        rule2.setResource("queryOrder");
        rule2.setGrade(RuleConstant.FLOW_GRADE_THREAD);
        rule2.setCount(50);  // 最大并发 50

        // 熔断降级
        DegradeRule degradeRule = new DegradeRule();
        degradeRule.setResource("callUserService");
        degradeRule.setGrade(CircuitBreakerStrategy.ERROR_RATIO.getType());
        degradeRule.setCount(0.5);     // 错误率 50%
        degradeRule.setTimeWindow(10); // 熔断 10 秒
        degradeRule.setMinRequestAmount(10);  // 最小请求数
        degradeRule.setStatIntervalMs(10000); // 统计窗口

        FlowRuleManager.loadRules(List.of(rule1, rule2));
        DegradeRuleManager.loadRules(List.of(degradeRule));
    }
}

// 使用 Sentinel 资源保护
@Service
public class OrderService {

    @SentinelResource(
        value = "createOrder",
        blockHandler = "createOrderBlock",
        fallback = "createOrderFallback"
    )
    public OrderDTO createOrder(CreateOrderRequest req) {
        // 业务逻辑
        return doCreateOrder(req);
    }

    // 限流处理
    public OrderDTO createOrderBlock(CreateOrderRequest req, BlockException ex) {
        throw new BusinessException("系统繁忙，请稍后重试");
    }

    // 降级处理
    public OrderDTO createOrderFallback(CreateOrderRequest req, Throwable ex) {
        // 返回缓存数据或默认值
        return OrderDTO.builder().status("PENDING_RETRY").build();
    }
}

// Resilience4j 替代方案（更现代）
@Service
public class ResilientOrderService {
    private final CircuitBreaker circuitBreaker = CircuitBreaker.ofDefaults("userService");
    private final RateLimiter rateLimiter = RateLimiter.ofDefaults("createOrder");

    public OrderDTO createOrder(CreateOrderRequest req) {
        Supplier<OrderDTO> decorated = Decorators.ofSupplier(() -> doCreateOrder(req))
            .withCircuitBreaker(circuitBreaker)
            .withRateLimiter(rateLimiter)
            .withFallback(List.of(
                CallNotPermittedException.class, e -> fallbackOrder(),
                RequestNotPermitted.class, e -> rateLimited()
            ))
            .decorate();
        return decorated.get();
    }
}
```

### 5. 分布式事务 - Seata（Java）

```yaml
# application.yml
seata:
  enabled: true
  application-id: order-service
  tx-service-group: my_tx_group
  registry:
    type: nacos
    nacos:
      server-addr: nacos:8848
  config:
    type: nacos
    nacos:
      server-addr: nacos:8848
```

```java
// AT 模式（自动补偿，最简单）
@Service
public class OrderService {

    @GlobalTransactional(name = "create-order", rollbackFor = Exception.class)
    public void createOrder(CreateOrderRequest req) {
        // 1. 扣减库存（库存服务）
        storageClient.deduct(req.getProductId(), req.getQuantity());

        // 2. 扣减余额（账户服务）
        accountClient.debit(req.getUserId(), req.getTotalAmount());

        // 3. 创建订单（本地事务）
        Order order = new Order();
        order.setUserId(req.getUserId());
        order.setProductId(req.getProductId());
        order.setStatus(OrderStatus.CREATED);
        orderRepository.save(order);

        // 任意一步异常，Seata 自动回滚所有已执行的操作
    }
}

// Saga 模式（长事务，手动补偿）
@Service
public class SagaOrderService {

    @Autowired
    private StateMachineEngine engine;

    public void createOrderWithSaga(CreateOrderRequest req) {
        String businessKey = "order:" + req.getOrderId();
        Map<String, Object> startParams = new HashMap<>();
        startParams.put("order", req);

        // 启动状态机
        engine.start("createOrderStateMachine", businessKey, startParams);
    }
}

// TCC 模式（手动 Try-Confirm-Cancel）
@Component
public class StorageTccAction {

    @TwoPhaseBusinessAction(name = "storageDeduct",
        commitMethod = "confirm", rollbackMethod = "cancel")
    public boolean tryDeduct(
            @BusinessActionContextParameter(paramName = "productId") String productId,
            @BusinessActionContextParameter(paramName = "quantity") int quantity) {
        // Try: 冻结库存
        int rows = storageMapper.freezeStock(productId, quantity);
        return rows > 0;
    }

    public boolean confirm(BusinessActionContext context) {
        // Confirm: 扣减冻结库存
        String productId = (String) context.getActionContext("productId");
        int quantity = (int) context.getActionContext("quantity");
        storageMapper.deductFrozen(productId, quantity);
        return true;
    }

    public boolean cancel(BusinessActionContext context) {
        // Cancel: 释放冻结库存
        String productId = (String) context.getActionContext("productId");
        int quantity = (int) context.getActionContext("quantity");
        storageMapper.releaseFrozen(productId, quantity);
        return true;
    }
}
```

### 6. API 网关 - Spring Cloud Gateway

```yaml
# application.yml
spring:
  cloud:
    gateway:
      routes:
        - id: order-service
          uri: lb://order-service
          predicates:
            - Path=/api/orders/**
          filters:
            - StripPrefix=1
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 10
                redis-rate-limiter.burstCapacity: 20
                key-resolver: "#{@ipKeyResolver}"
            - name: CircuitBreaker
              args:
                name: orderService
                fallbackUri: forward:/fallback/order

        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
          filters:
            - StripPrefix=1
            - name: JwtAuth
              args:
                whiteList:
                  - /api/users/login
                  - /api/users/register

      default-filters:
        - name: GlobalLog
          args:
            showPayload: true
```

```java
// 全局认证过滤器
@Component
public class AuthGlobalFilter implements GlobalFilter, Ordered {
    @Autowired
    private JwtTokenProvider tokenProvider;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        String path = request.getURI().getPath();

        // 白名单放行
        if (isWhiteListed(path)) {
            return chain.filter(exchange);
        }

        // 校验 Token
        String token = resolveToken(request);
        if (token == null || !tokenProvider.validateToken(token)) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        // 传递用户信息到下游服务
        Claims claims = tokenProvider.parseToken(token);
        ServerHttpRequest mutatedRequest = request.mutate()
            .header("X-User-Id", claims.getSubject())
            .header("X-User-Roles", claims.get("roles", String.class))
            .build();

        return chain.filter(exchange.mutate().request(mutatedRequest).build());
    }

    @Override
    public int getOrder() { return -100; }
}

// 全局异常处理
@RestControllerAdvice
public class GatewayExceptionHandler {
    @ExceptionHandler(Exception.class)
    public Result<Void> handleException(Exception e) {
        if (e instanceof ResponseStatusException rse) {
            return Result.fail(rse.getStatusCode().value(), rse.getReason());
        }
        return Result.fail(500, "网关内部错误");
    }
}
```

### 7. 链路追踪 - OpenTelemetry

```yaml
# application.yml
management:
  tracing:
    sampling:
      probability: 1.0
  zipkin:
    tracing:
      endpoint: http://zipkin:9411/api/v2/spans
  endpoints:
    web:
      exposure:
        include: health, metrics, prometheus
```

```java
// 自定义 Span
@RestController
public class OrderController {
    private final Tracer tracer;

    public OrderController(Tracer tracer) {
        this.tracer = tracer;
    }

    @PostMapping("/api/orders")
    public Result<OrderDTO> createOrder(@RequestBody CreateOrderRequest req) {
        Span span = tracer.nextSpan().name("createOrder").start();
        try (Tracer.SpanInScope ws = tracer.withSpan(span)) {
            span.tag("userId", req.getUserId());
            span.tag("itemCount", String.valueOf(req.getItems().size()));

            OrderDTO order = orderService.createOrder(req);

            span.tag("orderId", order.getOrderId());
            return Result.ok(order);
        } catch (Exception e) {
            span.error(e);
            throw e;
        } finally {
            span.end();
        }
    }
}
```

```go
// Go - OpenTelemetry 集成
package main

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/zipkin"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
)

func initTracer() func() {
	exporter, _ := zipkin.New("http://zipkin:9411/api/v2/spans")
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String("order-service"),
		)),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)
	otel.SetTracerProvider(tp)
	return func() { tp.Shutdown(context.Background()) }
}

// 使用
func CreateOrder(ctx context.Context, req CreateOrderRequest) (*Order, error) {
	tracer := otel.Tracer("order-service")
	ctx, span := tracer.Start(ctx, "CreateOrder")
	defer span.End()

	span.SetAttributes(
		attribute.String("user.id", req.UserID),
		attribute.Int("items.count", len(req.Items)),
	)
	// 业务逻辑...
}
```

### 8. 可观测性三件套

```
Metrics（指标）: Prometheus + Grafana
  - QPS、RT、错误率
  - JVM / Go Runtime 指标
  - 自定义业务指标（订单量、支付成功率）

Logging（日志）: ELK / Loki
  - 结构化日志（JSON 格式）
  - 关联 TraceId（日志中注入链路 ID）
  - 日志级别动态调整

Tracing（链路）: Jaeger / Zipkin / SkyWalking
  - 分布式调用链
  - 慢查询定位
  - 依赖拓扑图
```

---

## Common Patterns

### 模式 1：服务通信选型

```
REST (HTTP/JSON):
  ✅ 简单、通用、调试方便
  ❌ 性能一般、序列化开销大
  适用：对外 API、前后端交互

gRPC (HTTP/2 + Protobuf):
  ✅ 高性能、强类型、双向流
  ❌ 调试不便、浏览器支持差
  适用：内部服务间高频调用

Dubbo (自定义协议):
  ✅ 高性能、服务治理完善
  ❌ 生态相对封闭
  适用：Java 技术栈内部调用
```

### 模式 2：分布式事务选型

```
AT 模式 (Seata):
  - 自动补偿，侵入性低
  - 适用于大多数场景
  - 性能有一定损耗

TCC 模式:
  - 手动编写 Try/Confirm/Cancel
  - 性能好，但开发成本高
  - 适用于资金、库存等强一致场景

Saga 模式:
  - 每步有对应的补偿操作
  - 适用于长事务
  - 最终一致性

消息事务:
  - 本地事务 + 事务消息
  - 最终一致性
  - 适用于异步场景
```

### 模式 3：配置管理策略

```
Nacos 配置中心:
  共享配置: common.yml (数据库连接、公共配置)
  服务配置: order-service.yml (服务特有配置)
  环境配置: order-service-dev.yml / order-service-prod.yml

配置优先级:
  命令行参数 > 环境变量 > application-{profile}.yml > application.yml > 共享配置

动态刷新:
  @RefreshScope 标注的 Bean 会自动刷新
  监听 Nacos 配置变更事件
```

### 模式 4：服务降级策略

```
降级层次:
  1. 接口降级: 返回缓存数据 / 默认值 / 兜底数据
  2. 功能降级: 关闭非核心功能（推荐、评论）
  3. 页面降级: 返回静态化页面
  4. 流量降级: 拒绝部分请求，保证核心链路

降级触发条件:
  - 响应时间 > 阈值
  - 错误率 > 阈值
  - 并发数 > 阈值
  - 手动开关（配置中心控制）
```

### 模式 5：API 版本管理

```
方式1: URL 路径  → /api/v1/orders, /api/v2/orders
方式2: Header    → Accept: application/vnd.api.v1+json
方式3: Query参数 → /api/orders?version=1

推荐方式1（URL 路径），简单直观

版本迭代策略:
  - 新版本保持向后兼容至少 3 个月
  - 旧版本只修安全漏洞
  - 通过 API 网关统一做版本路由
```

---

## References

- [Spring Cloud 官方文档](https://spring.io/projects/spring-cloud)
- [Spring Cloud Alibaba](https://github.com/alibaba/spring-cloud-alibaba)
- [Nacos 文档](https://nacos.io/docs/)
- [Sentinel 文档](https://sentinelguard.io/docs/)
- [Seata 文档](https://seata.io/docs/)
- [Spring Cloud Gateway](https://spring.io/projects/spring-cloud-gateway)
- [gRPC 官方文档](https://grpc.io/docs/)
- [Apache Dubbo](https://dubbo.apache.org/)
- [OpenTelemetry](https://opentelemetry.io/docs/)
- [Resilience4j](https://resilience4j.readme.io/)
- [DDD 领域驱动设计](https://martinfowler.com/tags/domain%20driven%20design.html)
- [微服务架构设计模式 - Chris Richardson](https://microservices.io/patterns/)
