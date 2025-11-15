# 其他公用程式

本參考涵蓋 SemanticKernel.Graph 中公開的其他公用程式類別和方法，為常見作業、驗證和進階模式提供輔助功能。

## 概述

SemanticKernel.Graph 程式庫提供了一套完整的公用程式類別和擴充方法，可簡化常見作業、啟用進階模式，並提供驗證和除錯功能。這些公用程式設計為非侵入性的，並在可能的情況下遵循函數程式設計原則。

## 擴充類別

### AdvancedPatternsExtensions

整合進階模式與圖形系統的擴充方法，為學術恢復模式、最佳化和企業整合提供流暢的輔助程式。

#### 學術模式

```csharp
public static class AdvancedPatternsExtensions
{
    // 新增學術恢復模式
    public static GraphExecutor WithAcademicPatterns(
        this GraphExecutor executor,
        Action<AcademicPatternsConfiguration>? configureOptions = null)
    
    // 使用熔斷器保護執行
    public static async Task<T> ExecuteWithCircuitBreakerAsync<T>(
        this GraphExecutor executor,
        Func<Task<T>> operation,
        Func<Task<T>>? fallback = null)
    
    // 使用隔離執行
    public static async Task<T> ExecuteWithBulkheadAsync<T>(
        this GraphExecutor executor,
        Func<CancellationToken, Task<T>> operation,
        CancellationToken cancellationToken)
    
    // 使用快取旁路模式執行
    public static async Task<T> ExecuteWithCacheAsideAsync<T>(
        this GraphExecutor executor,
        string cacheKey,
        Func<Task<T>> operation,
        TimeSpan? expiration = null)
}
```

**範例：**
```csharp
var executor = new GraphExecutor("resilient-graph")
    .WithAcademicPatterns(config => 
    {
        config.EnableCircuitBreaker = true;
        config.EnableBulkhead = true;
        config.EnableCacheAside = true;
    });

// 使用熔斷器保護執行
var result = await executor.ExecuteWithCircuitBreakerAsync(
    async () => await ProcessDataAsync(),
    async () => await GetFallbackDataAsync()
);
```

### DynamicRoutingExtensions

用於動態路由和條件執行模式的擴充方法。

```csharp
public static class DynamicRoutingExtensions
{
    // 將動態路由新增至執行程式
    public static GraphExecutor WithDynamicRouting(
        this GraphExecutor executor,
        Action<DynamicRoutingConfiguration>? configureOptions = null)
    
    // 設定路由策略
    public static GraphExecutor ConfigureRoutingStrategies(
        this GraphExecutor executor,
        IDictionary<string, IRoutingStrategy> strategies)
    
    // 新增路由中介軟體
    public static GraphExecutor AddRoutingMiddleware(
        this GraphExecutor executor,
        IRoutingMiddleware middleware)
}
```

**範例：**
```csharp
var executor = new GraphExecutor("dynamic-graph")
    .WithDynamicRouting(config => 
    {
        config.EnableEmbeddingBasedRouting = true;
        config.EnableProbabilisticRouting = true;
        config.DefaultRoutingStrategy = "similarity";
    });
```

### GraphPerformanceExtensions

用於效能監控和最佳化的擴充方法。

```csharp
public static class GraphPerformanceExtensions
{
    // 啟用效能指標
    public static GraphExecutor WithPerformanceMetrics(
        this GraphExecutor executor,
        Action<GraphPerformanceOptions>? configureOptions = null)
    
    // 取得效能摘要
    public static GraphPerformanceSummary GetPerformanceSummary(
        this GraphExecutor executor)
    
    // 匯出指標
    public static async Task ExportMetricsAsync(
        this GraphExecutor executor,
        IMetricsExporter exporter)
}
```

**範例：**
```csharp
var executor = new GraphExecutor("performance-graph")
    .WithPerformanceMetrics(config => 
    {
        config.EnableDetailedMetrics = true;
        config.EnableExport = true;
        config.ExportInterval = TimeSpan.FromMinutes(5);
    });

// 執行後取得效能摘要
var summary = executor.GetPerformanceSummary();
Console.WriteLine($"總執行時間: {summary.TotalExecutionTime}");
Console.WriteLine($"平均節點時間: {summary.AverageNodeExecutionTime}");
```

### HumanInTheLoopExtensions

人工在迴圈中 (Human-in-the-Loop) 功能的擴充方法。

```csharp
public static class HumanInTheLoopExtensions
{
    // 新增人工核准節點
    public static GraphExecutor AddHumanApproval(
        this GraphExecutor executor,
        string nodeId,
        string title,
        string message,
        IHumanInteractionChannel channel)
    
    // 新增信心度閘門
    public static GraphExecutor AddConfidenceGate(
        this GraphExecutor executor,
        string nodeId,
        double confidenceThreshold,
        IConfidenceSource confidenceSource)
    
    // 設定 HITL 選項
    public static GraphExecutor ConfigureHumanInTheLoop(
        this GraphExecutor executor,
        Action<HumanInTheLoopOptions> configureOptions)
}
```

**範例：**
```csharp
var executor = new GraphExecutor("hitl-graph")
    .AddHumanApproval("approval", "資料審查", "請審查已處理的資料", channel)
    .AddConfidenceGate("confidence", 0.8, confidenceSource)
    .ConfigureHumanInTheLoop(config => 
    {
        config.DefaultTimeout = TimeSpan.FromHours(24);
        config.EnableBatching = true;
    });
```

### LoggingExtensions

增強圖形記錄功能的擴充方法。

```csharp
public static class LoggingExtensions
{
    // 記錄圖形層級資訊
    public static void LogGraphInfo(
        this IGraphLogger logger,
        string executionId,
        string message,
        IDictionary<string, object>? properties = null)
    
    // 記錄節點層級資訊
    public static void LogNodeInfo(
        this IGraphLogger logger,
        string executionId,
        string nodeId,
        string message,
        IDictionary<string, object>? properties = null)
    
    // 記錄執行指標
    public static void LogExecutionMetrics(
        this IGraphLogger logger,
        string executionId,
        GraphPerformanceMetrics metrics)
}
```

**範例：**
```csharp
logger.LogGraphInfo(executionId, "圖形執行已開始", 
    new Dictionary<string, object> { ["nodeCount"] = 5 });

logger.LogNodeInfo(executionId, "node1", "節點執行已完成", 
    new Dictionary<string, object> { ["duration"] = "150ms" });
```

### StreamingExtensions

用於串流執行和事件處理的擴充方法。

```csharp
public static class StreamingExtensions
{
    // 啟用串流執行
    public static GraphExecutor WithStreamingSupport(
        this GraphExecutor executor,
        Action<StreamingOptions>? configureOptions = null)
    
    // 設定事件串流
    public static GraphExecutor ConfigureEventStream(
        this GraphExecutor executor,
        IGraphExecutionEventStream eventStream)
    
    // 新增串流中介軟體
    public static GraphExecutor AddStreamingMiddleware(
        this GraphExecutor executor,
        IStreamingMiddleware middleware)
}
```

**範例：**
```csharp
var executor = new GraphExecutor("streaming-graph")
    .WithStreamingSupport(config => 
    {
        config.EnableRealTimeEvents = true;
        config.EventBufferSize = 1000;
        config.EnableCompression = true;
    });
```

## 公用程式類別

### StateHelpers

靜態公用程式方法用於常見的狀態作業，包括序列化、合併、驗證和檢查點。

#### 序列化方法

```csharp
public static class StateHelpers
{
    // 使用選項序列化狀態
    public static string SerializeState(
        GraphState state, 
        bool indented = false, 
        bool enableCompression = true, 
        bool useCache = true)
    
    // 使用指標序列化
    public static string SerializeState(
        GraphState state, 
        bool indented, 
        bool enableCompression, 
        bool useCache, 
        out SerializationMetrics metrics)
    
    // 反序列化狀態
    public static GraphState DeserializeState(string serializedData)
    
    // 建立狀態快照
    public static GraphState CreateSnapshot(GraphState state)
}
```

#### 狀態管理方法

```csharp
// 使用衝突解決合併狀態
public static StateMergeResult MergeStates(
    GraphState baseState, 
    GraphState otherState, 
    StateMergeConflictPolicy policy)

// 驗證狀態完整性
public static ValidationResult ValidateState(GraphState state)

// 建立檢查點
public static string CreateCheckpoint(GraphState state, string checkpointName)

// 還原檢查點
public static GraphState RestoreCheckpoint(GraphState state, string checkpointId)

// 回復交易
public static GraphState RollbackTransaction(GraphState state, string transactionId)
```

#### 壓縮方法

```csharp
// 取得壓縮統計資訊
public static CompressionStats GetCompressionStats(string data)

// 取得自適應壓縮臨界值
public static int GetAdaptiveCompressionThreshold()

// 重設自適應壓縮
public static void ResetAdaptiveCompression()

// 取得自適應壓縮狀態
public static AdaptiveCompressionState GetAdaptiveCompressionState()
```

### StateValidator

靜態公用程式方法用於驗證圖形狀態的完整性和一致性。

```csharp
public static class StateValidator
{
    // 驗證完整狀態
    public static ValidationResult ValidateState(GraphState state)
    
    // 驗證關鍵屬性
    public static bool ValidateCriticalProperties(GraphState state)
    
    // 驗證參數名稱
    public static IList<string> ValidateParameterNames(GraphState state)
    
    // 驗證執行歷程記錄
    public static IList<string> ValidateExecutionHistory(GraphState state)
}
```

### ConditionalExpressionEvaluator

使用語意核心範本和自訂邏輯評估條件運算式的公用程式類別。

```csharp
public sealed class ConditionalExpressionEvaluator
{
    // 評估條件運算式
    public static ConditionalEvaluationResult Evaluate(
        string expression, 
        GraphState state, 
        Kernel kernel)
    
    // 使用自訂內容評估
    public static ConditionalEvaluationResult Evaluate(
        string expression, 
        GraphState state, 
        Kernel kernel, 
        IDictionary<string, object> customContext)
    
    // 取得評估統計資訊
    public static ConditionalEvaluationStats GetStatistics()
    
    // 清除評估快取
    public static void ClearCache()
}
```

### ChainOfThoughtValidator

驗證思維鏈 (Chain-of-Thought) 推理步驟的公用程式類別。

```csharp
public sealed class ChainOfThoughtValidator
{
    // 驗證推理步驟
    public async Task<ChainOfThoughtValidationResult> ValidateStepAsync(
        ChainOfThoughtStep step,
        ChainOfThoughtContext context,
        ChainOfThoughtResult previousResult,
        CancellationToken cancellationToken = default)
    
    // 新增自訂驗證規則
    public void AddCustomRule(IChainOfThoughtValidationRule rule)
    
    // 設定驗證臨界值
    public void ConfigureThresholds(IDictionary<string, double> thresholds)
    
    // 取得驗證統計資訊
    public ChainOfThoughtValidationStats GetStatistics()
}
```

## 模組啟用

### ModuleActivationExtensions

用於透過相依性注入有條件地啟用選用圖形模組的擴充程式。

```csharp
public static class ModuleActivationExtensions
{
    // 新增選用圖形模組
    public static IKernelBuilder AddGraphModules(
        this IKernelBuilder builder, 
        Action<GraphModuleActivationOptions>? configure = null)
}

public sealed class GraphModuleActivationOptions
{
    public bool EnableStreaming { get; set; }
    public bool EnableCheckpointing { get; set; }
    public bool EnableRecovery { get; set; }
    public bool EnableHumanInTheLoop { get; set; }
    public bool EnableMultiAgent { get; set; }
    
    // 套用環境覆寫
    public void ApplyEnvironmentOverrides()
}
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder()
    .AddGraphModules(options => 
    {
        options.EnableStreaming = true;
        options.EnableCheckpointing = true;
        options.EnableRecovery = true;
        options.EnableHumanInTheLoop = true;
        options.EnableMultiAgent = true;
    });

// 環境變數可以覆寫這些設定:
// SKG_ENABLE_STREAMING=true
// SKG_ENABLE_CHECKPOINTING=true
// SKG_ENABLE_RECOVERY=true
// SKG_ENABLE_HITL=true
// SKG_ENABLE_MULTIAGENT=true
```

## 使用範例

### 基本公用程式使用

```csharp
// 使用 StateHelpers 進行序列化
var serialized = StateHelpers.SerializeState(graphState, indented: true);
var restored = StateHelpers.DeserializeState(serialized);

// 使用 StateValidator 進行完整性檢查
var validation = StateValidator.ValidateState(graphState);
if (!validation.IsValid)
{
    foreach (var issue in validation.Errors)
    {
        Console.WriteLine($"錯誤: {issue.Message}");
    }
}

// 使用 ConditionalExpressionEvaluator
var evaluator = new ConditionalExpressionEvaluator();
var result = evaluator.Evaluate("{{user.role}} == 'admin'", graphState, kernel);
if (result.IsTrue)
{
    Console.WriteLine("使用者是管理員");
}
```

### 進階模式整合

```csharp
var executor = new GraphExecutor("advanced-graph")
    .WithAcademicPatterns(config => 
    {
        config.EnableCircuitBreaker = true;
        config.EnableBulkhead = true;
        config.EnableCacheAside = true;
    })
    .WithDynamicRouting(config => 
    {
        config.EnableEmbeddingBasedRouting = true;
    })
    .WithPerformanceMetrics(config => 
    {
        config.EnableDetailedMetrics = true;
    });
```

### 模組設定

```csharp
var builder = Kernel.CreateBuilder()
    .AddGraphSupport()
    .AddGraphModules(options => 
    {
        options.EnableStreaming = true;
        options.EnableCheckpointing = true;
        options.EnableRecovery = true;
        options.EnableHumanInTheLoop = true;
        options.EnableMultiAgent = true;
    });

var kernel = builder.Build();
```

## 另請參閱

* [擴充程式和選項](./extensions-and-options.md) - 核心擴充類別和設定選項
* [狀態和序列化](./state-and-serialization.md) - 狀態管理和序列化公用程式
* [執行內容](./execution-context.md) - 執行內容和事件公用程式
* [GraphExecutor API](./graph-executor.md) - 主要執行程式介面
* [進階模式](../how-to/advanced-patterns.md) - 進階模式使用指南
