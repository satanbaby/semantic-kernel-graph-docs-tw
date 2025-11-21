# 執行模型

本指南說明 `GraphExecutor` 如何協調圖形執行，包括完整的生命週期、導航邏輯、執行限制和內建的無限迴圈防護機制。

## 概述

`GraphExecutor` 是中央協調器，用來管理圖形的完整執行流程。它處理 Node 生命週期管理、Node 之間的導航、並行執行、錯誤恢復，並提供全面的防護措施，以確保可靠和可預測的執行。

## 執行生命週期

### 1. 執行初始化

在執行開始之前，執行器會執行多個設定步驟：

```csharp
// 使用不可變選項快照建立執行內容
var graphState = arguments.GetOrCreateGraphState();
var context = new GraphExecutionContext(kernel, graphState, cancellationToken, arguments.GetExecutionSeed());

// 驗證圖形完整性（可選，由各執行選項控制）
if (context.ExecutionOptions.ValidateGraphIntegrity)
{
    var validationResult = ValidateGraphIntegrity();
    if (!validationResult.IsValid)
    {
        throw new InvalidOperationException($"圖形驗證失敗: {validationResult.CreateSummary()}");
    }
}

// 啟用計劃編譯和快取（可選）
if (context.ExecutionOptions.EnablePlanCompilation)
{
    _ = GraphPlanCompiler.ComputeSignature(this);
    _ = GraphExecutionPlanCache.GetOrAdd(this);
}
```

### 2. Node 執行生命週期

每個 Node 遵循一致的生命週期模式：

#### 執行前 (`OnBeforeExecuteAsync`)
* **中介軟體管道**：自訂中介軟體在 Node 之前執行
* **Node Hook**：Node 的 `OnBeforeExecuteAsync` 方法執行
* **資源取得**：根據 Node 成本和優先級取得資源許可
* **效能追蹤**：執行計時開始
* **偵錯 Hook**：斷點和逐步模式檢查

```csharp
// 執行生命週期：執行前（中介軟體，然後是 Node Hook）
// Await 呼叫使用 ConfigureAwait(false)，以避免在消費應用程式中擷取
// 同步化內容。
await InvokeBeforeMiddlewaresAsync(context, execNode).ConfigureAwait(false);
await execNode.OnBeforeExecuteAsync(context.Kernel, context.GraphState.KernelArguments, effectiveCt).ConfigureAwait(false);

// 資源治理：取得許可
using var lease = _resourceGovernor != null
    ? await _resourceGovernor.AcquireAsync(nodeCost, priority, context.CancellationToken)
    : default;

// 開始效能追蹤
var nodeTracker = _performanceMetrics?.StartNodeTracking(currentNode.NodeId, currentNode.Name, context.ExecutionId);
```

#### 主要執行 (`ExecuteAsync`)
* **函數執行**：Node 的核心邏輯執行
* **結果處理**：輸出被擷取並儲存
* **狀態更新**：根據結果修改圖形狀態

#### 執行後 (`OnAfterExecuteAsync`)
* **Node Hook**：Node 的 `OnAfterExecuteAsync` 方法執行
* **中介軟體管道**：自訂中介軟體在 Node 之後執行
* **效能完成**：執行計時最終確定
* **成功註冊**：為自我修復記錄 Node 成功

```csharp
// 執行 Node
// 使用 ConfigureAwait(false)，以免範例程式庫代碼擷取內容。
var result = await execNode.ExecuteAsync(context.Kernel, context.GraphState.KernelArguments, effectiveCt).ConfigureAwait(false);

// 執行生命週期：執行後（Node Hook，然後是中介軟體）
await execNode.OnAfterExecuteAsync(context.Kernel, context.GraphState.KernelArguments, result, effectiveCt).ConfigureAwait(false);
await InvokeAfterMiddlewaresAsync(context, execNode, result).ConfigureAwait(false);

// 記錄成功完成
context.RecordNodeCompleted(execNode, result);

// 自我修復：註冊成功
RegisterNodeSuccess(execNode.NodeId);
```

#### 錯誤處理 (`OnExecutionFailedAsync`)
* **失敗記錄**：記錄並追蹤 Node 失敗
* **錯誤恢復**：恢復引擎嘗試恢復執行
* **原則應用**：錯誤處理原則決定重試/跳過行為
* **自我修復**：失敗的 Node 可能被隔離

```csharp
// 執行生命週期：失敗
// 確保在等待的呼叫上使用 ConfigureAwait(false)。
await currentNode.OnExecutionFailedAsync(context.Kernel, context.GraphState.KernelArguments, ex, context.CancellationToken).ConfigureAwait(false);

// 記錄 Node 失敗
context.RecordNodeFailed(currentNode, ex);

// 自我修復：註冊失敗並可能隔離
RegisterNodeFailure(currentNode.NodeId);

// 應用錯誤處理原則
if (_metadata.TryGetValue(nameof(IErrorHandlingPolicy), out var epObj) && epObj is IErrorHandlingPolicy errorPolicy)
{
    if (errorPolicy.ShouldRetry(currentNode, ex, context, out var delay))
    {
        // 重試邏輯
    }
    if (errorPolicy.ShouldSkip(currentNode, ex, context))
    {
        // 跳過邏輯
    }
}
```

## 導航邏輯

### 下一個 Node 選擇

在 Node 執行後，執行器決定哪些 Node 要接著執行：

```csharp
// 尋找下一個要執行的 Node
var nextNodes = GetCombinedNextNodes(execNode, result, context.GraphState).ToList();

if (_routingEngine != null && nextNodes.Count > 0)
{
    // 使用動態路由引擎進行智能 Node 選擇
    // 在程式庫代碼範例中等待時使用 ConfigureAwait(false)。
    currentNode = await _routingEngine.SelectNextNodeAsync(nextNodes, execNode,
        context.GraphState, result, context.CancellationToken).ConfigureAwait(false);
}
else
{
    if (nextNodes.Count <= 1 || !_concurrencyOptions.EnableParallelExecution)
    {
        // 序列執行，具有確定性順序
        var ordered = context.WorkQueue.OrderDeterministically(nextNodes).ToList();
        currentNode = ordered.FirstOrDefault();
    }
    else
    {
        // 並行分支/合併執行
        // ... 並行執行邏輯
    }
}
```

### 條件 Edge 評估

評估 Edge 以決定有效的轉換：

```csharp
private IEnumerable<IGraphNode> GetCombinedNextNodes(IGraphNode node, FunctionResult? result, GraphState graphState)
{
    var nextNodes = new List<IGraphNode>();
    
    // 從 Node 自身的導航邏輯取得 Node
    var nodeNextNodes = node.GetNextNodes(result, graphState);
    nextNodes.AddRange(nodeNextNodes);
    
    // 從條件 Edge 取得 Node
    var edgeNextNodes = GetOutgoingEdges(node)
        .Where(edge => edge.EvaluateCondition(graphState))
        .Select(edge => edge.TargetNode);
    nextNodes.AddRange(edgeNextNodes);
    
    return nextNodes.DistinctBy(n => n.NodeId);
}
```

## 執行限制和防護措施

### 1. 最大迭代

執行器強制執行可配置的執行步驟總數限制：

```csharp
// 尊重各執行選項的最大步驟，在需要時退回到結構界限
var maxIterations = Math.Max(1, context.ExecutionOptions.MaxExecutionSteps);
var iterations = 0;

while (currentNode != null && iterations < maxIterations)
{
    // ... 執行邏輯
    iterations++;
}

if (iterations >= maxIterations)
{
    throw new InvalidOperationException($"圖形執行超過最大步驟 ({maxIterations})。檢測到可能的無限迴圈。");
}
```

### 2. 執行逾時

整體執行逾時防止運行失控的圖形：

```csharp
// 在設定時應用整體逾時
if (context.ExecutionOptions.ExecutionTimeout > TimeSpan.Zero)
{
    var elapsed = DateTimeOffset.UtcNow - context.StartTime;
    if (elapsed > context.ExecutionOptions.ExecutionTimeout)
    {
        throw new OperationCanceledException($"圖形執行超過設定的逾時 {context.ExecutionOptions.ExecutionTimeout}");
    }
}
```

### 3. Node 層級逾時

個別 Node 可以有可配置的逾時：

```csharp
private CancellationTokenSource? CreateNodeTimeoutCts(GraphExecutionContext context, IGraphNode node)
{
    if (_metadata.TryGetValue(nameof(ITimeoutPolicy), out var tpObj) && tpObj is ITimeoutPolicy timeoutPolicy)
    {
        var timeout = timeoutPolicy.GetNodeTimeout(node, context.GraphState);
        if (timeout.HasValue && timeout.Value > TimeSpan.Zero)
        {
            var cts = CancellationTokenSource.CreateLinkedTokenSource(context.CancellationToken);
            cts.CancelAfter(timeout.Value);
            return cts;
        }
    }
    return null;
}
```

### 4. 斷路器

自我修復機制自動隔離失敗的 Node：

```csharp
// 自我修復：跳過隔離的 Node
if (IsNodeQuarantined(currentNode.NodeId))
{
    var skipCandidates = GetCombinedNextNodes(currentNode, lastResult, context.GraphState).ToList();
    currentNode = await SelectNextNodeAsync(currentNode,
        context.WorkQueue.OrderDeterministically(skipCandidates).ToList(),
        context, lastResult).ConfigureAwait(false);
    continue;
}
```

### 5. 執行深度追蹤

執行器追蹤執行深度以偵測過度巢狀：

```csharp
// 記錄執行路徑用於計量
if (_performanceMetrics != null && context.ExecutionPath.Count > 0)
{
    var executionPath = context.ExecutionPath.Select(n => n.NodeId).ToList();
    var totalDuration = context.Duration ?? TimeSpan.Zero;
    var success = lastResult != null;

    _performanceMetrics.RecordExecutionPath(context.ExecutionId, executionPath, totalDuration, success);
}
```

## 並行執行

### 分支/合併模式

執行器支援多個分支的並行執行：

```csharp
// 並行分支/合併：並行執行所有下一個 Node，合併狀態，然後繼續
var branchNodes = context.WorkQueue.OrderDeterministically(nextNodes).ToList();

// 為每個分支複製基本狀態，以避免寫入衝突
var branchStates = branchNodes
    .Select(_ => StateHelpers.CloneState(context.GraphState))
    .ToList();

var semaphore = new SemaphoreSlim(Math.Max(1, _concurrencyOptions.MaxDegreeOfParallelism));

var branchTasks = branchNodes.Select(async (branchNode, index) =>
{
    await semaphore.WaitAsync(context.CancellationToken);
    try
    {
        // 使用隔離狀態執行分支 Node
        var branchArgs = branchStates[index].KernelArguments;
        var branchResult = await branchNode.ExecuteAsync(context.Kernel, branchArgs, context.CancellationToken);
        
        return (Node: branchNode, State: branchStates[index], Result: branchResult, Error: (Exception?)null);
    }
    finally
    {
        semaphore.Release();
    }
});

var branchResults = await Task.WhenAll(branchTasks);

// 使用 Edge 特定配置合併狀態
var merged = StateHelpers.CloneState(originalGraphState);
foreach (var br in branchResults)
{
    if (br.Error == null && br.Result != null)
    {
        var edgeConfiguration = GetEdgeMergeConfiguration(execNode, br.Node, context.GraphState);
        merged = StateHelpers.MergeStates(merged, br.State, edgeConfiguration);
    }
}
```

## 錯誤恢復和復原力

### 恢復引擎整合

執行器與恢復引擎整合以進行自動錯誤處理：

```csharp
// 如果有恢復引擎，嘗試錯誤恢復
if (_recoveryEngine != null)
{
    try
    {
        // 建立錯誤內容
        var errorContext = new ErrorHandlingContext
        {
            Exception = ex,
            ErrorType = CategorizeError(ex),
            Severity = DetermineErrorSeverity(ex),
            FailedNode = currentNode,
            AttemptNumber = 1,
            IsTransient = IsTransientError(ex),
            AdditionalContext = new Dictionary<string, object>
            {
                ["CurrentNodeId"] = currentNode.NodeId,
                ["CurrentNodeName"] = currentNode.Name,
                ["IterationCount"] = iterations,
                ["ExecutionId"] = context.GraphState.KernelArguments.GetExecutionId(),
                ["ErrorTimestamp"] = DateTimeOffset.UtcNow
            }
        };

        // 應用恢復原則
        var recoveryResult = await _recoveryEngine.ApplyRecoveryPolicyAsync(errorContext, context.GraphState);
        
        if (recoveryResult.Success)
        {
            // 根據類型處理恢復（重試、回復、繼續）
            switch (recoveryResult.RecoveryType)
            {
                case RecoveryType.Retry:
                    iterations--; // 不計為迭代的重試
                    continue;
                case RecoveryType.Rollback:
                    if (recoveryResult.RestoredState != null)
                    {
                        context.GraphState = recoveryResult.RestoredState;
                    }
                    break;
            }
        }
    }
    catch (Exception recoveryEx)
    {
        // 恢復失敗，繼續原始錯誤
        context.GraphState.KernelArguments["RecoveryError"] = recoveryEx.Message;
        context.GraphState.KernelArguments["RecoveryFailed"] = true;
    }
}
```

### 錯誤原則框架

可配置的原則決定如何處理不同類型的錯誤：

```csharp
// 可插入的錯誤原則決定（重試/跳過）
if (_metadata.TryGetValue(nameof(IErrorHandlingPolicy), out var epObj) && epObj is IErrorHandlingPolicy errorPolicy)
{
    if (errorPolicy.ShouldRetry(currentNode, ex, context, out var delay))
    {
        if (delay.HasValue && delay.Value > TimeSpan.Zero)
        {
            await Task.Delay(delay.Value, context.CancellationToken).ConfigureAwait(false);
        }
        iterations--; // 重試不計為迭代
        continue; // 重試目前的 Node
    }
    if (errorPolicy.ShouldSkip(currentNode, ex, context))
    {
        // 選擇下一個 Node，不執行目前的
        var nextCandidates = GetCombinedNextNodes(currentNode, lastResult, context.GraphState).ToList();
        currentNode = await SelectNextNodeAsync(currentNode, nextCandidates, context, lastResult);
        continue;
    }
}
```

## 中介軟體管道

### 執行中介軟體

自訂中介軟體可以在各個點攔截執行：

```csharp
private async Task InvokeBeforeMiddlewaresAsync(GraphExecutionContext context, IGraphNode node)
{
    var ordered = GetOrderedMiddlewares();
    foreach (var m in ordered)
    {
        await m.OnBeforeNodeAsync(context, node, context.CancellationToken).ConfigureAwait(false);
    }
}

private async Task InvokeAfterMiddlewaresAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result)
{
    var ordered = GetOrderedMiddlewares();
    for (int i = ordered.Count - 1; i >= 0; i--)
    {
        await ordered[i].OnAfterNodeAsync(context, node, result, context.CancellationToken).ConfigureAwait(false);
    }
}

private async Task InvokeFailureMiddlewaresAsync(GraphExecutionContext context, IGraphNode node, Exception exception)
{
    var ordered = GetOrderedMiddlewares();
    for (int i = ordered.Count - 1; i >= 0; i--)
    {
        await ordered[i].OnNodeFailedAsync(context, node, exception, context.CancellationToken).ConfigureAwait(false);
    }
}
```

## 資源治理

### 資源取得

執行器根據 Node 成本和優先級管理資源分配：

```csharp
// 決定成本和優先級（可透過 DI 插入）
var priority = context.GraphState.KernelArguments.GetExecutionPriority() ?? _resourceOptions.DefaultPriority;
var nodeCost = 1.0;

if (_metadata.TryGetValue(nameof(ICostPolicy), out var cpObj) && cpObj is ICostPolicy costPolicy)
{
    nodeCost = costPolicy.GetNodeCostWeight(currentNode, context.GraphState) ?? nodeCost;
    var p = costPolicy.GetNodePriority(currentNode, context.GraphState);
    if (p.HasValue) priority = p.Value;
}

// 取得資源許可
using var lease = _resourceGovernor != null
    ? await _resourceGovernor.AcquireAsync(nodeCost, priority, context.CancellationToken).ConfigureAwait(false)
    : default;
```

## 最佳實踐

### 執行配置

* **設定合理限制**：根據你的工作流程複雜性設定 `MaxExecutionSteps` 和 `ExecutionTimeout`
* **使用中介軟體**：實作自訂中介軟體用於跨領域關切，如記錄、監控和安全性
* **配置資源限制**：設定適當的資源治理以防止資源耗盡
* **啟用驗證**：在開發中使用 `ValidateGraphIntegrity` 以及早發現結構問題

### 錯誤處理

* **實作恢復原則**：為你的領域建立自訂錯誤處理原則
* **使用斷路器**：利用自我修復自動處理失敗的 Node
* **監控執行路徑**：追蹤執行路徑以識別效能瓶頸
* **設定 Node 逾時**：為長時間執行的操作設定適當的逾時

### 效能

* **啟用計劃編譯**：對複雜圖形使用 `EnablePlanCompilation` 以改善效能
* **配置並行執行**：為獨立分支使用並行執行
* **監控資源使用**：追蹤 CPU 和記憶體使用情況以優化資源分配
* **使用確定性順序**：使用 `DeterministicWorkQueue` 確保可重現的執行

## 另請參閱

* [Graph 概念](graph-concepts.md) - 基本的圖形概念和元件
* [Node 類型](nodes.md) - 可用的 Node 實作及其生命週期
* [狀態管理](state.md) - 如何管理和傳播執行狀態
* [錯誤處理](error-handling.md) - 進階錯誤恢復和復原力模式
* [效能調整](performance-tuning.md) - 優化圖形執行效能
* [範例](../examples/) - 執行模式的實踐範例
