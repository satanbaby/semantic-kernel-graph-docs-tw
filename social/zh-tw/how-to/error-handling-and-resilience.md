# 錯誤處理與復原能力

SemanticKernel.Graph 的錯誤處理與復原能力提供強大的機制來處理失敗、實現重試策略，並通過斷路器和資源預算防止級聯故障。本指南涵蓋全面的錯誤處理系統，包括策略、指標收集和遙測。

## 您將學到

* 如何配置具有指數退避和抖動的重試策略
* 實現斷路器模式以防止級聯故障
* 管理資源預算並防止資源耗盡
* 通過註冊表配置錯誤處理策略
* 為複雜場景使用專門的錯誤處理 Node
* 收集和分析錯誤指標和遙測
* 在串流執行中處理失敗和取消事件

## 概念與技術

**ErrorPolicyRegistry**: 用於跨 Graph 管理錯誤處理策略的中央註冊表，支持重試、斷路器和預算策略。

**RetryPolicyGraphNode**: 用自動重試功能包裝其他 Node，支持可配置的退避策略和錯誤類型篩選。

**ErrorHandlerGraphNode**: 用於錯誤分類、恢復操作和基於錯誤類型的條件路由的專用 Node。

**NodeCircuitBreakerManager**: 管理每個 Node 的斷路器狀態，與資源治理和錯誤指標整合。

**ResourceGovernor**: 提供自適應速率限制和資源預算管理，防止資源耗盡。

**ErrorMetricsCollector**: 收集、聚合和分析錯誤指標，用於趨勢分析和異常檢測。

**ErrorHandlingTypes**: 具有 13 種錯誤類型和 8 種恢復操作的全面錯誤分類系統。

## 先決條件

* [第一個 Graph 教學](../first-graph-5-minutes.md)已完成
* 對 Graph 執行概念的基本理解
* 熟悉復原能力模式（重試、斷路器）
* 對資源管理原則的理解

## 錯誤類型和恢復操作

### 錯誤分類

SemanticKernel.Graph 將錯誤分為 13 種不同的類型，以實現精確的處理：

```csharp
// GraphErrorType: 錯誤處理元件使用的錯誤類型分類。
public enum GraphErrorType
{
    Unknown = 0,           // 未指定的錯誤類型
    Validation = 1,        // 輸入或架構驗證錯誤
    NodeExecution = 2,     // Node 執行期間拋出的錯誤
    Timeout = 3,           // 執行逾時
    Network = 4,           // 網路相關問題（通常可重試）
    ServiceUnavailable = 5,// 外部服務不可用
    RateLimit = 6,         // 上游服務超過速率限制
    Authentication = 7,    // 認證/授權失敗
    ResourceExhaustion = 8,// 記憶體/磁碟或配額耗盡
    GraphStructure = 9,    // Graph 遍歷或配置問題
    Cancellation = 10,     // 操作通過令牌被取消
    CircuitBreakerOpen = 11,// 斷路器目前處於開啟狀態
    BudgetExhausted = 12   // 達到資源或預算限制
}
```

### 恢復操作

八種恢復策略可用於不同的錯誤場景：

```csharp
// ErrorRecoveryAction: 當發生錯誤時建議的恢復策略。
public enum ErrorRecoveryAction
{
    Retry = 0,           // 使用配置的策略重試失敗的操作
    Skip = 1,            // 跳過失敗的 Node 並繼續
    Fallback = 2,        // 執行備用邏輯或替代 Node
    Rollback = 3,        // 回復到目前為止執行的狀態變更
    Halt = 4,            // 停止整個執行
    Escalate = 5,        // 升級到人工操作員或警告系統
    CircuitBreaker = 6,  // 觸發斷路器行為
    Continue = 7         // 儘管有錯誤也繼續（儘力）
}
```

## 重試策略和退避策略

### 基本重試配置

配置具有指數退避和抖動的重試策略：

```csharp
using SemanticKernel.Graph.Core;

// 配置具有指數退避和抖動的強大重試策略。
var retryConfig = new RetryPolicyConfig
{
    MaxRetries = 3,
    BaseDelay = TimeSpan.FromSeconds(1),
    MaxDelay = TimeSpan.FromMinutes(1),
    Strategy = RetryStrategy.ExponentialBackoff,
    BackoffMultiplier = 2.0,
    UseJitter = true,
    // 僅嘗試重試通常為瞬間的錯誤類型。
    RetryableErrorTypes = new HashSet<GraphErrorType>
    {
        GraphErrorType.Network,
        GraphErrorType.ServiceUnavailable,
        GraphErrorType.Timeout,
        GraphErrorType.RateLimit
    }
};
```

### 重試策略

支持多種重試策略：

```csharp
// RetryStrategy 控制如何計算嘗試之間的重試延遲。
public enum RetryStrategy
{
    NoRetry = 0,              // 不執行重試
    FixedDelay = 1,           // 嘗試之間的常數延遲
    LinearBackoff = 2,        // 延遲每次嘗試線性增加
    ExponentialBackoff = 3,   // 延遲呈指數增長（推薦）
    Custom = 4                // 使用者提供的自訂退避計算
}
```

### 使用 RetryPolicyGraphNode

用自動重試功能包裝任何 Node：

```csharp
using SemanticKernel.Graph.Nodes;

// 示例：建立一個簡單的函數 Node 並用重試行為包裝它。
// 'kernelFunction' 代表現有的 KernelFunction 實例。
var functionNode = new FunctionGraphNode("api-call", kernelFunction);

// 用配置的重試策略包裝以使呼叫具有復原能力。
var retryNode = new RetryPolicyGraphNode(functionNode, retryConfig);

// 將重試 Node 新增到 Graph 中並從開始 Node 連接。
graph.AddNode(retryNode);
graph.AddEdge(startNode, retryNode);
```

重試 Node 自動：
* 在 `KernelArguments` 中追蹤嘗試計數
* 應用帶有抖動的指數退避
* 篩選可重試的錯誤類型
* 在中繼資料中記錄重試統計資訊

## 斷路器模式

### 斷路器配置

配置斷路器以防止級聯故障：

```csharp
// 配置斷路器以防止級聯故障。
var circuitBreakerConfig = new CircuitBreakerPolicyConfig
{
    Enabled = true,
    FailureThreshold = 5,               // 開啟電路的故障次數
    OpenTimeout = TimeSpan.FromSeconds(30), // 在移至半開之前要等待的時間
    HalfOpenRetryCount = 3,             // 半開狀態下的探測嘗試次數
    FailureWindow = TimeSpan.FromMinutes(1), // 故障計數的時間窗口
    TriggerOnBudgetExhaustion = true    // 資源預算耗盡時開啟
};
```

### 斷路器狀態

斷路器在三種狀態下運行：

1. **Closed**: 正常運行，計算故障
2. **Open**: 電路開啟，操作被阻止
3. **Half-Open**: 允許有限操作來測試恢復

### 使用 NodeCircuitBreakerManager

在 Node 級別管理斷路器：

```csharp
using SemanticKernel.Graph.Core;

// 建立負責每個 Node 斷路器狀態的管理器。
var circuitBreakerManager = new NodeCircuitBreakerManager(
    graphLogger,
    errorMetricsCollector,
    eventStream,
    resourceGovernor,
    performanceMetrics);

// 將斷路器策略應用於特定的 Node ID。
circuitBreakerManager.ConfigureNode("api-node", circuitBreakerConfig);

// 通過斷路器管理器執行受保護的操作。提供
// 可選的備用方案在電路開啟或操作失敗時運行。
var result = await circuitBreakerManager.ExecuteAsync<string>(
    "api-node",
    executionId,
    async () => await apiCall(),
    async () => await fallbackCall()); // 可選備用方案
```

## 資源預算管理

### 資源治理配置

配置資源限制和自適應速率限制：

```csharp
// 配置資源治理以控制並行和資源使用。
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 50.0,      // 每秒基礎執行速率
    MaxBurstSize = 100,               // 允許的突發容量
    CpuHighWatermarkPercent = 85.0,   // CPU 使用率閾值用於強背壓
    CpuSoftLimitPercent = 70.0,       // 軟 CPU 閾值在節流之前
    MinAvailableMemoryMB = 512.0,     // 分配的最小可用記憶體
    DefaultPriority = ExecutionPriority.Normal
};

// 建立強制執行配置資源限制的治理者。
var resourceGovernor = new ResourceGovernor(resourceOptions);
```

### 執行優先級

四個優先級別影響資源分配：

```csharp
// ExecutionPriority 影響資源治理者如何分配許可。
public enum ExecutionPriority
{
    Low = 0,      // 低優先級（更高的相對成本）
    Normal = 1,   // 預設優先級
    High = 2,     // 延遲敏感型工作的高優先級
    Critical = 3  // 基本操作的最高優先級
}
```

### 資源租約

在執行前獲取資源許可：

```csharp
// 在執行工作前獲取資源租約。租約在處置時釋放。
using var lease = await resourceGovernor.AcquireAsync(
    workCostWeight: 2.0,                  // 此工作單位的成本權重
    priority: ExecutionPriority.High,
    cancellationToken);

// 在持有租約時執行受保護的工作。
await performWork();

// 租約在 'lease' 被處置時自動釋放（使用區塊結束）。
```

## 錯誤策略註冊表

### 集中式策略管理

`ErrorPolicyRegistry` 提供集中式錯誤處理策略：

```csharp
// 建立一個中央註冊表來保持由註冊表支持的策略使用的錯誤處理規則。
var registry = new ErrorPolicyRegistry(new ErrorPolicyRegistryOptions());

// 為網路錯誤註冊重試規則。執行期間註冊表將被
// 錯誤處理策略諮詢以確定恢復操作。
registry.RegisterPolicyRule(new PolicyRule
{
    ContextId = "Examples",
    ErrorType = GraphErrorType.Network,
    RecoveryAction = ErrorRecoveryAction.Retry,
    MaxRetries = 3,
    RetryDelay = TimeSpan.FromSeconds(1),
    BackoffMultiplier = 2.0,
    Priority = 100,
    Description = "重試網路錯誤"
});

// 為 'api-node' 註冊 Node 級別斷路器配置。
registry.RegisterNodeCircuitBreakerPolicy("api-node", circuitBreakerConfig);
```

### 策略解析

根據錯誤上下文和 Node 資訊解析策略：

```csharp
// 構造代表已捕獲異常的錯誤處理上下文。
var errorContext = new ErrorHandlingContext
{
    Exception = exception,
    ErrorType = GraphErrorType.Network,
    Severity = ErrorSeverity.Medium,
    AttemptNumber = 1,
    IsTransient = true
};

// 解析適用於此錯誤和執行上下文的策略。
var policy = registry.ResolvePolicy(errorContext, executionContext);
if (policy?.RecoveryAction == ErrorRecoveryAction.Retry)
{
    // 解析的策略指出此錯誤應被重試。
    // 重試協調應尊重 policy.MaxRetries 和計時值。
}
```

## 錯誤處理 Node

### ErrorHandlerGraphNode

用於複雜錯誤處理場景的專門 Node：

```csharp
// 建立一個專門的 Node 來檢查錯誤並相應地路由執行。
var errorHandler = new ErrorHandlerGraphNode(
    "error-handler",
    "ErrorHandler",
    "處理錯誤並路由執行");

// 將特定錯誤類型對應到恢復操作。
errorHandler.ConfigureErrorHandler(GraphErrorType.Network, ErrorRecoveryAction.Retry);
errorHandler.ConfigureErrorHandler(GraphErrorType.Authentication, ErrorRecoveryAction.Escalate);
errorHandler.ConfigureErrorHandler(GraphErrorType.BudgetExhausted, ErrorRecoveryAction.CircuitBreaker);

// 定義當選擇特定恢復操作時要執行的備用 Node。
errorHandler.AddFallbackNode(GraphErrorType.Network, fallbackNode);
errorHandler.AddFallbackNode(GraphErrorType.Authentication, escalationNode);

// 將錯誤處理程序新增到 Graph 中並根據錯誤標誌連接條件路由。
graph.AddNode(errorHandler);
graph.AddConditionalEdge(startNode, errorHandler,
    edge => edge.Condition = "HasError");
```

### 條件錯誤路由

根據錯誤類型和恢復操作路由執行：

```csharp
// 基於解析條件從錯誤處理程序進行條件路由的示例。
// 對於網路錯誤路由到重試 Node。
graph.AddConditionalEdge(errorHandler, retryNode,
    edge => edge.Condition = "ErrorType == 'Network'");

// 當恢復操作指示應運行備用時，路由到備用 Node。
graph.AddConditionalEdge(errorHandler, fallbackNode,
    edge => edge.Condition = "RecoveryAction == 'Fallback'");

// 對於高嚴重性問題路由到升級流。
graph.AddConditionalEdge(errorHandler, escalationNode,
    edge => edge.Condition = "ErrorSeverity >= 'High'");
```

## 錯誤指標和遙測

### 錯誤指標收集

收集全面的錯誤指標以進行分析：

```csharp
// 配置錯誤指標收集並初始化收集器。
var errorMetricsOptions = new ErrorMetricsOptions
{
    AggregationInterval = TimeSpan.FromMinutes(1),
    MaxEventQueueSize = 10000,
    EnableMetricsCleanup = true,
    MetricsRetentionPeriod = TimeSpan.FromDays(7)
};

var errorMetricsCollector = new ErrorMetricsCollector(errorMetricsOptions, graphLogger);

// 記錄一個樣本錯誤事件以驗證指標配管。
errorMetricsCollector.RecordError(
    executionId,
    nodeId,
    errorContext,
    recoveryAction: ErrorRecoveryAction.Retry,
    recoverySuccess: true);
```

### 錯誤事件結構

錯誤事件捕獲全面的資訊：

```csharp
// ErrorEvent: 描述單個已捕獲錯誤發生的不可變類 DTO。
public sealed class ErrorEvent
{
    public string EventId { get; set; }           // 事件的唯一識別符
    public string ExecutionId { get; set; }       // 執行上下文 ID
    public string NodeId { get; set; }            // 發生錯誤的 Node
    public GraphErrorType ErrorType { get; set; } // 已分類的錯誤類型
    public ErrorSeverity Severity { get; set; }   // 嚴重程度級別用於警告/升級
    public bool IsTransient { get; set; }         // 指示錯誤是否為瞬間
    public int AttemptNumber { get; set; }        // 錯誤發生時的嘗試次數
    public DateTimeOffset Timestamp { get; set; } // 錯誤被記錄的時間
    public string ExceptionType { get; set; }     // CLR 異常類型名稱
    public string ErrorMessage { get; set; }      // 異常訊息或錯誤描述
    public ErrorRecoveryAction? RecoveryAction { get; set; } // 建議的恢復操作
    public bool? RecoverySuccess { get; set; }    // 恢復是否成功
    public TimeSpan Duration { get; set; }        // 失敗操作的持續時間
}
```

### 指標查詢

查詢錯誤指標進行分析和監控：

```csharp
// 從收集器查詢並顯示執行特定的指標。
var executionMetrics = errorMetricsCollector.GetExecutionMetrics(executionId);
if (executionMetrics != null)
{
    Console.WriteLine($"總錯誤：{executionMetrics.TotalErrors}");
    Console.WriteLine($"恢復成功率：{executionMetrics.RecoverySuccessRate:F1}%");
    Console.WriteLine($"最常見的錯誤：{executionMetrics.MostCommonErrorType}");
}

// 查詢 Node 特定的指標進行目標故障排除。
var nodeMetrics = errorMetricsCollector.GetNodeMetrics(nodeId);
if (nodeMetrics != null)
{
    Console.WriteLine($"Node 錯誤率：{nodeMetrics.ErrorRate:F2} 錯誤/分鐘");
    Console.WriteLine($"恢復成功率：{nodeMetrics.RecoverySuccessRate:F1}%");
}

// 讀取收集器公開的總體聚合統計資訊。
var overallStats = errorMetricsCollector.OverallStatistics;
Console.WriteLine($"目前錯誤率：{overallStats.CurrentErrorRate:F2} 錯誤/分鐘");
Console.WriteLine($"記錄的總錯誤：{overallStats.TotalErrorsRecorded}");
```

## 與 Graph 執行的整合

### 錯誤處理中間件

將錯誤處理與 Graph 執行整合：

```csharp
// 使用由註冊表支持的錯誤處理策略來集中決策。
var errorHandlingPolicy = new RegistryBackedErrorHandlingPolicy(errorPolicyRegistry);

// 建立配置了錯誤處理和資源治理的 Graph 執行器。
var executor = new GraphExecutor("ResilientGraph", "具有錯誤處理的 Graph")
    .ConfigureErrorHandling(errorHandlingPolicy)
    .ConfigureResources(resourceOptions);

// 將錯誤指標收集器連接到執行器以進行遙測。
executor.ConfigureMetrics(new GraphMetricsOptions
{
    EnableErrorMetrics = true,
    ErrorMetricsCollector = errorMetricsCollector
});
```

### 串流錯誤事件

錯誤事件被發送到執行流：

```csharp
// 建立串流執行器並訂閱運行時事件，包括錯誤事件。
using var eventStream = executor.CreateStreamingExecutor()
    .CreateEventStream();

// 訂閱執行事件並處理 Node 錯誤事件以進行可觀測性。
eventStream.SubscribeToEvents<GraphExecutionEvent>(evt =>
{
    if (evt.EventType == GraphExecutionEventType.NodeError)
    {
        var errorEvent = evt as NodeErrorEvent;
        Console.WriteLine($"{errorEvent.NodeId} 中的錯誤：{errorEvent.ErrorType}");
        Console.WriteLine($"恢復操作：{errorEvent.RecoveryAction}");
    }
});

// 開始執行並附加事件流進行即時檢查。
await executor.ExecuteAsync(arguments, eventStream);
```

## 最佳實踐

### 錯誤分類

* **使用特定的錯誤類型**而不是通用的 `Unknown`
* **適當標記瞬間錯誤**以支持重試邏輯
* **設定適當的嚴重程度級別**用於升級決策

### 重試配置

* **大多數場景以指數退避開始**
* **新增抖動**以防止雷鳴羊群問題
* **限制重試嘗試**以防止無限迴圈
* **使用錯誤類型篩選**以避免重試永久故障

### 斷路器調整

* **根據預期故障率設定適當的故障閾值**
* **配置允許恢復的逾時**
* **監控斷路器狀態變更**以獲得操作洞察
* **當電路開啟時使用備用操作**

### 資源管理

* **根據系統容量設定實際的資源限制**
* **為關鍵操作使用執行優先級**
* **監控資源耗盡事件**用於容量規劃
* **當預算超出時實現優雅降級**

### 指標和監控

* **在生產環境中收集錯誤指標**
* **為高錯誤率或斷路器開啟設定警告**
* **分析錯誤模式**以進行系統改進
* **追蹤恢復成功率**以驗證錯誤處理

## 故障排除

### 常見問題

**重試迴圈不起作用**: 檢查錯誤類型是否標記為可重試且 `MaxRetries` 大於 0。

**斷路器不開啟**: 驗證 `FailureThreshold` 是否適當且 `TriggerErrorTypes` 包含相關的錯誤類型。

**資源預算耗盡**: 檢查 `BasePermitsPerSecond` 和 `MaxBurstSize` 設定，並監控系統資源使用。

**未收集錯誤指標**: 確保 `ErrorMetricsCollector` 已正確配置並與 Graph 執行器整合。

### 除錯錯誤處理

啟用除錯日誌以追蹤錯誤處理決策：

```csharp
// 配置詳細的 Graph 日誌以追蹤錯誤處理決策。
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableErrorHandlingLogging = true
};

// 建立在 Graph 元件中使用的日誌記錄器適配器。
var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);
```

### 效能考量

* **錯誤處理新增開銷** - 在效能關鍵路徑中謹慎使用
* **指標收集**可能會在高錯誤率下影響效能
* **斷路器狀態變更**被記錄並可能產生雜訊
* **資源預算檢查**為 Node 執行新增延遲

## 參閱

* [資源治理和並行](resource-governance-and-concurrency.md) - 管理資源限制和優先級
* [指標和可觀測性](metrics-logging-quickstart.md) - 全面的監控和遙測
* [串流執行](streaming-quickstart.md) - 實時錯誤事件串流
* [狀態管理](state-quickstart.md) - 錯誤狀態持久化和恢復
* [Graph 執行](execution.md) - 理解執行生命週期
