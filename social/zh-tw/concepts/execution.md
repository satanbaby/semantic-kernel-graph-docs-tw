# 執行

執行定義了圖形的處理方式，包括循序、平行和分散式模式。

## 概念與技術

**圖形執行**：按照路由規則導航圖形節點並執行定義的操作的過程。

**執行週期**：執行期間發生的事件序列：前置 → 執行 → 後置。

**檢查點**：保存和還原執行狀態以供復原和分析的能力。

## 執行模式

### 循序執行
* **線性處理**：節點一個接一個地執行
* **尊重依賴關係**：根據圖形結構的順序
* **共享狀態**：資料從一個節點傳遞到下一個節點
* **簡單除錯**：易於追蹤執行流程

### 平行執行 (Fork/Join)
* **同時處理**：多個節點同時執行
* **確定性排程器**：保證可重複性
* **狀態合併**：合併平行執行結果
* **並發控制**：資源限制和策略

### 分散式執行
* **遠端處理**：在單獨的進程或機器中執行
* **非同步通訊**：組件之間的訊息交換
* **容錯機制**：從網路或進程失敗中復原
* **負載平衡**：均衡的工作分配

## 主要組件

### GraphExecutor
```csharp
// 使用合理的預設值建立已配置的 GraphExecutor。
// 這演示了初始化執行器並執行圖形。
var executorOptions = new GraphExecutionOptions
{
    // 單次圖形執行允許的最大時間
    MaxExecutionTime = TimeSpan.FromMinutes(5),
    // 啟用自動檢查點以進行復原案例
    EnableCheckpointing = true,
    // 分支時以平行方式執行的最大節點數
    MaxParallelNodes = 4
};

// 建構執行器（實現可能由庫提供）。
var executor = new GraphExecutor(options: executorOptions);

// 執行圖形。在庫代碼中使用 ConfigureAwait(false) 以避免
// 在消費者應用程式中捕獲同步化內容。
var result = await executor.ExecuteAsync(graph, arguments).ConfigureAwait(false);
```

### StreamingGraphExecutor
```csharp
// 建立用於執行事件即時監控的串流執行器。
var streamingOptions = new StreamingExecutionOptions
{
    // 套用背壓前要緩衝多少事件
    BufferSize = 1000,
    // 允許執行器在過載時向生產者發出背壓訊號
    EnableBackpressure = true,
    // 等待下一個事件的最長時間，然後逾時
    EventTimeout = TimeSpan.FromSeconds(30)
};

var streamingExecutor = new StreamingGraphExecutor(options: streamingOptions);

// 以串流模式執行圖形並獲得非同步事件串流。
var eventStream = await streamingExecutor.ExecuteStreamingAsync(graph, arguments).ConfigureAwait(false);
```

### CheckpointManager
```csharp
// 設定檢查點管理器以自動持久化執行狀態。
var checkpointOptions = new CheckpointOptions
{
    // 定期保存執行狀態以啟用復原
    AutoCheckpointInterval = TimeSpan.FromSeconds(30),
    // 限制存儲的檢查點以避免無限的存儲增長
    MaxCheckpoints = 10,
    // 啟用壓縮以減少檢查點大小
    CompressionEnabled = true
};

var checkpointManager = new CheckpointManager(options: checkpointOptions);
```

## 執行週期

### 前置階段
```csharp
// "前置"階段為節點執行做準備。
// 典型步驟：驗證輸入、取得資源和執行中介軟體鉤子。
await node.BeforeExecutionAsync(context).ConfigureAwait(false);

// 範例：驗證所需的輸入存在，並及早拋出清晰的例外。
if (!context.KernelArguments.ContainsKey("input"))
{
    throw new InvalidOperationException("Missing required argument 'input'");
}
```

### 執行階段
```csharp
// 核心節點邏輯在執行階段中執行。實現應為
// 非同步的，並返回可以持久化到狀態的結果物件。
var result = await node.ExecuteAsync(context).ConfigureAwait(false);

// 節點執行後，以
// 確定性和明確的方式套用任何業務特定的狀態更新。
context.State.Set("lastResult", result);
```

### 後置階段
```csharp
// 後置階段用於釋放資源、執行後處理鉤子
// 和發出指標。盡可能保持後執行邏輯冪等。
await node.AfterExecutionAsync(context).ConfigureAwait(false);

// 範例：釋放暫時許可證或記錄完成指標
//（實際實現取決於註冊的指標提供者）。
```

## 狀態管理

### 執行狀態
```csharp
// 強型別執行狀態捕獲執行時位置、變數
// 和對於除錯或繼續執行有用的任何中繼資料。
var executionState = new ExecutionState
{
    // 目前執行的節點的識別碼
    CurrentNode = nodeId,
    // 迄今為止訪問的節點的有序清單（用於診斷）
    ExecutionPath = new[] { "start", "process", "current" },
    // 跨節點保存的任意變數；偏好明確的鍵
    Variables = new Dictionary<string, object>(StringComparer.Ordinal)
    {
        ["input"] = "initial-value"
    },
    // 用於工具和分析的選擇性中繼資料
    Metadata = new ExecutionMetadata()
};
```

### 執行歷史
```csharp
// 歷史物件記錄步驟序列和時間資訊以供
// 事後分析和指標報告。
var executionHistory = new ExecutionHistory
{
    Steps = new List<ExecutionStep>(),
    Timestamps = new List<DateTime>(),
    PerformanceMetrics = new Dictionary<string, TimeSpan>(StringComparer.Ordinal)
};
```

## 復原和檢查點

### 保存狀態
```csharp
// 持久化目前的執行狀態，以便之後可以繼續執行或檢查
// 執行。檢查點管理器負責序列化和存儲。
var checkpoint = await checkpointManager.CreateCheckpointAsync(
    graphId: graph.Id,
    executionId: context.ExecutionId,
    state: context.State
.).ConfigureAwait(false);

Console.WriteLine($"Checkpoint saved (id={checkpoint.Id})");
```

### 還原狀態
```csharp
// 還原之前保存的檢查點並繼續執行。還原的
// 內容應在繼續之前驗證。
var restoredContext = await checkpointManager.RestoreFromCheckpointAsync(
    checkpointId: checkpoint.Id
.).ConfigureAwait(false);

// 選擇性地驗證還原的內容
if (restoredContext == null)
{
    throw new InvalidOperationException("Failed to restore checkpoint; context is null.");
}

var resumedResult = await executor.ExecuteAsync(graph, restoredContext).ConfigureAwait(false);
```

## 串流和事件

### 執行事件
```csharp
// 執行期間發出的事件提供對執行時間的細粒度可見性。
// 消費者可以訂閱串流或持久化事件以進行稽核。
var events = new[]
{
    new GraphExecutionEvent
    {
        Type = ExecutionEventType.NodeStarted,
        NodeId = "process",
        Timestamp = DateTime.UtcNow,
        // 在範例中為事件裝載使用簡單的匿名物件
        Data = new { input = "data" }
    },
    new GraphExecutionEvent
    {
        Type = ExecutionEventType.NodeCompleted,
        NodeId = "process",
        Timestamp = DateTime.UtcNow,
        Data = new { output = "result" }
    }
};
```

### 使用事件
```csharp
// 使用非同步執行事件串流。使用交換來處理
// 不同的事件類型；保持處理程式小而不會阻塞。
await foreach (var evt in eventStream.ConfigureAwait(false))
{
    switch (evt.Type)
    {
        case ExecutionEventType.NodeStarted:
            Console.WriteLine($"Node {evt.NodeId} started at {evt.Timestamp:O}");
            break;
        case ExecutionEventType.NodeCompleted:
            Console.WriteLine($"Node {evt.NodeId} completed at {evt.Timestamp:O}");
            break;
        default:
            Console.WriteLine($"Event {evt.Type} for node {evt.NodeId}");
            break;
    }
}
```

## 設定與選項

### GraphExecutionOptions
```csharp
var options = new GraphExecutionOptions
{
    MaxExecutionTime = TimeSpan.FromMinutes(10),
    EnableCheckpointing = true,
    MaxParallelNodes = 8,
    EnableMetrics = true,
    EnableLogging = true,
    RetryPolicy = new ExponentialBackoffRetryPolicy(maxRetries: 3)
};
```

### StreamingExecutionOptions
```csharp
var streamingOptions = new StreamingExecutionOptions
{
    BufferSize = 1000,
    EnableBackpressure = true,
    EventTimeout = TimeSpan.FromSeconds(60),
    BatchSize = 100,
    EnableCompression = true
};
```

## 監控和指標

### 效能指標
* **執行時間**：總延遲和每個節點
* **輸送量**：每秒執行的節點數
* **資源使用率**：CPU、記憶體和 I/O
* **成功率**：成功執行的百分比

### 記錄和追蹤
```csharp
// 記錄呼叫範例。用您偏好的記錄架構取代
//（Microsoft.Extensions.Logging.ILogger 推薦用於實際應用）。
var logger = new SemanticKernelGraphLogger();

// 記錄執行的開始、每個節點的執行和完成。
logger.LogExecutionStart(graph.Id, context.ExecutionId);
logger.LogNodeExecution(node.Id, context.ExecutionId, stopwatch.Elapsed);
logger.LogExecutionComplete(graph.Id, context.ExecutionId, result);
```

## 另請參閱

* [執行模型](../concepts/execution-model.md)
* [檢查點](../concepts/checkpointing.md)
* [串流](../concepts/streaming.md)
* [指標和可觀測性](../how-to/metrics-and-observability.md)
* [執行範例](../examples/execution-guide.md)
* [串流執行範例](../examples/streaming-execution.md)

## 參考資料

* `GraphExecutor`：主要圖形執行器
* `StreamingGraphExecutor`：具有事件串流的執行器
* `CheckpointManager`：檢查點管理器
* `GraphExecutionOptions`：執行選項
* `StreamingExecutionOptions`：串流選項
* `ExecutionState`：執行狀態
* `GraphExecutionEvent`：執行事件
