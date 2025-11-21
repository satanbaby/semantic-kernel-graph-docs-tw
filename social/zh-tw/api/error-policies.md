# 錯誤政策

本文件涵蓋了 SemanticKernel.Graph 中的全面錯誤處理系統，包括策略管理、重試機制、錯誤處理節點和指標收集。該系統提供了具有可配置策略、自動重試邏輯和全面錯誤追蹤的強大彈性模式。

## ErrorPolicyRegistry

`ErrorPolicyRegistry` 在 Graph 執行系統中提供集中的錯誤處理策略，支援重試、斷路器和預算策略，並具有執行時期策略解決方案。

### 概觀

該註冊表管理具有版本控制、執行時期解決和與 Graph 執行上下文集成的錯誤處理策略。它支援基於錯誤類型、Node 類型和自定義條件的策略規則。

### 主要特性

* **集中式策略管理**：所有錯誤處理策略的唯一數據來源
* **執行時期策略解決**：根據錯誤上下文和執行狀態動態選擇策略
* **策略版本控制**：支援策略更新和回滾
* **斷路器集成**：每個 Node 的內建斷路器策略
* **預算管理**：具有自動實施的資源預算策略
* **執行緒安全**：所有操作都是執行緒安全的，可用於並發訪問

### 策略註冊

```csharp
var registry = new ErrorPolicyRegistry(new ErrorPolicyRegistryOptions());

// 使用 PolicyRule 為特定錯誤類型註冊重試策略
// (使用 RegisterPolicyRule 以便正確索引和版本控制規則)
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

// 使用正確的配置屬性為 Node 註冊斷路器策略
registry.RegisterNodeCircuitBreakerPolicy("api-node", new CircuitBreakerPolicyConfig
{
    Enabled = true,
    FailureThreshold = 5,
    OpenTimeout = TimeSpan.FromMinutes(1),
    FailureWindow = TimeSpan.FromMinutes(5)
});
```

### 可運行範例

存儲庫包含一個已測試的可運行範例，其中包含本文件中的程式碼片段：

- 範例來源：`semantic-kernel-graph-docs/examples/ErrorPoliciesExample.cs`
- 從儲存庫根目錄執行範例（需要 .NET 8）：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- error-policies
```

此範例註冊樣本策略，使用模擬的 `HttpRequestException` 執行 `ErrorHandlerGraphNode`，並在 `ErrorMetricsCollector` 中記錄樣本事件，以便您可以檢查執行時期輸出並驗證記錄的行為。

### 策略解決

策略根據錯誤上下文和 Node 信息進行解決：

```csharp
var errorContext = new ErrorHandlingContext
{
    Exception = exception,
    ErrorType = GraphErrorType.Network,
    Severity = ErrorSeverity.Medium,
    AttemptNumber = 1,
    IsTransient = true
};

var policy = registry.ResolvePolicy(errorContext, executionContext);
if (policy?.RecoveryAction == ErrorRecoveryAction.Retry)
{
    // 使用配置的參數應用重試邏輯
    var delay = CalculateRetryDelay(policy, errorContext.AttemptNumber);
    await Task.Delay(delay);
}
```

### 策略規則配置

```csharp
public class PolicyRule
{
    public ErrorRecoveryAction RecoveryAction { get; set; }
    public int MaxRetries { get; set; }
    public TimeSpan RetryDelay { get; set; }
    public double BackoffMultiplier { get; set; }
    public TimeSpan MaxRetryDelay { get; set; }
    public int Priority { get; set; }
    public string? NodeTypePattern { get; set; }
    public ErrorSeverity? SeverityThreshold { get; set; }
    public Func<ErrorHandlingContext, GraphExecutionContext?, bool>? CustomCondition { get; set; }
}
```

## RetryPolicyGraphNode

`RetryPolicyGraphNode` 使用自動重試功能包裝另一個 Node，通過可配置的重試策略和退避策略處理短暫故障。

### 概觀

此特殊 Node 為包裝 Node 提供自動重試邏輯，支援多個重試策略、錯誤類型篩選和全面的重試統計。它通過自動處理短暫故障來增強 Graph 彈性。

### 主要特性

* **自動重試邏輯**：可配置的重試嘗試，具有智能退避
* **多個重試策略**：固定延遲、指數退避、線性退避和自定義策略
* **錯誤類型篩選**：僅重試特定錯誤類型或使用自定義重試條件
* **抖動支援**：隨機抖動以防止雷鳴羊群問題
* **重試統計**：全面追蹤重試嘗試和性能
* **元資料擴充**：將重試上下文添加到 Kernel 參數和結果

### 配置

```csharp
var retryConfig = new RetryPolicyConfig
{
    MaxRetries = 3,
    BaseDelay = TimeSpan.FromSeconds(1),
    MaxDelay = TimeSpan.FromSeconds(30),
    Strategy = RetryStrategy.ExponentialBackoff,
    BackoffMultiplier = 2.0,
    UseJitter = true,
    RetryableErrorTypes = new HashSet<GraphErrorType>
    {
        GraphErrorType.Network,
        GraphErrorType.ServiceUnavailable,
        GraphErrorType.Timeout
    }
};

var retryNode = new RetryPolicyGraphNode(wrappedNode, retryConfig);
```

### 重試策略

```csharp
public enum RetryStrategy
{
    None = 0,                    // 無重試嘗試
    FixedDelay = 1,             // 嘗試之間的固定延遲
    ExponentialBackoff = 2,     // 延遲的指數增加
    LinearBackoff = 3,          // 延遲的線性增加
    RandomJitter = 4,           // 添加到延遲的隨機抖動
    Custom = 5                   // 自定義重試邏輯
}
```

### 使用範例

#### 基本重試包裝器

```csharp
// 使用重試策略包裝函數 Node
var functionNode = new FunctionGraphNode(kernelFunction, "api-call");
var retryNode = new RetryPolicyGraphNode(functionNode, new RetryPolicyConfig
{
    MaxRetries = 3,
    BaseDelay = TimeSpan.FromSeconds(1),
    Strategy = RetryStrategy.ExponentialBackoff
});

// 在 Graph 中連接重試 Node
graph.AddNode(retryNode);
graph.AddEdge(previousNode, retryNode);
```

#### 自定義重試條件

```csharp
var retryNode = new RetryPolicyGraphNode(wrappedNode, new RetryPolicyConfig
{
    MaxRetries = 5,
    BaseDelay = TimeSpan.FromSeconds(2),
    CustomRetryCondition = (exception, attemptNumber) =>
    {
        // 僅在特定例外上重試
        if (exception is HttpRequestException httpEx)
        {
            return httpEx.StatusCode == System.Net.HttpStatusCode.TooManyRequests ||
                   httpEx.StatusCode == System.Net.HttpStatusCode.ServiceUnavailable;
        }
        return false;
    }
});
```

#### 重試結果路由

```csharp
// 添加僅在重試嘗試後執行的 Edge
retryNode.AddEdgeForRetryOutcome(
    targetNode: fallbackNode,
    onlyOnRetrySuccess: false,
    minRetryAttempts: 2
);

// 添加成功重試情況的 Edge
retryNode.AddEdgeForRetryOutcome(
    targetNode: successNode,
    onlyOnRetrySuccess: true,
    minRetryAttempts: 1
);
```

### 重試統計

該 Node 提供全面的重試統計：

```csharp
var statistics = retryNode.RetryStatistics;
Console.WriteLine($"Total retry attempts: {statistics.TotalRetryAttempts}");
Console.WriteLine($"Successful retries: {statistics.SuccessfulRetries}");
Console.WriteLine($"Average retry delay: {statistics.AverageRetryDelay}");
Console.WriteLine($"Last retry error: {statistics.LastRetryError?.Message}");
```

## ErrorHandlerGraphNode

`ErrorHandlerGraphNode` 是一個專門用於處理 Graph 執行期間錯誤的 Node，提供錯誤分類、恢復操作和基於錯誤類型的條件路由。

### 概觀

此 Node 實現了具有自動錯誤分類、可配置恢復操作和智能路由決策的複雜錯誤處理邏輯。它在複雜工作流中充當中央錯誤處理中心。

### 主要特性

* **自動錯誤分類**：將例外映射到 `GraphErrorType` 列舉值
* **可配置恢復操作**：重試、跳過、回退、回滾、停止、升級、繼續
* **條件路由**：根據錯誤處理結果動態選擇 Edge
* **回退 Node 支援**：不同錯誤情況的替代執行路徑
* **全面遙測**：詳細的錯誤追蹤和恢復指標
* **預設錯誤處理器**：針對常見錯誤類型的預先配置處理策略

### 錯誤分類

該 Node 會自動將例外分類為錯誤類型：

```csharp
// 基於例外類型的自動分類
ArgumentException → GraphErrorType.Validation
TimeoutException → GraphErrorType.Timeout
OperationCanceledException → GraphErrorType.Cancellation
HttpRequestException → GraphErrorType.Network
UnauthorizedAccessException → GraphErrorType.Authentication
OutOfMemoryException → GraphErrorType.ResourceExhaustion
```

### 預設錯誤處理器

```csharp
// 短暫性錯誤 - 自動重試
_errorHandlers[GraphErrorType.Network] = ErrorRecoveryAction.Retry;
_errorHandlers[GraphErrorType.ServiceUnavailable] = ErrorRecoveryAction.Retry;
_errorHandlers[GraphErrorType.Timeout] = ErrorRecoveryAction.Retry;
_errorHandlers[GraphErrorType.RateLimit] = ErrorRecoveryAction.Retry;

// 身份驗證錯誤 - 停止執行
_errorHandlers[GraphErrorType.Authentication] = ErrorRecoveryAction.Halt;

// 驗證錯誤 - 跳到下一個 Node
_errorHandlers[GraphErrorType.Validation] = ErrorRecoveryAction.Skip;

// 關鍵系統錯誤 - 停止執行
_errorHandlers[GraphErrorType.ResourceExhaustion] = ErrorRecoveryAction.Halt;
_errorHandlers[GraphErrorType.GraphStructure] = ErrorRecoveryAction.Halt;
```

### 使用範例

#### 基本錯誤處理器

```csharp
var errorHandler = new ErrorHandlerGraphNode(
    nodeId: "error-handler-1",
    name: "MainErrorHandler",
    description: "Handles errors in the main workflow",
    logger: graphLogger
);

// 添加到 Graph
graph.AddNode(errorHandler);
graph.AddEdge(failingNode, errorHandler);
```

#### 自定義錯誤處理

```csharp
var errorHandler = new ErrorHandlerGraphNode("custom-error", "CustomErrorHandler");

// 為特定錯誤類型配置自定義錯誤處理
errorHandler.ConfigureErrorHandler(GraphErrorType.Network, ErrorRecoveryAction.Retry);
errorHandler.ConfigureErrorHandler(GraphErrorType.Authentication, ErrorRecoveryAction.Escalate);

// 為特定錯誤類型設定回退 Node
errorHandler.SetFallbackNode(GraphErrorType.ServiceUnavailable, alternativeServiceNode);
errorHandler.SetFallbackNode(GraphErrorType.Validation, validationHelperNode);
```

#### 基於錯誤結果的條件路由

```csharp
// 根據恢復操作路由到不同 Node
errorHandler.AddEdgeForRecoveryAction(
    targetNode: retryNode,
    recoveryAction: ErrorRecoveryAction.Retry
);

errorHandler.AddEdgeForRecoveryAction(
    targetNode: fallbackNode,
    recoveryAction: ErrorRecoveryAction.Fallback
);

errorHandler.AddEdgeForRecoveryAction(
    targetNode: escalationNode,
    recoveryAction: ErrorRecoveryAction.Escalate
);
```

### 錯誤上下文和恢復

該 Node 從 Kernel 參數中處理錯誤上下文：

```csharp
// 錯誤處理器所期望的輸入參數
public IReadOnlyList<string> InputParameters { get; } = new[]
{
    "LastError",           // 發生的例外
    "ErrorContext",        // 其他錯誤上下文
    "ErrorType",           // 分類的錯誤類型
    "ErrorSeverity",       // 錯誤嚴重等級
    "AttemptCount"         // 當前嘗試編號
}.AsReadOnly();

// 錯誤處理器提供的輸出參數
public IReadOnlyList<string> OutputParameters { get; } = new[]
{
    "ErrorHandled",        // 錯誤是否已處理
    "RecoveryAction",      // 為恢復採取的操作
    "ShouldRetry",         // 是否建議重試
    "RetryDelay",          // 建議的重試延遲
    "FallbackExecuted",    // 是否使用了回退
    "EscalationRequired"   // 是否需要升級
}.AsReadOnly();
```

## ErrorMetricsCollector

`ErrorMetricsCollector` 在 Graph 執行中收集、聚集和分析錯誤指標，提供趨勢分析、性能洞察和異常檢測。

### 概觀

此元件提供全面的錯誤追蹤，具有即時指標、歷史分析和性能洞察。它與錯誤處理系統集成，為系統可靠性提供可行的智能。

### 主要特性

* **即時指標收集**：立即錯誤事件處理和聚集
* **多維分析**：按執行、Node、錯誤類型和時間的指標
* **性能洞察**：錯誤率、恢復成功率和趨勢分析
* **異常檢測**：自動識別異常錯誤模式
* **可配置保留**：可調整的數據保留和清理策略
* **整合就緒**：易於與監控和警報系統集成

### 指標結構

```csharp
// 執行級別指標
public class ExecutionErrorMetrics
{
    public string ExecutionId { get; set; }
    public int TotalErrors { get; set; }
    public List<GraphErrorType> ErrorTypes { get; set; }
    public double RecoverySuccessRate { get; set; }
    public double AverageErrorSeverity { get; set; }
    public DateTimeOffset FirstError { get; set; }
    public DateTimeOffset LastError { get; set; }
    public double ErrorRate { get; set; }
    public GraphErrorType MostCommonErrorType { get; set; }
}

// Node 級別指標
public class NodeErrorMetrics
{
    public string NodeId { get; set; }
    public int TotalErrors { get; set; }
    public double ErrorRate { get; set; }
    public double AverageErrorSeverity { get; set; }
    public double RecoverySuccessRate { get; set; }
    public DateTimeOffset LastErrorTime { get; set; }
    public GraphErrorType MostCommonErrorType { get; set; }
    public List<GraphErrorType> ErrorTypes { get; set; }
    public int RecoveryAttempts { get; set; }
    public int SuccessfulRecoveries { get; set; }
}
```

### 使用範例

#### 基本指標收集

```csharp
var metricsCollector = new ErrorMetricsCollector(new ErrorMetricsOptions
{
    AggregationInterval = TimeSpan.FromMinutes(1),
    MaxEventQueueSize = 10000,
    EnableMetricsCleanup = true,
    MetricsRetentionPeriod = TimeSpan.FromDays(7)
});

// 記錄錯誤事件
metricsCollector.RecordError(
    executionId: "exec-123",
    nodeId: "api-node",
    errorContext: errorContext,
    recoveryAction: ErrorRecoveryAction.Retry,
    recoverySuccess: true
);
```

#### 指標查詢

```csharp
// 取得特定執行的指標
var executionMetrics = metricsCollector.GetExecutionMetrics("exec-123");
if (executionMetrics != null)
{
    Console.WriteLine($"Total errors: {executionMetrics.TotalErrors}");
    Console.WriteLine($"Recovery success rate: {executionMetrics.RecoverySuccessRate:F2}%");
    Console.WriteLine($"Most common error: {executionMetrics.MostCommonErrorType}");
}

// 取得 Node 特定的指標
var nodeMetrics = metricsCollector.GetNodeMetrics("api-node");
if (nodeMetrics != null)
{
    Console.WriteLine($"Node error rate: {nodeMetrics.ErrorRate:F2} errors/min");
    Console.WriteLine($"Recovery success rate: {nodeMetrics.RecoverySuccessRate:F2}%");
}

// 取得整體統計
var overallStats = metricsCollector.OverallStatistics;
Console.WriteLine($"Total errors recorded: {overallStats.TotalErrors}");
Console.WriteLine($"Current error rate: {overallStats.CurrentErrorRate:F2} errors/min");
Console.WriteLine($"Overall recovery success rate: {overallStats.RecoverySuccessRate:F2}%");
```

#### 批次處理

```csharp
// 一次記錄多個錯誤事件
var errorEvents = new List<ErrorEvent>
{
    new ErrorEvent
    {
        ExecutionId = "exec-123",
        NodeId = "node-1",
        ErrorType = GraphErrorType.Network,
        Severity = ErrorSeverity.Medium,
        IsTransient = true,
        Timestamp = DateTimeOffset.UtcNow
    },
    new ErrorEvent
    {
        ExecutionId = "exec-123",
        NodeId = "node-2",
        ErrorType = GraphErrorType.Timeout,
        Severity = ErrorSeverity.High,
        IsTransient = true,
        Timestamp = DateTimeOffset.UtcNow
    }
};

metricsCollector.RecordErrorBatch(errorEvents);
```

### 配置選項

```csharp
public class ErrorMetricsOptions
{
    public TimeSpan AggregationInterval { get; set; } = TimeSpan.FromMinutes(1);
    public int MaxEventQueueSize { get; set; } = 10000;
    public bool EnableMetricsCleanup { get; set; } = true;
    public TimeSpan MetricsRetentionPeriod { get; set; } = TimeSpan.FromDays(7);
}
```

### 與錯誤處理集成

指標收集器與錯誤處理系統無縫集成：

```csharp
// 在 ErrorHandlerGraphNode 中
public async Task<FunctionResult> ExecuteAsync(Kernel kernel, KernelArguments arguments, CancellationToken cancellationToken = default)
{
    try
    {
        // ... 錯誤處理邏輯 ...
        
        // 記錄成功錯誤處理的指標
        _metricsCollector?.RecordError(
            executionId: arguments.GetExecutionId(),
            nodeId: NodeId,
            errorContext: errorContext,
            recoveryAction: recoveryAction,
            recoverySuccess: true
        );
        
        return result;
    }
    catch (Exception ex)
    {
        // 記錄失敗錯誤處理的指標
        _metricsCollector?.RecordError(
            executionId: arguments.GetExecutionId(),
            nodeId: NodeId,
            errorContext: new ErrorHandlingContext { Exception = ex },
            recoveryAction: null,
            recoverySuccess: false
        );
        
        throw;
    }
}
```

## 錯誤類型和恢復操作

### GraphErrorType 列舉

```csharp
public enum GraphErrorType
{
    Unknown = 0,           // 未知或未指定的錯誤類型
    Validation = 1,        // 執行前或執行期間的驗證錯誤
    NodeExecution = 2,     // Node 執行因內部邏輯錯誤而失敗
    Timeout = 3,           // Node 或 Graph 執行期間發生逾時
    Network = 4,           // 網路相關錯誤（短暫性、可重試）
    ServiceUnavailable = 5, // 外部服務不可用（可能是短暫性）
    RateLimit = 6,         // 超過速率限制（可能是短暫性）
    Authentication = 7,     // 身份驗證或授權失敗
    ResourceExhaustion = 8, // 資源耗盡（記憶體、磁碟等）
    GraphStructure = 9,    // Graph 結構或導航錯誤
    Cancellation = 10,     // 要求取消
    CircuitBreakerOpen = 11, // 斷路器打開（操作短路）
    BudgetExhausted = 12   // 資源預算耗盡（CPU、記憶體或成本限制）
}
```

### ErrorRecoveryAction 列舉

```csharp
public enum ErrorRecoveryAction
{
    Continue = 0,          // 繼續執行而不恢復
    Retry = 1,             // 重試失敗的操作
    Skip = 2,              // 跳過失敗的 Node 並繼續
    Fallback = 3,          // 執行回退邏輯或替代路徑
    Rollback = 4,          // 回滾到先前已知的良好狀態
    Halt = 5,              // 停止執行並傳播錯誤
    Escalate = 6,          // 升級為人工干預
    CircuitBreaker = 7     // 為 Node 打開斷路器
}
```

### ErrorSeverity 列舉

```csharp
public enum ErrorSeverity
{
    Low = 0,               // 低嚴重性 - 繼續執行並記錄
    Medium = 1,            // 中等嚴重性 - 嘗試恢復或重試
    High = 2,              // 高嚴重性 - 停止當前分支，嘗試替代方案
    Critical = 3           // 關鍵嚴重性 - 停止整個 Graph 執行
}
```

## 另見

* [錯誤處理和彈性指南](../how-to/error-handling-and-resilience.md) - 實現錯誤處理模式的綜合指南
* [Graph Executor 參考](graph-executor.md) - 與錯誤策略集成的核心執行引擎
* [主要 Node 類型參考](main-node-types.md) - 用於工作流程構建的其他專門 Node 類型
* [狀態和序列化參考](state-and-serialization.md) - 錯誤恢復和回滾的狀態管理
* [整合參考](integration.md) - 與外部系統的錯誤處理整合
* [錯誤處理範例](../examples/error-handling-examples.md) - 錯誤處理實現的實際範例
