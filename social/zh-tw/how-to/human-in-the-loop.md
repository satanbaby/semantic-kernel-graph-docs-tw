# 人類在環中（HITL）

SemanticKernel.Graph 中的人類在環（HITL）提供了在圖形執行期間進行人類干預的複雜機制。此系統為需要人類監督或決策的場景啟用條件暫停、人類批准、基於信心的路由和全面的審計。

## 你將學到什麼

* 如何使用可配置的條件實現人類批准節點
* 使用信心閘門根據不確定性級別路由執行
* 配置多個互動渠道（Console、Web API、CLI）
* 設置 SLA、超時和自動回退操作
* 實現批量批准系統以進行高效處理
* 全面的人類互動審計和追蹤
* HITL 在生產工作流程中的最佳實踐

## 概念和技術

**HumanApprovalGraphNode**：專門的 Node，在繼續前暫停 Graph 執行並等待人類批准，支持條件激活和多個批准選項。

**ConfidenceGateGraphNode**：Node 監視信心分數，當信心低於配置的閾值時自動觸發人類干預。

**IHumanInteractionChannel**：不同通信渠道（Console、Web API、CLI）的抽象界面，用於處理人類互動。

**HumanApprovalBatchManager**：管理多個批准請求的分組和處理以進行高效的批量操作。

**HumanInteractionTimeout**：可配置的超時設置，當未收到人類回應時採用自動回退操作。

**InterruptionType**：不同類型人類干預的分類系統（ManualApproval、ConfidenceGate、HumanInput、ResultValidation）。

## 前提條件

* [第一個 Graph 教程](../first-graph-5-minutes.md)已完成
* 對 Graph 執行概念的基本理解
* 熟悉條件 Node 和路由
* 對信心計分和品質指標的理解

## 人類批准節點

### 基本人類批准

建立在繼續執行前需要人類批准的 Node：

```csharp
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Core;

// 建立控制台互動渠道
var consoleChannel = new ConsoleHumanInteractionChannel();

// 建立人類批准節點
var approvalNode = new HumanApprovalGraphNode(
    "approval-1",
    "Document Review Required",
    "Please review the generated document for accuracy and completeness",
    consoleChannel);

// 添加到圖形
graph.AddNode(approvalNode);
graph.AddEdge(startNode, approvalNode);
```

### 條件人類批准

配置只在特定條件下啟用的批准 Node：

```csharp
// 建立條件批准節點
var conditionalApproval = HumanApprovalGraphNode.CreateConditional(
    "conditional-approval",
    "High-Risk Transaction Approval",
    "Approval required for transactions above threshold",
    state => state.GetValue<decimal>("transaction_amount") > 10000m,
    consoleChannel,
    "conditional-approval");

// 根據批准結果添加路由
graph.AddConditionalEdge(conditionalApproval, approvedNode,
    edge => edge.Condition = "ApprovalResult == true");
graph.AddConditionalEdge(conditionalApproval, rejectedNode,
    edge => edge.Condition = "ApprovalResult == false");
```

### 批准選項和路由

配置多個批准選項並進行自訂路由：

```csharp
// 添加批准選項
approvalNode.ApprovalOptions.Add(new HumanInteractionOption
{
    OptionId = "approve",
    DisplayText = "Approve and Continue",
    Value = true,
    IsDefault = true,
    Description = "Approve the document and continue processing"
});

approvalNode.ApprovalOptions.Add(new HumanInteractionOption
{
    OptionId = "reject",
    DisplayText = "Reject and Stop",
    Value = false,
    Description = "Reject the document and stop processing"
});

approvalNode.ApprovalOptions.Add(new HumanInteractionOption
{
    OptionId = "modify",
    DisplayText = "Request Modifications",
    Value = "modify",
    Description = "Request changes before approval"
});

// 根據批准選項配置路由
graph.AddConditionalEdge(approvalNode, approvedNode,
    edge => edge.Condition = "ApprovalResult == true");
graph.AddConditionalEdge(approvalNode, rejectedNode,
    edge => edge.Condition = "ApprovalResult == false");
graph.AddConditionalEdge(approvalNode, modificationNode,
    edge => edge.Condition = "ApprovalResult == 'modify'");
```

## 信心閘門

### 基本信心閘門

建立根據信心級別自動觸發人類干預的 Node：

```csharp
// 建立信心閘門，閾值為 0.7
var confidenceGate = new ConfidenceGateGraphNode(
    0.7,  // 信心閾值
    "quality-gate");

// 配置信心來源
confidenceGate.SetConfidenceSource(state => 
    state.GetValue<double>("llm_confidence_score"));

// 添加路由路徑
confidenceGate.AddHighConfidenceNode(highQualityProcessNode);
confidenceGate.AddLowConfidenceNode(humanReviewNode);

// 添加到圖形
graph.AddNode(confidenceGate);
graph.AddEdge(previousNode, confidenceGate);
```

### 進階信心分析

使用多個來源配置全面的信心評估：

```csharp
// 建立具有多個來源的信心閘門
var advancedGate = new ConfidenceGateGraphNode(
    0.8,  // 關鍵決策的更高閾值
    "critical-quality-gate");

// 配置具有權重的多個信心來源
advancedGate.SetConfidenceSources(new Dictionary<string, Func<GraphState, double>>
{
    ["llm_confidence"] = state => state.GetValue<double>("llm_confidence") * 0.6,
    ["similarity_score"] = state => state.GetValue<double>("similarity_score") * 0.3,
    ["validation_score"] = state => state.GetValue<double>("validation_score") * 0.1
});

// 配置不確定性分析
advancedGate.EnableUncertaintyAnalysis = true;
advancedGate.SetUncertaintyThreshold(0.3);

// 添加人類互動渠道以應對低信心
advancedGate.SetInteractionChannel(consoleChannel);
```

### 信心閘門模式

為信心閘門配置不同的操作模式：

```csharp
// 寬鬆模式 - 允許執行但有警告
var permissiveGate = new ConfidenceGateGraphNode(0.6, "permissive-gate")
{
    Mode = ConfidenceGateMode.Permissive,
    AllowManualBypass = true
};

// 嚴格模式 - 對於低信心需要人類批准
var strictGate = new ConfidenceGateGraphNode(0.8, "strict-gate")
{
    Mode = ConfidenceGateMode.Strict,
    RequireHumanApproval = true
};

// 學習模式 - 根據反饋調整閾值
var learningGate = new ConfidenceGateGraphNode(0.7, "learning-gate")
{
    Mode = ConfidenceGateMode.Learning,
    EnableThresholdAdjustment = true
};
```

## 互動渠道

### 控制台渠道

為開發和測試使用基於控制台的互動：

```csharp
using SemanticKernel.Graph.Core;

// 使用自訂配置建立控制台渠道
var consoleChannel = new ConsoleHumanInteractionChannel();

// 配置控制台設定
await consoleChannel.InitializeAsync(new Dictionary<string, object>
{
    ["enable_colors"] = true,
    ["show_timestamps"] = true,
    ["clear_screen_on_new_request"] = false,
    ["prompt_style"] = "detailed"
});

// 在批准 Node 中使用
var approvalNode = new HumanApprovalGraphNode(
    "console-approval",
    "Console Approval",
    "Please approve this action",
    consoleChannel);
```

### Web API 渠道

為生產部署實現基於網路的互動：

```csharp
using SemanticKernel.Graph.Core;

// 使用備份存儲建立 Web API 渠道
var interactionStore = new InMemoryHumanInteractionStore();
var webApiChannel = new WebApiHumanInteractionChannel(interactionStore);

// 配置 Web API 設定
await webApiChannel.InitializeAsync(new Dictionary<string, object>
{
    ["api_base_url"] = "https://api.example.com/approvals",
    ["timeout_seconds"] = 300,
    ["enable_notifications"] = true
});

// 訂閱事件
webApiChannel.ResponseReceived += (sender, response) =>
{
    Console.WriteLine($"Received response: {response.Status}");
};

webApiChannel.RequestTimedOut += (sender, request) =>
{
    Console.WriteLine($"Request timed out: {request.RequestId}");
};
```

### 自訂渠道實現

為特定需求建立自訂互動渠道：

```csharp
public class EmailInteractionChannel : IHumanInteractionChannel
{
    public HumanInteractionChannelType ChannelType => HumanInteractionChannelType.Email;
    public string ChannelName => "Email Interaction Channel";
    public bool IsAvailable => true;
    public bool SupportsBatchOperations => false;

    public async Task<HumanInterruptionResponse> SendInterruptionRequestAsync(
        HumanInterruptionRequest request,
        CancellationToken cancellationToken = default)
    {
        // 傳送含有批准連結的電子郵件
        var emailContent = CreateApprovalEmail(request);
        await SendEmailAsync(request.UserEmail, emailContent);
        
        // 等待透過 webhook 或輪詢的回應
        return await WaitForEmailResponseAsync(request.RequestId, cancellationToken);
    }

    // 實現其他介面方法...
}

// 使用自訂渠道
var emailChannel = new EmailInteractionChannel();
var approvalNode = new HumanApprovalGraphNode(
    "email-approval",
    "Email Approval",
    "Please check your email for approval",
    emailChannel);
```

## 超時配置和 SLA

### 基本超時配置

配置超時和自動回退操作：

```csharp
using SemanticKernel.Graph.Core;

// 建立超時配置
var timeoutConfig = new HumanInteractionTimeout
{
    PrimaryTimeout = TimeSpan.FromMinutes(15),
    WarningTimeout = TimeSpan.FromMinutes(10),
    DefaultAction = TimeoutAction.Reject,
    EnableEscalation = true,
    EscalationTimeout = TimeSpan.FromMinutes(30)
};

// 套用到批准節點
approvalNode.TimeoutConfiguration = timeoutConfig;

// 配置超時操作
approvalNode.SetTimeoutAction(TimeoutAction.Escalate, escalationNode);
approvalNode.SetTimeoutAction(TimeoutAction.UseDefault, defaultNode);
```

### 基於 SLA 的超時

實現服務級別協議（SLA）合規性：

```csharp
// 配置基於 SLA 的超時
var slaTimeouts = new Dictionary<string, HumanInteractionTimeout>
{
    ["critical"] = new HumanInteractionTimeout
    {
        PrimaryTimeout = TimeSpan.FromMinutes(5),
        DefaultAction = TimeoutAction.Escalate,
        EscalationTimeout = TimeSpan.FromMinutes(10)
    },
    
    ["high"] = new HumanInteractionTimeout
    {
        PrimaryTimeout = TimeSpan.FromMinutes(15),
        DefaultAction = TimeoutAction.Reject,
        WarningTimeout = TimeSpan.FromMinutes(10)
    },
    
    ["normal"] = new HumanInteractionTimeout
    {
        PrimaryTimeout = TimeSpan.FromMinutes(30),
        DefaultAction = TimeoutAction.UseDefault,
        WarningTimeout = TimeSpan.FromMinutes(20)
    }
};

// 根據優先權套用 SLA 超時
approvalNode.SetPriorityBasedTimeouts(slaTimeouts);
```

### 升級和回退

配置當主要批准者未回應時的自動升級：

```csharp
// 配置升級鏈
var escalationConfig = new EscalationConfiguration
{
    EnableEscalation = true,
    EscalationLevels = new List<EscalationLevel>
    {
        new EscalationLevel
        {
            Level = 1,
            ApproverRole = "Manager",
            Timeout = TimeSpan.FromMinutes(10),
            NotificationChannel = "email"
        },
        new EscalationLevel
        {
            Level = 2,
            ApproverRole = "Director",
            Timeout = TimeSpan.FromMinutes(20),
            NotificationChannel = "sms"
        }
    }
};

approvalNode.EscalationConfiguration = escalationConfig;
```

## 批量批准系統

### 基本批次配置

為高效處理分組多個批准請求：

```csharp
using SemanticKernel.Graph.Core;

// 建立具有配置的批次管理器
var batchOptions = new BatchApprovalOptions
{
    MaxBatchSize = 10,
    BatchFormationTimeout = TimeSpan.FromMinutes(5),
    AllowPartialApproval = true,
    GroupByInterruptionType = true,
    GroupByPriority = true
};

var batchManager = new HumanApprovalBatchManager(
    consoleChannel,
    batchOptions,
    graphLogger);

// 配置執行器使用批次系統
executor.WithBatchApproval(batchManager);

// 訂閱批次事件
batchManager.BatchFormed += (sender, batch) =>
{
    Console.WriteLine($"Batch formed: {batch.BatchId} with {batch.Requests.Count} requests");
};

batchManager.BatchCompleted += (sender, args) =>
{
    Console.WriteLine($"Batch completed: {args.BatchId} in {args.ProcessingTime}");
};
```

### 智慧批次分組

配置智慧分組策略：

```csharp
// 配置進階分組
var smartBatchOptions = new BatchApprovalOptions
{
    MaxBatchSize = 15,
    BatchFormationTimeout = TimeSpan.FromMinutes(3),
    AllowPartialApproval = false,
    GroupByInterruptionType = true,
    GroupByPriority = true,
    GroupByUser = true,
    GroupByContext = true
};

// 自訂分組標準
batchManager.SetCustomGroupingCriteria(request =>
{
    var criteria = new List<string>();
    
    // 按業務單位分組
    if (request.Context.TryGetValue("business_unit", out var bu))
        criteria.Add($"bu_{bu}");
    
    // 按風險級別分組
    if (request.Context.TryGetValue("risk_level", out var risk))
        criteria.Add($"risk_{risk}");
    
    return criteria;
});
```

## 審計和追蹤

### 基本審計線索

追蹤所有人類互動以確保合規性：

```csharp
// 啟用全面的審計
approvalNode.EnableAuditTrail = true;
approvalNode.AuditConfiguration = new AuditConfiguration
{
    TrackUserActions = true,
    TrackTiming = true,
    TrackContext = true,
    EnableAuditLogging = true
};

// 訂閱審計事件
approvalNode.AuditEventRaised += (sender, auditEvent) =>
{
    var auditLog = new
    {
        Timestamp = auditEvent.Timestamp,
        UserId = auditEvent.UserId,
        Action = auditEvent.Action,
        Context = auditEvent.Context,
        Duration = auditEvent.Duration
    };
    
    // 記錄到審計系統
    auditLogger.LogAuditEvent(auditLog);
};
```

### 合規報告

為法規要求生成合規報告：

```csharp
// 配置合規追蹤
var complianceConfig = new ComplianceConfiguration
{
    EnableComplianceTracking = true,
    RequiredFields = new[] { "user_id", "approval_reason", "risk_assessment" },
    RetentionPeriod = TimeSpan.FromDays(2555), // 7 年
    EnableDataExport = true
};

approvalNode.ComplianceConfiguration = complianceConfig;

// 生成合規報告
var complianceReport = await approvalNode.GenerateComplianceReportAsync(
    DateTimeOffset.UtcNow.AddDays(-30),
    DateTimeOffset.UtcNow);

Console.WriteLine($"Compliance Report: {complianceReport.TotalApprovals} approvals");
Console.WriteLine($"Average Response Time: {complianceReport.AverageResponseTime}");
Console.WriteLine($"SLA Compliance: {complianceReport.SlaComplianceRate:P}");
```

### 績效指標

追蹤 HITL 績效和效率：

```csharp
// 獲得 HITL 績效指標
var hitlMetrics = approvalNode.GetHITLMetrics();

Console.WriteLine($"Total Approvals: {hitlMetrics.TotalApprovals}");
Console.WriteLine($"Average Response Time: {hitlMetrics.AverageResponseTime}");
Console.WriteLine($"Timeout Rate: {hitlMetrics.TimeoutRate:P}");
Console.WriteLine($"Escalation Rate: {hitlMetrics.EscalationRate:P}");

// 獲得信心閘門指標
var gateMetrics = confidenceGate.GetGateMetrics();

Console.WriteLine($"Gate Passed: {gateMetrics.GatePassed}");
Console.WriteLine($"Gate Blocked: {gateMetrics.GateBlocked}");
Console.WriteLine($"Human Overrides: {gateMetrics.HumanOverrides}");
Console.WriteLine($"Average Confidence: {gateMetrics.AverageConfidence:F2}");
```

## 與 Graph 執行的整合

### 流暢配置

使用擴展方法進行清晰、可讀的配置：

```csharp
using SemanticKernel.Graph.Extensions;

// 使用流暢 API 配置 HITL
var executor = new GraphExecutor("HITLGraph", "Graph with human approval")
    .AddHumanApproval(
        "document-approval",
        "Document Review Required",
        "Please review the generated document",
        consoleChannel)
    .AddConfidenceGate(
        "quality-gate",
        0.8,
        consoleChannel)
    .WithBatchApproval(batchManager)
    .WithHumanApprovalTimeout(
        TimeSpan.FromMinutes(15),
        TimeoutAction.Reject);
```

### Kernel Builder 整合

在核心級別整合 HITL 功能：

```csharp
using SemanticKernel.Graph.Extensions;

// 將 HITL 支援添加到 kernel builder
var builder = Kernel.CreateBuilder()
    .AddConsoleHumanInteraction(new Dictionary<string, object>
    {
        ["enable_colors"] = true,
        ["show_timestamps"] = true
    })
    .AddWebApiHumanInteraction()
    .WithBatchApprovalOptions(new BatchApprovalOptions
    {
        MaxBatchSize = 20,
        BatchFormationTimeout = TimeSpan.FromMinutes(10)
    });

var kernel = builder.Build();
```

### 串流整合

即時監視 HITL 事件：

```csharp
using var eventStream = executor.CreateStreamingExecutor()
    .CreateEventStream();

// 訂閱 HITL 事件
eventStream.SubscribeToEvents<GraphExecutionEvent>(event =>
{
    if (event.EventType == GraphExecutionEventType.HumanInteractionRequested)
    {
        var hitlEvent = event as HumanInteractionRequestedEvent;
        Console.WriteLine($"HITL Request: {hitlEvent.NodeId} - {hitlEvent.Title}");
    }
    
    if (event.EventType == GraphExecutionEventType.HumanInteractionCompleted)
    {
        var hitlEvent = event as HumanInteractionCompletedEvent;
        Console.WriteLine($"HITL Completed: {hitlEvent.NodeId} - {hitlEvent.Result}");
    }
});

// 使用串流執行
await executor.ExecuteAsync(arguments, eventStream);
```

## 最佳實踐

### 人類批准設計

* **清楚的批准標準**：提供具體、可行的批准請求
* **上下文豐富的資訊**：包含決策的相關數據和推理
* **多個批准選項**：在適當時提供批准/拒絕/修改選項
* **條件啟用**：僅在必要時請求批准
* **超時處理**：始終為超時配置回退操作

### 信心閘門配置

* **適當的閾值**：根據業務風險和品質要求設置閾值
* **多個來源**：結合多個信心指標進行穩健評估
* **學習模式**：使用學習閘門隨時間改進閾值
* **不確定性分析**：啟用詳細的不確定性追蹤以進行調試
* **回退路徑**：為低信心場景提供清晰的路由

### 渠道選擇

* **開發**：為測試和開發使用控制台渠道
* **生產**：為可擴展的部署實現 Web API 渠道
* **用戶體驗**：根據用戶偏好和工作流程選擇渠道
* **整合**：確保渠道與現有批准系統集成
* **監視**：監視渠道可用性和績效

### 績效和可擴展性

* **批次處理**：為高容量場景使用批量批准系統
* **超時優化**：平衡 SLA 要求與用戶體驗
* **升級鏈**：實現有效的升級以防止瓶頸
* **審計效率**：配置審計日誌以最小化績效影響
* **資源管理**：監視 HITL 資源使用情況並相應地優化

### 合規和安全

* **審計線索**：為所有人類互動維護全面的審計日誌
* **用戶身份驗證**：實現適當的用戶識別和授權
* **數據清理**：清理批准請求中的敏感數據
* **保留政策**：為合規性配置適當的數據保留
* **存取控制**：根據用戶角色和許可限制 HITL 存取

## 故障排除

### 常見問題

**批准請求未出現**：檢查互動渠道是否正確初始化並可用。

**超時不起作用**：驗證超時配置並確保回退操作已正確配置。

**批次處理問題**：檢查批次管理器配置並確保正確的事件處理。

**信心閘門未觸發**：驗證信心來源配置和閾值設定。

**審計日誌遺失**：確保審計配置已啟用且審計事件處理器已正確註冊。

### 調試 HITL

啟用詳細日誌以進行故障排除：

```csharp
// 配置詳細的 HITL 日誌
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableHITLLogging = true,
    HITLLogLevel = LogLevel.Trace
};

var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);

// 啟用渠道特定的調試
consoleChannel.EnableDebugMode = true;
webApiChannel.EnableDebugMode = true;
```

### 績效監視

監視 HITL 績效指標：

```csharp
// 獲得全面的 HITL 指標
var overallMetrics = await executor.GetHITLMetricsAsync();

Console.WriteLine($"HITL Performance Summary:");
Console.WriteLine($"  Total Interactions: {overallMetrics.TotalInteractions}");
Console.WriteLine($"  Average Response Time: {overallMetrics.AverageResponseTime}");
Console.WriteLine($"  SLA Compliance: {overallMetrics.SlaComplianceRate:P}");
Console.WriteLine($"  User Satisfaction: {overallMetrics.UserSatisfactionScore:F2}");
```

## 另請參閱

* [條件 Node](conditional-nodes-quickstart.md) - 瞭解條件執行和路由
* [錯誤處理和恢復力](error-handling-and-resilience.md) - 管理失敗和恢復
* [狀態管理](state-quickstart.md) - 持久化 HITL 狀態和決策
* [串流執行](streaming-quickstart.md) - HITL 事件的即時監視
* [Graph 執行](execution.md) - 瞭解執行生命週期
