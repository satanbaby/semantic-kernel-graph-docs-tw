---
title: 疑難排解
---

# 疑難排解

SemanticKernel.Graph 中常見問題的解決和診斷指南。

## 概念與技術

**疑難排解**：識別、診斷和解決計算圖表系統問題的系統性過程。

**診斷**：分析症狀、日誌和指標以確定問題根本原因的分析過程。

**復原**：解決問題後恢復正常功能的策略。

## 執行問題

### 執行暫停或速度較慢

**症狀**：
* 圖表在特定節點之後停止進展
* 執行時間遠長於預期
* 應用程式似乎「凍結」

**可能原因**：
* 無限或非常長的迴圈
* 具有非常高逾時的節點
* 外部資源堵塞
* 永遠無法滿足的路由條件

**診斷**：
```csharp
// 啟用詳細指標和監測
var executionOptions = GraphExecutionOptions.CreateDefault();

// 建立具有效能監測的圖表
var graph = new GraphExecutor("performance-test-graph");

// 新增節點到圖表
var slowNode = new ActionGraphNode("slow-operation", "慢速操作", "模擬慢速操作");
var fastNode = new ActionGraphNode("fast-operation", "快速操作", "模擬快速操作");

graph.AddNode(slowNode);
graph.AddNode(fastNode);

// 設定執行的起始節點
graph.SetStartNode(slowNode);

// 執行並進行效能監測
var startTime = DateTimeOffset.UtcNow;
var arguments = new KernelArguments();
arguments["input"] = "test input";

var result = await graph.ExecuteAsync(kernel, arguments, CancellationToken.None);
var executionTime = DateTimeOffset.UtcNow - startTime;

Console.WriteLine($"圖表執行完成，耗時 {executionTime.TotalMilliseconds:F2}ms");
```

**解決方案**：
```csharp
// 配置執行選項並進行效能監測
var executionOptions = GraphExecutionOptions.CreateDefault();

// 設定適當的逾時和限制
var graph = new GraphExecutor("optimized-graph");
graph.ConfigureMetrics(new GraphMetricsOptions
{
    EnableRealTimeMetrics = true,
    MetricsRetentionPeriod = TimeSpan.FromHours(24)
});

// 新增配置適當的節點
var optimizedNode = new ActionGraphNode("optimized-operation", "最佳化操作", "具有監測功能的快速操作");
graph.AddNode(optimizedNode);
graph.SetStartNode(optimizedNode);
```

**預防**：
* 總是為圖表設定起始節點
* 配置適當的逾時
* 使用指標監測效能
* 為外部資源實現斷路器

### 缺少服務或 Null 提供者

**症狀**：
* 執行圖表時出現 `NullReferenceException`
* 「未註冊服務」錯誤或類似錯誤
* 特定功能無法運作

**可能原因**：
* 未呼叫 `AddGraphSupport()`
* 相依性未在 DI 容器中註冊
* 服務註冊順序不正確

**診斷**：
```csharp
// 檢查圖表支援是否正確配置
var serviceProvider = kernel.Services;
var graphExecutorFactory = serviceProvider.GetService<IGraphExecutorFactory>();

if (graphExecutorFactory == null)
{
    Console.WriteLine("未啟用圖表支援！這將導致錯誤。");
    
    // 示範正確的配置方式
    Console.WriteLine("正確配置應包含：");
    Console.WriteLine("builder.AddGraphSupport(options => {");
    Console.WriteLine("    options.EnableMetrics = true;");
    Console.WriteLine("    options.EnableCheckpointing = true;");
    Console.WriteLine("});");
}
else
{
    Console.WriteLine("圖表支援配置正確");
}

// 檢查其他必要的服務
var checkpointManager = serviceProvider.GetService<ICheckpointManager>();
var errorRecoveryEngine = serviceProvider.GetService<ErrorRecoveryEngine>();
var metricsExporter = serviceProvider.GetService<GraphMetricsExporter>();

Console.WriteLine("服務可用性檢查：");
Console.WriteLine($"- GraphExecutorFactory：{(graphExecutorFactory != null ? "可用" : "缺少")}");
Console.WriteLine($"- CheckpointManager：{(checkpointManager != null ? "可用" : "缺少")}");
Console.WriteLine($"- ErrorRecoveryEngine：{(errorRecoveryEngine != null ? "可用" : "缺少")}");
Console.WriteLine($"- MetricsExporter：{(metricsExporter != null ? "可用" : "缺少")}");
```

**解決方案**：
```csharp
// 正確配置
var builder = Kernel.CreateBuilder();

// 在其他服務之前新增圖表支援
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

**預防**：
* 總是在新增其他服務之前呼叫 `AddGraphSupport()`
* 驗證服務註冊順序
* 在啟動期間測試服務可用性
* 正確使用相依性注入

### REST 工具失敗

**症狀**：
* HTTP 呼叫逾時
* 驗證失敗
* 異常的 API 回應

**可能原因**：
* 驗證架構不正確
* 逾時設定過低
* 驗證問題
* 外部 API 不可用

**診斷**：
```csharp
// 檢查服務可用性
var serviceProvider = kernel.Services;
var restApiService = serviceProvider.GetService<GraphRestApi>();

if (restApiService == null)
{
    Console.WriteLine("REST API 服務不可用");
}
else
{
    Console.WriteLine("REST API 服務配置正確");
}

// 檢查日誌配置
var logger = serviceProvider.GetService<ILogger<GraphExecutor>>();
if (logger != null)
{
    logger.LogInformation("圖表執行日誌配置正確");
}
```

**解決方案**：
```csharp
// 使用適當設定配置 REST API
builder.AddGraphSupport(options => {
    options.EnableLogging = true;
    options.Logging.ConfigureForProduction();
});

// 使用適當的逾時配置 HTTP 用戶端
builder.Services.AddHttpClient("GraphRestApi", client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
    client.DefaultRequestHeaders.Add("User-Agent", "SemanticKernel.Graph/1.0");
});
```

**預防**：
* 在使用前測試外部 API
* 實現斷路器
* 配置合理的逾時
* 驗證輸入/輸出架構

## 狀態和檢查點問題

### 檢查點未還原

**症狀**：
* 執行之間狀態遺失
* 還原檢查點時出錯
* 復原後資料不一致

**可能原因**：
* 檢查點擴充功能未配置
* 資料庫集合不存在
* 狀態版本不相容
* 序列化問題

**診斷**：
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

    Console.WriteLine($"檢查點建立成功：{checkpoint.CheckpointId}");

    // 測試檢查點還原
    var restoredState = await checkpointManager.RestoreFromCheckpointAsync(
        checkpoint.CheckpointId, 
        CancellationToken.None);

    if (restoredState != null)
    {
        var restoredValue = restoredState.GetValue<string>("test_key");
        Console.WriteLine($"檢查點還原成功。值：{restoredValue}");
    }
    else
    {
        Console.WriteLine("檢查點還原失敗");
    }
}
else
{
    Console.WriteLine("檢查點服務不可用");
}
```

**解決方案**：
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

**預防**：
* 總是測試資料庫連接
* 實現版本狀態驗證
* 使用健全的序列化
* 監測磁碟空間

### 序列化問題

**症狀**：
* 「無法序列化類型 X」錯誤
* 檢查點損毀
* 狀態儲存失敗

**可能原因**：
* 非可序列化類型
* 循環參考
* 不支援的複雜類型

**診斷**：
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
    Console.WriteLine($"狀態序列化成功。大小：{serialized.Length} 位元組");

    // 測試複雜類型（可能失敗）
    try
    {
        state.SetValue("complex_object", new NonSerializableType());
        var complexSerialized = state.Serialize();
        Console.WriteLine("複雜物件序列化成功");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"複雜物件序列化失敗（預期）：{ex.Message}");
        Console.WriteLine("解決方案：使用簡單類型或實現 ISerializableState");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"狀態序列化失敗：{ex.Message}");
}
```

**解決方案**：
```csharp
// 為複雜類型實現 ISerializableState
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

**預防**：
* 盡可能使用基本類型
* 為複雜類型實現 `ISerializableState`
* 避免循環參考
* 在開發期間測試序列化

## Python 節點問題

### Python 執行錯誤

**症狀**：
* 「找不到 python」錯誤
* Python 執行逾時
* .NET 和 Python 之間的通訊失敗

**可能原因**：
* Python 不在 PATH 中
* Python 版本不正確
* 權限問題
* 缺少 Python 相依性

**診斷**：
```csharp
// 檢查 Python 是否可用
var pythonNode = new PythonGraphNode("python");
var isAvailable = await pythonNode.CheckAvailabilityAsync();
Console.WriteLine($"Python 可用：{isAvailable}");
```

**解決方案**：
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

**預防**：
* 使用 Python 的絕對路徑
* 驗證 Python 相依性
* 配置環境變數
* 為 Python 節點實現備援

## 效能問題

### 執行非常緩慢

**症狀**：
* 執行時間遠長於預期
* 過多的 CPU/記憶體使用
* 簡單圖表需要很長時間

**可能原因**：
* 節點效率不高
* 缺乏平行處理
* 不必要的堵塞
* 次優配置

**診斷**：
```csharp
// 分析效能指標
var serviceProvider = kernel.Services;
var metricsExporter = serviceProvider.GetService<GraphMetricsExporter>();

if (metricsExporter != null)
{
    // 建立示範效能指標
    var performanceMetrics = new GraphPerformanceMetrics();
    
    // 以不同格式匯出指標
    var jsonMetrics = metricsExporter.ExportMetrics(performanceMetrics, MetricsExportFormat.Json);
    Console.WriteLine("已成功以 JSON 格式匯出目前指標");

    // 匯出用於儀表板視覺化
    var dashboardMetrics = metricsExporter.ExportForDashboard(performanceMetrics, DashboardType.Grafana);
    Console.WriteLine("已成功為 Grafana 匯出儀表板指標");

    // 檢查效能異常
    if (jsonMetrics.Contains("error") || jsonMetrics.Contains("failure"))
    {
        Console.WriteLine("在指標中偵測到效能問題");
        Console.WriteLine("考慮實現斷路器或備援");
    }
}
else
{
    Console.WriteLine("指標匯出工具不可用");
}
```

**解決方案**：
```csharp
// 啟用平行執行和最佳化
var options = new GraphOptions
{
    EnableMetrics = true,
    EnableLogging = true,
    MaxExecutionSteps = 1000,
    EnablePlanCompilation = true
};

// 配置並發
var concurrencyOptions = new GraphConcurrencyOptions
{
    MaxParallelNodes = Environment.ProcessorCount,
    EnableOptimizations = true
};

// 使用最佳化節點
var optimizedNode = new ActionGraphNode("optimized-operation", "最佳化操作", "具有監測功能的快速操作");
```

**預防**：
* 定期監測指標
* 使用分析找出瓶頸
* 在適當時實現快取
* 最佳化關鍵節點

## 整合問題

### 驗證失敗

**症狀**：
* 外部 API 上的 401/403 錯誤
* LLM 驗證失敗
* 授權問題

**可能原因**：
* 無效的 API 金鑰
* 權杖已過期
* 不正確的認證配置
* 權限問題

**診斷**：
```csharp
// 檢查驗證配置
var serviceProvider = kernel.Services;
var authService = serviceProvider.GetService<IAuthenticationService>();

if (authService != null)
{
    var isValid = await authService.ValidateCredentialsAsync();
    Console.WriteLine($"驗證服務可用：{isValid}");
}
else
{
    Console.WriteLine("驗證服務不可用");
}
```

**解決方案**：
```csharp
// 正確配置驗證
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

**預防**：
* 使用環境變數儲存認證
* 實現自動權杖輪換
* 監測認證過期
* 使用密碼管理工具

## 復原策略

### 自動復原
```csharp
// 配置重試原則
var retryPolicy = new ExponentialBackoffRetryPolicy(
    maxRetries: 3,
    initialDelay: TimeSpan.FromSeconds(1)
);

// 實現斷路器
var circuitBreaker = new CircuitBreaker(
    failureThreshold: 5,
    recoveryTimeout: TimeSpan.FromMinutes(1)
);
```

### 備援和替代方案
```csharp
// 實現備援節點
var errorHandlerNode = new ErrorHandlerGraphNode("error-handler", "錯誤處理器", "處理執行期間的錯誤");
var fallbackNode = new ActionGraphNode("fallback", "備援操作", "由於錯誤而執行的備援操作");

// 配置錯誤處理
errorHandlerNode.ConfigureErrorHandler(GraphErrorType.Validation, ErrorRecoveryAction.Skip);
errorHandlerNode.ConfigureErrorHandler(GraphErrorType.Network, ErrorRecoveryAction.Retry);
errorHandlerNode.AddFallbackNode(GraphErrorType.Unknown, fallbackNode);
```

## 監測和警報

### 警報配置
```csharp
// 配置關鍵問題的警報
var alertingService = new GraphAlertingService();
alertingService.AddAlert(new AlertRule
{
    Condition = metrics => metrics.ErrorRate > 0.1,
    Severity = AlertSeverity.Critical,
    Message = "錯誤率超過閾值"
});
```

### 結構化日誌
```csharp
// 配置詳細日誌
var logger = new SemanticKernelGraphLogger();
logger.LogExecutionStart(graphId, executionId);
logger.LogNodeExecution(nodeId, executionId, duration);
logger.LogExecutionComplete(graphId, executionId, result);
```

## 完整工作範例

以下是展示疑難排解技術的完整工作範例：

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
        _logger.LogInformation("開始疑難排解示例");

        try
        {
            // 示例 1：執行效能問題
            await DemonstrateExecutionPerformanceTroubleshootingAsync();

            // 示例 2：服務註冊問題
            await DemonstrateServiceRegistrationTroubleshootingAsync();

            // 示例 3：狀態和檢查點問題
            await DemonstrateStateCheckpointTroubleshootingAsync();

            // 示例 4：錯誤復原和復原力
            await DemonstrateErrorRecoveryTroubleshootingAsync();

            // 示例 5：效能監測和診斷
            await DemonstratePerformanceMonitoringTroubleshootingAsync();

            _logger.LogInformation("所有疑難排解示例已成功完成");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "執行疑難排解示例時出錯");
            throw;
        }
    }

    private async Task DemonstrateExecutionPerformanceTroubleshootingAsync()
    {
        _logger.LogInformation("=== 執行效能疑難排解 ===");

        try
        {
            // 建立可能存在效能問題的圖表
            var graph = new GraphExecutor("performance-test-graph");
            
            // 新增節點到圖表
            var slowNode = new ActionGraphNode("slow-operation", "慢速操作", "模擬慢速操作");
            var fastNode = new ActionGraphNode("fast-operation", "快速操作", "模擬快速操作");
            
            graph.AddNode(slowNode);
            graph.AddNode(fastNode);

            // 設定執行的起始節點
            graph.SetStartNode(slowNode);

            // 執行並進行效能監測
            var startTime = DateTimeOffset.UtcNow;
            
            // 建立執行的引數
            var arguments = new KernelArguments();
            arguments["input"] = "test input";
            
            var result = await graph.ExecuteAsync(_kernel, arguments, CancellationToken.None);
            var executionTime = DateTimeOffset.UtcNow - startTime;

            _logger.LogInformation("圖表執行完成，耗時 {ExecutionTime:F2}ms", executionTime.TotalMilliseconds);

            // 分析效能指標（如果有的話）
            if (result.Metadata != null && result.Metadata.ContainsKey("ExecutionMetrics"))
            {
                _logger.LogInformation("在結果中繼資料中提供執行指標");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "執行效能疑難排解時出錯");
        }
    }

    // ... 如上述完整範例所示的其他方法
}
```

## 另請參閱

* [錯誤處理](../how-to/error-handling-and-resilience.md)
* [效能調整](../how-to/performance-tuning.md)
* [監測](../how-to/metrics-and-observability.md)
* [配置](../how-to/configuration.md)
* [範例](../examples/index.md)

## 參考

* `GraphExecutionOptions`：執行設定
* `CheckpointingOptions`：檢查點設定
* `PythonNodeOptions`：Python 節點設定
* `RetryPolicy`：重試原則
* `CircuitBreaker`：用於復原力的斷路器
* `GraphAlertingService`：警報系統

