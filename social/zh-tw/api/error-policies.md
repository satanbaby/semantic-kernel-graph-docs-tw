# 錯誤策略

本文件涵蓋 SemanticKernel.Graph 中的全面錯誤處理系統，包括策略管理、重試機制、錯誤處理節點和指標收集。該系統提供了具有可配置策略、自動重試邏輯和全面錯誤追蹤的強大彈性模式。

## ErrorPolicyRegistry

`ErrorPolicyRegistry` 在圖形執行系統中提供集中式錯誤處理策略，支持重試、斷路器和預算策略以及運行時策略解析。

### 概述

此註冊表管理具有版本控制、運行時解析和與圖形執行上下文集成的錯誤處理策略。它支持基於錯誤類型、節點類型和自定義條件的策略規則。

### 主要功能

* **集中式策略管理**：所有錯誤處理策略的單一來源
* **運行時策略解析**：基於錯誤上下文和執行狀態的動態策略選擇
* **策略版本控制**：支持策略更新和回滾
* **斷路器集成**：每個節點內置斷路器策略
* **預算管理**：具有自動執行的資源預算策略
* **線程安全性**：所有操作對於並發存取都是線程安全的

### 策略註冊

```csharp
var registry = new ErrorPolicyRegistry(new ErrorPolicyRegistryOptions());

// 使用 PolicyRule 為特定錯誤類型註冊重試策略
// (使用 RegisterPolicyRule 以正確索引和版本化規則)
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

// 使用正確的配置屬性為節點註冊斷路器策略
registry.RegisterNodeCircuitBreakerPolicy("api-node", new CircuitBreakerPolicyConfig
{
    Enabled = true,
    FailureThreshold = 5,
    OpenTimeout = TimeSpan.FromMinutes(1),
    FailureWindow = TimeSpan.FromMinutes(5)
});
```

### 可運行的範例

該存儲庫包含一個經過測試的、可運行的示例，該示例演示了本文件中的代碼片段：

- 範例源代碼：`semantic-kernel-graph-docs/examples/ErrorPoliciesExample.cs`
- 從存儲庫根目錄運行該示例（需要 .NET 8）：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- error-policies
```

此示例註冊示例策略，執行帶有模擬 `HttpRequestException` 的 `ErrorHandlerGraphNode`，並在 `ErrorMetricsCollector` 中記錄示例事件，以便您可以檢查運行時輸出並驗證所記錄的行為。

### 策略解析

策略根據錯誤上下文和節點信息進行解析：

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

`RetryPolicyGraphNode` 使用自動重試功能包裝另一個節點，使用可配置的重試策略和退避策略來處理瞬態故障。

### 概述

此專用節點為被包裝的節點提供自動重試邏輯，支持多個重試策略、錯誤類型過濾和全面的重試統計信息。它通過自動處理瞬態故障來增強圖形彈性。

### 主要功能

* **自動重試邏輯**：可配置的重試次數帶有智能退避
* **多種重試策略**：固定延遲、指數退避、線性退避和自定義策略
* **錯誤類型過濾**：僅重試特定錯誤類型或使用自定義重試條件
* **抖動支持**：隨機抖動以防止駭群問題
* **重試統計信息**：全面跟蹤重試次數和性能
* **元數據增強**：將重試上下文添加到核心參數和結果

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
    ExponentialBackoff = 2,     // 延遲指數增加
    LinearBackoff = 3,          // 延遲線性增加
    RandomJitter = 4,           // 添加到延遲的隨機抖動
    Custom = 5                   // 自定義重試邏輯
}
```

### 使用示例

#### 基本重試包裝器

```csharp
// 使用重試策略包裝函數節點
var functionNode = new FunctionGraphNode(kernelFunction, "api-call");
var retryNode = new RetryPolicyGraphNode(functionNode, new RetryPolicyConfig
{
    MaxRetries = 3,
    BaseDelay = TimeSpan.FromSeconds(1),
    Strategy = RetryStrategy.ExponentialBackoff
});

// 在圖形中連接重試節點
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
        // 僅在特定異常上重試
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
// 添加僅在重試嘗試後執行的邊
retryNode.AddEdgeForRetryOutcome(
    targetNode: fallbackNode,
    onlyOnRetrySuccess: false,
    minRetryAttempts: 2
);

// 為成功的重試場景添加邊
retryNode.AddEdgeForRetryOutcome(
    targetNode: successNode,
    onlyOnRetrySuccess: true,
    minRetryAttempts: 1
);
```

### 重試統計信息

該節點提供全面的重試統計信息：

```csharp
var statistics = retryNode.RetryStatistics;
Console.WriteLine($"Total retry attempts: {statistics.TotalRetryAttempts}");
Console.WriteLine($"Successful retries: {statistics.SuccessfulRetries}");
Console.WriteLine($"Average retry delay: {statistics.AverageRetryDelay}");
Console.WriteLine($"Last retry error: {statistics.LastRetryError?.Message}");
```

## ErrorHandlerGraphNode

`ErrorHandlerGraphNode` 是一個專用節點，用於在圖形執行期間處理錯誤，提供錯誤分類、恢復操作和基於錯誤類型的條件路由。

### 概述

該節點實現了具有自動錯誤分類、可配置恢復操作和智能路由決策的複雜錯誤處理邏輯。它在複雜工作流中用作集中式錯誤處理中樞。

### 主要功能

* **自動錯誤分類**：將異常映射到 `GraphErrorType` 枚舉值
* **可配置的恢復操作**：重試、跳過、回退、回滾、暫停、升級、繼續
* **條件路由**：基於錯誤處理結果的動態邊選擇
* **回退節點支持**：不同錯誤場景的替代執行路徑
* **全面的遙測**：詳細的錯誤追蹤和恢復指標
* **默認錯誤處理程序**：常見錯誤類型的預配置處理策略

### 錯誤分類

該節點自動將異常分類為錯誤類型：

```csharp
// 基於異常類型的自動分類
ArgumentException → GraphErrorType.Validation
TimeoutException → GraphErrorType.Timeout
OperationCanceledException → GraphErrorType.Cancellation
HttpRequestException → GraphErrorType.Network
UnauthorizedAccessException → GraphErrorType.Authentication
OutOfMemoryException → GraphErrorType.ResourceExhaustion
```

### 默認錯誤處理程序

```csharp
// 瞬態錯誤 - 自動重試
_errorHandlers[GraphErrorType.Network] = ErrorRecoveryAction.Retry;
_errorHandlers[GraphErrorType.ServiceUnavailable] = ErrorRecoveryAction.Retry;
_errorHandlers[GraphErrorType.Timeout] = ErrorRecoveryAction.Retry;
_errorHandlers[GraphErrorType.RateLimit] = ErrorRecoveryAction.Retry;

// 身份驗證錯誤 - 暫停執行
_errorHandlers[GraphErrorType.Authentication] = ErrorRecoveryAction.Halt;

// 驗證錯誤 - 跳過到下一個節點
_errorHandlers[GraphErrorType.Validation] = ErrorRecoveryAction.Skip;

// 關鍵系統錯誤 - 暫停執行
_errorHandlers[GraphErrorType.ResourceExhaustion] = ErrorRecoveryAction.Halt;
_errorHandlers[GraphErrorType.GraphStructure] = ErrorRecoveryAction.Halt;
```

### 使用示例

#### 基本錯誤處理程序

```csharp
var errorHandler = new ErrorHandlerGraphNode(
    nodeId: "error-handler-1",
    name: "MainErrorHandler",
    description: "Handles errors in the main workflow",
    logger: graphLogger
);

// 添加到圖形
graph.AddNode(errorHandler);
graph.AddEdge(failingNode, errorHandler);
```

#### 自定義錯誤處理

```csharp
var errorHandler = new ErrorHandlerGraphNode("custom-error", "CustomErrorHandler");

// 為特定錯誤類型配置自定義錯誤處理
errorHandler.ConfigureErrorHandler(GraphErrorType.Network, ErrorRecoveryAction.Retry);
errorHandler.ConfigureErrorHandler(GraphErrorType.Authentication, ErrorRecoveryAction.Escalate);

// 為特定錯誤類型設置回退節點
errorHandler.SetFallbackNode(GraphErrorType.ServiceUnavailable, alternativeServiceNode);
errorHandler.SetFallbackNode(GraphErrorType.Validation, validationHelperNode);
```

#### 基於錯誤結果的條件路由

```csharp
// 根據恢復操作路由到不同的節點
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

該節點從核心參數處理錯誤上下文：

```csharp
// 錯誤處理程序預期的輸入參數
public IReadOnlyList<string> InputParameters { get; } = new[]
{
    "LastError",           // 發生的異常
    "ErrorContext",        // 附加錯誤上下文
    "ErrorType",           // 分類的錯誤類型
    "ErrorSeverity",       // 錯誤嚴重程度級別
    "AttemptCount"         // 當前嘗試編號
}.AsReadOnly();

// 錯誤處理程序提供的輸出參數
public IReadOnlyList<string> OutputParameters { get; } = new[]
{
    "ErrorHandled",        // 是否處理了錯誤
    "RecoveryAction",      // 為恢復而採取的操作
    "ShouldRetry",         // 是否建議重試
    "RetryDelay",          // 建議的重試延遲
    "FallbackExecuted",    // 是否使用了回退
    "EscalationRequired"   // 是否需要升級
}.AsReadOnly();
```

## ErrorMetricsCollector

`ErrorMetricsCollector` 在圖形執行中收集、聚合和分析錯誤指標，提供趨勢分析、性能見解和異常檢測。

### 概述

此組件提供具有實時指標、歷史分析和性能見解的全面錯誤追蹤。它與錯誤處理系統集成，為系統可靠性提供可行的情報。

### 主要功能

* **實時指標收集**：立即進行錯誤事件處理和聚合
* **多維分析**：按執行、節點、錯誤類型和時間的指標
* **性能見解**：錯誤率、恢復成功率和趨勢分析
* **異常檢測**：自動識別異常錯誤模式
* **可配置的保留**：可調整的數據保留和清理策略
* **集成就緒**：易於與監控和警報系統集成

### 指標結構

```csharp
// 執行級別的指標
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

// 節點級別的指標
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

### 使用示例

#### 基本指標收集

```csharp
var metricsCollector = new ErrorMetricsCollector(new ErrorMetricsOptions
{
    AggregationInterval = TimeSpan.FromMinutes(1),
    MaxEventQueueSize = 10000,
    EnableMetricsCleanup = true,
    MetricsRetentionPeriod = TimeSpan.FromDays(7)
});

// 記錄一個錯誤事件
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
// 獲取特定執行的指標
var executionMetrics = metricsCollector.GetExecutionMetrics("exec-123");
if (executionMetrics != null)
{
    Console.WriteLine($"Total errors: {executionMetrics.TotalErrors}");
    Console.WriteLine($"Recovery success rate: {executionMetrics.RecoverySuccessRate:F2}%");
    Console.WriteLine($"Most common error: {executionMetrics.MostCommonErrorType}");
}

// 獲取節點特定的指標
var nodeMetrics = metricsCollector.GetNodeMetrics("api-node");
if (nodeMetrics != null)
{
    Console.WriteLine($"Node error rate: {nodeMetrics.ErrorRate:F2} errors/min");
    Console.WriteLine($"Recovery success rate: {nodeMetrics.RecoverySuccessRate:F2}%");
}

// 獲取整體統計信息
var overallStats = metricsCollector.OverallStatistics;
Console.WriteLine($"Total errors recorded: {overallStats.TotalErrors}");
Console.WriteLine($"Current error rate: {overallStats.CurrentErrorRate:F2} errors/min");
Console.WriteLine($"Overall recovery success rate: {overallStats.RecoverySuccessRate:F2}%");
```

#### 批量處理

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

### 與錯誤處理的集成

指標收集器與錯誤處理系統無縫集成：

```csharp
// 在 ErrorHandlerGraphNode 中
public async Task<FunctionResult> ExecuteAsync(Kernel kernel, KernelArguments arguments, CancellationToken cancellationToken = default)
{
    try
    {
        // ... 錯誤處理邏輯 ...
        
        // 為成功的錯誤處理記錄指標
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
        // 為失敗的錯誤處理記錄指標
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

### GraphErrorType 枚舉

```csharp
public enum GraphErrorType
{
    Unknown = 0,           // 未知或未指定的錯誤類型
    Validation = 1,        // 執行前或執行過程中的驗證錯誤
    NodeExecution = 2,     // 節點執行失敗，原因是內部邏輯錯誤
    Timeout = 3,           // 節點或圖形執行期間發生超時
    Network = 4,           // 網絡相關錯誤（瞬態的、可重試的）
    ServiceUnavailable = 5, // 外部服務不可用（可能是瞬態的）
    RateLimit = 6,         // 超出速率限制（可能是瞬態的）
    Authentication = 7,     // 身份驗證或授權失敗
    ResourceExhaustion = 8, // 資源耗盡（記憶體、磁碟等）
    GraphStructure = 9,    // 圖形結構或導航錯誤
    Cancellation = 10,     // 請求了取消
    CircuitBreakerOpen = 11, // 斷路器是打開的（操作被短路）
    BudgetExhausted = 12   // 資源預算已耗盡（CPU、記憶體或成本限額）
}
```

### ErrorRecoveryAction 枚舉

```csharp
public enum ErrorRecoveryAction
{
    Continue = 0,          // 繼續執行而不進行恢復
    Retry = 1,             // 重試失敗的操作
    Skip = 2,              // 跳過失敗的節點並繼續
    Fallback = 3,          // 執行回退邏輯或替代路徑
    Rollback = 4,          // 回滾到之前的已知良好狀態
    Halt = 5,              // 暫停執行並傳播錯誤
    Escalate = 6,          // 升級到人工干預
    CircuitBreaker = 7     // 打開節點的斷路器
}
```

### ErrorSeverity 枚舉

```csharp
public enum ErrorSeverity
{
    Low = 0,               // 低嚴重性 - 繼續執行並進行記錄
    Medium = 1,            // 中等嚴重性 - 嘗試恢復或重試
    High = 2,              // 高嚴重性 - 暫停當前分支，嘗試替代方案
    Critical = 3           // 關鍵嚴重性 - 暫停整個圖形執行
}
```

## 另請參閱

* [錯誤處理和彈性指南](../how-to/error-handling-and-resilience.md) - 實現錯誤處理模式的全面指南
* [圖形執行器參考](graph-executor.md) - 與錯誤策略集成的核心執行引擎
* [主要節點類型參考](main-node-types.md) - 用於工作流構建的其他專用節點類型
* [狀態和序列化參考](state-and-serialization.md) - 用於錯誤恢復和回滾的狀態管理
* [集成參考](integration.md) - 與外部系統的錯誤處理集成
* [錯誤處理示例](../examples/error-handling-examples.md) - 錯誤處理實現的實際示例
