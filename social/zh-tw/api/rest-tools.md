# REST 工具

SemanticKernel.Graph 中的 REST 工具系統提供了對外部 REST API 和服務的全面整合能力。它使您能夠將外部 HTTP 端點無縫地整合到圖形工作流中，同時提供內置的驗證、快取和冪等性支持。

## 概述

REST 工具系統由以下幾個關鍵元件組成：

* **`RestToolSchema`**：定義 REST API 操作的結構和行為
* **`RestToolGraphNode`**：執行 HTTP 請求的可執行圖形節點
* **`RestToolSchemaConverter`**：將架構轉換為可執行節點
* **`IToolSchemaConverter`**：自訂工具轉換器的介面
* **內置快取和冪等性**：效能最佳化和請求安全性

## 核心類別

### RestToolSchema

定義 REST API 操作的契約，提供全面的配置選項：

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

**關鍵屬性：**
* **`Id`**：REST 工具的唯一識別碼
* **`Name`**：工具的易讀名稱
* **`Description`**：目的和行為說明
* **`BaseUri`**：遠端服務的基礎 URI
* **`Path`**：操作的相對路徑
* **`Method`**：HTTP 方法（GET、POST、PUT、DELETE 等）
* **`JsonBodyTemplate`**：可選的 JSON 正文範本，具有變數替換功能
* **`QueryParameters`**：查詢參數到圖形狀態變數的映射
* **`Headers`**：支援字面值和機密的標頭映射
* **`TimeoutSeconds`**：請求逾時（秒）
* **`CacheEnabled`**：是否啟用回應快取
* **`CacheTtlSeconds`**：快取存留時間（秒）
* **`TelemetryDependencyName`**：用於遙測追蹤的自訂名稱

### RestToolGraphNode

根據架構定義執行 HTTP 請求的可執行圖形節點：

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

**建構函式參數：**
* `schema`：定義操作的 REST 工具架構
* `httpClient`：用於發送請求的 HTTP 用戶端
* `logger`：可選的記錄器用於診斷
* `secretResolver`：可選的機密解析器用於敏感資料
* `telemetry`：可選的遙測適配器用於依賴追蹤

**主要功能：**
* **輸入映射**：自動將圖形狀態映射到 HTTP 參數
* **回應處理**：解析 JSON 回應並提供結構化輸出
* **錯誤處理**：包含遙測的全面錯誤處理
* **架構驗證**：實現 `ITypedSchemaNode` 以實現類型安全
* **機密解析**：API 金鑰和敏感資料的安全處理
* **快取**：內置回應快取，具有可配置的 TTL
* **逾時管理**：每個請求的逾時處理
* **遙測整合**：監控的依賴追蹤

### RestToolSchemaConverter

預設轉換器，將 `RestToolSchema` 實例轉換為可執行的 `RestToolGraphNode` 實例：

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

**建構函式參數：**
* `httpClient`：在所有 REST 操作中共用的 HTTP 用戶端
* `logger`：可選的記錄器用於轉換診斷
* `secretResolver`：可選的機密解析器用於安全操作
* `telemetry`：可選的遙測適配器用於監控

### IToolSchemaConverter

自訂工具架構轉換器的介面：

```csharp
public interface IToolSchemaConverter
{
    IGraphNode CreateNode(RestToolSchema schema);
}
```

**目的：**
* 為工具轉換提供可插拔架構
* 支援特定使用情況的自訂轉換邏輯
* 支援 REST 以外的不同工具類型（未來可擴展性）

## 架構配置

### 基本 GET 操作

定義簡單的 GET 操作以檢索資料：

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

### POST 搭配 JSON 正文

定義具有動態正文內容的 POST 操作：

```csharp
var orderSchema = new RestToolSchema
{
    Id = "orders.create",
    Name = "Create Order",
    Description = "Create a new order in the system",
    BaseUri = new Uri("https://api.ecommerce.com"),
    Path = "/v1/orders",
    Method = HttpMethod.Post,
    JsonBodyTemplate = @"{
        ""customer_id"": ""{customer_id}"",
        ""items"": {items},
        ""shipping_address"": {
            ""street"": ""{street}"",
            ""city"": ""{city}"",
            ""postal_code"": ""{postal_code}""
        },
        ""payment_method"": ""{payment_method}""
    }",
    Headers = 
    {
        ["Content-Type"] = ":application/json",
        ["Authorization"] = "Bearer {auth_token}",
        ["X-Request-ID"] = "request_id"
    },
    CacheEnabled = false, // POST operations typically not cached
    TimeoutSeconds = 30
};
```

### PUT 搭配動態路徑

定義具有路徑參數替換的 PUT 操作：

```csharp
var updateSchema = new RestToolSchema
{
    Id = "users.update",
    Name = "Update User",
    Description = "Update user information",
    BaseUri = new Uri("https://api.users.com"),
    Path = "/v1/users/{user_id}", // Path parameter
    Method = HttpMethod.Put,
    JsonBodyTemplate = @"{
        ""name"": ""{name}"",
        ""email"": ""{email}"",
        ""phone"": ""{phone}""
    }",
    Headers = 
    {
        ["Content-Type"] = ":application/json",
        ["Authorization"] = "Bearer {auth_token}",
        ["If-Match"] = "etag"
    },
    TimeoutSeconds = 15
};
```

## 參數映射

### 查詢參數

將圖形狀態變數映射到 HTTP 查詢參數：

```csharp
var searchSchema = new RestToolSchema
{
    // ... other properties
    QueryParameters = 
    {
        ["q"] = "search_term",        // Maps to graph state "search_term"
        ["limit"] = "result_limit",    // Maps to graph state "result_limit"
        ["offset"] = "page_offset",    // Maps to graph state "page_offset"
        ["sort"] = "sort_order",       // Maps to graph state "sort_order"
        ["filter"] = "filter_criteria" // Maps to graph state "filter_criteria"
    }
};
```

**用法：**
```csharp
var args = new KernelArguments
{
    ["search_term"] = "machine learning",
    ["result_limit"] = 20,
    ["page_offset"] = 0,
    ["sort_order"] = "relevance",
    ["filter_criteria"] = "recent"
};

// Results in: ?q=machine%20learning&limit=20&offset=0&sort=relevance&filter=recent
```

### 標頭

配置具有彈性映射選項的 HTTP 標頭：

```csharp
var apiSchema = new RestToolSchema
{
    // ... other properties
    Headers = 
    {
        // Literal values (prefixed with ":")
        ["Content-Type"] = ":application/json",
        ["User-Agent"] = ":MyApp/1.0",
        
        // Graph state variables
        ["X-Request-ID"] = "request_id",
        ["X-Correlation-ID"] = "correlation_id",
        ["X-User-ID"] = "user_id",
        
        // Secret references (prefixed with "secret:")
        ["Authorization"] = "secret:api_key",
        ["X-API-Key"] = "secret:service_key"
    }
};
```

**標頭類型：**
* **字面值**：以 `:` 作為前綴，用於靜態標頭值
* **狀態變數**：映射到圖形狀態變數
* **機密參考**：以 `secret:` 作為前綴，用於安全解析

### JSON 正文範本

使用變數替換建立動態請求正文：

```csharp
var complexSchema = new RestToolSchema
{
    // ... other properties
    JsonBodyTemplate = @"{
        ""metadata"": {
            ""request_id"": ""{request_id}"",
            ""timestamp"": ""{timestamp}"",
            ""source"": ""{source}""
        },
        ""data"": {
            ""user"": {
                ""id"": ""{user_id}"",
                ""name"": ""{user_name}"",
                ""email"": ""{user_email}""
            },
            ""preferences"": {user_preferences},
            ""settings"": {
                ""language"": ""{language}"",
                ""timezone"": ""{timezone}"",
                ""notifications"": {notifications_enabled}
            }
        }
    }"
};
```

**範本功能：**
* **變數替換**：`{variable_name}` 語法
* **嵌套物件**：支援複雜的 JSON 結構
* **陣列支援**：直接陣列變數插入
* **條件邏輯**：基本條件式呈現（未來增強）

## 快取和效能

### 回應快取

啟用快取以提高效能並減少 API 呼叫：

```csharp
var cachedSchema = new RestToolSchema
{
    // ... other properties
    CacheEnabled = true,
    CacheTtlSeconds = 3600 // 1 hour
};
```

**快取行為：**
* **快取金鑰**：從 HTTP 方法、URL 和請求正文雜湊生成
* **TTL 管理**：根據架構配置自動過期
* **記憶體效率**：使用具有過期追蹤的並行字典
* **執行緒安全**：支援並行存取以實現高效能場景

**快取配置選項：**
```csharp
// Short-term caching for frequently changing data
var shortCache = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 60 // 1 minute
};

// Long-term caching for stable data
var longCache = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 86400 // 24 hours
};

// Disable caching for dynamic content
var noCache = new RestToolSchema
{
    CacheEnabled = false
};
```

### 快取金鑰生成

快取系統根據請求特性生成唯一金鑰：

```csharp
// Cache key components:
// 1. HTTP method (GET, POST, PUT, DELETE)
// 2. Full URL (base URI + path + query parameters)
// 3. Request body hash (for POST/PUT operations)
// 4. Header values that affect response (optional)

// Example cache key: "GET:https://api.example.com/v1/data?q=test"
// Example cache key: "POST:https://api.example.com/v1/orders:abc123def456"
```

## 逾時和錯誤處理

### 請求逾時

配置每個請求的逾時設定：

```csharp
var timeoutSchema = new RestToolSchema
{
    // ... other properties
    TimeoutSeconds = 15 // 15 second timeout
};
```

**逾時行為：**
* **每個請求**：每個架構可以有不同的逾時值
* **取消**：與圖形執行取消權杖整合
* **回退**：優雅地處理逾時情況
* **記錄**：全面的逾時記錄和遙測

### 錯誤處理

具有詳細診斷的全面錯誤處理：

```csharp
try
{
    var result = await restNode.ExecuteAsync(kernel, arguments, cancellationToken);
    
    // Check response status
    // The RestToolGraphNode stores HTTP metadata in the FunctionResult.Metadata dictionary.
    // Read status code and response body from metadata safely.
    var statusCode = result.Metadata.TryGetValue("status_code", out var scObj) && scObj is int sc ? sc : -1;
    if (statusCode >= 400)
    {
        // Handle error response
        var errorBody = result.Metadata.TryGetValue("response_body", out var ebObj) ? ebObj?.ToString() ?? string.Empty : string.Empty;
        _logger.LogError("API request failed with status {StatusCode}: {ErrorBody}", statusCode, errorBody);
    }
}
catch (HttpRequestException ex)
{
    // Handle HTTP-specific errors
    _logger.LogError(ex, "HTTP request failed: {Message}", ex.Message);
}
catch (TaskCanceledException ex)
{
    // Handle timeout and cancellation
    _logger.LogWarning("Request was cancelled or timed out: {Message}", ex.Message);
}
catch (Exception ex)
{
    // Handle other errors
    _logger.LogError(ex, "Unexpected error during REST operation: {Message}", ex.Message);
}
```

**錯誤類型：**
* **HTTP 錯誤**：狀態碼、網路問題、逾時
* **驗證錯誤**：架構驗證失敗
* **機密解析錯誤**：缺少或無效的機密
* **序列化錯誤**：JSON 解析和格式化問題

## 機密解析

### 機密參考

敏感資料（如 API 金鑰）的安全處理：

```csharp
var secureSchema = new RestToolSchema
{
    // ... other properties
    Headers = 
    {
        ["Authorization"] = "secret:weather_api_key",
        ["X-API-Key"] = "secret:service_api_key"
    }
};
```

**機密類型：**
* **API 金鑰**：`"secret:weather_api_key"`
* **驗證權杖**：`"secret:bearer_token"`
* **連接字串**：`"secret:database_connection"`
* **服務認證**：`"secret:service_username"`

### 機密解析器實作

實作自訂機密解析邏輯：

```csharp
public class AzureKeyVaultSecretResolver : ISecretResolver
{
    private readonly SecretClient _secretClient;
    
    public AzureKeyVaultSecretResolver(SecretClient secretClient)
    {
        _secretClient = secretClient;
    }
    
    public async Task<string?> ResolveSecretAsync(string secretName, CancellationToken cancellationToken = default)
    {
        try
        {
            var secret = await _secretClient.GetSecretAsync(secretName, cancellationToken: cancellationToken);
            return secret.Value.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to resolve secret {SecretName}", secretName);
            return null;
        }
    }
}

// Usage
var secretResolver = new AzureKeyVaultSecretResolver(keyVaultClient);
var restNode = new RestToolGraphNode(schema, httpClient, secretResolver: secretResolver);
```

## 遙測和監控

### 依賴追蹤

監控 REST API 效能和可靠性：

```csharp
var monitoredSchema = new RestToolSchema
{
    // ... other properties
    TelemetryDependencyName = "Weather API"
};
```

**遙測資料：**
* **請求持續時間**：每個 API 呼叫所花費的時間
* **成功率**：成功請求的百分比
* **錯誤模式**：常見的失敗模式和狀態碼
* **效能指標**：回應時間、吞吐量、延遲
* **依賴映射**：服務依賴和關係

### 自訂遙測

實作自訂遙測以進行專門監控：

```csharp
public class CustomTelemetry : IGraphTelemetry
{
    public void TrackDependency(
        string dependencyType,
        string target,
        string name,
        DateTimeOffset startTime,
        TimeSpan duration,
        bool success,
        string resultCode,
        Dictionary<string, string?> properties)
    {
        // Custom telemetry implementation
        var metric = new
        {
            Type = dependencyType,
            Target = target,
            Name = name,
            Duration = duration.TotalMilliseconds,
            Success = success,
            ResultCode = resultCode,
            Properties = properties
        };
        
        // Send to monitoring system
        _monitoringService.TrackMetric(metric);
    }
}

// Usage
var telemetry = new CustomTelemetry();
var restNode = new RestToolGraphNode(schema, httpClient, telemetry: telemetry);
```

## 驗證和架構安全性

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

**驗證功能：**
* **參數存在**：檢查所需參數是否可用
* **類型驗證**：確保參數類型符合期望
* **架構相容性**：根據 REST 架構要求驗證
* **機密可用性**：驗證機密是否可以解析

### 架構驗證

驗證架構的完整性和配置：

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

if (schema.Method == HttpMethod.Post && string.IsNullOrEmpty(schema.JsonBodyTemplate))
    throw new ArgumentException("POST operations should include JSON body template");
```

## 使用範例

### 天氣 API 整合

整合天氣 API 的完整範例：

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
// Results are returned in the FunctionResult.Metadata dictionary.
var weatherData = result.Metadata.TryGetValue("response_json", out var wj) ? wj : null;
var statusCode = result.Metadata.TryGetValue("status_code", out var ws) && ws is int wsi ? wsi : -1;
```

### 電子商務 API 整合

整合電子商務系統的範例：

```csharp
// 1. Product search schema
var searchSchema = new RestToolSchema
{
    Id = "products.search",
    Name = "Search Products",
    Description = "Search for products in the catalog",
    BaseUri = new Uri("https://api.ecommerce.com"),
    Path = "/v1/products/search",
    Method = HttpMethod.Get,
    QueryParameters = 
    {
        ["q"] = "search_term",
        ["category"] = "category_id",
        ["price_min"] = "min_price",
        ["price_max"] = "max_price",
        ["sort"] = "sort_order",
        ["limit"] = "result_limit"
    },
    CacheEnabled = true,
    CacheTtlSeconds = 300, // 5 minutes
    TimeoutSeconds = 15
};

// 2. Order creation schema
var orderSchema = new RestToolSchema
{
    Id = "orders.create",
    Name = "Create Order",
    Description = "Create a new order",
    BaseUri = new Uri("https://api.ecommerce.com"),
    Path = "/v1/orders",
    Method = HttpMethod.Post,
    JsonBodyTemplate = @"{
        ""customer_id"": ""{customer_id}"",
        ""items"": {cart_items},
        ""shipping_address"": {
            ""street"": ""{street}"",
            ""city"": ""{city}"",
            ""postal_code"": ""{postal_code}""
        },
        ""payment_method"": ""{payment_method}""
    }",
    Headers = 
    {
        ["Content-Type"] = ":application/json",
        ["Authorization"] = "Bearer {auth_token}",
        ["X-Request-ID"] = "request_id"
    },
    CacheEnabled = false, // POST operations not cached
    TimeoutSeconds = 30
};

// 3. Create nodes
var searchNode = new RestToolGraphNode(searchSchema, httpClient, secretResolver: secretResolver);
var orderNode = new RestToolGraphNode(orderSchema, httpClient, secretResolver: secretResolver);

// 4. Build workflow
var workflow = new GraphExecutor("ecommerce-workflow");
workflow.AddNode(searchNode)
        .AddNode(orderNode)
        .SetStartNode("products.search");

// 5. Execute workflow
var workflowArgs = new KernelArguments
{
    ["search_term"] = "laptop",
    ["category_id"] = "electronics",
    ["min_price"] = "500",
    ["max_price"] = "2000",
    ["sort_order"] = "price_asc",
    ["result_limit"] = "10"
};

var workflowResult = await workflow.ExecuteAsync(kernel, workflowArgs);
```

## 效能考量

### HTTP 用戶端管理

優化 HTTP 用戶端使用情況以提高效能：

```csharp
// Use HttpClientFactory for proper lifecycle management
var httpClientFactory = serviceProvider.GetRequiredService<IHttpClientFactory>();

// Create named client with specific configuration
var httpClient = httpClientFactory.CreateClient("api-client");

// Configure client settings
httpClient.Timeout = TimeSpan.FromSeconds(30);
httpClient.DefaultRequestHeaders.Add("User-Agent", "MyApp/1.0");

// Use in REST nodes
var restNode = new RestToolGraphNode(schema, httpClient);
```

**最佳實踐：**
* **連接池**：在請求中重複使用 HTTP 連接
* **逾時配置**：為不同的 API 設定適當的逾時
* **重試原則**：實作暫時失敗的重試邏輯
* **斷路器**：為容錯添加斷路器模式

### 快取策略

為不同的資料類型最佳化快取：

```csharp
// Static reference data - long cache
var referenceSchema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 86400 // 24 hours
};

// Semi-dynamic data - medium cache
var semiDynamicSchema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 3600 // 1 hour
};

// Dynamic data - short cache
var dynamicSchema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 60 // 1 minute
};

// Real-time data - no cache
var realTimeSchema = new RestToolSchema
{
    CacheEnabled = false
};
```

## 安全考量

### 機密管理

敏感配置的安全處理：

```csharp
// Use secure secret storage
var secretResolver = new AzureKeyVaultSecretResolver(keyVaultClient);

// Never hardcode secrets in schemas
var secureSchema = new RestToolSchema
{
    // ... other properties
    Headers = 
    {
        ["Authorization"] = "secret:api_key", // Secure reference
        // Avoid: ["Authorization"] = "Bearer hardcoded-token"
    }
};
```

**安全最佳實踐：**
* **機密輪換**：定期輪換 API 金鑰和權杖
* **存取控制**：限制對機密解析服務的存取
* **稽核記錄**：記錄所有機密存取以進行合規
* **加密**：加密靜止和傳輸中的機密

### 資料清理

保護日誌和遙測中的敏感資料：

```csharp
// Sensitive data is automatically sanitized
var sanitizer = new SensitiveDataSanitizer(new SensitiveDataPolicy
{
    SanitizeApiKeys = true,
    SanitizeTokens = true,
    SanitizeUrls = false,
    SanitizeHeaders = new[] { "Authorization", "X-API-Key" }
});

// Apply sanitization to telemetry
var telemetry = new SanitizedTelemetry(originalTelemetry, sanitizer);
var restNode = new RestToolGraphNode(schema, httpClient, telemetry: telemetry);
```

## 另請參閱

* [REST 工具整合](../how-to/rest-tools-integration.md) - REST 工具概念和技術的全面指南
* [工具和擴充](../how-to/tools.md) - 通用工具系統和整合模式
* [Graph 執行器](./graph-executor.md) - 執行 REST 工具節點的核心執行引擎
* [Graph 狀態](./graph-state.md) - REST 工具參數的狀態管理
* [REST API 範例](../../examples/rest-api-example.md) - 展示 REST 工具功能的完整範例
