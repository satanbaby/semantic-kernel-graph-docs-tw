# 伺服器和 API

本指南說明如何透過 REST API、串流端點和整合模式，將 SemanticKernel.Graph 功能公開給外部服務和應用程式。該框架提供了一套全面的 API 層，使外部系統能夠遠端執行圖表、即時監控執行情況，並與事件驅動的架構整合。

## 概覽

SemanticKernel.Graph 提供強大的 API 基礎架構，支援：

* **透過 REST 端點進行遠端圖表執行**，具備身份驗證和速率限制
* **透過 WebSocket、伺服器傳送事件或 HTTP 輪詢進行實時串流**執行事件
* **執行監控**和非同步結果檢索
* **與框架無關的設計**，可適配任何 HTTP 框架（ASP.NET Core、最小 API 等）
* **企業級功能**，包括冪等性、佇列和安全性上下文豐富化

## 核心 REST API 元件

### GraphRestApi：主要 API 服務

`GraphRestApi` 類別提供了一個與框架無關的服務層，可以適配任何 HTTP 框架：

```csharp
using SemanticKernel.Graph.Integration;

var api = new GraphRestApi(
    registry: graphRegistry,
    serviceProvider: serviceProvider,
    options: new GraphRestApiOptions
    {
        ApiKey = "your-api-key",
        MaxConcurrentExecutions = 32,
        EnableRateLimiting = true,
        EnableExecutionQueue = true
    }
);
```

**主要功能：**
* **圖表執行**：執行帶有參數的圖表並檢索結果
* **圖表管理**：列出、註冊和管理圖表定義
* **執行監控**：追蹤執行狀態並檢索結果
* **安全性**：API 金鑰和持有人令牌身份驗證
* **速率限制**：可配置的請求限流和配額
* **執行佇列**：具有優先順序排程的背景處理
* **冪等性**：安全的請求重試和重複資料刪除

### API 配置選項

透過 `GraphRestApiOptions` 配置 REST API 行為：

```csharp
var apiOptions = new GraphRestApiOptions
{
    // 身份驗證
    ApiKey = "your-api-key",
    RequireAuthentication = true,
    EnableBearerTokenAuth = true,
    
    // 並發和效能
    MaxConcurrentExecutions = 64,
    DefaultTimeout = TimeSpan.FromMinutes(5),
    
    // 速率限制
    EnableRateLimiting = true,
    GlobalRequestsPerWindow = 1000,
    PerApiKeyRequestsPerWindow = 100,
    RateLimitWindow = TimeSpan.FromMinutes(1),
    
    // 執行佇列
    EnableExecutionQueue = true,
    QueueMaxLength = 1000,
    
    // 冪等性
    EnableIdempotency = true,
    IdempotencyWindow = TimeSpan.FromMinutes(10),
    
    // 安全性上下文
    EnableSecurityContextEnrichment = true,
    CorrelationIdHeaderName = "X-Correlation-Id"
};
```

## REST API 端點

### 基本圖表操作

```csharp
// 列出已註冊的圖表
app.MapGet("/graphs", async () => await graphApi.ListGraphsAsync());

// 執行圖表
app.MapPost("/graphs/execute", async (ExecuteGraphRequest req, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    var response = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);
    return Results.Json(response);
});

// 將執行加入佇列以進行背景處理
app.MapPost("/graphs/enqueue", async (EnqueueExecutionRequest req, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    var response = await graphApi.EnqueueAsync(req, apiKey, http.RequestAborted);
    return Results.Json(response);
});

// 列出作用中的執行
app.MapGet("/graphs/executions", (ExecutionPageRequest page) => 
    graphApi.ListActiveExecutions(page));
```

### 身份驗證和安全性

API 支援多種身份驗證機制：

```csharp
// API 金鑰身份驗證
var options = new GraphRestApiOptions
{
    ApiKey = "your-secret-key",
    RequireAuthentication = true
};

// 持有人令牌身份驗證 (Azure AD 等)
var options = new GraphRestApiOptions
{
    EnableBearerTokenAuth = true,
    RequiredScopes = new[] { "api://your-app/.default" },
    RequiredAppRoles = new[] { "GraphExecutor" }
};

// 安全性上下文豐富化
var options = new GraphRestApiOptions
{
    EnableSecurityContextEnrichment = true,
    CorrelationIdHeaderName = "X-Correlation-Id"
};
```

## 串流執行

### WebSocket 串流

實作雙向 WebSocket 串流，用於即時執行監控：

```csharp
app.MapGet("/graphs/{graphId}/stream/ws", async (string graphId, HttpContext http) =>
{
    if (http.WebSockets.IsWebSocketRequest)
    {
        using var webSocket = await http.WebSockets.AcceptWebSocketAsync();
        await HandleWebSocketStreamingAsync(graphId, webSocket);
    }
    else
    {
        http.Response.StatusCode = StatusCodes.Status400BadRequest;
    }
});

private async Task HandleWebSocketStreamingAsync(string graphId, WebSocket webSocket)
{
    var executor = GetExecutor(graphId);
    var arguments = new KernelArguments();
    
    var options = new StreamingExecutionOptions
    {
        BufferSize = 5,
        EnableEventCompression = true,
        ProducerBatchSize = 1
    };
    
    var eventStream = executor.ExecuteStreamAsync(arguments, options);
    
    try
    {
        await foreach (var @event in eventStream)
        {
            var eventJson = JsonSerializer.Serialize(@event);
            var buffer = Encoding.UTF8.GetBytes(eventJson);
            
            await webSocket.SendAsync(
                new ArraySegment<byte>(buffer),
                WebSocketMessageType.Text,
                true,
                CancellationToken.None);
        }
    }
    catch (Exception ex)
    {
        var errorMessage = JsonSerializer.Serialize(new { error = ex.Message });
        var buffer = Encoding.UTF8.GetBytes(errorMessage);
        
        await webSocket.SendAsync(
            new ArraySegment<byte>(buffer),
            WebSocketMessageType.Text,
            true,
            CancellationToken.None);
    }
}
```

### 伺服器傳送事件

使用伺服器傳送事件實作單向串流：

```csharp
app.MapGet("/graphs/{graphId}/stream/sse", async (string graphId, HttpContext http) =>
{
    http.Response.Headers.Add("Content-Type", "text/event-stream");
    http.Response.Headers.Add("Cache-Control", "no-cache");
    http.Response.Headers.Add("Connection", "keep-alive");
    
    var executor = GetExecutor(graphId);
    var arguments = new KernelArguments();
    
    var options = new StreamingExecutionOptions
    {
        BufferSize = 10,
        EnableEventCompression = true,
        ProducerBatchSize = 1,
        ProducerFlushInterval = TimeSpan.FromMilliseconds(50)
    };
    
    var eventStream = executor.ExecuteStreamAsync(arguments, options);
    
    await foreach (var @event in eventStream)
    {
        var eventData = JsonSerializer.Serialize(@event);
        var sseMessage = $"data: {eventData}\n\n";
        
        await http.Response.WriteAsync(sseMessage, http.RequestAborted);
        await http.Response.Body.FlushAsync(http.RequestAborted);
        
        if (http.RequestAborted.IsCancellationRequested)
            break;
    }
});
```

### HTTP 輪詢

對於不支援串流的用戶端，實作基於輪詢的事件檢索：

```csharp
app.MapGet("/graphs/{graphId}/stream/poll", async (string graphId, string? lastEventId, HttpContext http) =>
{
    var executor = GetExecutor(graphId);
    var arguments = new KernelArguments();
    
    var options = new StreamingExecutionOptions
    {
        BufferSize = 50,
        EnableCompression = false
    };
    
    var eventStream = executor.ExecuteStreamAsync(kernel, arguments, options);
    var events = new List<GraphExecutionEvent>();
    
    // 收集自上次輪詢以來的事件
    await foreach (var @event in eventStream)
    {
        if (string.IsNullOrEmpty(lastEventId) || 
            string.Compare(@event.EventId, lastEventId, StringComparison.Ordinal) > 0)
        {
            events.Add(@event);
        }
        
        if (events.Count >= 10) break; // 限制批次大小
    }
    
    var response = new PollingResponse
    {
        Events = events,
        LastEventId = events.LastOrDefault()?.EventId,
        HasMore = events.Count >= 10
    };
    
    return Results.Json(response);
});
```

## 執行佇列和背景處理

### 佇列配置

針對長時間執行的作業啟用背景執行處理：

```csharp
var options = new GraphRestApiOptions
{
    EnableExecutionQueue = true,
    QueueMaxLength = 1000,
    QueuePollInterval = TimeSpan.FromMilliseconds(25)
};

// 將執行加入佇列
var enqueueRequest = new EnqueueExecutionRequest
{
    GraphName = "data-processing-graph",
    Arguments = new Dictionary<string, object>
    {
        ["inputFile"] = "large-dataset.csv",
        ["priority"] = 1
    },
    Priority = 1
};

var enqueueResponse = await graphApi.EnqueueAsync(enqueueRequest);
```

### 優先順序排程

執行佇列支援基於優先順序的排程：

```csharp
// 高優先順序執行
var highPriorityRequest = new EnqueueExecutionRequest
{
    GraphName = "urgent-analysis",
    Arguments = new Dictionary<string, object>(),
    Priority = 10  // 數字越大 = 優先順序越高
};

// 低優先順序批次處理
var batchRequest = new EnqueueExecutionRequest
{
    GraphName = "batch-processing",
    Arguments = new Dictionary<string, object>(),
    Priority = 1   // 數字越小 = 優先順序越低
};
```

## 速率限制和限流

### 全域速率限制

配置應用程式範圍內的請求限制：

```csharp
var options = new GraphRestApiOptions
{
    EnableRateLimiting = true,
    GlobalRequestsPerWindow = 1000,
    RateLimitWindow = TimeSpan.FromMinutes(1)
};
```

### 單一 API 金鑰限制

實作單一用戶端速率限制：

```csharp
var options = new GraphRestApiOptions
{
    EnableRateLimiting = true,
    PerApiKeyRequestsPerWindow = 100,
    RateLimitWindow = TimeSpan.FromMinutes(1)
};
```

### 單一租戶限制

支援多租戶速率限制：

```csharp
var options = new GraphRestApiOptions
{
    EnableRateLimiting = true,
    PerTenantRequestsPerWindow = 500,
    RateLimitWindow = TimeSpan.FromMinutes(1)
};

// 在請求中提供租戶上下文
var securityContext = new ApiRequestSecurityContext
{
    TenantId = "tenant-123",
    ApiKeyHeader = "api-key-456"
};

var response = await graphApi.ExecuteWithSecurityAsync(request, securityContext);
```

## 冪等性和請求安全

### 冪等性配置

啟用安全的請求重試和重複資料刪除：

```csharp
var options = new GraphRestApiOptions
{
    EnableIdempotency = true,
    IdempotencyWindow = TimeSpan.FromMinutes(10),
    MaxIdempotencyEntries = 10000
};
```

### 使用冪等性金鑰

```csharp
// 用戶端提供冪等性金鑰
var request = new ExecuteGraphRequest
{
    GraphName = "data-processing",
    Arguments = new Dictionary<string, object>(),
    IdempotencyKey = "unique-request-id-123"
};

// 或透過標題
http.Request.Headers.Add("Idempotency-Key", "unique-request-id-123");
```

## 整合範例

### 最小 API 設定

```csharp
var builder = WebApplication.CreateBuilder(args);

// 新增服務
builder.Services.AddKernel().AddGraphSupport();
builder.Services.AddSingleton<GraphRestApi>();

var app = builder.Build();

// 配置 REST API
var graphApi = app.Services.GetRequiredService<GraphRestApi>();

// REST 端點
app.MapGet("/graphs", () => graphApi.ListGraphsAsync());
app.MapPost("/graphs/execute", async (ExecuteGraphRequest req) => 
    await graphApi.ExecuteAsync(req));

// 串流端點
app.MapGet("/graphs/{graphId}/stream/ws", HandleWebSocketStreaming);
app.MapGet("/graphs/{graphId}/stream/sse", HandleServerSentEvents);

app.Run();
```

### ASP.NET Core 控制器

```csharp
[ApiController]
[Route("api/[controller]")]
public class GraphExecutionController : ControllerBase
{
    private readonly GraphRestApi _graphApi;
    
    public GraphExecutionController(GraphRestApi graphApi)
    {
        _graphApi = graphApi;
    }
    
    [HttpPost("execute")]
    public async Task<IActionResult> ExecuteAsync([FromBody] ExecuteGraphRequest request)
    {
        var apiKey = Request.Headers["x-api-key"].FirstOrDefault();
        var response = await _graphApi.ExecuteAsync(request, apiKey, RequestAborted);
        return Ok(response);
    }
    
    [HttpGet("stream/{graphId}/sse")]
    public async Task<IActionResult> StreamAsync(string graphId)
    {
        Response.Headers.Add("Content-Type", "text/event-stream");
        Response.Headers.Add("Cache-Control", "no-cache");
        
        var executor = GetExecutor(graphId);
        var eventStream = executor.ExecuteStreamAsync(new KernelArguments());
        
        await foreach (var @event in eventStream)
        {
            var eventData = JsonSerializer.Serialize(@event);
            var sseMessage = $"data: {eventData}\n\n";
            
            await Response.WriteAsync(sseMessage, RequestAborted);
            await Response.Body.FlushAsync(RequestAborted);
            
            if (RequestAborted.IsCancellationRequested)
                break;
        }
        
        return new EmptyResult();
    }
}
```

## 最佳實踐

### 效能最佳化

1. **緩衝區大小調整**：根據消費者處理速度選擇適當的緩衝區大小
2. **壓縮**：為高量級串流啟用事件壓縮
3. **批次處理**：使用生產者批處理實現高效的事件傳遞
4. **連線管理**：實作正確的 WebSocket 生命週期管理

### 安全性考量

1. **API 金鑰輪換**：定期輪換 API 金鑰並使用安全存儲
2. **速率限制**：實作適當的限制以防止濫用
3. **輸入驗證**：驗證所有輸入參數並清理資料
4. **HTTPS**：在生產環境中始終使用 HTTPS

### 監控和可觀測性

1. **請求記錄**：啟用請求記錄以進行除錯和稽核追蹤
2. **指標收集**：使用內建指標進行效能監控
3. **相關性 ID**：包括相關性 ID 以進行請求追蹤
4. **健康檢查**：為負載平衡器實作健康檢查端點

### 錯誤處理

1. **優雅降級**：正確處理串流失敗
2. **重試邏輯**：針對瞬時故障實作指數退避
3. **斷路器**：使用斷路器模式處理外部相依性
4. **使用者回饋**：為 API 消費者提供有意義的錯誤訊息

## 概念和技巧

**GraphRestApi**：與框架無關的服務層，為圖表執行、管理和監控提供 REST API 功能。它處理身份驗證、速率限制、執行佇列和冪等性。

**StreamingExecutionOptions**：控制串流行為的配置物件，包括緩衝區大小、壓縮設定和事件篩選。

**GraphExecutionEventStream**：非同步可列舉串流，在處理期間提供對圖表執行事件的即時存取。

**ApiRequestSecurityContext**：安全性上下文物件，封裝 API 請求的身份驗證和授權資訊。

**IdempotencyEntry**：快取項目，確保重複請求返回相同回應，防止意外的副作用。

## 另請參閱

* [串流執行](streaming-quickstart.md) - 了解串流執行模式
* [錯誤處理和復原力](error-handling-and-resilience.md) - 瞭解錯誤處理策略
* [安全性和資料](security-and-data.md) - 安全性最佳實踐和資料保護
* [REST 工具整合](rest-tools-integration.md) - 將外部 REST API 整合到您的圖表中
* [範例：RestApiExample](../examples/rest-api-example.md) - REST API 整合的完整工作範例
