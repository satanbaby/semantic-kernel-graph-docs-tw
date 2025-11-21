# 串流 API 參考

本參考文件記錄 SemanticKernel.Graph 中的串流執行 API，使實時監控和事件驅動的圖形執行處理成為可能。

## IStreamingGraphExecutor

在執行期間發出事件的串流圖形執行器的介面。

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
* `kernel`: Semantic kernel 實例
* `arguments`: 執行的初始參數
* `options`: 可選的串流執行選項
* `cancellationToken`: 取消令牌

**返回：** 執行事件的串流

#### ExecuteStreamFromAsync

```csharp
IGraphExecutionEventStream ExecuteStreamFromAsync(
    string startNodeId,
    Kernel kernel,
    KernelArguments arguments,
    StreamingExecutionOptions? options = null,
    CancellationToken cancellationToken = default)
```

執行從特定 Node 開始的圖形並返回執行事件的串流。

**參數：**
* `startNodeId`: 開始執行的 Node 的 ID
* `kernel`: Semantic kernel 實例
* `arguments`: 執行的初始參數
* `options`: 可選的串流執行選項
* `cancellationToken`: 取消令牌

**返回：** 執行事件的串流

## IGraphExecutionEventStream

代表實時圖形執行事件的串流。提供對執行事件的非同步迭代，當事件發生時立即獲取。

### 屬性

* `ExecutionId`: 取得此串流的執行識別碼
* `Status`: 取得執行串流的目前狀態
* `CreatedAt`: 取得建立串流時的時戳
* `EventCount`: 取得此串流發出的事件總數
* `IsCompleted`: 指示串流是否已完成
* `CompletionResult`: 取得完成結果（如果已完成）

### 事件

* `StatusChanged`: 串流狀態改變時觸發的事件
* `EventEmitted`: 新事件發出到串流時觸發的事件
* `SerializedEventEmitted`: 事件的序列化內容可用時觸發的事件

### 方法

#### WaitForCompletionAsync

```csharp
Task<StreamCompletionResult> WaitForCompletionAsync(TimeSpan timeout)
```

等待串流完成，具有逾時限制。

**參數：**
* `timeout`: 等待完成的最長時間

**返回：** 完成結果

## StreamingExecutionOptions

串流執行的配置選項。

### 緩衝區配置

```csharp
public int BufferSize { get; set; } = 100;                    // 初始緩衝區大小
public int MaxBufferSize { get; set; } = 1000;                // 觸發背壓前的最大緩衝區大小
public int ProducerBatchSize { get; set; } = 1;               // 生產者端批次大小（刷新前）
public TimeSpan? ProducerFlushInterval { get; set; }          // 可選的刷新間隔
```

### 重新連接設定

```csharp
public bool EnableAutoReconnect { get; set; } = true;         // 啟用自動重新連接
public int MaxReconnectAttempts { get; set; } = 3;            // 最大重新連接嘗試次數
public TimeSpan InitialReconnectDelay { get; set; } = TimeSpan.FromSeconds(1);  // 初始延遲
public TimeSpan MaxReconnectDelay { get; set; } = TimeSpan.FromSeconds(30);     // 最大延遲
```

### 事件配置

```csharp
public bool IncludeStateSnapshots { get; set; } = false;      // 包含中間狀態快照
public GraphExecutionEventType[]? EventTypesToEmit { get; set; }  // 要發出的事件類型
public List<IGraphExecutionEventHandler> EventHandlers { get; set; } = new();  // 自訂事件處理器
```

### 心跳配置

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

### 記憶體對應緩衝區選項

```csharp
public bool UseMemoryMappedSerializedBuffer { get; set; } = false;  // 使用記憶體對應檔案
public int MemoryMappedSerializedThresholdBytes { get; set; } = 64 * 1024;  // MM 緩衝區的最小大小
public string MemoryMappedBufferDirectory { get; set; } = Path.GetTempPath();  // 緩衝區目錄
public long MemoryMappedFileSizeBytes { get; set; } = 64L * 1024 * 1024;  // 最大檔案大小
```

## GraphExecutionEvent

串流系統中所有圖形執行事件的基類。

### 屬性

* `EventId`: 此事件的唯一識別碼
* `ExecutionId`: 此事件所屬的執行識別碼
* `Timestamp`: 事件發生時的時戳
* `EventType`: 此事件的類型
* `HighPrecisionTimestamp`: 單調高精度時戳（Stopwatch 計時）
* `HighPrecisionFrequency`: 高精度計時器的頻率

## 事件類型

### 執行事件

#### GraphExecutionStartedEvent

圖形執行開始時觸發。

**屬性：**
* `StartNode`: 執行的起始 Node
* `InitialState`: 初始圖形狀態

#### GraphExecutionCompletedEvent

圖形執行成功完成時觸發。

**屬性：**
* `FinalResult`: 最終執行結果
* `FinalState`: 最終圖形狀態
* `TotalDuration`: 總執行持續時間
* `NodesExecuted`: 執行的 Node 數

#### GraphExecutionFailedEvent

圖形執行失敗時觸發。

**屬性：**
* `Exception`: 導致失敗的例外狀況
* `FinalState`: 最終圖形狀態
* `TotalDuration`: 總執行持續時間
* `NodesExecuted`: 失敗前執行的 Node 數

#### GraphExecutionCancelledEvent

圖形執行被取消時觸發。

**屬性：**
* `FinalState`: 最終圖形狀態
* `TotalDuration`: 總執行持續時間
* `NodesExecuted`: 取消前執行的 Node 數

### Node 事件

#### NodeExecutionStartedEvent

Node 開始執行時觸發。

**屬性：**
* `Node`: 開始執行的 Node
* `CurrentState`: 目前圖形狀態

#### NodeExecutionCompletedEvent

Node 成功完成執行時觸發。

**屬性：**
* `Node`: 完成執行的 Node
* `Result`: 執行結果
* `UpdatedState`: Node 執行後更新的圖形狀態
* `ExecutionDuration`: Node 執行的持續時間

#### NodeExecutionFailedEvent

Node 執行失敗時觸發。

**屬性：**
* `Node`: 執行失敗的 Node
* `Exception`: 執行期間發生的例外狀況
* `CurrentState`: 失敗時的目前圖形狀態
* `ExecutionDuration`: 失敗前的執行持續時間

#### NodeEnteredEvent

執行器進入 Node（選擇為目前 Node）時觸發。

**屬性：**
* `Node`: 進入的 Node
* `CurrentState`: 進入 Node 時的目前圖形狀態

#### NodeExitedEvent

執行器退出 Node（在導航決策之後）時觸發。

**屬性：**
* `Node`: 退出的 Node
* `UpdatedState`: 退出 Node 時更新的圖形狀態

### 條件和控制事件

#### ConditionEvaluatedEvent

條件 Node 評估條件時觸發。

**屬性：**
* `NodeId`: 條件 Node 的 ID
* `NodeName`: 條件 Node 的名稱
* `Expression`: 評估的表達式（如果基於範本）
* `Result`: 布林值評估結果
* `EvaluationDuration`: 評估所需的時間
* `State`: 評估時的圖形狀態

#### StateMergeConflictEvent

在執行期間偵測到狀態合併衝突時觸發。

**屬性：**
* `ConflictKey`: 發生衝突的參數鍵
* `BaseValue`: 基底狀態中的值
* `OverlayValue`: 疊加狀態中的值
* `ConflictPolicy`: 偵測衝突的合併策略
* `ResolvedValue`: 衝突解決後使用的值
* `NodeId`: 發生衝突的 Node ID
* `WasResolved`: 衝突是否自動解決

### 斷路器事件

#### CircuitBreakerStateChangedEvent

斷路器狀態改變時觸發。

**屬性：**
* `NodeId`: Node 識別碼
* `OldState`: 前一個斷路器狀態
* `NewState`: 新的斷路器狀態

#### CircuitBreakerOperationAttemptedEvent

嘗試斷路器操作時觸發。

**屬性：**
* `NodeId`: Node 識別碼
* `OperationType`: 嘗試的操作類型
* `CircuitState`: 目前的斷路器狀態

#### CircuitBreakerOperationBlockedEvent

斷路器阻止操作時觸發。

**屬性：**
* `NodeId`: Node 識別碼
* `Reason`: 阻止操作的原因
* `CircuitState`: 目前的斷路器狀態
* `FailureCount`: 目前的失敗計數

### 資源和錯誤策略事件

#### ResourceBudgetExhaustedEvent

資源預算用盡時觸發。

**屬性：**
* `NodeId`: Node 識別碼
* `ResourceType`: 用盡的資源類型
* `RequestedAmount`: 要求的資源數量
* `AvailableAmount`: 可用的資源數量

#### RetryScheduledEvent

由於錯誤策略決策而排程重試時觸發。

**屬性：**
* `NodeId`: Node 識別碼
* `NodeName`: Node 名稱
* `AttemptNumber`: 重試嘗試次數
* `Delay`: 重試前的可選延遲

#### NodeSkippedDueToErrorPolicyEvent

由於錯誤策略決策而跳過 Node 時觸發。

**屬性：**
* `NodeId`: Node 識別碼
* `NodeName`: Node 名稱
* `Reason`: 跳過 Node 的原因

## GraphExecutionEventType 列舉

不同圖形執行事件類型的列舉。

```csharp
public enum GraphExecutionEventType
{
    ExecutionStarted = 0,           // 圖形執行已開始
    NodeStarted = 1,                // Node 執行已開始
    NodeCompleted = 2,              // Node 執行成功完成
    NodeFailed = 3,                 // Node 執行失敗
    ExecutionCompleted = 4,         // 圖形執行成功完成
    ExecutionFailed = 5,            // 圖形執行失敗
    ExecutionCancelled = 6,         // 圖形執行已取消
    NodeEntered = 7,                // 執行器進入 Node
    NodeExited = 8,                 // 執行器退出 Node
    ConditionEvaluated = 9,         // 條件表達式已評估
    StateMergeConflictDetected = 10, // 偵測到狀態合併衝突
    CircuitBreakerStateChanged = 11, // 斷路器狀態已改變
    CircuitBreakerOperationAttempted = 12, // 嘗試斷路器操作
    CircuitBreakerOperationBlocked = 13,   // 斷路器操作已阻止
    ResourceBudgetExhausted = 14,   // 資源預算已用盡
    RetryScheduled = 15,            // 重試已排程
    NodeSkippedDueToErrorPolicy = 16 // Node 因錯誤策略而被跳過
}
```

## StreamingGraphExecutor

支援串流的圖形執行器，在執行期間發出實時事件。

### 建構式

```csharp
public StreamingGraphExecutor(string name, string? description = null, IGraphLogger? logger = null)
public StreamingGraphExecutor(GraphExecutor executor)
```

### 屬性

* `Name`: 圖形的名稱
* `Description`: 圖形的描述
* `GraphId`: 圖形的唯一識別碼
* `IsReadyForExecution`: 圖形是否準備好執行
* `NodeCount`: 圖形中的 Node 數

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

## 串流擴充功能

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

## 追蹤和相關性

SemanticKernel.Graph 通過 OpenTelemetry 的 `ActivitySource` 提供全面的分散式追蹤功能，實現執行事件與追蹤 span 之間的相關性，便於可觀測性和除錯。

### ActivitySource 整合

框架使用名為 "SemanticKernel.Graph" 的 `ActivitySource` 自動為圖形執行和個別 Node 操作建立追蹤 span。

#### 圖形級別追蹤

```csharp
// 具有相關性標籤的圖形執行 span
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

#### Node 級別追蹤

```csharp
// 每個 Node 執行 span，具有相關性標籤
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

### 事件相關性

所有執行事件都包含相關性識別碼，將它們連結到對應的追蹤 span：

#### 執行相關性

* **`ExecutionId`**: 每個圖形執行的唯一識別碼
* **`GraphId`**: 圖形定義的穩定識別碼
* **`EventId`**: 每個事件的唯一識別碼

#### Node 相關性

* **`NodeId`**: 特定 Node 的穩定識別碼
* **`NodeName`**: Node 的人類可讀名稱
* **`Timestamp`**: 事件發生時的精確時戳
* **`HighPrecisionTimestamp`**: 用於精確排序的單調時戳

### 多代理分散式追蹤

對於多代理工作流，`MultiAgentCoordinator` 提供額外的追蹤功能：

```csharp
// 工作流級別追蹤 span
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

### 追蹤配置

通過 `MultiAgentOptions` 在多代理場景中啟用分散式追蹤：

```csharp
var options = new MultiAgentOptions
{
    EnableDistributedTracing = true,
    DistributedTracingSourceName = "SemanticKernel.Graph.MultiAgent"
};
```

### 相關性模式

#### 執行流程相關性

```csharp
// 事件和 span 共享相同的 execution.id
var execStarted = events.OfType<GraphExecutionStartedEvent>().First();
var execSpan = activities.First(a => 
    a.Tags.Any(t => t.Key == "execution.id" && 
    t.Value?.ToString() == execStarted.ExecutionId));
```

#### Node 執行相關性

```csharp
// Node 事件通過 execution.id 和 node.id 與 Node span 相關聯
var nodeStarted = events.OfType<NodeExecutionStartedEvent>().First();
var nodeSpan = activities.First(a => 
    a.Tags.Any(t => t.Key == "execution.id" && 
    t.Value?.ToString() == nodeStarted.ExecutionId) &&
    a.Tags.Any(t => t.Key == "node.id" && 
    t.Value?.ToString() == nodeStarted.Node.NodeId));
```

### 高精度計時

事件包含用於準確效能測量的高精度時戳：

```csharp
public class GraphExecutionEvent
{
    // 單調高精度時戳（Stopwatch 計時）
    public long HighPrecisionTimestamp { get; }
    
    // 高精度計時器的頻率
    public long HighPrecisionFrequency { get; }
}
```

### 追蹤最佳實務

1. **相關性 ID**：始終使用 `ExecutionId` 和 `NodeId` 來關聯跨系統的事件
2. **Span 命名**：使用一致的 span 名稱：`Graph.Execute`、`Graph.Node.Execute`、`MultiAgent.ExecuteWorkflow`
3. **標籤一致性**：在所有 span 中應用一致的標籤：`graph.id`、`execution.id`、`node.id`
4. **錯誤追蹤**：當發生例外狀況時，在 span 上設定錯誤標籤
5. **效能指標**：使用高精度時戳進行準確的延遲測量

## 另請參閱

* [串流快速開始](../streaming-quickstart.md) - 開始使用串流執行
* [串流概念](../concepts/streaming.md) - 深入瞭解串流概念
* [串流範例](../examples/streaming-execution.md) - 實踐串流範例
* [GraphExecutor 參考](./graph-executor.md) - 核心圖形執行 API
* [狀態管理參考](./state.md) - 圖形狀態和序列化
* [指標和可觀測性](../how-to/metrics-and-observability.md) - 全面的可觀測性指南
