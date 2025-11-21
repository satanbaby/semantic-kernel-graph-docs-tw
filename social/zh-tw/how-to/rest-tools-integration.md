# REST Tools 整合

SemanticKernel.Graph 提供全面的整合功能，用於外部 REST API 和工具，讓您能夠將外部服務無縫整合到您的 Graph 工作流中。本指南涵蓋完整的 REST 工具生態系統，包括模式定義、驗證、快取和冪等性。

## 概述

REST 工具整合系統由多個關鍵組件組成：

* **RestToolSchema**: 定義 REST API 操作的結構和行為
* **RestToolGraphNode**: 執行 HTTP 請求的可執行 Graph Node
* **IToolRegistry**: 用於管理和發現可用工具的中央登錄表
* **IToolSchemaConverter**: 將模式轉換為可執行 Node
* **內建快取和冪等性**: 性能優化和請求安全性

## 核心組件

### RestToolSchema

`RestToolSchema` 類別定義 REST API 操作的契約：

```csharp
public sealed class RestToolSchema
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public string Description { get; init; } = string.Empty;
    public required Uri BaseUri { get; init; }
    public required string Path { get; init; }
    public required HttpMethod Method { get; init; }
    public string? JsonBodyTemplate { get; init; }
    public Dictionary<string, string> QueryParameters { get; init; } = new();
    public Dictionary<string, string> Headers { get; init; } = new();
    public int TimeoutSeconds { get; init; } = 30;
    public bool CacheEnabled { get; init; } = true;
    public int CacheTtlSeconds { get; init; } = 60;
    public string? TelemetryDependencyName { get; init; }
}
```

**主要功能：**
* **彈性參數對應**: 將查詢參數和標頭對應到 Graph 狀態變數
* **範本支援**: JSON 主體範本與變數替換
* **可設定的逾時**: 每個請求的逾時設定
* **內建快取**: 具有可設定 TTL 的回應快取
* **遙測整合**: 用於監視的依賴項追蹤

### RestToolGraphNode

`RestToolGraphNode` 根據模式定義執行 REST 操作：

```csharp
public sealed class RestToolGraphNode : IGraphNode, ITypedSchemaNode
{
    public RestToolGraphNode(
        RestToolSchema schema, 
        HttpClient httpClient, 
        ILogger<RestToolGraphNode>? logger = null, 
        ISecretResolver? secretResolver = null, 
        IGraphTelemetry? telemetry = null);
}
```

**功能：**
* **輸入對應**: 自動將 Graph 狀態對應到 HTTP 參數
* **回應處理**: 解析 JSON 回應並提供結構化輸出
* **錯誤處理**: 具有遙測的綜合錯誤處理
* **模式驗證**: 為型別安全實作 `ITypedSchemaNode`
* **密鑰解析**: 安全處理 API 金鑰和敏感資料

## 模式定義

### 基本 REST 模式

定義簡單的 GET 操作：

```csharp
var weatherSchema = new RestToolSchema
{
    Id = "weather.get",
    Name = "Get Weather",
    Description = "Retrieve current weather information",
    BaseUri = new Uri("https://api.weatherapi.com"),
    Path = "/v1/current.json",
    Method = HttpMethod.Get,
    QueryParameters = 
    {
        ["q"] = "location",           // Maps to graph state "location"
        ["key"] = "secret:weather_key" // Resolved via secret resolver
    },
    Headers = 
    {
        ["User-Agent"] = ":SemanticKernel.Graph/1.0", // Literal value
        ["X-Correlation-ID"] = "correlation_id"        // Maps to graph state
    },
    CacheEnabled = true,
    CacheTtlSeconds = 300, // 5 minutes
    TimeoutSeconds = 10
};
```

### POST with JSON Body

定義具有動態主體內容的 POST 操作：

```csharp
var orderSchema = new RestToolSchema
{
    Id = "orders.create",
    Name = "Create Order",
    Description = "Create a new order in the system",
    BaseUri = new Uri("https://api.store.com"),
    Path = "/v1/orders",
    Method = HttpMethod.Post,
    JsonBodyTemplate = """
    {
        "customer_id": "{{customer_id}}",
        "items": {{items_json}},
        "shipping_address": {
            "street": "{{street}}",
            "city": "{{city}}",
            "postal_code": "{{postal_code}}"
        }
    }
    """,
    Headers = 
    {
        ["Content-Type"] = ":application/json",
        ["Authorization"] = "secret:store_api_key",
        ["X-Request-ID"] = "request_id"
    },
    CacheEnabled = false, // POST operations typically not cached
    TimeoutSeconds = 30
};
```

### 具有路由參數的進階模式

定義具有動態路徑區段的操作：

```csharp
var userSchema = new RestToolSchema
{
    Id = "users.get",
    Name = "Get User",
    Description = "Retrieve user information by ID",
    BaseUri = new Uri("https://api.users.com"),
    Path = "/v1/users/{user_id}/profile", // Route parameter
    Method = HttpMethod.Get,
    QueryParameters = 
    {
        ["include"] = "include_fields",
        ["format"] = ":json"
    },
    Headers = 
    {
        ["Accept"] = ":application/json",
        ["Authorization"] = "secret:users_api_key"
    }
};
```

## 參數對應

### 查詢參數

將 Graph 狀態變數對應到 HTTP 查詢參數：

```csharp
var schema = new RestToolSchema
{
    // ... other properties
    QueryParameters = 
    {
        ["search"] = "query_text",        // ?search=value_from_state
        ["page"] = "page_number",         // &page=value_from_state
        ["limit"] = "max_results",        // &limit=value_from_state
        ["sort"] = ":name_asc"            // &sort=name_asc (literal)
    }
};

// Graph state
var args = new KernelArguments
{
    ["query_text"] = "semantic kernel",
    ["page_number"] = 1,
    ["max_results"] = 20
};

// Results in: ?search=semantic%20kernel&page=1&limit=20&sort=name_asc
```

### 標頭

將 Graph 狀態變數對應到 HTTP 標頭：

```csharp
var schema = new RestToolSchema
{
    // ... other properties
    Headers = 
    {
        ["Authorization"] = "secret:api_key",           // Resolved via secret resolver
        ["X-Correlation-ID"] = "correlation_id",        // From graph state
        ["User-Agent"] = ":MyApp/1.0",                  // Literal value
        ["Accept-Language"] = "language_code",          // From graph state
        ["X-Tenant"] = "tenant_id"                      // From graph state
    }
};
```

**標頭值型別：**
* **字面值**: 以 `:` 開頭 (例如 `":application/json"`)
* **密鑰參考**: 以 `secret:` 開頭 (例如 `"secret:api_key"`)
* **狀態變數**: 無前綴 (例如 `"correlation_id"`)

### JSON 主體範本

針對動態請求主體使用 Handlebars 風格的範本：

```csharp
var schema = new RestToolSchema
{
    // ... other properties
    JsonBodyTemplate = """
    {
        "user": {
            "id": "{{user_id}}",
            "name": "{{user_name}}",
            "email": "{{user_email}}"
        },
        "preferences": {{preferences_json}},
        "metadata": {
            "created_at": "{{timestamp}}",
            "source": "{{source}}"
        }
    }
    """
};
```

**範本功能：**
* **變數替換**: `{{variable_name}}` 以 Graph 狀態值替換
* **JSON 嵌入**: `{{json_variable}}` 適用於複雜物件
* **條件邏輯**: 支援基本 Handlebars 運算式
* **逸出處理**: 自動進行 JSON 逸出以安全輸出

## 工具登錄表

### IToolRegistry 介面

`IToolRegistry` 提供集中式工具管理：

```csharp
public interface IToolRegistry
{
    Task<bool> RegisterAsync(ToolMetadata metadata, Func<IServiceProvider, IGraphNode> factory);
    Task<bool> UnregisterAsync(string toolId);
    Task<ToolMetadata?> GetAsync(string toolId);
    Task<IGraphNode?> CreateNodeAsync(string toolId, IServiceProvider serviceProvider);
    Task<IReadOnlyList<ToolMetadata>> ListAsync(ToolSearchCriteria? criteria = null);
}
```

### 工具登錄

在登錄表中登錄 REST 工具：

```csharp
// Create tool metadata
var metadata = new ToolMetadata
{
    Id = "weather.api",
    Name = "Weather API",
    Description = "Weather information services",
    Type = ToolType.Rest,
    Tags = new HashSet<string> { "weather", "external", "api" },
    Version = "1.0.0"
};

// Create factory function
Func<IServiceProvider, IGraphNode> factory = (services) =>
{
    var httpClient = services.GetRequiredService<HttpClient>();
    var logger = services.GetService<ILogger<RestToolGraphNode>>();
    var secretResolver = services.GetService<ISecretResolver>();
    var telemetry = services.GetService<IGraphTelemetry>();
    
    return new RestToolGraphNode(weatherSchema, httpClient, logger, secretResolver, telemetry);
};

// Register the tool
await toolRegistry.RegisterAsync(metadata, factory);
```

### 工具探索

探索和列出可用的工具：

```csharp
// List all tools
var allTools = await toolRegistry.ListAsync();

// Search by criteria
var searchCriteria = new ToolSearchCriteria
{
    SearchText = "weather",
    Type = ToolType.Rest,
    Tags = new HashSet<string> { "api" }
};

var weatherTools = await toolRegistry.ListAsync(searchCriteria);

// Get specific tool
var toolMetadata = await toolRegistry.GetAsync("weather.api");
if (toolMetadata != null)
{
    var toolNode = await toolRegistry.CreateNodeAsync("weather.api", serviceProvider);
    // Use the tool node in your graph
}
```

## 模式轉換

### IToolSchemaConverter

將模式轉換為可執行 Node：

```csharp
public interface IToolSchemaConverter
{
    IGraphNode CreateNode(RestToolSchema schema);
}
```

### RestToolSchemaConverter

REST 工具的預設實作：

```csharp
public sealed class RestToolSchemaConverter : IToolSchemaConverter
{
    public RestToolSchemaConverter(
        HttpClient httpClient, 
        ILogger<RestToolSchemaConverter>? logger = null, 
        ISecretResolver? secretResolver = null, 
        IGraphTelemetry? telemetry = null);
    
    public IGraphNode CreateNode(RestToolSchema schema);
}
```

**用法：**
```csharp
var converter = new RestToolSchemaConverter(
    httpClient: httpClient,
    logger: logger,
    secretResolver: secretResolver,
    telemetry: telemetry
);

var restNode = converter.CreateNode(weatherSchema);
```

## 快取和效能

### 回應快取

啟用快取以改善效能：

```csharp
var schema = new RestToolSchema
{
    // ... other properties
    CacheEnabled = true,
    CacheTtlSeconds = 600 // 10 minutes
};
```

**快取行為：**
* **快取鑰匙**: 從 HTTP 方法、URL 和請求主體雜湊生成
* **TTL 管理**: 根據模式設定自動過期
* **記憶體有效率**: 使用具有過期追蹤的並行字典
* **執行緒安全**: 支援並行存取以實現高效能案例

### 快取設定

設定快取行為：

```csharp
// Enable caching with custom TTL
var schema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 3600, // 1 hour
    // ... other properties
};

// Disable caching for dynamic content
var dynamicSchema = new RestToolSchema
{
    CacheEnabled = false,
    // ... other properties
};
```

## 冪等性

### 請求冪等性

使用冪等性鑰匙確保安全的重試行為：

```csharp
// The GraphRestApi automatically handles idempotency
var request = new ExecuteGraphRequest
{
    GraphName = "weather-workflow",
    Arguments = new KernelArguments { ["location"] = "New York" },
    IdempotencyKey = "weather-ny-2025-08-15" // Unique key for this operation
};

var response = await graphApi.ExecuteGraphAsync(request, cancellationToken);
```

**冪等性功能：**
* **自動處理**: 內建於 GraphRestApi 服務
* **請求去重**: 防止重複執行
* **雜湊驗證**: 確保請求一致性
* **可設定視窗**: 可調整的冪等性時間視窗

## 驗證和錯誤處理

### 輸入驗證

在執行前驗證輸入：

```csharp
var node = new RestToolGraphNode(schema, httpClient);

// Validate execution arguments
var validationResult = node.ValidateExecution(arguments);
if (!validationResult.IsValid)
{
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"Validation error: {error.Message}");
    }
}
```

### 模式驗證

驗證模式完整性：

```csharp
// Validate schema configuration
if (string.IsNullOrEmpty(schema.Id))
    throw new ArgumentException("Schema ID is required");

if (schema.BaseUri == null)
    throw new ArgumentException("Base URI is required");

if (schema.TimeoutSeconds <= 0)
    throw new ArgumentException("Timeout must be positive");

if (schema.CacheTtlSeconds <= 0 && schema.CacheEnabled)
    throw new ArgumentException("Cache TTL must be positive when caching is enabled");
```

### 錯誤處理

REST 操作中的綜合錯誤處理：

```csharp
try
{
    var result = await restNode.ExecuteAsync(kernel, arguments, cancellationToken);
    
    // Safely read HTTP metadata from the execution result.
    // The RestToolGraphNode stores HTTP metadata in the FunctionResult.Metadata dictionary.
    var statusCode = result.Metadata.TryGetValue("status_code", out var scObj) && scObj is int sc ? sc : -1;
    if (statusCode >= 400)
    {
        // Handle HTTP errors: read the response body safely and log.
        var errorBody = result.Metadata.TryGetValue("response_body", out var ebObj) ? ebObj?.ToString() ?? string.Empty : string.Empty;
        _logger.LogError("HTTP error {StatusCode}: {ErrorBody}", statusCode, errorBody);
    }
}
catch (OperationCanceledException)
{
    // Handle timeout or cancellation
    _logger.LogWarning("Request was cancelled or timed out");
}
catch (HttpRequestException ex)
{
    // Handle HTTP request errors
    _logger.LogError(ex, "HTTP request failed");
}
catch (Exception ex)
{
    // Handle other errors
    _logger.LogError(ex, "Unexpected error during REST operation");
}
```

## 遙測和監視

### 依賴項追蹤

追蹤外部 API 依賴項：

```csharp
var schema = new RestToolSchema
{
    // ... other properties
    TelemetryDependencyName = "Weather API Service"
};

// Telemetry is automatically emitted when IGraphTelemetry is available
```

**遙測資料：**
* **依賴項類型**: HTTP
* **目標**: API 主機名稱
* **操作**: HTTP 方法 + 路徑
* **持續時間**: 請求執行時間
* **成功**: HTTP 狀態碼範圍
* **屬性**: Node ID、Graph 名稱、URI

### 效能監視

監視 REST 工具效能：

```csharp
// Access performance metrics
var metrics = restNode.GetPerformanceMetrics();
Console.WriteLine($"Total requests: {metrics.TotalExecutions}");
Console.WriteLine($"Average duration: {metrics.AverageExecutionTime}");
Console.WriteLine($"Cache hit rate: {metrics.CacheHitRate:P2}");
```

## 安全功能

### 密鑰解析

敏感資料的安全處理：

```csharp
public interface ISecretResolver
{
    Task<string?> ResolveSecretAsync(string secretName, CancellationToken cancellationToken = default);
}

// Configure secret resolver
var secretResolver = new AzureKeyVaultSecretResolver(keyVaultClient);
var restNode = new RestToolGraphNode(schema, httpClient, secretResolver: secretResolver);
```

**密鑰型別：**
* **API 金鑰**: `"secret:weather_api_key"`
* **驗證權杖**: `"secret:bearer_token"`
* **連接字串**: `"secret:database_connection"`

### 資料清理

自動清理敏感資料：

```csharp
// Sensitive data is automatically sanitized in logs and telemetry
var sanitizer = new SensitiveDataSanitizer(new SensitiveDataPolicy
{
    SanitizeApiKeys = true,
    SanitizeTokens = true,
    SanitizeUrls = false
});
```

## 使用範例

### 天氣 API 整合

整合氣象 API 的完整範例：

```csharp
// 1. Define the schema
var weatherSchema = new RestToolSchema
{
    Id = "weather.current",
    Name = "Current Weather",
    Description = "Get current weather for a location",
    BaseUri = new Uri("https://api.weatherapi.com"),
    Path = "/v1/current.json",
    Method = HttpMethod.Get,
    QueryParameters = 
    {
        ["q"] = "location",
        ["key"] = "secret:weather_api_key"
    },
    CacheEnabled = true,
    CacheTtlSeconds = 1800, // 30 minutes
    TimeoutSeconds = 10
};

// 2. Create the node
var httpClient = new HttpClient();
var secretResolver = new EnvironmentSecretResolver();
var weatherNode = new RestToolGraphNode(weatherSchema, httpClient, secretResolver: secretResolver);

// 3. Use in a graph
var graph = new GraphExecutor("weather-graph");
graph.AddNode(weatherNode).SetStartNode("weather.current");

// 4. Execute with location
var args = new KernelArguments { ["location"] = "London" };
var result = await graph.ExecuteAsync(kernel, args);

// 5. Process results
var weatherData = result.GetValue<object>("response_json");
var statusCode = result.GetValue<int>("status_code");
```

### 電子商務 API 整合

整合電子商務系統的範例：

```csharp
// Product search schema
var productSearchSchema = new RestToolSchema
{
    Id = "products.search",
    Name = "Search Products",
    BaseUri = new Uri("https://api.store.com"),
    Path = "/v1/products/search",
    Method = HttpMethod.Get,
    QueryParameters = 
    {
        ["q"] = "search_query",
        ["category"] = "category_id",
        ["price_min"] = "min_price",
        ["price_max"] = "max_price",
        ["sort"] = "sort_order"
    },
    Headers = 
    {
        ["Authorization"] = "secret:store_api_key",
        ["Accept-Language"] = "language"
    },
    CacheEnabled = true,
    CacheTtlSeconds = 300
};

// Order creation schema
var orderCreateSchema = new RestToolSchema
{
    Id = "orders.create",
    Name = "Create Order",
    BaseUri = new Uri("https://api.store.com"),
    Path = "/v1/orders",
    Method = HttpMethod.Post,
    JsonBodyTemplate = """
    {
        "customer_id": "{{customer_id}}",
        "items": {{items_json}},
        "shipping_address": {
            "street": "{{street}}",
            "city": "{{city}}",
            "postal_code": "{{postal_code}}"
        }
    }
    """,
    Headers = 
    {
        ["Content-Type"] = ":application/json",
        ["Authorization"] = "secret:store_api_key"
    },
    CacheEnabled = false,
    TimeoutSeconds = 30
};
```

## 最佳實踐

### 1. 模式設計

* **使用描述性 ID**: 清晰、分層命名 (例如 `"api.weather.current"`)
* **提供說明**: 幫助開發者瞭解工具用途
* **設定適當的逾時**: 平衡反應速度與可靠性
* **設定快取**: 針對讀取操作啟用，針對變更停用

### 2. 安全性

* **使用密鑰解析**: 永遠不要硬編碼 API 金鑰
* **驗證輸入**: 清理使用者提供的資料
* **設定逾時**: 防止懸掛的請求
* **監視使用情況**: 追蹤 API 消費和錯誤

### 3. 效能

* **啟用快取**: 針對讀取操作快取回應
* **適當設定 TTL**: 平衡新鮮度與效能
* **使用連線集區**: 重複使用 HttpClient 執行個體
* **監視指標**: 追蹤回應時間和錯誤率

### 4. 錯誤處理

* **處理 HTTP 錯誤**: 檢查狀態碼和錯誤回應
* **實作重試**: 針對暫時性失敗使用指數退避法
* **記錄失敗**: 提供偵錯的上下文
* **優雅降級**: 在可能時繼續執行

### 5. 測試

* **模擬外部 API**: 使用測試替身進行開發
* **驗證模式**: 確保模式定義正確
* **測試錯誤情境**: 驗證錯誤處理行為
* **效能測試**: 驗證快取和逾時行為

## 疑難排解

### 常見問題

**逾時錯誤：**
* 檢查網路連線
* 驗證 API 端點可用性
* 調整模式中的逾時設定
* 監視 API 回應時間

**驗證失敗：**
* 驗證密鑰解析設定
* 檢查 API 金鑰有效性
* 確保適當的標頭格式
* 驗證授權範圍

**快取問題：**
* 驗證快取設定
* 檢查 TTL 設定
* 監視記憶體使用情況
* 驗證快取鑰匙生成

**模式驗證錯誤：**
* 檢查必要屬性
* 驗證 URI 格式
* 驗證 HTTP 方法
* 確保參數對應

### 偵錯資訊

啟用詳細記錄以進行疑難排解：

```csharp
// Enable debug logging
var logger = LoggerFactory.Create(builder => 
    builder.SetMinimumLevel(LogLevel.Debug)
.).CreateLogger<RestToolGraphNode>();

var restNode = new RestToolGraphNode(schema, httpClient, logger: logger);

// Check execution details using safe metadata access.
var result = await restNode.ExecuteAsync(kernel, arguments);
var status = result.Metadata.TryGetValue("status_code", out var stObj) && stObj is int sti ? sti : -1;
var responseBody = result.Metadata.TryGetValue("response_body", out var respObj) ? respObj?.ToString() ?? string.Empty : string.Empty;
var fromCache = result.Metadata.TryGetValue("from_cache", out var fcObj) && fcObj is bool fcb && fcb;
Console.WriteLine($"Status: {status}");
Console.WriteLine($"Response: {responseBody}");
Console.WriteLine($"From cache: {fromCache}");
```

## 另請參閱

* [公開 REST API](./exposing-rest-apis.md) - 透過 REST 公開 Graph 功能
* [狀態管理](./state.md) - Graph 狀態和引數處理
* [效能指標](./metrics-and-observability.md) - 監視和可觀測性
* [安全性和資料](./security-and-data.md) - 安全最佳實踐
* [整合和擴充](./integration-and-extensions.md) - 一般整合模式

## 範例

* [REST API 範例](../../examples/rest-api.md) - 完整的 REST 整合示範
* [多代理工作流程](../../tutorials/multi-agent-workflow.md) - 複雜工具編排
* [文件分析管道](../../tutorials/document-analysis-pipeline.md) - 外部服務整合
