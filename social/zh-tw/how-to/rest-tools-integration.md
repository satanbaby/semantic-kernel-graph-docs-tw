# REST 工具整合

SemanticKernel.Graph 提供全面的外部 REST API 和工具整合能力，使您能夠將外部服務無縫整合至您的圖形工作流程中。本指南涵蓋完整的 REST 工具生態系統，包括結構定義、驗證、快取和冪等性。

## 概述

REST 工具整合系統由以下幾個關鍵組件組成：

* **RestToolSchema**：定義 REST API 操作的結構和行為
* **RestToolGraphNode**：執行 HTTP 請求的可執行圖形節點
* **IToolRegistry**：用於管理和發現可用工具的中央登錄檔
* **IToolSchemaConverter**：將結構轉換為可執行節點
* **內置快取和冪等性**：性能優化和請求安全性

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

**主要特性：**
* **靈活的參數對映**：將查詢參數和標頭對映至圖形狀態變數
* **範本支援**：具有變數替換的 JSON 正文範本
* **可配置的逾時**：每個請求的逾時設定
* **內置快取**：具有可配置 TTL 的回應快取
* **遙測整合**：用於監控的相依性追蹤

### RestToolGraphNode

`RestToolGraphNode` 根據結構定義執行 REST 操作：

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
* **輸入對映**：自動將圖形狀態對映至 HTTP 參數
* **回應處理**：解析 JSON 回應並提供結構化輸出
* **錯誤處理**：具有遙測的全面錯誤處理
* **結構驗證**：實現 `ITypedSchemaNode` 以確保類型安全
* **祕密解析**：安全處理 API 金鑰和敏感資料

## 結構定義

### 基本 REST 結構

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
        ["q"] = "location",           // 對映至圖形狀態 "location"
        ["key"] = "secret:weather_key" // 透過祕密解析器解析
    },
    Headers = 
    {
        ["User-Agent"] = ":SemanticKernel.Graph/1.0", // 字面值
        ["X-Correlation-ID"] = "correlation_id"        // 對映至圖形狀態
    },
    CacheEnabled = true,
    CacheTtlSeconds = 300, // 5 分鐘
    TimeoutSeconds = 10
};
```

### POST 搭配 JSON 正文

定義含有動態正文內容的 POST 操作：

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
    CacheEnabled = false, // POST 操作通常不快取
    TimeoutSeconds = 30
};
```

### 具備路由參數的進階結構

定義具有動態路徑區段的操作：

```csharp
var userSchema = new RestToolSchema
{
    Id = "users.get",
    Name = "Get User",
    Description = "Retrieve user information by ID",
    BaseUri = new Uri("https://api.users.com"),
    Path = "/v1/users/{user_id}/profile", // 路由參數
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

## 參數對映

### 查詢參數

將圖形狀態變數對映至 HTTP 查詢參數：

```csharp
var schema = new RestToolSchema
{
    // ... 其他屬性
    QueryParameters = 
    {
        ["search"] = "query_text",        // ?search=value_from_state
        ["page"] = "page_number",         // &page=value_from_state
        ["limit"] = "max_results",        // &limit=value_from_state
        ["sort"] = ":name_asc"            // &sort=name_asc (字面值)
    }
};

// 圖形狀態
var args = new KernelArguments
{
    ["query_text"] = "semantic kernel",
    ["page_number"] = 1,
    ["max_results"] = 20
};

// 結果：?search=semantic%20kernel&page=1&limit=20&sort=name_asc
```

### 標頭

將圖形狀態變數對映至 HTTP 標頭：

```csharp
var schema = new RestToolSchema
{
    // ... 其他屬性
    Headers = 
    {
        ["Authorization"] = "secret:api_key",           // 透過祕密解析器解析
        ["X-Correlation-ID"] = "correlation_id",        // 來自圖形狀態
        ["User-Agent"] = ":MyApp/1.0",                  // 字面值
        ["Accept-Language"] = "language_code",          // 來自圖形狀態
        ["X-Tenant"] = "tenant_id"                      // 來自圖形狀態
    }
};
```

**標頭值類型：**
* **字面值**：以 `:` 開頭 (例如 `":application/json"`)
* **祕密參考**：以 `secret:` 開頭 (例如 `"secret:api_key"`)
* **狀態變數**：無前置詞 (例如 `"correlation_id"`)

### JSON 正文範本

使用 Handlebars 風格的範本進行動態請求正文：

```csharp
var schema = new RestToolSchema
{
    // ... 其他屬性
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

**範本特性：**
* **變數替換**：`{{variable_name}}` 由圖形狀態值替換
* **JSON 嵌入**：`{{json_variable}}` 用於複雜物件
* **條件邏輯**：支援基本 Handlebars 表達式
* **跳出處理**：自動 JSON 跳出以確保安全輸出

## 工具登錄檔

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

在登錄檔中登錄 REST 工具：

```csharp
// 建立工具中繼資料
var metadata = new ToolMetadata
{
    Id = "weather.api",
    Name = "Weather API",
    Description = "Weather information services",
    Type = ToolType.Rest,
    Tags = new HashSet<string> { "weather", "external", "api" },
    Version = "1.0.0"
};

// 建立處理工廠函式
Func<IServiceProvider, IGraphNode> factory = (services) =>
{
    var httpClient = services.GetRequiredService<HttpClient>();
    var logger = services.GetService<ILogger<RestToolGraphNode>>();
    var secretResolver = services.GetService<ISecretResolver>();
    var telemetry = services.GetService<IGraphTelemetry>();
    
    return new RestToolGraphNode(weatherSchema, httpClient, logger, secretResolver, telemetry);
};

// 登錄工具
await toolRegistry.RegisterAsync(metadata, factory);
```

### 工具發現

發現和列出可用工具：

```csharp
// 列出所有工具
var allTools = await toolRegistry.ListAsync();

// 按條件搜尋
var searchCriteria = new ToolSearchCriteria
{
    SearchText = "weather",
    Type = ToolType.Rest,
    Tags = new HashSet<string> { "api" }
};

var weatherTools = await toolRegistry.ListAsync(searchCriteria);

// 取得特定工具
var toolMetadata = await toolRegistry.GetAsync("weather.api");
if (toolMetadata != null)
{
    var toolNode = await toolRegistry.CreateNodeAsync("weather.api", serviceProvider);
    // 在您的圖形中使用工具節點
}
```

## 結構轉換

### IToolSchemaConverter

將結構轉換為可執行節點：

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

**使用方式：**
```csharp
var converter = new RestToolSchemaConverter(
    httpClient: httpClient,
    logger: logger,
    secretResolver: secretResolver,
    telemetry: telemetry
);

var restNode = converter.CreateNode(weatherSchema);
```

## 快取和性能

### 回應快取

啟用快取以改善性能：

```csharp
var schema = new RestToolSchema
{
    // ... 其他屬性
    CacheEnabled = true,
    CacheTtlSeconds = 600 // 10 分鐘
};
```

**快取行為：**
* **快取金鑰**：由 HTTP 方法、URL 和請求正文雜湊產生
* **TTL 管理**：根據結構配置自動過期
* **記憶體效率**：使用具有過期追蹤的並行字典
* **執行緒安全**：支援並行存取以實現高性能情境

### 快取配置

配置快取行為：

```csharp
// 啟用快取搭配自訂 TTL
var schema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 3600, // 1 小時
    // ... 其他屬性
};

// 停用動態內容快取
var dynamicSchema = new RestToolSchema
{
    CacheEnabled = false,
    // ... 其他屬性
};
```

## 冪等性

### 請求冪等性

透過冪等性金鑰確保安全重試行為：

```csharp
// GraphRestApi 自動處理冪等性
var request = new ExecuteGraphRequest
{
    GraphName = "weather-workflow",
    Arguments = new KernelArguments { ["location"] = "New York" },
    IdempotencyKey = "weather-ny-2025-08-15" // 此操作的唯一金鑰
};

var response = await graphApi.ExecuteGraphAsync(request, cancellationToken);
```

**冪等性特性：**
* **自動處理**：內置於 GraphRestApi 服務中
* **請求去重**：防止重複執行
* **雜湊驗證**：確保請求一致性
* **可配置視窗**：可調整的冪等性時間視窗

## 驗證和錯誤處理

### 輸入驗證

在執行前驗證輸入：

```csharp
var node = new RestToolGraphNode(schema, httpClient);

// 驗證執行引數
var validationResult = node.ValidateExecution(arguments);
if (!validationResult.IsValid)
{
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"Validation error: {error.Message}");
    }
}
```

### 結構驗證

驗證結構完整性：

```csharp
// 驗證結構配置
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

REST 操作中的全面錯誤處理：

```csharp
try
{
    var result = await restNode.ExecuteAsync(kernel, arguments, cancellationToken);
    
    // 安全地從執行結果讀取 HTTP 中繼資料。
    // RestToolGraphNode 將 HTTP 中繼資料儲存在 FunctionResult.Metadata 字典中。
    var statusCode = result.Metadata.TryGetValue("status_code", out var scObj) && scObj is int sc ? sc : -1;
    if (statusCode >= 400)
    {
        // 處理 HTTP 錯誤：安全地讀取回應正文並記錄。
        var errorBody = result.Metadata.TryGetValue("response_body", out var ebObj) ? ebObj?.ToString() ?? string.Empty : string.Empty;
        _logger.LogError("HTTP error {StatusCode}: {ErrorBody}", statusCode, errorBody);
    }
}
catch (OperationCanceledException)
{
    // 處理逾時或取消
    _logger.LogWarning("Request was cancelled or timed out");
}
catch (HttpRequestException ex)
{
    // 處理 HTTP 要求錯誤
    _logger.LogError(ex, "HTTP request failed");
}
catch (Exception ex)
{
    // 處理其他錯誤
    _logger.LogError(ex, "Unexpected error during REST operation");
}
```

## 遙測和監控

### 相依性追蹤

追蹤外部 API 相依性：

```csharp
var schema = new RestToolSchema
{
    // ... 其他屬性
    TelemetryDependencyName = "Weather API Service"
};

// 當 IGraphTelemetry 可用時，遙測會自動發出
```

**遙測資料：**
* **相依性類型**：HTTP
* **目標**：API 主機名稱
* **操作**：HTTP 方法 + 路徑
* **持續時間**：請求執行時間
* **成功**：HTTP 狀態碼範圍
* **屬性**：節點識別碼、圖形名稱、URI

### 性能監控

監控 REST 工具性能：

```csharp
// 存取性能指標
var metrics = restNode.GetPerformanceMetrics();
Console.WriteLine($"Total requests: {metrics.TotalExecutions}");
Console.WriteLine($"Average duration: {metrics.AverageExecutionTime}");
Console.WriteLine($"Cache hit rate: {metrics.CacheHitRate:P2}");
```

## 安全功能

### 祕密解析

安全處理敏感資料：

```csharp
public interface ISecretResolver
{
    Task<string?> ResolveSecretAsync(string secretName, CancellationToken cancellationToken = default);
}

// 配置祕密解析器
var secretResolver = new AzureKeyVaultSecretResolver(keyVaultClient);
var restNode = new RestToolGraphNode(schema, httpClient, secretResolver: secretResolver);
```

**祕密類型：**
* **API 金鑰**：`"secret:weather_api_key"`
* **驗證權杖**：`"secret:bearer_token"`
* **連接字串**：`"secret:database_connection"`

### 資料清理

敏感資料的自動清理：

```csharp
// 敏感資料在日誌和遙測中會自動清理
var sanitizer = new SensitiveDataSanitizer(new SensitiveDataPolicy
{
    SanitizeApiKeys = true,
    SanitizeTokens = true,
    SanitizeUrls = false
});
```

## 使用範例

### 天氣 API 整合

整合天氣 API 的完整範例：

```csharp
// 1. 定義結構
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
    CacheTtlSeconds = 1800, // 30 分鐘
    TimeoutSeconds = 10
};

// 2. 建立節點
var httpClient = new HttpClient();
var secretResolver = new EnvironmentSecretResolver();
var weatherNode = new RestToolGraphNode(weatherSchema, httpClient, secretResolver: secretResolver);

// 3. 在圖形中使用
var graph = new GraphExecutor("weather-graph");
graph.AddNode(weatherNode).SetStartNode("weather.current");

// 4. 執行並指定位置
var args = new KernelArguments { ["location"] = "London" };
var result = await graph.ExecuteAsync(kernel, args);

// 5. 處理結果
var weatherData = result.GetValue<object>("response_json");
var statusCode = result.GetValue<int>("status_code");
```

### 電子商務 API 整合

整合電子商務系統的範例：

```csharp
// 產品搜尋結構
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

// 訂單建立結構
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

## 最佳做法

### 1. 結構設計

* **使用描述性 ID**：清晰的階層式命名 (例如 `"api.weather.current"`)
* **提供描述**：幫助開發人員理解工具用途
* **設定適當的逾時**：平衡回應性和可靠性
* **配置快取**：為讀取操作啟用，為變更操作停用

### 2. 安全性

* **使用祕密解析器**：不要硬編碼 API 金鑰
* **驗證輸入**：清理使用者提供的資料
* **設定逾時**：防止掛起的請求
* **監控使用情況**：追蹤 API 耗用和錯誤

### 3. 性能

* **啟用快取**：快取讀取操作的回應
* **適當設定 TTL**：平衡新鮮度和性能
* **使用連接集區**：重複使用 HttpClient 執行個體
* **監控指標**：追蹤回應時間和錯誤率

### 4. 錯誤處理

* **處理 HTTP 錯誤**：檢查狀態碼和錯誤回應
* **實作重試**：使用指數退避處理暫時性故障
* **記錄故障**：提供用於偵錯的內容
* **緩雅降級**：在可能時繼續執行

### 5. 測試

* **模擬外部 API**：使用測試替身進行開發
* **驗證結構**：確保結構定義正確
* **測試錯誤情節**：驗證錯誤處理行為
* **性能測試**：驗證快取和逾時行為

## 疑難排解

### 常見問題

**逾時錯誤：**
* 檢查網路連線
* 驗證 API 端點可用性
* 調整結構中的逾時設定
* 監控 API 回應時間

**驗證失敗：**
* 驗證祕密解析器配置
* 檢查 API 金鑰有效性
* 確保適當的標頭格式
* 驗證授權範圍

**快取問題：**
* 驗證快取配置
* 檢查 TTL 設定
* 監控記憶體使用情況
* 驗證快取金鑰產生

**結構驗證錯誤：**
* 檢查必要屬性
* 驗證 URI 格式
* 驗證 HTTP 方法
* 確保參數對映

### 偵錯資訊

啟用詳細記錄以進行疑難排解：

```csharp
// 啟用偵錯記錄
var logger = LoggerFactory.Create(builder => 
    builder.SetMinimumLevel(LogLevel.Debug)
).CreateLogger<RestToolGraphNode>();

var restNode = new RestToolGraphNode(schema, httpClient, logger: logger);

// 使用安全中繼資料存取檢查執行詳細資料。
var result = await restNode.ExecuteAsync(kernel, arguments);
var status = result.Metadata.TryGetValue("status_code", out var stObj) && stObj is int sti ? sti : -1;
var responseBody = result.Metadata.TryGetValue("response_body", out var respObj) ? respObj?.ToString() ?? string.Empty : string.Empty;
var fromCache = result.Metadata.TryGetValue("from_cache", out var fcObj) && fcObj is bool fcb && fcb;
Console.WriteLine($"Status: {status}");
Console.WriteLine($"Response: {responseBody}");
Console.WriteLine($"From cache: {fromCache}");
```

## 另請參閱

* [公開 REST API](./exposing-rest-apis.md) - 透過 REST 公開圖形功能
* [狀態管理](./state.md) - 圖形狀態和引數處理
* [性能指標](./metrics-and-observability.md) - 監控和可觀測性
* [安全性和資料](./security-and-data.md) - 安全性最佳做法
* [整合和擴充](./integration-and-extensions.md) - 一般整合模式

## 範例

* [REST API 範例](../../examples/rest-api.md) - 完整 REST 整合示範
* [多代理工作流程](../../tutorials/multi-agent-workflow.md) - 複雜工具編排
* [文件分析管道](../../tutorials/document-analysis-pipeline.md) - 外部服務整合
