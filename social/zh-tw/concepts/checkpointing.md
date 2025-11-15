# 檢查點與恢復

檢查點和恢復是 SemanticKernel.Graph 中的必要功能，可以實現容錯、執行恢復和狀態持久化。本指南解釋如何使用 `StateHelpers`、管理狀態版本、實現壓縮、確保完整性以及配置恢復策略。

## 您將學到

* 如何使用 `StateHelpers` 保存和恢復圖表執行狀態
* 管理狀態版本和跨不同版本的兼容性
* 實現壓縮以進行有效的存儲和傳輸
* 在檢查點操作期間確保數據完整性和驗證
* 配置恢復策略和自動清理
* 使用自動恢復構建容錯工作流

## 概念和技術

**檢查點**：在特定點保存圖表執行當前狀態的過程，使能夠從任何保存的狀態恢復和繼續執行。

**狀態持久化**：`StateHelpers` 提供使用壓縮和完整性驗證序列化和反序列化 `GraphState` 對象的實用程序。

**恢復機制**：從檢查點進行自動和手動恢復，具有一致性驗證和風險評估。

**狀態版本控制**：語義版本控制系統，確保兼容性並支持不同狀態格式之間的遷移。

**壓縮和完整性**：內置壓縮以實現存儲效率，以及校驗和驗證以確保數據完整性。

## 先決條件

* 已完成 [狀態管理](state.md) 指南
* 對 `GraphState` 和 `KernelArguments` 有基本了解
* 配置了圖表內存服務（檢查點所需）
* 在您的內核中啟用了檢查點支持

## 核心檢查點組件

### StateHelpers：核心檢查點實用程序

`StateHelpers` 為所有檢查點操作提供基礎：

```csharp
using SemanticKernel.Graph.State;

// 保存狀態到檢查點
var checkpointId = StateHelpers.CreateCheckpoint(graphState, "my-checkpoint");

// 從檢查點恢復狀態
// 注意：RestoreCheckpoint 期望檢查點存儲在相同的
// 狀態的元數據中（CreateCheckpoint 在提供的狀態上存儲檢查點條目）。
var restoredState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);

// 序列化狀態以進行存儲
var serializedState = StateHelpers.SerializeState(graphState);

// 從存儲反序列化狀態
var deserializedState = StateHelpers.DeserializeState(serializedState);
```

### CheckpointManager：集中式檢查點管理

`CheckpointManager` 處理存儲、檢索和生命週期管理：

```csharp
using SemanticKernel.Graph.Core;

var checkpointManager = kernel.Services.GetRequiredService<ICheckpointManager>();

// 創建新檢查點
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

// 檢索檢查點
var retrievedCheckpoint = await checkpointManager.GetCheckpointAsync(checkpointId);

// 列出執行的檢查點
var checkpoints = await checkpointManager.ListCheckpointsAsync("exec-123", limit: 10);
```

## 狀態版本控制和兼容性

### StateVersion：語義版本控制

`StateVersion` 確保跨不同版本的兼容性：

```csharp
using SemanticKernel.Graph.State;

// 當前版本信息
var currentVersion = StateVersion.Current;           // 例如 1.1.0
var minSupported = StateVersion.MinimumSupported;    // 例如 1.0.0

// 檢查版本兼容性
var stateVersion = graphState.Version;
var isCompatible = stateVersion.IsCompatibleWith(StateVersion.Current);
var requiresMigration = stateVersion.RequiresMigration; // 當舊於當前版本時需要遷移

// 版本比較和解析
if (StateVersion.TryParse("1.2.3", out var version))
{
    if (version < StateVersion.Current)
    {
        Console.WriteLine("狀態版本舊於當前版本");
    }
}
else
{
    Console.WriteLine("無效的版本字符串");
}
```

### 版本遷移

自動遷移處理狀態格式更改：

```csharp
// 在反序列化期間，可能需要進行遷移。使用 StateMigrationManager
// 在反序列化之前將序列化狀態遷移到當前版本。
if (StateMigrationManager.IsMigrationNeeded(StateVersion.Parse("1.0.0")))
{
    var migratedJson = StateMigrationManager.MigrateToCurrentVersion(serializedData, StateVersion.Parse("1.0.0"));
    var state = JsonSerializer.Deserialize<GraphState>(migratedJson);
    if (state != null)
    {
        Console.WriteLine($"反序列化的遷移狀態版本：{state.Version}");
    }
}
```

## 狀態壓縮和存儲

### 壓縮選項

配置壓縮以提高存儲效率：

```csharp
// 帶壓縮的序列化選項。使用 GraphState.Serialize 方法
// 它接受 SerializationOptions 實例。
var options = new SerializationOptions
{
    EnableCompression = true,           // 啟用壓縮
    CompressionThreshold = 1024,        // 如果 > 1KB 則壓縮
    IncludeMetadata = true,             // 包含狀態元數據
    IncludeExecutionHistory = false,    // 排除執行歷史以進行存儲
    ValidateIntegrity = true            // 序列化前驗證
};

var compressedState = graphState.Serialize(options);
```

### 存儲優化

通過選擇性序列化優化存儲：

```csharp
// 最小存儲選項
var storageOptions = new SerializationOptions
{
    EnableCompression = true,
    IncludeMetadata = false,            // 排除存儲的元數據
    IncludeExecutionHistory = false,    // 排除執行歷史
    ValidateIntegrity = true
};

// 用於調試的完整狀態選項
var debugOptions = new SerializationOptions
{
    EnableCompression = false,          // 不壓縮以便調試
    IncludeMetadata = true,             // 包含所有元數據
    IncludeExecutionHistory = true,     // 包含執行歷史
    Indented = true                     // 人類可讀格式
};
```

## 數據完整性和驗證

### 完整性驗證

確保檢查點數據完整性：

```csharp
// 檢查點前驗證狀態
var validationResult = graphState.ValidateIntegrity();
if (!validationResult.IsValid)
{
    Console.WriteLine($"狀態驗證失敗：{validationResult.ErrorCount} 個錯誤");
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"錯誤：{error.Message}");
    }
    return;
}

// 為完整性驗證創建校驗和
var checksum = graphState.CreateChecksum();
Console.WriteLine($"狀態校驗和：{checksum}");
```

### 檢查點驗證

在恢復期間驗證檢查點：

```csharp
// 驗證檢查點完整性
var checkpointValidation = await checkpointManager.ValidateCheckpointAsync(checkpointId);
if (!checkpointValidation.IsValid)
{
    Console.WriteLine($"檢查點驗證失敗：{checkpointValidation.ErrorMessage}");
    return;
}

// 檢查檢查點元數據
Console.WriteLine($"檢查點大小：{checkpointValidation.SizeInBytes:N0} 字節");
Console.WriteLine($"已壓縮：{checkpointValidation.IsCompressed}");
Console.WriteLine($"校驗和：{checkpointValidation.Checksum}");
```

### 一致性驗證

確保恢復狀態的一致性：

```csharp
// 驗證恢復狀態的一致性
var consistencyResult = await checkpointManager.ValidateRestoredStateConsistencyAsync(
    restoredState,
    recoveryContext,
    cancellationToken
);

if (!consistencyResult.IsConsistent)
{
    Console.WriteLine($"一致性驗證失敗：分數 {consistencyResult.ConsistencyScore:P1}");
    foreach (var issue in consistencyResult.Issues)
    {
        Console.WriteLine($"問題：{issue.Description}（嚴重程度：{issue.Severity}）");
    }
}
```

## 檢查點圖表執行器

### 基本配置

配置檢查點行為：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;

// 在內核中啟用檢查點支持
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphMemory()  // 檢查點所需
    .AddCheckpointSupport(options =>
    {
        options.EnableCompression = true;
        options.MaxCacheSize = 100;
    })
    .Build();

// 創建檢查點執行器
var executorFactory = kernel.Services.GetRequiredService<ICheckpointingGraphExecutorFactory>();
var executor = executorFactory.CreateExecutor("my-graph", new CheckpointingOptions
{
    CheckpointInterval = 3,  // 每 3 個節點創建一個檢查點
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true
});
```

### 高級檢查點選項

微調檢查點行為：

```csharp
var checkpointingOptions = new CheckpointingOptions
{
    // 基於間隔的檢查點
    CheckpointInterval = 5,  // 每 5 個節點
    CheckpointTimeInterval = TimeSpan.FromMinutes(10),  // 或每 10 分鐘
    
    // 關鍵檢查點
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true,
    
    // 始終觸發檢查點的關鍵節點
    CriticalNodes = new HashSet<string> { "process", "validate", "output" },
    
    // 自動清理
    EnableAutoCleanup = true,
    FailOnCheckpointError = false,  // 即使檢查點失敗也繼續執行
    
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

實現從檢查點的手動恢復：

```csharp
try
{
    var result = await executor.ExecuteAsync(kernel, arguments);
    Console.WriteLine("執行成功完成");
}
catch (Exception ex)
{
    Console.WriteLine($"執行失敗：{ex.Message}");
    
    // 查找可用的檢查點
    var executionId = executor.LastExecutionId ?? arguments.GetOrCreateGraphState().StateId;
    var checkpoints = await executor.GetExecutionCheckpointsAsync(executionId);
    
    if (checkpoints.Count > 0)
    {
        var latestCheckpoint = checkpoints.First();
        Console.WriteLine($"最新檢查點：{latestCheckpoint.CheckpointId}");
        
        // 從檢查點恢復
        var recoveredResult = await executor.ResumeFromCheckpointAsync(
            latestCheckpoint.CheckpointId, 
            kernel
        );
        
        Console.WriteLine($"恢復成功：{recoveredResult.GetValue<object>()}");
    }
}
```

### 自動恢復

使用 `GraphRecoveryService` 啟用自動恢復：

```csharp
using SemanticKernel.Graph.Core;

var recoveryService = kernel.Services.GetRequiredService<IGraphRecoveryService>();

// 配置恢復選項
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
    Console.WriteLine($"恢復時間：{recoveryResult.RecoveryDuration}");
}
else
{
    Console.WriteLine($"恢復失敗：{recoveryResult.Reason}");
}
```

## 保留和清理策略

### 保留策略配置

配置自動清理行為：

```csharp
var retentionPolicy = new CheckpointRetentionPolicy
{
    MaxAge = TimeSpan.FromDays(7),           // 保留 7 天
    MaxCheckpointsPerExecution = 100,        // 每次執行最多 100 個
    MaxTotalStorageBytes = 1024 * 1024 * 1024,  // 1GB 總存儲
    KeepCriticalCheckpoints = true,          // 始終保留關鍵檢查點
    CriticalCheckpointInterval = 10          // 每 10 個常規檢查點中有一個關鍵檢查點
};
```

### 清理服務配置

配置自動清理服務：

```csharp
using SemanticKernel.Graph.Core;

var cleanupOptions = new CheckpointCleanupOptions
{
    CleanupInterval = TimeSpan.FromHours(1),  // 每小時運行清理
    EnableAdvancedCleanup = true,
    MaxTotalStorageBytes = 1024 * 1024 * 1024,  // 1GB 限制
    AuditRetentionPeriod = TimeSpan.FromDays(30),  // 保留 30 天的審計日誌
    EnableDetailedLogging = true
};

// 使用保留策略配置清理
cleanupOptions.WithRetentionPolicy(
    maxAge: TimeSpan.FromDays(7),
    maxCheckpointsPerExecution: 100,
    maxTotalStorage: 1024 * 1024 * 1024
);
```

## 分佈式備份和存儲

### 備份配置

為關鍵檢查點啟用分佈式備份：

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
    EnableEncryption = false  // 對敏感數據啟用加密
};

// 使用備份配置檢查點
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

// 創建關鍵檢查點的備份
await checkpointManager.CreateBackupAsync(checkpointId, backupOptions);

// 列出備份位置
var backupLocations = await checkpointManager.GetBackupLocationsAsync(checkpointId);

// 如果主備份損壞，從備份恢復
var backupCheckpoint = await checkpointManager.RestoreFromBackupAsync(checkpointId, backupLocation);
```

## 監視和可觀測性

### 檢查點統計

監視檢查點性能和使用情況：

```csharp
// 獲取檢查點統計
var stats = await checkpointManager.GetStatisticsAsync();

Console.WriteLine($"總檢查點數：{stats.TotalCheckpoints}");
Console.WriteLine($"使用的總存儲：{stats.TotalStorageBytes / 1024 / 1024:F1} MB");
Console.WriteLine($"平均檢查點大小：{stats.AverageCheckpointSizeBytes / 1024:F1} KB");
Console.WriteLine($"壓縮比：{stats.AverageCompressionRatio:P1}");
Console.WriteLine($"緩存命中率：{stats.CacheHitRate:P1}");
```

### 性能監視

監視檢查點性能：

```csharp
// 獲取具有性能數據的執行檢查點
var checkpoints = await executor.GetExecutionCheckpointsAsync(executionId);

foreach (var checkpoint in checkpoints)
{
    Console.WriteLine($"檢查點：{checkpoint.CheckpointId}");
    Console.WriteLine($"  節點：{checkpoint.NodeId}");
    Console.WriteLine($"  大小：{checkpoint.SizeInBytes / 1024:F1} KB");
    Console.WriteLine($"  已壓縮：{checkpoint.IsCompressed}");
    Console.WriteLine($"  建立時間：{checkpoint.CreatedAt:HH:mm:ss}");
    Console.WriteLine($"  序列號：{checkpoint.SequenceNumber}");
}
```

## 高級模式

### 條件檢查點

基於業務邏輯創建檢查點：

```csharp
public class ConditionalCheckpointNode : IGraphNode
{
    public async Task<FunctionResult> ExecuteAsync(GraphState state)
    {
        // 檢查是否需要檢查點
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
        
        // 如果數據很大、處理很慢或發生錯誤，則創建檢查點
        return dataSize > 1000 || processingTime > TimeSpan.FromMinutes(5) || errorCount > 0;
    }
}
```

### 檢查點鏈接

為複雜工作流創建鏈接的檢查點：

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
        
        // 階段 1：初始化
        state.SetValue("stage", "initialization");
        var stage1Checkpoint = StateHelpers.SaveCheckpoint(state.ToGraphState(), "stage1-init");
        
        // 階段 2：數據處理
        state.SetValue("stage", "processing");
        state.SetValue("previousCheckpoint", stage1Checkpoint);
        var stage2Checkpoint = StateHelpers.SaveCheckpoint(state.ToGraphState(), "stage2-processing");
        
        // 階段 3：驗證
        state.SetValue("stage", "validation");
        state.SetValue("previousCheckpoint", stage2Checkpoint);
        var stage3Checkpoint = StateHelpers.SaveCheckpoint(state.ToGraphState(), "stage3-validation");
        
        // 鏈接檢查點以實現回滾功能
        state.SetValue("checkpointChain", new[]
        {
            stage1Checkpoint,
            stage2Checkpoint,
            stage3Checkpoint
        });
        
        Console.WriteLine("檢查點鏈創建成功");
    }
}
```

## 最佳實踐

### 檢查點設計原則

1. **戰略位置**：在邏輯邊界和昂貴操作後放置檢查點
2. **大小管理**：監視檢查點大小並對大型狀態使用壓縮
3. **保留計劃**：根據業務需求配置保留策略
4. **錯誤處理**：始終優雅地處理檢查點失敗
5. **驗證**：在檢查點操作前後驗證狀態完整性

### 性能考慮

1. **壓縮**：啟用壓縮以提高存儲效率
2. **選擇性序列化**：從檢查點排除不必要的數據
3. **清理**：配置自動清理以防止存儲膨脹
4. **緩存**：使用內存中緩存來處理頻繁訪問的檢查點
5. **後台操作**：盡可能異步執行檢查點操作

### 恢復策略

1. **多個恢復點**：為不同的恢復場景維護多個檢查點
2. **一致性驗證**：始終驗證恢復狀態的一致性
3. **回滾功能**：如果恢復失敗，實現回滾到先前的檢查點
4. **監視**：監視恢復成功率和性能
5. **文檔**：記錄恢復程序和預期結果

## 故障排除

### 常見問題

**檢查點創建失敗**
```
Failed to create checkpoint: State validation failed
```
**解決方案**：在檢查點前驗證狀態完整性，並檢查不可序列化的對象。

**恢復失敗**
```
Failed to restore checkpoint: Checksum mismatch
```
**解決方案**：檢查數據損壞並驗證檢查點完整性。

**存儲配額超出**
```
Checkpoint storage quota exceeded: 1GB limit reached
```
**解決方案**：配置保留策略並啟用自動清理。

**版本兼容性問題**
```
State version 1.0.0 is not compatible with current version 1.1.0
```
**解決方案**：使用狀態遷移或更新工作流以處理版本差異。

**恢復性能問題**
```
Recovery taking too long: 5 minutes elapsed
```
**解決方案**：優化檢查點大小、使用壓縮並配置適當的保留策略。

## 參見

* [狀態管理](state.md) - 核心狀態管理概念
* [檢查點快速入門](../checkpointing-quickstart.md) - 檢查點的快速介紹
* [執行模型](execution-model.md) - 執行如何流過圖表
* [圖表恢復服務](../api/graph-recovery-service.md) - 恢復操作的 API 參考
* [檢查點示例](../examples/checkpointing-examples.md) - 實用的檢查點示例
