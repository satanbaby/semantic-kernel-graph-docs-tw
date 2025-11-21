# 人工介入循環 (HITL)

SemanticKernel.Graph 中的人工介入循環系統提供了將人工決策整合到自動化工作流程中的全面功能。它使您可以暫停圖表執行、要求人工批准、驗證信心水準，以及管理批量批准流程。

## 概述

HITL 系統由多個關鍵組件組成：

* **`HumanApprovalGraphNode`**：暫停執行以等待人工批准決策
* **`ConfidenceGateGraphNode`**：監視信心水準，並在不滿足閾值時觸發人工介入
* **`HumanApprovalBatchManager`**：高效地分組和管理多個批准請求
* **`HumanInteractionStore`**：持久化並協調 HITL 請求和回應
* **`WebApiHumanInteractionChannel`**：用於生產部署的基於 Web 的互動通道

## 核心類別

### HumanApprovalGraphNode

暫停圖表執行並等待人工批准後才繼續：

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

**建構函式參數：**
* `approvalTitle`：批准請求的標題
* `approvalMessage`：向使用者呈現的詳細訊息
* `interactionChannel`：用於使用者互動的通訊通道
* `nodeId`：節點的可選唯一識別碼
* `logger`：用於診斷的可選記錄器

**關鍵功能：**
* **條件啟動**：基於圖表狀態的可選啟動條件
* **多個通道**：支援控制台、Web API、CLI 和自訂通道
* **可設定的逾時**：當未收到回應時自動回退動作
* **批量批准**：與批量批准管理的整合
* **上下文感知**：為人工決策提供豐富的上下文資訊
* **狀態修改**：使用者批准的可選狀態變更
* **稽核軌跡**：批准決策和中繼資料的全面追蹤

**輸入參數：**
* `execution_context`：目前執行上下文
* `previous_result`：來自上一個節點執行的結果
* `graph_state`：目前圖表狀態
* `user_context`：使用者特定的上下文資訊

**輸出參數：**
* `approval_result`：批准決策的布林結果
* `user_response`：完整的使用者回應物件
* `approved_by`：做出決策的使用者識別碼
* `approval_timestamp`：做出決策的時間
* `user_modifications`：使用者要求的任何狀態修改

### ConfidenceGateGraphNode

監視信心水準，並在不滿足閾值時觸發人工介入：

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

**建構函式參數：**
* `confidenceThreshold`：最小信心閾值 (0.0 到 1.0)
* `nodeId`：節點的可選唯一識別碼
* `logger`：用於診斷的可選記錄器

**關鍵功能：**
* **可設定的閾值**：為自動處理設定最小信心水準
* **多個來源**：支援 LLM 信心、相似性分數和自訂計量
* **自動分析**：偵測不確定性的模式和潛在問題
* **升級水準**：根據信心嚴重程度的不同批准要求
* **學習功能**：根據歷史回饋調整閾值
* **手動略過**：可選的手動覆寫功能

**輸入參數：**
* `confidence_score`：整體信心分數
* `uncertainty_factors`：導致不確定性的因素
* `llm_confidence`：LLM 生成的信心計量
* `similarity_scores`：基於相似性的信心指標
* `validation_results`：驗證結果信心
* `previous_confidence_history`：歷史信心資料

**輸出參數：**
* `gate_result`：閘道是否通過或阻止執行
* `confidence_level`：目前信心水準評估
* `uncertainty_analysis`：詳細的不確定性因素分析
* `human_override`：是否套用了手動覆寫
* `confidence_sources`：對信心計算有貢獻的來源
* `gate_decision_reason`：閘道決策的說明

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

**建構函式參數：**
* `defaultChannel`：用於處理批次的預設互動通道
* `options`：批次處理的設定選項
* `logger`：用於診斷的可選記錄器

**關鍵功能：**
* **智能分組**：按類型、優先順序、使用者和上下文分組請求
* **可設定的逾時**：批次形成和處理逾時
* **部分批准**：選項以處理不完整的批次
* **詳細統計資訊**：效能和使用量計量
* **執行緒安全**：安全的並行操作
* **持久化**：可選的批次狀態持久化

**事件：**
* `BatchFormed`：當批次準備好進行處理時引發
* `BatchCompleted`：當批次處理完成時引發
* `RequestAddedToBatch`：當請求添加到批次時引發

**批次配置選項：**
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

抽象化 HITL 請求和回應的持久化與協調：

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

**關鍵功能：**
* **請求管理**：新增、擷取和追蹤待處理請求
* **回應處理**：提交和處理使用者回應
* **狀態追蹤**：在整個生命週期中監視請求狀態
* **篩選**：按執行 ID 或節點 ID 列出請求
* **非同步操作**：非阻塞的請求/回應處理
* **取消支援**：待處理請求的優雅取消

**事件：**
* `RequestAdded`：當新請求被添加時引發
* `ResponseSubmitted`：當回應被提交時引發
* `RequestCancelled`：當請求被取消時引發

### WebApiHumanInteractionChannel

用於生產部署的基於 Web 的互動通道：

```csharp
public sealed class WebApiHumanInteractionChannel : IHumanInteractionChannel, IDisposable
{
    public WebApiHumanInteractionChannel(IHumanInteractionStore store);
    
    public async Task InitializeAsync(Dictionary<string, object>? configuration = null);
}
```

**建構函式參數：**
* `store`：用於請求/回應協調的後端存放區

**關鍵功能：**
* **Web API 整合**：透過後端存放區公開請求供 REST 消費
* **事件驅動**：為請求生命週期變更引發事件
* **設定**：彈性的設定選項
* **存放區協作**：與任何 `IHumanInteractionStore` 實作搭配使用
* **生產就緒**：為 Web 型批准介面設計

**事件：**
* `ResponseReceived`：當收到回應時引發
* `RequestTimedOut`：當請求逾時時引發
* `RequestAvailable`：當新請求可用時引發
* `RequestCancelled`：當請求被取消時引發

## 設定和選項

### HumanInteractionTimeout

設定人工互動的逾時行為：

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
* **`PrimaryTimeout`**：互動的初始逾時
* **`EscalationTimeout`**：升級情況下的延長逾時
* **`DefaultAction`**：發生逾時時要採取的動作
* **`EnableEscalation`**：是否啟用逾時升級
* **`EscalationRecipients`**：升級通知的收件人

### HumanInteractionOption

定義可供使用者選擇的選項：

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
* **`DisplayText`**：用於顯示的人工可讀文字
* **`Description`**：選項的詳細說明
* **`Value`**：選取選項時傳回的值
* **`IsDefault`**：這是否為預設選項
* **`RequiresJustification`**：是否需要理由
* **`AllowedUsers`**：允許選取此選項的使用者

### BatchApprovalOptions

設定批量批准處理行為：

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
* **`MaxBatchAge`**：批次在處理前的最大年齡
* **`AllowPartialBatches`**：是否處理不完整的批次
* **`GroupingCriteria`**：用於分組請求的條件
* **`EnableNotifications`**：是否啟用批次通知
* **`NotificationChannels`**：用於批次通知的通道

## 使用範例

### 基本人工批准

使用控制台互動建立簡單的批准節點：

```csharp
// 建立控制台互動通道
var consoleChannel = new ConsoleHumanInteractionChannel();

// 建立批准節點
var approvalNode = new HumanApprovalGraphNode(
    "Document Review",
    "Please review the generated document for accuracy and completeness",
    consoleChannel,
    "doc_review_approval");

// 設定批准選項
approvalNode.AddApprovalOption("approve", "Approve and Continue", true, true)
            .AddApprovalOption("reject", "Reject and Stop", false)
            .AddApprovalOption("modify", "Approve with Modifications", "modified");

// 設定逾時
approvalNode.WithTimeout(TimeSpan.FromHours(24), TimeoutAction.Reject);

// 添加到圖表
graph.AddNode(approvalNode);
graph.AddEdge(previousNode, approvalNode);
```

### 條件式批准

建立只在特定條件下啟動的批准節點：

```csharp
// 建立條件式批准節點
var conditionalApproval = HumanApprovalGraphNode.CreateConditional(
    "High-Risk Transaction",
    "Approval required for transactions above threshold",
    state => state.GetValue<decimal>("transaction_amount") > 10000m,
    consoleChannel,
    "high_risk_approval");

// 設定優先順序和逾時
conditionalApproval.WithPriority(InteractionPriority.High)
                  .WithTimeout(TimeSpan.FromHours(4), TimeoutAction.Escalate);

// 新增批准選項
conditionalApproval.AddApprovalOption("approve", "Approve Transaction", true)
                  .AddApprovalOption("reject", "Reject Transaction", false)
                  .AddApprovalOption("review", "Request Additional Review", "review");

// 根據批准結果新增路由
// 使用執行器幫助程式新增條件式路由。使用 KernelArguments 謂詞
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

### 信心閘道

監視信心水準並觸發人工介入：

```csharp
// 建立信心閘道節點
var confidenceGate = new ConfidenceGateGraphNode(
    confidenceThreshold: 0.8,
    nodeId: "quality_gate");

// 設定信心來源
confidenceGate.ConfidenceSources.Add(new LLMConfidenceSource("llm_confidence"));
confidenceGate.ConfidenceSources.Add(new SimilarityConfidenceSource("similarity_score"));
confidenceGate.ConfidenceSources.Add(new ValidationConfidenceSource("validation_result"));

// 設定聚合策略
confidenceGate.AggregationStrategy = ConfidenceAggregationStrategy.WeightedAverage;

// 設定人工互動的逾時
confidenceGate.TimeoutConfiguration.PrimaryTimeout = TimeSpan.FromMinutes(30);
confidenceGate.TimeoutConfiguration.DefaultAction = TimeoutAction.Reject;

// 允許手動略過以應對緊急情況
confidenceGate.WithManualBypass(true);

// 添加到圖表
graph.AddNode(confidenceGate);
graph.AddEdge(previousNode, confidenceGate);
```

### 批量批准管理

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
    Console.WriteLine($"Batch {batch.BatchId} formed with {batch.Requests.Count} requests");
};

batchManager.BatchCompleted += (sender, args) =>
{
    Console.WriteLine($"Batch {args.Batch.BatchId} completed in {args.ProcessingTime}");
};

// 在批准節點中使用批次管理器
var batchApprovalNode = new HumanApprovalGraphNode(
    "Batch Document Review",
    "Review multiple documents for approval",
    consoleChannel,
    "batch_doc_review");

// 設定批次處理
batchApprovalNode.WithTimeout(TimeSpan.FromHours(2), TimeoutAction.Escalate);
```

### Web API 整合

實作 Web 型批准介面：

```csharp
// 建立 Web API 互動通道
var interactionStore = new InMemoryHumanInteractionStore();
var webApiChannel = new WebApiHumanInteractionChannel(interactionStore);

// 初始化 Web API 通道
await webApiChannel.InitializeAsync(new Dictionary<string, object>
{
    ["api_base_url"] = "https://api.example.com/approvals",
    ["timeout_seconds"] = 300,
    ["enable_notifications"] = true
});

// 訂閱通道事件
webApiChannel.ResponseReceived += (sender, response) =>
{
    Console.WriteLine($"Received response: {response.Status} for request {response.RequestId}");
};

webApiChannel.RequestTimedOut += (sender, request) =>
{
    Console.WriteLine($"Request {request.RequestId} timed out");
};

// 建立 Web 型批准節點
var webApprovalNode = new HumanApprovalGraphNode(
    "Web Document Approval",
    "Approve document via web interface",
    webApiChannel,
    "web_doc_approval");

// 設定 Web 特定的選項
webApprovalNode.WithTimeout(TimeSpan.FromHours(24), TimeoutAction.Escalate)
               .WithPriority(InteractionPriority.Normal);

// 新增批准選項
webApprovalNode.AddApprovalOption("approve", "Approve Document", true, true)
               .AddApprovalOption("reject", "Reject Document", false)
               .AddApprovalOption("modify", "Request Modifications", "modify");
```

## 與 Graph Executor 的整合

### Kernel 建構器擴充

將 HITL 支援新增至核心建構器：

```csharp
var builder = Kernel.CreateBuilder();

// 新增基本 HITL 支援
builder.AddHumanInTheLoop(consoleChannel);

// 新增控制台型 HITL
builder.AddConsoleHumanInteraction(new Dictionary<string, object>
{
    ["prompt_format"] = "APPROVAL REQUIRED: {message}\nEnter 'approve' or 'reject': ",
    ["validation_pattern"] = @"^(approve|reject)$",
    ["retry_count"] = 3
});

// 新增 Web API 型 HITL
builder.AddWebApiHumanInteraction();

// 以 HITL 支援建立核心
var kernel = builder.Build();
```

### Graph Executor 設定

在執行器層級設定 HITL 行為：

```csharp
var executor = new GraphExecutor("hitl-enabled-graph");

// 設定預設 HITL 逾時
executor.WithHumanApprovalTimeout(TimeSpan.FromHours(24), TimeoutAction.Reject);

// 設定 HITL 稽核服務
executor.WithHitlAuditService(new HitlAuditService(
    interactionStore: interactionStore,
    memoryService: memoryService,
    logger: logger));

// 新增 HITL 計量收集
executor.WithHitlMetrics(new HitlMetricsCollector());
```

## 進階模式

### 多層級批准

實作分層式批准工作流程：

```csharp
// 第 1 層：基本批准
var level1Approval = new HumanApprovalGraphNode(
    "Level 1 Approval",
    "Initial review and approval",
    consoleChannel,
    "level1_approval");

// 第 2 層：經理批准 (僅在金額 > 閾值時)
var level2Approval = HumanApprovalGraphNode.CreateConditional(
    "Level 2 Approval",
    "Manager approval required for high-value transactions",
    state => state.GetValue<decimal>("transaction_amount") > 50000m,
    managerChannel,
    "level2_approval");

// 第 3 層：主管批准 (僅在金額 > 閾值時)
var level3Approval = HumanApprovalGraphNode.CreateConditional(
    "Level 3 Approval",
    "Executive approval required for critical transactions",
    state => state.GetValue<decimal>("transaction_amount") > 100000m,
    executiveChannel,
    "level3_approval");

// 設定批准鏈
level1Approval.WithTimeout(TimeSpan.FromHours(4), TimeoutAction.Escalate);
level2Approval.WithTimeout(TimeSpan.FromHours(8), TimeoutAction.Escalate);
level3Approval.WithTimeout(TimeSpan.FromHours(24), TimeoutAction.Reject);

// 新增至圖表並使用條件式路由
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

根據信心水準路由執行：

```csharp
// 建立信心閘道
var confidenceGate = new ConfidenceGateGraphNode(0.7, "quality_gate");

// 設定信心來源
confidenceGate.ConfidenceSources.Add(new LLMConfidenceSource("llm_confidence"));
confidenceGate.ConfidenceSources.Add(new ValidationConfidenceSource("validation_score"));

// 根據信心新增路由
// 根據信心閘道節點產生的 gate_result 路由
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

// 為低信心路徑設定人工批准
var humanReviewNode = new HumanApprovalGraphNode(
    "Human Review Required",
    "Low confidence result requires human review",
    consoleChannel,
    "human_review");

lowConfidenceNode.AddEdge(humanReviewNode);
```

### 帶升級的批次處理

使用升級邏輯處理批量批准：

```csharp
// 建立帶升級的批次管理器
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
    "Batch Document Review",
    "Review multiple documents for approval",
    consoleChannel,
    "batch_doc_review");

// 設定批次處理
batchApprovalNode.WithTimeout(TimeSpan.FromHours(1), TimeoutAction.Escalate);
```

## 效能和監視

### 計量收集

監視 HITL 效能和使用情況：

```csharp
// 建立 HITL 計量收集器
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

// 訂閱信心閘道事件
confidenceGate.GateActivated += (sender, args) =>
{
    hitlMetrics.RecordGateActivation(
        nodeId: args.NodeId,
        confidenceLevel: args.ConfidenceLevel,
        threshold: args.Threshold);
};

// 取得 HITL 效能摘要
var summary = hitlMetrics.GetPerformanceSummary();
Console.WriteLine($"Average approval time: {summary.AverageApprovalTime}");
Console.WriteLine($"Confidence gate activation rate: {summary.GateActivationRate:P2}");
```

### 稽核軌跡

維護全面的稽核記錄：

```csharp
// 建立 HITL 稽核服務
var auditService = new HitlAuditService(
    interactionStore: interactionStore,
    memoryService: memoryService,
    logger: logger);

// 設定稽核選項
auditService.Configure(new HitlAuditOptions
{
    EnableDetailedLogging = true,
    RetainAuditDataFor = TimeSpan.FromDays(90),
    LogSensitiveData = false,
    EnableComplianceReporting = true
});

// 訂閱稽核事件
auditService.AuditRecordCreated += (sender, record) =>
{
    Console.WriteLine($"Audit record created: {record.RecordId}");
};

// 取得稽核摘要
var auditSummary = await auditService.GetAuditSummaryAsync(
    startDate: DateTimeOffset.UtcNow.AddDays(-30),
    endDate: DateTimeOffset.UtcNow);
```

## 安全性和合規性

### 驗證和授權

保護 HITL 互動：

```csharp
// 建立驗證的互動通道
var authenticatedChannel = new AuthenticatedHumanInteractionChannel(
    baseChannel: webApiChannel,
    authProvider: new JwtAuthProvider(),
    userStore: new UserStore());

// 設定授權原則
authenticatedChannel.ConfigureAuthorization(new AuthorizationPolicy
{
    RequireAuthentication = true,
    RequireApprovalRole = true,
    AllowedRoles = new[] { "approver", "manager", "admin" },
    RequireMFA = true
});

// 在批准節點中使用驗證的通道
var secureApprovalNode = new HumanApprovalGraphNode(
    "Secure Document Approval",
    "Approval requires proper authentication and authorization",
    authenticatedChannel,
    "secure_approval");
```

### 資料隱私

保護 HITL 工作流程中的敏感資訊：

```csharp
// 建立隱私感知的批准節點
var privacyApprovalNode = new HumanApprovalGraphNode(
    "Privacy Review",
    "Review data processing for privacy compliance",
    consoleChannel,
    "privacy_approval");

// 設定隱私選項
privacyApprovalNode.AllowStateModifications = false; // 防止狀態變更
privacyApprovalNode.WithPrivacyProtection(new PrivacyProtectionOptions
{
    MaskSensitiveData = true,
    LogAccessAttempts = true,
    RequireJustification = true,
    AuditDataAccess = true
});

// 新增隱私特定的批准選項
privacyApprovalNode.AddApprovalOption("approve", "Approve Processing", true)
                   .AddApprovalOption("reject", "Reject Processing", false)
                   .AddApprovalOption("modify", "Request Modifications", "modify");
```

## 參見

* [人工介入循環指南](../how-to/human-in-the-loop.md) - HITL 概念和技術的全面指南
* [條件式節點](./conditional-nodes.md) - 條件式執行和路由模式
* [圖表狀態](./graph-state.md) - HITL 工作流程的狀態管理
* [Graph Executor](./graph-executor.md) - 支援 HITL 的核心執行引擎
* [HITL 範例](../../examples/hitl-examples.md) - 示範 HITL 功能的完整範例
