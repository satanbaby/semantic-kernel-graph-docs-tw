# 並行執行與 Fork/Join

SemanticKernel.Graph 中的並行執行與 Fork/Join 提供了複雑的機制來並行執行多個 Graph 分支，同時維持確定性行為和適當的狀態管理。該系統支援具有可設定合併策略的高效並行處理以及可重現的執行模式。

## 你將學到什麼

* 如何在 Graph 中啟用和設定並行執行
* 理解確定性工作排程和排序
* 設定狀態合併策略和衝突解決政策
* 實作工作竊取以進行負載平衡
* 使用穩定種子確保可重現執行
* 並行 Graph 設計的最佳實踐和效能最佳化

## 概念與技術

**DeterministicWorkQueue**：執行緒安全的工作佇列，維持穩定的單調工作項目 ID 和確定性排序，以實現跨執行的可重現執行。

**Fork/Join 執行**：當多個下一個 Node 可用時自動並行執行，包括狀態複製、並行處理和確定性狀態合併。

**StateMergeConflictPolicy**：可設定的政策，用於解決並行分支合併狀態時的衝突（PreferFirst、PreferSecond、LastWriteWins、Reduce、CRDT-like）。

**StateMergeConfiguration**：按鍵和按類型的合併策略，允許對如何組合狀態的不同部分進行精細控制。

**工作竊取**：負載平衡機制，其中閒置的工人可以從忙碌的佇列竊取工作，同時維持執行確定性。

**執行種子**：穩定的隨機種子，確保跨執行的可重現行為，支援可靠的重放和偵錯。

## 前置條件

* [第一個 Graph 教學](../first-graph-5-minutes.md) 已完成
* 對 Graph 執行概念的基本了解
* 熟悉狀態管理和條件路由
* 對並行程式設計概念的理解

## 啟用並行執行

### 基本並行設定

當多個下一個 Node 可用時啟用並行執行：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Extensions;

// 建立輕量級記憶體中核心以供範例和初始引數使用
var kernel = Kernel.CreateBuilder().Build();
var args = new KernelArguments();

// 建立啟用並行執行的執行器
var executor = new GraphExecutor("ParallelGraph", "Graph with parallel execution");
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount,
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = true
});

// 使用核心函式工廠建立 Node，讓程式碼片段自己包含
var startNode = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "start", "Start"), nodeId: "start");
var branchA = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "A", "Branch A"), nodeId: "branchA");
var branchB = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "B", "Branch B"), nodeId: "branchB");
var joinNode = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "join", "Join"), nodeId: "join");

// 連接 Graph（start -> A,B 和 A,B -> join）
startNode.ConnectTo(branchA);
startNode.ConnectTo(branchB);
branchA.ConnectTo(joinNode);
branchB.ConnectTo(joinNode);

executor.AddNode(startNode).AddNode(branchA).AddNode(branchB).AddNode(joinNode);
executor.SetStartNode("start");

// 執行以驗證（選擇性）
// var result = await executor.ExecuteAsync(kernel, args);
```

### 進階並行選項

設定詳細的並行執行行為：

```csharp
// 設定進階並行選項
var concurrencyOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = 4, // 限制為 4 個並行分支
    MergeConflictPolicy = StateMergeConflictPolicy.LastWriteWins,
    FallbackToSequentialOnCycles = true
};

executor.ConfigureConcurrency(concurrencyOptions);

// 為並行執行設定資源治理
executor.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    MaxBurstSize = 2, // 允許 2 個並行執行的爆發
    BasePermitsPerSecond = 10
});
```

## 確定性工作排程

### 工作佇列管理

確定性工作佇列確保穩定的執行順序：

```csharp
using SemanticKernel.Graph.Execution;

// 使用確定性工作佇列建立執行上下文
var context = new GraphExecutionContext(kernelWrapper, graphState, cancellationToken);

// 工作佇列自動以確定性方式排序 Node
var nextNodes = context.WorkQueue.OrderDeterministically(availableNodes);

// 用穩定的 ID 將工作項目加入佇列
foreach (var node in nextNodes)
{
    var workItem = context.WorkQueue.Enqueue(node, priority: 0);
    Console.WriteLine($"Enqueued: {workItem.WorkId} for node {node.NodeId}");
}
```

### 工作竊取以進行負載平衡

啟用工作竊取來平衡並行工人之間的負載：

```csharp
// 在執行器中設定工作竊取
var executor = new GraphExecutor("WorkStealingGraph")
    .ConfigureConcurrency(new GraphConcurrencyOptions
    {
        EnableParallelExecution = true,
        MaxDegreeOfParallelism = 4
    });

// 執行器自動處理並行分支之間的工作竊取
// 工人可以從忙碌的佇列竊取工作，同時維持確定性
```

## 狀態合併和衝突解決

### 基本狀態合併

設定當並行分支完成時如何合併狀態：

```csharp
using SemanticKernel.Graph.State;

// 設定整個 Graph 的合併政策
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond
});

// 或設定每個 Edge 合併策略
var edge = new ConditionalEdge(startNode, branchA, "true");
edge.MergeConfiguration = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.LastWriteWins,
    KeyPolicies = 
    {
        ["critical_data"] = StateMergeConflictPolicy.ThrowOnConflict,
        ["accumulator"] = StateMergeConflictPolicy.Reduce
    }
};
```

### 進階合併策略

為不同的資料類型設定複雜的合併策略：

```csharp
// 建立綜合合併設定
var mergeConfig = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.PreferSecond,
    
    // 按鍵政策
    KeyPolicies = 
    {
        ["user_id"] = StateMergeConflictPolicy.PreferFirst, // 永遠不變更用戶 ID
        ["transaction_count"] = StateMergeConflictPolicy.Reduce, // 加總計數
        ["status"] = StateMergeConflictPolicy.LastWriteWins, // 最新狀態獲勝
        ["metadata"] = StateMergeConflictPolicy.CrdtLike // 智慧合併中繼資料
    },
    
    // 按類型政策
    TypePolicies = 
    {
        [typeof(int)] = StateMergeConflictPolicy.Reduce, // 加總整數
        [typeof(List<string>)] = StateMergeConflictPolicy.CrdtLike, // 聯集列表
        [typeof(Dictionary<string, object>)] = StateMergeConflictPolicy.CrdtLike // 合併字典
    }
};

// 套用到特定 Edge
var edge = new ConditionalEdge(branchA, joinNode, "true");
edge.MergeConfiguration = mergeConfig;
```

### 衝突偵測和解決

在需要時明確處理合併衝突：

```csharp
using SemanticKernel.Graph.State;

// 使用衝突偵測合併狀態
var mergeResult = StateHelpers.MergeStatesWithConflictDetection(
    baseState, 
    overlayState, 
    mergeConfig, 
    detectConflicts: true);

if (mergeResult.HasConflicts)
{
    Console.WriteLine($"偵測到 {mergeResult.Conflicts.Count} 個衝突：");
    foreach (var conflict in mergeResult.Conflicts)
    {
        Console.WriteLine($"  鍵：{conflict.Key}");
        Console.WriteLine($"    基礎：{conflict.BaseValue}");
        Console.WriteLine($"    覆蓋：{conflict.OverlayValue}");
        Console.WriteLine($"    政策：{conflict.Policy}");
        Console.WriteLine($"    已解決：{conflict.WasResolved}");
    }
}

// 使用合併的狀態
var finalState = mergeResult.MergedState;
```

## 並行執行模式

### 簡單 Fork/Join

建立基本的並行執行模式：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Extensions;

// 輕量級記憶體中核心和範例初始引數
var kernel = Kernel.CreateBuilder().Build();
var args = new KernelArguments();

// 使用核心函式工廠建立 Node，讓範例自己包含
var start = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "start", "Start"), nodeId: "start");
var parallelA = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "A", "Parallel A"), nodeId: "parallelA");
var parallelB = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "B", "Parallel B"), nodeId: "parallelB");
var joinNode = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "join", "Join"), nodeId: "join");

// AfterExecute 鉤子將分支輸出記錄到分支本地 KernelArguments 中
parallelA.SetMetadata("AfterExecute", (Action<Kernel, KernelArguments, FunctionResult>)((k, ka, r) =>
{
    ka["result_a"] = "Result from A";
    ka["timestamp_a"] = DateTimeOffset.UtcNow;
}));

parallelB.SetMetadata("AfterExecute", (Action<Kernel, KernelArguments, FunctionResult>)((k, ka, r) =>
{
    ka["result_b"] = "Result from B";
    ka["timestamp_b"] = DateTimeOffset.UtcNow;
}));

// 連接 Graph：start -> parallelA, parallelB -> join
start.ConnectTo(parallelA);
start.ConnectTo(parallelB);
parallelA.ConnectTo(joinNode);
parallelB.ConnectTo(joinNode);

// 建立執行器並啟用並行執行
var executor = new GraphExecutor("SimpleForkJoin");
executor.AddNode(start).AddNode(parallelA).AddNode(parallelB).AddNode(joinNode);
executor.SetStartNode("start");
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = 2
});

// 執行 Graph 並列印根引數的合併結果
var result = await executor.ExecuteAsync(kernel, args);
Console.WriteLine($"Result node: {result.GetValueAsString()}");
Console.WriteLine($"result_a: {args.GetValueOrDefault("result_a")} ");
Console.WriteLine($"result_b: {args.GetValueOrDefault("result_b")} ");
```

### 條件並行執行

根據狀態有條件地執行分支：

```csharp
// 建立條件並行執行
var startNode = new FunctionGraphNode("start", "Start");
var conditionNode = new ConditionalGraphNode("condition", "Check Condition");
var branchA = new FunctionGraphNode("branchA", "Branch A");
var branchB = new FunctionGraphNode("branchB", "Branch B");
var joinNode = new FunctionGraphNode("join", "Join");

// 設定條件路由
conditionNode.AddCondition("value > 100", branchA);
conditionNode.AddCondition("value <= 100", branchB);

// 兩個分支都連接到 join Node
executor.Connect("branchA", "join");
executor.Connect("branchB", "join");

// 為 join 設定合併策略
var joinEdge = new ConditionalEdge(branchA, joinNode, "true");
joinEdge.MergeConfiguration = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.LastWriteWins,
    KeyPolicies = 
    {
        ["processed_value"] = StateMergeConflictPolicy.Reduce
    }
};
```

### 複雜並行工作流

建立具有多個聯結點的複雜並行工作流：

```csharp
// 建立複雜並行工作流
var startNode = new FunctionGraphNode("start", "Start");
var parallel1 = new FunctionGraphNode("parallel1", "Parallel 1");
var parallel2 = new FunctionGraphNode("parallel2", "Parallel 2");
var parallel3 = new FunctionGraphNode("parallel3", "Parallel 3");
var join1 = new FunctionGraphNode("join1", "Join 1");
var parallel4 = new FunctionGraphNode("parallel4", "Parallel 4");
var finalJoin = new FunctionGraphNode("finalJoin", "Final Join");

// 第一級並行執行
executor.Connect("start", "parallel1");
executor.Connect("start", "parallel2");
executor.Connect("start", "parallel3");

// 第一個聯結點
executor.Connect("parallel1", "join1");
executor.Connect("parallel2", "join1");
executor.Connect("parallel3", "join1");

// 第二級並行執行
executor.Connect("join1", "parallel4");
executor.Connect("parallel3", "parallel4"); // 直接連接

// 最終聯結
executor.Connect("parallel4", "finalJoin");

// 為不同的聯結點設定不同的合併策略
var join1Edge = new ConditionalEdge(parallel1, join1, "true");
join1Edge.MergeConfiguration = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.PreferSecond,
    KeyPolicies = 
    {
        ["intermediate_result"] = StateMergeConflictPolicy.Reduce
    }
};

var finalJoinEdge = new ConditionalEdge(parallel4, finalJoin, "true");
finalJoinEdge.MergeConfiguration = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.LastWriteWins
};
```

## 可重現執行

### 執行種子

確保跨執行的可重現行為：

```csharp
// 使用穩定種子建立執行上下文
var executionSeed = 42; // 固定種子以獲得可重現執行
var context = new GraphExecutionContext(
    kernelWrapper, 
    graphState, 
    cancellationToken, 
    executionSeed);

// 相同的種子將產生相同的執行模式
// 對於偵錯、測試和確定性工作流很有用
```

### 重放和偵錯

使用確定性執行進行可靠的重放：

```csharp
// 為重放啟用詳細日誌記錄
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableExecutionTracing = true,
    EnableDeterministicLogging = true
};

var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);

// 多次執行相同種子
for (int i = 0; i < 3; i++)
{
    var replayContext = new GraphExecutionContext(
        kernelWrapper, 
        graphState.Clone(), 
        cancellationToken, 
        executionSeed: 42);
    
    var result = await executor.ExecuteAsync(replayContext);
    
    // 結果應該跨執行相同
    Console.WriteLine($"Replay {i + 1}: {result.Result}");
}
```

## 效能最佳化

### 並行度調整

為工作負載最佳化並行執行：

```csharp
// 分析和調整並行設定
var optimizedOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount * 2, // I/O 綁定工作過度訂閱
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond, // 最快合併政策
    FallbackToSequentialOnCycles = false // 如果知道 Graph 是無環的，禁用
};

executor.ConfigureConcurrency(optimizedOptions);

// 監視效能指標
var metrics = await executor.GetPerformanceMetricsAsync();
Console.WriteLine($"Parallel branches executed: {metrics.ParallelBranchesExecuted}");
Console.WriteLine($"Average merge time: {metrics.AverageStateMergeTime}");
Console.WriteLine($"Total execution time: {metrics.TotalExecutionTime}");
```

### 資源感知並行執行

在資源限制的情況下平衡並行度：

```csharp
// 設定資源感知並行執行
executor.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    MaxBurstSize = 4, // 允許並行執行的爆發
    BasePermitsPerSecond = 20, // 速率限制整體執行
    EnableCostTracking = true
});

// 設定 Node 特定資源成本
parallelA.SetMetadata("ResourceCost", 2); // 更高成本
parallelB.SetMetadata("ResourceCost", 1); // 更低成本

// 資源治理器將根據成本和限制進行節流
```

## 最佳實踐

### 並行 Graph 設計

* **保持分支獨立**：設計並行分支以最小化共享狀態和依賴關係
* **均衡工作負載**：確保並行分支的執行時間相似以獲得最佳效能
* **清晰聯結點**：定義並行執行聚合的明確聯結 Node
* **狀態隔離**：使用狀態複製來防止並行分支之間的寫入衝突

### 合併策略選擇

* **PreferSecond**：在大多數情況下使用，其中最新資料應該獲勝
* **PreferFirst**：用於不應變更的不可變或參考資料
* **LastWriteWins**：當時間順序很重要時使用
* **Reduce**：用於累積器、計數器和聚合
* **CRDT-like**：用於可以智慧合併的複雜資料結構
* **ThrowOnConflict**：用於關鍵資料，其中衝突表示設計問題

### 效能考量

* **監視資源使用**：在並行執行期間追蹤 CPU、記憶體和 I/O 使用
* **調整並行度**：根據系統功能調整 MaxDegreeOfParallelism
* **分析合併操作**：確保狀態合併不會成為瓶頸
* **使用工作竊取**：為不同工作負載啟用工作竊取以實現更好的負載平衡

### 偵錯和測試

* **使用穩定種子**：始終為可重現偵錯使用固定執行種子
* **啟用追蹤**：使用執行追蹤來了解並行執行流程
* **測試邊界情況**：使用各種合併政策和衝突情景進行測試
* **監視指標**：追蹤並行執行指標進行效能分析

## 疑難排解

### 常見問題

**並行執行不工作**：檢查 `EnableParallelExecution` 是否為真且存在多個下一個 Node。

**合併期間狀態衝突**：驗證合併政策設定並確保適當的衝突解決策略。

**非確定性行為**：使用穩定執行種子並確保所有隨機操作使用播種隨機數產生器。

**效能下降**：監視資源使用並根據系統功能調整 `MaxDegreeOfParallelism`。

**記憶體問題**：確保並行分支中的適當狀態複製和清理。

### 偵錯並行執行

啟用詳細日誌記錄進行疑難排解：

```csharp
// 設定詳細並行執行日誌記錄
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableExecutionTracing = true,
    EnableParallelExecutionLogging = true,
    EnableStateMergeLogging = true
};

var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);

// 監視並行執行事件
using var eventStream = executor.CreateStreamingExecutor().CreateEventStream();

eventStream.SubscribeToEvents<GraphExecutionEvent>(event =>
{
    if (event.EventType == GraphExecutionEventType.ParallelBranchStarted)
    {
        var parallelEvent = event as ParallelBranchStartedEvent;
        Console.WriteLine($"Parallel branch started: {parallelEvent.BranchId}");
    }
    
    if (event.EventType == GraphExecutionEventType.StateMergeCompleted)
    {
        var mergeEvent = event as StateMergeCompletedEvent;
        Console.WriteLine($"State merge completed: {mergeEvent.Conflicts.Count} conflicts resolved");
    }
});
```

## 另見

* [Graph 執行](execution.md) - 了解執行生命週期和並行處理
* [狀態管理](state-quickstart.md) - 在並行執行情境中管理狀態
* [錯誤處理和復原](error-handling-and-resilience.md) - 處理並行分支中的失敗
* [資源治理](resource-governance-and-concurrency.md) - 在並行執行期間管理資源
* [串流執行](streaming-quickstart.md) - 並行執行的即時監視
