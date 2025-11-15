# 整合與擴充

SemanticKernel.Graph 中的整合與擴充提供與 Semantic Kernel 的無縫整合以及用於生產環境部署的全面配置選項。本指南涵蓋核心建構器擴充、配置選項、資料清理、結構化日誌記錄和政策管理。

## 您將學習的內容

* 如何將圖表功能與現有的 Semantic Kernel 實例整合
* 針對不同環境配置全面的圖表選項
* 實施資料清理和安全政策
* 使用關聯和上下文設置結構化日誌記錄
* 管理成本、逾時和錯誤處理的政策
* 生產整合和部署的最佳實務

## 概念和技術

**KernelBuilderExtensions**：流暢的 API 擴充功能，支援零配置圖表設置並與現有 Semantic Kernel 實例整合。

**GraphOptions**：圖表功能的全面配置選項，包括日誌記錄、指標、驗證和執行邊界。

**SensitiveDataSanitizer**：自動從日誌、匯出和偵錯輸出中編輯敏感資訊的工具。

**Structured Logging**：透過關聯 ID、執行上下文和結構化資料增強的日誌記錄，以提升可觀測性。

**Policy System**：可插拔政策，用於成本管理、逾時處理、錯誤恢復和商業邏輯整合。

## 先決條件

* [第一個圖表教程](../first-graph-5-minutes.md)已完成
* 對 Semantic Kernel 概念的基本理解
* 熟悉依賴注入和配置
* 了解日誌記錄和安全最佳實務

## 核心建構器整合

### 基本圖表支援整合

將圖表功能新增到現有 Semantic Kernel 實例：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;

// 建立具有圖表支援的核心
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport()  // 使用預設配置啟用
    .Build();
```

### 自訂圖表整合

在整合期間配置圖表選項：

```csharp
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.EnableLogging = true;
        options.EnableMetrics = true;
        options.MaxExecutionSteps = 500;
        options.ValidateGraphIntegrity = true;
        options.ExecutionTimeout = TimeSpan.FromMinutes(5);
        
        // 配置日誌記錄選項
        options.Logging.EnableStructuredLogging = true;
        options.Logging.EnableCorrelationIds = true;
        options.Logging.IncludeTimings = true;
        options.Logging.LogSensitiveData = false;
    })
    .Build();
```

### 環境特定整合

使用預設配置針對不同環境：

```csharp
// 開發環境
var devKernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupportForDebugging()  // 增強的日誌記錄、詳細指標
    .Build();

// 生產環境
var prodKernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupportForProduction()  // 最佳化的日誌記錄、生產指標
    .Build();

// 高效能環境
var perfKernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupportForPerformance()  // 最小日誌記錄、效能重點
    .Build();
```

### 具有所有功能的完整整合

啟用全面的圖表功能：

```csharp
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddCompleteGraphSupport(options =>
    {
        options.EnableLogging = true;
        options.EnableMetrics = true;
        options.EnableMemory = true;
        options.EnableTemplates = true;
        options.EnableVectorSearch = true;
        options.EnableSemanticSearch = true;
        options.MaxExecutionSteps = 1000;
    })
    .Build();
```

## 圖表選項配置

### 核心圖表選項

配置基本圖表行為：

```csharp
var graphOptions = new GraphOptions
{
    // 核心功能
    EnableLogging = true,
    EnableMetrics = true,
    EnablePlanCompilation = true,
    
    // 執行限制
    MaxExecutionSteps = 1000,
    ExecutionTimeout = TimeSpan.FromMinutes(10),
    
    // 驗證
    ValidateGraphIntegrity = true
};

// 套用至核心
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.EnableLogging = graphOptions.EnableLogging;
        options.EnableMetrics = graphOptions.EnableMetrics;
        options.MaxExecutionSteps = graphOptions.MaxExecutionSteps;
        options.ExecutionTimeout = graphOptions.ExecutionTimeout;
        options.ValidateGraphIntegrity = graphOptions.ValidateGraphIntegrity;
    })
    .Build();
```

### 進階日誌記錄配置

配置詳細日誌記錄行為：

```csharp
var loggingOptions = new GraphLoggingOptions
{
    // 基本日誌記錄
    MinimumLevel = LogLevel.Information,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    IncludeTimings = true,
    
    // 上下文和中繼資料
    IncludeNodeMetadata = true,
    IncludeStateSnapshots = false,
    MaxStateDataSize = 2000,
    
    // 敏感資料處理
    LogSensitiveData = false,
    Sanitization = SensitiveDataPolicy.Default,
    
    // 自訂
    CorrelationIdPrefix = "myapp",
    TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff"
};

// 配置類別特定的日誌記錄
loggingOptions.CategoryConfigs["Graph"] = new LogCategoryConfig 
{ 
    Level = LogLevel.Information, 
    Enabled = true 
};
loggingOptions.CategoryConfigs["Node"] = new LogCategoryConfig 
{ 
    Level = LogLevel.Debug, 
    Enabled = true 
};
loggingOptions.CategoryConfigs["Performance"] = new LogCategoryConfig 
{ 
    Level = LogLevel.Information, 
    Enabled = true 
};

// 套用至核心
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.Logging = loggingOptions;
    })
    .Build();
```

### 指標配置

配置效能指標收集：

```csharp
var metricsOptions = GraphMetricsOptions.CreateProductionOptions();
metricsOptions.EnableResourceMonitoring = true;
metricsOptions.ResourceSamplingInterval = TimeSpan.FromSeconds(10);
metricsOptions.MaxSampleHistory = 10000;
metricsOptions.EnableDetailedPathTracking = true;

// 套用至圖表執行器
var graph = new GraphExecutor("ConfiguredGraph", "Graph with custom metrics");
graph.ConfigureMetrics(metricsOptions);
```

## 資料清理和安全

### 基本資料清理

實施自動敏感資料編輯：

```csharp
using SemanticKernel.Graph.Integration;

// 使用預設政策建立清理工具
var sanitizer = new SensitiveDataSanitizer();

// 清理字典資料
System.Collections.Generic.IDictionary<string, object?> sensitiveData = new System.Collections.Generic.Dictionary<string, object?>
{
    ["username"] = "john_doe",
    ["password"] = "secret123",
    ["api_key"] = "sk-1234567890abcdef",
    ["authorization"] = "Bearer sk-1234567890abcdef",
    ["connection_string"] = "Server=localhost;Database=test;User Id=admin;Password=secret;",
    ["normal_data"] = "This is not sensitive"
};

var sanitizedData = sanitizer.Sanitize(sensitiveData);

// 輸出：敏感值已編輯
foreach (var kvp in sanitizedData)
{
    Console.WriteLine($"{kvp.Key}: {kvp.Value}");
}
// username: john_doe
// password: ***REDACTED***
// api_key: ***REDACTED***
// authorization: Bearer ***REDACTED***
// connection_string: ***REDACTED***
// normal_data: This is not sensitive
```

### 自訂清理政策

針對您的領域配置清理行為：

```csharp
var customPolicy = new SensitiveDataPolicy
{
    Enabled = true,
    Level = SanitizationLevel.Basic,
    RedactionText = "[REDACTED]",
    SensitiveKeySubstrings = new[]
    {
        "password", "secret", "token", "key",
        "credential", "auth", "private",
        "ssn", "credit_card", "bank_account"
    },
    MaskAuthorizationBearerToken = true
};

var sanitizer = new SensitiveDataSanitizer(customPolicy);

// 測試自訂政策
System.Collections.Generic.IDictionary<string, object?> testData = new System.Collections.Generic.Dictionary<string, object?>
{
    ["user_ssn"] = "123-45-6789",
    ["credit_card_number"] = "4111-1111-1111-1111",
    ["private_note"] = "Confidential information",
    ["public_info"] = "This is public"
};

var sanitized = sanitizer.Sanitize(testData);
```

### 與日誌記錄整合

將清理套用至日誌記錄輸出：

```csharp
// 配置具有清理功能的日誌記錄
var loggingOptions = new GraphLoggingOptions
{
    LogSensitiveData = false,
    Sanitization = new SensitiveDataPolicy
    {
        Enabled = true,
        Level = SanitizationLevel.Basic,
        RedactionText = "[SENSITIVE]"
    }
};

// 套用至核心（明確輸入字典使用位置可防止 C# 中的模糊多載）
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.Logging = loggingOptions;
    })
    .Build();
```

## 結構化日誌記錄設置

### 基本結構化日誌記錄

啟用具有關聯的結構化日誌記錄：

```csharp
using Microsoft.Extensions.Logging;
using SemanticKernel.Graph.Integration;

// 配置日誌記錄工廠
var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole()
           .AddJsonConsole()  // 啟用結構化日誌記錄
           .SetMinimumLevel(LogLevel.Information);
});

// 建立具有結構化日誌記錄的圖表日誌記錄器
var graphLogger = new SemanticKernelGraphLogger(
    loggerFactory.CreateLogger<SemanticKernelGraphLogger>(),
    new GraphLoggingOptions
    {
        EnableStructuredLogging = true,
        EnableCorrelationIds = true,
        IncludeTimings = true,
        IncludeNodeMetadata = true
    }
);

// 在圖表執行器中使用
var graph = new GraphExecutor("LoggedGraph", "Graph with structured logging");
graph.SetLogger(graphLogger);
```

### 進階日誌記錄配置

配置全面的日誌記錄行為：

```csharp
var advancedLoggingOptions = new GraphLoggingOptions
{
    // 基本設定
    MinimumLevel = LogLevel.Debug,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    IncludeTimings = true,
    
    // 上下文和中繼資料
    IncludeNodeMetadata = true,
    IncludeStateSnapshots = true,
    MaxStateDataSize = 5000,
    
    // 類別特定配置
    CategoryConfigs = new Dictionary<string, LogCategoryConfig>
    {
        ["Graph"] = new LogCategoryConfig 
        { 
            Level = LogLevel.Information, 
            Enabled = true,
            CustomProperties = { ["component"] = "graph-engine" }
        },
        ["Node"] = new LogCategoryConfig 
        { 
            Level = LogLevel.Debug, 
            Enabled = true,
            CustomProperties = { ["component"] = "node-executor" }
        },
        ["Performance"] = new LogCategoryConfig 
        { 
            Level = LogLevel.Information, 
            Enabled = true,
            CustomProperties = { ["component"] = "metrics-collector" }
        },
        ["Error"] = new LogCategoryConfig 
        { 
            Level = LogLevel.Error, 
            Enabled = true,
            CustomProperties = { ["component"] = "error-handler" }
        }
    },
    
    // 節點特定日誌記錄
    NodeConfigs = new Dictionary<string, NodeLoggingConfig>
    {
        ["api_call"] = new NodeLoggingConfig
        {
            Level = LogLevel.Debug,
            LogInputs = true,
            LogOutputs = false,  // 不記錄 API 回應
            LogExecutionTime = true
        },
        ["data_processing"] = new NodeLoggingConfig
        {
            Level = LogLevel.Information,
            LogInputs = false,   // 不記錄大型資料輸入
            LogOutputs = false,  // 不記錄已處理的資料
            LogExecutionTime = true
        }
    }
};

// 套用至核心
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.Logging = advancedLoggingOptions;
    })
    .Build();
```

### 具有關聯的日誌記錄

針對分散式追蹤實施基於關聯的日誌記錄：

```csharp
// 配置關聯 ID 產生
var correlationOptions = new GraphLoggingOptions
{
    EnableCorrelationIds = true,
    CorrelationIdPrefix = "graph-exec",
    EnableStructuredLogging = true,
    IncludeTimings = true
};

// 建立具有關聯的日誌記錄器
var logger = new SemanticKernelGraphLogger(
    loggerFactory.CreateLogger<SemanticKernelGraphLogger>(),
    correlationOptions
);

// 使用關聯執行圖表
var graph = new GraphExecutor("CorrelatedGraph", "Graph with correlation IDs");
graph.SetLogger(logger);

var arguments = new KernelArguments();
arguments.Set("request_id", Guid.NewGuid().ToString());

var result = await graph.ExecuteAsync(kernel, arguments);

// 日誌將包含用於追蹤的關聯 ID
// [2025-08-15 10:30:45.123] [INFO] [graph-exec-abc123] Graph execution started
// [2025-08-15 10:30:45.125] [DEBUG] [graph-exec-abc123] Node 'start' execution started
// [2025-08-15 10:30:45.130] [DEBUG] [graph-exec-abc123] Node 'start' execution completed in 5ms
```

## 政策系統整合

### 成本政策實施

實施自訂成本計算政策：

```csharp
using SemanticKernel.Graph.Integration.Policies;

public class BusinessCostPolicy : ICostPolicy
{
    public double? GetNodeCostWeight(IGraphNode node, GraphState state)
    {
        // 根據商業價值計算成本
        if (state.KernelArguments.TryGetValue("business_value", out var valueObj))
        {
            var businessValue = Convert.ToDouble(valueObj);
            return Math.Max(1.0, businessValue / 100.0);
        }
        
        // 根據資料大小計算成本
        if (state.KernelArguments.TryGetValue("data_size_mb", out var sizeObj))
        {
            var sizeMB = Convert.ToDouble(sizeObj);
            if (sizeMB > 100) return 5.0;
            if (sizeMB > 10) return 2.0;
            return 0.5;
        }
        
        return null; // 使用預設
    }

    public ExecutionPriority? GetNodePriority(IGraphNode node, GraphState state)
    {
        // 根據客戶層級決定優先順序
        if (state.KernelArguments.TryGetValue("customer_tier", out var tierObj))
        {
            return tierObj.ToString() switch
            {
                "premium" => ExecutionPriority.Critical,
                "gold" => ExecutionPriority.High,
                "silver" => ExecutionPriority.Normal,
                _ => ExecutionPriority.Low
            };
        }
        
        return null; // 使用預設
    }
}

// 向圖表註冊政策
var graph = new GraphExecutor("PolicyGraph", "Graph with custom policies");
graph.AddMetadata(nameof(ICostPolicy), new BusinessCostPolicy());
```

### 逾時政策實施

實施自訂逾時政策：

```csharp
public class AdaptiveTimeoutPolicy : ITimeoutPolicy
{
    public TimeSpan? GetNodeTimeout(IGraphNode node, GraphState state)
    {
        // 根據節點類型設置逾時
        if (node.NodeId.Contains("api_call"))
        {
            return TimeSpan.FromSeconds(30); // API 呼叫獲得 30 秒逾時
        }
        
        if (node.NodeId.Contains("data_processing"))
        {
            // 根據資料大小調整逾時
            if (state.KernelArguments.TryGetValue("data_size_mb", out var sizeObj))
            {
                var sizeMB = Convert.ToDouble(sizeObj);
                if (sizeMB > 100) return TimeSpan.FromMinutes(5);
                if (sizeMB > 10) return TimeSpan.FromMinutes(2);
                return TimeSpan.FromSeconds(30);
            }
        }
        
        if (node.NodeId.Contains("ml_inference"))
        {
            return TimeSpan.FromMinutes(10); // ML 操作獲得 10 分鐘逾時
        }
        
        return null; // 使用預設逾時
    }
}

// 註冊逾時政策
graph.AddMetadata(nameof(ITimeoutPolicy), new AdaptiveTimeoutPolicy());
```

### 錯誤處理政策實施

實施自訂錯誤復原政策：

```csharp
public class RetryPolicy : IErrorHandlingPolicy
{
    public bool ShouldRetry(IGraphNode node, Exception exception, GraphExecutionContext context, out TimeSpan? delay)
    {
        delay = null;
        
        // 重試暫時性例外
        if (exception is HttpRequestException || 
            exception is TaskCanceledException ||
            exception.Message.Contains("timeout", StringComparison.OrdinalIgnoreCase))
        {
            // 指數退避：1秒、2秒、4秒、8秒
            var retryCount = context.GraphState.GetRetryCount(node.NodeId);
            if (retryCount < 3)
            {
                delay = TimeSpan.FromSeconds(Math.Pow(2, retryCount));
                return true;
            }
        }
        
        return false;
    }

    public bool ShouldSkip(IGraphNode node, Exception exception, GraphExecutionContext context)
    {
        // 跳過失敗並出現非關鍵錯誤的節點
        if (exception is UnauthorizedAccessException ||
            exception.Message.Contains("permission denied", StringComparison.OrdinalIgnoreCase))
        {
            return true; // 跳過未授權的操作
        }
        
        return false;
    }
}

// 註冊錯誤處理政策
graph.AddMetadata(nameof(IErrorHandlingPolicy), new RetryPolicy());
```

## 進階整合模式

### 模組啟用擴充

有條件地啟用圖表模組：

```csharp
using SemanticKernel.Graph.Extensions;

var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphModules(options =>
    {
        // 根據環境啟用模組
        options.EnableStreaming = true;
        options.EnableCheckpointing = true;
        options.EnableRecovery = true;
        options.EnableHumanInTheLoop = false; // 在生產環境中停用
        options.EnableMultiAgent = true;
    })
    .Build();
```

### 檢查點支援整合

新增檢查點功能：

```csharp
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport()
    .AddCheckpointSupport(options =>
    {
        options.EnableCompression = true;
        options.MaxCacheSize = 1000;
        options.EnableAutoCleanup = true;
        options.AutoCleanupInterval = TimeSpan.FromHours(1);
        options.CompressionLevel = System.IO.Compression.CompressionLevel.Optimal;
    })
    .Build();
```

### 記憶體整合

新增記憶體功能以進行狀態持久化：

```csharp
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport()
    .AddGraphMemory(options =>
    {
        options.EnableVectorSearch = true;
        options.EnableSemanticSearch = true;
        options.MaxMemorySize = 1024 * 1024 * 100; // 100MB
        options.EnablePersistence = true;
        options.PersistencePath = "./graph-memory";
    })
    .Build();
```

## 最佳實務

### 整合配置

* **從簡單開始**：以基本 `AddGraphSupport()` 開始，增量新增功能
* **環境特定**：針對不同的部署環境使用預設配置
* **依賴項管理**：在建置核心之前確保所有必需的服務都已註冊
* **配置驗證**：在啟動過程中早期驗證配置選項

### 安全和資料處理

* **始終清理**：為所有生產部署啟用資料清理
* **自訂政策**：實施特定領域的清理政策
* **審計日誌記錄**：記錄所有政策決定和資料存取以符合規範
* **定期審查**：定期檢視和更新安全政策

### 日誌記錄和可觀測性

* **結構化日誌記錄**：使用結構化日誌記錄以提升可搜尋性和分析效果
* **關聯 ID**：啟用關聯 ID 以進行分散式追蹤
* **效能監視**：在日誌中包含執行時機以進行效能分析
* **日誌層級**：針對不同的環境配置適當的日誌層級

### 政策管理

* **商業邏輯**：實施反映商業需求的政策
* **效能影響**：考慮複雜政策邏輯的效能影響
* **測試**：使用各種情景和邊界案例徹底測試政策
* **文件**：記錄政策行為和配置選項

## 疑難排解

### 常見整合問題

**服務註冊失敗**：確保在建置核心之前所有必需的服務都已註冊。

**配置驗證錯誤**：檢查所有配置選項是否具有有效值。

**政策執行錯誤**：驗證政策實施以正常處理所有邊界案例。

**日誌記錄配置問題**：確保日誌記錄提供者已正確配置且可存取。

### 效能最佳化

```csharp
// 針對高輸送量情景最佳化
var optimizedOptions = new GraphOptions
{
    EnableLogging = true,
    EnableMetrics = true,
    EnablePlanCompilation = true,
    ValidateGraphIntegrity = false, // 停用以提升效能
    MaxExecutionSteps = 5000
};

// 使用效能最佳化的日誌記錄
var perfLoggingOptions = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Warning, // 減少日誌量
    IncludeStateSnapshots = false,   // 停用昂貴的操作
    MaxStateDataSize = 500,          // 限制資料大小
    EnableStructuredLogging = true   // 保持結構化日誌記錄
};
```

## 另請參閱

* [資源治理和並行](resource-governance-and-concurrency.md) - 管理資源配置和執行政策
* [指標和可觀測性](metrics-and-observability.md) - 監視和效能分析
* [偵錯和檢查](debug-and-inspection.md) - 偵錯和檢查功能
* [範例](../../examples/) - 整合和擴充的實用範例

## 執行文件化範例

若要在本機執行本指南中使用的範例，請建置並執行 Examples 專案，並傳遞範例名稱 `integration-and-extensions`：

```bash
dotnet build ../semantic-kernel-graph/src/SemanticKernel.Graph.Examples/SemanticKernel.Graph.Examples.csproj
dotnet run --project ../semantic-kernel-graph/src/SemanticKernel.Graph.Examples/SemanticKernel.Graph.Examples.csproj --example integration-and-extensions
```

該範例列印已清理的承載，展示 `SensitiveDataSanitizer` 如何編輯敏感欄位。
