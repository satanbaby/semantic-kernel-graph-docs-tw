# 伺服器與 API

SemanticKernel.Graph 提供全面的伺服器基礎設施，包括 REST API、身份驗證、授權、速率限制、Webhook 和 GraphQL 訂閱。本參考涵蓋了完整的伺服器生態系統，用於向外部服務和應用程式公開 Graph 功能。

## GraphRestApi

框架無關的服務層，用於透過 REST 類 API 公開 Graph 執行和檢查。可適配至 ASP.NET 最小 API、控制器或任何 HTTP 框架。

### 建構函式

```csharp
public GraphRestApi(
    IGraphRegistry registry,
    IServiceProvider serviceProvider,
    GraphRestApiOptions? options = null,
    ILogger<GraphRestApi>? logger = null,
    IGraphTelemetry? telemetry = null)
```

**參數：**
* `registry`: Graph 登錄以管理 Graph 定義
* `serviceProvider`: 相依注入服務提供者
* `options`: API 行為的設定選項
* `logger`: 用於診斷的記錄器執行個體
* `telemetry`: 用於指標的可選遙測服務

### 方法

#### Graph 管理

```csharp
/// <summary>
/// 列出已登錄的 Graph。
/// </summary>
public Task<IReadOnlyList<RegisteredGraphInfo>> ListGraphsAsync()

/// <summary>
/// 取得特定 Graph 的資訊。
/// </summary>
public Task<RegisteredGraphInfo?> GetGraphAsync(string graphName)
```

#### Graph 執行

```csharp
/// <summary>
/// 執行 Graph 請求並傳回結構化回應。
/// </summary>
public Task<ExecuteGraphResponse> ExecuteAsync(
    ExecuteGraphRequest request, 
    string? apiKeyHeader = null, 
    CancellationToken cancellationToken = default)

/// <summary>
/// 將執行加入佇列以進行背景處理。
/// </summary>
public Task<EnqueueExecutionResponse> EnqueueAsync(
    EnqueueExecutionRequest request, 
    string? apiKeyHeader = null, 
    CancellationToken cancellationToken = default)
```

#### 執行監控

```csharp
/// <summary>
/// 列出活躍執行項目（含分頁）。
/// </summary>
public Task<ExecutionPageResponse> ListActiveExecutionsAsync(ExecutionPageRequest page)

/// <summary>
/// 取得執行狀態和結果。
/// </summary>
public Task<ExecutionStatusResponse?> GetExecutionStatusAsync(string executionId)

/// <summary>
/// 取消活躍的執行。
/// </summary>
public Task<bool> CancelExecutionAsync(string executionId)
```

#### Graph 檢查

```csharp
/// <summary>
/// 取得 Graph 結構和中繼資料。
/// </summary>
public Task<GraphStructureResponse?> GetGraphStructureAsync(string graphName)

/// <summary>
/// 取得執行指標和效能資料。
/// </summary>
public Task<ExecutionMetricsResponse?> GetExecutionMetricsAsync(string executionId)
```

### 主要功能

* **框架無關**: 適配至任何 HTTP 框架（ASP.NET Core、最小 API 等）
* **身份驗證**: API 金鑰和持有人權杖身份驗證
* **速率限制**: 可設定的請求節流和配額
* **執行佇列**: 具有優先級排程的背景處理
* **冪等性**: 安全的請求重試和去重
* **安全內容**: 請求相關性和租戶隔離
* **Human-in-the-Loop**: 與 HITL 工作流程整合

## GraphRestApiOptions

REST API 行為的設定選項，包括身份驗證、速率限制和執行控制。

### 身份驗證選項

```csharp
public sealed class GraphRestApiOptions
{
    /// <summary>
    /// 用於簡單標頭型身份驗證 ("x-api-key") 的選用 API 金鑰。
    /// </summary>
    public string? ApiKey { get; set; }

    /// <summary>
    /// 當為 true 時，請求必須根據啟用的機制提供有效的身份驗證。
    /// </summary>
    public bool RequireAuthentication { get; set; } = false;

    /// <summary>
    /// 啟用持有人權杖身份驗證（例如 Azure AD）。需要在 DI 中登錄驗證器。
    /// </summary>
    public bool EnableBearerTokenAuth { get; set; } = false;

    /// <summary>
    /// 用於持有人權杖身份驗證的選用必需 OAuth 範圍清單。
    /// </summary>
    public string[]? RequiredScopes { get; set; }

    /// <summary>
    /// 用於持有人權杖身份驗證的選用必需應用程式角色清單。
    /// </summary>
    public string[]? RequiredAppRoles { get; set; }
}
```

### 並行和效能

```csharp
/// <summary>
/// 取得或設定每個程序允許的最大並行執行數。
/// </summary>
public int MaxConcurrentExecutions { get; set; } = 64;

/// <summary>
/// 取得或設定預設執行超時時間。
/// </summary>
public TimeSpan DefaultTimeout { get; set; } = TimeSpan.FromMinutes(2);

/// <summary>
/// 啟用輕量級請求記錄。
/// </summary>
public bool EnableRequestLogging { get; set; } = true;
```

### 速率限制

```csharp
/// <summary>
/// 啟用 API 請求的速率限制。
/// </summary>
public bool EnableRateLimiting { get; set; } = false;

/// <summary>
/// 取得或設定速率限制視窗持續時間。
/// </summary>
public TimeSpan RateLimitWindow { get; set; } = TimeSpan.FromMinutes(1);

/// <summary>
/// 取得或設定全域每個視窗的請求限制。
/// </summary>
public int GlobalRequestsPerWindow { get; set; } = 1000;

/// <summary>
/// 取得或設定每個 API 金鑰每個視窗的請求限制。
/// </summary>
public int PerApiKeyRequestsPerWindow { get; set; } = 100;

/// <summary>
/// 取得或設定每個租戶每個視窗的請求限制。
/// </summary>
public int PerTenantRequestsPerWindow { get; set; } = 50;
```

### 執行佇列

```csharp
/// <summary>
/// 啟用執行佇列以進行背景處理。
/// </summary>
public bool EnableExecutionQueue { get; set; } = false;

/// <summary>
/// 取得或設定最大佇列長度。
/// </summary>
public int QueueMaxLength { get; set; } = 1000;

/// <summary>
/// 取得或設定佇列處理間隔。
/// </summary>
public TimeSpan QueueProcessingInterval { get; set; } = TimeSpan.FromSeconds(1);
```

### 冪等性

```csharp
/// <summary>
/// 啟用冪等性以進行安全的請求重試。
/// </summary>
public bool EnableIdempotency { get; set; } = false;

/// <summary>
/// 取得或設定冪等性視窗持續時間。
/// </summary>
public TimeSpan IdempotencyWindow { get; set; } = TimeSpan.FromMinutes(10);

/// <summary>
/// 取得或設定要快取的冪等性項目的最大數目。
/// </summary>
public int MaxIdempotencyEntries { get; set; } = 10000;
```

### 安全內容

```csharp
/// <summary>
/// 啟用安全內容擴充以進行請求相關性。
/// </summary>
public bool EnableSecurityContextEnrichment { get; set; } = false;

/// <summary>
/// 取得或設定相關性識別碼標頭名稱。
/// </summary>
public string CorrelationIdHeaderName { get; set; } = "X-Correlation-Id";

/// <summary>
/// 取得或設定租戶識別碼標頭名稱。
/// </summary>
public string TenantIdHeaderName { get; set; } = "X-Tenant-Id";
```

## 身份驗證與授權

### API 金鑰身份驗證

使用 `x-api-key` 標頭的簡單標頭型身份驗證：

```csharp
var options = new GraphRestApiOptions
{
    ApiKey = "your-secure-api-key-12345",
    RequireAuthentication = true
};

// 在 HTTP 請求中
// GET /graphs
// x-api-key: your-secure-api-key-12345
```

### 持有人權杖身份驗證

具有範圍和角色驗證的 OAuth 2.0 持有人權杖身份驗證：

```csharp
var options = new GraphRestApiOptions
{
    RequireAuthentication = true,
    EnableBearerTokenAuth = true,
    RequiredScopes = new[] { "graph.execute", "graph.read" },
    RequiredAppRoles = new[] { "GraphUser", "GraphAdmin" }
};

// 在 DI 中登錄驗證器
builder.Services.AddSingleton<IBearerTokenValidator, AzureAdBearerTokenValidator>();

// 在 HTTP 請求中
// GET /graphs
// Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1Ni...
```

### IBearerTokenValidator

用於驗證持有人權杖（含範圍和角色檢查）的介面：

```csharp
public interface IBearerTokenValidator
{
    /// <summary>
    /// 根據實作驗證傳入的持有人權杖。
    /// </summary>
    /// <param name="bearerToken">持有人權杖字串（不含「Bearer 」前置詞）</param>
    /// <param name="requiredScopes">選用必需的 OAuth 範圍</param>
    /// <param name="requiredAppRoles">選用必需的應用程式角色</param>
    /// <param name="cancellationToken">取消權杖</param>
    /// <returns>當權杖有效且包含必需的宣告時傳回 True</returns>
    Task<bool> ValidateAsync(
        string bearerToken, 
        IEnumerable<string>? requiredScopes = null, 
        IEnumerable<string>? requiredAppRoles = null, 
        CancellationToken cancellationToken = default);
}
```

### AzureAdBearerTokenValidator

Azure AD JWT 驗證器實作：

```csharp
public sealed class AzureAdBearerTokenValidator : IBearerTokenValidator
{
    public Task<bool> ValidateAsync(
        string bearerToken,
        IEnumerable<string>? requiredScopes = null,
        IEnumerable<string>? requiredAppRoles = null,
        CancellationToken cancellationToken = default)
    {
        // 僅供文件用途的最簡範例實作。
        // 生產實作必須驗證 JWT 簽名、簽發者、受眾、
        // 過期/nbf 宣告，並驗證必需的範圍和應用程式角色是否存在。
        if (string.IsNullOrWhiteSpace(bearerToken)) return Task.FromResult(false);

        // TODO: 用真實 JWT 驗證取代（例如 Microsoft.IdentityModel.Tokens + OpenID Connect 中繼資料）
        // 這裡我們傳回 true，表示在範例/測試中接受權杖。
        return Task.FromResult(true);
    }
}
```

## 速率限制

### 速率限制設定

在多個層級設定速率限制：

```csharp
var options = new GraphRestApiOptions
{
    EnableRateLimiting = true,
    RateLimitWindow = TimeSpan.FromMinutes(1),
    
    // 全域速率限制
    GlobalRequestsPerWindow = 1000,
    
    // 每個 API 金鑰速率限制
    PerApiKeyRequestsPerWindow = 100,
    
    // 每個租戶速率限制
    PerTenantRequestsPerWindow = 50
};
```

### 速率限制實作

API 實作了滑動視窗速率限制：

* **全域限制**: 所有用戶端的整體 API 請求速率
* **每個 API 金鑰**: 每個個別 API 金鑰的速率限制
* **每個租戶**: 每個租戶/組織的速率限制
* **滑動視窗**: 用於準確速率計算的滾動時間視窗
* **自動清理**: 過期的項目會自動移除

### 速率限制回應

當超過速率限制時：

```json
{
  "executionId": "",
  "graphName": "my-workflow",
  "success": false,
  "error": "Rate limit exceeded (api key)"
}
```

## Webhook

### Webhook 設定

設定 Webhook 以進行外部服務通知：

```csharp
public sealed class WebhookConfiguration
{
    /// <summary>
    /// 取得或設定 Webhook URL。
    /// </summary>
    public string Url { get; set; } = string.Empty;

    /// <summary>
    /// 取得或設定 Webhook 密碼以進行簽名驗證。
    /// </summary>
    public string Secret { get; set; } = string.Empty;

    /// <summary>
    /// 取得或設定要傳送至此 Webhook 的事件類型。
    /// </summary>
    public GraphExecutionEventType[] EventTypes { get; set; } = Array.Empty<GraphExecutionEventType>();

    /// <summary>
    /// 取得或設定失敗傳遞的重試間隔。
    /// </summary>
    public TimeSpan RetryInterval { get; set; } = TimeSpan.FromMinutes(5);

    /// <summary>
    /// 取得或設定重試嘗試的最大次數。
    /// </summary>
    public int MaxRetries { get; set; } = 3;
}
```

### Webhook 服務

用於管理 Webhook 傳遞的服務：

```csharp
public sealed class WebhookService
{
    /// <summary>
    /// 登錄新的 Webhook 設定。
    /// </summary>
    public void RegisterWebhook(WebhookConfiguration configuration);

    /// <summary>
    /// 通知所有已登錄的 Webhook 有關事件。
    /// </summary>
    public Task NotifyWebhooksAsync(GraphExecutionEvent @event);

    /// <summary>
    /// 移除 Webhook 設定。
    /// </summary>
    public void RemoveWebhook(string url);
}
```

### Webhook 事件處理

```csharp
// 為特定事件類型設定 Webhook
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

### Webhook 安全

Webhook 包括安全功能：

* **密碼驗證**: HMAC-SHA256 簽名驗證
* **重試邏輯**: 可設定的重試間隔和最大嘗試次數
* **事件篩選**: 選擇性事件類型傳遞
* **錯誤處理**: 正常的失敗處理和記錄

## GraphQL 訂閱

### GraphQL 綱要

定義 GraphQL 綱要以進行實時訂閱：

```graphql
type GraphExecutionEvent {
  eventId: ID!
  executionId: ID!
  nodeId: ID
  eventType: String!
  timestamp: String!
  data: JSON
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
```

### GraphQL 訂閱服務

用於管理 GraphQL 訂閱的服務：

```csharp
public sealed class GraphQLSubscriptionService
{
    private readonly IGraphExecutionEventStream _eventStream;
    private readonly ILogger<GraphQLSubscriptionService> _logger;
    
    /// <summary>
    /// 訂閱執行事件（含選用篩選）。
    /// </summary>
    public IAsyncEnumerable<GraphExecutionEvent> SubscribeToExecutionEvents(
        string? executionId = null,
        string? nodeId = null,
        GraphExecutionEventType[]? eventTypes = null);

    /// <summary>
    /// 訂閱 Node 狀態更新。
    /// </summary>
    public IAsyncEnumerable<NodeStatus> SubscribeToNodeStatus(
        string executionId, 
        string nodeId);

    /// <summary>
    /// 訂閱執行進度更新。
    /// </summary>
    public IAsyncEnumerable<ExecutionProgress> SubscribeToExecutionProgress(
        string executionId);
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
}
```

## 請求和回應模型

### ExecuteGraphRequest

```csharp
public sealed class ExecuteGraphRequest
{
    /// <summary>
    /// 取得或設定要執行的 Graph 名稱。
    /// </summary>
    public required string GraphName { get; init; }

    /// <summary>
    /// 取得或設定 Graph 執行的輸入變數。
    /// </summary>
    public Dictionary<string, object> Variables { get; init; } = new();

    /// <summary>
    /// 取得或設定用於安全重試的選用冪等性金鑰。
    /// </summary>
    public string? IdempotencyKey { get; init; }

    /// <summary>
    /// 取得或設定執行優先順序（較高的值 = 較高的優先順序）。
    /// </summary>
    public int Priority { get; init; } = 0;

    /// <summary>
    /// 取得或設定執行超時時間。
    /// </summary>
    public TimeSpan? Timeout { get; init; }
}
```

### ExecuteGraphResponse

```csharp
public sealed class ExecuteGraphResponse
{
    /// <summary>
    /// 取得或設定唯一的執行識別碼。
    /// </summary>
    public required string ExecutionId { get; init; }

    /// <summary>
    /// 取得或設定已執行之 Graph 的名稱。
    /// </summary>
    public required string GraphName { get; init; }

    /// <summary>
    /// 取得或設定執行是否成功。
    /// </summary>
    public required bool Success { get; init; }

    /// <summary>
    /// 取得或設定執行結果資料。
    /// </summary>
    public object? Result { get; init; }

    /// <summary>
    /// 取得或設定執行失敗時的錯誤訊息。
    /// </summary>
    public string? Error { get; init; }

    /// <summary>
    /// 取得或設定執行持續時間。
    /// </summary>
    public TimeSpan? Duration { get; init; }

    /// <summary>
    /// 取得或設定執行狀態。
    /// </summary>
    public string Status { get; init; } = "Unknown";
}
```

### EnqueueExecutionRequest

```csharp
public sealed class EnqueueExecutionRequest
{
    /// <summary>
    /// 取得或設定要執行的 Graph 名稱。
    /// </summary>
    public required string GraphName { get; init; }

    /// <summary>
    /// 取得或設定 Graph 執行的輸入變數。
    /// </summary>
    public Dictionary<string, object> Variables { get; init; } = new();

    /// <summary>
    /// 取得或設定執行優先順序（較高的值 = 較高的優先順序）。
    /// </summary>
    public int Priority { get; init; } = 0;

    /// <summary>
    /// 取得或設定選用的冪等性金鑰。
    /// </summary>
    public string? IdempotencyKey { get; init; }

    /// <summary>
    /// 取得或設定用於完成通知的 Webhook URL。
    /// </summary>
    public string? CompletionWebhookUrl { get; init; }
}
```

## 使用範例

### 基本 REST API 設定

```csharp
using SemanticKernel.Graph.Integration;

// 建立 REST API 選項
var apiOptions = new GraphRestApiOptions
{
    ApiKey = "your-api-key",
    MaxConcurrentExecutions = 32,
    EnableRateLimiting = true,
    EnableExecutionQueue = true,
    RequireAuthentication = true
};

// 準備登錄並登錄最小 GraphExecutor 以便 API 可以執行它
var registry = new InMemoryGraphRegistry(); // 或您的 IGraphRegistry 實作
var executor = new SemanticKernel.Graph.Core.GraphExecutor("my-workflow", "Demo workflow");
var startNode = new SimpleNodeExample();
executor.AddNode(startNode).SetStartNode(startNode.NodeId);
await registry.RegisterAsync(executor);

// 建立或取得包含已登錄 Kernel 執行個體的 IServiceProvider（GraphRestApi 需要）
IServiceProvider serviceProvider = /* resolve or build service provider with Kernel registered */;

// 建立 GraphRestApi 執行個體
var graphApi = new GraphRestApi(registry, serviceProvider, apiOptions);

// 執行 Graph（設定 ApiKey 時傳遞 API 金鑰）
var request = new ExecuteGraphRequest
{
    GraphName = "my-workflow",
    Variables = new Dictionary<string, object>
    {
        ["input"] = "Hello, World!",
        ["maxIterations"] = 5
    }
};

var response = await graphApi.ExecuteAsync(request, apiOptions.ApiKey);
Console.WriteLine($"Execution ID: {response.ExecutionId}");
```

### ASP.NET Core 整合

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// 登錄服務
builder.Services.AddSingleton<IGraphRegistry, GraphRegistry>();
builder.Services.AddSingleton<IBearerTokenValidator, AzureAdBearerTokenValidator>();

var app = builder.Build();

// 設定 GraphRestApi
var apiOptions = new GraphRestApiOptions
{
    RequireAuthentication = true,
    EnableBearerTokenAuth = true,
    RequiredScopes = new[] { "graph.execute", "graph.read" },
    EnableRateLimiting = true,
    GlobalRequestsPerWindow = 1000,
    PerApiKeyRequestsPerWindow = 100
};

var graphApi = new GraphRestApi(
    registry: app.Services.GetRequiredService<IGraphRegistry>(),
    serviceProvider: app.Services,
    options: apiOptions
);

// 定義端點
app.MapGet("/graphs", async () => await graphApi.ListGraphsAsync());

app.MapPost("/graphs/execute", async (ExecuteGraphRequest req, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    var response = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);
    return Results.Json(response);
});

app.MapGet("/graphs/executions/{executionId}", async (string executionId) =>
{
    var status = await graphApi.GetExecutionStatusAsync(executionId);
    return status != null ? Results.Json(status) : Results.NotFound();
});
```

### Webhook 整合

```csharp
// 設定 Webhook
var webhookService = new WebhookService(httpClient, logger);

webhookService.RegisterWebhook(new WebhookConfiguration
{
    Url = "https://external-service.com/webhook",
    Secret = "webhook-secret-123",
    EventTypes = new[] 
    { 
        GraphExecutionEventType.ExecutionCompleted,
        GraphExecutionEventType.NodeFailed 
    },
    RetryInterval = TimeSpan.FromMinutes(2),
    MaxRetries = 5
});

// 以 Webhook 通知執行
var request = new EnqueueExecutionRequest
{
    GraphName = "my-workflow",
    Variables = new Dictionary<string, object> { ["input"] = "data" },
    CompletionWebhookUrl = "https://my-service.com/completion"
};

var response = await graphApi.EnqueueAsync(request);
```

### GraphQL 訂閱

```csharp
// 建立訂閱服務
var subscriptionService = new GraphQLSubscriptionService(eventStream, logger);

// 訂閱執行事件
await foreach (var @event in subscriptionService.SubscribeToExecutionEvents(
    executionId: "exec-123",
    eventTypes: new[] { GraphExecutionEventType.NodeCompleted }))
{
    Console.WriteLine($"Node {@event.NodeId} completed at {@event.Timestamp}");
}

// 訂閱執行進度
await foreach (var progress in subscriptionService.SubscribeToExecutionProgress("exec-123"))
{
    Console.WriteLine($"Progress: {progress.Progress:P0} ({progress.CompletedNodes}/{progress.TotalNodes})");
}
```

## 效能考慮

* **連線池**: 對外部服務呼叫使用連線池
* **事件批次處理**: 盡可能批次處理事件以減少額外負荷
* **壓縮**: 為大型事件承載啟用壓縮
* **快取**: 快取頻繁存取的 Graph 定義和結果
* **非同步作業**: 對所有 I/O 作業使用非同步方法
* **速率限制**: 根據您的使用情況設定適當的速率限制

## 安全考慮

* **HTTPS**: 在生產環境中一律使用 HTTPS
* **API 金鑰**: 使用強式、隨機產生的 API 金鑰
* **持有人權杖**: 實作適當的 JWT 驗證和範圍檢查
* **輸入驗證**: 驗證所有輸入參數並清理資料
* **速率限制**: 為每個用戶端/租戶實作適當的速率限制
* **Webhook 安全**: 使用密碼進行 Webhook 簽名驗證

## 監控與觀測

* **指標**: 追蹤 API 使用率、回應時間和錯誤率
* **記錄**: 記錄所有 API 請求和回應以進行偵錯
* **追蹤**: 使用分散式追蹤進行請求相關性
* **健康檢查**: 實作健康檢查端點
* **警示**: 為速率限制違規和錯誤設定警示

## 另請參閱

* [公開 REST API](../how-to/exposing-rest-apis.md) - REST API 實作指南
* [伺服器與 API](../how-to/server-and-apis.md) - 完整伺服器實作指南
* [安全與資料](../how-to/security-and-data.md) - 安全最佳做法
* [串流執行](../concepts/streaming.md) - 實時執行概念
* [Human-in-the-Loop](../how-to/hitl.md) - HITL 整合模式
