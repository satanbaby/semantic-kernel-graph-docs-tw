# REST 工具

SemanticKernel.Graph 中的 REST 工具系統提供了與外部 REST API 和服務的全面整合功能。它能讓您在圖形工作流程中無縫整合外部 HTTP 端點，並提供內置的驗證、快取和冪等性支援。

## 概述

REST 工具系統由幾個主要元件組成：

* **`RestToolSchema`**：定義 REST API 操作的結構和行為
* **`RestToolGraphNode`**：執行 HTTP 請求的可執行圖形節點
* **`RestToolSchemaConverter`**：將結構描述轉換為可執行的節點
* **`IToolSchemaConverter`**：自訂工具轉換器介面
* **內置快取和冪等性**：效能最佳化和請求安全性

## 核心類別

### RestToolSchema

定義 REST API 操作的契約，具有全面的配置選項：

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

**主要屬性：**
* **`Id`**：REST 工具的唯一標識符
* **`Name`**：使用者友善的工具名稱
* **`Description`**：用途和行為描述
* **`BaseUri`**：遠端服務的基本 URI
* **`Path`**：操作的相對路徑
* **`Method`**：HTTP 方法 (GET、POST、PUT、DELETE 等)
* **`JsonBodyTemplate`**：可選的 JSON 主體範本，支援變數替換
* **`QueryParameters`**：查詢參數與圖形狀態變數的對應
* **`Headers`**：支援字面值和祕密的標頭對應
* **`TimeoutSeconds`**：請求超時時間（秒）
* **`CacheEnabled`**：是否啟用響應快取
* **`CacheTtlSeconds`**：快取存留時間（秒）
* **`TelemetryDependencyName`**：用於遙測追蹤的自訂名稱

### RestToolGraphNode

基於結構描述定義執行 HTTP 請求的可執行圖形節點：

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
* `schema`：定義操作的 REST 工具結構描述
* `httpClient`：用於發出請求的 HTTP 用戶端
* `logger`：可選的日誌記錄器用於診斷
* `secretResolver`：可選的祕密解析器用於敏感資料
* `telemetry`：可選的遙測配接器用於相依性追蹤

**主要功能：**
* **輸入對應**：自動將圖形狀態對應到 HTTP 參數
* **響應處理**：解析 JSON 響應並提供結構化輸出
* **錯誤處理**：具有遙測的全面錯誤處理
* **結構描述驗證**：實現 `ITypedSchemaNode` 以確保型別安全
* **祕密解析**：API 金鑰和敏感資料的安全處理
* **快取**：內置的響應快取，具有可配置的 TTL
* **超時管理**：個別請求的超時處理
* **遙測整合**：用於監控的相依性追蹤

### RestToolSchemaConverter

將 `RestToolSchema` 實例轉換為可執行 `RestToolGraphNode` 實例的預設轉換器：

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
* `logger`：可選的日誌記錄器用於轉換診斷
* `secretResolver`：可選的祕密解析器用於安全操作
* `telemetry`：可選的遙測配接器用於監控

### IToolSchemaConverter

自訂工具結構描述轉換器的介面：

```csharp
public interface IToolSchemaConverter
{
    IGraphNode CreateNode(RestToolSchema schema);
}
```

**用途：**
* 為工具轉換提供可插入的架構
* 針對特殊用途啟用自訂轉換邏輯
* 支援未來超越 REST 的不同工具型別

## 結構描述配置

### 基本 GET 操作

定義用於檢索資料的簡單 GET 操作：

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
        ["q"] = "location",           // 對應到圖形狀態 "location"
        ["key"] = "secret:weather_key" // 透過祕密解析器解析
    },
    Headers = 
    {
        ["User-Agent"] = ":SemanticKernel.Graph/1.0", // 字面值
        ["X-Correlation-ID"] = "correlation_id"        // 對應到圖形狀態
    },
    CacheEnabled = true,
    CacheTtlSeconds = 300, // 5 分鐘
    TimeoutSeconds = 10
};
```

### 帶有 JSON 主體的 POST

定義具有動態主體內容的 POST 操作：

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
    CacheEnabled = false, // POST 操作通常不進行快取
    TimeoutSeconds = 30
};
```

### 帶有動態路徑的 PUT

定義具有路徑參數替換的 PUT 操作：

```csharp
var updateSchema = new RestToolSchema
{
    Id = "users.update",
    Name = "Update User",
    Description = "Update user information",
    BaseUri = new Uri("https://api.users.com"),
    Path = "/v1/users/{user_id}", // 路徑參數
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

## 參數對應

### 查詢參數

將圖形狀態變數對應到 HTTP 查詢參數：

```csharp
var searchSchema = new RestToolSchema
{
    // ... 其他屬性
    QueryParameters = 
    {
        ["q"] = "search_term",        // 對應到圖形狀態 "search_term"
        ["limit"] = "result_limit",    // 對應到圖形狀態 "result_limit"
        ["offset"] = "page_offset",    // 對應到圖形狀態 "page_offset"
        ["sort"] = "sort_order",       // 對應到圖形狀態 "sort_order"
        ["filter"] = "filter_criteria" // 對應到圖形狀態 "filter_criteria"
    }
};
```

**使用方式：**
```csharp
var args = new KernelArguments
{
    ["search_term"] = "machine learning",
    ["result_limit"] = 20,
    ["page_offset"] = 0,
    ["sort_order"] = "relevance",
    ["filter_criteria"] = "recent"
};

// 結果為：?q=machine%20learning&limit=20&offset=0&sort=relevance&filter=recent
```

### 標頭

使用靈活的對應選項配置 HTTP 標頭：

```csharp
var apiSchema = new RestToolSchema
{
    // ... 其他屬性
    Headers = 
    {
        // 字面值 (前綴為 ":")
        ["Content-Type"] = ":application/json",
        ["User-Agent"] = ":MyApp/1.0",
        
        // 圖形狀態變數
        ["X-Request-ID"] = "request_id",
        ["X-Correlation-ID"] = "correlation_id",
        ["X-User-ID"] = "user_id",
        
        // 祕密參考 (前綴為 "secret:")
        ["Authorization"] = "secret:api_key",
        ["X-API-Key"] = "secret:service_key"
    }
};
```

**標頭型別：**
* **字面值**：前綴為 `:` 用於靜態標頭值
* **狀態變數**：對應到圖形狀態變數
* **祕密參考**：前綴為 `secret:` 用於安全解析

### JSON 主體範本

使用變數替換建立動態請求主體：

```csharp
var complexSchema = new RestToolSchema
{
    // ... 其他屬性
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
* **巢狀物件**：支援複雜的 JSON 結構
* **陣列支援**：直接陣列變數插入
* **條件邏輯**：基本條件式呈現 (未來增強功能)

## 快取和效能

### 響應快取

啟用快取以提升效能並減少 API 呼叫：

```csharp
var cachedSchema = new RestToolSchema
{
    // ... 其他屬性
    CacheEnabled = true,
    CacheTtlSeconds = 3600 // 1 小時
};
```

**快取行為：**
* **快取金鑰**：從 HTTP 方法、URL 和請求主體雜湊生成
* **TTL 管理**：根據結構描述設定自動過期
* **記憶體高效**：使用具有過期追蹤的並行字典
* **執行緒安全**：支援高效能情況下的並行存取

**快取配置選項：**
```csharp
// 短期快取，用於頻繁變化的資料
var shortCache = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 60 // 1 分鐘
};

// 長期快取，用於穩定資料
var longCache = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 86400 // 24 小時
};

// 禁用快取，用於動態內容
var noCache = new RestToolSchema
{
    CacheEnabled = false
};
```

### 快取金鑰生成

快取系統根據請求特性生成唯一金鑰：

```csharp
// 快取金鑰元件：
// 1. HTTP 方法 (GET、POST、PUT、DELETE)
// 2. 完整 URL (基本 URI + 路徑 + 查詢參數)
// 3. 請求主體雜湊 (針對 POST/PUT 操作)
// 4. 影響響應的標頭值 (可選)

// 範例快取金鑰："GET:https://api.example.com/v1/data?q=test"
// 範例快取金鑰："POST:https://api.example.com/v1/orders:abc123def456"
```

## 超時和錯誤處理

### 請求超時

配置個別請求的超時設定：

```csharp
var timeoutSchema = new RestToolSchema
{
    // ... 其他屬性
    TimeoutSeconds = 15 // 15 秒超時
};
```

**超時行為：**
* **個別請求**：每個結構描述可以設定不同的超時值
* **取消**：與圖形執行取消令牌整合
* **後備**：優雅處理超時情況
* **日誌記錄**：全面的超時日誌記錄和遙測

### 錯誤處理

具有詳細診斷的全面錯誤處理：

```csharp
try
{
    var result = await restNode.ExecuteAsync(kernel, arguments, cancellationToken);
    
    // 檢查響應狀態
    // RestToolGraphNode 將 HTTP 中繼資料儲存在 FunctionResult.Metadata 字典中。
    // 安全地從中繼資料讀取狀態碼和響應主體。
    var statusCode = result.Metadata.TryGetValue("status_code", out var scObj) && scObj is int sc ? sc : -1;
    if (statusCode >= 400)
    {
        // 處理錯誤響應
        var errorBody = result.Metadata.TryGetValue("response_body", out var ebObj) ? ebObj?.ToString() ?? string.Empty : string.Empty;
        _logger.LogError("API request failed with status {StatusCode}: {ErrorBody}", statusCode, errorBody);
    }
}
catch (HttpRequestException ex)
{
    // 處理 HTTP 特定錯誤
    _logger.LogError(ex, "HTTP request failed: {Message}", ex.Message);
}
catch (TaskCanceledException ex)
{
    // 處理超時和取消
    _logger.LogWarning("Request was cancelled or timed out: {Message}", ex.Message);
}
catch (Exception ex)
{
    // 處理其他錯誤
    _logger.LogError(ex, "Unexpected error during REST operation: {Message}", ex.Message);
}
```

**錯誤型別：**
* **HTTP 錯誤**：狀態碼、網路問題、超時
* **驗證錯誤**：結構描述驗證失敗
* **祕密解析錯誤**：缺少或無效的祕密
* **序列化錯誤**：JSON 解析和格式化問題

## 祕密解析

### 祕密參考

敏感資料（如 API 金鑰）的安全處理：

```csharp
var secureSchema = new RestToolSchema
{
    // ... 其他屬性
    Headers = 
    {
        ["Authorization"] = "secret:weather_api_key",
        ["X-API-Key"] = "secret:service_api_key"
    }
};
```

**祕密型別：**
* **API 金鑰**：`"secret:weather_api_key"`
* **驗證令牌**：`"secret:bearer_token"`
* **連接字串**：`"secret:database_connection"`
* **服務認證**：`"secret:service_username"`

### 祕密解析器實作

實作自訂祕密解析邏輯：

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

// 使用方式
var secretResolver = new AzureKeyVaultSecretResolver(keyVaultClient);
var restNode = new RestToolGraphNode(schema, httpClient, secretResolver: secretResolver);
```

## 遙測和監控

### 相依性追蹤

監控 REST API 效能和可靠性：

```csharp
var monitoredSchema = new RestToolSchema
{
    // ... 其他屬性
    TelemetryDependencyName = "Weather API"
};
```

**遙測資料：**
* **請求時間**：每個 API 呼叫所需的時間
* **成功率**：成功請求的百分比
* **錯誤模式**：常見故障模式和狀態碼
* **效能指標**：響應時間、吞吐量、延遲
* **相依性對應**：服務相依性和關係

### 自訂遙測

為特殊監控實作自訂遙測：

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
        // 自訂遙測實作
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
        
        // 傳送到監控系統
        _monitoringService.TrackMetric(metric);
    }
}

// 使用方式
var telemetry = new CustomTelemetry();
var restNode = new RestToolGraphNode(schema, httpClient, telemetry: telemetry);
```

## 驗證和結構描述安全性

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

**驗證功能：**
* **參數存在**：檢查所需參數是否可用
* **型別驗證**：確保參數型別符合預期
* **結構描述合規性**：針對 REST 結構描述需求驗證
* **祕密可用性**：驗證祕密可以解析

### 結構描述驗證

驗證結構描述完整性和配置：

```csharp
// 驗證結構描述配置
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
// 1. 定義結構描述
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

// 4. 執行位置
var args = new KernelArguments { ["location"] = "London" };
var result = await graph.ExecuteAsync(kernel, args);

// 5. 處理結果
// 結果以 FunctionResult.Metadata 字典的形式返回。
var weatherData = result.Metadata.TryGetValue("response_json", out var wj) ? wj : null;
var statusCode = result.Metadata.TryGetValue("status_code", out var ws) && ws is int wsi ? wsi : -1;
```

### 電子商務 API 整合

整合電子商務系統的範例：

```csharp
// 1. 產品搜尋結構描述
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
    CacheTtlSeconds = 300, // 5 分鐘
    TimeoutSeconds = 15
};

// 2. 訂單建立結構描述
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
    CacheEnabled = false, // POST 操作不進行快取
    TimeoutSeconds = 30
};

// 3. 建立節點
var searchNode = new RestToolGraphNode(searchSchema, httpClient, secretResolver: secretResolver);
var orderNode = new RestToolGraphNode(orderSchema, httpClient, secretResolver: secretResolver);

// 4. 構建工作流程
var workflow = new GraphExecutor("ecommerce-workflow");
workflow.AddNode(searchNode)
        .AddNode(orderNode)
        .SetStartNode("products.search");

// 5. 執行工作流程
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

最佳化 HTTP 用戶端使用以提升效能：

```csharp
// 使用 HttpClientFactory 進行適當的生命週期管理
var httpClientFactory = serviceProvider.GetRequiredService<IHttpClientFactory>();

// 建立具有特定配置的具名用戶端
var httpClient = httpClientFactory.CreateClient("api-client");

// 配置用戶端設定
httpClient.Timeout = TimeSpan.FromSeconds(30);
httpClient.DefaultRequestHeaders.Add("User-Agent", "MyApp/1.0");

// 在 REST 節點中使用
var restNode = new RestToolGraphNode(schema, httpClient);
```

**最佳實踐：**
* **連接池**：在請求間重複使用 HTTP 連接
* **超時配置**：為不同的 API 設定適當的超時
* **重試原則**：對暫時性故障實作重試邏輯
* **斷路器**：為容錯新增斷路器模式

### 快取策略

針對不同的資料型別最佳化快取：

```csharp
// 靜態參考資料 - 長期快取
var referenceSchema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 86400 // 24 小時
};

// 半動態資料 - 中期快取
var semiDynamicSchema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 3600 // 1 小時
};

// 動態資料 - 短期快取
var dynamicSchema = new RestToolSchema
{
    CacheEnabled = true,
    CacheTtlSeconds = 60 // 1 分鐘
};

// 即時資料 - 無快取
var realTimeSchema = new RestToolSchema
{
    CacheEnabled = false
};
```

## 安全性考量

### 祕密管理

敏感配置的安全處理：

```csharp
// 使用安全的祕密儲存
var secretResolver = new AzureKeyVaultSecretResolver(keyVaultClient);

// 永遠不在結構描述中硬編碼祕密
var secureSchema = new RestToolSchema
{
    // ... 其他屬性
    Headers = 
    {
        ["Authorization"] = "secret:api_key", // 安全參考
        // 避免：["Authorization"] = "Bearer hardcoded-token"
    }
};
```

**安全最佳實踐：**
* **祕密輪換**：定期輪換 API 金鑰和令牌
* **存取控制**：限制對祕密解析服務的存取
* **稽核日誌記錄**：記錄所有祕密存取以符合規範
* **加密**：對靜態和傳輸中的祕密進行加密

### 資料淨化

保護日誌和遙測中的敏感資料：

```csharp
// 敏感資料會自動淨化
var sanitizer = new SensitiveDataSanitizer(new SensitiveDataPolicy
{
    SanitizeApiKeys = true,
    SanitizeTokens = true,
    SanitizeUrls = false,
    SanitizeHeaders = new[] { "Authorization", "X-API-Key" }
});

// 對遙測套用淨化
var telemetry = new SanitizedTelemetry(originalTelemetry, sanitizer);
var restNode = new RestToolGraphNode(schema, httpClient, telemetry: telemetry);
```

## 另請參閱

* [REST 工具整合](../how-to/rest-tools-integration.md) - REST 工具概念和技術的綜合指南
* [工具和擴充](../how-to/tools.md) - 一般工具系統和整合模式
* [圖形執行器](./graph-executor.md) - 執行 REST 工具節點的核心執行引擎
* [圖形狀態](./graph-state.md) - REST 工具參數的狀態管理
* [REST API 範例](../../examples/rest-api-example.md) - 展示 REST 工具功能的完整範例
