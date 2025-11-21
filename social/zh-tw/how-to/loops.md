# Loops

本指南說明如何使用 SemanticKernel.Graph 中的迴圈節點來實現反覆工作流程。您將學習如何建立 while 迴圈、foreach 迴圈，以及使用反覆限制和 break/continue 邏輯來實現適當的迴圈控制。

## 概述

Loop 節點可讓您建立反覆工作流程，能夠：
- **重複操作** 直到符合條件
- **處理數據項目的集合**
- **使用指數退避實現重試邏輯**
- **使用 break 和 continue 陳述式控制反覆流程**

## 基本迴圈類型

### While Loops

使用 `WhileLoopGraphNode` 建立在條件為真時繼續的迴圈。下面的程式碼片段使用已記錄的運行時型別和最小輔助 API，因此在放置在範例專案中時是可執行的。

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;

// 建立具有反覆限制的 while 迴圈
var whileNode = new WhileLoopGraphNode(
    condition: state => state.GetValue<int>("attempt") < 3,
    maxIterations: 5,
    nodeId: "retry_loop"
);

// 將迴圈新增至您的 Graph executor 或 Graph 表示
graph.AddNode(whileNode)
     .AddEdge("start", "retry_loop")
     .AddEdge("retry_loop", "process")
     .AddEdge("process", "retry_loop"); // 迴圈返回
```

### ForEach Loops

使用 `ForeachLoopGraphNode` 來反覆集合。該節點接受集合訪問子（或範本），並在每次反覆時在 Graph 狀態中公開目前項目和索引。

```csharp
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;

var foreachNode = new ForeachLoopGraphNode(
    collectionAccessor: state => state.GetValue<IEnumerable<object>>("items_to_process"),
    itemVariableName: "current_item",
    indexVariableName: "current_index",
    maxIterations: 100,
    nodeId: "process_items"
);

graph.AddNode(foreachNode)
     .AddEdge("start", "process_items")
     .AddEdge("process_items", "process_single_item")
     .AddEdge("process_single_item", "process_items"); // 繼續迴圈
```

## 迴圈控制模式

### Break 和 Continue 邏輯

透過評估狀態變數並連接條件邊來實現 break 和 continue 邏輯。使用 `GetValue<T>` 從 `GraphState` 讀取已鍵入的值。

```csharp
var whileNode = new WhileLoopGraphNode(
    condition: state =>
    {
        var attempt = state.GetValue<int>("attempt");
        var maxAttempts = state.GetValue<int>("max_attempts");
        var shouldContinue = state.GetValue<bool>("should_continue");

        return attempt < maxAttempts && shouldContinue;
    },
    maxIterations: 10,
    nodeId: "controlled_loop"
);

// 根據狀態新增條件路由
graph.AddConditionalEdge("controlled_loop", "break_loop",
    condition: state => !state.GetValue<bool>("should_continue"))
     .AddConditionalEdge("controlled_loop", "continue_loop",
    condition: state => state.GetValue<bool>("should_continue"));
```

### 反覆計數

追蹤和控制反覆進度。在 `FunctionGraphNode` 中從 `GraphState` 讀取和更新反覆計數器。

```csharp
var loopNode = new WhileLoopGraphNode(
    condition: state =>
    {
        var iteration = state.GetValue<int>("iteration");
        var maxIterations = state.GetValue<int>("max_iterations");
        var hasMoreWork = state.GetValue<bool>("has_more_work");

        return iteration < maxIterations && hasMoreWork;
    },
    maxIterations: 15,
    nodeId: "counting_loop"
);

// 在每次反覆中遞增計數器（在 FunctionGraphNode 中實現）
graph.AddEdge("counting_loop", "increment_counter")
     .AddEdge("increment_counter", "process_work")
     .AddEdge("process_work", "check_work_status")
     .AddEdge("check_work_status", "counting_loop");
```

## 進階迴圈模式

### 使用退避的重試迴圈

實現具有退避的重試邏輯。使用已鍵入的訪問子和輔助函式節點來計算延遲。

```csharp
var retryNode = new WhileLoopGraphNode(
    condition: state =>
    {
        var attempt = state.GetValue<int>("attempt");
        var maxAttempts = state.GetValue<int>("max_attempts");
        var lastError = state.GetValue<string>("last_error");
        var isRetryable = IsRetryableError(lastError);

        return attempt < maxAttempts && isRetryable;
    },
    maxIterations: 10,
    nodeId: "retry_with_backoff"
);

// 使用函式節點計算退避延遲
var backoffNode = new FunctionGraphNode(
    kernelFunction: CalculateBackoffDelay,
    nodeId: "calculate_backoff"
);

graph.AddNode(retryNode)
     .AddNode(backoffNode)
     .AddEdge("retry_with_backoff", "attempt_operation")
     .AddEdge("attempt_operation", "check_result")
     .AddConditionalEdge("check_result", "success",
        condition: state => state.GetValue<bool>("operation_succeeded"))
     .AddConditionalEdge("check_result", "calculate_backoff",
        condition: state => !state.GetValue<bool>("operation_succeeded"))
     .AddEdge("calculate_backoff", "wait_delay")
     .AddEdge("wait_delay", "retry_with_backoff");
```

### 批次處理迴圈

使用迴圈控制處理批次中的資料。使用 `GraphState` 追蹤進度，並使用函式節點來處理每個批次。

```csharp
var batchLoop = new WhileLoopGraphNode(
    condition: state =>
    {
        var processedCount = state.GetValue<int>("processed_count");
        var totalCount = state.GetValue<int>("total_count");
        var batchSize = state.GetValue<int>("batch_size");

        return processedCount < totalCount;
    },
    maxIterations: 1000,
    nodeId: "batch_processor"
);

var batchProcessor = new FunctionGraphNode(
    kernelFunction: ProcessBatch,
    nodeId: "process_batch"
);

graph.AddNode(batchLoop)
     .AddNode(batchProcessor)
     .AddEdge("batch_processor", "process_batch")
     .AddEdge("process_batch", "update_progress")
     .AddEdge("update_progress", "batch_processor");
```

### 巢狀迴圈

透過組合迴圈節點來實現複雜處理的巢狀迴圈結構。

```csharp
var outerLoop = new WhileLoopGraphNode(
    condition: state => state.GetValue<int>("outer_iteration") < 10,
    maxIterations: 15,
    nodeId: "outer_loop"
);

var innerLoop = new WhileLoopGraphNode(
    condition: state => state.GetValue<int>("inner_iteration") < 5,
    maxIterations: 10,
    nodeId: "inner_loop"
);

graph.AddNode(outerLoop)
     .AddNode(innerLoop)
     .AddEdge("outer_loop", "inner_loop")
     .AddEdge("inner_loop", "process_item")
     .AddEdge("process_item", "inner_loop")
     .AddEdge("inner_loop", "outer_loop");
```

## 迴圈狀態管理

### 狀態初始化

使用函式節點來正確初始化迴圈狀態變數，該節點在 `GraphState` 中設定必要的鍵。

```csharp
var initializeLoop = new FunctionGraphNode(
    kernelFunction: (KernelArguments args) =>
    {
        var state = args.GetOrCreateGraphState();
        state.SetValue("iteration", 0);
        state.SetValue("max_iterations", 10);
        state.SetValue("accumulator", 0);
        state.SetValue("items_processed", new List<string>());
        return "Loop initialized";
    },
    nodeId: "initialize_loop"
);

var loopNode = new WhileLoopGraphNode(
    condition: state => state.GetValue<int>("iteration") < state.GetValue<int>("max_iterations"),
    maxIterations: 15,
    nodeId: "main_loop"
);

graph.AddNode(initializeLoop)
     .AddNode(loopNode)
     .AddEdge("start", "initialize_loop")
     .AddEdge("initialize_loop", "main_loop");
```

### 狀態更新

在每次反覆中使用函式節點來更新迴圈狀態，該節點讀取/寫入已鍵入的值。

```csharp
var updateState = new FunctionGraphNode(
    kernelFunction: (KernelArguments args) =>
    {
        var state = args.GetOrCreateGraphState();
        var currentIteration = state.GetValue<int>("iteration");
        state.SetValue("iteration", currentIteration + 1);

        var currentAccumulator = state.GetValue<int>("accumulator");
        var newValue = state.GetValue<int>("current_value");
        state.SetValue("accumulator", currentAccumulator + newValue);

        return $"Iteration {currentIteration + 1} completed";
    },
    nodeId: "update_state"
);

graph.AddEdge("main_loop", "process_work")
     .AddEdge("process_work", "update_state")
     .AddEdge("update_state", "main_loop");
```

## 效能最佳化

### 迴圈效率

使用適當的狀態管理和昂貴計算的快取來最佳化迴圈效能。

```csharp
var optimizedLoop = new WhileLoopGraphNode(
    condition: state =>
    {
        // 快取昂貴的計算
        if (state.TryGetValue("cached_condition", out var cached) && cached is bool cachedBool)
        {
            return cachedBool;
        }

        var result = EvaluateComplexCondition(state);
        state.SetValue("cached_condition", result);
        return result;
    },
    maxIterations: 50,
    nodeId: "optimized_loop"
);
```

### 批次處理

在每次反覆中處理多個項目：

```csharp
var batchLoop = new WhileLoopGraphNode(
    condition: state =>
    {
        var remainingItems = state.GetValue<List<string>>("remaining_items");
        return remainingItems != null && remainingItems.Count > 0;
    },
    maxIterations: 100,
    nodeId: "efficient_batch_loop"
);

var batchProcessor = new FunctionGraphNode(
    kernelFunction: (KernelArguments args) =>
    {
        var state = args.GetOrCreateGraphState();
        var remainingItems = state.GetValue<List<string>>("remaining_items") ?? new List<string>();
        var batchSize = Math.Min(10, remainingItems.Count);
        var batch = remainingItems.Take(batchSize).ToList();

        // 處理批次
        var results = ProcessBatch(batch);

        // 更新剩餘項目
        state.SetValue("remaining_items", remainingItems.Skip(batchSize).ToList());
        state.SetValue("processed_results", results);

        return $"Processed {batch.Count} items";
    },
    nodeId: "process_batch"
);
```

## 迴圈中的錯誤處理

### 迴圈錯誤恢復

透過路由至錯誤處理節點並應用恢復策略，在迴圈內優雅地處理錯誤。

```csharp
var errorHandlingLoop = new WhileLoopGraphNode(
    condition: state =>
    {
        var attempt = state.GetValue<int>("attempt");
        var maxAttempts = state.GetValue<int>("max_attempts");
        var lastError = state.GetValue<string>("last_error");

        return attempt < maxAttempts && !string.IsNullOrEmpty(lastError);
    },
    maxIterations: 10,
    nodeId: "error_recovery_loop"
);

var errorHandler = new ErrorHandlerGraphNode(
    errorTypes: new[] { ErrorType.Transient, ErrorType.External },
    recoveryAction: RecoveryAction.Retry,
    maxRetries: 2,
    nodeId: "loop_error_handler"
);

graph.AddNode(errorHandlingLoop)
     .AddNode(errorHandler)
     .AddEdge("error_recovery_loop", "attempt_operation")
     .AddEdge("attempt_operation", "loop_error_handler")
     .AddEdge("loop_error_handler", "error_recovery_loop");
```

### 優雅降級

當迴圈失敗時實現回退邏輯：

```csharp
var fallbackLoop = new WhileLoopGraphNode(
    condition: state =>
    {
        var primaryMethodFailed = state.GetValue<bool>("primary_method_failed");
        var fallbackAttempts = state.GetValue<int>("fallback_attempts");
        var maxFallbackAttempts = state.GetValue<int>("max_fallback_attempts");

        return primaryMethodFailed && fallbackAttempts < maxFallbackAttempts;
    },
    maxIterations: 5,
    nodeId: "fallback_loop"
);

graph.AddConditionalEdge("attempt_primary", "primary_success",
    condition: state => state.GetValue<bool>("primary_succeeded"))
    .AddConditionalEdge("attempt_primary", "fallback_loop",
    condition: state => !state.GetValue<bool>("primary_succeeded"))
    .AddEdge("fallback_loop", "attempt_fallback")
    .AddEdge("attempt_fallback", "fallback_loop");
```

## 監控和計量

### 迴圈效能追蹤

監控迴圈效能和效率：

```csharp
var monitoredLoop = new WhileLoopGraphNode(
    condition: state =>
    {
        var startTime = state.GetValue<DateTimeOffset>("loop_start_time");
        var maxDuration = TimeSpan.FromMinutes(5);
        var elapsed = DateTimeOffset.UtcNow - startTime;

        // 追蹤迴圈計量
        var iteration = state.GetValue<int>("iteration");
        state.SetValue("loop_metrics", new {
            Iteration = iteration,
            ElapsedTime = elapsed,
            AverageTimePerIteration = elapsed.TotalMilliseconds / Math.Max(1, iteration)
        });

        return elapsed < maxDuration && state.GetValue<bool>("should_continue");
    },
    maxIterations: 100,
    nodeId: "monitored_loop"
);
```

### 迴圈健康檢查

為長期運行的迴圈實現健康檢查：

```csharp
var healthCheckLoop = new WhileLoopGraphNode(
    condition: state =>
    {
        var iteration = state.GetValue<int>("iteration");
        var lastHealthCheck = state.GetValue<DateTimeOffset>("last_health_check");
        var healthCheckInterval = TimeSpan.FromSeconds(30);

        // 如果需要執行健康檢查
        if (DateTimeOffset.UtcNow - lastHealthCheck > healthCheckInterval)
        {
            var isHealthy = PerformHealthCheck(state);
            state.SetValue("last_health_check", DateTimeOffset.UtcNow);
            state.SetValue("is_healthy", isHealthy);

            if (!isHealthy)
            {
                state.SetValue("health_check_failed", true);
                return false; // 健康檢查失敗時結束迴圈
            }
        }

        return state.GetValue<bool>("should_continue");
    },
    maxIterations: 1000,
    nodeId: "health_checked_loop"
);
```

## 最佳實踐

### 迴圈設計

1. **設定反覆限制** - 總是定義 `maxIterations` 以防止無限迴圈
2. **正確初始化狀態** - 在進入迴圈之前設定迴圈變數
3. **處理邊界情況** - 為意外條件提供回退路徑
4. **監控效能** - 追蹤迴圈效率和資源使用情況

### 狀態管理

1. **一致地更新狀態** - 確保在每次反覆中更新迴圈變數
2. **快取昂貴的操作** - 儲存結果以避免重新計算
3. **清理資源** - 正確處理迴圈中使用的資源
4. **驗證狀態變更** - 驗證狀態更新是否正確

### 錯誤處理

1. **實現重試邏輯** - 優雅地處理暫時性失敗
2. **設定逾時限制** - 防止迴圈無限期運行
3. **記錄迴圈進度** - 追蹤反覆進度以便偵錯
4. **提供回退** - 當迴圈失敗時有替代路徑

## 疑難排解

### 常見問題

**無限迴圈**: 檢查迴圈條件並確保它們最終變為假

**效能降級**: 監控反覆時間並最佳化昂貴的操作

**狀態損毀**: 驗證狀態更新並實現適當的錯誤處理

**記憶體洩漏**: 清理資源並避免在迴圈中累積資料

### 偵錯提示

1. **啟用迴圈記錄** 追蹤反覆進度
2. **在迴圈條件和狀態更新中新增中斷點**
3. **監控迴圈計量** 以了解效能問題
4. **使用迴圈視覺化** 以了解執行流程

## 概念和技術

**WhileLoopNode**: 一個專門的 Graph 節點，建立在指定條件為真時繼續的迴圈。它能夠透過適當的反覆限制和狀態管理來實現反覆工作流程。

**ForeachLoopNode**: 一個 Graph 節點，反覆集合中的資料項目。它處理集合中的每個項目，並在整個過程中維護反覆狀態。

**Loop Control**: 控制迴圈執行的機制，包括 break 和 continue 邏輯、反覆限制以及反覆工作流程內的狀態管理。

**Iteration Limits**: 安全機制，透過設定最大反覆計數和迴圈執行的逾時約束來防止無限迴圈。

**Loop State Management**: 在迴圈執行過程中正確初始化、更新和維護狀態變數的做法，以確保正確的行為和效能。

## 另請參閱

- [Build a Graph](build-a-graph.md) - 學習 Graph 構建的基礎知識
- [Conditional Nodes](conditional-nodes.md) - 在工作流程中實現分支邏輯
- [Advanced Routing](advanced-routing.md) - 探索複雜的路由模式
- [State Management](../state-quickstart.md) - 了解如何管理節點之間的資料流
- [Error Handling and Resilience](error-handling-and-resilience.md) - 了解迴圈中的錯誤處理
- [Examples: Loop Workflows](../examples/loop-nodes-example.md) - 迴圈實現的完整工作範例
