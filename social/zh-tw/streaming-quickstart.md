# 串流快速入門

本快速教學將教您如何在 SemanticKernel.Graph 中使用串流執行。您將學習如何使用 `StreamingGraphExecutor` 執行 Graph，以及透過 `IGraphExecutionEventStream` 消費即時事件。

## 您將學到的內容

* 建立和設定 `StreamingGraphExecutor`
* 消費即時執行事件
* 過濾和緩衝事件流
* 處理串流完成和錯誤
* Graph 執行的即時監控

## 概念和技術

**StreamingGraphExecutor**：一個專門的執行器，透過事件流提供即時執行更新，支援即時監控和回應式應用程式。

**IGraphExecutionEventStream**：一個事件流介面，提供關於 Graph 執行進度、Node 完成和狀態變化的即時更新。

**Streaming Events**：關於 Graph 執行的即時通知，包括 Node 啟動/完成事件、狀態更新和執行進度。

**Backpressure Management**：控制事件流程的能力，以防止消費者被淹沒並維持系統穩定性。

## 先決條件

* [First Graph Tutorial](first-graph-5-minutes.md) 已完成
* [State Quickstart](state-quickstart.md) 已完成
* [Conditional Nodes Quickstart](conditional-nodes-quickstart.md) 已完成
* SemanticKernel.Graph 概念的基本瞭解

## 步驟 1：基本串流設定

### 建立串流執行器

```csharp
using SemanticKernel.Graph.Streaming;

// 建立一個啟用串流的 Graph 執行器
var streamingExecutor = new StreamingGraphExecutor("StreamingDemo", "Demo of streaming execution");

// 或轉換現有的 GraphExecutor
var regularExecutor = new GraphExecutor("MyGraph", "Regular graph");
var streamingExecutor2 = regularExecutor.AsStreamingExecutor();
```

### 新增 Node 到您的串流 Graph

```csharp
// 新增函數 Node
var node1 = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () => 
        {
            Thread.Sleep(1000); // 模擬工作
            return "Hello from node 1";
        },
        "node1_function",
        "First node function"
    ),
    "node1",
    "First Node"
);

var node2 = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () => 
        {
            Thread.Sleep(1500); // 模擬工作
            return "Hello from node 2";
        },
        "node2_function",
        "Second node function"
    ),
    "node2",
    "Second Node"
);

var node3 = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () => 
        {
            Thread.Sleep(800); // 模擬工作
            return "Hello from node 3";
        },
        "node3_function",
        "Third node function"
    ),
    "node3",
    "Third Node"
);

// 新增 Node 到執行器
streamingExecutor.AddNode(node1);
streamingExecutor.AddNode(node2);
streamingExecutor.AddNode(node3);

// 連接 Node
streamingExecutor.Connect("node1", "node2");
streamingExecutor.Connect("node2", "node3");
streamingExecutor.SetStartNode("node1");
```

## 步驟 2：設定串流選項

### 基本串流設定

```csharp
using SemanticKernel.Graph.Streaming;

// 建立具有預設值的串流選項
var options = new StreamingExecutionOptions();

// 或設定特定選項
var configuredOptions = new StreamingExecutionOptions
{
    BufferSize = 20,
    EventTypesToEmit = new[]
    {
        GraphExecutionEventType.ExecutionStarted,
        GraphExecutionEventType.NodeStarted,
        GraphExecutionEventType.NodeCompleted,
        GraphExecutionEventType.ExecutionCompleted
    }
};
```

### 進階串流選項

```csharp
var advancedOptions = new StreamingExecutionOptions
{
        BufferSize = 50,
    MaxBufferSize = 200,
    EventTypesToEmit = new[]
    {
        GraphExecutionEventType.ExecutionStarted,
        GraphExecutionEventType.NodeStarted,
        GraphExecutionEventType.NodeCompleted,
        GraphExecutionEventType.NodeFailed,
        GraphExecutionEventType.ExecutionCompleted,
        GraphExecutionEventType.ExecutionFailed
    },
    EnableEventCompression = true,
    CompressionAlgorithm = CompressionAlgorithm.Gzip,
    CompressionThresholdBytes = 8 * 1024, // 8KB 閾值
    AdaptiveEventCompressionEnabled = true,
    UseMemoryMappedSerializedBuffer = false,
    MemoryMappedSerializedThresholdBytes = 64 * 1024, // 64KB 閾值
    MemoryMappedFileSizeBytes = 64L * 1024 * 1024, // 每個檔案 64MB
    MemoryMappedMaxFiles = 16,
    MemoryMappedBufferDirectory = Path.GetTempPath(),
    ProducerBatchSize = 1,
    ProducerFlushInterval = TimeSpan.FromMilliseconds(100),
    EnableHeartbeat = true,
    HeartbeatInterval = TimeSpan.FromSeconds(30)
};
```

## 步驟 3：執行和消費串流

### 基本事件消費

```csharp
// 啟動串流執行
var arguments = new KernelArguments();
var eventStream = streamingExecutor.ExecuteStreamAsync(kernel, arguments, options);

Console.WriteLine("⚡ 啟動串流執行...\n");

// 即時消費事件
await foreach (var @event in eventStream)
{
    Console.WriteLine($"📡 事件：{@event.EventType} 於 {@event.Timestamp:HH:mm:ss.fff}");
    
    // 處理不同事件類型
    switch (@event)
    {
        case GraphExecutionStartedEvent started:
            Console.WriteLine($"   🚀 執行已啟動，ID：{started.ExecutionId}");
            break;
            
        case NodeExecutionStartedEvent nodeStarted:
            Console.WriteLine($"   ▶️  Node 已啟動：{nodeStarted.Node.Name}");
            break;
            
        case NodeExecutionCompletedEvent nodeCompleted:
            Console.WriteLine($"   ✅ Node 已完成：{nodeCompleted.Node.Name} 用時 {nodeCompleted.ExecutionDuration.TotalMilliseconds:F0}ms");
            break;
            
        case GraphExecutionCompletedEvent completed:
            Console.WriteLine($"   🎯 執行已完成，用時 {completed.TotalDuration.TotalMilliseconds:F0}ms");
            break;
    }
    
    // 新增小延遲以展示即時性質
    await Task.Delay(100);
}
```

## 步驟 4：進階串流功能

### 事件過濾

```csharp
// 僅過濾 Node 相關事件
var nodeEventsStream = eventStream.Filter(
    GraphExecutionEventType.NodeStarted,
    GraphExecutionEventType.NodeCompleted
);

Console.WriteLine("🎯 僅限 Node 事件：");
await foreach (var @event in nodeEventsStream)
{
    Console.WriteLine($"   Node 事件：{@event.EventType}");
}
```

### 緩衝消費

```csharp
// 為高吞吐量情境建立緩衝流
var bufferedStream = eventStream.Buffer(10);

Console.WriteLine("🚀 緩衝事件（批次 10）：");
var eventBatch = new List<GraphExecutionEvent>();
await foreach (var @event in bufferedStream)
{
    eventBatch.Add(@event);
    
    if (eventBatch.Count >= 10)
    {
        Console.WriteLine($"   批次：{eventBatch.Count} 個事件");
        eventBatch.Clear();
    }
}
```

### 等待完成

```csharp
// 透過消費所有事件等待執行完成
var eventCount = 0;
var startTime = DateTimeOffset.UtcNow;

await foreach (var @event in eventStream)
{
    eventCount++;
    // 處理每個事件
}

var duration = DateTimeOffset.UtcNow - startTime;
Console.WriteLine($"\n✅ 執行已完成！");
Console.WriteLine($"   狀態：已完成");
Console.WriteLine($"   耗時：{duration.TotalMilliseconds:F0}ms");
Console.WriteLine($"   總事件數：{eventCount}");
```

## 步驟 5：完整串流範例

### 建立即時監控 Graph

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Streaming;

class Program
{
    static async Task Main(string[] args)
    {
        var builder = Kernel.CreateBuilder();
        builder.AddOpenAIChatCompletion("gpt-3.5-turbo", Environment.GetEnvironmentVariable("OPENAI_API_KEY"));
        builder.AddGraphSupport();
        var kernel = builder.Build();

        // 建立串流執行器
        var streamingExecutor = new StreamingGraphExecutor("RealTimeMonitor", "Real-time execution monitoring");

        // 建立具有不同執行時間的 Node
        var inputNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    args["startTime"] = DateTimeOffset.UtcNow;
                    args["input"] = "Sample input data";
                    return "Input processed";
                },
                "ProcessInput",
                "Processes input data"
            ),
            "input_node"
        ).StoreResultAs("inputResult");

        var analysisNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                async (KernelArguments args) =>
                {
                    // 模擬 AI 分析
                    await Task.Delay(2000);
                    args["analysis"] = "AI analysis completed";
                    args["analysisTime"] = DateTimeOffset.UtcNow;
                    return "Analysis completed";
                },
                "AnalyzeData",
                "Performs AI analysis"
            ),
            "analysis_node"
        ).StoreResultAs("analysisResult");

        var decisionNode = new ConditionalGraphNode(
            state => state.KernelArguments.ContainsName("analysis") && state.KernelArguments["analysis"]?.ToString()?.Contains("completed") == true,
            "decision_node",
            "DecisionMaker",
            "Makes routing decision based on analysis"
        );

        var successNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    args["result"] = "Success path taken";
                    return "Success processing completed";
                },
                "ProcessSuccess",
                "Handles success path"
            ),
            "success_node"
        ).StoreResultAs("successResult");

        var fallbackNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    args["result"] = "Fallback path taken";
                    return "Fallback processing completed";
                },
                "ProcessFallback",
                "Handles fallback path"
            ),
            "fallback_node"
        ).StoreResultAs("fallbackResult");

        var summaryNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var startTime = args.ContainsName("startTime") ? (DateTimeOffset)args["startTime"] : DateTimeOffset.UtcNow;
                    var endTime = DateTimeOffset.UtcNow;
                    var duration = endTime - startTime;
                    
                    args["totalDuration"] = duration.TotalMilliseconds;
                    args["finalResult"] = args.ContainsName("result") ? args["result"]?.ToString() ?? "" : "";
                    
                    return $"Processing completed in {duration.TotalMilliseconds:F0}ms";
                },
                "CreateSummary",
                "Creates execution summary"
            ),
            "summary_node"
        ).StoreResultAs("summaryResult");

        // 建置 Graph
        streamingExecutor.AddNode(inputNode);
        streamingExecutor.AddNode(analysisNode);
        streamingExecutor.AddNode(decisionNode);
        streamingExecutor.AddNode(successNode);
        streamingExecutor.AddNode(fallbackNode);
        streamingExecutor.AddNode(summaryNode);

        // 連接 Node
        streamingExecutor.Connect("input_node", "analysis_node");
        streamingExecutor.Connect("analysis_node", "decision_node");
        streamingExecutor.Connect("decision_node", "success_node");
        streamingExecutor.Connect("decision_node", "fallback_node");
        streamingExecutor.Connect("success_node", "summary_node");
        streamingExecutor.Connect("fallback_node", "summary_node");

        streamingExecutor.SetStartNode("input_node");

        // 設定串流選項
        var options = new StreamingExecutionOptions
        {
            BufferSize = 15,
            EnableHeartbeat = true,
            HeartbeatInterval = TimeSpan.FromSeconds(10),
            EventTypesToEmit = new[]
            {
                GraphExecutionEventType.ExecutionStarted,
                GraphExecutionEventType.NodeStarted,
                GraphExecutionEventType.NodeCompleted,
                                GraphExecutionEventType.ExecutionCompleted
            },
            IncludeStateSnapshots = true
        };

        // 執行串流
        var arguments = new KernelArguments();
        var eventStream = streamingExecutor.ExecuteStreamAsync(kernel, arguments, options);

        Console.WriteLine("=== 即時執行監控 ===\n");
        Console.WriteLine("⚡ 啟動串流執行...\n");

        // 即時監控執行
        var eventCount = 0;
        await foreach (var @event in eventStream)
        {
            eventCount++;
            var timestamp = @event.Timestamp.ToString("HH:mm:ss.fff");
            
            Console.WriteLine($"[{timestamp}] #{eventCount} {@event.EventType}");
            
            switch (@event)
            {
                case GraphExecutionStartedEvent started:
                    Console.WriteLine($"   🚀 執行 ID：{started.ExecutionId}");
                    break;
                    
                        case NodeExecutionStartedEvent nodeStarted:
            Console.WriteLine($"   ▶️  Node：{nodeStarted.Node.Name}");
            break;
            
        case NodeExecutionCompletedEvent nodeCompleted:
            var duration = nodeCompleted.ExecutionDuration.TotalMilliseconds;
            Console.WriteLine($"   ✅ Node：{nodeCompleted.Node.Name} ({duration:F0}ms)");
            break;
                    
                case GraphExecutionCompletedEvent completed:
                    var totalDuration = completed.TotalDuration.TotalMilliseconds;
                    Console.WriteLine($"   🎯 總耗時：{totalDuration:F0}ms");
                    break;
            }
            
            // 小延遲以提高可讀性
            await Task.Delay(200);
        }

        // 等待完成並顯示結果
        // 注意：WaitForCompletionAsync 透過消費流至完成來處理
        
        Console.WriteLine($"\n=== 執行摘要 ===");
        Console.WriteLine($"狀態：已完成");
        Console.WriteLine($"總事件數：{eventCount}");
        Console.WriteLine($"耗時：處理已完成");
        
        // 顯示最終狀態
        var finalState = await streamingExecutor.ExecuteAsync(kernel, arguments);
        Console.WriteLine($"最終結果：{finalState.ContainsName("finalResult") ? finalState["finalResult"]?.ToString() ?? "" : ""}");
        Console.WriteLine($"總耗時：{finalState.ContainsName("totalDuration") ? finalState["totalDuration"]?.ToString() ?? "0" : "0"}ms");
        
        Console.WriteLine("\n✅ 串流執行已成功完成！");
    }
}
```

## 步驟 6：執行您的串流範例

### 設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

### 執行 Graph

```bash
dotnet run
```

您應該會看到類似的即時輸出：

```
=== 即時執行監控 ===

⚡ 啟動串流執行...

[14:30:15.123] #1 ExecutionStarted
   🚀 執行 ID：abc123def456
[14:30:15.125] #2 NodeStarted
   ▶️  Node：input_node
[14:30:15.127] #3 NodeCompleted
   ✅ Node：input_node (4ms)
[14:30:15.129] #4 NodeStarted
   ▶️  Node：analysis_node
[14:30:17.135] #5 NodeCompleted
   ✅ Node：analysis_node (2006ms)
[14:30:17.137] #6 NodeStarted
   ▶️  Node：decision_node
[14:30:17.138] #7 NodeCompleted
   ✅ Node：decision_node (1ms)
[14:30:17.140] #8 NodeStarted
   ▶️  Node：success_node
[14:30:17.141] #9 NodeCompleted
   ✅ Node：success_node (1ms)
[14:30:17.143] #10 NodeStarted
   ▶️  Node：summary_node
[14:30:17.144] #11 NodeCompleted
   ✅ Node：summary_node (1ms)
[14:30:17.145] #12 ExecutionCompleted
   🎯 總耗時：2022ms

=== 執行摘要 ===
狀態：已完成
總事件數：12
耗時：2022ms
最終結果：Success path taken
總耗時：2022ms

✅ 串流執行已成功完成！
```

## 剛發生了什麼？

### 1. **串流執行器建立**
```csharp
var streamingExecutor = new StreamingGraphExecutor("RealTimeMonitor");
```
建立一個在 Graph 執行期間發出即時事件的執行器。

### 2. **事件流生成**
```csharp
var eventStream = streamingExecutor.ExecuteStreamAsync(kernel, arguments, options);
```
啟動執行並傳回即時事件的流。

### 3. **即時事件消費**
```csharp
await foreach (var @event in eventStream)
{
    // 處理每個發生的事件
}
```
消費事件時提供即時監控。

### 4. **事件過濾和緩衝**
```csharp
var nodeEventsStream = eventStream.Filter(GraphExecutionEventType.NodeStarted);
var bufferedStream = eventStream.Buffer(10);
```
過濾特定事件類型並為高吞吐量情境緩衝事件。

## 重要概念

* **StreamingGraphExecutor**：執行 Graph 同時發出即時事件
* **IGraphExecutionEventStream**：透過執行事件提供非同步迭代
* **GraphExecutionEvent**：所有執行事件的基類（啟動、完成、失敗等）
* **事件過濾**：選擇特定事件類型進行監控
* **事件緩衝**：為提高效能而批量處理事件
* **即時監控**：在執行進行時觀察執行進度

## 常見模式

### 監控特定事件類型
```csharp
var criticalEvents = eventStream.Filter(
    GraphExecutionEventType.NodeFailed,
    GraphExecutionEventType.ExecutionFailed
);
```

### 為批量處理緩衝事件
```csharp
var batchStream = eventStream.Buffer(50);
await foreach (var batch in batchStream)
{
    // 批量處理 50 個事件
}
```

### 處理不同事件類型
```csharp
switch (@event)
{
    case NodeExecutionStartedEvent started:
        Console.WriteLine($"Node {started.Node.Name} 已啟動");
        break;
    case NodeExecutionCompletedEvent completed:
        Console.WriteLine($"Node {completed.Node.Name} 已完成，用時 {completed.ExecutionDuration}ms");
        break;
}
```

### 等待完成
```csharp
// 消費所有事件以等待完成
var eventCount = 0;
var startTime = DateTimeOffset.UtcNow;

await foreach (var @event in eventStream)
{
    eventCount++;
    // 視需要處理事件
    if (@event is GraphExecutionCompletedEvent)
    {
        var duration = DateTimeOffset.UtcNow - startTime;
        Console.WriteLine($"執行已在 {duration.TotalMilliseconds:F0}ms 內完成");
        break;
    }
}
```

## 疑難排解

### **串流未啟動**
```
未發出任何事件
```
**解決方案**：確保 Graph 有起始 Node 並正確設定。

### **事件在執行中止**
```
流意外結束
```
**解決方案**：檢查 Node 執行中是否有例外狀況，並驗證錯誤處理。

### **高記憶體使用量**
```
串流期間記憶體消耗增加
```
**解決方案**：使用緩衝並批量處理事件，正確處置流。

### **事件順序錯亂**
```
事件序列不是按時間順序排列
```
**解決方案**：在高吞吐量情境中使用 `HighPrecisionTimestamp` 以確保精確排序。

## 後續步驟

* **[Streaming Tutorial](streaming-tutorial.md)**：進階串流模式和最佳實踐
* **[Event Handling](how-to/event-handling.md)**：自訂事件處理程式和處理
* **[Performance Optimization](how-to/streaming-performance.md)**：高吞吐量串流情境
* **[Core Concepts](concepts/index.md)**：理解 Graph、Node 和執行

## 概念和技術

本教學介紹了幾個關鍵概念：

* **串流執行**：Graph 執行進度的即時監控
* **事件流**：執行事件的非同步消費
* **事件類型**：執行事件的不同類別（啟動、完成、失敗）
* **事件過濾**：選擇性監控特定事件類型
* **事件緩衝**：為提高效能而批量處理事件
* **即時監控**：在執行進行時觀察執行進度

## 先決條件和最低配置

要完成本教學，您需要：
* **.NET 8.0+** 執行時和 SDK
* **SemanticKernel.Graph** 套件已安裝
* **LLM 提供者**已設定有效的 API 金鑰
* **環境變數**已為您的 API 認證設定

## 另請參閱

* **[First Graph Tutorial](first-graph-5-minutes.md)**：建立您的第一個 Graph 工作流程
* **[State Quickstart](state-quickstart.md)**：管理 Node 之間的資料流
* **[Conditional Nodes Quickstart](conditional-nodes-quickstart.md)**：將決策制定新增到工作流程
* **[Streaming Tutorial](streaming-tutorial.md)**：進階串流概念
* **[Core Concepts](concepts/index.md)**：理解 Graph、Node 和執行
* **[API Reference](api/streaming.md)**：完整串流 API 文件

## 參考 API

* **[StreamingGraphExecutor](../api/streaming.md#streaming-graph-executor)**：串流執行引擎
* **[IGraphExecutionEventStream](../api/streaming.md#igraph-execution-event-stream)**：事件流介面
* **[GraphExecutionEvent](../api/streaming.md#graph-execution-event)**：執行事件類型
* **[StreamingExecutionOptions](../api/streaming.md#streaming-execution-options)**：串流設定
