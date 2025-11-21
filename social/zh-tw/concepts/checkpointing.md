# Checkpointing 和恢復

Checkpointing 和恢復是 SemanticKernel.Graph 的必要功能，可以實現容錯、執行恢復和狀態持久化。本指南說明如何使用 `StateHelpers`、管理狀態版本、實現壓縮、確保完整性並設定恢復策略。

## 您將學到

* 如何使用 `StateHelpers` 保存和還原 Graph 執行狀態
* 跨不同版本管理狀態版本和相容性
* 實現壓縮以實現高效的儲存和傳輸
* 在 checkpoint 操作期間確保資料完整性和驗證
* 設定恢復策略和自動清理
* 使用自動恢復構建容錯工作流程

## 概念和技術

**Checkpointing**: 在特定時間點保存 Graph 執行的目前狀態的過程，可以從任何已保存的狀態恢復和繼續執行。

**狀態持久化**: `StateHelpers` 提供用於序列化和反序列化 `GraphState` 物件的實用程式，並支持壓縮和完整性驗證。

**恢復機制**: 從 checkpoints 自動和手動恢復，並具有一致性驗證和風險評估。

**狀態版本控制**: 語意版本系統，確保相容性並實現不同狀態格式之間的遷移。

**壓縮和完整性**: 用於儲存效率的內建壓縮以及用於資料完整性的校驗和驗證。

## 前置條件

* 已完成[狀態管理](state.md)指南
* 對 `GraphState` 和 `KernelArguments` 的基本理解
* 已設定 Graph 記憶體服務（checkpointing 需要）
* 在您的核心中啟用 Checkpoint 支援

## 核心 Checkpointing 元件

### StateHelpers: 核心 Checkpoint 工具

`StateHelpers` 為所有 checkpointing 操作提供基礎：

```csharp
using SemanticKernel.Graph.State;

// 將狀態保存到 checkpoint
var checkpointId = StateHelpers.CreateCheckpoint(graphState, "my-checkpoint");

// 從 checkpoint 還原狀態
// 注意: RestoreCheckpoint 期望 checkpoint 被儲存在相同的
// 狀態的中繼資料中（CreateCheckpoint 在提供的狀態上儲存一個 checkpoint 條目）。
var restoredState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);

// 序列化狀態以供儲存
var serializedState = StateHelpers.SerializeState(graphState);

// 從儲存區反序列化狀態
var deserializedState = StateHelpers.DeserializeState(serializedState);
```

### CheckpointManager: 集中式 Checkpoint 管理

`CheckpointManager` 處理儲存、檢索和生命週期管理：

```csharp
using SemanticKernel.Graph.Core;

var checkpointManager = kernel.Services.GetRequiredService<ICheckpointManager>();

// 建立新的 checkpoint
var checkpoint = await checkpointManager.CreateCheckpointAsync(
    executionId: "exec-123",
    nodeId: "process-node",
    state: graphState,
    metadata: new Dictionary<string, object>
    {
        ["step"] = "data-processing",
        ["timestamp"] = DateTimeOffset.UtcNow
    }
);

// 檢索 checkpoint
var retrievedCheckpoint = await checkpointManager.GetCheckpointAsync(checkpointId);

// 列出執行的 checkpoints
var checkpoints = await checkpointManager.ListCheckpointsAsync("exec-123", limit: 10);
```

## 狀態版本控制和相容性

### StateVersion: 語意版本控制

`StateVersion` 確保跨不同版本的相容性：

```csharp
using SemanticKernel.Graph.State;

// 目前版本資訊
var currentVersion = StateVersion.Current;           // 例如 1.1.0
var minSupported = StateVersion.MinimumSupported;    // 例如 1.0.0

// 檢查版本相容性
var stateVersion = graphState.Version;
var isCompatible = stateVersion.IsCompatibleWith(StateVersion.Current);
var requiresMigration = stateVersion.RequiresMigration; // 當比目前版本舊時需要遷移

// 版本比較和解析
if (StateVersion.TryParse("1.2.3", out var version))
{
    if (version < StateVersion.Current)
    {
        Console.WriteLine("狀態版本比目前版本舊");
    }
}
else
{
    Console.WriteLine("無效的版本字串");
}
```

### 版本遷移

自動遷移處理狀態格式變更：

```csharp
// 在反序列化期間，可能需要遷移。使用 StateMigrationManager
// 在反序列化前將序列化狀態遷移到目前版本。
if (StateMigrationManager.IsMigrationNeeded(StateVersion.Parse("1.0.0")))
{
    var migratedJson = StateMigrationManager.MigrateToCurrentVersion(serializedData, StateVersion.Parse("1.0.0"));
    var state = JsonSerializer.Deserialize<GraphState>(migratedJson);
    if (state != null)
    {
        Console.WriteLine($"反序列化已遷移狀態版本: {state.Version}");
    }
}
```

## 狀態壓縮和儲存

### 壓縮選項

設定壓縮以提高儲存效率：

```csharp
// 具有壓縮的序列化選項。使用 GraphState.Serialize 方法
// 該方法接受 SerializationOptions 執行個體。
var options = new SerializationOptions
{
    EnableCompression = true,           // 啟用壓縮
    CompressionThreshold = 1024,        // 如果 > 1KB 則壓縮
    IncludeMetadata = true,             // 包含狀態中繼資料
    IncludeExecutionHistory = false,    // 排除儲存的執行記錄
    ValidateIntegrity = true            // 序列化前驗證
};

var compressedState = graphState.Serialize(options);
```

### 儲存最佳化

使用選擇性序列化最佳化儲存：

```csharp
// 最小儲存選項
var storageOptions = new SerializationOptions
{
    EnableCompression = true,
    IncludeMetadata = false,            // 排除儲存的中繼資料
    IncludeExecutionHistory = false,    // 排除執行記錄
    ValidateIntegrity = true
};

// 用於偵錯的完整狀態選項
var debugOptions = new SerializationOptions
{
    EnableCompression = false,          // 不壓縮用於偵錯
    IncludeMetadata = true,             // 包含所有中繼資料
    IncludeExecutionHistory = true,     // 包含執行記錄
    Indented = true                     // 人類可讀格式
};
```

## 資料完整性和驗證

### 完整性驗證

確保 checkpoint 資料完整性：

```csharp
// checkpointing 前驗證狀態
var validationResult = graphState.ValidateIntegrity();
if (!validationResult.IsValid)
{
    Console.WriteLine($"狀態驗證失敗: {validationResult.ErrorCount} 個錯誤");
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"錯誤: {error.Message}");
    }
    return;
}

// 建立用於完整性驗證的校驗和
var checksum = graphState.CreateChecksum();
Console.WriteLine($"狀態校驗和: {checksum}");
```

### Checkpoint 驗證

在還原期間驗證 checkpoints：

```csharp
// 驗證 checkpoint 完整性
var checkpointValidation = await checkpointManager.ValidateCheckpointAsync(checkpointId);
if (!checkpointValidation.IsValid)
{
    Console.WriteLine($"Checkpoint 驗證失敗: {checkpointValidation.ErrorMessage}");
    return;
}

// 檢查 checkpoint 中繼資料
Console.WriteLine($"Checkpoint 大小: {checkpointValidation.SizeInBytes:N0} 位元組");
Console.WriteLine($"已壓縮: {checkpointValidation.IsCompressed}");
Console.WriteLine($"校驗和: {checkpointValidation.Checksum}");
```

### 一致性驗證

確保還原狀態的一致性：

```csharp
// 驗證還原狀態的一致性
var consistencyResult = await checkpointManager.ValidateRestoredStateConsistencyAsync(
    restoredState,
    recoveryContext,
    cancellationToken
);

if (!consistencyResult.IsConsistent)
{
    Console.WriteLine($"一致性驗證失敗: 得分 {consistencyResult.ConsistencyScore:P1}");
    foreach (var issue in consistencyResult.Issues)
    {
        Console.WriteLine($"問題: {issue.Description} (嚴重性: {issue.Severity})");
    }
}
```

## Checkpointing Graph Executor

### 基本設定

設定 checkpointing 行為：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;

// 在核心中啟用 checkpoint 支援
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphMemory()  // checkpointing 需要
    .AddCheckpointSupport(options =>
    {
        options.EnableCompression = true;
        options.MaxCacheSize = 100;
    })
    .Build();

// 建立 checkpointing executor
var executorFactory = kernel.Services.GetRequiredService<ICheckpointingGraphExecutorFactory>();
var executor = executorFactory.CreateExecutor("my-graph", new CheckpointingOptions
{
    CheckpointInterval = 3,  // 每 3 個 Node 建立 checkpoint
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true
});
```

### 進階 Checkpointing 選項

微調 checkpointing 行為：

```csharp
var checkpointingOptions = new CheckpointingOptions
{
    // 基於間隔的 checkpointing
    CheckpointInterval = 5,  // 每 5 個 Node
    CheckpointTimeInterval = TimeSpan.FromMinutes(10),  // 或每 10 分鐘
    
    // 關鍵 checkpointing
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true,
    
    // 總是觸發 checkpoints 的關鍵 Node
    CriticalNodes = new HashSet<string> { "process", "validate", "output" },
    
    // 自動清理
    EnableAutoCleanup = true,
    FailOnCheckpointError = false,  // 即使 checkpointing 失敗也繼續執行
    
    // 保留策略
    RetentionPolicy = new CheckpointRetentionPolicy
    {
        MaxAge = TimeSpan.FromHours(24),
        MaxCheckpointsPerExecution = 50,
        MaxTotalStorageBytes = 100 * 1024 * 1024,  // 100MB
        KeepCriticalCheckpoints = true
    }
};
```

## 恢復和還原

### 手動恢復

從 checkpoints 實現手動恢復：

```csharp
try
{
    var result = await executor.ExecuteAsync(kernel, arguments);
    Console.WriteLine("執行成功完成");
}
catch (Exception ex)
{
    Console.WriteLine($"執行失敗: {ex.Message}");
    
    // 尋找可用的 checkpoints
    var executionId = executor.LastExecutionId ?? arguments.GetOrCreateGraphState().StateId;
    var checkpoints = await executor.GetExecutionCheckpointsAsync(executionId);
    
    if (checkpoints.Count > 0)
    {
        var latestCheckpoint = checkpoints.First();
        Console.WriteLine($"最新 checkpoint: {latestCheckpoint.CheckpointId}");
        
        // 從 checkpoint 繼續
        var recoveredResult = await executor.ResumeFromCheckpointAsync(
            latestCheckpoint.CheckpointId, 
            kernel
        );
        
        Console.WriteLine($"恢復成功: {recoveredResult.GetValue<object>()}");
    }
}
```

### 自動恢復

使用 `GraphRecoveryService` 啟用自動恢復：

```csharp
using SemanticKernel.Graph.Core;

var recoveryService = kernel.Services.GetRequiredService<IGraphRecoveryService>();

// 設定恢復選項
var recoveryOptions = new RecoveryOptions
{
    MaxRecoveryAttempts = 3,
    EnableAutomaticRecovery = true,
    RecoveryTimeout = TimeSpan.FromMinutes(5),
    PreferredRecoveryStrategy = RecoveryStrategy.CheckpointRestore
};

// 嘗試自動恢復
var recoveryResult = await recoveryService.AttemptRecoveryAsync(
    failureContext,
    kernel,
    recoveryOptions,
    cancellationToken
);

if (recoveryResult.IsSuccessful)
{
    Console.WriteLine($"使用 {recoveryResult.RecoveryStrategy} 恢復成功");
    Console.WriteLine($"恢復時間: {recoveryResult.RecoveryDuration}");
}
else
{
    Console.WriteLine($"恢復失敗: {recoveryResult.Reason}");
}
```

## 保留和清理策略

### 保留策略設定

設定自動清理行為：

```csharp
var retentionPolicy = new CheckpointRetentionPolicy
{
    MaxAge = TimeSpan.FromDays(7),           // 保留 7 天
    MaxCheckpointsPerExecution = 100,        // 每次執行最多 100 個
    MaxTotalStorageBytes = 1024 * 1024 * 1024,  // 總共 1GB 儲存空間
    KeepCriticalCheckpoints = true,          // 始終保留關鍵 checkpoints
    CriticalCheckpointInterval = 10          // 每 10 個常規的關鍵 checkpoint
};
```

### 清理服務設定

設定自動清理服務：

```csharp
using SemanticKernel.Graph.Core;

var cleanupOptions = new CheckpointCleanupOptions
{
    CleanupInterval = TimeSpan.FromHours(1),  // 每小時執行一次清理
    EnableAdvancedCleanup = true,
    MaxTotalStorageBytes = 1024 * 1024 * 1024,  // 1GB 限制
    AuditRetentionPeriod = TimeSpan.FromDays(30),  // 保留 30 天的審核日誌
    EnableDetailedLogging = true
};

// 使用保留策略設定清理
cleanupOptions.WithRetentionPolicy(
    maxAge: TimeSpan.FromDays(7),
    maxCheckpointsPerExecution: 100,
    maxTotalStorage: 1024 * 1024 * 1024
);
```

## 分散式備份和儲存

### 備份設定

為關鍵 checkpoints 啟用分散式備份：

```csharp
var backupOptions = new CheckpointBackupOptions
{
    EnableDistributedBackup = true,
    BackupLocations = new[]
    {
        "https://backup1.example.com/checkpoints",
        "https://backup2.example.com/checkpoints"
    },
    BackupInterval = TimeSpan.FromMinutes(30),
    BackupRetentionPeriod = TimeSpan.FromDays(90),
    EnableCompression = true,
    EnableEncryption = false  // 對敏感資料啟用
};

// 使用備份設定 checkpointing
var checkpointingOptions = new CheckpointingOptions
{
    EnableDistributedBackup = true,
    BackupOptions = backupOptions
};
```

### 備份操作

管理備份操作：

```csharp
var checkpointManager = kernel.Services.GetRequiredService<ICheckpointManager>();

// 建立關鍵 checkpoint 的備份
await checkpointManager.CreateBackupAsync(checkpointId, backupOptions);

// 列出備份位置
var backupLocations = await checkpointManager.GetBackupLocationsAsync(checkpointId);

// 如果主要位置已損毀，從備份還原
var backupCheckpoint = await checkpointManager.RestoreFromBackupAsync(checkpointId, backupLocation);
```

## 監視和可觀測性

### Checkpoint 統計資訊

監視 checkpoint 效能和使用情況：

```csharp
// 取得 checkpoint 統計資訊
var stats = await checkpointManager.GetStatisticsAsync();

Console.WriteLine($"Checkpoints 總數: {stats.TotalCheckpoints}");
Console.WriteLine($"使用的總儲存空間: {stats.TotalStorageBytes / 1024 / 1024:F1} MB");
Console.WriteLine($"平均 checkpoint 大小: {stats.AverageCheckpointSizeBytes / 1024:F1} KB");
Console.WriteLine($"壓縮比: {stats.AverageCompressionRatio:P1}");
Console.WriteLine($"快取命中率: {stats.CacheHitRate:P1}");
```

### 效能監視

監視 checkpointing 效能：

```csharp
// 取得具有效能資料的執行 checkpoints
var checkpoints = await executor.GetExecutionCheckpointsAsync(executionId);

foreach (var checkpoint in checkpoints)
{
    Console.WriteLine($"Checkpoint: {checkpoint.CheckpointId}");
    Console.WriteLine($"  Node: {checkpoint.NodeId}");
    Console.WriteLine($"  大小: {checkpoint.SizeInBytes / 1024:F1} KB");
    Console.WriteLine($"  已壓縮: {checkpoint.IsCompressed}");
    Console.WriteLine($"  建立於: {checkpoint.CreatedAt:HH:mm:ss}");
    Console.WriteLine($"  序列號: {checkpoint.SequenceNumber}");
}
```

## 進階模式

### 條件式 Checkpointing

根據商業邏輯建立 checkpoints：

```csharp
public class ConditionalCheckpointNode : IGraphNode
{
    public async Task<FunctionResult> ExecuteAsync(GraphState state)
    {
        // 檢查是否需要 checkpoint
        if (ShouldCreateCheckpoint(state))
        {
            var checkpointId = StateHelpers.SaveCheckpoint(state, "conditional-checkpoint");
            state.SetValue("lastCheckpointId", checkpointId);
            state.SetValue("checkpointReason", "business-rule-triggered");
        }
        
        // 繼續正常執行
        return await ProcessData(state);
    }
    
    private bool ShouldCreateCheckpoint(GraphState state)
    {
        var dataSize = state.GetValue<int>("dataSize", 0);
        var processingTime = state.GetValue<TimeSpan>("processingTime", TimeSpan.Zero);
        var errorCount = state.GetValue<int>("errorCount", 0);
        
        // 如果資料量大、處理速度慢或發生錯誤，建立 checkpoint
        return dataSize > 1000 || processingTime > TimeSpan.FromMinutes(5) || errorCount > 0;
    }
}
```

### Checkpoint 鏈結

為複雜工作流程建立連結 checkpoints：

```csharp
public class CheckpointChainingExample
{
    public async Task RunChainedCheckpointsAsync()
    {
        var kernel = CreateKernelWithCheckpointing();
        var executor = CreateCheckpointingExecutor(kernel);
        
        var state = new KernelArguments
        {
            ["workflow"] = "data-pipeline",
            ["stage"] = "initialization"
        };
        
        // 階段 1: 初始化
        state.SetValue("stage", "initialization");
        var stage1Checkpoint = StateHelpers.SaveCheckpoint(state.ToGraphState(), "stage1-init");
        
        // 階段 2: 資料處理
        state.SetValue("stage", "processing");
        state.SetValue("previousCheckpoint", stage1Checkpoint);
        var stage2Checkpoint = StateHelpers.SaveCheckpoint(state.ToGraphState(), "stage2-processing");
        
        // 階段 3: 驗證
        state.SetValue("stage", "validation");
        state.SetValue("previousCheckpoint", stage2Checkpoint);
        var stage3Checkpoint = StateHelpers.SaveCheckpoint(state.ToGraphState(), "stage3-validation");
        
        // 鏈結 checkpoints 以提供回復功能
        state.SetValue("checkpointChain", new[]
        {
            stage1Checkpoint,
            stage2Checkpoint,
            stage3Checkpoint
        });
        
        Console.WriteLine("Checkpoint 鏈建立成功");
    }
}
```

## 最佳實踐

### Checkpoint 設計原則

1. **策略配置**: 在邏輯邊界和昂貴操作後配置 checkpoints
2. **大小管理**: 監視 checkpoint 大小並對大型狀態使用壓縮
3. **保留計畫**: 根據商業需求設定保留策略
4. **錯誤處理**: 始終優雅地處理 checkpoint 失敗
5. **驗證**: 在 checkpoint 操作前後驗證狀態完整性

### 效能考量

1. **壓縮**: 啟用壓縮以提高儲存效率
2. **選擇性序列化**: 從 checkpoints 排除不必要的資料
3. **清理**: 設定自動清理以防止儲存空間過量
4. **快取**: 對經常訪問的 checkpoints 使用記憶體中快取
5. **背景操作**: 盡可能非同步執行 checkpoint 操作

### 恢復策略

1. **多個恢復點**: 為不同的恢復場景維護多個 checkpoints
2. **一致性驗證**: 始終驗證還原狀態的一致性
3. **回復功能**: 如果恢復失敗，實現回復到先前的 checkpoints
4. **監視**: 監視恢復成功率和效能
5. **文件**: 記錄恢復程序和預期結果

## 故障排除

### 常見問題

**Checkpoint 建立失敗**
```
無法建立 checkpoint: 狀態驗證失敗
```
**解決方案**: checkpointing 前驗證狀態完整性，並檢查非序列化物件。

**還原失敗**
```
無法還原 checkpoint: 校驗和不符
```
**解決方案**: 檢查資料損毀並驗證 checkpoint 完整性。

**儲存配額已超出**
```
Checkpoint 儲存配額已超出: 已達 1GB 限制
```
**解決方案**: 設定保留策略並啟用自動清理。

**版本相容性問題**
```
狀態版本 1.0.0 與目前版本 1.1.0 不相容
```
**解決方案**: 使用狀態遷移或更新工作流程以處理版本差異。

**恢復效能問題**
```
恢復耗時過長: 已耗時 5 分鐘
```
**解決方案**: 最佳化 checkpoint 大小、使用壓縮並設定適當的保留策略。

## 另請參閱

* [狀態管理](state.md) - 核心狀態管理概念
* [Checkpointing 快速入門](../checkpointing-quickstart.md) - checkpointing 簡介
* [執行模型](execution-model.md) - 執行如何流經 Graphs
* [Graph 恢復服務](../api/graph-recovery-service.md) - 恢復操作的 API 參考
* [Checkpointing 範例](../examples/checkpointing-examples.md) - 實用 checkpointing 範例
