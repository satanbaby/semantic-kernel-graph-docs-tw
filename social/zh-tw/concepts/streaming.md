# 串流執行

SemanticKernel.Graph 中的串流執行能夠進行實時監控和事件驅動的圖形執行處理。本指南解釋如何使用 `IStreamingGraphExecutor`、消費 `GraphExecutionEventStream`、實作篩選器、管理背壓，以及為生產環境設定串流選項。

## 你將學到什麼

* 如何建立和設定 `StreamingGraphExecutor` 以進行實時執行
* 透過 `IGraphExecutionEventStream` 消費執行事件
* 實作事件篩選和緩衝以最佳化效能
* 管理背壓和連線穩定性
* 為不同的生產環境場景設定串流選項
* 建立實時監控和反應型應用程式

## 概念和技術

**串流執行**：圖形的實時執行，具有即時事件發出功能，能進行即時監控和建立反應型應用程式。

**事件串流**：執行事件的非同步串流，提供關於圖形進度、Node 完成和狀態變化的實時更新。

**背壓管理**：內建機制用於控制事件流動和防止消費者被過度淹沒，同時維持系統穩定性。

**事件篩選**：選擇性地消費特定事件類型，以聚焦於相關的執行方面進行監控。

**連線管理**：自動重新連線、心跳監控和連線類型選擇，以實現穩健的串流。

## 前置需求

* 已完成 [執行模型](execution-model.md) 指南
* 已完成 [狀態管理](state.md) 指南
* 對 `GraphExecutor` 和圖形執行的基本理解
* 熟悉非同步程式設計和事件驅動模式

## 核心串流元件

### StreamingGraphExecutor：實時執行

`StreamingGraphExecutor` 使用串流功能包裝標準的圖形執行：

```csharp
using SemanticKernel.Graph.Streaming;

// 建立具有串流功能的執行器
var streamingExecutor = new StreamingGraphExecutor("StreamingDemo", "Real-time execution demo");

// 或轉換現有的 GraphExecutor
var regularExecutor = new GraphExecutor("MyGraph", "Regular graph");
var streamingExecutor2 = regularExecutor.AsStreamingExecutor();

// 如常新增 Node 和設定
streamingExecutor.AddNode(node1);
streamingExecutor.AddNode(node2);
streamingExecutor.Connect("node1", "node2");
streamingExecutor.SetStartNode("node1");
```

### IGraphExecutionEventStream：事件消費

`IGraphExecutionEventStream` 提供對執行事件的非同步疊代：

```csharp
// 使用串流執行
var eventStream = streamingExecutor.ExecuteStreamAsync(kernel, arguments);

// 即時消費事件
await foreach (var @event in eventStream)
{
    switch (@event)
    {
        case GraphExecutionStartedEvent started:
            Console.WriteLine($"Execution started: {started.ExecutionId}");
            break;

        case NodeExecutionStartedEvent nodeStarted:
            Console.WriteLine($"Node started: {nodeStarted.Node.Name}");
            break;

        case NodeExecutionCompletedEvent nodeCompleted:
            Console.WriteLine($"Node completed: {nodeCompleted.Node.Name} in {nodeCompleted.ExecutionDuration.TotalMilliseconds:F0}ms");
            break;

        case GraphExecutionCompletedEvent completed:
            Console.WriteLine($"Execution completed in {completed.TotalDuration.TotalMilliseconds:F0}ms");
            break;
    }
}
```

## 串流設定和選項

### StreamingExecutionOptions：細粒度控制

使用全面的選項設定串流行為：

```csharp
var options = new StreamingExecutionOptions
{
    // 緩衝設定
    BufferSize = 100,                    // 初始緩衝區大小
    MaxBufferSize = 1000,                // 背壓前的最大緩衝區
    
    // 事件篩選
    EventTypesToEmit = new[]
    {
        GraphExecutionEventType.ExecutionStarted,
        GraphExecutionEventType.NodeStarted,
        GraphExecutionEventType.NodeCompleted,
        GraphExecutionEventType.ExecutionCompleted
    },
    
    // 重新連線設定
    EnableAutoReconnect = true,
    MaxReconnectAttempts = 3,
    InitialReconnectDelay = TimeSpan.FromSeconds(1),
    MaxReconnectDelay = TimeSpan.FromSeconds(30),
    
    // 效能最佳化
    ProducerBatchSize = 5,               // 刷新前的批次事件
    ProducerFlushInterval = TimeSpan.FromMilliseconds(100),
    
    // 壓縮和序列化
    EnableEventCompression = true,
    CompressionAlgorithm = CompressionAlgorithm.Gzip,
    CompressionThresholdBytes = 8 * 1024, // 8KB 閾值
    
    // 記憶體管理
    EnableMemoryMappedBuffers = true,
    MemoryMappedFileSizeBytes = 64L * 1024 * 1024, // 64MB
    
    // 監控和指標
    EnableMetrics = true,
    EnableHeartbeat = true,
    HeartbeatInterval = TimeSpan.FromSeconds(30)
};
```

### 設定的擴充方法

使用流暢的設定方法應對常見場景：

```csharp
using SemanticKernel.Graph.Streaming;

// 基本設定
var basicOptions = StreamingExtensions.CreateStreamingOptions()
    .Configure()
    .WithBufferSize(50)
    .WithEventTypes(GraphExecutionEventType.NodeStarted, GraphExecutionEventType.NodeCompleted)
    .Build();

// 高效能設定
var performanceOptions = StreamingExtensions.CreateStreamingOptions()
    .Configure()
    .WithBufferSize(1000)
    .WithMaxBufferSize(10000)
    .WithProducerBatchSize(20)
    .WithProducerFlushInterval(TimeSpan.FromMilliseconds(50))
    .WithCompression(CompressionAlgorithm.Brotli)
    .Build();

// 監控設定
var monitoringOptions = StreamingExtensions.CreateStreamingOptions()
    .Configure()
    .WithEventTypes(GraphExecutionEventType.ExecutionStarted, 
                   GraphExecutionEventType.NodeStarted, 
                   GraphExecutionEventType.NodeCompleted, 
                   GraphExecutionEventType.ExecutionCompleted)
    .WithHeartbeat(TimeSpan.FromSeconds(10))
    .WithMetrics()
    .Build();
```

## 事件類型和處理

### GraphExecutionEvent：事件階層

所有串流事件都繼承自 `GraphExecutionEvent`：

```csharp
// 事件類型列舉
public enum GraphExecutionEventType
{
    ExecutionStarted = 0,        // 圖形執行開始
    NodeStarted = 1,             // Node 執行開始
    NodeCompleted = 2,           // Node 執行完成
    NodeFailed = 3,              // Node 執行失敗
    ExecutionCompleted = 4,      // 圖形執行完成
    ExecutionFailed = 5,         // 圖形執行失敗
    ExecutionCancelled = 6,      // 圖形執行已取消
    NodeEntered = 7,             // 執行器進入 Node
    NodeExited = 8,              // 執行器退出 Node
    ConditionEvaluated = 9,      // 條件表達式已評估
    StateMergeConflictDetected = 10, // 偵測到狀態合併衝突
    CircuitBreakerStateChanged = 11,  // 熔斷器狀態變更
    ResourceBudgetExhausted = 14,     // 資源預算已耗盡
    RetryAttempted = 15,              // 嘗試重試操作
    CheckpointCreated = 16,           // 已建立檢查點
    CheckpointRestored = 17           // 已還原檢查點
}
```

### 事件處理模式

實作不同的事件處理策略：

```csharp
// 全面的事件處理
public class ExecutionMonitor
{
    public async Task MonitorExecutionAsync(IGraphExecutionEventStream eventStream)
    {
        var nodeTimings = new Dictionary<string, TimeSpan>();
        var startTimes = new Dictionary<string, DateTimeOffset>();
        
        await foreach (var @event in eventStream)
        {
            switch (@event)
            {
                case NodeExecutionStartedEvent nodeStarted:
                    startTimes[nodeStarted.Node.Name] = nodeStarted.Timestamp;
                    Console.WriteLine($"🚀 Node started: {nodeStarted.Node.Name}");
                    break;

                case NodeExecutionCompletedEvent nodeCompleted:
                    var duration = nodeCompleted.Timestamp - startTimes[nodeCompleted.Node.Name];
                    nodeTimings[nodeCompleted.Node.Name] = duration;
                    Console.WriteLine($"✅ Node completed: {nodeCompleted.Node.Name} in {duration.TotalMilliseconds:F0}ms");
                    break;

                case NodeExecutionFailedEvent nodeFailed:
                    Console.WriteLine($"❌ Node failed: {nodeFailed.Node.Name} - {nodeFailed.ErrorMessage}");
                    break;

                case GraphExecutionCompletedEvent completed:
                    Console.WriteLine($"🎯 Execution completed in {completed.TotalDuration.TotalMilliseconds:F0}ms");
                    Console.WriteLine("Node performance summary:");
                    foreach (var timing in nodeTimings)
                    {
                        Console.WriteLine($"  {timing.Key}: {timing.Value.TotalMilliseconds:F0}ms");
                    }
                    break;

                case GraphExecutionFailedEvent failed:
                    Console.WriteLine($"💥 Execution failed: {failed.ErrorMessage}");
                    break;
            }
        }
    }
}
```

## 事件篩選和緩衝

### 選擇性事件消費

篩選事件以聚焦於特定執行方面：

```csharp
// 按事件類型篩選
var nodeEvents = eventStream.Filter(GraphExecutionEventType.NodeStarted, GraphExecutionEventType.NodeCompleted);
var errorEvents = eventStream.Filter(GraphExecutionEventType.NodeFailed, GraphExecutionEventType.ExecutionFailed);

// 按 Node ID 篩選
var specificNodeEvents = eventStream.FilterByNode("critical-node");

// 按自訂條件篩選
var longRunningEvents = eventStream.Filter(@event => 
    @event is NodeCompletedEvent completed && 
    completed.Duration > TimeSpan.FromSeconds(5)
);

// 結合篩選
var criticalEvents = eventStream
    .Filter(GraphExecutionEventType.NodeFailed, GraphExecutionEventType.ExecutionFailed)
    .FilterByNode("critical-node");
```

### 事件緩衝和批次處理

使用事件緩衝最佳化效能：

```csharp
// 緩衝事件以進行批次處理
var bufferedStream = eventStream.Buffer(10);

await foreach (var batch in bufferedStream)
{
    Console.WriteLine($"Processing batch of {batch.Count} events");
    
    // 批次處理事件
    foreach (var @event in batch)
    {
        ProcessEvent(@event);
    }
    
    // 模擬批次處理延遲
    await Task.Delay(100);
}

// 基於吞吐量的自適應緩衝
var adaptiveStream = eventStream.WithAdaptiveBuffering(
    minBatchSize: 5,
    maxBatchSize: 50,
    targetLatency: TimeSpan.FromMilliseconds(100)
);
```

## 背壓管理

### 內建背壓控制

串流執行會自動管理背壓：

```csharp
var options = new StreamingExecutionOptions
{
    // 緩衝區大小控制
    BufferSize = 100,                    // 初始緩衝區
    MaxBufferSize = 1000,                // 背壓前的最大值
    
    // 生產者批次處理
    ProducerBatchSize = 5,               // 刷新前的批次
    ProducerFlushInterval = TimeSpan.FromMilliseconds(50),
    
    // 記憶體管理
    EnableMemoryMappedBuffers = true,    // 使用磁碟進行大型緩衝區
    MemoryMappedFileSizeBytes = 64L * 1024 * 1024
};

var eventStream = streamingExecutor.ExecuteStreamAsync(kernel, arguments, options);

// 消費者驅動的背壓
await foreach (var @event in eventStream)
{
    // 處理事件
    await ProcessEventAsync(@event);
    
    // 控制消費速率
    if (IsOverloaded())
    {
        await Task.Delay(100); // 減慢消費
    }
}
```

### 自訂背壓策略

實作自訂背壓處理：

```csharp
public class AdaptiveEventConsumer
{
    private readonly SemaphoreSlim _processingSemaphore;
    private readonly int _maxConcurrentProcessing;
    
    public AdaptiveEventConsumer(int maxConcurrent = 5)
    {
        _maxConcurrentProcessing = maxConcurrent;
        _processingSemaphore = new SemaphoreSlim(maxConcurrent);
    }
    
    public async Task ConsumeEventsAsync(IGraphExecutionEventStream eventStream)
    {
        await foreach (var @event in eventStream)
        {
            // 等待處理插槽
            await _processingSemaphore.WaitAsync();
            
            // 非同步處理事件
            _ = Task.Run(async () =>
            {
                try
                {
                    await ProcessEventAsync(@event);
                }
                finally
                {
                    _processingSemaphore.Release();
                }
            });
        }
    }
    
    private async Task ProcessEventAsync(GraphExecutionEvent @event)
    {
        // 模擬事件處理
        await Task.Delay(TimeSpan.FromMilliseconds(100));
    }
}
```

## 連線管理和可靠性

### 自動重新連線

優雅地處理連線中斷：

```csharp
var options = new StreamingExecutionOptions
{
    EnableAutoReconnect = true,
    MaxReconnectAttempts = 5,
    InitialReconnectDelay = TimeSpan.FromSeconds(1),
    MaxReconnectDelay = TimeSpan.FromSeconds(30)
};

var eventStream = streamingExecutor.ExecuteStreamAsync(kernel, arguments, options);

// 處理重新連線事件
eventStream.StatusChanged += (sender, args) =>
{
    switch (args.NewStatus)
    {
        case StreamStatus.Reconnecting:
            Console.WriteLine("🔄 Reconnecting to stream...");
            break;
        case StreamStatus.Connected:
            Console.WriteLine("✅ Stream reconnected");
            break;
        case StreamStatus.Failed:
            Console.WriteLine("❌ Stream connection failed");
            break;
    }
};
```

### 連線類型選擇

為不同的場景選擇適當的連線類型：

```csharp
// WebSocket 用於雙向通訊
var webSocketOptions = new StreamingExecutionOptions
{
    ConnectionType = StreamingConnectionType.WebSocket,
    EnableCompression = true,
    HeartbeatInterval = TimeSpan.FromSeconds(15)
};

// 伺服器發送事件用於單向串流
var sseOptions = new StreamingExecutionOptions
{
    ConnectionType = StreamingConnectionType.ServerSentEvents,
    EnableCompression = false,  // SSE 不支援壓縮
    HeartbeatInterval = TimeSpan.FromSeconds(30)
};

// HTTP 輪詢用於相容性
var pollingOptions = new StreamingExecutionOptions
{
    ConnectionType = StreamingConnectionType.HttpPolling,
    BufferSize = 10,  // 輪詢的較小緩衝區
    ProducerFlushInterval = TimeSpan.FromSeconds(1)
};
```

## 效能最佳化

### 記憶體對應緩衝區

在高吞吐量場景中使用基於磁碟的緩衝：

```csharp
var highThroughputOptions = new StreamingExecutionOptions
{
    // 啟用記憶體對應緩衝區
    EnableMemoryMappedBuffers = true,
    MemoryMappedFileSizeBytes = 128L * 1024 * 1024, // 128MB
    
    // 針對吞吐量最佳化
    BufferSize = 1000,
    MaxBufferSize = 10000,
    ProducerBatchSize = 50,
    ProducerFlushInterval = TimeSpan.FromMilliseconds(25),
    
    // 大型承載的壓縮
    EnableEventCompression = true,
    CompressionAlgorithm = CompressionAlgorithm.Brotli,
    CompressionThresholdBytes = 4 * 1024 // 4KB 閾值
};
```

### 自適應壓縮

啟用智慧型壓縮決策：

```csharp
var adaptiveOptions = new StreamingExecutionOptions
{
    EnableEventCompression = true,
    EnableAdaptiveCompression = true,
    
    // 自適應壓縮設定
    AdaptiveCompressionWindowSize = 100,
    AdaptiveCompressionMinSavingsRatio = 0.1, // 最少 10% 節省
    AdaptiveCompressionMinThresholdBytes = 2 * 1024, // 最小 2KB
    AdaptiveCompressionMaxThresholdBytes = 64 * 1024, // 最大 64KB
    
    // 壓縮演算法
    CompressionAlgorithm = CompressionAlgorithm.Gzip
};
```

## 實時監控和儀表板

### 即時執行監控

建立實時監控儀表板：

```csharp
public class ExecutionDashboard
{
    private readonly Dictionary<string, NodeMetrics> _nodeMetrics = new();
    private readonly List<ExecutionEvent> _recentEvents = new();
    
    public async Task MonitorExecutionAsync(IGraphExecutionEventStream eventStream)
    {
        await foreach (var @event in eventStream)
        {
            UpdateMetrics(@event);
            UpdateDashboard();
            
            // 只保留最近的事件
            if (_recentEvents.Count > 100)
            {
                _recentEvents.RemoveAt(0);
            }
        }
    }
    
    private void UpdateMetrics(GraphExecutionEvent @event)
    {
        switch (@event)
        {
            case NodeStartedEvent nodeStarted:
                if (!_nodeMetrics.ContainsKey(nodeStarted.NodeId))
                {
                    _nodeMetrics[nodeStarted.NodeId] = new NodeMetrics();
                }
                _nodeMetrics[nodeStarted.NodeId].StartTime = nodeStarted.Timestamp;
                break;
                
            case NodeCompletedEvent nodeCompleted:
                if (_nodeMetrics.TryGetValue(nodeCompleted.NodeId, out var metrics))
                {
                    metrics.ExecutionCount++;
                    metrics.TotalDuration += nodeCompleted.Duration ?? TimeSpan.Zero;
                    metrics.AverageDuration = metrics.TotalDuration / metrics.ExecutionCount;
                }
                break;
        }
        
        _recentEvents.Add(new ExecutionEvent
        {
            Timestamp = @event.Timestamp,
            EventType = @event.EventType.ToString(),
            NodeId = @event is NodeEvent nodeEvent ? nodeEvent.NodeId : null
        });
    }
    
    private void UpdateDashboard()
    {
        Console.Clear();
        Console.WriteLine("=== Real-Time Execution Dashboard ===\n");
        
        // Node 效能摘要
        Console.WriteLine("Node Performance:");
        foreach (var kvp in _nodeMetrics)
        {
            var metrics = kvp.Value;
            Console.WriteLine($"  {kvp.Key}: {metrics.ExecutionCount} executions, " +
                           $"avg: {metrics.AverageDuration.TotalMilliseconds:F0}ms");
        }
        
        // 最近的事件
        Console.WriteLine("\nRecent Events:");
        foreach (var evt in _recentEvents.TakeLast(10))
        {
            Console.WriteLine($"  [{evt.Timestamp:HH:mm:ss}] {evt.EventType} " +
                           (evt.NodeId != null ? $"({evt.NodeId})" : ""));
        }
    }
}

public class NodeMetrics
{
    public DateTimeOffset StartTime { get; set; }
    public int ExecutionCount { get; set; }
    public TimeSpan TotalDuration { get; set; }
    public TimeSpan AverageDuration { get; set; }
}

public class ExecutionEvent
{
    public DateTimeOffset Timestamp { get; set; }
    public string EventType { get; set; } = string.Empty;
    public string? NodeId { get; set; }
}
```

### 指標和遙測

啟用全面的指標收集：

```csharp
var metricsOptions = new StreamingExecutionOptions
{
    EnableMetrics = true,
    MetricsMeterName = "MyApp.GraphExecution",
    
    // 指標的自訂事件處理器
    EventHandlers = new List<IGraphExecutionEventHandler>
    {
        new MetricsEventHandler(),
        new PerformanceEventHandler()
    }
};

public class MetricsEventHandler : IGraphExecutionEventHandler
{
    private readonly Meter _meter = new("MyApp.GraphExecution");
    private readonly Counter<long> _eventCounter;
    private readonly Histogram<double> _nodeDurationHistogram;
    
    public MetricsEventHandler()
    {
        _eventCounter = _meter.CreateCounter<long>("events_total");
        _nodeDurationHistogram = _meter.CreateHistogram<double>("node_duration_ms");
    }
    
    public async Task HandleEventAsync(GraphExecutionEvent @event)
    {
        _eventCounter.Add(1, new KeyValuePair<string, object?>("event_type", @event.EventType.ToString()));
        
        if (@event is NodeCompletedEvent nodeCompleted && nodeCompleted.Duration.HasValue)
        {
            _nodeDurationHistogram.Record(nodeCompleted.Duration.Value.TotalMilliseconds,
                new KeyValuePair<string, object?>("node_id", nodeCompleted.NodeId));
        }
        
        await Task.CompletedTask;
    }
}
```

## Web API 整合

### REST API 串流

透過 REST API 公開串流執行：

```csharp
[ApiController]
[Route("api/[controller]")]
public class GraphExecutionController : ControllerBase
{
    [HttpPost("{graphId}/execute/stream")]
    public async Task<IActionResult> ExecuteStreamAsync(
        string graphId,
        [FromBody] ExecutionRequest request,
        CancellationToken cancellationToken)
    {
        var executor = GetExecutor(graphId);
        var arguments = new KernelArguments(request.Parameters);
        
        var options = new StreamingExecutionOptions
        {
            BufferSize = 10,
            EnableEventCompression = true,
            ProducerBatchSize = 1,  // API 的立即傳遞
            ProducerFlushInterval = TimeSpan.FromMilliseconds(50)
        };
        
        var eventStream = executor.ExecuteStreamAsync(kernel, arguments, options, cancellationToken);
        
        // 傳回伺服器發送事件串流
        Response.Headers.Add("Content-Type", "text/event-stream");
        Response.Headers.Add("Cache-Control", "no-cache");
        Response.Headers.Add("Connection", "keep-alive");
        
        await foreach (var @event in eventStream)
        {
            var eventData = JsonSerializer.Serialize(@event);
            var sseMessage = $"data: {eventData}\n\n";
            
            await Response.WriteAsync(sseMessage, cancellationToken);
            await Response.Body.FlushAsync(cancellationToken);
            
            if (cancellationToken.IsCancellationRequested)
                break;
        }
        
        return new EmptyResult();
    }
}
```

### WebSocket 串流

實作雙向 WebSocket 串流：

```csharp
[ApiController]
[Route("api/[controller]")]
public class WebSocketController : ControllerBase
{
    [HttpGet("{graphId}/ws")]
    public async Task GetWebSocketAsync(string graphId)
    {
        if (HttpContext.WebSockets.IsWebSocketRequest)
        {
            using var webSocket = await HttpContext.WebSockets.AcceptWebSocketAsync();
            await HandleWebSocketStreamingAsync(graphId, webSocket);
        }
        else
        {
            HttpContext.Response.StatusCode = StatusCodes.Status400BadRequest;
        }
    }
    
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
}
```

## 最佳實務

### 效能最佳化

1. **緩衝區大小**：根據消費者處理速度選擇適當的緩衝區大小
2. **事件篩選**：在來源處篩選事件以減少不必要的處理
3. **批次處理**：在高吞吐量場景中使用生產者批次處理
4. **壓縮**：為大型事件承載啟用壓縮
5. **記憶體管理**：在非常高的吞吐量中使用記憶體對應緩衝區

### 可靠性和監控

1. **重新連線**：為生產環境使用自動重新連線
2. **心跳**：使用心跳事件偵測連線問題
3. **指標**：收集全面的指標進行監控和警示
4. **錯誤處理**：為所有事件類型實作正確的錯誤處理
5. **背壓**：監控背壓並相應地調整緩衝區大小

### 生產環境考量

1. **連線類型**：為你的基礎結構選擇適當的連線類型
2. **安全性**：為串流 API 實作正確的驗證和授權
3. **可擴展性**：使用負載平衡和水平擴展以支援多個消費者
4. **監控**：實作全面的監控和警示
5. **測試**：在各種負載條件下測試串流行為

## 故障排除

### 常見問題

**高記憶體使用量**
```
串流執行期間記憶體使用量很高
```
**解決方案**：減少緩衝區大小、啟用記憶體對應緩衝區或實作消費者背壓。

**事件處理延遲**
```
事件處理有明顯的延遲
```
**解決方案**：增加生產者批次大小、減少刷新間隔或最佳化消費者處理。

**連線不穩定**
```
頻繁的連線中斷和重新連線
```
**解決方案**：檢查網路穩定性、增加重新連線延遲或實作連線集區。

**高 CPU 使用量**
```
事件處理期間 CPU 使用量尖峰
```
**解決方案**：最佳化事件序列化、減少壓縮開銷或實作事件批次處理。

**緩衝區溢位**
```
由於緩衝區溢位而丟失事件
```
**解決方案**：增加緩衝區大小、實作消費者背壓或最佳化消費者處理速度。

## 參見

* [串流快速入門](../streaming-quickstart.md) - 串流執行的快速介紹
* [執行模型](execution-model.md) - 執行如何透過圖形流動
* [狀態管理](state.md) - 在串流執行期間管理狀態
* [檢查點和復原](checkpointing.md) - 串流期間的狀態持久化
* [Graph 執行事件](../api/graph-execution-events.md) - 執行事件的 API 參考
* [串流範例](../examples/streaming-examples.md) - 實用的串流範例
