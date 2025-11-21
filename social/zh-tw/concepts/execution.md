# 執行

執行定義了圖形的處理方式，包括順序、平行和分散模式。

## 概念與技術

**Graph 執行**: 透過遵循路由規則導航 Graph Node，並執行已定義的操作之過程。

**Execution Cycle**: 執行期間發生的事件序列：Before → Execute → After。

**Checkpointing**: 能夠儲存和還原執行狀態以進行恢復和分析。

## 執行模式

### 順序執行
* **線性處理**: Node 逐個執行
* **尊重相依性**: 根據 Graph 結構排序
* **共享狀態**: 資料從一個 Node 傳遞到下一個
* **簡單偵錯**: 易於追蹤執行流程

### 平行執行 (Fork/Join)
* **同時處理**: 多個 Node 同時執行
* **確定性排程器**: 保證可重複性
* **狀態合併**: 平行執行結果的組合
* **並發控制**: 資源限制和策略

### 分散執行
* **遠端處理**: 在單獨的進程或機器中執行
* **非同步通信**: 組件之間的訊息交換
* **容錯能力**: 從網路或進程故障中恢復
* **負載平衡**: 平衡的工作分佈

## 主要組件

### GraphExecutor
```csharp
// 使用合理的預設值建立設定的 GraphExecutor。
// 這演示了初始化執行器和執行 Graph 的方法。
var executorOptions = new GraphExecutionOptions
{
    // 允許單個 Graph 執行的最長時間
    MaxExecutionTime = TimeSpan.FromMinutes(5),
    // 為恢復場景啟用自動檢查點
    EnableCheckpointing = true,
    // 分支時平行執行的最大 Node 數量
    MaxParallelNodes = 4
};

// 構建執行器（實現可能由庫提供）。
var executor = new GraphExecutor(options: executorOptions);

// 執行 Graph。在庫代碼中使用 ConfigureAwait(false) 以避免
// 在消費者應用程式中捕獲同步化上下文。
var result = await executor.ExecuteAsync(graph, arguments).ConfigureAwait(false);
```

### StreamingGraphExecutor
```csharp
// 建立流式執行器，用於實時監控執行事件。
var streamingOptions = new StreamingExecutionOptions
{
    // 在應用背壓之前要緩衝多少事件
    BufferSize = 1000,
    // 允許執行器在過載時向生產者發送背壓信號
    EnableBackpressure = true,
    // 等待下一個事件超時前的最長時間
    EventTimeout = TimeSpan.FromSeconds(30)
};

var streamingExecutor = new StreamingGraphExecutor(options: streamingOptions);

// 以流式模式執行 Graph 並取得非同步事件串流。
var eventStream = await streamingExecutor.ExecuteStreamingAsync(graph, arguments).ConfigureAwait(false);
```

### CheckpointManager
```csharp
// 設定檢查點管理器以自動保存執行狀態。
var checkpointOptions = new CheckpointOptions
{
    // 定期保存執行狀態以啟用恢復
    AutoCheckpointInterval = TimeSpan.FromSeconds(30),
    // 限制儲存的檢查點以避免無限制的存儲增長
    MaxCheckpoints = 10,
    // 啟用壓縮以減小檢查點大小
    CompressionEnabled = true
};

var checkpointManager = new CheckpointManager(options: checkpointOptions);
```

## Execution Cycle

### Before 階段
```csharp
// "Before" 階段為 Node 執行做準備。
// 典型步驟：驗證輸入、獲取資源和執行中介軟體鉤子。
await node.BeforeExecutionAsync(context).ConfigureAwait(false);

// 範例：驗證必需的輸入存在並儘早拋出清晰的異常。
if (!context.KernelArguments.ContainsKey("input"))
{
    throw new InvalidOperationException("Missing required argument 'input'");
}
```

### Execute 階段
```csharp
// 核心 Node 邏輯在 Execute 階段執行。實現應該是
// 非同步的並傳回可以持久化到狀態的結果物件。
var result = await node.ExecuteAsync(context).ConfigureAwait(false);

// Node 執行後，以決定性和明確的方式應用任何業務特定的狀態更新。
context.State.Set("lastResult", result);
```

### After 階段
```csharp
// After 階段用於釋放資源、執行後處理鉤子
// 和發送指標。盡可能保持執行後邏輯為冪等。
await node.AfterExecutionAsync(context).ConfigureAwait(false);

// 範例：釋放瞬時許可或記錄完成指標
// （實際實現取決於註冊的指標提供程式）。
```

## 狀態管理

### Execution State
```csharp
// 強型別執行狀態捕獲執行時位置、變數
// 和任何用於偵錯或恢復執行的後設資料。
var executionState = new ExecutionState
{
    // 目前執行中的 Node 識別碼
    CurrentNode = nodeId,
    // 到目前為止已訪問的 Node 的有序列表（用於診斷）
    ExecutionPath = new[] { "start", "process", "current" },
    // 跨 Node 持久化的任意變數；偏好明確的鍵
    Variables = new Dictionary<string, object>(StringComparer.Ordinal)
    {
        ["input"] = "initial-value"
    },
    // 工具和分析的選擇性後設資料
    Metadata = new ExecutionMetadata()
};
```

### Execution History
```csharp
// History 物件記錄步驟序列和時序資訊，用於
// 事後分析和指標報告。
var executionHistory = new ExecutionHistory
{
    Steps = new List<ExecutionStep>(),
    Timestamps = new List<DateTime>(),
    PerformanceMetrics = new Dictionary<string, TimeSpan>(StringComparer.Ordinal)
};
```

## 恢復和檢查點

### 儲存狀態
```csharp
// 保存目前執行狀態，以便稍後恢復或檢查執行。
// 檢查點管理器負責序列化和儲存。
var checkpoint = await checkpointManager.CreateCheckpointAsync(
    graphId: graph.Id,
    executionId: context.ExecutionId,
    state: context.State
.).ConfigureAwait(false);

Console.WriteLine($"Checkpoint saved (id={checkpoint.Id})");
```

### 還原狀態
```csharp
// 還原之前儲存的檢查點並繼續執行。還原的
// 上下文應在繼續之前驗證。
var restoredContext = await checkpointManager.RestoreFromCheckpointAsync(
    checkpointId: checkpoint.Id
.).ConfigureAwait(false);

// 可選地驗證還原的上下文
if (restoredContext == null)
{
    throw new InvalidOperationException("Failed to restore checkpoint; context is null.");
}

var resumedResult = await executor.ExecuteAsync(graph, restoredContext).ConfigureAwait(false);
```

## 流式處理和事件

### Execution Events
```csharp
// 執行期間發送的事件提供對執行時的細粒度可見性。
// 消費者可以訂閱串流或保存事件以進行稽核。
var events = new[]
{
    new GraphExecutionEvent
    {
        Type = ExecutionEventType.NodeStarted,
        NodeId = "process",
        Timestamp = DateTime.UtcNow,
        // 在範例中為事件承載使用簡單的匿名物件
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

### 消耗事件
```csharp
// 消耗執行事件的非同步串流。使用 switch 處理
// 不同的事件類型；保持處理程式小且非阻塞。
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

## 設定和選項

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
* **執行時間**: 總延遲和每個 Node
* **輸送量**: 每秒執行的 Node 數量
* **資源利用率**: CPU、記憶體和 I/O
* **成功率**: 成功執行的百分比

### 記錄和追蹤
```csharp
// 範例記錄呼叫。以您偏好的記錄架構取代
// （Microsoft.Extensions.Logging.ILogger 建議用於實際應用程式）。
var logger = new SemanticKernelGraphLogger();

// 記錄執行開始、每個 Node 執行和完成。
logger.LogExecutionStart(graph.Id, context.ExecutionId);
logger.LogNodeExecution(node.Id, context.ExecutionId, stopwatch.Elapsed);
logger.LogExecutionComplete(graph.Id, context.ExecutionId, result);
```

## 另請參閱

* [Execution Model](../concepts/execution-model.md)
* [Checkpointing](../concepts/checkpointing.md)
* [Streaming](../concepts/streaming.md)
* [Metrics and Observability](../how-to/metrics-and-observability.md)
* [Execution Examples](../examples/execution-guide.md)
* [Streaming Execution Examples](../examples/streaming-execution.md)

## 參考

* `GraphExecutor`: 主 Graph 執行器
* `StreamingGraphExecutor`: 具有事件串流的執行器
* `CheckpointManager`: 檢查點管理器
* `GraphExecutionOptions`: 執行選項
* `StreamingExecutionOptions`: 串流選項
* `ExecutionState`: 執行狀態
* `GraphExecutionEvent`: 執行事件
