---
name: workflow-engine
description: "工作流引擎设计与实现。覆盖 Activiti、Flowable、Camunda、Temporal，支持 BPMN 流程建模、任务管理、表单引擎、流程监听、版本管理。适用于 Java/Go 企业级审批流、业务流程自动化。"
---

# 工作流引擎

## When to Use This Skill

- 设计和实现业务审批流程（请假、报销、采购等）
- 集成 Activiti / Flowable / Camunda / Temporal 等工作流引擎
- BPMN 2.0 流程建模与部署
- 动态表单引擎与流程绑定
- 流程版本管理与热更新
- 流程监听器（事件钩子）开发
- 长时间运行的 Saga / 编排型业务流程
- 与现有业务系统集成

## Not For / Boundaries

- ❌ 不适用于简单的 if/else 状态机（用状态模式即可）
- ❌ 不处理实时计算或流式数据处理（用 Flink/Spark）
- ❌ 不替代消息队列的异步通信功能
- ❌ 不涉及前端流程设计器的 UI 实现（仅后端 API）
- ❌ Temporal 的 Temporal Server 运维部署不在范围内

---

## Quick Reference

### 1. BPMN 2.0 流程定义

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"
             xmlns:flowable="http://flowable.org/bpmn"
             targetNamespace="http://www.example.org">

    <process id="leave-approval" name="请假审批" isExecutable="true">
        <startEvent id="start" name="开始"/>

        <!-- 用户提交请假申请 -->
        <userTask id="submit" name="提交申请" flowable:assignee="${applicant}">
            <extensionElements>
                <flowable:formData>
                    <flowable:formProperty id="days" name="请假天数" type="long" required="true"/>
                    <flowable:formProperty id="reason" name="事由" type="string" required="true"/>
                </flowable:formData>
            </extensionElements>
        </userTask>

        <!-- 排他网关：根据天数走不同审批路径 -->
        <exclusiveGateway id="gateway1"/>

        <!-- 直接主管审批 -->
        <userTask id="managerApprove" name="主管审批"
                  flowable:candidateGroups="managers">
            <extensionElements>
                <flowable:formData>
                    <flowable:formProperty id="approved" name="是否同意" type="enum" required="true">
                        <flowable:value id="true" name="同意"/>
                        <flowable:value id="false" name="驳回"/>
                    </flowable:formProperty>
                    <flowable:formProperty id="comment" name="审批意见" type="string"/>
                </flowable:formData>
            </extensionElements>
        </userTask>

        <!-- HR 审批（>3天需要） -->
        <userTask id="hrApprove" name="HR审批" flowable:candidateGroups="hr">
            <extensionElements>
                <flowable:formData>
                    <flowable:formProperty id="approved" name="是否同意" type="enum" required="true">
                        <flowable:value id="true" name="同意"/>
                        <flowable:value id="false" name="驳回"/>
                    </flowable:formProperty>
                </flowable:formData>
            </extensionElements>
        </userTask>

        <!-- 结束事件 -->
        <endEvent id="approved" name="审批通过"/>
        <endEvent id="rejected" name="审批驳回"/>

        <!-- 连线 -->
        <sequenceFlow id="f1" sourceRef="start" targetRef="submit"/>
        <sequenceFlow id="f2" sourceRef="submit" targetRef="gateway1"/>
        <sequenceFlow id="f3" sourceRef="gateway1" targetRef="managerApprove">
            <conditionExpression>${days &lt;= 3}</conditionExpression>
        </sequenceFlow>
        <sequenceFlow id="f4" sourceRef="gateway1" targetRef="managerApprove">
            <conditionExpression>${days > 3}</conditionExpression>
        </sequenceFlow>
        <sequenceFlow id="f5" sourceRef="managerApprove" targetRef="hrApprove">
            <conditionExpression>${days > 3 && approved == 'true'}</conditionExpression>
        </sequenceFlow>
        <sequenceFlow id="f6" sourceRef="managerApprove" targetRef="approved">
            <conditionExpression>${days &lt;= 3 && approved == 'true'}</conditionExpression>
        </sequenceFlow>
        <sequenceFlow id="f7" sourceRef="managerApprove" targetRef="rejected">
            <conditionExpression>${approved == 'false'}</conditionExpression>
        </sequenceFlow>
        <sequenceFlow id="f8" sourceRef="hrApprove" targetRef="approved">
            <conditionExpression>${approved == 'true'}</conditionExpression>
        </sequenceFlow>
        <sequenceFlow id="f9" sourceRef="hrApprove" targetRef="rejected">
            <conditionExpression>${approved == 'false'}</conditionExpression>
        </sequenceFlow>
    </process>
</definitions>
```

### 2. Flowable 集成（Java / Spring Boot）

```xml
<!-- pom.xml 依赖 -->
<dependency>
    <groupId>org.flowable</groupId>
    <artifactId>flowable-spring-boot-starter</artifactId>
    <version>7.0.1</version>
</dependency>
```

```yaml
# application.yml
flowable:
  database-schema-update: true
  async-executor-activate: true
  history-level: audit
```

```java
// 流程部署与启动
@Service
public class WorkflowService {
    @Autowired
    private RuntimeService runtimeService;
    @Autowired
    private TaskService taskService;
    @Autowired
    private RepositoryService repositoryService;
    @Autowired
    private HistoryService historyService;

    // 部署流程定义
    public String deployProcess(String bpmnResource) {
        Deployment deployment = repositoryService.createDeployment()
            .addClasspathResource(bpmnResource)
            .name("请假审批流程")
            .deploy();
        return deployment.getId();
    }

    // 启动流程实例
    public String startProcess(String processKey, String applicant, Map<String, Object> variables) {
        variables.put("applicant", applicant);
        ProcessInstance instance = runtimeService.startProcessInstanceByKey(processKey, variables);
        return instance.getId();
    }

    // 查询待办任务
    public List<TaskVO> getTodoTasks(String userId) {
        List<Task> tasks = taskService.createTaskQuery()
            .taskCandidateOrAssigned(userId)
            .orderByTaskCreateTime().desc()
            .list();
        return tasks.stream().map(t -> {
            TaskVO vo = new TaskVO();
            vo.setTaskId(t.getId());
            vo.setTaskName(t.getName());
            vo.setAssignee(t.getAssignee());
            vo.setCreateTime(t.getCreateTime());
            vo.setProcessInstanceId(t.getProcessInstanceId());
            // 获取表单数据
            vo.setFormData(taskService.getVariables(t.getId()));
            return vo;
        }).collect(Collectors.toList());
    }

    // 完成任务（审批）
    public void completeTask(String taskId, String userId, Map<String, Object> variables) {
        Task task = taskService.createTaskQuery().taskId(taskId).singleResult();
        if (task == null) throw new BusinessException("任务不存在");

        // 认领任务（如果是候选任务）
        if (task.getAssignee() == null) {
            taskService.claim(taskId, userId);
        }
        taskService.complete(taskId, variables);
    }

    // 查询流程历史
    public List<HistoricActivityInstance> getProcessHistory(String processInstanceId) {
        return historyService.createHistoricActivityInstanceQuery()
            .processInstanceId(processInstanceId)
            .orderByHistoricActivityInstanceStartTime().asc()
            .list();
    }

    // 流程图当前节点高亮
    public byte[] getProcessDiagram(String processInstanceId) {
        ProcessInstance instance = runtimeService.createProcessInstanceQuery()
            .processInstanceId(processInstanceId).singleResult();
        if (instance == null) return null;

        BpmnModel bpmnModel = repositoryService.getBpmnModel(instance.getProcessDefinitionId());
        List<String> activeActivities = runtimeService.getActiveActivityIds(processInstanceId);
        return new DefaultProcessDiagramGenerator()
            .generateDiagram(bpmnModel, "png", activeActivities,
                Collections.emptyList(), "宋体", "宋体", null, 1.0, true);
    }
}
```

### 3. 流程监听器（事件钩子）

```java
// 全局流程事件监听
@Component
public class ProcessEventListener implements FlowableEventListener {

    @Override
    public void onEvent(FlowableEvent event) {
        if (event instanceof FlowableEntityEvent entityEvent) {
            Object entity = entityEvent.getEntity();
            if (entity instanceof HistoricProcessInstance hpi) {
                if (entityEvent.getType() == FlowableEngineEventType.PROCESS_COMPLETED) {
                    // 流程完成回调
                    notifyBusinessSystem(hpi.getBusinessKey(), "COMPLETED");
                }
            }
        }
    }

    @Override
    public boolean isFailOnException() { return false; }
    @Override
    public boolean isFireOnTransactionLifecycleEvent() { return true; }
    @Override
    public String getOnTransaction() { return "COMMITTED"; }
}

// 任务节点监听器（BPMN 中配置）
// <userTask id="approve">
//   <extensionElements>
//     <flowable:taskListener event="create" class="com.example.TaskCreateListener"/>
//     <flowable:taskListener event="complete" class="com.example.TaskCompleteListener"/>
//   </extensionElements>
// </userTask>
public class TaskCreateListener implements TaskListener {
    @Override
    public void notify(DelegateTask task) {
        // 任务创建时：发送通知、设置到期时间等
        String assignee = task.getAssignee();
        notificationService.send(assignee, "您有新的待办任务: " + task.getName());

        // 设置超时时间（3个工作日）
        task.setDueDate(Date.from(LocalDateTime.now().plusDays(3)
            .atZone(ZoneId.systemDefault()).toInstant()));
    }
}

// JavaDelegate 服务任务
// <serviceTask id="syncERP" flowable:class="com.example.SyncERPDelegate"/>
public class SyncERPDelegate implements JavaDelegate {
    @Override
    public void execute(DelegateExecution execution) {
        String businessKey = execution.getProcessInstanceBusinessKey();
        Map<String, Object> vars = execution.getVariables();
        // 调用外部系统
        erpClient.syncOrder(businessKey, vars);
        execution.setVariable("erpSyncResult", "SUCCESS");
    }
}
```

### 4. Temporal 工作流（Go）

```go
// go get go.temporal.io/sdk

package workflow

import (
	"time"
	"go.temporal.io/sdk/workflow"
)

// 工作流定义
func LeaveApprovalWorkflow(ctx workflow.Context, request LeaveRequest) (LeaveResult, error) {
	logger := workflow.GetLogger(ctx)
	logger.Info("开始请假审批流程", "applicant", request.Applicant)

	ao := workflow.ActivityOptions{
		StartToCloseTimeout: time.Minute * 5,
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	// Step 1: 提交申请
	var submitResult SubmitResult
	err := workflow.ExecuteActivity(ctx, SubmitLeaveActivity, request).Get(ctx, &submitResult)
	if err != nil {
		return LeaveResult{Status: "SUBMIT_FAILED"}, err
	}

	// Step 2: 主管审批（等待人工信号）
	var managerApproval ApprovalResult
	approvalChannel := workflow.GetSignalChannel(ctx, "manager-approval")

	// 设置超时（7天）
	sCtx, cancel := workflow.WithCancel(ctx)
	timer := workflow.NewTimer(sCtx, time.Hour*24*7)

	var selector workflow.SelectGroup
	selector.AddReceive(approvalChannel, func(c workflow.ReceiveChannel, more bool) {
		c.Receive(ctx, &managerApproval)
	})
	selector.AddReceive(timer, func(c workflow.ReceiveChannel, more bool) {
		managerApproval = ApprovalResult{Approved: false, Comment: "审批超时"}
	})
	selector.Select(ctx)
	cancel()

	if !managerApproval.Approved {
		return LeaveResult{Status: "REJECTED", Comment: managerApproval.Comment}, nil
	}

	// Step 3: >3天需要HR审批
	if request.Days > 3 {
		var hrApproval ApprovalResult
		err = workflow.ExecuteActivity(ctx, HRApprovalActivity, request).Get(ctx, &hrApproval)
		if err != nil || !hrApproval.Approved {
			return LeaveResult{Status: "REJECTED"}, err
		}
	}

	// Step 4: 更新考勤系统
	err = workflow.ExecuteActivity(ctx, UpdateAttendanceActivity, request).Get(ctx, nil)
	if err != nil {
		return LeaveResult{Status: "UPDATE_FAILED"}, err
	}

	return LeaveResult{Status: "APPROVED"}, nil
}

// 活动定义
func SubmitLeaveActivity(ctx context.Context, req LeaveRequest) (SubmitResult, error) {
	// 调用业务系统保存请假记录
	return SubmitResult{RecordID: "LR-2024001"}, nil
}

func HRApprovalActivity(ctx context.Context, req LeaveRequest) (ApprovalResult, error) {
	// 调用 HR 系统审批接口
	return ApprovalResult{Approved: true}, nil
}

// Worker 注册
func main() {
	c, _ := client.Dial(client.Options{})
	defer c.Close()

	w := worker.New(c, "leave-task-queue")
	w.RegisterWorkflow(LeaveApprovalWorkflow)
	w.RegisterActivity(SubmitLeaveActivity)
	w.RegisterActivity(HRApprovalActivity)
	w.RegisterActivity(UpdateAttendanceActivity)
	w.Run(worker.InterruptCh())
}
```

### 5. 流程版本管理

```java
// Flowable 版本管理
@Service
public class ProcessVersionService {
    @Autowired
    private RepositoryService repositoryService;
    @Autowired
    private RuntimeService runtimeService;

    // 部署新版本（同 key 自动 +1）
    public String deployNewVersion(String bpmnResource) {
        Deployment deployment = repositoryService.createDeployment()
            .addClasspathResource(bpmnResource)
            .name("请假审批-v2")
            .deploy();

        ProcessDefinition def = repositoryService.createProcessDefinitionQuery()
            .deploymentId(deployment.getId()).singleResult();
        return "v" + def.getVersion();
    }

    // 迁移运行中的流程到新版本
    public void migrateProcess(String processInstanceId, String newDefKey) {
        ProcessDefinition newDef = repositoryService.createProcessDefinitionQuery()
            .processDefinitionKey(newDefKey)
            .latestVersion().singleResult();

        runtimeService.createMigration(processInstanceId)
            .processDefinitionId(newDef.getId())
            .migrate();
    }

    // 查询所有版本
    public List<ProcessVersionVO> getVersions(String processKey) {
        return repositoryService.createProcessDefinitionQuery()
            .processDefinitionKey(processKey)
            .orderByProcessDefinitionVersion().asc()
            .list().stream()
            .map(d -> new ProcessVersionVO(d.getVersion(), d.getDeploymentId(),
                d.getResourceName(), d.isSuspended()))
            .collect(Collectors.toList());
    }

    // 挂起/激活流程定义
    public void suspendProcess(String processDefId) {
        repositoryService.suspendProcessDefinitionById(processDefId, true, null);
    }
}
```

### 6. 与业务系统集成模式

```java
// 模式：通过 BusinessKey 关联业务数据
@Service
public class LeaveService {
    @Autowired
    private WorkflowService workflowService;

    // 提交请假 → 启动流程
    @Transactional
    public String submitLeave(LeaveRequest request) {
        // 1. 保存业务数据
        LeaveRecord record = new LeaveRecord();
        record.setApplicant(request.getApplicant());
        record.setDays(request.getDays());
        record.setReason(request.getReason());
        record.setStatus("PENDING");
        leaveRepository.save(record);

        // 2. 启动流程，绑定业务 ID
        Map<String, Object> variables = new HashMap<>();
        variables.put("days", request.getDays());
        variables.put("reason", request.getReason());

        String processId = workflowService.startProcess(
            "leave-approval", request.getApplicant(), variables);

        // 3. 关联业务记录与流程实例
        record.setProcessInstanceId(processId);
        leaveRepository.save(record);

        return record.getId();
    }

    // 审批回调
    @EventListener
    public void onProcessCompleted(ProcessCompletedEvent event) {
        String businessKey = event.getBusinessKey();
        LeaveRecord record = leaveRepository.findByProcessInstanceId(businessKey);
        record.setStatus("APPROVED");
        leaveRepository.save(record);
        // 通知申请人
        notificationService.send(record.getApplicant(), "您的请假已批准");
    }
}
```

---

## Common Patterns

### 模式 1：引擎选型对比

| 特性 | Flowable | Camunda 7 | Camunda 8 | Temporal |
|------|----------|-----------|-----------|----------|
| 协议 | BPMN 2.0 | BPMN 2.0 | BPMN + gRPC | 代码定义 |
| 语言 | Java | Java | Java/Go/... | Go/Java/TS |
| 嵌入式 | ✅ | ✅ | ❌（独立部署） | ❌ |
| CMMN/DMN | ✅ | ✅ | ✅ | ❌ |
| 长事务 | ❌ | ❌ | ✅ (Zeebe) | ✅ |
| 社区 | Apache 2.0 | 社区版免费 | SaaS+自托管 | MIT |

### 模式 2：多级审批链

```
发起人 → 直接主管 → 部门经理 → [金额>10万] → 总经理 → HR备案
                     ↓ (驳回)
                   发起人修改重提
```

### 模式 3：并行会签

```xml
<!-- BPMN 并行网关：所有审批人都需通过 -->
<parallelGateway id="fork"/>
<userTask id="approve1" flowable:assignee="${manager1}"/>
<userTask id="approve2" flowable:assignee="${manager2}"/>
<userTask id="approve3" flowable:assignee="${manager3}"/>
<parallelGateway id="join"/>
<!-- 会签计数器在 complete listener 中维护 -->
```

### 模式 4：超时自动处理

```xml
<!-- BPMN 边界定时器事件 -->
<boundaryEvent id="timeout" attachedToRef="managerApprove">
    <timerEventDefinition>
        <timeDuration>P3D</timeDuration> <!-- 3天超时 -->
    </timerEventDefinition>
</boundaryEvent>
<sequenceFlow id="timeoutFlow" sourceRef="timeout" targetRef="autoEscalate"/>
<serviceTask id="autoEscalate" name="自动升级"
    flowable:class="com.example.EscalationDelegate"/>
```

### 模式 5：流程与表单解耦

```
流程引擎：只负责流转逻辑，不存储业务数据
表单引擎：独立管理表单 Schema，通过 processDefinitionId 关联
业务数据：存储在业务数据库，通过 businessKey 关联流程实例
```

---

## References

- [Flowable 官方文档](https://www.flowable.com/open-source/docs)
- [Flowable GitHub](https://github.com/flowable/flowable-engine)
- [Camunda 7 文档](https://docs.camunda.org/manual/7.20/)
- [Camunda 8 (Zeebe)](https://docs.camunda.io/)
- [Temporal 文档](https://docs.temporal.io/)
- [Temporal Go SDK](https://github.com/temporalio/sdk-go)
- [BPMN 2.0 规范](https://www.omg.org/spec/BPMN/2.0)
- [Activiti 用户指南](https://www.activiti.org/userguide)
- [BPMN 建模最佳实践](https://camunda.com/bpmn/reference/)
