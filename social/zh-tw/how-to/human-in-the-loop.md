# 人工介入迴圈 (HITL)

SemanticKernel.Graph 中的人工介入迴圈 (HITL) 提供了在圖執行期間進行人工干預的精密機制。此系統為需要人工監督或決策的場景啟用了條件暫停、人工批准、基於信心度的路由和全面的稽核。

## 您將學到的內容

* 如何實作具有可配置條件的人工批准節點
* 使用信心度閘門根據不確定性級別路由執行
* 配置多個交互通道（主控台、Web API、CLI）
* 設定 SLA、逾時和自動備用動作
* 實作批次批准系統以實現高效處理
* 人工交互的全面稽核和追蹤
* 生產工作流中 HITL 整合的最佳實踐

## 概念和技術

**HumanApprovalGraphNode**：特殊節點，在圖執行期間暫停並等待人工批准後才繼續，支援條件激活和多個批准選項。

**ConfidenceGateGraphNode**：監視信心度評分的節點，在信心度低於配置的閾值時自動觸發人工干預。

**IHumanInteractionChannel**：不同通信通道（主控台、Web API、CLI）的抽象介面，用於處理人工交互。

**HumanApprovalBatchManager**：管理多個批准請求的分組和處理，實現高效的批次操作。

**HumanInteractionTimeout**：可配置的逾時設定，在未收到人工回應時自動進行備用動作。

**InterruptionType**：不同類型人工干預的分類系統（ManualApproval、ConfidenceGate、HumanInput、ResultValidation）。

## 先決條件

* [第一個圖教學](../first-graph-5-minutes.md)已完成
* 基本了解圖執行概念
* 熟悉條件節點和路由
* 理解信心度評分和品質指標

## 人工批准節點

### 基本人工批准

建立需要人工批准才能繼續執行的節點：

```csharp
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Core;

// 建立主控台交互通道
var consoleChannel = new ConsoleHumanInteractionChannel();

// 建立人工批准節點
var approvalNode = new HumanApprovalGraphNode(
    "approval-1",
    "需要文件審查",
    "請審查生成的文件的準確性和完整性",
    consoleChannel);

// 新增至圖
graph.AddNode(approvalNode);
graph.AddEdge(startNode, approvalNode);
```

### 條件人工批准

配置只在特定條件下啟用的批准節點：

```csharp
// 建立條件批准節點
var conditionalApproval = HumanApprovalGraphNode.CreateConditional(
    "conditional-approval",
    "高風險交易批准",
    "超過閾值的交易需要批准",
    state => state.GetValue<decimal>("transaction_amount") > 10000m,
    consoleChannel,
    "conditional-approval");

// 根據批准結果新增路由
graph.AddConditionalEdge(conditionalApproval, approvedNode,
    edge => edge.Condition = "ApprovalResult == true");
graph.AddConditionalEdge(conditionalApproval, rejectedNode,
    edge => edge.Condition = "ApprovalResult == false");
```

### 批准選項和路由

配置多個批准選項和自訂路由：

```csharp
// 新增批准選項
approvalNode.ApprovalOptions.Add(new HumanInteractionOption
{
    OptionId = "approve",
    DisplayText = "批准並繼續",
    Value = true,
    IsDefault = true,
    Description = "批准文件並繼續處理"
});

approvalNode.ApprovalOptions.Add(new HumanInteractionOption
{
    OptionId = "reject",
    DisplayText = "拒絕並停止",
    Value = false,
    Description = "拒絕文件並停止處理"
});

approvalNode.ApprovalOptions.Add(new HumanInteractionOption
{
    OptionId = "modify",
    DisplayText = "要求修改",
    Value = "modify",
    Description = "在批准前要求進行變更"
});

// 根據批准選項配置路由
graph.AddConditionalEdge(approvalNode, approvedNode,
    edge => edge.Condition = "ApprovalResult == true");
graph.AddConditionalEdge(approvalNode, rejectedNode,
    edge => edge.Condition = "ApprovalResult == false");
graph.AddConditionalEdge(approvalNode, modificationNode,
    edge => edge.Condition = "ApprovalResult == 'modify'");
```

## 信心度閘門

### 基本信心度閘門

建立根據信心度級別自動觸發人工干預的節點：

```csharp
// 建立信心度閘門，閾值為 0.7
var confidenceGate = new ConfidenceGateGraphNode(
    0.7,  // 信心度閾值
    "quality-gate");

// 配置信心度來源
confidenceGate.SetConfidenceSource(state => 
    state.GetValue<double>("llm_confidence_score"));

// 新增路由路徑
confidenceGate.AddHighConfidenceNode(highQualityProcessNode);
confidenceGate.AddLowConfidenceNode(humanReviewNode);

// 新增至圖
graph.AddNode(confidenceGate);
graph.AddEdge(previousNode, confidenceGate);
```

### 進階信心度分析

配置具有多個來源的全面信心度評估：

```csharp
// 建立具有多個來源的信心度閘門
var advancedGate = new ConfidenceGateGraphNode(
    0.8,  // 關鍵決策的更高閾值
    "critical-quality-gate");

// 配置多個信心度來源及其權重
advancedGate.SetConfidenceSources(new Dictionary<string, Func<GraphState, double>>
{
    ["llm_confidence"] = state => state.GetValue<double>("llm_confidence") * 0.6,
    ["similarity_score"] = state => state.GetValue<double>("similarity_score") * 0.3,
    ["validation_score"] = state => state.GetValue<double>("validation_score") * 0.1
});

// 配置不確定性分析
advancedGate.EnableUncertaintyAnalysis = true;
advancedGate.SetUncertaintyThreshold(0.3);

// 為低信心度新增人工交互通道
advancedGate.SetInteractionChannel(consoleChannel);
```

### 信心度閘門模式

為信心度閘門配置不同的操作模式：

```csharp
// 寬鬆模式 - 允許執行並發出警告
var permissiveGate = new ConfidenceGateGraphNode(0.6, "permissive-gate")
{
    Mode = ConfidenceGateMode.Permissive,
    AllowManualBypass = true
};

// 嚴格模式 - 低信心度時需要人工批准
var strictGate = new ConfidenceGateGraphNode(0.8, "strict-gate")
{
    Mode = ConfidenceGateMode.Strict,
    RequireHumanApproval = true
};

// 學習模式 - 根據回饋調整閾值
var learningGate = new ConfidenceGateGraphNode(0.7, "learning-gate")
{
    Mode = ConfidenceGateMode.Learning,
    EnableThresholdAdjustment = true
};
```

## 交互通道

### 主控台通道

在開發和測試中使用主控台型交互：

```csharp
using SemanticKernel.Graph.Core;

// 建立具有自訂配置的主控台通道
var consoleChannel = new ConsoleHumanInteractionChannel();

// 配置主控台設定
await consoleChannel.InitializeAsync(new Dictionary<string, object>
{
    ["enable_colors"] = true,
    ["show_timestamps"] = true,
    ["clear_screen_on_new_request"] = false,
    ["prompt_style"] = "detailed"
});

// 在批准節點中使用
var approvalNode = new HumanApprovalGraphNode(
    "console-approval",
    "主控台批准",
    "請批准此動作",
    consoleChannel);
```

### Web API 通道

實作用於生產部署的網頁型交互：

```csharp
using SemanticKernel.Graph.Core;

// 建立具有支援存放區的 Web API 通道
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
    Console.WriteLine($"已接收回應: {response.Status}");
};

webApiChannel.RequestTimedOut += (sender, request) =>
{
    Console.WriteLine($"請求已逾時: {request.RequestId}");
};
```

### 自訂通道實作

為特定需求建立自訂交互通道：

```csharp
public class EmailInteractionChannel : IHumanInteractionChannel
{
    public HumanInteractionChannelType ChannelType => HumanInteractionChannelType.Email;
    public string ChannelName => "電子郵件交互通道";
    public bool IsAvailable => true;
    public bool SupportsBatchOperations => false;

    public async Task<HumanInterruptionResponse> SendInterruptionRequestAsync(
        HumanInterruptionRequest request,
        CancellationToken cancellationToken = default)
    {
        // 發送含有批准連結的電子郵件
        var emailContent = CreateApprovalEmail(request);
        await SendEmailAsync(request.UserEmail, emailContent);
        
        // 透過 webhook 或輪詢等待回應
        return await WaitForEmailResponseAsync(request.RequestId, cancellationToken);
    }

    // 實作其他介面方法...
}

// 使用自訂通道
var emailChannel = new EmailInteractionChannel();
var approvalNode = new HumanApprovalGraphNode(
    "email-approval",
    "電子郵件批准",
    "請檢查您的電子郵件以進行批准",
    emailChannel);
```

## 逾時配置和 SLA

### 基本逾時配置

配置具有自動備用動作的逾時：

```csharp
using SemanticKernel.Graph.Core;

// 建立逾時配置
var timeoutConfig = new HumanInteractionTimeout
{
    PrimaryTimeout = TimeSpan.FromMinutes(15),
    WarningTimeout = TimeSpan.FromMinutes(10),
    DefaultAction = TimeoutAction.Reject,
    EnableEscalation = true,
    EscalationTimeout = TimeSpan.FromMinutes(30)
};

// 應用至批准節點
approvalNode.TimeoutConfiguration = timeoutConfig;

// 配置逾時動作
approvalNode.SetTimeoutAction(TimeoutAction.Escalate, escalationNode);
approvalNode.SetTimeoutAction(TimeoutAction.UseDefault, defaultNode);
```

### 基於 SLA 的逾時

實作服務級別協議 (SLA) 合規性：

```csharp
// 配置基於 SLA 的逾時
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

// 根據優先級應用 SLA 逾時
approvalNode.SetPriorityBasedTimeouts(slaTimeouts);
```

### 升級和備用

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
            ApproverRole = "經理",
            Timeout = TimeSpan.FromMinutes(10),
            NotificationChannel = "email"
        },
        new EscalationLevel
        {
            Level = 2,
            ApproverRole = "主任",
            Timeout = TimeSpan.FromMinutes(20),
            NotificationChannel = "sms"
        }
    }
};

approvalNode.EscalationConfiguration = escalationConfig;
```

## 批次批准系統

### 基本批次配置

將多個批准請求分組以實現高效處理：

```csharp
using SemanticKernel.Graph.Core;

// 建立具有配置的批次管理員
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

// 配置執行程式以使用批次系統
executor.WithBatchApproval(batchManager);

// 訂閱批次事件
batchManager.BatchFormed += (sender, batch) =>
{
    Console.WriteLine($"批次已建立: {batch.BatchId}，包含 {batch.Requests.Count} 個請求");
};

batchManager.BatchCompleted += (sender, args) =>
{
    Console.WriteLine($"批次已完成: {args.BatchId}，耗時 {args.ProcessingTime}");
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

// 自訂分組條件
batchManager.SetCustomGroupingCriteria(request =>
{
    var criteria = new List<string>();
    
    // 按業務部門分組
    if (request.Context.TryGetValue("business_unit", out var bu))
        criteria.Add($"bu_{bu}");
    
    // 按風險級別分組
    if (request.Context.TryGetValue("risk_level", out var risk))
        criteria.Add($"risk_{risk}");
    
    return criteria;
});
```

## 稽核和追蹤

### 基本稽核軌跡

追蹤所有人工交互以確保合規性：

```csharp
// 啟用全面稽核
approvalNode.EnableAuditTrail = true;
approvalNode.AuditConfiguration = new AuditConfiguration
{
    TrackUserActions = true,
    TrackTiming = true,
    TrackContext = true,
    EnableAuditLogging = true
};

// 訂閱稽核事件
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
    
    // 記錄至稽核系統
    auditLogger.LogAuditEvent(auditLog);
};
```

### 合規性報告

為監管要求生成合規性報告：

```csharp
// 配置合規性追蹤
var complianceConfig = new ComplianceConfiguration
{
    EnableComplianceTracking = true,
    RequiredFields = new[] { "user_id", "approval_reason", "risk_assessment" },
    RetentionPeriod = TimeSpan.FromDays(2555), // 7 年
    EnableDataExport = true
};

approvalNode.ComplianceConfiguration = complianceConfig;

// 生成合規性報告
var complianceReport = await approvalNode.GenerateComplianceReportAsync(
    DateTimeOffset.UtcNow.AddDays(-30),
    DateTimeOffset.UtcNow);

Console.WriteLine($"合規性報告：{complianceReport.TotalApprovals} 次批准");
Console.WriteLine($"平均回應時間：{complianceReport.AverageResponseTime}");
Console.WriteLine($"SLA 合規率：{complianceReport.SlaComplianceRate:P}");
```

### 績效指標

追蹤 HITL 績效和效率：

```csharp
// 取得 HITL 績效指標
var hitlMetrics = approvalNode.GetHITLMetrics();

Console.WriteLine($"總批准數：{hitlMetrics.TotalApprovals}");
Console.WriteLine($"平均回應時間：{hitlMetrics.AverageResponseTime}");
Console.WriteLine($"逾時率：{hitlMetrics.TimeoutRate:P}");
Console.WriteLine($"升級率：{hitlMetrics.EscalationRate:P}");

// 取得信心度閘門指標
var gateMetrics = confidenceGate.GetGateMetrics();

Console.WriteLine($"閘門通過：{gateMetrics.GatePassed}");
Console.WriteLine($"閘門阻擋：{gateMetrics.GateBlocked}");
Console.WriteLine($"人工覆蓋：{gateMetrics.HumanOverrides}");
Console.WriteLine($"平均信心度：{gateMetrics.AverageConfidence:F2}");
```

## 與圖執行的整合

### 流暢配置

使用擴充方法進行簡潔、易讀的配置：

```csharp
using SemanticKernel.Graph.Extensions;

// 使用流暢 API 配置 HITL
var executor = new GraphExecutor("HITLGraph", "具有人工批准的圖")
    .AddHumanApproval(
        "document-approval",
        "需要文件審查",
        "請審查生成的文件",
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

### 核心建置工具整合

在核心層級整合 HITL 功能：

```csharp
using SemanticKernel.Graph.Extensions;

// 將 HITL 支援新增至核心建置工具
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
        Console.WriteLine($"HITL 請求: {hitlEvent.NodeId} - {hitlEvent.Title}");
    }
    
    if (event.EventType == GraphExecutionEventType.HumanInteractionCompleted)
    {
        var hitlEvent = event as HumanInteractionCompletedEvent;
        Console.WriteLine($"HITL 已完成: {hitlEvent.NodeId} - {hitlEvent.Result}");
    }
});

// 使用串流執行
await executor.ExecuteAsync(arguments, eventStream);
```

## 最佳實踐

### 人工批准設計

* **清晰的批准條件**：提供具體、可操作的批准請求
* **內容豐富的資訊**：納入用於決策的相關資料和推理
* **多個批准選項**：適當時提供批准/拒絕/修改選項
* **條件激活**：只在必要時要求批准
* **逾時處理**：始終為逾時配置備用動作

### 信心度閘門配置

* **適當的閾值**：根據業務風險和品質需求設定閾值
* **多個來源**：結合多個信心度指標進行穩健的評估
* **學習模式**：使用學習閘門隨著時間推移改進閾值
* **不確定性分析**：啟用詳細的不確定性追蹤以供除錯
* **備用路徑**：為低信心度場景提供明確的路由

### 通道選擇

* **開發**：在測試和開發中使用主控台通道
* **生產**：實作用於可擴充部署的 Web API 通道
* **使用者體驗**：根據使用者偏好和工作流選擇通道
* **整合**：確保通道與現有批准系統整合
* **監視**：監視通道可用性和效能

### 績效和可擴充性

* **批次處理**：在大量場景中使用批次批准系統
* **逾時最佳化**：平衡 SLA 需求與使用者體驗
* **升級鏈**：實作高效升級以防止瓶頸
* **稽核效率**：配置稽核記錄以最小化效能影響
* **資源管理**：監視 HITL 資源使用情況並相應進行最佳化

### 合規性和安全性

* **稽核軌跡**：為所有人工交互保持全面的稽核日誌
* **使用者身份驗證**：實作適當的使用者識別和授權
* **資料清理**：清理批准請求中的敏感資料
* **保留原則**：為合規性配置適當的資料保留
* **存取控制**：根據使用者角色和權限限制 HITL 存取

## 疑難排解

### 常見問題

**批准請求未顯示**：檢查交互通道是否已正確初始化並可用。

**逾時無法運作**：驗證逾時配置，並確保備用動作已正確配置。

**批次處理問題**：檢查批次管理員配置，並確保正確處理事件。

**信心度閘門未觸發**：驗證信心度來源配置和閾值設定。

**稽核日誌遺失**：確保已啟用稽核配置，並正確註冊稽核事件處理常式。

### 除錯 HITL

啟用詳細記錄以進行疑難排解：

```csharp
// 配置詳細 HITL 記錄
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableHITLLogging = true,
    HITLLogLevel = LogLevel.Trace
};

var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);

// 啟用通道特定除錯
consoleChannel.EnableDebugMode = true;
webApiChannel.EnableDebugMode = true;
```

### 績效監視

監視 HITL 績效指標：

```csharp
// 取得全面的 HITL 指標
var overallMetrics = await executor.GetHITLMetricsAsync();

Console.WriteLine($"HITL 績效摘要：");
Console.WriteLine($"  總交互數：{overallMetrics.TotalInteractions}");
Console.WriteLine($"  平均回應時間：{overallMetrics.AverageResponseTime}");
Console.WriteLine($"  SLA 合規率：{overallMetrics.SlaComplianceRate:P}");
Console.WriteLine($"  使用者滿意度：{overallMetrics.UserSatisfactionScore:F2}");
```

## 另請參閱

* [條件節點](conditional-nodes-quickstart.md) - 了解條件執行和路由
* [錯誤處理和復原力](error-handling-and-resilience.md) - 管理失敗和復原
* [狀態管理](state-quickstart.md) - 持續 HITL 狀態和決策
* [串流執行](streaming-quickstart.md) - 即時監視 HITL 事件
* [圖執行](execution.md) - 了解執行生命週期
