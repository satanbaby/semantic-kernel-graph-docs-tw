# 執行上下文與事件

本參考資料涵蓋了在 SemanticKernel.Graph 中管理圖形執行的執行上下文、事件、限制和優先級。

## GraphExecutionContext

`GraphExecutionContext` 維護單個圖形運行的執行狀態，追蹤執行進度、管理資源並提供協調服務。

### 核心屬性

```csharp
public sealed class GraphExecutionContext
{
    // 執行識別
    public string ExecutionId { get; }                    // 唯一的執行識別碼
    public int ExecutionSeed { get; }                     // 用於可重複隨機性的種子
    public Random Random { get; }                         // 帶種子的隨機數產生器
    
    // 核心與狀態
    public Kernel Kernel { get; }                         // 語義核心實例
    public IKernelWrapper KernelWrapper { get; }          // 核心包裝器
    public GraphState GraphState { get; set; }            // 目前圖形狀態
    
    // 執行控制
    public CancellationToken CancellationToken { get; }   // 有效的取消令牌
    public GraphExecutionOptions ExecutionOptions { get; } // 不可變的執行選項
    
    // 時間和狀態
    public DateTimeOffset StartTime { get; }              // 執行開始時間戳
    public DateTimeOffset? EndTime { get; }               // 執行結束時間戳
    public TimeSpan? Duration { get; }                    // 總執行持續時間
    public GraphExecutionStatus Status { get; }           // 目前執行狀態
    
    // 執行狀態
    public bool IsPaused { get; }                         // 執行是否暫停
    public string? PauseReason { get; }                   // 暫停原因
    public IGraphNode? CurrentNode { get; }               // 目前執行的節點
    public IReadOnlyList<IGraphNode> ExecutionPath { get; } // 執行路徑
    public int NodesExecuted { get; }                     // 已執行的節點數
    
    // 工作管理
    public DeterministicWorkQueue WorkQueue { get; }      // 確定性工作隊列
}
```

### 執行狀態

`GraphExecutionStatus` 列舉表示執行的目前狀態：

```csharp
public enum GraphExecutionStatus
{
    NotStarted = 0,    // 執行尚未開始
    Running = 1,       // 執行正在進行中
    Completed = 2,     // 執行成功完成
    Failed = 3,        // 執行失敗並出現錯誤
    Cancelled = 4,     // 執行已取消
    Paused = 5         // 執行暫停等待繼續
}
```

### 狀態管理方法

```csharp
// 執行生命週期
public void MarkAsStarted(IGraphNode startingNode)           // 標記執行已開始
public void MarkAsCompleted(FunctionResult result)           // 標記執行已完成
public void MarkAsFailed(Exception error)                    // 標記執行已失敗
public void MarkAsCancelled()                                // 標記執行已取消

// 節點追蹤
public void RecordNodeStarted(IGraphNode node)               // 記錄節點執行開始
public void RecordNodeCompleted(IGraphNode node, FunctionResult result) // 記錄節點完成
public void RecordNodeFailed(IGraphNode node, Exception exception)     // 記錄節點失敗

// 工作隊列管理
public void EnqueueNextNodes(IEnumerable<IGraphNode> candidates) // 排隊下一批節點

// 暫停/繼續控制
public void Pause(string reason)                             // 暫停執行
public void Resume()                                          // 繼續執行
public Task WaitIfPausedAsync(CancellationToken cancellationToken) // 如果暫停則等待
```

### 屬性管理

```csharp
public void SetProperty<T>(string key, T value)              // 設定自訂屬性
public T? GetProperty<T>(string key)                         // 取得自訂屬性
public bool TryGetProperty<T>(string key, out T? value)      // 嘗試取得屬性
public void RemoveProperty(string key)                        // 移除屬性
```

## 執行事件

執行系統會發出即時事件，提供對執行進度和狀態變更的可見性。

### GraphExecutionEvent 基類

所有執行事件都繼承自 `GraphExecutionEvent`：

```csharp
public abstract class GraphExecutionEvent
{
    public string EventId { get; }                          // 唯一的事件識別碼
    public string ExecutionId { get; }                      // 相關的執行 ID
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
    ExecutionStarted = 0,           // 圖形執行已開始
    NodeStarted = 1,                // 節點執行已開始
    NodeCompleted = 2,              // 節點執行成功完成
    NodeFailed = 3,                 // 節點執行失敗
    ExecutionCompleted = 4,         // 圖形執行成功完成
    ExecutionFailed = 5,            // 圖形執行失敗
    ExecutionCancelled = 6,         // 圖形執行已取消
    NodeEntered = 7,                // 執行器已進入節點
    NodeExited = 8,                 // 執行器已退出節點
    ConditionEvaluated = 9,         // 條件運算式已評估
    StateMergeConflictDetected = 10, // 偵測到狀態合併衝突
    CircuitBreakerStateChanged = 11, // 斷路器狀態已變更
    CircuitBreakerOperationAttempted = 12, // 斷路器操作已嘗試
    CircuitBreakerOperationBlocked = 13,   // 斷路器操作已被阻止
    ResourceBudgetExhausted = 14,   // 資源預算已耗盡
    RetryScheduled = 15,            // 已排程重試
    NodeSkippedDueToErrorPolicy = 16 // 因錯誤策略而略過節點
}
```

### 主要事件類別

#### GraphExecutionStartedEvent
```csharp
public sealed class GraphExecutionStartedEvent : GraphExecutionEvent
{
    public IGraphNode StartNode { get; }                    // 起始節點
    public GraphState InitialState { get; }                 // 初始圖形狀態
}
```

#### NodeExecutionStartedEvent
```csharp
public sealed class NodeExecutionStartedEvent : GraphExecutionEvent
{
    public IGraphNode Node { get; }                         // 已開始的節點
    public GraphState CurrentState { get; }                 // 目前狀態
}
```

#### NodeExecutionCompletedEvent
```csharp
public sealed class NodeExecutionCompletedEvent : GraphExecutionEvent
{
    public IGraphNode Node { get; }                         // 已完成的節點
    public FunctionResult Result { get; }                   // 執行結果
    public GraphState UpdatedState { get; }                 // 更新後的狀態
    public TimeSpan ExecutionDuration { get; }              // 執行持續時間
}
```

#### NodeExecutionFailedEvent
```csharp
public sealed class NodeExecutionFailedEvent : GraphExecutionEvent
{
    public IGraphNode Node { get; }                         // 失敗的節點
    public Exception Exception { get; }                     // 發生的異常
    public GraphState CurrentState { get; }                 // 目前狀態
    public TimeSpan ExecutionDuration { get; }              // 執行持續時間
}
```

## 執行限制和防護措施

執行系統提供多層保護，防止執行失控和資源耗盡。

### 執行選項

```csharp
public sealed class GraphExecutionOptions
{
    public bool EnableLogging { get; }                      // 是否啟用日誌記錄
    public bool EnableMetrics { get; }                      // 是否啟用度量
    public int MaxExecutionSteps { get; }                   // 最大執行步數
    public bool ValidateGraphIntegrity { get; }             // 是否驗證圖形
    public TimeSpan ExecutionTimeout { get; }               // 整體執行逾時
    public bool EnablePlanCompilation { get; }              // 是否啟用計劃編譯
}
```

### 預設限制

```csharp
public static GraphExecutionOptions CreateDefault()
{
    return new GraphExecutionOptions(
        enableLogging: true,
        enableMetrics: true,
        maxExecutionSteps: 1000,                            // 預設：1000 步
        validateGraphIntegrity: true,
        executionTimeout: TimeSpan.FromMinutes(10),         // 預設：10 分鐘
        enablePlanCompilation: true
    );
}
```

### 執行逾時

系統自動強制執行逾時：

```csharp
// 建立尊重整體執行逾時的有效取消令牌
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
// 尊重每個執行的最大步數選項
var maxIterations = Math.Max(1, context.ExecutionOptions.MaxExecutionSteps);
var iterations = 0;

while (currentNode != null && iterations < maxIterations)
{
    // ... 執行邏輯
    iterations++;
}

if (iterations >= maxIterations)
{
    throw new InvalidOperationException($"圖形執行超過最大步數 ({maxIterations})。偵測到可能的無窮迴圈。");
}
```

## 執行優先級

系統透過 `ExecutionPriority` 列舉支持基於優先級的資源分配和排程。

### 優先級等級

```csharp
public enum ExecutionPriority
{
    Low = 0,        // 低優先級（消耗更多資源）
    Normal = 1,     // 正常優先級（預設）
    High = 2,       // 高優先級（消耗較少資源）
    Critical = 3    // 關鍵優先級（最高優先級）
}
```

### 基於優先級的資源分配

```csharp
// 確定成本和優先級
var priority = context.GraphState.KernelArguments.GetExecutionPriority() ?? _resourceOptions.DefaultPriority;
var nodeCost = 1.0;

// 優先級影響資源消耗
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

優先級可在執行級別設定：

```csharp
// 設定整個執行的優先級
arguments.SetExecutionPriority(ExecutionPriority.High);

// 設定特定節點的優先級
arguments.SetNodePriority("nodeId", ExecutionPriority.Critical);
```

## 確定性工作隊列

`DeterministicWorkQueue` 為圖形執行提供穩定、可重複的排程。

### 主要功能

```csharp
public sealed class DeterministicWorkQueue
{
    public string ExecutionId { get; }                      // 相關的執行 ID
    public int Count { get; }                               // 待處理工作項
    
    // 入隊操作
    public ScheduledNodeWorkItem Enqueue(IGraphNode node, int priority = 0)
    public IReadOnlyList<ScheduledNodeWorkItem> EnqueueRange(IEnumerable<IGraphNode> nodes, int priority = 0)
    
    // 出隊操作
    public bool TryDequeue(out ScheduledNodeWorkItem? item)
    
    // 確定性排序
    public IReadOnlyList<IGraphNode> OrderDeterministically(IEnumerable<IGraphNode> nodes)
    
    // 工作竊取（用於平行執行）
    public IReadOnlyList<ScheduledNodeWorkItem> TryStealFrom(DeterministicWorkQueue victim, int maxItemsToSteal = 1, int minPriority = int.MinValue)
}
```

### 確定性排序

隊列確保執行之間的穩定排序：

```csharp
public IReadOnlyList<IGraphNode> OrderDeterministically(IEnumerable<IGraphNode> nodes)
{
    return nodes
        .Where(n => n != null)
        .OrderBy(n => n.NodeId, StringComparer.Ordinal)      // 主要：NodeId
        .ThenBy(n => n.Name, StringComparer.Ordinal)         // 次要：名稱
        .ToList()
        .AsReadOnly();
}
```

### 工作項結構

```csharp
public sealed class ScheduledNodeWorkItem
{
    public string WorkId { get; }                           // 唯一的工作識別碼
    public string ExecutionId { get; }                      // 相關的執行
    public long SequenceNumber { get; }                     // 單調序列
    public IGraphNode Node { get; }                         // 要執行的節點
    public int Priority { get; }                            // 執行優先級
    public DateTimeOffset ScheduledAt { get; }              // 排程時間戳
}
```

## 資源治理

執行上下文與資源治理整合，以管理 CPU、記憶體和 API 配額。

### 資源取得

```csharp
// 在節點執行前取得資源許可
using var lease = _resourceGovernor != null
    ? await _resourceGovernor.AcquireAsync(nodeCost, priority, context.CancellationToken)
    : default;

// 當租約被處置時，資源許可會自動釋放
```

### 資源選項

```csharp
public sealed class GraphResourceOptions
{
    public bool EnableResourceGovernance { get; set; }      // 啟用/停用治理
    public double CpuHighWatermarkPercent { get; set; }     // CPU 臨界值（預設：85%）
    public double CpuSoftLimitPercent { get; set; }         // CPU 軟性限制（預設：70%）
    public double MinAvailableMemoryMB { get; set; }        // 最小記憶體（預設：512MB）
    public double BasePermitsPerSecond { get; set; }        // 基礎速率（預設：50/s）
    public int MaxBurstSize { get; set; }                   // 最大爆發（預設：100）
    public ExecutionPriority DefaultPriority { get; set; }  // 預設優先級
}
```

## 使用範例

以下是與 examples 資料夾中實現相匹配的簡潔、可執行的 C# 程式碼片段。每個程式碼片段都有註釋，使各層級的讀者都能理解。

### 基本執行上下文（可執行）

```csharp
// 最小可執行範例，它建立具有圖形支持的核心、
// 構建一個小圖形並使用流式執行事件。
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Streaming;

// 建立核心並啟用圖形功能
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport()
    .Build();

// 建立在執行期間發出事件的流式執行器
var executor = new StreamingGraphExecutor("ExecutionContextDemo", "執行上下文演示");

// 建立三個簡單節點：開始 -> 工作 -> 結束
var startNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "start", "start_fn", "開始節點"),
    "start", "開始節點");

var workNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // 演示在執行引數中儲存屬性
        args["processedAt"] = DateTimeOffset.UtcNow;
        return "work-done";
    }, "work_fn", "工作節點"),
    "work", "工作節點").StoreResultAs("workResult");

var endNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "end", "end_fn", "結束節點"),
    "end", "結束節點");

// 組裝並配置圖形
executor.AddNode(startNode);
executor.AddNode(workNode);
executor.AddNode(endNode);
executor.Connect("start", "work");
executor.Connect("work", "end");
executor.SetStartNode("start");

// 初始執行引數/狀態
var arguments = new KernelArguments { ["input"] = "sample-input" };

// 即時消耗流式執行器產生的事件
await foreach (var evt in executor.ExecuteStreamAsync(kernel, arguments))
{
    Console.WriteLine($"事件：{evt.EventType} 於 {evt.Timestamp:HH:mm:ss.fff}");
}

// 執行後檢查最終狀態
Console.WriteLine("\n=== 最終狀態 ===");
foreach (var kvp in arguments)
{
    Console.WriteLine($"  {kvp.Key}: {kvp.Value}");
}
```

### 設定執行優先級

```csharp
// 使用 KernelArguments 助手設定執行級別和每節點優先級
arguments.SetExecutionPriority(ExecutionPriority.High);
arguments.SetNodePriority("dataProcessing", ExecutionPriority.Critical);
arguments.SetNodePriority("logging", ExecutionPriority.Low);
```

### 監控執行事件（模式）

```csharp
// 流式執行器產生強型別事件實例。
// 此模式展示如何對重要的生命週期事件做出反應。
await foreach (var evt in eventStream)
{
    switch (evt)
    {
        case GraphExecutionStartedEvent started:
            Console.WriteLine($"執行已開始：{started.ExecutionId}");
            break;

        case NodeExecutionStartedEvent nodeStarted:
            Console.WriteLine($"節點已開始：{nodeStarted.Node.Name}");
            break;

        case NodeExecutionCompletedEvent completed:
            Console.WriteLine($"節點已完成：{completed.Node.Name}，耗時 {completed.ExecutionDuration.TotalMilliseconds:F0}ms");
            break;

        case NodeExecutionFailedEvent failed:
            Console.WriteLine($"節點失敗：{failed.Node.Name} - {failed.Exception.Message}");
            break;
    }
}
```

### 資源感知執行

```csharp
// 為執行器配置資源治理選項以遵守
// CPU/記憶體配額和優先級。
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    CpuHighWatermarkPercent = 80.0,
    MinAvailableMemoryMB = 1024.0,
    DefaultPriority = ExecutionPriority.Normal
};

// 與資源治理器整合的執行器將使用這些
// 選項自動為每個節點執行取得/釋放許可。
```

### 可執行範例來源

上述文件程式碼片段由 `examples` 資料夾中包含的完全可執行範例演示。使用範例在本地重現此處顯示的行為。

**執行範例**：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- execution-context
```

**來源檔案**：`semantic-kernel-graph-docs/examples/ExecutionContextExample.cs`（可執行且已測試）

## 另請參閱

* [執行模型](../concepts/execution-model.md) - 核心執行概念和生命週期
* [資源治理](../how-to/resource-governance-and-concurrency.md) - 資源管理和並行
* [串流執行](../concepts/streaming.md) - 即時執行監控
* [錯誤處理](../how-to/error-handling-and-resilience.md) - 錯誤策略和復原
* [GraphExecutor API](./graph-executor.md) - 主要執行器介面
