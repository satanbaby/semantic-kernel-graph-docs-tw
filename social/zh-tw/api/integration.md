# 整合 API 參考

本參考文檔記錄了 SemanticKernel.Graph 中的整合 API，這些 API 為生產就緒的圖應用程序提供日誌記錄、註冊表管理、資料清潔和輔助服務。

## SemanticKernelGraphLogger

實現 `IGraphLogger` 的日誌記錄器，與 Microsoft.Extensions.Logging 整合，並為圖執行事件提供具有進階設定選項的結構化日誌記錄。

### 特色

* 與 Microsoft.Extensions.Logging 整合
* 具有相關 ID 的結構化日誌記錄
* 可配置的資料清潔
* 分類和節點特定日誌記錄
* 效能計時整合
* 狀態變更追蹤
* 帶有上下文的例外日誌記錄

### 建構函數

```csharp
public SemanticKernelGraphLogger(ILogger? logger, GraphOptions options)
```

### 方法

#### 圖執行日誌記錄

```csharp
public void LogGraphExecutionStarted(string graphId, string graphName, string executionId, GraphState initialState)
public void LogGraphExecutionCompleted(string graphId, string executionId, GraphState finalState, TimeSpan totalExecutionTime)
public void LogGraphExecutionFailed(string graphId, string executionId, Exception exception, GraphState stateAtFailure)
```

#### 節點執行日誌記錄

```csharp
public void LogNodeExecution(string nodeId, string executionId, NodeExecutionInfo nodeInfo)
public void LogNodeExecutionStarted(string nodeId, string executionId, string nodeName, string nodeType)
public void LogNodeExecutionCompleted(string nodeId, string executionId, object? outputResult, TimeSpan executionTime)
public void LogNodeExecutionFailed(string nodeId, string executionId, Exception exception, TimeSpan executionTime)
```

#### 狀態和內容日誌記錄

```csharp
public void LogStateChange(string executionId, StateChangeInfo stateChange)
public void LogCorrelatedEvent(string executionId, string category, string message, LogLevel level, object? data = null)
public IDisposable BeginExecutionScope(string executionId, string graphId)
```

#### 公用程式方法

```csharp
public bool IsEnabled(string category, LogLevel level)
public NodeLoggingConfig GetNodeConfig(string nodeId, string nodeType)
```

### 屬性

* `IsDisposed`：取得日誌記錄器是否已被回收

## IGraphRegistry

用於管理具名 `GraphExecutor` 執行個體的註冊表介面，以啟用遠端執行和發現。

### 特色

* 圖註冊和生命週期管理
* 執行緒安全的並行存取
* 遠端執行支援
* 發現和中繼資料存取

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

適合單一進程託管情境的預設記憶體內實作 `IGraphRegistry`。

#### 建構函數

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

用於外部工具的註冊表介面，這些工具可以公開為圖節點。

### 特色

* 使用中繼資料進行工具註冊
* 基於工廠的節點建立
* 搜尋和發現功能
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

具有執行緒安全操作的記憶體內實作 `IToolRegistry`。

#### 建構函數

```csharp
public ToolRegistry(ILogger<ToolRegistry>? logger = null)
```

## IPluginRegistry

提供發現、註冊和生命週期管理的外掛程式註冊表介面。

### 特色

* 使用中繼資料進行外掛程式註冊
* 基於工廠的例項化
* 搜尋和篩選功能
* 統計資訊和監控

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

具有定期清理和統計資訊追蹤的執行緒安全記憶體內實作。

#### 建構函數

```csharp
public PluginRegistry(PluginRegistryOptions? options = null, ILogger<PluginRegistry>? logger = null)
```

## SensitiveDataSanitizer

用於使用可配置原則清潔日誌、事件和匯出中的敏感資料的公用程式。

### 特色

* 自動敏感金鑰偵測
* 可配置的清潔等級
* JSON 元素處理
* 授權令牌遮罩
* 自訂編修文字

### 建構函數

```csharp
public SensitiveDataSanitizer(SensitiveDataPolicy policy)
```

### 方法

#### 資料清潔

```csharp
public object? Sanitize(object? value, string? keyHint = null)
public IDictionary<string, object?> Sanitize(IDictionary<string, object?> data)
public IDictionary<string, object?> Sanitize(IReadOnlyDictionary<string, object?> data)
```

#### 公用程式方法

```csharp
public bool IsSensitiveKey(string key)
public string GetRedactionText()
```

## SensitiveDataPolicy

日誌和匯出中敏感資料清潔的設定原則。

### 屬性

```csharp
public bool Enabled { get; set; } = true                                    // 啟用清潔
public SanitizationLevel Level { get; set; } = SanitizationLevel.Basic      // 清潔侵略性程度
public string RedactionText { get; set; } = "***REDACTED***"               // 替換文字
public string[] SensitiveKeySubstrings { get; set; } = DefaultKeySubstrings // 敏感金鑰模式
public bool MaskAuthorizationBearerToken { get; set; } = true               // 遮罩驗證令牌
```

### 靜態屬性

```csharp
public static string[] DefaultKeySubstrings { get; }                       // 預設敏感模式
public static SensitiveDataPolicy Default { get; }                         // 預設原則執行個體
```

## SanitizationLevel 列舉

控制清潔侵略性程度的列舉。

```csharp
public enum SanitizationLevel
{
    None = 0,      // 不應用清潔
    Basic = 1,     // 僅在金鑰建議敏感時編修
    Strict = 2     // 無論金鑰如何編修所有字串值
}
```

## GraphLoggingOptions

圖執行的進階日誌記錄設定，具有對行為和結構化資料的精細控制。

### 屬性

#### 基本設定

```csharp
public LogLevel MinimumLevel { get; set; } = LogLevel.Information          // 最小日誌等級
public bool EnableStructuredLogging { get; set; } = true                   // 啟用結構化日誌記錄
public bool EnableCorrelationIds { get; set; } = true                      // 啟用相關 ID
public bool IncludeTimings { get; set; } = true                            // 包括執行計時
public bool IncludeNodeMetadata { get; set; } = true                       // 包括節點中繼資料
public bool IncludeStateSnapshots { get; set; } = false                    // 包括狀態快照
public int MaxStateDataSize { get; set; } = 2000                           // 最大狀態資料大小
```

#### 資料處理

```csharp
public bool LogSensitiveData { get; set; } = false                         // 記錄敏感資料
public SensitiveDataPolicy Sanitization { get; set; } = Default            // 清潔原則
public string? CorrelationIdPrefix { get; set; }                           // 相關 ID 前置詞
public string TimestampFormat { get; set; } = "yyyy-MM-dd HH:mm:ss.fff"    // 時間戳格式
```

#### 分類和節點設定

```csharp
public Dictionary<string, LogCategoryConfig> CategoryConfigs { get; set; }  // 分類設定
public Dictionary<string, NodeLoggingConfig> NodeConfigs { get; set; }      // 節點設定
```

## LogCategoryConfig

特定事件分類的日誌記錄設定。

### 屬性

```csharp
public bool Enabled { get; set; } = true                                   // 啟用分類日誌記錄
public LogLevel Level { get; set; } = LogLevel.Information                 // 最小日誌等級
public Dictionary<string, object> CustomProperties { get; set; } = new()    // 自訂屬性
```

## NodeLoggingConfig

特定節點的日誌記錄設定，擴展 `LogCategoryConfig`。

### 屬性

```csharp
public bool LogInputs { get; set; } = true                                 // 記錄輸入參數
public bool LogOutputs { get; set; } = true                                // 記錄輸出結果
public bool LogTiming { get; set; } = true                                 // 記錄執行計時
public bool LogStateChanges { get; set; } = true                           // 記錄狀態變更
public int MaxDataSize { get; set; } = 1000                                // 記錄的最大資料大小
```

## HitlAuditService

訂閱人工互動事件並記錄稽核項目以進行合規性和檢查的服務。

### 特色

* 自動稽核追蹤產生
* 敏感資料清潔
* 記憶體服務整合
* 最近稽核快取

### 建構函數

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

### 基本日誌記錄器設定

```csharp
using Microsoft.Extensions.Logging;
using SemanticKernel.Graph.Integration;

// 建立日誌記錄器工廠
var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole()
           .AddJsonConsole()
           .SetMinimumLevel(LogLevel.Information);
});

// 建立圖日誌記錄器
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

// 在圖執行器中使用（透過建構函數傳遞日誌記錄器）
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

// 配置分類特定日誌記錄
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

// 配置節點特定日誌記錄
loggingOptions.NodeConfigs["api_call"] = new NodeLoggingConfig
{
    Level = LogLevel.Debug,
    LogInputs = true,
    LogOutputs = false,  // 不記錄 API 回應
    LogTiming = true,
    MaxDataSize = 500
};
```

### 圖註冊表使用

```csharp
using SemanticKernel.Graph.Integration;

// 建立註冊表
var registry = new GraphRegistry(logger);

// 註冊圖
await registry.RegisterAsync(graphExecutor1);
await registry.RegisterAsync(graphExecutor2);

// 列出已註冊的圖
var graphs = await registry.ListAsync();
foreach (var graphInfo in graphs)
{
    Console.WriteLine($"Graph: {graphInfo.Name} ({graphInfo.NodeCount} nodes)");
}

// 取得特定圖
var graph = await registry.GetAsync("MyGraph");
if (graph != null)
{
    // 執行圖
    var result = await graph.ExecuteAsync(kernel, arguments);
}
```

### 工具註冊表整合

```csharp
using SemanticKernel.Graph.Integration;

// 建立工具註冊表
var toolRegistry = new ToolRegistry(logger);

// 註冊外部工具
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

// 建立工具節點
var toolNode = await toolRegistry.CreateNodeAsync("weather_api", serviceProvider);
if (toolNode != null)
{
    // 在圖中使用工具節點
    graph.AddNode(toolNode);
}
```

### 資料清潔

```csharp
using SemanticKernel.Graph.Integration;

// 建立具有自訂原則的清潔器
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

// 清潔敏感資料
var sensitiveData = new Dictionary<string, object>
{
    ["username"] = "john_doe",
    ["password"] = "secret123",
    ["api_key"] = "sk-1234567890abcdef",
    ["authorization"] = "Bearer sk-1234567890abcdef"
};

var sanitized = sanitizer.Sanitize(sensitiveData);
// 結果：密碼和 api_key 值被編修，授權令牌被遮罩
```

### 外掛程式註冊表管理

```csharp
using SemanticKernel.Graph.Integration;

// 建立外掛程式註冊表
var pluginRegistry = new PluginRegistry(new PluginRegistryOptions
{
    MaxPlugins = 1000,
    EnablePeriodicCleanup = true,
    CleanupInterval = TimeSpan.FromHours(24)
}, logger);

// 註冊外掛程式
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

* [整合和擴充指南](../how-to/integration-and-extensions.md) - 如何配置和使用整合功能
* [安全和資料指南](../how-to/security-and-data.md) - 資料清潔和安全最佳實踐
* [計量和可觀察性指南](../how-to/metrics-and-observability.md) - 日誌記錄設定和可觀察性
* [擴充和選項參考](./extensions-and-options.md) - 圖選項和設定
* [串流 API 參考](./streaming.md) - 即時執行監控
* [檢查和視覺化參考](./inspection-visualization.md) - 除錯和檢查功能
