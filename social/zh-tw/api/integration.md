# 整合 APIs 參考

本參考文件記錄 SemanticKernel.Graph 中的整合 APIs，提供日誌記錄、登錄管理、資料清理和輔助服務，用於生產就緒的 Graph 應用程式。

## SemanticKernelGraphLogger

實作 `IGraphLogger` 的類別，與 Microsoft.Extensions.Logging 整合，並為 Graph 執行事件提供結構化日誌記錄，具有進階設定選項。

### 功能

* 與 Microsoft.Extensions.Logging 整合
* 具有關聯 ID 的結構化日誌記錄
* 可設定的資料清理
* 類別和 Node 特定的日誌記錄
* 效能計時整合
* 狀態變化追蹤
* 具有上下文的例外日誌記錄

### 建構式

```csharp
public SemanticKernelGraphLogger(ILogger? logger, GraphOptions options)
```

### 方法

#### Graph 執行日誌記錄

```csharp
public void LogGraphExecutionStarted(string graphId, string graphName, string executionId, GraphState initialState)
public void LogGraphExecutionCompleted(string graphId, string executionId, GraphState finalState, TimeSpan totalExecutionTime)
public void LogGraphExecutionFailed(string graphId, string executionId, Exception exception, GraphState stateAtFailure)
```

#### Node 執行日誌記錄

```csharp
public void LogNodeExecution(string nodeId, string executionId, NodeExecutionInfo nodeInfo)
public void LogNodeExecutionStarted(string nodeId, string executionId, string nodeName, string nodeType)
public void LogNodeExecutionCompleted(string nodeId, string executionId, object? outputResult, TimeSpan executionTime)
public void LogNodeExecutionFailed(string nodeId, string executionId, Exception exception, TimeSpan executionTime)
```

#### 狀態和上下文日誌記錄

```csharp
public void LogStateChange(string executionId, StateChangeInfo stateChange)
public void LogCorrelatedEvent(string executionId, string category, string message, LogLevel level, object? data = null)
public IDisposable BeginExecutionScope(string executionId, string graphId)
```

#### 工具方法

```csharp
public bool IsEnabled(string category, LogLevel level)
public NodeLoggingConfig GetNodeConfig(string nodeId, string nodeType)
```

### 屬性

* `IsDisposed`：取得記錄器是否已被釋放

## IGraphRegistry

登錄介面，用於管理具名 `GraphExecutor` 執行個體，以啟用遠端執行和探索。

### 功能

* Graph 登錄和生命週期管理
* 執行緒安全的並行存取
* 遠端執行支援
* 探索和中繼資料存取

### 方法

```csharp
Task<bool> RegisterAsync(GraphExecutor executor)
Task<bool> UnregisterAsync(string graphName)
Task<GraphExecutor?> GetAsync(string graphName)
Task<IList<RegisteredGraphInfo>> ListAsync()
Task<bool> ExistsAsync(string graphName)
Task<int> GetRegisteredCountAsync()
```

### GraphRegistry 實作

`IGraphRegistry` 的預設記憶體實作，適合單一程序裝載案例。

#### 建構式

```csharp
public GraphRegistry(ILogger<GraphRegistry>? logger = null)
```

#### 其他方法

```csharp
public Task<RegisteredGraphInfo?> GetInfoAsync(string graphName)
public Task<IList<RegisteredGraphInfo>> GetInfosAsync()
public Task<bool> ClearAsync()
```

## IToolRegistry

登錄介面，用於可公開為 Graph Node 的外部工具。

### 功能

* 帶中繼資料的工具登錄
* 以工廠為基礎的 Node 建立
* 搜尋和探索功能
* 生命週期管理

### 方法

```csharp
Task<bool> RegisterAsync(ToolMetadata metadata, Func<IServiceProvider, IGraphNode> factory)
Task<bool> UnregisterAsync(string toolId)
Task<ToolMetadata?> GetAsync(string toolId)
Task<IGraphNode?> CreateNodeAsync(string toolId, IServiceProvider serviceProvider)
Task<IList<ToolMetadata>> SearchAsync(ToolSearchCriteria criteria)
Task<IList<ToolMetadata>> ListAsync()
```

### ToolRegistry 實作

具有執行緒安全操作的 `IToolRegistry` 記憶體實作。

#### 建構式

```csharp
public ToolRegistry(ILogger<ToolRegistry>? logger = null)
```

## IPluginRegistry

外掛程式登錄操作的介面，提供探索、登錄和生命週期管理。

### 功能

* 帶中繼資料的外掛程式登錄
* 以工廠為基礎的具現化
* 搜尋和篩選功能
* 統計和監視

### 方法

```csharp
Task<PluginRegistrationResult> RegisterPluginAsync(PluginMetadata metadata, Func<IServiceProvider, IGraphNode> factory)
Task<bool> UnregisterPluginAsync(string pluginId)
Task<PluginMetadata?> GetPluginMetadataAsync(string pluginId)
Task<IGraphNode?> CreatePluginInstanceAsync(string pluginId, IServiceProvider serviceProvider)
Task<IList<PluginMetadata>> SearchPluginsAsync(PluginSearchCriteria criteria)
Task<IList<PluginMetadata>> GetAllPluginsAsync()
Task<PluginStatistics?> GetPluginStatisticsAsync(string pluginId)
```

### PluginRegistry 實作

具有定期清理和統計追蹤的執行緒安全記憶體實作。

#### 建構式

```csharp
public PluginRegistry(PluginRegistryOptions? options = null, ILogger<PluginRegistry>? logger = null)
```

## SensitiveDataSanitizer

用於在日誌、事件和匯出中清理敏感資料的工具，具有可設定的原則。

### 功能

* 自動敏感鍵偵測
* 可設定的清理等級
* JSON 元素處理
* 授權令牌遮罩
* 自訂修訂文字

### 建構式

```csharp
public SensitiveDataSanitizer(SensitiveDataPolicy policy)
```

### 方法

#### 資料清理

```csharp
public object? Sanitize(object? value, string? keyHint = null)
public IDictionary<string, object?> Sanitize(IDictionary<string, object?> data)
public IDictionary<string, object?> Sanitize(IReadOnlyDictionary<string, object?> data)
```

#### 工具方法

```csharp
public bool IsSensitiveKey(string key)
public string GetRedactionText()
```

## SensitiveDataPolicy

日誌和匯出中敏感資料清理的設定原則。

### 屬性

```csharp
public bool Enabled { get; set; } = true                                    // 啟用清理
public SanitizationLevel Level { get; set; } = SanitizationLevel.Basic      // 清理積極性
public string RedactionText { get; set; } = "***REDACTED***"               // 取代文字
public string[] SensitiveKeySubstrings { get; set; } = DefaultKeySubstrings // 敏感鍵圖樣
public bool MaskAuthorizationBearerToken { get; set; } = true               // 遮罩授權令牌
```

### 靜態屬性

```csharp
public static string[] DefaultKeySubstrings { get; }                       // 預設敏感圖樣
public static SensitiveDataPolicy Default { get; }                         // 預設原則執行個體
```

## SanitizationLevel 列舉

控制清理積極性的列舉。

```csharp
public enum SanitizationLevel
{
    None = 0,      // 不套用清理
    Basic = 1,     // 僅在鍵暗示敏感性時進行修訂
    Strict = 2     // 無論鍵為何，修訂所有字串值
}
```

## GraphLoggingOptions

Graph 執行的進階日誌記錄設定，對行為和結構化資料進行細緻控制。

### 屬性

#### 基本設定

```csharp
public LogLevel MinimumLevel { get; set; } = LogLevel.Information          // 最小日誌等級
public bool EnableStructuredLogging { get; set; } = true                   // 啟用結構化日誌記錄
public bool EnableCorrelationIds { get; set; } = true                      // 啟用關聯 ID
public bool IncludeTimings { get; set; } = true                            // 包括執行計時
public bool IncludeNodeMetadata { get; set; } = true                       // 包括 Node 中繼資料
public bool IncludeStateSnapshots { get; set; } = false                    // 包括狀態快照
public int MaxStateDataSize { get; set; } = 2000                           // 最大狀態資料大小
```

#### 資料處理

```csharp
public bool LogSensitiveData { get; set; } = false                         // 記錄敏感資料
public SensitiveDataPolicy Sanitization { get; set; } = Default            // 清理原則
public string? CorrelationIdPrefix { get; set; }                           // 關聯 ID 前置詞
public string TimestampFormat { get; set; } = "yyyy-MM-dd HH:mm:ss.fff"    // 時間戳記格式
```

#### 類別和 Node 設定

```csharp
public Dictionary<string, LogCategoryConfig> CategoryConfigs { get; set; }  // 類別設定
public Dictionary<string, NodeLoggingConfig> NodeConfigs { get; set; }      // Node 設定
```

## LogCategoryConfig

特定事件類別的日誌記錄設定。

### 屬性

```csharp
public bool Enabled { get; set; } = true                                   // 啟用類別日誌記錄
public LogLevel Level { get; set; } = LogLevel.Information                 // 最小日誌等級
public Dictionary<string, object> CustomProperties { get; set; } = new()    // 自訂屬性
```

## NodeLoggingConfig

特定 Node 的日誌記錄設定，擴充 `LogCategoryConfig`。

### 屬性

```csharp
public bool LogInputs { get; set; } = true                                 // 記錄輸入參數
public bool LogOutputs { get; set; } = true                                // 記錄輸出結果
public bool LogTiming { get; set; } = true                                 // 記錄執行計時
public bool LogStateChanges { get; set; } = true                           // 記錄狀態變化
public int MaxDataSize { get; set; } = 1000                                // 要記錄的最大資料大小
```

## HitlAuditService

訂閱人類互動事件並記錄稽核項目的服務，用於合規和檢查。

### 功能

* 自動稽核線索產生
* 敏感資料清理
* 記憶服務整合
* 最近稽核快取

### 建構式

```csharp
public HitlAuditService(
    IHumanInteractionStore store,
    IGraphMemoryService? memory,
    ILogger<HitlAuditService>? logger = null)
```

### 方法

```csharp
public Task RecordAuditAsync(string action, string? requestId = null, string? executionId = null, 
    string? nodeId = null, ApprovalStatus? status = null, string? userId = null, string? comments = null)
public Task<IList<AuditRecord>> GetRecentAuditsAsync(int count = 100)
public Task<IList<AuditRecord>> SearchAuditsAsync(AuditSearchCriteria criteria)
```

## 使用範例

### 基本記錄器設定

```csharp
using Microsoft.Extensions.Logging;
using SemanticKernel.Graph.Integration;

// 建立記錄器工廠
var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole()
           .AddJsonConsole()
           .SetMinimumLevel(LogLevel.Information);
});

// 建立 Graph 記錄器
var graphLogger = new SemanticKernelGraphLogger(
    loggerFactory.CreateLogger<SemanticKernelGraphLogger>(),
    new GraphOptions
    {
        EnableLogging = true,
        Logging = new GraphLoggingOptions
        {
            MinimumLevel = LogLevel.Information,
            EnableStructuredLogging = true,
            EnableCorrelationIds = true,
            IncludeTimings = true
        }
    }
);

// 在 Graph 執行器中使用 (透過建構式傳遞記錄器)
var graph = new GraphExecutor("LoggedGraph", "Graph with structured logging", graphLogger);
```

### 進階日誌記錄設定

```csharp
var loggingOptions = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Debug,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    IncludeTimings = true,
    IncludeNodeMetadata = true,
    MaxStateDataSize = 1000,
    LogSensitiveData = false,
    Sanitization = new SensitiveDataPolicy
    {
        Enabled = true,
        Level = SanitizationLevel.Basic,
        RedactionText = "[SENSITIVE]",
        MaskAuthorizationBearerToken = true
    }
};

// 設定類別特定的日誌記錄
loggingOptions.CategoryConfigs["Graph"] = new LogCategoryConfig 
{ 
    Level = LogLevel.Information, 
    Enabled = true,
    CustomProperties = { ["component"] = "graph-engine" }
};

loggingOptions.CategoryConfigs["Node"] = new LogCategoryConfig 
{ 
    Level = LogLevel.Debug, 
    Enabled = true,
    CustomProperties = { ["component"] = "node-executor" }
};

// 設定 Node 特定的日誌記錄
loggingOptions.NodeConfigs["api_call"] = new NodeLoggingConfig
{
    Level = LogLevel.Debug,
    LogInputs = true,
    LogOutputs = false,  // 不記錄 API 回應
    LogTiming = true,
    MaxDataSize = 500
};
```

### Graph 登錄使用

```csharp
using SemanticKernel.Graph.Integration;

// 建立登錄
var registry = new GraphRegistry(logger);

// 登錄 Graph
await registry.RegisterAsync(graphExecutor1);
await registry.RegisterAsync(graphExecutor2);

// 列出已登錄的 Graph
var graphs = await registry.ListAsync();
foreach (var graphInfo in graphs)
{
    Console.WriteLine($"Graph: {graphInfo.Name} ({graphInfo.NodeCount} nodes)");
}

// 取得特定 Graph
var graph = await registry.GetAsync("MyGraph");
if (graph != null)
{
    // 執行 Graph
    var result = await graph.ExecuteAsync(kernel, arguments);
}
```

### 工具登錄整合

```csharp
using SemanticKernel.Graph.Integration;

// 建立工具登錄
var toolRegistry = new ToolRegistry(logger);

// 登錄外部工具
var toolMetadata = new ToolMetadata
{
    Id = "weather_api",
    Name = "Weather API",
    Description = "Get current weather information",
    Type = ToolType.Rest
};

await toolRegistry.RegisterAsync(toolMetadata, serviceProvider =>
{
    return new RestToolGraphNode("weather_api", "https://api.weather.com/current");
});

// 建立工具 Node
var toolNode = await toolRegistry.CreateNodeAsync("weather_api", serviceProvider);
if (toolNode != null)
{
    // 在 Graph 中使用工具 Node
    graph.AddNode(toolNode);
}
```

### 資料清理

```csharp
using SemanticKernel.Graph.Integration;

// 使用自訂原則建立清理器
var policy = new SensitiveDataPolicy
{
    Enabled = true,
    Level = SanitizationLevel.Basic,
    RedactionText = "***REDACTED***",
    MaskAuthorizationBearerToken = true,
    SensitiveKeySubstrings = new[]
    {
        "password", "secret", "token", "api_key",
        "credit_card", "ssn", "social_security"
    }
};

var sanitizer = new SensitiveDataSanitizer(policy);

// 清理敏感資料
var sensitiveData = new Dictionary<string, object>
{
    ["username"] = "john_doe",
    ["password"] = "secret123",
    ["api_key"] = "sk-1234567890abcdef",
    ["authorization"] = "Bearer sk-1234567890abcdef"
};

var sanitized = sanitizer.Sanitize(sensitiveData);
// 結果：password 和 api_key 值被修訂，authorization 令牌被遮罩
```

### 外掛程式登錄管理

```csharp
using SemanticKernel.Graph.Integration;

// 建立外掛程式登錄
var pluginRegistry = new PluginRegistry(new PluginRegistryOptions
{
    MaxPlugins = 1000,
    EnablePeriodicCleanup = true,
    CleanupInterval = TimeSpan.FromHours(24)
}, logger);

// 登錄外掛程式
var pluginMetadata = new PluginMetadata
{
    Id = "data_processor",
    Name = "Data Processing Plugin",
    Description = "Process and transform data",
    Version = "2.1.0",
    Author = "Data Team",
    Tags = new[] { "data", "processing", "etl" }
};

var result = await pluginRegistry.RegisterPluginAsync(pluginMetadata, serviceProvider =>
{
    return new DataProcessingGraphNode();
});

if (result.IsSuccess)
{
    Console.WriteLine($"Plugin registered: {result.PluginId}");
}
else
{
    Console.WriteLine($"Registration failed: {result.ErrorMessage}");
}

// 搜尋外掛程式
var searchCriteria = new PluginSearchCriteria
{
    Tags = new[] { "data" },
    MinVersion = "2.0.0"
};

var matchingPlugins = await pluginRegistry.SearchPluginsAsync(searchCriteria);
```

## 另請參閱

* [整合和擴充指南](../how-to/integration-and-extensions.md) - 如何設定和使用整合功能
* [安全和資料指南](../how-to/security-and-data.md) - 資料清理和安全最佳實務
* [計量和可觀測性指南](../how-to/metrics-and-observability.md) - 日誌記錄設定和可觀測性
* [擴充和選項參考](./extensions-and-options.md) - Graph 選項和設定
* [串流 APIs 參考](./streaming.md) - 即時執行監視
* [檢查和可視化參考](./inspection-visualization.md) - 偵錯和檢查功能
