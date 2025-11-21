# 執行上下文和事件

本參考涵蓋 SemanticKernel.Graph 中管理 Graph 執行的執行上下文、事件、限制和優先級。

## GraphExecutionContext

`GraphExecutionContext` 維護單一 Graph 執行的執行狀態，追蹤執行進度、管理資源並提供協調服務。

### 核心屬性

```csharp
public sealed class GraphExecutionContext
{
    // Execution identification
    public string ExecutionId { get; }                    // 唯一的執行識別符
    public int ExecutionSeed { get; }                     // 用於可重現隨機性的種子值
    public Random Random { get; }                         // 經過種子處理的隨機生成器
    
    // Kernel and state
    public Kernel Kernel { get; }                         // Semantic kernel 實例
    public IKernelWrapper KernelWrapper { get; }          // Kernel 包裝器
    public GraphState GraphState { get; set; }            // 當前 Graph 狀態
    
    // Execution control
    public CancellationToken CancellationToken { get; }   // 有效的取消令牌
    public GraphExecutionOptions ExecutionOptions { get; } // 不可變的執行選項
    
    // Timing and status
    public DateTimeOffset StartTime { get; }              // 執行開始時間戳
    public DateTimeOffset? EndTime { get; }               // 執行結束時間戳
    public TimeSpan? Duration { get; }                    // 總執行持續時間
    public GraphExecutionStatus Status { get; }           // 當前執行狀態
    
    // Execution state
    public bool IsPaused { get; }                         // 執行是否已暫停
    public string? PauseReason { get; }                   // 暫停原因
    public IGraphNode? CurrentNode { get; }               // 當前執行的 Node
    public IReadOnlyList<IGraphNode> ExecutionPath { get; } // 執行路徑
    public int NodesExecuted { get; }                     // 已執行的 Node 數量
    
    // Work management
    public DeterministicWorkQueue WorkQueue { get; }      // 確定性工作佇列
}
```

### 執行狀態

`GraphExecutionStatus` 列舉表示執行的當前狀態：

```csharp
public enum GraphExecutionStatus
{
    NotStarted = 0,    // 執行尚未開始
    Running = 1,       // 執行正在進行中
    Completed = 2,     // 執行成功完成
    Failed = 3,        // 執行失敗並出現錯誤
    Cancelled = 4,     // 執行已取消
    Paused = 5         // 執行已暫停，等待繼續
}
```

### 狀態管理方法

```csharp
// Execution lifecycle
public void MarkAsStarted(IGraphNode startingNode)           // 標記執行已開始
public void MarkAsCompleted(FunctionResult result)           // 標記執行已完成
public void MarkAsFailed(Exception error)                    // 標記執行已失敗
public void MarkAsCancelled()                                // 標記執行已取消

// Node tracking
public void RecordNodeStarted(IGraphNode node)               // 記錄 Node 執行開始
public void RecordNodeCompleted(IGraphNode node, FunctionResult result) // 記錄 Node 完成
public void RecordNodeFailed(IGraphNode node, Exception exception)     // 記錄 Node 失敗

// Work queue management
public void EnqueueNextNodes(IEnumerable<IGraphNode> candidates) // 將下一個 Node 加入佇列

// Pause/resume control
public void Pause(string reason)                             // 暫停執行
public void Resume()                                          // 恢復執行
public Task WaitIfPausedAsync(CancellationToken cancellationToken) // 如果已暫停則等待
```

### 屬性管理

```csharp
public void SetProperty<T>(string key, T value)              // 設定自訂屬性
public T? GetProperty<T>(string key)                         // 取得自訂屬性
public bool TryGetProperty<T>(string key, out T? value)      // 嘗試取得屬性
public void RemoveProperty(string key)                        // 移除屬性
```

## 執行事件

執行系統會發出即時事件，提供對執行進度和狀態變化的可見性。

### GraphExecutionEvent 基類

所有執行事件都繼承自 `GraphExecutionEvent`：

```csharp
public abstract class GraphExecutionEvent
{
    public string EventId { get; }                          // 唯一的事件識別符
    public string ExecutionId { get; }                      // 關聯的執行 ID
    public DateTimeOffset Timestamp { get; }                // 事件時間戳
    public abstract GraphExecutionEventType EventType { get; } // 事件類型
    public long HighPrecisionTimestamp { get; }             // 高精度時間戳
    public long HighPrecisionFrequency { get; }             // 計時器頻率
}
```

### 事件類型

`GraphExecutionEventType` 列舉定義所有可能的事件類型：

```csharp
public enum GraphExecutionEventType
{
    ExecutionStarted = 0,           // Graph 執行已開始
    NodeStarted = 1,                // Node 執行已開始
    NodeCompleted = 2,              // Node 執行成功完成
    NodeFailed = 3,                 // Node 執行失敗
    ExecutionCompleted = 4,         // Graph 執行成功完成
    ExecutionFailed = 5,            // Graph 執行失敗
    ExecutionCancelled = 6,         // Graph 執行已取消
    NodeEntered = 7,                // 執行器已進入 Node
    NodeExited = 8,                 // 執行器已離開 Node
    ConditionEvaluated = 9,         // 條件運算式已評估
    StateMergeConflictDetected = 10, // 檢測到狀態合併衝突
    CircuitBreakerStateChanged = 11, // 斷路器狀態已變更
    CircuitBreakerOperationAttempted = 12, // 斷路器操作已嘗試
    CircuitBreakerOperationBlocked = 13,   // 斷路器操作已阻止
    ResourceBudgetExhausted = 14,   // 資源預算已耗盡
    RetryScheduled = 15,            // 已排定重試
    NodeSkippedDueToErrorPolicy = 16 // 由於錯誤原則已跳過 Node
}
```

### 關鍵事件類別

#### GraphExecutionStartedEvent
```csharp
public sealed class GraphExecutionStartedEvent : GraphExecutionEvent
{
    public IGraphNode StartNode { get; }                    // 起始 Node
    public GraphState InitialState { get; }                 // 初始 Graph 狀態
}
```

#### NodeExecutionStartedEvent
```csharp
public sealed class NodeExecutionStartedEvent : GraphExecutionEvent
{
    public IGraphNode Node { get; }                         // 已開始的 Node
    public GraphState CurrentState { get; }                 // 當前狀態
}
```

#### NodeExecutionCompletedEvent
```csharp
public sealed class NodeExecutionCompletedEvent : GraphExecutionEvent
{
    public IGraphNode Node { get; }                         // 已完成的 Node
    public FunctionResult Result { get; }                   // 執行結果
    public GraphState UpdatedState { get; }                 // 已更新的狀態
    public TimeSpan ExecutionDuration { get; }              // 執行持續時間
}
```

#### NodeExecutionFailedEvent
```csharp
public sealed class NodeExecutionFailedEvent : GraphExecutionEvent
{
    public IGraphNode Node { get; }                         // 失敗的 Node
    public Exception Exception { get; }                     // 發生的例外狀況
    public GraphState CurrentState { get; }                 // 當前狀態
    public TimeSpan ExecutionDuration { get; }              // 執行持續時間
}
```

## 執行限制和防護措施

執行系統提供多層保護，防止失控執行和資源耗盡。

### 執行選項

```csharp
public sealed class GraphExecutionOptions
{
    public bool EnableLogging { get; }                      // 是否啟用記錄
    public bool EnableMetrics { get; }                      // 是否啟用指標
    public int MaxExecutionSteps { get; }                   // 最大執行步驟數
    public bool ValidateGraphIntegrity { get; }             // 是否驗證 Graph
    public TimeSpan ExecutionTimeout { get; }               // 總執行逾時
    public bool EnablePlanCompilation { get; }              // 是否編譯計畫
}
```

### 預設限制

```csharp
public static GraphExecutionOptions CreateDefault()
{
    return new GraphExecutionOptions(
        enableLogging: true,
        enableMetrics: true,
        maxExecutionSteps: 1000,                            // 預設：1000 個步驟
        validateGraphIntegrity: true,
        executionTimeout: TimeSpan.FromMinutes(10),         // 預設：10 分鐘
        enablePlanCompilation: true
    );
}
```

### 執行逾時

系統會自動強制執行逾時：

```csharp
// Build effective cancellation token honoring overall execution timeout
if (ExecutionOptions.ExecutionTimeout > TimeSpan.Zero)
{
    _executionTimeoutCts = new CancellationTokenSource(ExecutionOptions.ExecutionTimeout);
    var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, _executionTimeoutCts.Token);
    _effectiveCancellationToken = linked.Token;
}
```

### 步驟限制

如果超過最大步驟計數，執行會自動終止：

```csharp
// Respect per-execution options for max steps
var maxIterations = Math.Max(1, context.ExecutionOptions.MaxExecutionSteps);
var iterations = 0;

while (currentNode != null && iterations < maxIterations)
{
    // ... execution logic
    iterations++;
}

if (iterations >= maxIterations)
{
    throw new InvalidOperationException($"Graph execution exceeded maximum steps ({maxIterations}). Possible infinite loop detected.");
}
```

## 執行優先級

系統透過 `ExecutionPriority` 列舉支援基於優先級的資源配置和排程。

### 優先級

```csharp
public enum ExecutionPriority
{
    Low = 0,        // 低優先級（消耗更多資源）
    Normal = 1,     // 正常優先級（預設）
    High = 2,       // 高優先級（消耗更少資源）
    Critical = 3    // 關鍵優先級（最高優先級）
}
```

### 基於優先級的資源配置

```csharp
// Determine cost and priority
var priority = context.GraphState.KernelArguments.GetExecutionPriority() ?? _resourceOptions.DefaultPriority;
var nodeCost = 1.0;

// Priority affects resource consumption
var priorityFactor = priority switch
{
    ExecutionPriority.Critical => 0.5,  // 50% 資源消耗
    ExecutionPriority.High => 0.6,      // 60% 資源消耗
    ExecutionPriority.Normal => 1.0,    // 100% 資源消耗
    _ => 1.5                            // 150% 資源消耗
};

var adjustedCost = Math.Max(0.5, workCostWeight * priorityFactor);
```

### 設定執行優先級

優先級可以在執行層級設定：

```csharp
// Set priority for the entire execution
arguments.SetExecutionPriority(ExecutionPriority.High);

// Set priority for specific nodes
arguments.SetNodePriority("nodeId", ExecutionPriority.Critical);
```

## 確定性工作佇列

`DeterministicWorkQueue` 為 Graph 執行提供穩定、可重現的排程。

### 主要功能

```csharp
public sealed class DeterministicWorkQueue
{
    public string ExecutionId { get; }                      // 關聯的執行 ID
    public int Count { get; }                               // 待定的工作項目
    
    // Enqueue operations
    public ScheduledNodeWorkItem Enqueue(IGraphNode node, int priority = 0)
    public IReadOnlyList<ScheduledNodeWorkItem> EnqueueRange(IEnumerable<IGraphNode> nodes, int priority = 0)
    
    // Dequeue operations
    public bool TryDequeue(out ScheduledNodeWorkItem? item)
    
    // Deterministic ordering
    public IReadOnlyList<IGraphNode> OrderDeterministically(IEnumerable<IGraphNode> nodes)
    
    // Work stealing (for parallel execution)
    public IReadOnlyList<ScheduledNodeWorkItem> TryStealFrom(DeterministicWorkQueue victim, int maxItemsToSteal = 1, int minPriority = int.MinValue)
}
```

### 確定性排序

佇列確保執行中的穩定排序：

```csharp
public IReadOnlyList<IGraphNode> OrderDeterministically(IEnumerable<IGraphNode> nodes)
{
    return nodes
        .Where(n => n != null)
        .OrderBy(n => n.NodeId, StringComparer.Ordinal)      // 主要：NodeId
        .ThenBy(n => n.Name, StringComparer.Ordinal)         // 次要：Name
        .ToList()
        .AsReadOnly();
}
```

### 工作項目結構

```csharp
public sealed class ScheduledNodeWorkItem
{
    public string WorkId { get; }                           // 唯一的工作識別符
    public string ExecutionId { get; }                      // 關聯的執行
    public long SequenceNumber { get; }                     // 單調遞增序號
    public IGraphNode Node { get; }                         // 要執行的 Node
    public int Priority { get; }                            // 執行優先級
    public DateTimeOffset ScheduledAt { get; }              // 排程時間戳
}
```

## 資源管理

執行上下文與資源管理集成，以管理 CPU、記憶體和 API 配額。

### 資源獲取

```csharp
// Acquire resource permits before node execution
using var lease = _resourceGovernor != null
    ? await _resourceGovernor.AcquireAsync(nodeCost, priority, context.CancellationToken)
    : default;

// Resource permits are automatically released when the lease is disposed
```

### 資源選項

```csharp
public sealed class GraphResourceOptions
{
    public bool EnableResourceGovernance { get; set; }      // 啟用/停用管理
    public double CpuHighWatermarkPercent { get; set; }     // CPU 閾值（預設：85%）
    public double CpuSoftLimitPercent { get; set; }         // 軟 CPU 限制（預設：70%）
    public double MinAvailableMemoryMB { get; set; }        // 最小記憶體（預設：512MB）
    public double BasePermitsPerSecond { get; set; }        // 基本速率（預設：50/s）
    public int MaxBurstSize { get; set; }                   // 最大突增（預設：100）
    public ExecutionPriority DefaultPriority { get; set; }  // 預設優先級
}
```

## 使用範例

以下是簡潔、可執行的 C# 程式碼片段，與 examples 資料夾中的實作相符。每個程式碼片段都有註解，以便任何層級的讀者都能理解。

### 基本執行上下文（可執行）

```csharp
// Minimal runnable example that creates a kernel with graph support,
// builds a tiny graph and consumes streaming execution events.
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Streaming;

// Build kernel and enable graph features
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport()
    .Build();

// Create a streaming executor that emits events during execution
var executor = new StreamingGraphExecutor("ExecutionContextDemo", "Demo of execution context");

// Create three simple nodes: start -> work -> end
var startNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "start", "start_fn", "Start node"),
    "start", "Start Node");

var workNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // Demonstrate storing a property in the execution arguments
        args["processedAt"] = DateTimeOffset.UtcNow;
        return "work-done";
    }, "work_fn", "Work node"),
    "work", "Work Node").StoreResultAs("workResult");

var endNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "end", "end_fn", "End node"),
    "end", "End Node");

// Assemble and configure the graph
executor.AddNode(startNode);
executor.AddNode(workNode);
executor.AddNode(endNode);
executor.Connect("start", "work");
executor.Connect("work", "end");
executor.SetStartNode("start");

// Initial execution arguments/state
var arguments = new KernelArguments { ["input"] = "sample-input" };

// Consume events produced by the streaming executor in real-time
await foreach (var evt in executor.ExecuteStreamAsync(kernel, arguments))
{
    Console.WriteLine($"Event: {evt.EventType} at {evt.Timestamp:HH:mm:ss.fff}");
}

// Inspect final state after execution
Console.WriteLine("\n=== Final State ===");
foreach (var kvp in arguments)
{
    Console.WriteLine($"  {kvp.Key}: {kvp.Value}");
}
```

### 設定執行優先級

```csharp
// Use KernelArguments helpers to set execution-level and per-node priorities
arguments.SetExecutionPriority(ExecutionPriority.High);
arguments.SetNodePriority("dataProcessing", ExecutionPriority.Critical);
arguments.SetNodePriority("logging", ExecutionPriority.Low);
```

### 監視執行事件（模式）

```csharp
// The streaming executor yields strongly-typed event instances.
// This pattern shows how to react to important lifecycle events.
await foreach (var evt in eventStream)
{
    switch (evt)
    {
        case GraphExecutionStartedEvent started:
            Console.WriteLine($"Execution started: {started.ExecutionId}");
            break;

        case NodeExecutionStartedEvent nodeStarted:
            Console.WriteLine($"Node started: {nodeStarted.Node.Name}");
            break;

        case NodeExecutionCompletedEvent completed:
            Console.WriteLine($"Node completed: {completed.Node.Name} in {completed.ExecutionDuration.TotalMilliseconds:F0}ms");
            break;

        case NodeExecutionFailedEvent failed:
            Console.WriteLine($"Node failed: {failed.Node.Name} - {failed.Exception.Message}");
            break;
    }
}
```

### 資源感知執行

```csharp
// Configure resource governance options for the executor to honor
// CPU/memory quotas and prioritization.
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    CpuHighWatermarkPercent = 80.0,
    MinAvailableMemoryMB = 1024.0,
    DefaultPriority = ExecutionPriority.Normal
};

// Executors that integrate with a resource governor will use these
// options to acquire/release permits automatically per node execution.
```

### 可執行範例來源

上述文件程式碼片段由 `examples` 資料夾中包含的完全可執行範例來執行。使用該範例在本機重現此處所示的行為。

**執行範例**：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- execution-context
```

**原始檔案**：`semantic-kernel-graph-docs/examples/ExecutionContextExample.cs`（可執行且已測試）

## 另請參閱

* [執行模型](../concepts/execution-model.md) - 核心執行概念和生命週期
* [資源管理](../how-to/resource-governance-and-concurrency.md) - 資源管理和並行
* [串流執行](../concepts/streaming.md) - 即時執行監視
* [錯誤處理](../how-to/error-handling-and-resilience.md) - 錯誤原則和恢復
* [GraphExecutor API](./graph-executor.md) - 主要執行器介面
