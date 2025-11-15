# 人類在迴路中 (HITL)

語義核心圖中的人類在迴路系統提供全面的功能，用於將人類決策整合到自動化工作流程中。它讓您能夠暫停圖執行、請求人類批准、驗證信心級別並管理批次批准程序。

## 概述

HITL 系統由幾個關鍵組件組成：

* **`HumanApprovalGraphNode`**：暫停執行以等待人類批准決策
* **`ConfidenceGateGraphNode`**：監控信心級別，當未達到閾值時觸發人類干預
* **`HumanApprovalBatchManager`**：有效地分組和管理多個批准請求
* **`HumanInteractionStore`**：持久化並協調 HITL 請求和回應
* **`WebApiHumanInteractionChannel`**：用於生產部署的基於網絡的互動通道

## 核心類別

### HumanApprovalGraphNode

暫停圖執行並等待人類批准後才繼續：

```csharp
public sealed class HumanApprovalGraphNode : IGraphNode
{
    public HumanApprovalGraphNode(
        string approvalTitle,
        string approvalMessage,
        IHumanInteractionChannel interactionChannel,
        string? nodeId = null,
        IGraphLogger? logger = null);
    
    public static HumanApprovalGraphNode CreateConditional(
        string approvalTitle,
        string approvalMessage,
        Func<GraphState, bool> activationCondition,
        IHumanInteractionChannel interactionChannel,
        string? nodeId = null,
        IGraphLogger? logger = null);
}
```

**構造函式參數：**
* `approvalTitle`：批准請求的標題
* `approvalMessage`：呈現給用戶的詳細訊息
* `interactionChannel`：用於用戶互動的通訊通道
* `nodeId`：節點的可選唯一識別碼
* `logger`：可選的診斷記錄器

**主要功能：**
* **條件啟動**：基於圖狀態的可選啟動條件
* **多個通道**：支援控制台、網路 API、CLI 和自訂通道
* **可配置的超時**：未收到回應時的自動回退操作
* **批次批准**：與批次批准管理的整合
* **上下文感知**：為人類決策提供豐富的上下文訊息
* **狀態修改**：可選的用戶批准的狀態變更
* **審計追蹤**：批准決策和元資料的全面追蹤

**輸入參數：**
* `execution_context`：當前執行上下文
* `previous_result`：前一個節點執行的結果
* `graph_state`：當前圖狀態
* `user_context`：用戶特定的上下文訊息

**輸出參數：**
* `approval_result`：批准決策的布林值結果
* `user_response`：完整的用戶回應物件
* `approved_by`：進行決策的用戶的識別碼
* `approval_timestamp`：做出決策的時間
* `user_modifications`：用戶請求的任何狀態修改

### ConfidenceGateGraphNode

監控信心級別，當未達到閾值時觸發人類干預：

```csharp
public sealed class ConfidenceGateGraphNode : IGraphNode
{
    public ConfidenceGateGraphNode(
        double confidenceThreshold = 0.7,
        string? nodeId = null,
        IGraphLogger? logger = null);
    
    public static ConfidenceGateGraphNode CreateWithInteraction(
        double confidenceThreshold,
        IHumanInteractionChannel interactionChannel,
        string? nodeId = null,
        IGraphLogger? logger = null);
}
```

**構造函式參數：**
* `confidenceThreshold`：最小信心閾值 (0.0 到 1.0)
* `nodeId`：節點的可選唯一識別碼
* `logger`：可選的診斷記錄器

**主要功能：**
* **可配置的閾值**：為自動處理設定最小信心級別
* **多個來源**：支援 LLM 信心、相似度分數和自訂指標
* **自動分析**：偵測不確定性和潛在問題的模式
* **升級級別**：根據信心嚴重程度的不同批准要求
* **學習能力**：根據歷史反饋調整閾值
* **手動繞過**：可選的手動覆蓋功能

**輸入參數：**
* `confidence_score`：整體信心分數
* `uncertainty_factors`：導致不確定性的因素
* `llm_confidence`：LLM 生成的信心指標
* `similarity_scores`：基於相似度的信心指標
* `validation_results`：驗證結果信心
* `previous_confidence_history`：歷史信心資料

**輸出參數：**
* `gate_result`：閘門是否通過或阻止執行
* `confidence_level`：當前信心級別評估
* `uncertainty_analysis`：詳細的不確定性因素分析
* `human_override`：是否應用了手動覆蓋
* `confidence_sources`：對信心計算有貢獻的來源
* `gate_decision_reason`：閘門決策的說明

### HumanApprovalBatchManager

有效地管理和處理多個批准請求：

```csharp
public sealed class HumanApprovalBatchManager : IDisposable
{
    public HumanApprovalBatchManager(
        IHumanInteractionChannel defaultChannel,
        BatchApprovalOptions? options = null,
        IGraphLogger? logger = null);
}
```

**構造函式參數：**
* `defaultChannel`：用於處理批次的預設互動通道
* `options`：批次處理的組態選項
* `logger`：可選的診斷記錄器

**主要功能：**
* **智能分組**：按類型、優先順序、用戶和上下文分組請求
* **可配置的超時**：批次形成和處理超時
* **部分批准**：選項以處理不完整的批次
* **詳細統計**：效能和使用指標
* **執行緒安全**：安全的並行操作
* **持久化**：可選的批次狀態持久化

**事件：**
* `BatchFormed`：當批次準備好處理時引發
* `BatchCompleted`：當批次處理完成時引發
* `RequestAddedToBatch`：當請求新增到批次時引發

**批次組態選項：**
```csharp
public class BatchApprovalOptions
{
    public int MaxBatchSize { get; set; } = 10;
    public TimeSpan BatchFormationTimeout { get; set; } = TimeSpan.FromMinutes(5);
    public TimeSpan MaxBatchAge { get; set; } = TimeSpan.FromHours(1);
    public bool AllowPartialBatches { get; set; } = true;
    public string[] GroupingCriteria { get; set; } = { "type", "priority" };
}
```

### HumanInteractionStore

抽象化 HITL 請求和回應的持久化和協調：

```csharp
public interface IHumanInteractionStore
{
    Task<bool> AddPendingAsync(HumanInterruptionRequest request, CancellationToken cancellationToken = default);
    Task<HumanInterruptionRequest?> GetRequestAsync(string requestId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<HumanInterruptionRequest>> ListPendingAsync(string? executionId = null, string? nodeId = null, CancellationToken cancellationToken = default);
    Task<bool> SubmitResponseAsync(HumanInterruptionResponse response, CancellationToken cancellationToken = default);
    Task<bool> CancelAsync(string requestId, CancellationToken cancellationToken = default);
    Task<ApprovalStatus> GetStatusAsync(string requestId, CancellationToken cancellationToken = default);
    Task<HumanInterruptionResponse> AwaitResponseAsync(string requestId, CancellationToken cancellationToken = default);
}
```

**主要功能：**
* **請求管理**：新增、擷取和追蹤待處理的請求
* **回應處理**：提交和處理用戶回應
* **狀態追蹤**：在整個生命週期中監控請求狀態
* **篩選**：按執行 ID 或節點 ID 列出請求
* **非同步操作**：非阻塞請求/回應處理
* **取消支援**：待處理請求的優雅取消

**事件：**
* `RequestAdded`：當新請求被新增時引發
* `ResponseSubmitted`：當回應被提交時引發
* `RequestCancelled`：當請求被取消時引發

### WebApiHumanInteractionChannel

用於生產部署的基於網絡的互動通道：

```csharp
public sealed class WebApiHumanInteractionChannel : IHumanInteractionChannel, IDisposable
{
    public WebApiHumanInteractionChannel(IHumanInteractionStore store);
    
    public async Task InitializeAsync(Dictionary<string, object>? configuration = null);
}
```

**構造函式參數：**
* `store`：用於請求/回應協調的支援儲存

**主要功能：**
* **網路 API 整合**：透過支援儲存為 REST 消費公開請求
* **事件驅動**：為請求生命週期變更引發事件
* **組態**：靈活的組態選項
* **儲存協作**：與任何 `IHumanInteractionStore` 實作合作
* **生產就緒**：為基於網絡的批准介面設計

**事件：**
* `ResponseReceived`：當收到回應時引發
* `RequestTimedOut`：當請求逾時時引發
* `RequestAvailable`：當新請求可用時引發
* `RequestCancelled`：當請求被取消時引發

## 組態和選項

### HumanInteractionTimeout

配置人類互動的超時行為：

```csharp
public class HumanInteractionTimeout
{
    public TimeSpan PrimaryTimeout { get; set; } = TimeSpan.FromMinutes(30);
    public TimeSpan EscalationTimeout { get; set; } = TimeSpan.FromHours(2);
    public TimeoutAction DefaultAction { get; set; } = TimeoutAction.Reject;
    public bool EnableEscalation { get; set; } = false;
    public string[] EscalationRecipients { get; set; } = Array.Empty<string>();
}
```

**屬性：**
* **`PrimaryTimeout`**：互動的初始超時
* **`EscalationTimeout`**：升級情景中的延長超時
* **`DefaultAction`**：超時發生時採取的操作
* **`EnableEscalation`**：是否啟用超時升級
* **`EscalationRecipients`**：升級通知的接收者

### HumanInteractionOption

定義用戶選擇的可用選項：

```csharp
public class HumanInteractionOption
{
    public string OptionId { get; set; } = string.Empty;
    public string DisplayText { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public object? Value { get; set; }
    public bool IsDefault { get; set; } = false;
    public bool RequiresJustification { get; set; } = false;
    public string[] AllowedUsers { get; set; } = Array.Empty<string>();
}
```

**屬性：**
* **`OptionId`**：選項的唯一識別碼
* **`DisplayText`**：人類可讀的顯示文字
* **`Description`**：選項的詳細說明
* **`Value`**：選定選項時傳回的值
* **`IsDefault`**：這是否為預設選項
* **`RequiresJustification`**：是否需要正當理由
* **`AllowedUsers`**：允許選擇此選項的用戶

### BatchApprovalOptions

配置批次批准處理行為：

```csharp
public class BatchApprovalOptions
{
    public int MaxBatchSize { get; set; } = 10;
    public TimeSpan BatchFormationTimeout { get; set; } = TimeSpan.FromMinutes(5);
    public TimeSpan MaxBatchAge { get; set; } = TimeSpan.FromHours(1);
    public bool AllowPartialBatches { get; set; } = true;
    public string[] GroupingCriteria { get; set; } = { "type", "priority" };
    public bool EnableNotifications { get; set; } = true;
    public string[] NotificationChannels { get; set; } = { "email", "webhook" };
}
```

**屬性：**
* **`MaxBatchSize`**：每個批次的最大請求數
* **`BatchFormationTimeout`**：等待批次形成的時間
* **`MaxBatchAge`**：批次處理前的最大存留期
* **`AllowPartialBatches`**：是否處理不完整的批次
* **`GroupingCriteria`**：分組請求的條件
* **`EnableNotifications`**：是否啟用批次通知
* **`NotificationChannels`**：批次通知的通道

## 使用範例

### 基本人類批准

使用控制台互動建立簡單的批准節點：

```csharp
// 建立控制台互動通道
var consoleChannel = new ConsoleHumanInteractionChannel();

// 建立批准節點
var approvalNode = new HumanApprovalGraphNode(
    "文件審查",
    "請審查生成的文件，確保其準確性和完整性",
    consoleChannel,
    "doc_review_approval");

// 配置批准選項
approvalNode.AddApprovalOption("approve", "批准並繼續", true, true)
            .AddApprovalOption("reject", "拒絕並停止", false)
            .AddApprovalOption("modify", "批准並修改", "modified");

// 配置超時
approvalNode.WithTimeout(TimeSpan.FromHours(24), TimeoutAction.Reject);

// 新增到圖
graph.AddNode(approvalNode);
graph.AddEdge(previousNode, approvalNode);
```

### 條件批准

建立僅在特定條件下啟動的批准節點：

```csharp
// 建立條件批准節點
var conditionalApproval = HumanApprovalGraphNode.CreateConditional(
    "高風險交易",
    "交易金額超過閾值時需要批准",
    state => state.GetValue<decimal>("transaction_amount") > 10000m,
    consoleChannel,
    "high_risk_approval");

// 配置優先順序和超時
conditionalApproval.WithPriority(InteractionPriority.High)
                  .WithTimeout(TimeSpan.FromHours(4), TimeoutAction.Escalate);

// 新增批准選項
conditionalApproval.AddApprovalOption("approve", "批准交易", true)
                  .AddApprovalOption("reject", "拒絕交易", false)
                  .AddApprovalOption("review", "要求進一步審查", "review");

// 根據批准結果新增路由
// 使用執行器助手新增條件路由。使用 KernelArguments 述詞
// 來評估批准節點傳回的 approval_result。
graph.ConnectWhen(
    conditionalApproval.NodeId,
    approvedNode.NodeId,
    args => args.TryGetValue("approval_result", out var v) && v is bool b && b,
    "approval_result_true");

graph.ConnectWhen(
    conditionalApproval.NodeId,
    rejectedNode.NodeId,
    args => args.TryGetValue("approval_result", out var v) && v is bool b && !b,
    "approval_result_false");

graph.ConnectWhen(
    conditionalApproval.NodeId,
    reviewNode.NodeId,
    args => args.TryGetValue("approval_result", out var v) && v?.ToString() == "review",
    "approval_result_review");
```

### 信心閘門

監控信心級別並觸發人類干預：

```csharp
// 建立信心閘門節點
var confidenceGate = new ConfidenceGateGraphNode(
    confidenceThreshold: 0.8,
    nodeId: "quality_gate");

// 配置信心來源
confidenceGate.ConfidenceSources.Add(new LLMConfidenceSource("llm_confidence"));
confidenceGate.ConfidenceSources.Add(new SimilarityConfidenceSource("similarity_score"));
confidenceGate.ConfidenceSources.Add(new ValidationConfidenceSource("validation_result"));

// 配置聚合策略
confidenceGate.AggregationStrategy = ConfidenceAggregationStrategy.WeightedAverage;

// 配置人類互動的超時
confidenceGate.TimeoutConfiguration.PrimaryTimeout = TimeSpan.FromMinutes(30);
confidenceGate.TimeoutConfiguration.DefaultAction = TimeoutAction.Reject;

// 允許手動繞過緊急情況
confidenceGate.WithManualBypass(true);

// 新增到圖
graph.AddNode(confidenceGate);
graph.AddEdge(previousNode, confidenceGate);
```

### 批次批准管理

有效地管理多個批准請求：

```csharp
// 建立批次管理器
var batchManager = new HumanApprovalBatchManager(
    defaultChannel: consoleChannel,
    options: new BatchApprovalOptions
    {
        MaxBatchSize = 20,
        BatchFormationTimeout = TimeSpan.FromMinutes(10),
        AllowPartialBatches = true,
        GroupingCriteria = new[] { "type", "priority" }
    });

// 訂閱批次事件
batchManager.BatchFormed += (sender, batch) =>
{
    Console.WriteLine($"批次 {batch.BatchId} 已形成，包含 {batch.Requests.Count} 個請求");
};

batchManager.BatchCompleted += (sender, args) =>
{
    Console.WriteLine($"批次 {args.Batch.BatchId} 已完成，耗時 {args.ProcessingTime}");
};

// 在批准節點中使用批次管理器
var batchApprovalNode = new HumanApprovalGraphNode(
    "批次文件審查",
    "審查多份文件進行批准",
    consoleChannel,
    "batch_doc_review");

// 配置批次處理
batchApprovalNode.WithTimeout(TimeSpan.FromHours(2), TimeoutAction.Escalate);
```

### 網路 API 整合

實作基於網絡的批准介面：

```csharp
// 建立網路 API 互動通道
var interactionStore = new InMemoryHumanInteractionStore();
var webApiChannel = new WebApiHumanInteractionChannel(interactionStore);

// 初始化網路 API 通道
await webApiChannel.InitializeAsync(new Dictionary<string, object>
{
    ["api_base_url"] = "https://api.example.com/approvals",
    ["timeout_seconds"] = 300,
    ["enable_notifications"] = true
});

// 訂閱通道事件
webApiChannel.ResponseReceived += (sender, response) =>
{
    Console.WriteLine($"收到回應：{response.Status}，請求 {response.RequestId}");
};

webApiChannel.RequestTimedOut += (sender, request) =>
{
    Console.WriteLine($"請求 {request.RequestId} 逾時");
};

// 建立基於網絡的批准節點
var webApprovalNode = new HumanApprovalGraphNode(
    "網絡文件批准",
    "透過網絡介面批准文件",
    webApiChannel,
    "web_doc_approval");

// 配置網絡特定選項
webApprovalNode.WithTimeout(TimeSpan.FromHours(24), TimeoutAction.Escalate)
               .WithPriority(InteractionPriority.Normal);

// 新增批准選項
webApprovalNode.AddApprovalOption("approve", "批准文件", true, true)
               .AddApprovalOption("reject", "拒絕文件", false)
               .AddApprovalOption("modify", "要求修改", "modify");
```

## 與圖執行器的整合

### 核心建構器擴充

將 HITL 支援新增到核心建構器：

```csharp
var builder = Kernel.CreateBuilder();

// 新增基本 HITL 支援
builder.AddHumanInTheLoop(consoleChannel);

// 新增基於控制台的 HITL
builder.AddConsoleHumanInteraction(new Dictionary<string, object>
{
    ["prompt_format"] = "需要批准：{message}\n輸入 'approve' 或 'reject'：",
    ["validation_pattern"] = @"^(approve|reject)$",
    ["retry_count"] = 3
});

// 新增基於網路 API 的 HITL
builder.AddWebApiHumanInteraction();

// 建構具有 HITL 支援的核心
var kernel = builder.Build();
```

### 圖執行器配置

在執行器層級配置 HITL 行為：

```csharp
var executor = new GraphExecutor("hitl-enabled-graph");

// 設定預設 HITL 超時
executor.WithHumanApprovalTimeout(TimeSpan.FromHours(24), TimeoutAction.Reject);

// 配置 HITL 審計服務
executor.WithHitlAuditService(new HitlAuditService(
    interactionStore: interactionStore,
    memoryService: memoryService,
    logger: logger));

// 新增 HITL 指標收集
executor.WithHitlMetrics(new HitlMetricsCollector());
```

## 進階模式

### 多級別批准

實作分層批准工作流程：

```csharp
// 第一級：基本批准
var level1Approval = new HumanApprovalGraphNode(
    "第一級批准",
    "初步審查和批准",
    consoleChannel,
    "level1_approval");

// 第二級：經理批准（僅當金額 > 閾值時）
var level2Approval = HumanApprovalGraphNode.CreateConditional(
    "第二級批准",
    "高值交易需要經理批准",
    state => state.GetValue<decimal>("transaction_amount") > 50000m,
    managerChannel,
    "level2_approval");

// 第三級：執行管理者批准（僅當金額 > 閾值時）
var level3Approval = HumanApprovalGraphNode.CreateConditional(
    "第三級批准",
    "關鍵交易需要執行管理者批准",
    state => state.GetValue<decimal>("transaction_amount") > 100000m,
    executiveChannel,
    "level3_approval");

// 配置批准鏈
level1Approval.WithTimeout(TimeSpan.FromHours(4), TimeoutAction.Escalate);
level2Approval.WithTimeout(TimeSpan.FromHours(8), TimeoutAction.Escalate);
level3Approval.WithTimeout(TimeSpan.FromHours(24), TimeoutAction.Reject);

// 新增到圖並進行條件路由
graph.AddEdge(level1Approval, level2Approval);
// 根據 KernelArguments 中的 transaction_amount 路由
graph.ConnectWhen(
    level2Approval.NodeId,
    level3Approval.NodeId,
    args => args.TryGetValue("transaction_amount", out var v) &&
            decimal.TryParse(v?.ToString(), out var amt) && amt > 100000m,
    "transaction_amount_gt_100000");
```

### 基於信心的路由

根據信心級別路由執行：

```csharp
// 建立信心閘門
var confidenceGate = new ConfidenceGateGraphNode(0.7, "quality_gate");

// 配置信心來源
confidenceGate.ConfidenceSources.Add(new LLMConfidenceSource("llm_confidence"));
confidenceGate.ConfidenceSources.Add(new ValidationConfidenceSource("validation_score"));

// 根據信心新增路由
// 根據信心閘門節點產生的 gate_result 路由
graph.ConnectWhen(
    confidenceGate.NodeId,
    highConfidenceNode.NodeId,
    args => args.TryGetValue("gate_result", out var v) && v is bool bv && bv,
    "gate_result_true");

graph.ConnectWhen(
    confidenceGate.NodeId,
    lowConfidenceNode.NodeId,
    args => args.TryGetValue("gate_result", out var v) && v is bool bv2 && !bv2,
    "gate_result_false");

// 使用人類批准配置低信心路徑
var humanReviewNode = new HumanApprovalGraphNode(
    "需要人類審查",
    "低信心結果需要人類審查",
    consoleChannel,
    "human_review");

lowConfidenceNode.AddEdge(humanReviewNode);
```

### 批次處理與升級

處理具有升級邏輯的批次批准：

```csharp
// 建立具有升級的批次管理器
var batchManager = new HumanApprovalBatchManager(
    defaultChannel: consoleChannel,
    options: new BatchApprovalOptions
    {
        MaxBatchSize = 15,
        BatchFormationTimeout = TimeSpan.FromMinutes(15),
        AllowPartialBatches = false
    });

// 訂閱批次事件
batchManager.BatchFormed += async (sender, batch) =>
{
    // 傳送批次通知
    await SendBatchNotificationAsync(batch);
    
    // 啟動升級計時器
    _ = Task.Run(async () =>
    {
        await Task.Delay(TimeSpan.FromMinutes(30));
        if (batch.Requests.Any(r => r.Status == ApprovalStatus.Pending))
        {
            await EscalateBatchAsync(batch);
        }
    });
};

// 在批准工作流程中使用批次管理器
var batchApprovalNode = new HumanApprovalGraphNode(
    "批次文件審查",
    "審查多份文件進行批准",
    consoleChannel,
    "batch_doc_review");

// 配置批次處理
batchApprovalNode.WithTimeout(TimeSpan.FromHours(1), TimeoutAction.Escalate);
```

## 效能和監控

### 指標收集

監控 HITL 效能和使用情況：

```csharp
// 建立 HITL 指標收集器
var hitlMetrics = new HitlMetricsCollector();

// 訂閱批准事件
approvalNode.ApprovalCompleted += (sender, args) =>
{
    hitlMetrics.RecordApproval(
        nodeId: args.NodeId,
        duration: args.Duration,
        result: args.Result,
        channel: args.ChannelType);
};

// 訂閱信心閘門事件
confidenceGate.GateActivated += (sender, args) =>
{
    hitlMetrics.RecordGateActivation(
        nodeId: args.NodeId,
        confidenceLevel: args.ConfidenceLevel,
        threshold: args.Threshold);
};

// 取得 HITL 效能摘要
var summary = hitlMetrics.GetPerformanceSummary();
Console.WriteLine($"平均批准時間：{summary.AverageApprovalTime}");
Console.WriteLine($"信心閘門啟動率：{summary.GateActivationRate:P2}");
```

### 審計追蹤

維護全面的審計記錄：

```csharp
// 建立 HITL 審計服務
var auditService = new HitlAuditService(
    interactionStore: interactionStore,
    memoryService: memoryService,
    logger: logger);

// 配置審計選項
auditService.Configure(new HitlAuditOptions
{
    EnableDetailedLogging = true,
    RetainAuditDataFor = TimeSpan.FromDays(90),
    LogSensitiveData = false,
    EnableComplianceReporting = true
});

// 訂閱審計事件
auditService.AuditRecordCreated += (sender, record) =>
{
    Console.WriteLine($"已建立審計記錄：{record.RecordId}");
};

// 取得審計摘要
var auditSummary = await auditService.GetAuditSummaryAsync(
    startDate: DateTimeOffset.UtcNow.AddDays(-30),
    endDate: DateTimeOffset.UtcNow);
```

## 安全性和合規性

### 驗證和授權

保護 HITL 互動：

```csharp
// 建立經過驗證的互動通道
var authenticatedChannel = new AuthenticatedHumanInteractionChannel(
    baseChannel: webApiChannel,
    authProvider: new JwtAuthProvider(),
    userStore: new UserStore());

// 配置授權策略
authenticatedChannel.ConfigureAuthorization(new AuthorizationPolicy
{
    RequireAuthentication = true,
    RequireApprovalRole = true,
    AllowedRoles = new[] { "approver", "manager", "admin" },
    RequireMFA = true
});

// 在批准節點中使用經過驗證的通道
var secureApprovalNode = new HumanApprovalGraphNode(
    "安全文件批准",
    "批准需要適當的驗證和授權",
    authenticatedChannel,
    "secure_approval");
```

### 資料隱私

在 HITL 工作流程中保護敏感訊息：

```csharp
// 建立隱私感知批准節點
var privacyApprovalNode = new HumanApprovalGraphNode(
    "隱私審查",
    "審查資料處理以確保隱私合規性",
    consoleChannel,
    "privacy_approval");

// 配置隱私選項
privacyApprovalNode.AllowStateModifications = false; // 防止狀態變更
privacyApprovalNode.WithPrivacyProtection(new PrivacyProtectionOptions
{
    MaskSensitiveData = true,
    LogAccessAttempts = true,
    RequireJustification = true,
    AuditDataAccess = true
});

// 新增隱私特定的批准選項
privacyApprovalNode.AddApprovalOption("approve", "批准處理", true)
                   .AddApprovalOption("reject", "拒絕處理", false)
                   .AddApprovalOption("modify", "要求修改", "modify");
```

## 另請參閱

* [人類在迴路指南](../how-to/human-in-the-loop.md) - 全面的 HITL 概念和技術指南
* [條件節點](./conditional-nodes.md) - 條件執行和路由模式
* [圖狀態](./graph-state.md) - HITL 工作流程的狀態管理
* [圖執行器](./graph-executor.md) - 支援 HITL 的核心執行引擎
* [HITL 範例](../../examples/hitl-examples.md) - 示範 HITL 功能的完整範例
