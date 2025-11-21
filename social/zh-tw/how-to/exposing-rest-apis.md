# 公開 REST API

本指南說明如何透過 REST API、串流端點、Webhook 和 GraphQL 訂閱公開 SemanticKernel.Graph 功能，以便與外部服務和應用程式進行整合。

## 概述

SemanticKernel.Graph 提供全面的 API 層，能讓外部系統：

* **遠端執行圖形** - 透過具有身份驗證和速率限制的 REST 端點執行
* **即時串流執行事件** - 透過 WebSocket、Server-Sent Events 或 HTTP 輪詢串流
* **監控執行狀態** - 非同步追蹤和擷取結果
* **與 Webhook 整合** - 用於事件驅動架構
* **訂閱 GraphQL 訂閱** - 即時更新和檢查

## 核心 REST API 元件

### GraphRestApi：主要 API 服務

`GraphRestApi` 類別提供與框架無關的服務層，可適配任何 HTTP 框架：

* **Graph Execution** - 使用參數執行 Graph 並擷取結果
* **Graph Management** - 列出、註冊和管理 Graph 定義
* **Execution Monitoring** - 追蹤執行狀態並擷取結果
* **Security** - API 金鑰和 Bearer Token 身份驗證
* **Rate Limiting** - 可配置的請求節流和配額

### API 組態選項

透過 `GraphRestApiOptions` 配置 REST API 行為：

```csharp
using SemanticKernel.Graph.Integration;

var apiOptions = new GraphRestApiOptions
{
    // 身份驗證
    ApiKey = "your-api-key",
    RequireAuthentication = true,
    EnableBearerTokenAuth = true,
    RequiredScopes = new[] { "graph.execute", "graph.read" },
    RequiredAppRoles = new[] { "GraphUser" },
    
    // 速率限制
    EnableRateLimiting = true,
    RateLimitWindow = TimeSpan.FromMinutes(1),
    GlobalRequestsPerWindow = 1000,
    PerApiKeyRequestsPerWindow = 100,
    PerTenantRequestsPerWindow = 50,
    
    // 執行控制
    MaxConcurrentExecutions = 64,
    DefaultTimeout = TimeSpan.FromMinutes(5),
    EnableExecutionQueue = true,
    QueueMaxLength = 1000,
    
    // 冪等性
    EnableIdempotency = true,
    MaxIdempotencyEntries = 10000
};
```

## REST API 端點

### 基本 Graph 操作

#### 列出已註冊的 Graph

```csharp
// GET /graphs
app.MapGet("/graphs", async () => 
{
    var graphs = await graphApi.ListGraphsAsync();
    return Results.Ok(graphs);
});
```

#### 執行 Graph

```csharp
// POST /graphs/execute
app.MapPost("/graphs/execute", async (ExecuteGraphRequest request, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    var response = await graphApi.ExecuteAsync(request, apiKey, http.RequestAborted);
    return Results.Json(response);
});
```

#### 排入執行隊列

```csharp
// POST /graphs/enqueue
app.MapPost("/graphs/enqueue", async (EnqueueExecutionRequest request, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    var response = await graphApi.EnqueueAsync(request, apiKey, http.RequestAborted);
    return Results.Json(response);
});
```

### 請求和回應模型

#### ExecuteGraphRequest

```csharp
var request = new ExecuteGraphRequest
{
    GraphName = "my-workflow",
    Variables = new Dictionary<string, object?>
    {
        ["input"] = "Hello, World!",
        ["user_id"] = "user123",
        ["priority"] = "high"
    },
    StartNodeId = "start-node", // 選擇性
    TimeoutSeconds = 300,       // 選擇性
    IdempotencyKey = "req-123"  // 選擇性
};
```

#### ExecuteGraphResponse

```csharp
var response = new ExecuteGraphResponse
{
    ExecutionId = "exec-456",
    GraphName = "my-workflow",
    Success = true,
    Result = "Processed: Hello, World!",
    ExecutionTime = TimeSpan.FromSeconds(2.5),
    NodeCount = 5
};
```

## 串流執行 API

### 串流 API 介面

`IGraphStreamingApi` 提供串流執行功能：

```csharp
using SemanticKernel.Graph.Streaming;

var streamingApi = serviceProvider.GetService<IGraphStreamingApi>();

// 開始串流執行
var streamingRequest = new StreamingExecutionRequest
{
    Arguments = new Dictionary<string, object>
    {
        ["input"] = "Streaming test"
    },
    Options = new StreamingExecutionOptions
    {
        BufferSize = 10,
        EnableCompression = true,
        ConnectionType = StreamingConnectionType.WebSocket
    }
};

var streamingResponse = await streamingApi.StartExecutionAsync(
    "my-graph", 
    streamingRequest
);
```

### 串流端點

#### WebSocket 串流

```csharp
// GET /graphs/{graphId}/stream/ws
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
    
    var eventStream = executor.ExecuteStreamAsync(kernel, arguments, options);
    
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

#### Server-Sent Events

```csharp
// GET /graphs/{graphId}/stream/sse
app.MapGet("/graphs/{graphId}/stream/sse", async (string graphId, HttpContext http) =>
{
    http.Response.Headers.Add("Content-Type", "text/event-stream");
    http.Response.Headers.Add("Cache-Control", "no-cache");
    http.Response.Headers.Add("Connection", "keep-alive");
    
    var executor = GetExecutor(graphId);
    var arguments = new KernelArguments();
    
    var eventStream = executor.ExecuteStreamAsync(kernel, arguments);
    
    try
    {
        await foreach (var @event in eventStream)
        {
            var eventJson = JsonSerializer.Serialize(@event);
            var sseData = $"data: {eventJson}\n\n";
            
            await http.Response.WriteAsync(sseData);
            await http.Response.Body.FlushAsync();
        }
    }
    catch (Exception ex)
    {
        var errorData = $"data: {{\"error\":\"{ex.Message}\"}}\n\n";
        await http.Response.WriteAsync(errorData);
        await http.Response.Body.FlushAsync();
    }
});
```

#### HTTP 輪詢

```csharp
// GET /graphs/{graphId}/stream/poll
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

## Webhook 整合

### Webhook 組態

為外部服務通知配置 Webhook：

```csharp
public sealed class WebhookConfiguration
{
    public string Url { get; set; } = string.Empty;
    public string Secret { get; set; } = string.Empty;
    public GraphExecutionEventType[] EventTypes { get; set; } = Array.Empty<GraphExecutionEventType>();
    public TimeSpan RetryInterval { get; set; } = TimeSpan.FromMinutes(5);
    public int MaxRetries { get; set; } = 3;
}

public sealed class WebhookService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<WebhookService> _logger;
    private readonly List<WebhookConfiguration> _webhooks = new();
    
    public void RegisterWebhook(WebhookConfiguration config)
    {
        _webhooks.Add(config);
    }
    
    public async Task NotifyWebhooksAsync(GraphExecutionEvent @event)
    {
        var relevantWebhooks = _webhooks.Where(w => 
            w.EventTypes.Contains(@event.EventType)).ToList();
            
        foreach (var webhook in relevantWebhooks)
        {
            await SendWebhookAsync(webhook, @event);
        }
    }
    
    private async Task SendWebhookAsync(WebhookConfiguration webhook, GraphExecutionEvent @event)
    {
        try
        {
            var payload = new
            {
                event_type = @event.EventType.ToString(),
                execution_id = @event.ExecutionId,
                node_id = @event.NodeId,
                timestamp = @event.Timestamp,
                data = @event
            };
            
            var json = JsonSerializer.Serialize(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            // 新增簽名以保障安全性
            var signature = ComputeSignature(json, webhook.Secret);
            content.Headers.Add("X-Webhook-Signature", signature);
            
            var response = await _httpClient.PostAsync(webhook.Url, content);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Webhook delivery failed: {StatusCode}", response.StatusCode);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send webhook to {Url}", webhook.Url);
        }
    }
    
    private string ComputeSignature(string payload, string secret)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(payload));
        return Convert.ToBase64String(hash);
    }
}
```

### Webhook 事件處理

```csharp
// 為特定事件類型配置 Webhook
var webhookService = new WebhookService(httpClient, logger);

webhookService.RegisterWebhook(new WebhookConfiguration
{
    Url = "https://external-service.com/webhook",
    Secret = "webhook-secret-123",
    EventTypes = new[] 
    { 
        GraphExecutionEventType.NodeCompleted,
        GraphExecutionEventType.ExecutionCompleted 
    },
    RetryInterval = TimeSpan.FromMinutes(2),
    MaxRetries = 5
});

// 與串流執行整合
var eventStream = executor.ExecuteStreamAsync(kernel, arguments);

await foreach (var @event in eventStream)
{
    // 在本機處理事件
    await ProcessEventAsync(@event);
    
    // 通知 Webhook
    await webhookService.NotifyWebhooksAsync(@event);
}
```

## GraphQL 訂閱

### GraphQL Schema

定義 GraphQL Schema 以支援即時訂閱：

```graphql
type GraphExecutionEvent {
  eventId: ID!
  executionId: ID!
  nodeId: ID
  eventType: String!
  timestamp: String!
  data: JSON
}

type Subscription {
  graphExecutionEvents(
    executionId: ID
    nodeId: ID
    eventTypes: [String!]
  ): GraphExecutionEvent!
  
  nodeExecutionStatus(
    executionId: ID!
    nodeId: ID!
  ): NodeStatus!
  
  graphExecutionProgress(
    executionId: ID!
  ): ExecutionProgress!
}

type NodeStatus {
  nodeId: ID!
  status: String!
  startTime: String
  endTime: String
  duration: Float
  result: String
  error: String
}

type ExecutionProgress {
  executionId: ID!
  totalNodes: Int!
  completedNodes: Int!
  failedNodes: Int!
  progress: Float!
  estimatedTimeRemaining: Float
}
```

### GraphQL 訂閱實作

```csharp
public sealed class GraphQLSubscriptionService
{
    private readonly IGraphExecutionEventStream _eventStream;
    private readonly ILogger<GraphQLSubscriptionService> _logger;
    
    public IAsyncEnumerable<GraphExecutionEvent> SubscribeToExecutionEvents(
        string? executionId = null,
        string? nodeId = null,
        GraphExecutionEventType[]? eventTypes = null)
    {
        var options = new StreamingExecutionOptions
        {
            BufferSize = 100,
            EnableCompression = true,
            EventTypesToReceive = eventTypes
        };
        
        return _eventStream.GetEventsAsync(executionId, nodeId, options);
    }
    
    public IAsyncEnumerable<NodeStatus> SubscribeToNodeStatus(
        string executionId, 
        string nodeId)
    {
        return SubscribeToExecutionEvents(executionId, nodeId, new[] 
        { 
            GraphExecutionEventType.NodeStarted,
            GraphExecutionEventType.NodeCompleted,
            GraphExecutionEventType.NodeFailed 
        })
        .Select(@event => MapToNodeStatus(@event));
    }
    
    public IAsyncEnumerable<ExecutionProgress> SubscribeToExecutionProgress(
        string executionId)
    {
        return SubscribeToExecutionEvents(executionId, null, new[] 
        { 
            GraphExecutionEventType.NodeStarted,
            GraphExecutionEventType.NodeCompleted,
            GraphExecutionEventType.NodeFailed,
            GraphExecutionEventType.ExecutionCompleted 
        })
        .Buffer(TimeSpan.FromSeconds(1))
        .Select(events => CalculateProgress(executionId, events));
    }
    
    private NodeStatus MapToNodeStatus(GraphExecutionEvent @event)
    {
        return new NodeStatus
        {
            NodeId = @event.NodeId ?? string.Empty,
            Status = @event.EventType.ToString(),
            StartTime = @event.Timestamp.ToString("O"),
            // 根據事件類型映射其他屬性
        };
    }
    
    private ExecutionProgress CalculateProgress(string executionId, IEnumerable<GraphExecutionEvent> events)
    {
        // 根據事件批次計算進度
        var totalNodes = events.Count(e => e.EventType == GraphExecutionEventType.NodeStarted);
        var completedNodes = events.Count(e => e.EventType == GraphExecutionEventType.NodeCompleted);
        var failedNodes = events.Count(e => e.EventType == GraphExecutionEventType.NodeFailed);
        
        return new ExecutionProgress
        {
            ExecutionId = executionId,
            TotalNodes = totalNodes,
            CompletedNodes = completedNodes,
            FailedNodes = failedNodes,
            Progress = totalNodes > 0 ? (float)completedNodes / totalNodes : 0f
        };
    }
}
```

## 即時視覺化

### 即時螢光筆

使用 `GraphRealtimeHighlighter` 進行即時執行視覺化：

```csharp
using SemanticKernel.Graph.Core;

var highlighter = new GraphRealtimeHighlighter(
    visualizationEngine, 
    eventStream, 
    logger, 
    options
);

// 訂閱即時更新
highlighter.NodeExecutionStarted += (sender, e) =>
{
    Console.WriteLine($"Node {e.NodeId} started execution");
    // 使用 Node 螢光筆更新 UI
};

highlighter.NodeExecutionCompleted += (sender, e) =>
{
    Console.WriteLine($"Node {e.NodeId} completed in {e.Duration}");
    // 使用完成狀態更新 UI
};

// 開始為執行進行螢光筆標記
await highlighter.StartHighlightingAsync("exec-123");

// 取得即時螢光筆狀態
var highlightState = highlighter.GetHighlightState("exec-123");
```

### WebSocket 視覺化端點

```csharp
// GET /graphs/{graphId}/visualize/ws
app.MapGet("/graphs/{graphId}/visualize/ws", async (string graphId, HttpContext http) =>
{
    if (http.WebSockets.IsWebSocketRequest)
    {
        using var webSocket = await http.WebSockets.AcceptWebSocketAsync();
        await HandleVisualizationWebSocketAsync(graphId, webSocket);
    }
});

private async Task HandleVisualizationWebSocketAsync(string graphId, WebSocket webSocket)
{
    var highlighter = GetHighlighter(graphId);
    
    // 訂閱螢光筆事件
    highlighter.NodeExecutionStarted += async (sender, e) =>
    {
        var highlightEvent = new
        {
            type = "node_started",
            nodeId = e.NodeId,
            timestamp = e.Timestamp,
            executionId = e.ExecutionId
        };
        
        await SendWebSocketMessageAsync(webSocket, highlightEvent);
    };
    
    highlighter.NodeExecutionCompleted += async (sender, e) =>
    {
        var highlightEvent = new
        {
            type = "node_completed",
            nodeId = e.NodeId,
            timestamp = e.Timestamp,
            duration = e.Duration?.TotalMilliseconds,
            result = e.Result
        };
        
        await SendWebSocketMessageAsync(webSocket, highlightEvent);
    };
    
    // 保持連線活動
    var buffer = new byte[1024];
    while (webSocket.State == WebSocketState.Open)
    {
        try
        {
            var result = await webSocket.ReceiveAsync(
                new ArraySegment<byte>(buffer), CancellationToken.None);
                
            if (result.MessageType == WebSocketMessageType.Close)
            {
                await webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, 
                    string.Empty, CancellationToken.None);
            }
        }
        catch
        {
            break;
        }
    }
}

private async Task SendWebSocketMessageAsync(WebSocket webSocket, object message)
{
    try
    {
        var json = JsonSerializer.Serialize(message);
        var buffer = Encoding.UTF8.GetBytes(json);
        
        await webSocket.SendAsync(
            new ArraySegment<byte>(buffer),
            WebSocketMessageType.Text,
            true,
            CancellationToken.None);
    }
    catch
    {
        // 處理連線錯誤
    }
}
```

## 整合範例

### 最小 API 設定

```csharp
var builder = WebApplication.CreateBuilder(args);

// 新增服務
builder.Services.AddKernel().AddGraphSupport();
builder.Services.AddSingleton<GraphRestApi>();
builder.Services.AddSingleton<GraphQLSubscriptionService>();
builder.Services.AddSingleton<WebhookService>();

var app = builder.Build();

// 配置 REST API
var graphApi = app.Services.GetRequiredService<GraphRestApi>();
var subscriptionService = app.Services.GetRequiredService<GraphQLSubscriptionService>();

// REST 端點
app.MapGet("/graphs", () => graphApi.ListGraphsAsync());
app.MapPost("/graphs/execute", async (ExecuteGraphRequest req) => 
    await graphApi.ExecuteAsync(req));

// 串流端點
app.MapGet("/graphs/{graphId}/stream/ws", HandleWebSocketStreaming);
app.MapGet("/graphs/{graphId}/stream/sse", HandleServerSentEvents);

// 視覺化端點
app.MapGet("/graphs/{graphId}/visualize/ws", HandleVisualizationWebSocket);

app.Run();
```

### ASP.NET Core Controller

```csharp
[ApiController]
[Route("api/[controller]")]
public class GraphExecutionController : ControllerBase
{
    private readonly GraphRestApi _graphApi;
    private readonly GraphQLSubscriptionService _subscriptionService;
    
    public GraphExecutionController(
        GraphRestApi graphApi,
        GraphQLSubscriptionService subscriptionService)
    {
        _graphApi = graphApi;
        _subscriptionService = subscriptionService;
    }
    
    [HttpGet]
    public async Task<ActionResult<IEnumerable<RegisteredGraphInfo>>> ListGraphs()
    {
        var graphs = await _graphApi.ListGraphsAsync();
        return Ok(graphs);
    }
    
    [HttpPost("execute")]
    public async Task<ActionResult<ExecuteGraphResponse>> ExecuteGraph(
        [FromBody] ExecuteGraphRequest request)
    {
        var apiKey = Request.Headers["x-api-key"].FirstOrDefault();
        var response = await _graphApi.ExecuteAsync(request, apiKey, Request.HttpContext.RequestAborted);
        
        if (response.Success)
            return Ok(response);
        else
            return BadRequest(response);
    }
    
    [HttpPost("enqueue")]
    public async Task<ActionResult<EnqueueExecutionResponse>> EnqueueExecution(
        [FromBody] EnqueueExecutionRequest request)
    {
        var apiKey = Request.Headers["x-api-key"].FirstOrDefault();
        var response = await _graphApi.EnqueueAsync(request, apiKey, Request.HttpContext.RequestAborted);
        
        return Ok(response);
    }
    
    [HttpGet("{executionId}/status")]
    public async Task<ActionResult<ExecutionStatusResponse>> GetExecutionStatus(
        string executionId)
    {
        var status = await _graphApi.GetExecutionStatusAsync(executionId);
        return Ok(status);
    }
}
```

## 安全性和身份驗證

### API 金鑰身份驗證

```csharp
var apiOptions = new GraphRestApiOptions
{
    ApiKey = Environment.GetEnvironmentVariable("GRAPH_API_KEY"),
    RequireAuthentication = true
};

// 在中介軟體中
app.Use(async (context, next) =>
{
    var apiKey = context.Request.Headers["x-api-key"].FirstOrDefault();
    
    if (string.IsNullOrEmpty(apiKey) || apiKey != apiOptions.ApiKey)
    {
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        return;
    }
    
    await next();
});
```

### Bearer Token 身份驗證

```csharp
var apiOptions = new GraphRestApiOptions
{
    RequireAuthentication = true,
    EnableBearerTokenAuth = true,
    RequiredScopes = new[] { "graph.execute", "graph.read" },
    RequiredAppRoles = new[] { "GraphUser" }
};

// 註冊 Bearer Token 驗證器
builder.Services.AddSingleton<IBearerTokenValidator, AzureAdBearerTokenValidator>();
```

## 最佳實務

### 效能最佳化

1. **連線集區** - 對外部服務呼叫使用連線集區
2. **事件批次處理** - 盡可能進行批次事件以減少負荷
3. **壓縮** - 為大型事件承載啟用壓縮
4. **快取** - 快取頻繁存取的 Graph 定義和結果

### 安全考量

1. **速率限制** - 為每個用戶端/租用戶實作適當的速率限制
2. **輸入驗證** - 驗證所有輸入參數並清理資料
3. **身份驗證** - 使用強大的身份驗證機制 (API 金鑰、OAuth)
4. **HTTPS** - 在生產環境中一律使用 HTTPS

### 監控和可觀測性

1. **指標** - 追蹤 API 使用、回應時間和錯誤率
2. **日誌記錄** - 記錄所有 API 請求和回應以供偵錯
3. **追蹤** - 使用分散式追蹤進行請求相關性
4. **健康檢查** - 實作健康檢查端點

## 疑難排解

### 常見問題

**WebSocket 連線失敗**
* 檢查 WebSocket 通訊協定支援
* 確認連線升級標頭
* 檢查防火牆和代理設定

**串流效能問題**
* 根據使用者速度調整緩衝區大小
* 為大型承載啟用壓縮
* 監控背壓指標

**身份驗證問題**
* 驗證 API 金鑰格式和有效性
* 檢查 Bearer Token 過期和範圍
* 驗證必要的應用程式角色

### 偵錯提示

1. **啟用詳細日誌記錄** - 使用結構化日誌記錄進行 API 請求
2. **監控事件串流** - 檢查事件串流健康和效能
3. **測試端點** - 使用 Postman 或 curl 等工具測試端點
4. **檢查網路** - 驗證網路連線和防火牆規則

## 另請參閱

* [串流執行](../concepts/streaming.md) - 即時執行和事件串流
* [安全性和資料處理](../how-to/security-and-data.md) - API 安全和身份驗證
* [整合和擴充](../how-to/integration-and-extensions.md) - 核心整合模式
* [API 參考](../api/) - REST 和串流型別的完整 API 文件

## 範例實作和測試

- REST API 整合的可執行範例實作於 `semantic-kernel-graph-docs/examples/RestApiExample.cs`。
- 此範例已編譯並執行以驗證本文件中的程式碼片段，並遵循 C# 最佳實務且附有英文註解。
- 若要從存放庫根目錄執行範例：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- rest-api
```

本文件中的所有程式碼片段皆已檢查以符合經測試的範例。如果您發現不一致之處，請將 `semantic-kernel-graph-docs/examples/RestApiExample.cs` 的範例實作作為正式來源。
