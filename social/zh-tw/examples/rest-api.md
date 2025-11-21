# REST API 範例

此範例演示如何將 Semantic Kernel Graph 工作流程公開為 REST API，使外部系統能夠遠程執行 Graph。

## 目標

了解如何在 Semantic Kernel Graph 中為 Graph 執行建立 REST API，以便：
* 將 Graph 工作流程公開為 HTTP 端點
* 使用身份驗證啟用遠程 Graph 執行
* 提供 Graph 發現和管理 API
* 將 Graph 執行與網路應用程式整合
* 透過 HTTP 支持外部系統整合

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph package** 已安裝
* **ASP.NET Core** 開發經驗
* 對 [Graph 概念](../concepts/graph-concepts.md) 和 [REST API 整合](../how-to/exposing-rest-apis.md) 的基本了解

## 關鍵元件

### 概念和技術

* **REST API 公開**：用於 Graph 執行和管理的 HTTP 端點
* **Graph Registry**：可用 Graph 的集中管理
* **遠程執行**：從外部系統執行 Graph
* **身份驗證**：基於 API 金鑰的存取控制
* **服務整合**：與 ASP.NET Core 依賴注入的整合

### 核心類別

* `WebApplication`：ASP.NET Core 網路應用程式主機
* `IGraphRegistry`：用於管理可用 Graph 的 Registry
* `IGraphExecutorFactory`：用於建立 Graph Executor 的 Factory
* `GraphRestApi`：用於 Graph 操作的 REST API 服務
* `FunctionGraphNode`：用於工作流程執行的 Graph Node

## 執行範例

### 開始使用

此範例演示與 Semantic Kernel Graph package 的 REST API 整合。下面的程式碼片段展示如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. 網路應用程式設定

該範例首先建立 ASP.NET Core 網路應用程式。

```csharp
public static async Task RunAsync(string[] args)
{
    var builder = WebApplication.CreateBuilder(args);

    // Logging
    builder.Logging.ClearProviders();
    builder.Logging.AddConsole();

    // Services: Kernel + Graph services
    builder.Services.AddKernel().AddGraphSupport(options =>
    {
        options.EnableLogging = true;
        options.EnableMetrics = true;
    });

    // Minimal SK kernel (no real LLM for the example)
    builder.Services.AddSingleton<Kernel>(_ => Kernel.CreateBuilder().Build());

    // Build app
    var app = builder.Build();
```

### 2. 服務解析

應用程式從依賴注入容器中解析所需的服務。

```csharp
// Resolve required services
var registry = app.Services.GetRequiredService<IGraphRegistry>();
var factory = app.Services.GetRequiredService<IGraphExecutorFactory>();
var graphApi = app.Services.GetRequiredService<GraphRestApi>();
var kernel = app.Services.GetRequiredService<Kernel>();
```

### 3. Graph 建立和註冊

為示範目的建立並註冊簡單的 Graph。

```csharp
// Create a simple graph and register it. Use a Kernel-bound function for correct
// integration with KernelArguments and the GraphExecutor runtime.
var echoFunc = kernel.CreateFunctionFromMethod(
    (KernelArguments args) =>
    {
        var input = args["input"]?.ToString() ?? string.Empty;
        return $"echo:{input}";
    },
    functionName: "echo",
    description: "Echoes the input string");

var echoNode = new FunctionGraphNode(echoFunc, nodeId: "echo");
var graph = new GraphExecutor("sample-graph", "Simple echo graph");
graph.AddNode(echoNode).SetStartNode("echo");

await factory.RegisterAsync(graph);
```

### 4. Graph 發現端點

API 提供用於列出所有可用 Graph 的端點。

```csharp
// Endpoints
app.MapGet("/graphs", async () => await graphApi.ListGraphsAsync());
```

### 5. Graph 執行端點

用於執行具有身份驗證的 Graph 的主要端點。

```csharp
app.MapPost("/graphs/execute", async (ExecuteGraphRequest req, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    var response = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);
    return Results.Json(response);
});
```

### 6. 請求模型

執行請求模型定義 Graph 執行請求的結構。

```csharp
public class ExecuteGraphRequest
{
    public string GraphName { get; set; } = string.Empty;
    public Dictionary<string, object> Variables { get; set; } = new();
    public GraphExecutionOptions? Options { get; set; }
}

public class GraphExecutionOptions
{
    public int? MaxSteps { get; set; }
    public TimeSpan? Timeout { get; set; }
    public bool EnableStreaming { get; set; }
    public string? ExecutionId { get; set; }
}
```

### 7. 回應模型

執行回應模型定義 Graph 執行結果的結構。

```csharp
public class ExecuteGraphResponse
{
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
    public object? Result { get; set; }
    public string ExecutionId { get; set; } = string.Empty;
    public TimeSpan Duration { get; set; }
    public Dictionary<string, object> State { get; set; } = new();
    public List<string> ExecutionPath { get; set; } = new();
}
```

### 8. 身份驗證和安全性

API 為安全實現基本的 API 金鑰身份驗證。

```csharp
// Extract API key from request headers
var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();

// Validate API key (in production, implement proper validation)
if (string.IsNullOrEmpty(apiKey))
{
    return Results.Unauthorized();
}

// Execute graph with authentication
var response = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);
```

### 9. 錯誤處理

API 為各種失敗情景提供全面的錯誤處理。

```csharp
app.MapPost("/graphs/execute", async (ExecuteGraphRequest req, HttpContext http) =>
{
    try
    {
        var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
        
        if (string.IsNullOrEmpty(apiKey))
        {
            return Results.Unauthorized(new { error = "API key required" });
        }

        if (string.IsNullOrEmpty(req.GraphName))
        {
            return Results.BadRequest(new { error = "Graph name is required" });
        }

        var response = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);
        return Results.Json(response);
    }
    catch (Exception ex)
    {
        var logger = http.RequestServices.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Error executing graph {GraphName}", req.GraphName);
        
        return Results.Problem(
            title: "Graph execution failed",
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError
        );
    }
});
```

### 10. Graph 管理端點

用於全面 Graph 管理的其他端點。

```csharp
// List all available graphs
app.MapGet("/graphs", async () => await graphApi.ListGraphsAsync());

// Get graph metadata
app.MapGet("/graphs/{graphName}", async (string graphName) => 
    await graphApi.GetGraphMetadataAsync(graphName));

// Get graph execution history
app.MapGet("/graphs/{graphName}/history", async (string graphName, 
    [FromQuery] int limit = 10) => 
    await graphApi.GetExecutionHistoryAsync(graphName, limit));

// Cancel running execution
app.MapPost("/graphs/{graphName}/cancel", async (string graphName, 
    [FromBody] CancelExecutionRequest req) => 
    await graphApi.CancelExecutionAsync(graphName, req.ExecutionId));
```

### 11. 串流支持

API 可以支持長時間運行 Graph 的串流執行。

```csharp
// Streaming execution endpoint (SSE-style). Note: GraphRestApi does not provide a
// streaming enumerable. This example demonstrates a simple Server-Sent Events
// pattern that emits a "started" event, executes the graph, then emits a
// "completed" event containing the final result. Adaptors may implement
// richer, incremental streaming if needed.
app.MapPost("/graphs/{graphName}/stream", async (string graphName, ExecuteGraphRequest req, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    if (string.IsNullOrEmpty(apiKey))
    {
        return Results.Unauthorized();
    }

    // Configure response for Server-Sent Events (SSE)
    http.Response.Headers.Add("Content-Type", "text/event-stream");
    http.Response.Headers.Add("Cache-Control", "no-cache");
    http.Response.Headers.Add("Connection", "keep-alive");

    await using var writer = new StreamWriter(http.Response.Body);

    // Emit a short "started" event so clients know execution began.
    var startEvent = new { type = "started", graph = graphName };
    await writer.WriteAsync($"data: {JsonSerializer.Serialize(startEvent)}\n\n");
    await writer.FlushAsync();

    try
    {
        // Execute synchronously (no incremental streaming available in GraphRestApi)
        var execResp = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);

        // Emit completion event with execution outcome
        var completeEvent = new
        {
            type = "completed",
            success = execResp.Success,
            executionId = execResp.ExecutionId,
            result = execResp.ResultText,
            error = execResp.Error
        };

        await writer.WriteAsync($"data: {JsonSerializer.Serialize(completeEvent)}\n\n");
        await writer.FlushAsync();
    }
    catch (Exception ex)
    {
        var errorEvent = new { type = "error", message = ex.Message };
        await writer.WriteAsync($"data: {JsonSerializer.Serialize(errorEvent)}\n\n");
        await writer.FlushAsync();
    }

    return Results.Empty;
});
```

### 12. 設定和選項

API 支持各種設定選項以進行自訂。

```csharp
// Configure graph support with options
builder.Services.AddKernel().AddGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMetrics = true;
    options.EnableCheckpointing = true;
    options.EnableStreaming = true;
    options.MaxConcurrentExecutions = 10;
    options.DefaultTimeout = TimeSpan.FromMinutes(5);
});

// Configure REST API options
builder.Services.Configure<GraphRestApiOptions>(options =>
{
    options.EnableAuthentication = true;
    options.RequireApiKey = true;
    options.MaxRequestSize = 1024 * 1024; // 1MB
    options.EnableCors = true;
    options.CorsOrigins = new[] { "http://localhost:3000", "https://myapp.com" };
});
```

## 預期輸出

該範例產生了一個執行中的網路伺服器，具有：

* 🌐 網路應用程式在 http://localhost:5000 上執行
* 📋 GET /graphs 端點用於 Graph 發現
* 🚀 POST /graphs/execute 端點用於 Graph 執行
* 🔐 API 金鑰身份驗證支持
* 📊 Graph 執行結果和錯誤處理
* ✅ 完整的 Graph 管理 REST API

## API 使用範例

### 列出可用 Graph

```bash
curl -X GET http://localhost:5000/graphs
```

### 執行 Graph

```bash
curl -X POST http://localhost:5000/graphs/execute \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{
    "graphName": "sample-graph",
    "variables": {
      "input": "Hello, World!"
    }
  }'
```

### 取得 Graph 中繼資料

```bash
curl -X GET http://localhost:5000/graphs/sample-graph
```

## 故障排除

### 常見問題

1. **服務解析失敗**：確保所有所需的服務都在 DI 容器中註冊
2. **身份驗證錯誤**：驗證 API 金鑰是否在請求標頭中提供
3. **Graph 註冊問題**：檢查 Graph 在 API 公開前是否正確註冊
4. **執行失敗**：監視 Graph 執行日誌和錯誤回應

### 除錯秘訣

* 為服務解析和 Graph 執行啟用詳細日誌
* 監視 HTTP 請求/回應日誌以進行 API 除錯
* 驗證 Registry 中的 Graph 註冊和可用性
* 檢查身份驗證和授權設定

## 另請參閱

* [公開 REST API](../how-to/exposing-rest-apis.md)
* [Graph Registry](../concepts/graph-registry.md)
* [服務整合](../how-to/integration-and-extensions.md)
* [身份驗證和安全性](../how-to/security-and-data.md)
* [串流執行](../concepts/streaming.md)
