# 錯誤處理和復原力

SemanticKernel.Graph 中的錯誤處理和復原力提供了強大的機制來處理故障、實施重試策略，並通過斷路器和資源預算防止級聯故障。本指南涵蓋了全面的錯誤處理系統，包括策略、指標收集和遙測。

## 您將學到什麼

* 如何配置具有指數退避和抖動的重試策略
* 實施斷路器模式以防止級聯故障
* 管理資源預算並防止資源耗盡
* 通過註冊表配置錯誤處理策略
* 為複雜場景使用專用的錯誤處理節點
* 收集和分析錯誤指標和遙測
* 在流式執行中處理故障和取消事件

## 概念和技術

**ErrorPolicyRegistry**：用於管理圖中的錯誤處理策略的中央註冊表，支持重試、斷路器和預算策略。

**RetryPolicyGraphNode**：用自動重試功能包裝其他節點，支持可配置的退避策略和錯誤類型篩選。

**ErrorHandlerGraphNode**：用於錯誤分類、恢復操作和基於錯誤類型進行條件路由的專用節點。

**NodeCircuitBreakerManager**：按節點管理斷路器狀態，集成資源治理和錯誤指標。

**ResourceGovernor**：提供自適應速率限制和資源預算管理，防止資源耗盡。

**ErrorMetricsCollector**：收集、聚合和分析錯誤指標，用於趨勢分析和異常檢測。

**ErrorHandlingTypes**：包含 13 種錯誤類型和 8 種恢復操作的全面錯誤分類系統。

## 先決條件

* 已完成[第一個圖表教程](../first-graph-5-minutes.md)
* 對圖表執行概念的基本理解
* 熟悉復原力模式（重試、斷路器）
* 對資源管理原則的理解

## 錯誤類型和恢復操作

### 錯誤分類

SemanticKernel.Graph 將錯誤分為 13 種不同的類型，以便進行精確的處理：

```csharp
// GraphErrorType：錯誤處理組件使用的錯誤分類。
public enum GraphErrorType
{
    Unknown = 0,           // 未指定的錯誤類型
    Validation = 1,        // 輸入或模式驗證錯誤
    NodeExecution = 2,     // 節點執行期間拋出的錯誤
    Timeout = 3,           // 執行超時
    Network = 4,           // 網路相關問題（通常可重試）
    ServiceUnavailable = 5,// 外部服務不可用
    RateLimit = 6,         // 超級服務的速率限制
    Authentication = 7,    // 身份驗證/授權故障
    ResourceExhaustion = 8,// 記憶體/磁碟或配額耗盡
    GraphStructure = 9,    // 圖形遍歷或配置問題
    Cancellation = 10,     // 透過令牌取消操作
    CircuitBreakerOpen = 11,// 斷路器當前打開
    BudgetExhausted = 12   // 資源或預算限制達到
}
```

### 恢復操作

有八種恢復策略可用於不同的錯誤場景：

```csharp
// ErrorRecoveryAction：發生錯誤時的建議恢復策略。
public enum ErrorRecoveryAction
{
    Retry = 0,           // 使用配置的策略重試失敗的操作
    Skip = 1,            // 跳過故障節點並繼續
    Fallback = 2,        // 執行後備邏輯或替代節點
    Rollback = 3,        // 回滾到目前為止執行的狀態更改
    Halt = 4,            // 停止整個執行
    Escalate = 5,        // 上報給人工操作員或警報系統
    CircuitBreaker = 6,  // 觸發斷路器行為
    Continue = 7         // 儘管出錯但繼續（盡力而為）
}
```

## 重試策略和退避策略

### 基本重試配置

使用指數退避和抖動配置重試策略：

```csharp
using SemanticKernel.Graph.Core;

// 使用指數退避和抖動配置健全的重試策略。
var retryConfig = new RetryPolicyConfig
{
    MaxRetries = 3,
    BaseDelay = TimeSpan.FromSeconds(1),
    MaxDelay = TimeSpan.FromMinutes(1),
    Strategy = RetryStrategy.ExponentialBackoff,
    BackoffMultiplier = 2.0,
    UseJitter = true,
    // 僅對通常是暫時性的錯誤類型嘗試重試。
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
// RetryStrategy 控制如何在嘗試之間計算重試延遲。
public enum RetryStrategy
{
    NoRetry = 0,              // 不執行重試
    FixedDelay = 1,           // 嘗試之間的恆定延遲
    LinearBackoff = 2,        // 延遲按嘗試線性增加
    ExponentialBackoff = 3,   // 延遲呈指數增長（推薦）
    Custom = 4                // 使用者提供的自訂退避計算
}
```

### 使用 RetryPolicyGraphNode

用自動重試功能包裝任何節點：

```csharp
using SemanticKernel.Graph.Nodes;

// 範例：建立一個簡單函式節點並使用重試行為進行包裝。
// 'kernelFunction' 代表現有的 KernelFunction 執行個體。
var functionNode = new FunctionGraphNode("api-call", kernelFunction);

// 使用配置的重試策略進行包裝，使呼叫具有復原力。
var retryNode = new RetryPolicyGraphNode(functionNode, retryConfig);

// 將重試節點新增到圖中，並從開始節點連接它。
graph.AddNode(retryNode);
graph.AddEdge(startNode, retryNode);
```

重試節點自動執行：
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
    FailureThreshold = 5,               // 打開斷路器的故障數
    OpenTimeout = TimeSpan.FromSeconds(30), // 在移動到半開前等待的時間
    HalfOpenRetryCount = 3,             // 半開狀態下的探針嘗試次數
    FailureWindow = TimeSpan.FromMinutes(1), // 故障計數窗口
    TriggerOnBudgetExhaustion = true    // 在資源預算耗盡時打開
};
```

### 斷路器狀態

斷路器在三種狀態下運作：

1. **Closed**：正常操作，故障被計數
2. **Open**：斷路器打開，操作被阻止
3. **Half-Open**：允許有限的操作以測試復原

### 使用 NodeCircuitBreakerManager

在節點級別管理斷路器：

```csharp
using SemanticKernel.Graph.Core;

// 建立一個負責按節點斷路器狀態的管理器。
var circuitBreakerManager = new NodeCircuitBreakerManager(
    graphLogger,
    errorMetricsCollector,
    eventStream,
    resourceGovernor,
    performanceMetrics);

// 將斷路器策略應用於特定節點 ID。
circuitBreakerManager.ConfigureNode("api-node", circuitBreakerConfig);

// 透過斷路器管理器執行受保護的操作。提供
// 一個可選的後備，當斷路器打開或操作失敗時執行。
var result = await circuitBreakerManager.ExecuteAsync<string>(
    "api-node",
    executionId,
    async () => await apiCall(),
    async () => await fallbackCall()); // 可選的後備
```

## 資源預算管理

### 資源治理配置

配置資源限制和自適應速率限制：

```csharp
// 配置資源治理以控制並發和資源使用。
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 50.0,      // 每秒的基本執行速率
    MaxBurstSize = 100,               // 允許的突發容量
    CpuHighWatermarkPercent = 85.0,   // CPU 使用率閾值，用於強反壓力
    CpuSoftLimitPercent = 70.0,       // 軟 CPU 閾值，在節流前
    MinAvailableMemoryMB = 512.0,     // 分配的最小可用記憶體
    DefaultPriority = ExecutionPriority.Normal
};

// 建立強制執行配置的資源限制的治理者。
var resourceGovernor = new ResourceGovernor(resourceOptions);
```

### 執行優先級

四個優先級別影響資源分配：

```csharp
// ExecutionPriority 影響資源治理者如何分配許可證。
public enum ExecutionPriority
{
    Low = 0,      // 低優先級（相對成本更高）
    Normal = 1,   // 預設優先級
    High = 2,     // 對延遲敏感的工作的高優先級
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

// 租約在 'lease' 被處置時自動釋放（using 區塊結束）。
```

## 錯誤策略註冊表

### 集中式策略管理

`ErrorPolicyRegistry` 提供集中式的錯誤處理策略：

```csharp
// 建立一個中央註冊表來保存由註冊表支援的策略使用的錯誤處理規則。
var registry = new ErrorPolicyRegistry(new ErrorPolicyRegistryOptions());

// 為網路錯誤註冊重試規則。註冊表將由
// 執行期間的錯誤處理策略查閱以確定恢復操作。
registry.RegisterPolicyRule(new PolicyRule
{
    ContextId = "Examples",
    ErrorType = GraphErrorType.Network,
    RecoveryAction = ErrorRecoveryAction.Retry,
    MaxRetries = 3,
    RetryDelay = TimeSpan.FromSeconds(1),
    BackoffMultiplier = 2.0,
    Priority = 100,
    Description = "Retry network errors"
});

// 為 'api-node' 註冊節點級斷路器配置。
registry.RegisterNodeCircuitBreakerPolicy("api-node", circuitBreakerConfig);
```

### 策略解析

基於錯誤上下文和節點資訊解析策略：

```csharp
// 構造代表捕獲的例外的錯誤處理上下文。
var errorContext = new ErrorHandlingContext
{
    Exception = exception,
    ErrorType = GraphErrorType.Network,
    Severity = ErrorSeverity.Medium,
    AttemptNumber = 1,
    IsTransient = true
};

// 為此錯誤和執行上下文解析適當的策略。
var policy = registry.ResolvePolicy(errorContext, executionContext);
if (policy?.RecoveryAction == ErrorRecoveryAction.Retry)
{
    // 解析的策略表示應該重試此錯誤。
    // 重試編排應該尊重 policy.MaxRetries 和計時值。
}
```

## 錯誤處理節點

### ErrorHandlerGraphNode

用於複雜錯誤處理場景的專用節點：

```csharp
// 建立一個檢查錯誤並相應路由執行的專用節點。
var errorHandler = new ErrorHandlerGraphNode(
    "error-handler",
    "ErrorHandler",
    "Handles errors and routes execution");

// 將特定錯誤類型對映到恢復操作。
errorHandler.ConfigureErrorHandler(GraphErrorType.Network, ErrorRecoveryAction.Retry);
errorHandler.ConfigureErrorHandler(GraphErrorType.Authentication, ErrorRecoveryAction.Escalate);
errorHandler.ConfigureErrorHandler(GraphErrorType.BudgetExhausted, ErrorRecoveryAction.CircuitBreaker);

// 定義在選擇特定恢復操作時執行的後備節點。
errorHandler.AddFallbackNode(GraphErrorType.Network, fallbackNode);
errorHandler.AddFallbackNode(GraphErrorType.Authentication, escalationNode);

// 將錯誤處理器新增到圖中，並根據錯誤標誌進行條件路由。
graph.AddNode(errorHandler);
graph.AddConditionalEdge(startNode, errorHandler,
    edge => edge.Condition = "HasError");
```

### 條件錯誤路由

基於錯誤類型和恢復操作路由執行：

```csharp
// 基於解析的條件從錯誤處理器進行條件路由的範例。
// 針對網路錯誤路由到重試節點。
graph.AddConditionalEdge(errorHandler, retryNode,
    edge => edge.Condition = "ErrorType == 'Network'");

// 當恢復操作表示應執行後備時，路由到後備節點。
graph.AddConditionalEdge(errorHandler, fallbackNode,
    edge => edge.Condition = "RecoveryAction == 'Fallback'");

// 針對高嚴重性問題路由到上報流程。
graph.AddConditionalEdge(errorHandler, escalationNode,
    edge => edge.Condition = "ErrorSeverity >= 'High'");
```

## 錯誤指標和遙測

### 錯誤指標收集

收集全面的錯誤指標進行分析：

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

// 記錄一個範例錯誤事件以驗證指標配管。
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
// ErrorEvent：描述單個捕獲的錯誤出現的不可變類 DTO。
public sealed class ErrorEvent
{
    public string EventId { get; set; }           // 事件的唯一識別碼
    public string ExecutionId { get; set; }       // 執行上下文 ID
    public string NodeId { get; set; }            // 錯誤發生的節點
    public GraphErrorType ErrorType { get; set; } // 分類的錯誤類型
    public ErrorSeverity Severity { get; set; }   // 警報/上報的嚴重程度
    public bool IsTransient { get; set; }         // 表示錯誤是否為暫時性
    public int AttemptNumber { get; set; }        // 錯誤發生時的嘗試次數
    public DateTimeOffset Timestamp { get; set; } // 記錄錯誤的時間
    public string ExceptionType { get; set; }     // CLR 例外類型名稱
    public string ErrorMessage { get; set; }      // 例外訊息或錯誤說明
    public ErrorRecoveryAction? RecoveryAction { get; set; } // 建議的恢復操作
    public bool? RecoverySuccess { get; set; }    // 恢復是否成功
    public TimeSpan Duration { get; set; }        // 故障操作的持續時間
}
```

### 指標查詢

查詢錯誤指標進行分析和監控：

```csharp
// 查詢並顯示來自收集器的執行特定指標。
var executionMetrics = errorMetricsCollector.GetExecutionMetrics(executionId);
if (executionMetrics != null)
{
    Console.WriteLine($"Total Errors: {executionMetrics.TotalErrors}");
    Console.WriteLine($"Recovery Success Rate: {executionMetrics.RecoverySuccessRate:F1}%");
    Console.WriteLine($"Most Common Error: {executionMetrics.MostCommonErrorType}");
}

// 查詢節點特定的指標以進行目標故障排除。
var nodeMetrics = errorMetricsCollector.GetNodeMetrics(nodeId);
if (nodeMetrics != null)
{
    Console.WriteLine($"Node Error Rate: {nodeMetrics.ErrorRate:F2} errors/min");
    Console.WriteLine($"Recovery Success Rate: {nodeMetrics.RecoverySuccessRate:F1}%");
}

// 讀取收集器公開的整體聚合統計資訊。
var overallStats = errorMetricsCollector.OverallStatistics;
Console.WriteLine($"Current Error Rate: {overallStats.CurrentErrorRate:F2} errors/min");
Console.WriteLine($"Total Errors Recorded: {overallStats.TotalErrorsRecorded}");
```

## 與圖形執行的整合

### 錯誤處理中介軟體

將錯誤處理與圖形執行整合：

```csharp
// 使用註冊表支援的錯誤處理策略來集中決策。
var errorHandlingPolicy = new RegistryBackedErrorHandlingPolicy(errorPolicyRegistry);

// 建立配置了錯誤處理和資源治理的圖形執行器。
var executor = new GraphExecutor("ResilientGraph", "Graph with error handling")
    .ConfigureErrorHandling(errorHandlingPolicy)
    .ConfigureResources(resourceOptions);

// 將錯誤指標收集器附加到執行器進行遙測。
executor.ConfigureMetrics(new GraphMetricsOptions
{
    EnableErrorMetrics = true,
    ErrorMetricsCollector = errorMetricsCollector
});
```

### 流式錯誤事件

錯誤事件會發出到執行流：

```csharp
// 建立流式執行器並訂閱執行時事件，包括錯誤事件。
using var eventStream = executor.CreateStreamingExecutor()
    .CreateEventStream();

// 訂閱執行事件並處理節點錯誤事件以便進行可觀測性。
eventStream.SubscribeToEvents<GraphExecutionEvent>(evt =>
{
    if (evt.EventType == GraphExecutionEventType.NodeError)
    {
        var errorEvent = evt as NodeErrorEvent;
        Console.WriteLine($"Error in {errorEvent.NodeId}: {errorEvent.ErrorType}");
        Console.WriteLine($"Recovery Action: {errorEvent.RecoveryAction}");
    }
});

// 使用附加的事件流開始執行以進行即時檢查。
await executor.ExecuteAsync(arguments, eventStream);
```

## 最佳實踐

### 錯誤分類

* **使用特定的錯誤類型**而不是通用的 `Unknown`
* **適當標記暫時性錯誤**以進行重試邏輯
* **為上報決策設置適當的嚴重性級別**

### 重試配置

* **對大多數情況開始使用指數退避**
* **新增抖動**以防止雷鳴羊群問題
* **限制重試次數**以防止無限迴圈
* **使用錯誤類型篩選**以避免重試永久性故障

### 斷路器調整

* **根據預期的故障速率設置適當的故障閾值**
* **配置允許復原的超時**
* **監控斷路器狀態變化**以獲得運作洞察
* **在斷路器打開時使用後備操作**

### 資源管理

* **根據系統容量設置實際的資源限制**
* **對關鍵操作使用執行優先級**
* **監控資源耗盡事件**以進行容量規劃
* **在超過預算時實施優雅降級**

### 指標和監控

* **在生產環境中收集錯誤指標**
* **設置高錯誤率或斷路器開啟的警報**
* **分析錯誤模式**以改進系統
* **追蹤恢復成功率**以驗證錯誤處理

## 疑難排解

### 常見問題

**重試迴圈不起作用**：檢查是否將錯誤類型標記為可重試，並且 `MaxRetries` 大於 0。

**斷路器未打開**：驗證 `FailureThreshold` 是否合適，並且 `TriggerErrorTypes` 包含相關的錯誤類型。

**資源預算耗盡**：檢查 `BasePermitsPerSecond` 和 `MaxBurstSize` 設置，並監控系統資源使用。

**未收集錯誤指標**：確保 `ErrorMetricsCollector` 已正確配置並與圖形執行器整合。

### 調試錯誤處理

啟用調試日誌來追蹤錯誤處理決策：

```csharp
// 配置詳細的圖形日誌以追蹤錯誤處理決策。
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableErrorHandlingLogging = true
};

// 建立在圖形元件中使用的記錄器配接器。
var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);
```

### 效能考量

* **錯誤處理增加了開銷** - 在效能關鍵的路徑中謹慎使用
* **指標收集**在高錯誤率下可能會影響效能
* **斷路器狀態變化**會被記錄，可能產生噪聲
* **資源預算檢查**增加了節點執行的延遲

## 另請參閱

* [資源治理和並發](resource-governance-and-concurrency.md) - 管理資源限制和優先級
* [指標和可觀測性](metrics-logging-quickstart.md) - 全面的監控和遙測
* [流式執行](streaming-quickstart.md) - 即時錯誤事件流
* [狀態管理](state-quickstart.md) - 錯誤狀態的持久化和復原
* [圖形執行](execution.md) - 理解執行生命週期
