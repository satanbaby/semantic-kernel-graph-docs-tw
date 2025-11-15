# REST API 範例

此範例演示如何將 Semantic Kernel Graph 工作流程公開為 REST API，使外部系統能夠遠程執行圖表。

## 目標

了解如何在 Semantic Kernel Graph 中為圖表執行建立 REST API，以便：
* 將圖表工作流程公開為 HTTP 端點
* 使用身份驗證啟用遠程圖表執行
* 提供圖表探索和管理 API
* 將圖表執行與網頁應用程式整合
* 透過 HTTP 支援外部系統整合

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* **ASP.NET Core** 開發經驗
* 基本了解 [圖表概念](../concepts/graph-concepts.md) 和 [REST API 整合](../how-to/exposing-rest-apis.md)

## 主要元件

### 概念和技巧

* **REST API 公開**：用於圖表執行和管理的 HTTP 端點
* **圖表註冊表**：可用圖表的集中管理
* **遠程執行**：從外部系統執行圖表
* **身份驗證**：基於 API 金鑰的存取控制
* **服務整合**：與 ASP.NET Core 相依性注入整合

### 核心類別

* `WebApplication`：ASP.NET Core 網頁應用程式主機
* `IGraphRegistry`：用於管理可用圖表的註冊表
* `IGraphExecutorFactory`：用於建立圖表執行器的工廠
* `GraphRestApi`：用於圖表操作的 REST API 服務
* `FunctionGraphNode`：用於工作流程執行的圖表節點

## 執行範例

### 開始使用

此範例演示與 Semantic Kernel Graph 套件的 REST API 整合。下面的程式碼片段說明如何在你自己的應用程式中實現此模式。

## 逐步實現

### 1. 網頁應用程式設定

該範例首先建立一個 ASP.NET Core 網頁應用程式。

```csharp
public static async Task RunAsync(string[] args)
{
    var builder = WebApplication.CreateBuilder(args);

    // 日誌記錄
    builder.Logging.ClearProviders();
    builder.Logging.AddConsole();

    // 服務：Kernel + 圖表服務
    builder.Services.AddKernel().AddGraphSupport(options =>
    {
        options.EnableLogging = true;
        options.EnableMetrics = true;
    });

    // 最小 SK kernel（此範例沒有真實 LLM）
    builder.Services.AddSingleton<Kernel>(_ => Kernel.CreateBuilder().Build());

    // 建立應用程式
    var app = builder.Build();
```

### 2. 服務解析

應用程式從相依性注入容器解析所需的服務。

```csharp
// 解析所需的服務
var registry = app.Services.GetRequiredService<IGraphRegistry>();
var factory = app.Services.GetRequiredService<IGraphExecutorFactory>();
var graphApi = app.Services.GetRequiredService<GraphRestApi>();
var kernel = app.Services.GetRequiredService<Kernel>();
```

### 3. 圖表建立和註冊

建立一個簡單的圖表並進行註冊以進行演示。

```csharp
// 建立一個簡單的圖表並進行註冊。使用與 Kernel 繫結的函式以確保與
// KernelArguments 和 GraphExecutor 運行時的正確整合。
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

### 4. 圖表探索端點

API 提供一個端點以列出所有可用的圖表。

```csharp
// 端點
app.MapGet("/graphs", async () => await graphApi.ListGraphsAsync());
```

### 5. 圖表執行端點

用於執行圖表的主要端點，包含身份驗證。

```csharp
app.MapPost("/graphs/execute", async (ExecuteGraphRequest req, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    var response = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);
    return Results.Json(response);
});
```

### 6. 請求模型

執行請求模型定義了圖表執行請求的結構。

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

執行回應模型定義了圖表執行結果的結構。

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

### 8. 身份驗證和安全

API 實現了基本的 API 金鑰身份驗證以提高安全性。

```csharp
// 從請求標頭中提取 API 金鑰
var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();

// 驗證 API 金鑰（在生產環境中，實現適當的驗證）
if (string.IsNullOrEmpty(apiKey))
{
    return Results.Unauthorized();
}

// 使用身份驗證執行圖表
var response = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);
```

### 9. 錯誤處理

API 包含適用於各種失敗情境的全面錯誤處理。

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

### 10. 圖表管理端點

用於全面圖表管理的其他端點。

```csharp
// 列出所有可用的圖表
app.MapGet("/graphs", async () => await graphApi.ListGraphsAsync());

// 獲取圖表中繼資料
app.MapGet("/graphs/{graphName}", async (string graphName) => 
    await graphApi.GetGraphMetadataAsync(graphName));

// 獲取圖表執行歷史記錄
app.MapGet("/graphs/{graphName}/history", async (string graphName, 
    [FromQuery] int limit = 10) => 
    await graphApi.GetExecutionHistoryAsync(graphName, limit));

// 取消執行中的執行
app.MapPost("/graphs/{graphName}/cancel", async (string graphName, 
    [FromBody] CancelExecutionRequest req) => 
    await graphApi.CancelExecutionAsync(graphName, req.ExecutionId));
```

### 11. 串流支援

API 可以支援長時間執行的圖表的串流執行。

```csharp
// 串流執行端點（SSE 式）。注意：GraphRestApi 不提供
// 串流列舉。此範例演示了一個簡單的伺服器傳送事件
// 模式，它發出「已啟動」事件，執行圖表，然後發出
// 包含最終結果的「已完成」事件。適配器可以實現
// 更豐富的增量串流（如果需要）。
app.MapPost("/graphs/{graphName}/stream", async (string graphName, ExecuteGraphRequest req, HttpContext http) =>
{
    var apiKey = http.Request.Headers["x-api-key"].FirstOrDefault();
    if (string.IsNullOrEmpty(apiKey))
    {
        return Results.Unauthorized();
    }

    // 配置伺服器傳送事件 (SSE) 的回應
    http.Response.Headers.Add("Content-Type", "text/event-stream");
    http.Response.Headers.Add("Cache-Control", "no-cache");
    http.Response.Headers.Add("Connection", "keep-alive");

    await using var writer = new StreamWriter(http.Response.Body);

    // 發出一個簡短的「已啟動」事件，以便客戶端知道執行已開始。
    var startEvent = new { type = "started", graph = graphName };
    await writer.WriteAsync($"data: {JsonSerializer.Serialize(startEvent)}\n\n");
    await writer.FlushAsync();

    try
    {
        // 同步執行（GraphRestApi 中沒有可用的增量串流）
        var execResp = await graphApi.ExecuteAsync(req, apiKey, http.RequestAborted);

        // 發出包含執行結果的完成事件
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

### 12. 配置和選項

API 支援各種配置選項以進行自訂。

```csharp
// 使用選項配置圖表支援
builder.Services.AddKernel().AddGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMetrics = true;
    options.EnableCheckpointing = true;
    options.EnableStreaming = true;
    options.MaxConcurrentExecutions = 10;
    options.DefaultTimeout = TimeSpan.FromMinutes(5);
});

// 配置 REST API 選項
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

該範例產生一個執行中的網頁伺服器，具有：

* 🌐 在 http://localhost:5000 上執行的網頁應用程式
* 📋 用於圖表探索的 GET /graphs 端點
* 🚀 用於圖表執行的 POST /graphs/execute 端點
* 🔐 API 金鑰身份驗證支援
* 📊 圖表執行結果和錯誤處理
* ✅ 完整的圖表管理 REST API

## API 使用範例

### 列出可用的圖表

```bash
curl -X GET http://localhost:5000/graphs
```

### 執行圖表

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

### 獲取圖表中繼資料

```bash
curl -X GET http://localhost:5000/graphs/sample-graph
```

## 疑難排解

### 常見問題

1. **服務解析失敗**：確保所有必需的服務都在 DI 容器中註冊
2. **身份驗證錯誤**：驗證 API 金鑰是否在請求標頭中提供
3. **圖表註冊問題**：檢查圖表在 API 公開前是否正確註冊
4. **執行失敗**：監控圖表執行日誌和錯誤回應

### 調試提示

* 啟用詳細的服務解析和圖表執行日誌記錄
* 監控 HTTP 請求/回應日誌以進行 API 調試
* 驗證圖表在註冊表中的註冊和可用性
* 檢查身份驗證和授權配置

## 另請參閱

* [公開 REST API](../how-to/exposing-rest-apis.md)
* [圖表註冊表](../concepts/graph-registry.md)
* [服務整合](../how-to/integration-and-extensions.md)
* [身份驗證和安全](../how-to/security-and-data.md)
* [串流執行](../concepts/streaming.md)
