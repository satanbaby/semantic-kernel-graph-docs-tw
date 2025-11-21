# 整合與擴展

SemanticKernel.Graph 中的整合與擴展提供與 Semantic Kernel 的無縫整合以及用於生產部署的全面配置選項。本指南涵蓋 kernel builder 擴展、配置選項、資料清理、結構化記錄和策略管理。

## 您將學到的內容

* 如何將 Graph 功能與現有的 Semantic Kernel 實例整合
* 為不同環境配置全面的 Graph 選項
* 實現資料清理和安全策略
* 設定具有關聯和上下文的結構化記錄
* 管理成本、逾時和錯誤處理的策略
* 生產整合和部署的最佳實踐

## 概念與技術

**KernelBuilderExtensions**：Fluent API 擴展，支援零配置 Graph 設定以及與現有 Semantic Kernel 實例的整合。

**GraphOptions**：Graph 功能的全面配置選項，包括記錄、指標、驗證和執行邊界。

**SensitiveDataSanitizer**：用於自動從記錄、匯出和除錯輸出中移除敏感資訊的公用程式。

**結構化記錄**：具有關聯 ID、執行上下文和結構化資料的增強記錄，以提高可觀測性。

**策略系統**：用於成本管理、逾時處理、錯誤恢復和業務邏輯整合的可插入策略。

## 先決條件

* [第一個 Graph 教學課程](../first-graph-5-minutes.md)已完成
* 對 Semantic Kernel 概念的基本理解
* 熟悉相依性注入和配置
* 瞭解記錄和安全最佳實踐

## Kernel Builder 整合

### 基本 Graph 支援整合

將 Graph 功能新增至現有的 Semantic Kernel 實例：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;

// 建立具有 Graph 支援的 kernel
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport()  // 使用預設配置啟用
    .Build();
```

### 自訂 Graph 整合

在整合期間配置 Graph 選項：

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
        
        // 配置記錄選項
        options.Logging.EnableStructuredLogging = true;
        options.Logging.EnableCorrelationIds = true;
        options.Logging.IncludeTimings = true;
        options.Logging.LogSensitiveData = false;
    })
    .Build();
```

### 環境特定的整合

使用預設配置處理不同的環境：

```csharp
// 開發環境
var devKernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupportForDebugging()  // 增強的記錄、詳細的指標
    .Build();

// 生產環境
var prodKernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupportForProduction()  // 最佳化的記錄、生產指標
    .Build();

// 高效能環境
var perfKernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupportForPerformance()  // 最少的記錄、效能焦點
    .Build();
```

### 含所有功能的完整整合

啟用全面的 Graph 功能：

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

## Graph 選項配置

### 核心 Graph 選項

配置基本 Graph 行為：

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

// 套用到 kernel
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

### 進階記錄配置

配置詳細的記錄行為：

```csharp
var loggingOptions = new GraphLoggingOptions
{
    // 基本記錄
    MinimumLevel = LogLevel.Information,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    IncludeTimings = true,
    
    // 上下文與中繼資料
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

// 配置分類特定的記錄
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

// 套用到 kernel
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.Logging = loggingOptions;
    })
    .Build();
```

### 指標配置

配置效能指標的收集：

```csharp
var metricsOptions = GraphMetricsOptions.CreateProductionOptions();
metricsOptions.EnableResourceMonitoring = true;
metricsOptions.ResourceSamplingInterval = TimeSpan.FromSeconds(10);
metricsOptions.MaxSampleHistory = 10000;
metricsOptions.EnableDetailedPathTracking = true;

// 套用到 Graph 執行器
var graph = new GraphExecutor("ConfiguredGraph", "Graph with custom metrics");
graph.ConfigureMetrics(metricsOptions);
```

## 資料清理和安全

### 基本資料清理

實現自動敏感資料移除：

```csharp
using SemanticKernel.Graph.Integration;

// 使用預設原則建立清理工具
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

// 輸出：敏感值被移除
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

### 自訂清理原則

為您的領域配置清理行為：

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

// 測試自訂原則
System.Collections.Generic.IDictionary<string, object?> testData = new System.Collections.Generic.Dictionary<string, object?>
{
    ["user_ssn"] = "123-45-6789",
    ["credit_card_number"] = "4111-1111-1111-1111",
    ["private_note"] = "Confidential information",
    ["public_info"] = "This is public"
};

var sanitized = sanitizer.Sanitize(testData);
```

### 與記錄的整合

將清理套用至記錄輸出：

```csharp
// 使用清理配置記錄
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

// 套用到 kernel (當使用字典時，明確輸入可防止 C# 中的模糊多載)
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.Logging = loggingOptions;
    })
    .Build();
```

## 結構化記錄設定

### 基本結構化記錄

啟用具有關聯的結構化記錄：

```csharp
using Microsoft.Extensions.Logging;
using SemanticKernel.Graph.Integration;

// 配置記錄工廠
var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole()
           .AddJsonConsole()  // 啟用結構化記錄
           .SetMinimumLevel(LogLevel.Information);
});

// 建立具有結構化記錄的 Graph 記錄器
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

// 在 Graph 執行器中使用
var graph = new GraphExecutor("LoggedGraph", "Graph with structured logging");
graph.SetLogger(graphLogger);
```

### 進階記錄配置

配置全面的記錄行為：

```csharp
var advancedLoggingOptions = new GraphLoggingOptions
{
    // 基本設定
    MinimumLevel = LogLevel.Debug,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    IncludeTimings = true,
    
    // 上下文與中繼資料
    IncludeNodeMetadata = true,
    IncludeStateSnapshots = true,
    MaxStateDataSize = 5000,
    
    // 分類特定的配置
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
    
    // Node 特定的記錄
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

// 套用到 kernel
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.Logging = advancedLoggingOptions;
    })
    .Build();
```

### 具有關聯的記錄

實現以關聯為基礎的記錄以進行分散式追蹤：

```csharp
// 配置關聯 ID 生成
var correlationOptions = new GraphLoggingOptions
{
    EnableCorrelationIds = true,
    CorrelationIdPrefix = "graph-exec",
    EnableStructuredLogging = true,
    IncludeTimings = true
};

// 使用關聯建立記錄器
var logger = new SemanticKernelGraphLogger(
    loggerFactory.CreateLogger<SemanticKernelGraphLogger>(),
    correlationOptions
);

// 使用關聯執行 Graph
var graph = new GraphExecutor("CorrelatedGraph", "Graph with correlation IDs");
graph.SetLogger(logger);

var arguments = new KernelArguments();
arguments.Set("request_id", Guid.NewGuid().ToString());

var result = await graph.ExecuteAsync(kernel, arguments);

// 記錄將包含用於追蹤的關聯 ID
// [2025-08-15 10:30:45.123] [INFO] [graph-exec-abc123] Graph execution started
// [2025-08-15 10:30:45.125] [DEBUG] [graph-exec-abc123] Node 'start' execution started
// [2025-08-15 10:30:45.130] [DEBUG] [graph-exec-abc123] Node 'start' execution completed in 5ms
```

## 策略系統整合

### 成本策略實現

實現自訂成本計算策略：

```csharp
using SemanticKernel.Graph.Integration.Policies;

public class BusinessCostPolicy : ICostPolicy
{
    public double? GetNodeCostWeight(IGraphNode node, GraphState state)
    {
        // 根據業務價值計算成本
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
        
        return null; // 使用預設值
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
        
        return null; // 使用預設值
    }
}

// 將策略註冊到 Graph
var graph = new GraphExecutor("PolicyGraph", "Graph with custom policies");
graph.AddMetadata(nameof(ICostPolicy), new BusinessCostPolicy());
```

### 逾時策略實現

實現自訂逾時策略：

```csharp
public class AdaptiveTimeoutPolicy : ITimeoutPolicy
{
    public TimeSpan? GetNodeTimeout(IGraphNode node, GraphState state)
    {
        // 根據 Node 類型設定逾時
        if (node.NodeId.Contains("api_call"))
        {
            return TimeSpan.FromSeconds(30); // API 呼叫取得 30 秒逾時
        }
        
        if (node.NodeId.Contains("data_processing"))
        {
            // 根據資料大小的逾時
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
            return TimeSpan.FromMinutes(10); // ML 作業取得 10 分鐘逾時
        }
        
        return null; // 使用預設逾時
    }
}

// 註冊逾時策略
graph.AddMetadata(nameof(ITimeoutPolicy), new AdaptiveTimeoutPolicy());
```

### 錯誤處理策略實現

實現自訂錯誤恢復策略：

```csharp
public class RetryPolicy : IErrorHandlingPolicy
{
    public bool ShouldRetry(IGraphNode node, Exception exception, GraphExecutionContext context, out TimeSpan? delay)
    {
        delay = null;
        
        // 重試暫時性例外狀況
        if (exception is HttpRequestException || 
            exception is TaskCanceledException ||
            exception.Message.Contains("timeout", StringComparison.OrdinalIgnoreCase))
        {
            // 指數退避：1s、2s、4s、8s
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
        // 略過因非關鍵錯誤而失敗的 Node
        if (exception is UnauthorizedAccessException ||
            exception.Message.Contains("permission denied", StringComparison.OrdinalIgnoreCase))
        {
            return true; // 略過未授權的作業
        }
        
        return false;
    }
}

// 註冊錯誤處理策略
graph.AddMetadata(nameof(IErrorHandlingPolicy), new RetryPolicy());
```

## 進階整合模式

### 模組啟用擴展

有條件地啟用 Graph 模組：

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

## 最佳實踐

### 整合配置

* **簡單開始**：以基本的 `AddGraphSupport()` 開始，並逐步新增功能
* **環境特定**：針對不同的部署環境使用預設配置
* **相依性管理**：確保在建立 kernel 之前註冊所有必需的服務
* **配置驗證**：在啟動程序的早期驗證配置選項

### 安全與資料處理

* **始終清理**：針對所有生產部署啟用資料清理
* **自訂原則**：實現特定領域的清理原則
* **稽核記錄**：記錄所有原則決定和資料存取以進行合規性稽核
* **定期檢查**：定期檢查和更新安全原則

### 記錄和可觀測性

* **結構化記錄**：使用結構化記錄以獲得更好的可搜尋性和分析
* **關聯 ID**：啟用關聯 ID 以進行分散式追蹤
* **效能監控**：在記錄中包含執行計時以進行效能分析
* **記錄層級**：為不同的環境配置適當的記錄層級

### 策略管理

* **業務邏輯**：實現反映您的業務需求的策略
* **效能影響**：考慮複雜策略邏輯的效能影響
* **測試**：使用各種情景和邊界案例徹底測試策略
* **文件**：記錄策略行為和配置選項

## 疑難排解

### 常見整合問題

**服務註冊失敗**：確保在建立 kernel 之前註冊所有必需的服務。

**配置驗證錯誤**：檢查所有配置選項是否具有有效值。

**策略執行錯誤**：驗證策略實現是否妥善處理所有邊界案例。

**記錄配置問題**：確保記錄提供者已正確配置且可存取。

### 效能最佳化

```csharp
// 針對高輸送量情景進行最佳化
var optimizedOptions = new GraphOptions
{
    EnableLogging = true,
    EnableMetrics = true,
    EnablePlanCompilation = true,
    ValidateGraphIntegrity = false, // 為了效能停用
    MaxExecutionSteps = 5000
};

// 使用效能最佳化的記錄
var perfLoggingOptions = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Warning, // 降低記錄量
    IncludeStateSnapshots = false,   // 停用成本高昂的作業
    MaxStateDataSize = 500,          // 限制資料大小
    EnableStructuredLogging = true   // 保留結構化記錄
};
```

## 另請參閱

* [資源治理和並行](resource-governance-and-concurrency.md) - 管理資源分配和執行策略
* [指標和可觀測性](metrics-and-observability.md) - 監控和效能分析
* [除錯和檢查](debug-and-inspection.md) - 除錯和檢查功能
* [範例](../../examples/) - 整合與擴展的實際範例

## 執行文件中的範例

若要在本機執行本指南中使用的範例，請建立並執行 Examples 專案，並傳遞範例名稱 `integration-and-extensions`：

```bash
dotnet build ../semantic-kernel-graph/src/SemanticKernel.Graph.Examples/SemanticKernel.Graph.Examples.csproj
dotnet run --project ../semantic-kernel-graph/src/SemanticKernel.Graph.Examples/SemanticKernel.Graph.Examples.csproj --example integration-and-extensions
```

此範例列印已清理的承載，示範 `SensitiveDataSanitizer` 如何移除敏感欄位。
