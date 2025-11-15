# 檢查點快速入門

了解如何使用 SemanticKernel.Graph 的檢查點系統來保存和恢復圖執行狀態。本指南展示如何在長時間運行的操作中保持狀態、從失敗中恢復以及維護執行歷史。

## 概念和技術

**檢查點**：在圖執行的特定點保存當前狀態的過程，能夠從任何保存的狀態進行恢復和繼續執行。

**狀態持久化**：`StateHelpers` 提供序列化和反序列化 `GraphState` 物件的工具，而 `CheckpointManager` 處理存儲和檢索。

**恢復和重播**：從任何檢查點恢復執行，實現容錯能力和重播執行場景的能力。

## 前置條件和最低配置

* .NET 8.0 或更高版本
* 已安裝 SemanticKernel.Graph 套件
* 已配置圖記憶體服務（檢查點必須）
* 在核心中啟用檢查點支持

## 快速設置

### 1. 啟用檢查點支持

使用記憶體集成向核心添加檢查點支持：

```csharp
using SemanticKernel.Graph.Extensions;

var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphMemory()  // 檢查點必須
    .AddCheckpointSupport(options =>
    {
        options.EnableCompression = true;
        options.MaxCacheSize = 100;
    })
    .Build();
```

### 2. 創建一個檢查點圖執行器

使用檢查點執行器工廠創建具有檢查點功能的執行器：

```csharp
using SemanticKernel.Graph.Core;

var executorFactory = kernel.Services.GetRequiredService<ICheckpointingGraphExecutorFactory>();
var executor = executorFactory.CreateExecutor("my-graph", new CheckpointingOptions
{
    CheckpointInterval = 2,  // 每 2 個節點創建一個檢查點
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    EnableAutoCleanup = true,
    CriticalNodes = new HashSet<string> { "process", "validate" }
});
```

### 3. 構建並執行您的圖

添加節點並使用自動檢查點執行：

```csharp
using SemanticKernel.Graph.Nodes;

// 向圖添加節點
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

// 使用自動檢查點執行
var arguments = new KernelArguments();
arguments["input"] = "Process this data";
arguments["counter"] = 0;

var result = await executor.ExecuteAsync(kernel, arguments);
Console.WriteLine($"Execution completed: {result.GetValue<object>()}");
Console.WriteLine($"ExecutionId: {executor.LastExecutionId}");
```

## 手動檢查點管理

### 創建檢查點

使用 `StateHelpers` 手動創建和管理檢查點：

```csharp
using SemanticKernel.Graph.State;

// 獲取當前圖狀態
var graphState = arguments.GetOrCreateGraphState();

// 使用自訂名稱創建檢查點
var checkpointId = StateHelpers.CreateCheckpoint(graphState, "manual-checkpoint");
Console.WriteLine($"Created checkpoint: {checkpointId}");

// 檢查點現在存儲在狀態元資料中
var checkpoint = graphState.GetMetadata<object>($"checkpoint_{checkpointId}");
if (checkpoint != null)
{
    Console.WriteLine("Checkpoint created successfully");
}
```

### 從檢查點恢復

從任何保存的檢查點恢復圖狀態：

```csharp
try
{
    // 從特定檢查點恢復狀態
    var restoredState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);
    
    // 注意：UpdateFromGraphState 方法在當前實現中不存在
    // 恢復的狀態可用於分析或手動狀態重建
    Console.WriteLine("State restored successfully");
}
catch (InvalidOperationException ex)
{
    Console.WriteLine($"Failed to restore checkpoint: {ex.Message}");
}
```

## 高級檢查點配置

### 檢查點選項

配置詳細的檢查點行為：

```csharp
var checkpointingOptions = new CheckpointingOptions
{
    CheckpointInterval = 3,  // 每 3 個節點
    CheckpointTimeInterval = TimeSpan.FromMinutes(5),  // 或每 5 分鐘
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true,  // 在發生錯誤時保存狀態
    EnableAutoCleanup = true,
    FailOnCheckpointError = false,  // 即使檢查點失敗也繼續執行
    
    // 定義總是觸發檢查點的關鍵節點
    CriticalNodes = new HashSet<string> { "process", "validate", "output" },
    
    // 配置保留策略
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

使用自動檢查點恢復實現容錯能力：

```csharp
try
{
    var result = await executor.ExecuteAsync(kernel, arguments);
    Console.WriteLine("Execution completed successfully");
}
catch (Exception ex)
{
    Console.WriteLine($"Execution failed: {ex.Message}");
    
    // 尋找最新的檢查點以進行恢復
    var executionId = executor.LastExecutionId ?? arguments.GetOrCreateGraphState().StateId;
    var checkpoints = await executor.GetExecutionCheckpointsAsync(executionId);
    
    if (checkpoints.Count > 0)
    {
        var latestCheckpoint = checkpoints.First();
        Console.WriteLine($"Latest checkpoint: {latestCheckpoint.CheckpointId}");
        
        // 從檢查點恢復
        var recoveredResult = await executor.ResumeFromCheckpointAsync(
            latestCheckpoint.CheckpointId, kernel);
        
        Console.WriteLine($"Recovery successful: {recoveredResult.GetValue<object>()}");
    }
}
```

## 檢查點監測和管理

### 查看檢查點統計

監控檢查點系統：

```csharp
// 獲取最後執行的檢查點統計
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

清理舊檢查點以管理儲存空間：

```csharp
var checkpointManager = kernel.Services.GetRequiredService<ICheckpointManager>();

// 清理舊檢查點
var cleanupCount = await checkpointManager.CleanupCheckpointsAsync(
    retentionPolicy: new CheckpointRetentionPolicy
    {
        MaxAge = TimeSpan.FromHours(1),
        MaxCheckpointsPerExecution = 10,
        MaxTotalStorageBytes = 50 * 1024 * 1024  // 50MB
    });

Console.WriteLine($"Cleaned up {cleanupCount} old checkpoints");
```

## 故障排除

### 常見問題

**檢查點不工作**：確保在構建核心時調用了 `.AddGraphMemory()` 和 `.AddCheckpointSupport()`。

**找不到記憶體服務**：檢查點系統需要圖記憶體服務。確保已正確配置。

**檢查點太大**：使用 `options.EnableCompression = true` 啟用壓縮，並考慮減少存儲在狀態中的數據。

**恢復失敗**：驗證檢查點完整性並確保在嘗試恢復前檢查點 ID 存在。

### 性能建議

* 根據執行時間使用適當的檢查點間隔
* 為大型狀態物件啟用壓縮
* 配置保留策略以防止儲存空間溢出
* 謹慎使用關鍵節點以避免過度檢查點
* 監測檢查點大小並相應調整壓縮設置

## 另請參閱

* **參考**：[CheckpointManager](../api/CheckpointManager.md)、[CheckpointingOptions](../api/CheckpointingOptions.md)、[StateHelpers](../api/StateHelpers.md)
* **指南**：[狀態管理](../guides/state-management.md)、[恢復和重播](../guides/recovery-replay.md)
* **範例**：[CheckpointingExample](../examples/checkpointing.md)、[AdvancedPatternsExample](../examples/advanced-patterns.md)

## 參考 API

* **[CheckpointManager](../api/checkpointing.md#checkpoint-manager)**：檢查點存儲和檢索
* **[CheckpointingOptions](../api/checkpointing.md#checkpointing-options)**：檢查點配置
* **[StateHelpers](../api/state.md#state-helpers)**：狀態序列化工具
* **[ICheckpointingGraphExecutor](../api/checkpointing.md#icheckpointing-graph-executor)**：檢查點執行器介面
