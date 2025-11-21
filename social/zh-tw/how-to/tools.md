# 整合工具

本指南說明如何將外部工具和 REST API 整合到您的 SemanticKernel.Graph 工作流程中。您將了解如何使用工具登錄、建立工具結構描述，以及實作自動轉換器以實現無縫整合。

## 概述

工具整合系統可讓您：
* **將外部 API 包裝**為可執行圖表節點
* **自動驗證輸入/輸出結構描述**
* **快取回應**以改善效能
* **處理驗證**和錯誤情境
* **透過標準化結構描述與任何 REST 服務整合**

## 核心元件

### 工具登錄

`IToolRegistry` 提供可用工具的集中管理：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Integration;

// 從您的服務提供者取得工具登錄
var toolRegistry = serviceProvider.GetRequiredService<IToolRegistry>();

// 列出可用的工具
var availableTools = await toolRegistry.ListAsync();
foreach (var tool in availableTools)
{
    Console.WriteLine($"Tool: {tool.Name} - {tool.Description}");
}
```

### 工具結構描述

使用 `RestToolSchema` 定義外部工具的結構和行為：

```csharp
var weatherTool = new RestToolSchema
{
    Id = "weather_api",
    Name = "Weather Service",
    Description = "Get current weather information for a location",
    BaseUri = new Uri("https://api.weatherapi.com/v1"),
    Path = "/current.json",
    Method = HttpMethod.Get,
    QueryParameters = new Dictionary<string, string>
    {
        ["key"] = "{api_key}",
        ["q"] = "{location}",
        ["aqi"] = "no"
    },
    Headers = new Dictionary<string, string>
    {
        ["User-Agent"] = "SemanticKernel.Graph/1.0"
    },
    TimeoutSeconds = 30,
    CacheEnabled = true,
    CacheTtlSeconds = 300 // 5 minutes
};
```

### 工具結構描述轉換器

自動將結構描述轉換為可執行節點：

```csharp
var converter = serviceProvider.GetRequiredService<IToolSchemaConverter>();

// 將結構描述轉換為可執行節點
var weatherNode = converter.ConvertToNode(weatherTool);

// 新增到您的 Graph
graph.AddNode(weatherNode)
     .AddEdge("start", "weather_api")
     .AddEdge("weather_api", "process_weather");
```

## REST API 整合

### 基本 REST 工具

為外部 API 呼叫建立簡單的 REST 工具：

```csharp
var restTool = new RestToolSchema
{
    Id = "external_api",
    Name = "External Service",
    Description = "Call external REST API",
    BaseUri = new Uri("https://api.example.com"),
    Path = "/data",
    Method = HttpMethod.Post,
    JsonBodyTemplate = @"{
        ""user_id"": ""{user_id}"",
        ""action"": ""{action}"",
        ""timestamp"": ""{timestamp}""
    }",
    Headers = new Dictionary<string, string>
    {
        ["Authorization"] = "Bearer {auth_token}",
        ["Content-Type"] = "application/json"
    },
    TimeoutSeconds = 60,
    CacheEnabled = false
};
```

### 動態參數對應

將圖表狀態變數對應到 API 參數：

```csharp
var dynamicTool = new RestToolSchema
{
    Id = "dynamic_api",
    Name = "Dynamic API Call",
    Description = "API with dynamic parameter mapping",
    BaseUri = new Uri("https://api.example.com"),
    Path = "/search",
    Method = HttpMethod.Get,
    QueryParameters = new Dictionary<string, string>
    {
        ["query"] = "{search_term}",
        ["limit"] = "{result_limit}",
        ["offset"] = "{page_offset}",
        ["sort"] = "{sort_order}"
    },
    Headers = new Dictionary<string, string>
    {
        ["X-API-Key"] = "{api_key}",
        ["X-Request-ID"] = "{request_id}"
    }
};
```

## 進階工具模式

### 鏈式工具呼叫

建立可鏈式多個工具呼叫的工作流程：

```csharp
var dataFetchTool = new RestToolSchema
{
    Id = "fetch_data",
    Name = "Data Fetcher",
    Description = "Fetch data from external source",
    BaseUri = new Uri("https://api.datasource.com"),
    Path = "/data/{data_id}",
    Method = HttpMethod.Get
};

var dataProcessTool = new RestToolSchema
{
    Id = "process_data",
    Name = "Data Processor",
    Description = "Process fetched data",
    BaseUri = new Uri("https://api.processor.com"),
    Path = "/process",
    Method = HttpMethod.Post,
    JsonBodyTemplate = @"{
        ""input_data"": ""{fetched_data}"",
        ""processing_options"": ""{processing_options}""
    }"
};

// 在您的 Graph 中鏈式這些工具
graph.AddNode(converter.ConvertToNode(dataFetchTool))
     .AddNode(converter.ConvertToNode(dataProcessTool))
     .AddEdge("start", "fetch_data")
     .AddEdge("fetch_data", "process_data");
```

### 條件式工具執行

使用條件邏輯來決定要執行哪些工具：

```csharp
var highPriorityTool = new RestToolSchema
{
    Id = "high_priority_api",
    Name = "High Priority Service",
    Description = "Fast, premium API service",
    BaseUri = new Uri("https://api.premium.com"),
    Path = "/process",
    Method = HttpMethod.Post,
    TimeoutSeconds = 10
};

var standardTool = new RestToolSchema
{
    Id = "standard_api",
    Name = "Standard Service",
    Description = "Standard API service",
    BaseUri = new Uri("https://api.standard.com"),
    Path = "/process",
    Method = HttpMethod.Post,
    TimeoutSeconds = 30
};

// 根據優先順序路由到不同的工具
graph.AddConditionalEdge("decision", "high_priority_api", 
    condition: state => state.GetString("priority") == "high")
.AddConditionalEdge("decision", "standard_api", 
    condition: state => state.GetString("priority") != "high");
```

### 工具結果處理

處理和轉換工具結果：

```csharp
var resultProcessor = new FunctionGraphNode(
    kernelFunction: (state) => {
        var apiResult = state.GetValue<object>("api_response");
        var processedData = ProcessApiResult(apiResult);
        
        // 儲存處理後的資料
        state["processed_data"] = processedData;
        state["processing_timestamp"] = DateTimeOffset.UtcNow;
        
        return $"Processed {processedData.Count} items";
    },
    nodeId: "process_results"
);

graph.AddEdge("external_api", "process_results")
     .AddEdge("process_results", "next_step");
```

## 驗證和安全性

### API 金鑰驗證

使用 API 金鑰驗證設定工具：

```csharp
var authenticatedTool = new RestToolSchema
{
    Id = "secure_api",
    Name = "Secure API",
    Description = "API requiring authentication",
    BaseUri = new Uri("https://api.secure.com"),
    Path = "/protected",
    Method = HttpMethod.Get,
    Headers = new Dictionary<string, string>
    {
        ["X-API-Key"] = "{api_key}",
        ["Authorization"] = "Bearer {bearer_token}"
    }
};

// 在狀態中儲存敏感認證
var authNode = new FunctionGraphNode(
    kernelFunction: (state) => {
        state["api_key"] = Environment.GetEnvironmentVariable("API_KEY");
        state["bearer_token"] = GetBearerToken();
        return "Authentication configured";
    },
    nodeId: "configure_auth"
);
```

### 機密管理

使用機密解析器進行安全的認證處理：

```csharp
var secretResolver = new EnvironmentSecretResolver();

var secureTool = new RestToolSchema
{
    Id = "secret_api",
    Name = "Secret API",
    Description = "API with secret credentials",
    BaseUri = new Uri("https://api.secret.com"),
    Path = "/secret",
    Method = HttpMethod.Post,
    Headers = new Dictionary<string, string>
    {
        ["X-Secret-Key"] = "{secret_key}"
    }
};

// 機密解析器會自動解析 {secret_key}
var secureNode = converter.ConvertToNode(secureTool, secretResolver);
```

## 快取和效能

### 回應快取

啟用快取以改善效能：

```csharp
var cachedTool = new RestToolSchema
{
    Id = "cached_api",
    Name = "Cached API",
    Description = "API with response caching",
    BaseUri = new Uri("https://api.cacheable.com"),
    Path = "/data",
    Method = HttpMethod.Get,
    CacheEnabled = true,
    CacheTtlSeconds = 600 // 10 minutes
};

// 快取金鑰根據方法、URL 和參數自動產生
var cachedNode = converter.ConvertToNode(cachedTool);
```

### 自訂快取金鑰

實作自訂快取策略：

```csharp
var customCacheTool = new RestToolSchema
{
    Id = "custom_cache_api",
    Name = "Custom Cache API",
    Description = "API with custom caching",
    BaseUri = new Uri("https://api.custom.com"),
    Path = "/custom",
    Method = HttpMethod.Get,
    CacheEnabled = true,
    CacheTtlSeconds = 300
};

// 自訂快取金鑰產生
var customCacheNode = new RestToolGraphNode(customCacheTool, httpClient)
{
    CustomCacheKeyGenerator = (request) => {
        var userId = request.GetValue<string>("user_id");
        var timestamp = DateTimeOffset.UtcNow.Date.ToString("yyyy-MM-dd");
        return $"user_{userId}_date_{timestamp}";
    }
};
```

## 錯誤處理

### 工具錯誤復原

適當地處理工具失敗：

```csharp
var errorHandlingTool = new RestToolSchema
{
    Id = "resilient_api",
    Name = "Resilient API",
    Description = "API with error handling",
    BaseUri = new Uri("https://api.resilient.com"),
    Path = "/resilient",
    Method = HttpMethod.Get,
    TimeoutSeconds = 30
};

var errorHandler = new ErrorHandlerGraphNode(
    errorTypes: new[] { ErrorType.External, ErrorType.Timeout },
    recoveryAction: RecoveryAction.Retry,
    maxRetries: 3,
    nodeId: "tool_error_handler"
);

graph.AddEdge("resilient_api", "tool_error_handler")
     .AddEdge("tool_error_handler", "fallback_service");
```

### 後備工具

在主要工具失敗時提供替代工具：

```csharp
var primaryTool = new RestToolSchema
{
    Id = "primary_api",
    Name = "Primary API",
    Description = "Primary API service",
    BaseUri = new Uri("https://api.primary.com"),
    Path = "/service",
    Method = HttpMethod.Get
};

var fallbackTool = new RestToolSchema
{
    Id = "fallback_api",
    Name = "Fallback API",
    Description = "Fallback API service",
    BaseUri = new Uri("https://api.fallback.com"),
    Path = "/service",
    Method = HttpMethod.Get
};

// 在主要失敗時路由到後備
graph.AddConditionalEdge("primary_api", "success", 
    condition: state => state.GetBool("primary_succeeded", false))
.AddConditionalEdge("primary_api", "fallback_api", 
    condition: state => !state.GetBool("primary_succeeded", false));
```

## 監控和可觀測性

### 工具指標

追蹤工具效能和使用情況：

```csharp
var monitoredTool = new RestToolSchema
{
    Id = "monitored_api",
    Name = "Monitored API",
    Description = "API with performance monitoring",
    BaseUri = new Uri("https://api.monitored.com"),
    Path = "/monitored",
    Method = HttpMethod.Get,
    TelemetryDependencyName = "external_api_service"
};

// 指標會透過 IGraphTelemetry 自動收集
var monitoredNode = converter.ConvertToNode(monitoredTool);
```

### 自訂遙測

為工具實作自訂遙測：

```csharp
var customTelemetryTool = new RestToolSchema
{
    Id = "custom_telemetry_api",
    Name = "Custom Telemetry API",
    Description = "API with custom telemetry",
    BaseUri = new Uri("https://api.telemetry.com"),
    Path = "/telemetry",
    Method = HttpMethod.Get
};

var telemetryNode = new RestToolGraphNode(customTelemetryTool, httpClient)
{
    BeforeExecution = async (context) => {
        context.GraphState["tool_start_time"] = DateTimeOffset.UtcNow;
        context.GraphState["tool_request_id"] = Guid.NewGuid().ToString();
        return Task.CompletedTask;
    },
    AfterExecution = async (context, result) => {
        var startTime = context.GraphState.GetValue<DateTimeOffset>("tool_start_time");
        var duration = DateTimeOffset.UtcNow - startTime;
        
        // 記錄自訂指標
        context.GraphState["tool_duration"] = duration;
        context.GraphState["tool_success"] = result.IsSuccess;
        
        return Task.CompletedTask;
    }
};
```

## 最佳做法

### 工具設計

1. **清晰命名** - 為工具 ID 和描述使用清楚的名稱
2. **參數驗證** - 在工具執行前驗證必要的參數
3. **錯誤處理** - 實作適當的錯誤處理和後備策略
4. **效能最佳化** - 在適當之處使用快取和連線池

### 安全考量

1. **認證管理** - 對敏感資訊使用機密解析器
2. **輸入驗證** - 驗證所有輸入以防止注入攻擊
3. **HTTPS 強制** - 外部 API 呼叫務必使用 HTTPS
4. **速率限制** - 實作速率限制以防止 API 濫用

### 監控和維護

1. **效能追蹤** - 監控工具回應時間和成功率
2. **錯誤記錄** - 記錄所有工具失敗以進行偵錯和改進
3. **健全檢查** - 對重要的外部工具實作健全檢查
4. **文件** - 保持工具結構描述和使用範例最新

## 疑難排解

### 常見問題

**驗證失敗**: 驗證 API 金鑰和持有人權杖是否正確設定

**逾時錯誤**: 檢查網路連線並調整逾時設定

**快取問題**: 驗證快取設定並在需要時清除快取

**參數對應錯誤**: 確保狀態變數與結構描述參數名稱相符

### 偵錯祕訣

1. **啟用詳細記錄**以追蹤工具執行
2. **檢查 HTTP 要求**在網路監視工具中
3. **驗證工具結構描述**執行前
4. **獨立測試工具**以隔離問題

## 概念和技術

**RestToolSchema**: 定義外部 REST API 工具結構和行為的設定物件。它指定 API 端點、HTTP 方法、參數、標頭和快取行為。

**IToolRegistry**: 集中服務，在圖表系統中管理可用工具的註冊、探索和生命週期。

**IToolSchemaConverter**: 服務，自動將工具結構描述轉換為可執行圖表節點，實現外部 API 的無縫整合。

**RestToolGraphNode**: 包裝外部 REST API 呼叫的可執行圖表節點。它處理參數對應、HTTP 要求、回應處理和錯誤處理。

**工具快取**: 效能最佳化機制，儲存 API 回應以避免對相同要求重複呼叫，改善回應時間並減少外部 API 使用。

## 參見

* [REST 工具整合](rest-tools-integration.md) - REST 工具整合的完整指南
* [建立 Graph](build-a-graph.md) - 了解如何使用工具節點建構圖表
* [錯誤處理和復原力](error-handling-and-resilience.md) - 適當地處理工具失敗
* [安全和資料](security-and-data.md) - 安全工具整合做法
* [範例：工具整合](../examples/plugin-system-example.md) - 工具整合的完整工作範例
