# Checkpointing 快速入門

了解如何使用 SemanticKernel.Graph 的 checkpointing 系統來儲存和恢復 Graph 執行狀態。本指南將展示如何在長時間執行作業期間持久化狀態、從失敗中恢復，以及維護執行歷史。

## 概念和技術

**Checkpointing**: 在特定點儲存 Graph 執行當前狀態的過程，可從任何儲存狀態中實現恢復和繼續執行。

**State Persistence**: `StateHelpers` 提供用於序列化和反序列化 `GraphState` 物件的公用程式，而 `CheckpointManager` 則處理儲存和擷取。

**Recovery and Replay**: 從任何 checkpoint 繼續執行，啟用容錯能力和重新執行情景的能力。

## 前置條件和最小設定

* .NET 8.0 或更高版本
* 已安裝 SemanticKernel.Graph 套件
* Graph 記憶體服務已設定（checkpointing 所需）
* 在您的 kernel 中啟用 checkpoint 支援

## 快速設定

### 1. 啟用 Checkpoint 支援

使用記憶體整合將 checkpoint 支援新增至您的 kernel：

```csharp
using SemanticKernel.Graph.Extensions;

var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphMemory()  // checkpointing 所需
    .AddCheckpointSupport(options =>
    {
        options.EnableCompression = true;
        options.MaxCacheSize = 100;
    })
    .Build();
```

### 2. 建立 Checkpointing Graph Executor

使用 checkpointing executor 工廠建立具有 checkpoint 功能的 executor：

```csharp
using SemanticKernel.Graph.Core;

var executorFactory = kernel.Services.GetRequiredService<ICheckpointingGraphExecutorFactory>();
var executor = executorFactory.CreateExecutor("my-graph", new CheckpointingOptions
{
    CheckpointInterval = 2,  // 每 2 個 Node 建立一個 checkpoint
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    EnableAutoCleanup = true,
    CriticalNodes = new HashSet<string> { "process", "validate" }
});
```

### 3. 建置並執行您的 Graph

新增 Node 並使用自動 checkpointing 執行：

```csharp
using SemanticKernel.Graph.Nodes;

// 將 Node 新增至您的 Graph
var inputNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "Input data", "input"),
    "input", "DataInput");

var processNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "Processed data", "process"),
    "process", "DataProcess");

executor.AddNode(inputNode)
        .AddNode(processNode)
        .Connect("input", "process")
        .SetStartNode("input");

// 使用自動 checkpointing 執行
var arguments = new KernelArguments();
arguments["input"] = "Process this data";
arguments["counter"] = 0;

var result = await executor.ExecuteAsync(kernel, arguments);
Console.WriteLine($"Execution completed: {result.GetValue<object>()}");
Console.WriteLine($"ExecutionId: {executor.LastExecutionId}");
```

## 手動 Checkpoint 管理

### 建立 Checkpoint

使用 `StateHelpers` 手動建立和管理 checkpoint：

```csharp
using SemanticKernel.Graph.State;

// 取得當前 Graph 狀態
var graphState = arguments.GetOrCreateGraphState();

// 使用自訂名稱建立 checkpoint
var checkpointId = StateHelpers.CreateCheckpoint(graphState, "manual-checkpoint");
Console.WriteLine($"Created checkpoint: {checkpointId}");

// checkpoint 現在儲存在狀態中繼資料中
var checkpoint = graphState.GetMetadata<object>($"checkpoint_{checkpointId}");
if (checkpoint != null)
{
    Console.WriteLine("Checkpoint created successfully");
}
```

### 從 Checkpoint 恢復

從任何儲存的 checkpoint 恢復您的 Graph 狀態：

```csharp
try
{
    // 從特定 checkpoint 恢復狀態
    var restoredState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);
    
    // 注意：UpdateFromGraphState 方法在目前實作中不存在
    // 恢復的狀態可用於分析或手動狀態重建
    Console.WriteLine("State restored successfully");
}
catch (InvalidOperationException ex)
{
    Console.WriteLine($"Failed to restore checkpoint: {ex.Message}");
}
```

## 進階 Checkpoint 設定

### Checkpointing 選項

設定詳細的 checkpoint 行為：

```csharp
var checkpointingOptions = new CheckpointingOptions
{
    CheckpointInterval = 3,  // 每 3 個 Node
    CheckpointTimeInterval = TimeSpan.FromMinutes(5),  // 或每 5 分鐘
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true,  // 在錯誤時儲存狀態
    EnableAutoCleanup = true,
    FailOnCheckpointError = false,  // 即使 checkpointing 失敗也繼續執行
    
    // 定義始終觸發 checkpoint 的關鍵 Node
    CriticalNodes = new HashSet<string> { "process", "validate", "output" },
    
    // 設定保留原則
    RetentionPolicy = new CheckpointRetentionPolicy
    {
        MaxAge = TimeSpan.FromHours(24),
        MaxCheckpointsPerExecution = 50,
        MaxTotalStorageBytes = 100 * 1024 * 1024  // 100MB
    }
};

var executor = executorFactory.CreateExecutor("advanced-graph", checkpointingOptions);
```

### 從失敗中恢復

使用自動 checkpoint 恢復實施容錯能力：

```csharp
try
{
    var result = await executor.ExecuteAsync(kernel, arguments);
    Console.WriteLine("Execution completed successfully");
}
catch (Exception ex)
{
    Console.WriteLine($"Execution failed: {ex.Message}");
    
    // 尋找最新的 checkpoint 以進行恢復
    var executionId = executor.LastExecutionId ?? arguments.GetOrCreateGraphState().StateId;
    var checkpoints = await executor.GetExecutionCheckpointsAsync(executionId);
    
    if (checkpoints.Count > 0)
    {
        var latestCheckpoint = checkpoints.First();
        Console.WriteLine($"Latest checkpoint: {latestCheckpoint.CheckpointId}");
        
        // 從 checkpoint 繼續執行
        var recoveredResult = await executor.ResumeFromCheckpointAsync(
            latestCheckpoint.CheckpointId, kernel);
        
        Console.WriteLine($"Recovery successful: {recoveredResult.GetValue<object>()}");
    }
}
```

## Checkpoint 監控和管理

### 檢視 Checkpoint 統計資訊

監控您的 checkpoint 系統：

```csharp
// 取得最後執行的 checkpoint 統計資訊
var executionId = executor.LastExecutionId;
if (!string.IsNullOrEmpty(executionId))
{
    var checkpoints = await executor.GetExecutionCheckpointsAsync(executionId);
    
    Console.WriteLine($"Checkpoint Statistics for {executionId}:");
    Console.WriteLine($"Total checkpoints: {checkpoints.Count}");
    
    foreach (var checkpoint in checkpoints.OrderBy(c => c.SequenceNumber))
    {
        Console.WriteLine($"  {checkpoint.CheckpointId}: " +
                         $"Node {checkpoint.NodeId}, " +
                         $"Size: {checkpoint.SizeInBytes / 1024:F1} KB, " +
                         $"Created: {checkpoint.CreatedAt:HH:mm:ss}");
    }
}
```

### 手動清理

清理舊的 checkpoint 以管理儲存空間：

```csharp
var checkpointManager = kernel.Services.GetRequiredService<ICheckpointManager>();

// 清理舊的 checkpoint
var cleanupCount = await checkpointManager.CleanupCheckpointsAsync(
    retentionPolicy: new CheckpointRetentionPolicy
    {
        MaxAge = TimeSpan.FromHours(1),
        MaxCheckpointsPerExecution = 10,
        MaxTotalStorageBytes = 50 * 1024 * 1024  // 50MB
    });

Console.WriteLine($"Cleaned up {cleanupCount} old checkpoints");
```

## 疑難排解

### 常見問題

**Checkpointing 無法運作**: 確保在建置 kernel 時呼叫了 `.AddGraphMemory()` 和 `.AddCheckpointSupport()`。

**找不到記憶體服務**: checkpointing 系統需要 Graph 記憶體服務。確保已正確設定它。

**Checkpoint 太大**: 使用 `options.EnableCompression = true` 啟用壓縮，並考慮減少儲存在狀態中的資料。

**恢復失敗**: 驗證 checkpoint 完整性，並在嘗試還原之前確保 checkpoint ID 存在。

### 效能建議

* 根據您的執行時間使用適當的 checkpoint 間隔
* 為大型狀態物件啟用壓縮
* 設定保留原則以防止儲存空間膨脹
* 謹慎使用關鍵 Node 以避免過度 checkpointing
* 監控 checkpoint 大小並相應調整壓縮設定

## 另請參閱

* **Reference**: [CheckpointManager](../api/CheckpointManager.md), [CheckpointingOptions](../api/CheckpointingOptions.md), [StateHelpers](../api/StateHelpers.md)
* **Guides**: [State Management](../guides/state-management.md), [Recovery and Replay](../guides/recovery-replay.md)
* **Examples**: [CheckpointingExample](../examples/checkpointing.md), [AdvancedPatternsExample](../examples/advanced-patterns.md)

## 參考 API

* **[CheckpointManager](../api/checkpointing.md#checkpoint-manager)**: Checkpoint 儲存和擷取
* **[CheckpointingOptions](../api/checkpointing.md#checkpointing-options)**: Checkpoint 設定
* **[StateHelpers](../api/state.md#state-helpers)**: 狀態序列化公用程式
* **[ICheckpointingGraphExecutor](../api/checkpointing.md#icheckpointing-graph-executor)**: Checkpointing executor 介面
