# 串流 API 參考

本參考文件說明 SemanticKernel.Graph 中的串流執行 API，這些 API 可實現對圖形執行的即時監控和事件驅動處理。

## IStreamingGraphExecutor

在執行過程中發出事件的串流圖形執行器介面。

### 方法

#### ExecuteStreamAsync

```csharp
IGraphExecutionEventStream ExecuteStreamAsync(
    Kernel kernel,
    KernelArguments arguments,
    StreamingExecutionOptions? options = null,
    CancellationToken cancellationToken = default)
```

執行圖形並返回執行事件的串流。

**參數：**
* `kernel`：Semantic kernel 實例
* `arguments`：執行的初始參數
* `options`：可選的串流執行選項
* `cancellationToken`：取消權杖

**返回值：** 執行事件串流

#### ExecuteStreamFromAsync

```csharp
IGraphExecutionEventStream ExecuteStreamFromAsync(
    string startNodeId,
    Kernel kernel,
    KernelArguments arguments,
    StreamingExecutionOptions? options = null,
    CancellationToken cancellationToken = default)
```

從特定節點開始執行圖形，並返回執行事件的串流。

**參數：**
* `startNodeId`：要開始執行的節點 ID
* `kernel`：Semantic kernel 實例
* `arguments`：執行的初始參數
* `options`：可選的串流執行選項
* `cancellationToken`：取消權杖

**返回值：** 執行事件串流

## IGraphExecutionEventStream

表示圖形執行事件的實時串流。提供對執行事件發生時進行非同步迭代的功能。

### 屬性

* `ExecutionId`：取得此串流的執行識別碼
* `Status`：取得執行串流的目前狀態
* `CreatedAt`：取得建立串流的時間戳
* `EventCount`：取得此串流發出的事件總數
* `IsCompleted`：指示串流是否已完成
* `CompletionResult`：取得完成結果（如果已完成）

### 事件

* `StatusChanged`：串流狀態變更時引發的事件
* `EventEmitted`：向串流發出新事件時引發的事件
* `SerializedEventEmitted`：事件的序列化裝載可用時引發的事件

### 方法

#### WaitForCompletionAsync

```csharp
Task<StreamCompletionResult> WaitForCompletionAsync(TimeSpan timeout)
```

等待串流完成，超時時間為指定的時間。

**參數：**
* `timeout`：等待完成的最大時間

**返回值：** 完成結果

## StreamingExecutionOptions

串流執行的組態選項。

### 緩衝區組態

```csharp
public int BufferSize { get; set; } = 100;                    // 初始緩衝區大小
public int MaxBufferSize { get; set; } = 1000;                // 背壓前的最大緩衝區大小
public int ProducerBatchSize { get; set; } = 1;               // 生產者端批處理大小（沖刷前）
public TimeSpan? ProducerFlushInterval { get; set; }          // 可選的沖刷間隔
```

### 重新連接設定

```csharp
public bool EnableAutoReconnect { get; set; } = true;         // 啟用自動重新連接
public int MaxReconnectAttempts { get; set; } = 3;            // 最大重新連接嘗試次數
public TimeSpan InitialReconnectDelay { get; set; } = TimeSpan.FromSeconds(1);  // 初始延遲
public TimeSpan MaxReconnectDelay { get; set; } = TimeSpan.FromSeconds(30);     // 最大延遲
```

### 事件組態

```csharp
public bool IncludeStateSnapshots { get; set; } = false;      // 包含中間狀態快照
public GraphExecutionEventType[]? EventTypesToEmit { get; set; }  // 要發出的事件類型
public List<IGraphExecutionEventHandler> EventHandlers { get; set; } = new();  // 自訂事件處理器
```

### 心跳組態

```csharp
public bool EnableHeartbeat { get; set; } = false;            // 啟用心跳事件
public TimeSpan HeartbeatInterval { get; set; } = TimeSpan.FromSeconds(30);  // 心跳間隔
```

### 壓縮和序列化

```csharp
public bool EnableEventCompression { get; set; } = false;     // 啟用事件壓縮
public CompressionAlgorithm CompressionAlgorithm { get; set; } = CompressionAlgorithm.Gzip;  // 壓縮演算法
public int CompressionThresholdBytes { get; set; } = 8 * 1024;  // 壓縮前的最小大小
public bool AdaptiveEventCompressionEnabled { get; set; } = true;  // 啟用自適應壓縮決策
public int AdaptiveEventCompressionWindowSize { get; set; } = 32;  // 滑動視窗大小
public double AdaptiveEventCompressionMinSavingsRatio { get; set; } = 0.10;  // 最小節省比率
```

### 記憶體映射緩衝區選項

```csharp
public bool UseMemoryMappedSerializedBuffer { get; set; } = false;  // 使用記憶體映射檔案
public int MemoryMappedSerializedThresholdBytes { get; set; } = 64 * 1024;  // 記憶體映射緩衝區的最小大小
public string MemoryMappedBufferDirectory { get; set; } = Path.GetTempPath();  // 緩衝區目錄
public long MemoryMappedFileSizeBytes { get; set; } = 64L * 1024 * 1024;  // 最大檔案大小
```

## GraphExecutionEvent

串流系統中所有圖形執行事件的基底類別。

### 屬性

* `EventId`：此事件的唯一識別碼
* `ExecutionId`：此事件所屬的執行識別碼
* `Timestamp`：此事件發生的時間戳
* `EventType`：此事件的類型
* `HighPrecisionTimestamp`：單調高精度時間戳（Stopwatch 計時周期）
* `HighPrecisionFrequency`：高精度計時器的頻率

## 事件類型

### 執行事件

#### GraphExecutionStartedEvent

在圖形執行開始時引發。

**屬性：**
* `StartNode`：執行的起始節點
* `InitialState`：初始圖形狀態

#### GraphExecutionCompletedEvent

在圖形執行成功完成時引發。

**屬性：**
* `FinalResult`：最終執行結果
* `FinalState`：最終圖形狀態
* `TotalDuration`：總執行時間
* `NodesExecuted`：已執行的節點數

#### GraphExecutionFailedEvent

在圖形執行失敗時引發。

**屬性：**
* `Exception`：導致失敗的例外狀況
* `FinalState`：最終圖形狀態
* `TotalDuration`：總執行時間
* `NodesExecuted`：失敗前已執行的節點數

#### GraphExecutionCancelledEvent

在圖形執行被取消時引發。

**屬性：**
* `FinalState`：最終圖形狀態
* `TotalDuration`：總執行時間
* `NodesExecuted`：取消前已執行的節點數

### 節點事件

#### NodeExecutionStartedEvent

在節點開始執行時引發。

**屬性：**
* `Node`：開始執行的節點
* `CurrentState`：目前圖形狀態

#### NodeExecutionCompletedEvent

在節點成功完成執行時引發。

**屬性：**
* `Node`：完成執行的節點
* `Result`：執行結果
* `UpdatedState`：節點執行後的更新圖形狀態
* `ExecutionDuration`：節點執行時間

#### NodeExecutionFailedEvent

在節點執行失敗時引發。

**屬性：**
* `Node`：執行失敗的節點
* `Exception`：執行期間發生的例外狀況
* `CurrentState`：失敗時的目前圖形狀態
* `ExecutionDuration`：失敗前的執行時間

#### NodeEnteredEvent

當執行器進入節點（選為目前節點）時引發。

**屬性：**
* `Node`：進入的節點
* `CurrentState`：進入節點時的目前圖形狀態

#### NodeExitedEvent

當執行器離開節點（導航決策後）時引發。

**屬性：**
* `Node`：離開的節點
* `UpdatedState`：離開節點時的更新圖形狀態

### 條件和控制事件

#### ConditionEvaluatedEvent

在條件節點評估條件時引發。

**屬性：**
* `NodeId`：條件節點的 ID
* `NodeName`：條件節點的名稱
* `Expression`：評估的運算式（如果是基於範本的）
* `Result`：布林值評估結果
* `EvaluationDuration`：評估所花費的時間
* `State`：評估時的圖形狀態

#### StateMergeConflictEvent

在執行期間檢測到狀態合併衝突時引發。

**屬性：**
* `ConflictKey`：發生衝突的參數鍵
* `BaseValue`：基底狀態中的值
* `OverlayValue`：覆蓋狀態中的值
* `ConflictPolicy`：檢測到衝突的合併原則
* `ResolvedValue`：衝突解決後使用的值
* `NodeId`：發生衝突的節點 ID
* `WasResolved`：衝突是否已自動解決

### 斷路器事件

#### CircuitBreakerStateChangedEvent

當斷路器狀態變更時引發。

**屬性：**
* `NodeId`：節點識別碼
* `OldState`：以前的斷路器狀態
* `NewState`：新的斷路器狀態

#### CircuitBreakerOperationAttemptedEvent

當嘗試斷路器操作時引發。

**屬性：**
* `NodeId`：節點識別碼
* `OperationType`：嘗試的操作類型
* `CircuitState`：目前的斷路器狀態

#### CircuitBreakerOperationBlockedEvent

當斷路器阻止操作時引發。

**屬性：**
* `NodeId`：節點識別碼
* `Reason`：阻止操作的原因
* `CircuitState`：目前的斷路器狀態
* `FailureCount`：目前的失敗計數

### 資源和錯誤原則事件

#### ResourceBudgetExhaustedEvent

當資源預算用盡時引發。

**屬性：**
* `NodeId`：節點識別碼
* `ResourceType`：已用盡的資源類型
* `RequestedAmount`：要求的資源數量
* `AvailableAmount`：可用的資源數量

#### RetryScheduledEvent

當由於錯誤原則決策而排定重試時引發。

**屬性：**
* `NodeId`：節點識別碼
* `NodeName`：節點名稱
* `AttemptNumber`：重試嘗試號碼
* `Delay`：重試前的可選延遲

#### NodeSkippedDueToErrorPolicyEvent

當由於錯誤原則決策而跳過節點時引發。

**屬性：**
* `NodeId`：節點識別碼
* `NodeName`：節點名稱
* `Reason`：跳過節點的原因

## GraphExecutionEventType 列舉

圖形執行事件的不同類型的列舉。

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
    NodeExited = 8,                 // 執行器已離開節點
    ConditionEvaluated = 9,         // 條件運算式已評估
    StateMergeConflictDetected = 10, // 檢測到狀態合併衝突
    CircuitBreakerStateChanged = 11, // 斷路器狀態已變更
    CircuitBreakerOperationAttempted = 12, // 嘗試斷路器操作
    CircuitBreakerOperationBlocked = 13,   // 斷路器操作已被阻止
    ResourceBudgetExhausted = 14,   // 資源預算已用盡
    RetryScheduled = 15,            // 重試已排定
    NodeSkippedDueToErrorPolicy = 16 // 由於錯誤原則而跳過節點
}
```

## StreamingGraphExecutor

在執行期間發出實時事件的串流啟用圖形執行器。

### 建構函式

```csharp
public StreamingGraphExecutor(string name, string? description = null, IGraphLogger? logger = null)
public StreamingGraphExecutor(GraphExecutor executor)
```

### 屬性

* `Name`：圖形的名稱
* `Description`：圖形的描述
* `GraphId`：圖形的唯一識別碼
* `IsReadyForExecution`：圖形是否已準備好執行
* `NodeCount`：圖形中的節點數

### 方法

#### 圖形管理

```csharp
public void AddNode(IGraphNode node)
public void Connect(string fromNodeId, string toNodeId, ConditionalEdge? edge = null)
public void SetStartNode(string nodeId)
public ValidationResult ValidateGraphIntegrity()
```

#### 執行

```csharp
public Task<FunctionResult> ExecuteAsync(Kernel kernel, KernelArguments arguments, CancellationToken cancellationToken = default)
public IGraphExecutionEventStream ExecuteStreamAsync(Kernel kernel, KernelArguments arguments, StreamingExecutionOptions? options = null, CancellationToken cancellationToken = default)
public IGraphExecutionEventStream ExecuteStreamFromAsync(string startNodeId, Kernel kernel, KernelArguments arguments, StreamingExecutionOptions? options = null, CancellationToken cancellationToken = default)
```

## 串流擴充

### 轉換執行器

```csharp
// 將一般執行器轉換為串流執行器
var streamingExecutor = regularExecutor.AsStreamingExecutor();
```

### 建立選項

```csharp
// 使用流暢 API 建立
var options = StreamingExtensions.CreateStreamingOptions()
    .Configure()
    .WithBufferSize(100)
    .WithEventTypes(GraphExecutionEventType.ExecutionStarted, GraphExecutionEventType.NodeCompleted)
    .Build();
```

### 串流處理

```csharp
// 篩選事件
var filteredStream = eventStream.Filter(GraphExecutionEventType.NodeCompleted);

// 緩衝事件
var bufferedStream = eventStream.WithBuffering(50);

// 轉換為 API 回應
var apiResponses = eventStream.ToApiResponses().WithHeartbeat(TimeSpan.FromSeconds(5));
```

## 追蹤和相互關聯

SemanticKernel.Graph 透過 OpenTelemetry 的 `ActivitySource` 提供全面的分散式追蹤功能，可實現執行事件和追蹤跨距之間的相互關聯，以供可觀察性和偵錯使用。

### ActivitySource 整合

框架會使用名為「SemanticKernel.Graph」的 `ActivitySource` 自動為圖形執行和單個節點操作建立追蹤跨距。

#### 圖形級追蹤

```csharp
// 具有相關聯標籤的圖形執行跨距
using var execActivity = _activitySource.StartActivity("Graph.Execute", ActivityKind.Internal);
if (execActivity is not null)
{
    execActivity.SetTag("graph.id", GraphId);
    execActivity.SetTag("graph.name", Name);
    execActivity.SetTag("execution.id", context.ExecutionId);
    execActivity.SetTag("start.node.id", StartNode?.NodeId);
    execActivity.SetTag("node.count", NodeCount);
}
```

#### 節點級追蹤

```csharp
// 每個節點執行跨距，包含相關聯標籤
using var nodeActivity = _activitySource.StartActivity("Graph.Node.Execute", ActivityKind.Internal);
if (nodeActivity is not null)
{
    nodeActivity.SetTag("graph.id", GraphId);
    nodeActivity.SetTag("graph.name", Name);
    nodeActivity.SetTag("execution.id", context.ExecutionId);
    nodeActivity.SetTag("node.id", currentNode.NodeId);
    nodeActivity.SetTag("node.name", currentNode.Name);
}
```

### 事件相互關聯

所有執行事件都包含相互關聯識別碼，將它們連結到對應的追蹤跨距：

#### 執行相互關聯

* **`ExecutionId`**：每個圖形執行執行的唯一識別碼
* **`GraphId`**：圖形定義的穩定識別碼
* **`EventId`**：每個個別事件的唯一識別碼

#### 節點相互關聯

* **`NodeId`**：特定節點的穩定識別碼
* **`NodeName`**：節點的人類可讀名稱
* **`Timestamp`**：事件發生的精確時間戳
* **`HighPrecisionTimestamp`**：用於精確排序的單調時間戳

### 多代理分散式追蹤

對於多代理工作流，`MultiAgentCoordinator` 提供額外的追蹤功能：

```csharp
// 工作流級追蹤跨距
using var activity = _activitySource?.StartActivity(
    "MultiAgent.ExecuteWorkflow",
    ActivityKind.Internal);
if (activity is not null)
{
    activity.SetTag("workflow.id", workflowId);
    activity.SetTag("workflow.name", workflow.Name);
    activity.SetTag("workflow.task.count", workflow.Tasks.Count);
    activity.SetTag("workflow.agents.count", workflow.RequiredAgents.Count);
}
```

### 追蹤組態

透過 `MultiAgentOptions` 在多代理情況中啟用分散式追蹤：

```csharp
var options = new MultiAgentOptions
{
    EnableDistributedTracing = true,
    DistributedTracingSourceName = "SemanticKernel.Graph.MultiAgent"
};
```

### 相互關聯模式

#### 執行流程相互關聯

```csharp
// 事件和跨距共用相同的 execution.id
var execStarted = events.OfType<GraphExecutionStartedEvent>().First();
var execSpan = activities.First(a => 
    a.Tags.Any(t => t.Key == "execution.id" && 
    t.Value?.ToString() == execStarted.ExecutionId));
```

#### 節點執行相互關聯

```csharp
// 節點事件透過 execution.id 和 node.id 與節點跨距相互關聯
var nodeStarted = events.OfType<NodeExecutionStartedEvent>().First();
var nodeSpan = activities.First(a => 
    a.Tags.Any(t => t.Key == "execution.id" && 
    t.Value?.ToString() == nodeStarted.ExecutionId) &&
    a.Tags.Any(t => t.Key == "node.id" && 
    t.Value?.ToString() == nodeStarted.Node.NodeId));
```

### 高精度計時

事件包含高精度時間戳，用於精確的效能測量：

```csharp
public class GraphExecutionEvent
{
    // 單調高精度時間戳（Stopwatch 計時周期）
    public long HighPrecisionTimestamp { get; }
    
    // 高精度計時器的頻率
    public long HighPrecisionFrequency { get; }
}
```

### 追蹤最佳做法

1. **相互關聯 ID**：始終使用 `ExecutionId` 和 `NodeId` 在系統間相互關聯事件
2. **跨距命名**：使用一致的跨距名稱：`Graph.Execute`、`Graph.Node.Execute`、`MultiAgent.ExecuteWorkflow`
3. **標籤一致性**：在所有跨距中應用一致的標籤：`graph.id`、`execution.id`、`node.id`
4. **錯誤追蹤**：當發生例外狀況時，在跨距上設定錯誤標籤
5. **效能指標**：使用高精度時間戳進行精確的延遲測量

## 另請參閱

* [串流快速入門](../streaming-quickstart.md) - 開始使用串流執行
* [串流概念](../concepts/streaming.md) - 深入瞭解串流概念
* [串流範例](../examples/streaming-execution.md) - 實用的串流範例
* [GraphExecutor 參考](./graph-executor.md) - 核心圖形執行 API
* [狀態管理參考](./state.md) - 圖形狀態和序列化
* [指標和可觀察性](../how-to/metrics-and-observability.md) - 全面的可觀察性指南
