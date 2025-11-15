# 執行模型

本指南說明 `GraphExecutor` 如何協調圖形執行，包括完整的生命週期、導航邏輯、執行限制和內建的無限迴圈防護。

## 概述

`GraphExecutor` 是中央協調器，管理圖形的完整執行流程。它處理節點生命週期管理、節點間的導航、平行執行、錯誤恢復，並提供全面的防護措施以確保可靠且可預測的執行。

## 執行生命週期

### 1. 執行初始化

執行開始前，執行器執行數個設定步驟：

```csharp
// 建立執行內容，含有不可變選項快照
var graphState = arguments.GetOrCreateGraphState();
var context = new GraphExecutionContext(kernel, graphState, cancellationToken, arguments.GetExecutionSeed());

// 驗證圖形完整性（可選，由各執行選項控制）
if (context.ExecutionOptions.ValidateGraphIntegrity)
{
    var validationResult = ValidateGraphIntegrity();
    if (!validationResult.IsValid)
    {
        throw new InvalidOperationException($"Graph validation failed: {validationResult.CreateSummary()}");
    }
}

// 啟用計畫編譯和快取（可選）
if (context.ExecutionOptions.EnablePlanCompilation)
{
    _ = GraphPlanCompiler.ComputeSignature(this);
    _ = GraphExecutionPlanCache.GetOrAdd(this);
}
```

### 2. 節點執行生命週期

每個節點都遵循一致的生命週期模式：

#### 執行前 (`OnBeforeExecuteAsync`)
* **中介軟體管線**：自訂中介軟體在節點執行前執行
* **節點掛鉤**：節點的 `OnBeforeExecuteAsync` 方法執行
* **資源取得**：根據節點成本和優先級取得資源許可
* **效能追蹤**：開始執行計時
* **除錯掛鉤**：斷點和逐步模式檢查

```csharp
// 執行生命週期：執行前（中介軟體然後節點掛鉤）
// Await 呼叫使用 ConfigureAwait(false)，以避免在消費者應用程式中捕捉
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
* **函式執行**：節點的核心邏輯執行
* **結果處理**：輸出被捕捉並儲存
* **狀態更新**：根據結果修改圖形狀態

#### 執行後 (`OnAfterExecuteAsync`)
* **節點掛鉤**：節點的 `OnAfterExecuteAsync` 方法執行
* **中介軟體管線**：自訂中介軟體在節點執行後執行
* **效能完成**：執行計時被最終化
* **成功登記**：節點成功被記錄以便自我修復

```csharp
// 執行節點
// 使用 ConfigureAwait(false) 讓程式庫程式碼不會捕捉內容。
var result = await execNode.ExecuteAsync(context.Kernel, context.GraphState.KernelArguments, effectiveCt).ConfigureAwait(false);

// 執行生命週期：執行後（節點掛鉤然後中介軟體）
await execNode.OnAfterExecuteAsync(context.Kernel, context.GraphState.KernelArguments, result, effectiveCt).ConfigureAwait(false);
await InvokeAfterMiddlewaresAsync(context, execNode, result).ConfigureAwait(false);

// 記錄成功完成
context.RecordNodeCompleted(execNode, result);

// 自我修復：登記成功
RegisterNodeSuccess(execNode.NodeId);
```

#### 錯誤處理 (`OnExecutionFailedAsync`)
* **失敗記錄**：節點失敗被記錄和追蹤
* **錯誤恢復**：恢復引擎嘗試恢復執行
* **原則應用**：錯誤處理原則決定重試/跳過行為
* **自我修復**：失敗的節點可能被隔離

```csharp
// 執行生命週期：失敗
// 確保在等待呼叫上使用 ConfigureAwait(false)。
await currentNode.OnExecutionFailedAsync(context.Kernel, context.GraphState.KernelArguments, ex, context.CancellationToken).ConfigureAwait(false);

// 記錄節點失敗
context.RecordNodeFailed(currentNode, ex);

// 自我修復：登記失敗並可能隔離
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

### 下一個節點選擇

節點執行後，執行器決定接下來執行哪些節點：

```csharp
// 找到下一個要執行的節點
var nextNodes = GetCombinedNextNodes(execNode, result, context.GraphState).ToList();

if (_routingEngine != null && nextNodes.Count > 0)
{
    // 使用動態路由引擎進行智能節點選擇
    // 在程式庫程式碼範例中等待時使用 ConfigureAwait(false)。
    currentNode = await _routingEngine.SelectNextNodeAsync(nextNodes, execNode,
        context.GraphState, result, context.CancellationToken).ConfigureAwait(false);
}
else
{
    if (nextNodes.Count <= 1 || !_concurrencyOptions.EnableParallelExecution)
    {
        // 以確定性順序進行順序執行
        var ordered = context.WorkQueue.OrderDeterministically(nextNodes).ToList();
        currentNode = ordered.FirstOrDefault();
    }
    else
    {
        // 平行分叉/合併執行
        // ... 平行執行邏輯
    }
}
```

### 條件邊緣評估

邊緣被評估以確定有效的轉換：

```csharp
private IEnumerable<IGraphNode> GetCombinedNextNodes(IGraphNode node, FunctionResult? result, GraphState graphState)
{
    var nextNodes = new List<IGraphNode>();
    
    // 獲取來自節點自身導航邏輯的節點
    var nodeNextNodes = node.GetNextNodes(result, graphState);
    nextNodes.AddRange(nodeNextNodes);
    
    // 獲取來自條件邊緣的節點
    var edgeNextNodes = GetOutgoingEdges(node)
        .Where(edge => edge.EvaluateCondition(graphState))
        .Select(edge => edge.TargetNode);
    nextNodes.AddRange(edgeNextNodes);
    
    return nextNodes.DistinctBy(n => n.NodeId);
}
```

## 執行限制和防護

### 1. 最大迭代次數

執行器對執行步驟總數施加可配置的限制：

```csharp
// 遵循各執行選項中的最大步驟數，在需要時回退到結構界限
var maxIterations = Math.Max(1, context.ExecutionOptions.MaxExecutionSteps);
var iterations = 0;

while (currentNode != null && iterations < maxIterations)
{
    // ... 執行邏輯
    iterations++;
}

if (iterations >= maxIterations)
{
    throw new InvalidOperationException($"Graph execution exceeded maximum steps ({maxIterations}). Possible infinite loop detected.");
}
```

### 2. 執行超時

整體執行超時防止失控的圖形：

```csharp
// 在配置時應用整體超時
if (context.ExecutionOptions.ExecutionTimeout > TimeSpan.Zero)
{
    var elapsed = DateTimeOffset.UtcNow - context.StartTime;
    if (elapsed > context.ExecutionOptions.ExecutionTimeout)
    {
        throw new OperationCanceledException($"Graph execution exceeded configured timeout of {context.ExecutionOptions.ExecutionTimeout}");
    }
}
```

### 3. 節點級超時

個別節點可以有可配置的超時：

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

自我修復機制自動隔離失敗的節點：

```csharp
// 自我修復：跳過隔離的節點
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

執行器追蹤執行深度以偵測過度嵌套：

```csharp
// 記錄執行路徑以供度量
if (_performanceMetrics != null && context.ExecutionPath.Count > 0)
{
    var executionPath = context.ExecutionPath.Select(n => n.NodeId).ToList();
    var totalDuration = context.Duration ?? TimeSpan.Zero;
    var success = lastResult != null;

    _performanceMetrics.RecordExecutionPath(context.ExecutionId, executionPath, totalDuration, success);
}
```

## 平行執行

### 分叉/合併模式

執行器支援多個分支的平行執行：

```csharp
// 平行分叉/合併：並行執行所有下一個節點，合併狀態，然後繼續
var branchNodes = context.WorkQueue.OrderDeterministically(nextNodes).ToList();

// 為每個分支複製基礎狀態以避免寫入衝突
var branchStates = branchNodes
    .Select(_ => StateHelpers.CloneState(context.GraphState))
    .ToList();

var semaphore = new SemaphoreSlim(Math.Max(1, _concurrencyOptions.MaxDegreeOfParallelism));

var branchTasks = branchNodes.Select(async (branchNode, index) =>
{
    await semaphore.WaitAsync(context.CancellationToken);
    try
    {
        // 使用隔離狀態執行分支節點
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

// 使用邊緣特定配置合併狀態
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

## 錯誤恢復和彈性

### 恢復引擎整合

執行器與恢復引擎整合以進行自動錯誤處理：

```csharp
// 如果有恢復引擎可用，嘗試錯誤恢復
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
            // 根據類型處理恢復（重試、回滾、繼續）
            switch (recoveryResult.RecoveryType)
            {
                case RecoveryType.Retry:
                    iterations--; // 不計算重試為迭代
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
        continue; // 重試目前節點
    }
    if (errorPolicy.ShouldSkip(currentNode, ex, context))
    {
        // 選擇下一個節點而不執行目前節點
        var nextCandidates = GetCombinedNextNodes(currentNode, lastResult, context.GraphState).ToList();
        currentNode = await SelectNextNodeAsync(currentNode, nextCandidates, context, lastResult);
        continue;
    }
}
```

## 中介軟體管線

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

執行器根據節點成本和優先級管理資源配置：

```csharp
// 決定成本和優先級（透過 DI 可插入）
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

* **設定合理的限制**：根據工作流程複雜性配置 `MaxExecutionSteps` 和 `ExecutionTimeout`
* **使用中介軟體**：實作自訂中介軟體以處理橫切關注點，如日誌記錄、監控和安全性
* **配置資源限制**：設定適當的資源治理以防止資源耗盡
* **啟用驗證**：在開發中使用 `ValidateGraphIntegrity` 以及早捕捉結構問題

### 錯誤處理

* **實作恢復原則**：為您的網域建立自訂錯誤處理原則
* **使用斷路器**：利用自我修復以自動處理失敗的節點
* **監控執行路徑**：追蹤執行路徑以識別效能瓶頸
* **設定節點超時**：為長時間執行的操作配置適當的超時

### 效能

* **啟用計畫編譯**：對複雜圖形使用 `EnablePlanCompilation` 以改善效能
* **配置平行執行**：為獨立分支使用平行執行
* **監控資源使用**：追蹤 CPU 和記憶體使用以優化資源配置
* **使用確定性順序**：使用 `DeterministicWorkQueue` 確保可重複執行

## 參考資源

* [圖形概念](graph-concepts.md) - 基本圖形概念和元件
* [節點類型](nodes.md) - 可用的節點實現及其生命週期
* [狀態管理](state.md) - 執行狀態如何被管理和傳播
* [錯誤處理](error-handling.md) - 進階錯誤恢復和彈性模式
* [效能調優](performance-tuning.md) - 最佳化圖形執行效能
* [範例](../examples/) - 執行模式的實際範例
