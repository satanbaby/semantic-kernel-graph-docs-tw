# 平行化和 Fork/Join

SemanticKernel.Graph 中的平行化和 fork/join 提供了精細的機制來同時執行多個圖形分支，同時保持確定性行為和適當的狀態管理。此系統透過可配置的合併策略和可重現的執行模式實現高效的平行處理。

## 您將學習什麼

* 如何在圖形中啟用和配置平行執行
* 瞭解確定性工作調度和排序
* 配置狀態合併策略和衝突解決原則
* 實現工作竊取以進行負載平衡
* 透過穩定的種子確保可重現的執行
* 平行圖形設計和性能優化的最佳實踐

## 概念和技術

**DeterministicWorkQueue**：線程安全的工作佇列，維護穩定的單調工作項目 ID 和確定性排序，以便在多次執行中重現執行。

**Fork/Join 執行**：當有多個下一個節點可用時自動進行平行執行，具有狀態克隆、並發處理和確定性狀態合併。

**StateMergeConflictPolicy**：可配置的原則用於在合併平行分支的狀態時解決衝突（PreferFirst、PreferSecond、LastWriteWins、Reduce、CRDT 類似）。

**StateMergeConfiguration**：按鍵和按類型的合併策略，允許對狀態的不同部分進行細粒度控制。

**工作竊取**：負載平衡機制，其中空閒工作者可以從繁忙的佇列竊取工作，同時保持執行確定性。

**執行種子**：穩定的隨機種子，確保跨執行的可重現行為，啟用可靠的重放和除錯。

## 先決條件

* [首個圖形教程](../first-graph-5-minutes.md)已完成
* 對圖形執行概念有基本理解
* 熟悉狀態管理和條件路由
* 瞭解並發編程概念

## 啟用平行執行

### 基本平行配置

當有多個下一個節點可用時啟用平行執行：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Extensions;

// 為示例和初始參數建立輕量級記憶體內核
var kernel = Kernel.CreateBuilder().Build();
var args = new KernelArguments();

// 建立啟用平行執行的執行器
var executor = new GraphExecutor("ParallelGraph", "Graph with parallel execution");
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount,
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = true
});

// 使用核心函數工廠建立節點，使代碼片段自成一體
var startNode = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "start", "Start"), nodeId: "start");
var branchA = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "A", "Branch A"), nodeId: "branchA");
var branchB = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "B", "Branch B"), nodeId: "branchB");
var joinNode = new FunctionGraphNode(KernelFunctionFactory.CreateFromMethod(() => "join", "Join"), nodeId: "join");

// 連接圖形（start -> A,B 和 A,B -> join）
startNode.ConnectTo(branchA);
startNode.ConnectTo(branchB);
branchA.ConnectTo(joinNode);
branchB.ConnectTo(joinNode);

executor.AddNode(startNode).AddNode(branchA).AddNode(branchB).AddNode(joinNode);
executor.SetStartNode("start");

// 執行以驗證（可選）
// var result = await executor.ExecuteAsync(kernel, args);
```

### 進階並發選項

配置詳細的平行執行行為：

```csharp
// 配置進階並發選項
var concurrencyOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = 4, // 限制為 4 個並發分支
    MergeConflictPolicy = StateMergeConflictPolicy.LastWriteWins,
    FallbackToSequentialOnCycles = true
};

executor.ConfigureConcurrency(concurrencyOptions);

// 為平行執行配置資源治理
executor.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    MaxBurstSize = 2, // 允許 2 個平行執行的突發
    BasePermitsPerSecond = 10
});
```

## 確定性工作調度

### 工作佇列管理

確定性工作佇列確保穩定的執行排序：

```csharp
using SemanticKernel.Graph.Execution;

// 使用確定性工作佇列建立執行上下文
var context = new GraphExecutionContext(kernelWrapper, graphState, cancellationToken);

// 工作佇列自動以確定性方式排序節點
var nextNodes = context.WorkQueue.OrderDeterministically(availableNodes);

// 使用穩定的 ID 將工作項目加入佇列
foreach (var node in nextNodes)
{
    var workItem = context.WorkQueue.Enqueue(node, priority: 0);
    Console.WriteLine($"Enqueued: {workItem.WorkId} for node {node.NodeId}");
}
```

### 工作竊取以進行負載平衡

啟用工作竊取以平衡平行工作者之間的負載：

```csharp
// 在執行器中配置工作竊取
var executor = new GraphExecutor("WorkStealingGraph")
    .ConfigureConcurrency(new GraphConcurrencyOptions
    {
        EnableParallelExecution = true,
        MaxDegreeOfParallelism = 4
    });

// 執行器自動處理平行分支之間的工作竊取
// 工作者可以從繁忙的佇列竊取工作，同時保持確定性
```

## 狀態合併和衝突解決

### 基本狀態合併

配置平行分支完成時狀態的合併方式：

```csharp
using SemanticKernel.Graph.State;

// 為整個圖形配置合併原則
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond
});

// 或按邊配置合併策略
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

為不同的數據類型配置精細的合併策略：

```csharp
// 建立綜合合併配置
var mergeConfig = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.PreferSecond,
    
    // 按鍵的原則
    KeyPolicies = 
    {
        ["user_id"] = StateMergeConflictPolicy.PreferFirst, // 永遠不要改變使用者 ID
        ["transaction_count"] = StateMergeConflictPolicy.Reduce, // 累加計數
        ["status"] = StateMergeConflictPolicy.LastWriteWins, // 最新狀態獲勝
        ["metadata"] = StateMergeConflictPolicy.CrdtLike // 智能合併元數據
    },
    
    // 按類型的原則
    TypePolicies = 
    {
        [typeof(int)] = StateMergeConflictPolicy.Reduce, // 求和整數
        [typeof(List<string>)] = StateMergeConflictPolicy.CrdtLike, // 並集列表
        [typeof(Dictionary<string, object>)] = StateMergeConflictPolicy.CrdtLike // 合併字典
    }
};

// 應用於特定邊
var edge = new ConditionalEdge(branchA, joinNode, "true");
edge.MergeConfiguration = mergeConfig;
```

### 衝突檢測和解決

在需要時明確處理合併衝突：

```csharp
using SemanticKernel.Graph.State;

// 合併狀態並進行衝突檢測
var mergeResult = StateHelpers.MergeStatesWithConflictDetection(
    baseState, 
    overlayState, 
    mergeConfig, 
    detectConflicts: true);

if (mergeResult.HasConflicts)
{
    Console.WriteLine($"Detected {mergeResult.Conflicts.Count} conflicts:");
    foreach (var conflict in mergeResult.Conflicts)
    {
        Console.WriteLine($"  Key: {conflict.Key}");
        Console.WriteLine($"    Base: {conflict.BaseValue}");
        Console.WriteLine($"    Overlay: {conflict.OverlayValue}");
        Console.WriteLine($"    Policy: {conflict.Policy}");
        Console.WriteLine($"    Resolved: {conflict.WasResolved}");
    }
}

// 使用已合併的狀態
var finalState = mergeResult.MergedState;
```

## 平行執行模式

### 簡單 Fork/Join

建立基本的平行執行模式：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.Extensions;

// 為示例建立輕量級記憶體內核和初始參數
var kernel = Kernel.CreateBuilder().Build();
var args = new KernelArguments();

// 使用核心函數工廠建立節點，使示例自成一體
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

// 連接圖形：start -> parallelA、parallelB -> join
start.ConnectTo(parallelA);
start.ConnectTo(parallelB);
parallelA.ConnectTo(joinNode);
parallelB.ConnectTo(joinNode);

// 建立執行器並啟用平行執行
var executor = new GraphExecutor("SimpleForkJoin");
executor.AddNode(start).AddNode(parallelA).AddNode(parallelB).AddNode(joinNode);
executor.SetStartNode("start");
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = 2
});

// 執行圖形並列印來自根參數的已合併結果
var result = await executor.ExecuteAsync(kernel, args);
Console.WriteLine($"Result node: {result.GetValueAsString()}");
Console.WriteLine($"result_a: {args.GetValueOrDefault("result_a")} ");
Console.WriteLine($"result_b: {args.GetValueOrDefault("result_b")} ");
```

### 條件平行執行

根據狀態有條件地執行分支：

```csharp
// 建立條件平行執行
var startNode = new FunctionGraphNode("start", "Start");
var conditionNode = new ConditionalGraphNode("condition", "Check Condition");
var branchA = new FunctionGraphNode("branchA", "Branch A");
var branchB = new FunctionGraphNode("branchB", "Branch B");
var joinNode = new FunctionGraphNode("join", "Join");

// 配置條件路由
conditionNode.AddCondition("value > 100", branchA);
conditionNode.AddCondition("value <= 100", branchB);

// 兩個分支都連接到連接節點
executor.Connect("branchA", "join");
executor.Connect("branchB", "join");

// 為連接配置合併策略
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

### 複雜的平行工作流程

使用多個連接點建立精細的平行工作流程：

```csharp
// 建立複雜的平行工作流程
var startNode = new FunctionGraphNode("start", "Start");
var parallel1 = new FunctionGraphNode("parallel1", "Parallel 1");
var parallel2 = new FunctionGraphNode("parallel2", "Parallel 2");
var parallel3 = new FunctionGraphNode("parallel3", "Parallel 3");
var join1 = new FunctionGraphNode("join1", "Join 1");
var parallel4 = new FunctionGraphNode("parallel4", "Parallel 4");
var finalJoin = new FunctionGraphNode("finalJoin", "Final Join");

// 第一級平行執行
executor.Connect("start", "parallel1");
executor.Connect("start", "parallel2");
executor.Connect("start", "parallel3");

// 第一個連接點
executor.Connect("parallel1", "join1");
executor.Connect("parallel2", "join1");
executor.Connect("parallel3", "join1");

// 第二級平行執行
executor.Connect("join1", "parallel4");
executor.Connect("parallel3", "parallel4"); // 直接連接

// 最終連接
executor.Connect("parallel4", "finalJoin");

// 為不同的連接點配置不同的合併策略
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

## 可重現的執行

### 執行種子

確保跨執行的可重現行為：

```csharp
// 使用穩定種子建立執行上下文
var executionSeed = 42; // 固定種子用於可重現執行
var context = new GraphExecutionContext(
    kernelWrapper, 
    graphState, 
    cancellationToken, 
    executionSeed);

// 相同的種子將產生相同的執行模式
// 用於除錯、測試和確定性工作流程
```

### 重放和除錯

使用確定性執行進行可靠的重放：

```csharp
// 啟用詳細日誌記錄以進行重放
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableExecutionTracing = true,
    EnableDeterministicLogging = true
};

var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);

// 使用相同的種子執行多次
for (int i = 0; i < 3; i++)
{
    var replayContext = new GraphExecutionContext(
        kernelWrapper, 
        graphState.Clone(), 
        cancellationToken, 
        executionSeed: 42);
    
    var result = await executor.ExecuteAsync(replayContext);
    
    // 結果應該在多次執行中相同
    Console.WriteLine($"Replay {i + 1}: {result.Result}");
}
```

## 性能優化

### 平行化調整

為您的工作負載優化平行執行：

```csharp
// 分析並調整平行化設置
var optimizedOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount * 2, // 過度訂閱以處理 I/O 密集型工作
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond, // 最快的合併原則
    FallbackToSequentialOnCycles = false // 如果您知道圖形是無環的，請禁用此選項
};

executor.ConfigureConcurrency(optimizedOptions);

// 監控性能指標
var metrics = await executor.GetPerformanceMetricsAsync();
Console.WriteLine($"Parallel branches executed: {metrics.ParallelBranchesExecuted}");
Console.WriteLine($"Average merge time: {metrics.AverageStateMergeTime}");
Console.WriteLine($"Total execution time: {metrics.TotalExecutionTime}");
```

### 資源感知平行執行

平衡平行化與資源約束：

```csharp
// 配置資源感知平行執行
executor.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    MaxBurstSize = 4, // 允許平行執行的突發
    BasePermitsPerSecond = 20, // 限制整體執行速率
    EnableCostTracking = true
});

// 設置節點特定的資源成本
parallelA.SetMetadata("ResourceCost", 2); // 較高成本
parallelB.SetMetadata("ResourceCost", 1); // 較低成本

// 資源監管器將根據成本和限制進行限制
```

## 最佳實踐

### 平行圖形設計

* **保持分支獨立**：設計平行分支以最小化共享狀態和依賴性
* **均衡的工作負載**：確保平行分支具有相似的執行時間以實現最佳性能
* **明確的連接點**：定義平行執行收斂的明確連接節點
* **狀態隔離**：使用狀態克隆來防止平行分支之間的寫入衝突

### 合併策略選擇

* **PreferSecond**：用於最新數據應該獲勝的大多數情況
* **PreferFirst**：用於不應改變的不可變或參考數據
* **LastWriteWins**：當時間順序很重要時使用
* **Reduce**：用於累加器、計數器和聚合
* **CRDT 類似**：用於可以智能合併的複雜數據結構
* **ThrowOnConflict**：用於衝突表示設計問題的關鍵數據

### 性能考慮

* **監控資源使用**：在平行執行期間追蹤 CPU、記憶體和 I/O 使用情況
* **調整平行化**：根據您的系統功能調整 MaxDegreeOfParallelism
* **設定文件合併操作**：確保狀態合併不會成為瓶頸
* **使用工作竊取**：在異構工作負載中啟用工作竊取以實現更好的負載平衡

### 除錯和測試

* **使用穩定種子**：始終對可重現除錯使用固定執行種子
* **啟用追蹤**：使用執行追蹤來瞭解平行執行流程
* **測試邊界情況**：使用各種合併原則和衝突場景進行測試
* **監控指標**：追蹤平行執行指標以進行性能分析

## 故障排除

### 常見問題

**平行執行不工作**：檢查 `EnableParallelExecution` 是否為 true，以及是否存在多個下一個節點。

**合併期間的狀態衝突**：驗證合併原則配置並確保適當的衝突解決策略。

**非確定性行為**：使用穩定執行種子並確保所有隨機操作都使用已播種的隨機數生成器。

**性能降低**：監控資源使用情況並根據系統功能調整 `MaxDegreeOfParallelism`。

**記憶體問題**：確保平行分支中的適當狀態克隆和清理。

### 除錯平行執行

啟用詳細日誌記錄以進行故障排除：

```csharp
// 配置詳細的平行執行日誌記錄
var graphOptions = new GraphOptions
{
    LogLevel = LogLevel.Debug,
    EnableExecutionTracing = true,
    EnableParallelExecutionLogging = true,
    EnableStateMergeLogging = true
};

var graphLogger = new SemanticKernelGraphLogger(logger, graphOptions);

// 監控平行執行事件
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

## 另請參閱

* [圖形執行](execution.md) - 瞭解執行生命週期和平行處理
* [狀態管理](state-quickstart.md) - 在平行執行場景中管理狀態
* [錯誤處理和恢復力](error-handling-and-resilience.md) - 處理平行分支中的失敗
* [資源治理](resource-governance-and-concurrency.md) - 在平行執行期間管理資源
* [串流執行](streaming-quickstart.md) - 實時監控平行執行
