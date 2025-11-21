---
title: 故障排除
---

# 故障排除

用於解決 SemanticKernel.Graph 中常見問題和診斷問題的指南。

## 概念和技術

**故障排除**：系統性地識別、診斷和解決計算圖系統中的問題的過程。

**診斷**：分析症狀、日誌和指標以確定問題的根本原因。

**恢復**：在解決問題後恢復正常功能的策略。

## 執行問題

### 執行暫停或緩慢

**症狀**:
* Graph 在特定 Node 之後不進展
* 執行時間比預期長得多
* 應用程式似乎「凍結」

**可能的原因**:
* 無限或非常長的循環
* 具有非常高超時的 Node
* 在外部資源上阻塞
* 從不滿足的路由條件

**診斷**:
```csharp
// 啟用詳細的指標和監控
var executionOptions = GraphExecutionOptions.CreateDefault();

// 建立具有效能監控的 Graph
var graph = new GraphExecutor("performance-test-graph");

// 將 Node 新增至 Graph
var slowNode = new ActionGraphNode("slow-operation", "Slow Operation", "Simulates a slow operation");
var fastNode = new ActionGraphNode("fast-operation", "Fast Operation", "Simulates a fast operation");

graph.AddNode(slowNode);
graph.AddNode(fastNode);

// 為執行設定開始 Node
graph.SetStartNode(slowNode);

// 使用效能監控執行
var startTime = DateTimeOffset.UtcNow;
var arguments = new KernelArguments();
arguments["input"] = "test input";

var result = await graph.ExecuteAsync(kernel, arguments, CancellationToken.None);
var executionTime = DateTimeOffset.UtcNow - startTime;

Console.WriteLine($"Graph execution completed in {executionTime.TotalMilliseconds:F2}ms");
```

**解決方案**:
```csharp
// 使用效能監控配置執行選項
var executionOptions = GraphExecutionOptions.CreateDefault();

// 設定適當的超時和限制
var graph = new GraphExecutor("optimized-graph");
graph.ConfigureMetrics(new GraphMetricsOptions
{
    EnableRealTimeMetrics = true,
    MetricsRetentionPeriod = TimeSpan.FromHours(24)
});

// 新增具有適當配置的 Node
var optimizedNode = new ActionGraphNode("optimized-operation", "Optimized Operation", "Fast operation with monitoring");
graph.AddNode(optimizedNode);
graph.SetStartNode(optimizedNode);
```

**預防**:
* 始終為 Graph 設定開始 Node
* 配置適當的超時
* 使用指標監控效能
* 為外部資源實作斷路器

### 缺少服務或 Null 提供者

**症狀**:
* 執行 Graph 時出現 `NullReferenceException`
* 「未註冊服務」錯誤或類似錯誤
* 特定功能無法運作

**可能的原因**:
* 未調用 `AddGraphSupport()`
* 依賴項未在 DI 容器中註冊
* 服務註冊順序不正確

**診斷**:
```csharp
// 檢查 Graph 支援是否已正確配置
var serviceProvider = kernel.Services;
var graphExecutorFactory = serviceProvider.GetService<IGraphExecutorFactory>();

if (graphExecutorFactory == null)
{
    Console.WriteLine("Graph support not enabled! This will cause errors.");
    
    // 展示配置服務的正確方式
    Console.WriteLine("Correct configuration should include:");
    Console.WriteLine("builder.AddGraphSupport(options => {");
    Console.WriteLine("    options.EnableMetrics = true;");
    Console.WriteLine("    options.EnableCheckpointing = true;");
    Console.WriteLine("});");
}
else
{
    Console.WriteLine("Graph support is properly configured");
}

// 檢查其他基本服務
var checkpointManager = serviceProvider.GetService<ICheckpointManager>();
var errorRecoveryEngine = serviceProvider.GetService<ErrorRecoveryEngine>();
var metricsExporter = serviceProvider.GetService<GraphMetricsExporter>();

Console.WriteLine("Service availability check:");
Console.WriteLine($"- GraphExecutorFactory: {(graphExecutorFactory != null ? "Available" : "Missing")}");
Console.WriteLine($"- CheckpointManager: {(checkpointManager != null ? "Available" : "Missing")}");
Console.WriteLine($"- ErrorRecoveryEngine: {(errorRecoveryEngine != null ? "Available" : "Missing")}");
Console.WriteLine($"- MetricsExporter: {(metricsExporter != null ? "Available" : "Missing")}");
```

**解決方案**:
```csharp
// 正確的配置
var builder = Kernel.CreateBuilder();

// 在其他服務之前新增 Graph 支援
builder.AddGraphSupport(options => {
    options.EnableMetrics = true;
    options.EnableCheckpointing = true;
    options.EnableLogging = true;
    options.MaxExecutionSteps = 1000;
    options.ExecutionTimeout = TimeSpan.FromMinutes(10);
});

// 新增其他服務
builder.AddOpenAIChatCompletion("gpt-4", "your-api-key");

var kernel = builder.Build();
```

**預防**:
* 始終在新增其他服務之前調用 `AddGraphSupport()`
* 驗證服務註冊順序
* 在啟動時測試服務可用性
* 正確使用相依性注入

### REST 工具中的失敗

**症狀**:
* HTTP 呼叫超時
* 身份驗證失敗
* 非預期的 API 回應

**可能的原因**:
* 不正確的驗證架構
* 非常低的超時
* 身份驗證問題
* 外部 API 無法使用

**診斷**:
```csharp
// 檢查服務可用性
var serviceProvider = kernel.Services;
var restApiService = serviceProvider.GetService<GraphRestApi>();

if (restApiService == null)
{
    Console.WriteLine("REST API service not available");
}
else
{
    Console.WriteLine("REST API service is properly configured");
}

// 檢查日誌記錄配置
var logger = serviceProvider.GetService<ILogger<GraphExecutor>>();
if (logger != null)
{
    logger.LogInformation("Graph execution logging is properly configured");
}
```

**解決方案**:
```csharp
// 使用適當的設定配置 REST API
builder.AddGraphSupport(options => {
    options.EnableLogging = true;
    options.Logging.ConfigureForProduction();
});

// 使用適當的超時配置 HTTP 用戶端
builder.Services.AddHttpClient("GraphRestApi", client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
    client.DefaultRequestHeaders.Add("User-Agent", "SemanticKernel.Graph/1.0");
});
```

**預防**:
* 使用前測試外部 API
* 實作斷路器
* 配置現實的超時
* 驗證輸入/輸出架構

## 狀態和檢查點問題

### 檢查點未還原

**症狀**:
* 執行之間失去狀態
* 還原檢查點時出錯
* 恢復後資料不一致

**可能的原因**:
* 未配置檢查點延伸
* 資料庫集合不存在
* 狀態版本不相容
* 序列化問題

**診斷**:
```csharp
// 測試檢查點功能
var serviceProvider = kernel.Services;
var checkpointManager = serviceProvider.GetService<ICheckpointManager>();

if (checkpointManager != null)
{
    // 測試檢查點建立
    var testState = new GraphState();
    testState.SetValue("test_key", "test_value");
    testState.SetValue("test_number", 42);

    var checkpoint = await checkpointManager.CreateCheckpointAsync(
        "test-execution", 
        testState, 
        "test-node", 
        null, 
        CancellationToken.None);

    Console.WriteLine($"Checkpoint created successfully: {checkpoint.CheckpointId}");

    // 測試檢查點還原
    var restoredState = await checkpointManager.RestoreFromCheckpointAsync(
        checkpoint.CheckpointId, 
        CancellationToken.None);

    if (restoredState != null)
    {
        var restoredValue = restoredState.GetValue<string>("test_key");
        Console.WriteLine($"Checkpoint restored successfully. Value: {restoredValue}");
    }
    else
    {
        Console.WriteLine("Failed to restore checkpoint");
    }
}
else
{
    Console.WriteLine("Checkpointing service not available");
}
```

**解決方案**:
```csharp
// 正確配置檢查點
builder.AddGraphSupport(options => {
    options.EnableCheckpointing = true;
    options.Checkpointing = new CheckpointingOptions
    {
        Enabled = true,
        Provider = "MongoDB", // 或其他提供者
        ConnectionString = "mongodb://localhost:27017",
        DatabaseName = "semantic-kernel-graph",
        CollectionName = "checkpoints"
    };
});
```

**預防**:
* 始終測試資料庫連線
* 實作版本狀態驗證
* 使用強大的序列化
* 監控磁碟空間

### 序列化問題

**症狀**:
* 「無法序列化類型 X」錯誤
* 檢查點損壞
* 無法保存狀態

**可能的原因**:
* 無法序列化的類型
* 迴圈參考
* 不支援的複雜類型

**診斷**:
```csharp
// 測試狀態序列化
var state = new GraphState();
try
{
    // 使用簡單類型測試
    state.SetValue("string_value", "test");
    state.SetValue("int_value", 123);
    state.SetValue("array_value", new[] { 1, 2, 3 });

    // 使用 ISerializableState 介面測試序列化
    var serialized = state.Serialize();
    Console.WriteLine($"State serialization successful. Size: {serialized.Length} bytes");

    // 使用複雜類型測試（這可能會失敗）
    try
    {
        state.SetValue("complex_object", new NonSerializableType());
        var complexSerialized = state.Serialize();
        Console.WriteLine("Complex object serialization successful");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Complex object serialization failed (expected): {ex.Message}");
        Console.WriteLine("Solution: Use simple types or implement ISerializableState");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"State serialization failed: {ex.Message}");
}
```

**解決方案**:
```csharp
// 為複雜類型實作 ISerializableState
public class MyState : ISerializableState
{
    public string Serialize() => JsonSerializer.Serialize(this);
    public static MyState Deserialize(string data) => JsonSerializer.Deserialize<MyState>(data);
}

// 或使用簡單類型
state.SetValue("simple", "string value");
state.SetValue("number", 42);
state.SetValue("array", new[] { 1, 2, 3 });
```

**預防**:
* 盡可能使用基本類型
* 為複雜類型實作 `ISerializableState`
* 避免迴圈參考
* 在開發期間測試序列化

## Python Node 問題

### Python 執行錯誤

**症狀**:
* 「找不到 python」錯誤
* Python 執行超時
* .NET 和 Python 之間的通訊失敗

**可能的原因**:
* Python 不在 PATH 中
* Python 版本不正確
* 權限問題
* 缺少 Python 依賴項

**診斷**:
```csharp
// 檢查 Python 是否可用
var pythonNode = new PythonGraphNode("python");
var isAvailable = await pythonNode.CheckAvailabilityAsync();
Console.WriteLine($"Python available: {isAvailable}");
```

**解決方案**:
```csharp
// 明確配置 Python
var pythonOptions = new PythonNodeOptions
{
    PythonPath = @"C:\Python39\python.exe", // 明確路徑
    EnvironmentVariables = new Dictionary<string, string>
    {
        ["PYTHONPATH"] = @"C:\my-python-libs",
        ["PYTHONUNBUFFERED"] = "1"
    },
    Timeout = TimeSpan.FromMinutes(5)
};

var pythonNode = new PythonGraphNode("python", pythonOptions);
```

**預防**:
* 對 Python 使用絕對路徑
* 驗證 Python 依賴項
* 配置環境變數
* 為 Python Node 實作回退

## 效能問題

### 非常緩慢的執行

**症狀**:
* 執行時間比預期長得多
* 過度的 CPU/記憶體使用
* 簡單的 Graph 需要很長時間

**可能的原因**:
* 效率低下的 Node
* 缺乏並行性
* 不必要的阻塞
* 次優的配置

**診斷**:
```csharp
// 分析效能指標
var serviceProvider = kernel.Services;
var metricsExporter = serviceProvider.GetService<GraphMetricsExporter>();

if (metricsExporter != null)
{
    // 為演示建立示例效能指標
    var performanceMetrics = new GraphPerformanceMetrics();
    
    // 以不同格式匯出指標
    var jsonMetrics = metricsExporter.ExportMetrics(performanceMetrics, MetricsExportFormat.Json);
    Console.WriteLine("Current metrics exported successfully in JSON format");

    // 為儀表板視覺化匯出
    var dashboardMetrics = metricsExporter.ExportForDashboard(performanceMetrics, DashboardType.Grafana);
    Console.WriteLine("Dashboard metrics exported successfully for Grafana");

    // 檢查效能異常
    if (jsonMetrics.Contains("error") || jsonMetrics.Contains("failure"))
    {
        Console.WriteLine("Performance issues detected in metrics");
        Console.WriteLine("Consider implementing circuit breakers or fallbacks");
    }
}
else
{
    Console.WriteLine("Metrics exporter not available");
}
```

**解決方案**:
```csharp
// 啟用並行執行和最佳化
var options = new GraphOptions
{
    EnableMetrics = true,
    EnableLogging = true,
    MaxExecutionSteps = 1000,
    EnablePlanCompilation = true
};

// 配置並行
var concurrencyOptions = new GraphConcurrencyOptions
{
    MaxParallelNodes = Environment.ProcessorCount,
    EnableOptimizations = true
};

// 使用最佳化的 Node
var optimizedNode = new ActionGraphNode("optimized-operation", "Optimized Operation", "Fast operation with monitoring");
```

**預防**:
* 定期監控指標
* 使用分析來識別瓶頸
* 在適當時實作快取
* 最佳化關鍵 Node

## 整合問題

### 身份驗證失敗

**症狀**:
* 外部 API 出現 401/403 錯誤
* LLM 身份驗證失敗
* 授權問題

**可能的原因**:
* 無效的 API 金鑰
* 過期的權杖
* 不正確的認證配置
* 權限問題

**診斷**:
```csharp
// 檢查身份驗證配置
var serviceProvider = kernel.Services;
var authService = serviceProvider.GetService<IAuthenticationService>();

if (authService != null)
{
    var isValid = await authService.ValidateCredentialsAsync();
    Console.WriteLine($"Authentication service available: {isValid}");
}
else
{
    Console.WriteLine("Authentication service not available");
}
```

**解決方案**:
```csharp
// 正確配置身份驗證
builder.AddOpenAIChatCompletion(
    modelId: "gpt-4",
    apiKey: Environment.GetEnvironmentVariable("OPENAI_API_KEY")
);

// 或使用 Azure AD
builder.AddAzureOpenAIChatCompletion(
    deploymentName: "gpt-4",
    endpoint: "https://your-endpoint.openai.azure.com/",
    apiKey: Environment.GetEnvironmentVariable("AZURE_OPENAI_API_KEY")
);
```

**預防**:
* 為認證使用環境變數
* 實作自動權杖輪換
* 監控認證過期
* 使用密碼管理員

## 恢復策略

### 自動恢復
```csharp
// 配置重試原則
var retryPolicy = new ExponentialBackoffRetryPolicy(
    maxRetries: 3,
    initialDelay: TimeSpan.FromSeconds(1)
);

// 實作斷路器
var circuitBreaker = new CircuitBreaker(
    failureThreshold: 5,
    recoveryTimeout: TimeSpan.FromMinutes(1)
);
```

### 回退和替代方案
```csharp
// 實作回退 Node
var errorHandlerNode = new ErrorHandlerGraphNode("error-handler", "Error Handler", "Handles errors during execution");
var fallbackNode = new ActionGraphNode("fallback", "Fallback Operation", "Fallback operation executed due to error");

// 配置錯誤處理
errorHandlerNode.ConfigureErrorHandler(GraphErrorType.Validation, ErrorRecoveryAction.Skip);
errorHandlerNode.ConfigureErrorHandler(GraphErrorType.Network, ErrorRecoveryAction.Retry);
errorHandlerNode.AddFallbackNode(GraphErrorType.Unknown, fallbackNode);
```

## 監控和警報

### 警報配置
```csharp
// 為關鍵問題配置警報
var alertingService = new GraphAlertingService();
alertingService.AddAlert(new AlertRule
{
    Condition = metrics => metrics.ErrorRate > 0.1,
    Severity = AlertSeverity.Critical,
    Message = "Error rate exceeded threshold"
});
```

### 結構化日誌記錄
```csharp
// 配置詳細的日誌記錄
var logger = new SemanticKernelGraphLogger();
logger.LogExecutionStart(graphId, executionId);
logger.LogNodeExecution(nodeId, executionId, duration);
logger.LogExecutionComplete(graphId, executionId, result);
```

## 完整的工作示例

這是展示故障排除技術的完整工作示例：

```csharp
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using SemanticKernel.Graph;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Integration;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;

public class TroubleshootingExample
{
    private readonly Kernel _kernel;
    private readonly ILogger<TroubleshootingExample> _logger;

    public TroubleshootingExample(Kernel kernel, ILogger<TroubleshootingExample> logger)
    {
        _kernel = kernel ?? throw new ArgumentNullException(nameof(kernel));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task RunAsync()
    {
        _logger.LogInformation("Starting Troubleshooting Examples");

        try
        {
            // 示例 1：執行效能問題
            await DemonstrateExecutionPerformanceTroubleshootingAsync();

            // 示例 2：服務註冊問題
            await DemonstrateServiceRegistrationTroubleshootingAsync();

            // 示例 3：狀態和檢查點問題
            await DemonstrateStateCheckpointTroubleshootingAsync();

            // 示例 4：錯誤恢復和彈性
            await DemonstrateErrorRecoveryTroubleshootingAsync();

            // 示例 5：效能監控和診斷
            await DemonstratePerformanceMonitoringTroubleshootingAsync();

            _logger.LogInformation("All troubleshooting examples completed successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error running troubleshooting examples");
            throw;
        }
    }

    private async Task DemonstrateExecutionPerformanceTroubleshootingAsync()
    {
        _logger.LogInformation("=== Execution Performance Troubleshooting ===");

        try
        {
            // 建立具有潛在效能問題的 Graph
            var graph = new GraphExecutor("performance-test-graph");
            
            // 將 Node 新增至 Graph
            var slowNode = new ActionGraphNode("slow-operation", "Slow Operation", "Simulates a slow operation");
            var fastNode = new ActionGraphNode("fast-operation", "Fast Operation", "Simulates a fast operation");
            
            graph.AddNode(slowNode);
            graph.AddNode(fastNode);

            // 為執行設定開始 Node
            graph.SetStartNode(slowNode);

            // 使用效能監控執行
            var startTime = DateTimeOffset.UtcNow;
            
            // 建立執行的引數
            var arguments = new KernelArguments();
            arguments["input"] = "test input";
            
            var result = await graph.ExecuteAsync(_kernel, arguments, CancellationToken.None);
            var executionTime = DateTimeOffset.UtcNow - startTime;

            _logger.LogInformation("Graph execution completed in {ExecutionTime:F2}ms", executionTime.TotalMilliseconds);

            // 分析效能指標（如果可用）
            if (result.Metadata != null && result.Metadata.ContainsKey("ExecutionMetrics"))
            {
                _logger.LogInformation("Execution metrics available in result metadata");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in execution performance troubleshooting");
        }
    }

    // ... 其他方法如上面的完整示例所示
}
```

## 另請參閱

* [錯誤處理](../how-to/error-handling-and-resilience.md)
* [效能調整](../how-to/performance-tuning.md)
* [監控](../how-to/metrics-and-observability.md)
* [配置](../how-to/configuration.md)
* [示例](../examples/index.md)

## 參考

* `GraphExecutionOptions`：執行設定
* `CheckpointingOptions`：檢查點設定
* `PythonNodeOptions`：Python Node 設定
* `RetryPolicy`：重試原則
* `CircuitBreaker`：用於彈性的斷路器
* `GraphAlertingService`：警報系統
