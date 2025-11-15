# 串流執行

SemanticKernel.Graph 中的串流執行能夠實現對圖執行的即時監控和事件驅動處理。本指南說明如何使用 `IStreamingGraphExecutor`、消費 `GraphExecutionEventStream`、實現篩選器、管理背壓，以及為生產環境設定串流選項。

## 您將學習的內容

* 如何為即時執行建立和設定 `StreamingGraphExecutor`
* 透過 `IGraphExecutionEventStream` 消費執行事件
* 實現事件篩選和緩衝以最佳化效能
* 管理背壓和連線穩定性
* 為不同的生產環境場景設定串流選項
* 建立即時監控和反應式應用程式

## 概念與技術

**串流執行**：使用即時事件發出的圖執行，能夠進行即時監控和構建反應式應用程式。

**事件串流**：提供圖進度、節點完成和狀態變化即時更新的非同步執行事件串流。

**背壓管理**：內建機制用來控制事件流並防止消費者被淹沒，同時維持系統穩定性。

**事件篩選**：選擇性消費特定事件類型以專注於相關的執行面向。

**連線管理**：自動重新連線、心跳監控和連線類型選擇，以確保穩健的串流。

## 先決條件

* 已完成 [執行模型](execution-model.md) 指南
* 已完成 [狀態管理](state.md) 指南
* 對 `GraphExecutor` 和圖執行的基本理解
* 熟悉非同步程式設計和事件驅動模式

## 核心串流元件

### StreamingGraphExecutor：即時執行

`StreamingGraphExecutor` 將標準圖執行包裝成具有串流功能：

```csharp
using SemanticKernel.Graph.Streaming;

// 建立啟用串流的執行器
var streamingExecutor = new StreamingGraphExecutor("StreamingDemo", "Real-time execution demo");

// 或轉換現有的 GraphExecutor
var regularExecutor = new GraphExecutor("MyGraph", "Regular graph");
var streamingExecutor2 = regularExecutor.AsStreamingExecutor();

// 新增節點並如往常一樣設定
streamingExecutor.AddNode(node1);
streamingExecutor.AddNode(node2);
streamingExecutor.Connect("node1", "node2");
streamingExecutor.SetStartNode("node1");
```

### IGraphExecutionEventStream：事件消費

`IGraphExecutionEventStream` 提供對執行事件的非同步迭代：

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

### StreamingExecutionOptions：精細控制

使用全面的選項設定串流行為：

```csharp
var options = new StreamingExecutionOptions
{
    // 緩衝區設定
    BufferSize = 100,                    // 初始緩衝區大小
    MaxBufferSize = 1000,                // 背壓前的最大值
    
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
    ProducerBatchSize = 5,               // 刷新前批次事件
    ProducerFlushInterval = TimeSpan.FromMilliseconds(100),
    
    // 壓縮和序列化
    EnableEventCompression = true,
    CompressionAlgorithm = CompressionAlgorithm.Gzip,
    CompressionThresholdBytes = 8 * 1024, // 8KB 臨界值
    
    // 記憶體管理
    EnableMemoryMappedBuffers = true,
    MemoryMappedFileSizeBytes = 64L * 1024 * 1024, // 64MB
    
    // 監控和度量
    EnableMetrics = true,
    EnableHeartbeat = true,
    HeartbeatInterval = TimeSpan.FromSeconds(30)
};
```

### 設定的擴充方法

使用流暢的設定方法實現常見場景：

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
    ExecutionStarted = 0,        // 圖執行已開始
    NodeStarted = 1,             // 節點執行已開始
    NodeCompleted = 2,           // 節點執行已完成
    NodeFailed = 3,              // 節點執行失敗
    ExecutionCompleted = 4,      // 圖執行已完成
    ExecutionFailed = 5,         // 圖執行失敗
    ExecutionCancelled = 6,      // 圖執行已取消
    NodeEntered = 7,             // 執行器已進入節點
    NodeExited = 8,              // 執行器已退出節點
    ConditionEvaluated = 9,      // 條件式已評估
    StateMergeConflictDetected = 10, // 狀態合併衝突
    CircuitBreakerStateChanged = 11,  // 斷路器狀態變化
    ResourceBudgetExhausted = 14,     // 資源預算已耗盡
    RetryAttempted = 15,              // 重試操作已嘗試
    CheckpointCreated = 16,           // 檢查點已建立
    CheckpointRestored = 17           // 檢查點已還原
}
```

### 事件處理模式

實現不同的事件處理策略：

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

篩選事件以專注於特定的執行面向：

```csharp
// 按事件類型篩選
var nodeEvents = eventStream.Filter(GraphExecutionEventType.NodeStarted, GraphExecutionEventType.NodeCompleted);
var errorEvents = eventStream.Filter(GraphExecutionEventType.NodeFailed, GraphExecutionEventType.ExecutionFailed);

// 按節點 ID 篩選
var specificNodeEvents = eventStream.FilterByNode("critical-node");

// 按自訂準則篩選
var longRunningEvents = eventStream.Filter(@event => 
    @event is NodeCompletedEvent completed && 
    completed.Duration > TimeSpan.FromSeconds(5)
);

// 合併篩選器
var criticalEvents = eventStream
    .Filter(GraphExecutionEventType.NodeFailed, GraphExecutionEventType.ExecutionFailed)
    .FilterByNode("critical-node");
```

### 事件緩衝和批處理

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

// 基於輸送量的自適應緩衝
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
    
    // 生產者批處理
    ProducerBatchSize = 5,               // 刷新前批次
    ProducerFlushInterval = TimeSpan.FromMilliseconds(50),
    
    // 記憶體管理
    EnableMemoryMappedBuffers = true,    // 針對大型緩衝區使用磁碟
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
        await Task.Delay(100); // 減速消費
    }
}
```

### 自訂背壓策略

實現自訂背壓處理：

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
            // 等待處理槽位
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

為不同的場景選擇合適的連線類型：

```csharp
// WebSocket 用於雙向通訊
var webSocketOptions = new StreamingExecutionOptions
{
    ConnectionType = StreamingConnectionType.WebSocket,
    EnableCompression = true,
    HeartbeatInterval = TimeSpan.FromSeconds(15)
};

// 伺服器傳送事件用於單向串流
var sseOptions = new StreamingExecutionOptions
{
    ConnectionType = StreamingConnectionType.ServerSentEvents,
    EnableCompression = false,  // SSE 不支援壓縮
    HeartbeatInterval = TimeSpan.FromSeconds(30)
};

// HTTP 輪詢以提高相容性
var pollingOptions = new StreamingExecutionOptions
{
    ConnectionType = StreamingConnectionType.HttpPolling,
    BufferSize = 10,  // 輪詢的較小緩衝區
    ProducerFlushInterval = TimeSpan.FromSeconds(1)
};
```

## 效能最佳化

### 記憶體映射緩衝區

為高輸送量場景使用磁碟型緩衝：

```csharp
var highThroughputOptions = new StreamingExecutionOptions
{
    // 啟用記憶體映射緩衝區
    EnableMemoryMappedBuffers = true,
    MemoryMappedFileSizeBytes = 128L * 1024 * 1024, // 128MB
    
    // 針對輸送量最佳化
    BufferSize = 1000,
    MaxBufferSize = 10000,
    ProducerBatchSize = 50,
    ProducerFlushInterval = TimeSpan.FromMilliseconds(25),
    
    // 針對大型承載的壓縮
    EnableEventCompression = true,
    CompressionAlgorithm = CompressionAlgorithm.Brotli,
    CompressionThresholdBytes = 4 * 1024 // 4KB 臨界值
};
```

### 自適應壓縮

啟用智能壓縮決策：

```csharp
var adaptiveOptions = new StreamingExecutionOptions
{
    EnableEventCompression = true,
    EnableAdaptiveCompression = true,
    
    // 自適應壓縮設定
    AdaptiveCompressionWindowSize = 100,
    AdaptiveCompressionMinSavingsRatio = 0.1, // 最少節省 10%
    AdaptiveCompressionMinThresholdBytes = 2 * 1024, // 最少 2KB
    AdaptiveCompressionMaxThresholdBytes = 64 * 1024, // 最多 64KB
    
    // 壓縮演算法
    CompressionAlgorithm = CompressionAlgorithm.Gzip
};
```

## 即時監控和儀表板

### 即時執行監控

建立即時監控儀表板：

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
            
            // 僅保留最近的事件
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
        
        // 節點效能摘要
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

### 度量和遙測

啟用全面的度量收集：

```csharp
var metricsOptions = new StreamingExecutionOptions
{
    EnableMetrics = true,
    MetricsMeterName = "MyApp.GraphExecution",
    
    // 度量的自訂事件處理器
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
            ProducerBatchSize = 1,  // API 的即時傳遞
            ProducerFlushInterval = TimeSpan.FromMilliseconds(50)
        };
        
        var eventStream = executor.ExecuteStreamAsync(kernel, arguments, options, cancellationToken);
        
        // 傳回伺服器傳送事件串流
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

實現雙向 WebSocket 串流：

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

## 最佳實踐

### 效能最佳化

1. **緩衝區大小**：根據消費者處理速度選擇適當的緩衝區大小
2. **事件篩選**：在來源篩選事件以減少不必要的處理
3. **批次處理**：為高輸送量場景使用生產者批處理
4. **壓縮**：為大型事件承載啟用壓縮
5. **記憶體管理**：針對非常高輸送量使用記憶體映射緩衝區

### 可靠性和監控

1. **重新連線**：始終為生產環境使用啟用自動重新連線
2. **心跳**：使用心跳事件偵測連線問題
3. **度量**：收集全面的度量以用於監控和警示
4. **錯誤處理**：為所有事件類型實現適當的錯誤處理
5. **背壓**：監控背壓並相應調整緩衝區大小

### 生產考量

1. **連線類型**：為您的基礎設施選擇適當的連線類型
2. **安全性**：為串流 API 實現適當的驗證和授權
3. **可擴充性**：為多個消費者使用負載平衡和水平擴展
4. **監控**：實現全面的監控和警示
5. **測試**：在各種負載條件下測試串流行為

## 疑難排解

### 常見問題

**記憶體使用率高**
```
串流執行期間記憶體使用量很高
```
**解決方案**：減少緩衝區大小、啟用記憶體映射緩衝區，或實現消費者背壓。

**事件處理延遲**
```
事件處理存在明顯延遲
```
**解決方案**：增加生產者批次大小、減少刷新間隔，或最佳化消費者處理。

**連線不穩定**
```
頻繁的連線中斷和重新連線
```
**解決方案**：檢查網路穩定性、增加重新連線延遲，或實現連線池。

**CPU 使用率高**
```
事件處理期間 CPU 使用率飆升
```
**解決方案**：最佳化事件序列化、減少壓縮額外負荷，或實現事件批處理。

**緩衝區溢出**
```
事件因緩衝區溢出而被捨棄
```
**解決方案**：增加緩衝區大小、實現消費者背壓，或最佳化消費者處理速度。

## 另請參閱

* [串流快速入門](../streaming-quickstart.md) - 串流執行的快速介紹
* [執行模型](execution-model.md) - 執行如何流經圖
* [狀態管理](state.md) - 在串流執行期間管理狀態
* [檢查點和復原](checkpointing.md) - 串流期間的狀態持續性
* [圖執行事件](../api/graph-execution-events.md) - 執行事件的 API 參考
* [串流範例](../examples/streaming-examples.md) - 實務串流範例
