# 檢查點範例

此範例示範使用 Semantic Kernel Graph 檢查點系統進行執行狀態持久化和恢復。它展示如何保存、還原和管理執行狀態以實現彈性工作流程。

## 目標

學習如何在基於圖的工作流程中實現檢查點，以便：
* 在關鍵點保存執行狀態
* 從先前的檢查點還原工作流程
* 實現自動檢查點管理
* 處理分散式檢查點儲存
* 監控和優化檢查點效能

## 先決條件

* **.NET 8.0** 或更高版本
* **OpenAI API 金鑰**在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 對[圖的概念](../concepts/graph-concepts.md)和[狀態管理](../concepts/state.md)的基本理解

## 主要元件

### 概念和技術

* **檢查點**：在特定點保存執行狀態以供稍後還原
* **狀態序列化**：將圖狀態轉換為持久儲存格式
* **恢復**：從保存的檢查點還原工作流程執行
* **分散式儲存**：跨多個儲存位置管理檢查點

### 核心類別

* `CheckpointManager`：管理檢查點的建立、儲存和檢索
* `CheckpointingGraphExecutor`：具有內建檢查點支援的執行器
* `StateHelpers`：狀態序列化和驗證的工具
* `CheckpointOptions`：檢查點行為的配置選項

## 執行範例

### 開始使用

此範例示範使用 Semantic Kernel Graph 套件進行檢查點和狀態持久化。下面的程式碼片段展示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本檢查點系統

此範例示範基本的檢查點建立和還原。

```csharp
// 建立具有檢查點支援的核心
var kernel = CreateKernel();

// 建立檢查點執行器
var checkpointingExecutor = new CheckpointingGraphExecutor(
    "CheckpointingExample",
    "基本檢查點演示",
    logger);

// 配置檢查點選項
var checkpointOptions = new CheckpointOptions
{
    EnableAutoCheckpointing = true,
    CheckpointInterval = 2, // 每 2 個節點建立一個檢查點
    EnableCompression = true,
    MaxCheckpointSize = 1024 * 1024, // 1MB
    StorageProvider = new FileSystemStorageProvider("./checkpoints")
};

checkpointingExecutor.ConfigureCheckpointing(checkpointOptions);

// 建立簡單工作流程
var workflow = CreateCheckpointingWorkflow();
checkpointingExecutor.AddGraph(workflow);

// 使用檢查點執行
var arguments = new KernelArguments
{
    ["input_data"] = "用於處理的範例資料",
    ["checkpoint_id"] = Guid.NewGuid().ToString()
};

Console.WriteLine("🚀 開始執行具有檢查點的工作流程...");
var result = await checkpointingExecutor.ExecuteAsync(kernel, arguments);

Console.WriteLine($"✅ 工作流程完成。最終結果：{result.GetValue<string>()}");
Console.WriteLine($"📊 建立的檢查點：{checkpointingExecutor.CheckpointManager.GetCheckpointCount()}");
```

### 2. 檢查點恢復範例

示範如何從檢查點還原工作流程執行。

```csharp
// 模擬工作流程中斷和恢復
Console.WriteLine("\n🔄 模擬工作流程中斷...");

// 建立長時間運行的工作流程
var longWorkflow = CreateLongRunningWorkflow();
var recoveryExecutor = new CheckpointingGraphExecutor(
    "RecoveryExample",
    "檢查點恢復演示",
    logger);

recoveryExecutor.ConfigureCheckpointing(new CheckpointOptions
{
    EnableAutoCheckpointing = true,
    CheckpointInterval = 1, // 在每個節點後建立檢查點
    EnableCompression = true,
    StorageProvider = new FileSystemStorageProvider("./recovery-checkpoints")
});

recoveryExecutor.AddGraph(longWorkflow);

// 開始執行
var recoveryArgs = new KernelArguments
{
    ["workflow_id"] = "recovery_001",
    ["data"] = "用於處理的大型資料集"
};

try
{
    Console.WriteLine("🚀 開始長時間工作流程...");
    var recoveryResult = await recoveryExecutor.ExecuteAsync(kernel, recoveryArgs);
    Console.WriteLine($"✅ 工作流程完成：{recoveryResult.GetValue<string>()}");
}
catch (OperationCanceledException)
{
    Console.WriteLine("⏸️ 工作流程已中斷。檢查點已保存。");
    
    // 模擬恢復
    Console.WriteLine("🔄 從檢查點恢復...");
    var recoveredResult = await recoveryExecutor.RecoverFromLatestCheckpointAsync(
        kernel, recoveryArgs);
    
    Console.WriteLine($"✅ 恢復成功：{recoveredResult.GetValue<string>()}");
}
```

### 3. 分散式備份範例

展示如何為高可用性實現分散式檢查點儲存。

```csharp
// 建立分散式儲存提供者
var localStorage = new FileSystemStorageProvider("./local-checkpoints");
var cloudStorage = new AzureBlobStorageProvider(connectionString, containerName);
var distributedStorage = new DistributedStorageProvider(new[]
{
    localStorage,
    cloudStorage
});

// 配置分散式檢查點
var distributedExecutor = new CheckpointingGraphExecutor(
    "DistributedExample",
    "分散式檢查點演示",
    logger);

distributedExecutor.ConfigureCheckpointing(new CheckpointOptions
{
    EnableAutoCheckpointing = true,
    CheckpointInterval = 3,
    EnableCompression = true,
    StorageProvider = distributedStorage,
    ReplicationFactor = 2, // 儲存在 2 個位置
    EnableAsyncBackup = true
});

// 建立並執行工作流程
var distributedWorkflow = CreateDistributedWorkflow();
distributedExecutor.AddGraph(distributedWorkflow);

var distributedArgs = new KernelArguments
{
    ["workflow_id"] = "distributed_001",
    ["data"] = "需要備份的關鍵資料"
};

Console.WriteLine("🚀 開始分散式檢查點工作流程...");
var distributedResult = await distributedExecutor.ExecuteAsync(kernel, distributedArgs);

Console.WriteLine($"✅ 分散式工作流程完成：{distributedResult.GetValue<string>()}");
Console.WriteLine($"📊 檢查點儲存在 {distributedStorage.GetActiveProviders().Count()} 個位置");
```

### 4. 監控和分析範例

示範檢查點監控和效能分析。

```csharp
// 建立啟用監控的執行器
var monitoringExecutor = new CheckpointingGraphExecutor(
    "MonitoringExample",
    "檢查點監控演示",
    logger);

monitoringExecutor.ConfigureCheckpointing(new CheckpointOptions
{
    EnableAutoCheckpointing = true,
    CheckpointInterval = 2,
    EnableCompression = true,
    StorageProvider = new FileSystemStorageProvider("./monitoring-checkpoints"),
    EnableMetrics = true,
    EnableDetailedLogging = true
});

// 訂閱檢查點事件
monitoringExecutor.CheckpointManager.CheckpointCreated += (sender, e) =>
{
    Console.WriteLine($"📝 檢查點已建立：{e.CheckpointId}，時間為 {e.Timestamp}");
    Console.WriteLine($"   大小：{e.SizeBytes} 位元組，壓縮率：{e.CompressionRatio:P1}");
};

monitoringExecutor.CheckpointManager.CheckpointRestored += (sender, e) =>
{
    Console.WriteLine($"🔄 檢查點已還原：{e.CheckpointId}，耗時 {e.RestoreTimeMs}ms");
};

// 執行具有監控的工作流程
var monitoringWorkflow = CreateMonitoringWorkflow();
monitoringExecutor.AddGraph(monitoringWorkflow);

var monitoringArgs = new KernelArguments
{
    ["workflow_id"] = "monitoring_001",
    ["data"] = "用於監控演示的資料"
};

Console.WriteLine("🚀 開始監控工作流程...");
var monitoringResult = await monitoringExecutor.ExecuteAsync(kernel, monitoringArgs);

// 顯示檢查點分析
var analytics = monitoringExecutor.CheckpointManager.GetAnalytics();
Console.WriteLine("\n📊 檢查點分析：");
Console.WriteLine($"   總檢查點數：{analytics.TotalCheckpoints}");
Console.WriteLine($"   平均大小：{analytics.AverageSizeBytes} 位元組");
Console.WriteLine($"   壓縮率：{analytics.AverageCompressionRatio:P1}");
Console.WriteLine($"   儲存效率：{analytics.StorageEfficiency:P1}");
```

## 預期輸出

### 基本檢查點範例

```
🚀 開始執行具有檢查點的工作流程...
📝 在節點後建立檢查點：data-processor
📝 在節點後建立檢查點：data-validator
📝 在節點後建立檢查點：result-generator
✅ 工作流程完成。最終結果：經過驗證的已處理資料
📊 建立的檢查點：3
📁 檢查點儲存在：./checkpoints/
   - checkpoint_001.json (2.3 KB)
   - checkpoint_002.json (2.1 KB)
   - checkpoint_003.json (1.8 KB)
```

### 恢復範例

```
🚀 開始長時間工作流程...
📝 在節點後建立檢查點：data-loader
📝 在節點後建立檢查點：data-processor
⏸️ 工作流程已中斷。檢查點已保存。

🔄 從檢查點恢復...
📝 從檢查點恢復：checkpoint_002.json
🔄 從節點繼續執行：data-validator
📝 在節點後建立檢查點：data-validator
📝 在節點後建立檢查點：result-generator
✅ 恢復成功：使用恢復功能處理的大型資料集
📊 恢復時間：1.2 秒
📊 使用的檢查點：1
```

### 分散式備份範例

```
🚀 開始分散式檢查點工作流程...
📝 在節點後建立檢查點：data-processor
   📤 備份到本機儲存
   📤 備份到雲端儲存
📝 在節點後建立檢查點：data-validator
   📤 備份到本機儲存
   📤 備份到雲端儲存
📝 在節點後建立檢查點：result-generator
   📤 備份到本機儲存
   📤 備份到雲端儲存

✅ 分散式工作流程完成：備份的關鍵資料已處理
📊 檢查點儲存在 2 個位置
📁 本機儲存：3 個檢查點
☁️ 雲端儲存：3 個檢查點
🔒 複製因子：2x
```

### 監控範例

```
🚀 開始監控工作流程...
📝 檢查點已建立：cp_001，時間為 2025-08-15 10:30:15
   大小：2048 位元組，壓縮率：75.2%
📝 檢查點已建立：cp_002，時間為 2025-08-15 10:30:18
   大小：1920 位元組，壓縮率：78.1%
📝 檢查點已建立：cp_003，時間為 2025-08-15 10:30:21
   大小：1856 位元組，壓縮率：79.8%
🔄 檢查點已還原：cp_002，耗時 45ms

✅ 監控工作流程完成：使用監控處理的資料
📊 檢查點分析：
   總檢查點數：3
   平均大小：1941 位元組
   壓縮率：77.7%
   儲存效率：85.2%
```

## 配置選項

### 檢查點選項

```csharp
var checkpointOptions = new CheckpointOptions
{
    EnableAutoCheckpointing = true,           // 自動檢查點
    CheckpointInterval = 2,                   // 每 N 個節點建立檢查點
    EnableCompression = true,                 // 壓縮檢查點資料
    MaxCheckpointSize = 1024 * 1024,         // 最大檢查點大小
    StorageProvider = storageProvider,        // 儲存提供者
    ReplicationFactor = 2,                   // 儲存位置數
    EnableAsyncBackup = true,                // 非同步備份
    EnableMetrics = true,                    // 啟用效能指標
    EnableDetailedLogging = true,            // 詳細記錄
    CompressionLevel = CompressionLevel.Optimal, // 壓縮等級
    EncryptionEnabled = false,               // 啟用加密
    RetentionPolicy = new RetentionPolicy    // 檢查點保留策略
    {
        MaxCheckpoints = 100,
        MaxAge = TimeSpan.FromDays(30),
        EnableAutoCleanup = true
    }
};
```

### 儲存提供者配置

```csharp
// 檔案系統儲存
var fileStorage = new FileSystemStorageProvider("./checkpoints")
{
    MaxFileSize = 10 * 1024 * 1024,         // 10MB 最大檔案大小
    EnableFileRotation = true,               // 輪轉舊檔案
    CompressionEnabled = true,               // 啟用檔案壓縮
    EncryptionEnabled = false                // 停用加密
};

// Azure Blob 儲存
var azureStorage = new AzureBlobStorageProvider(connectionString, containerName)
{
    BlobTier = BlobTier.Cool,                // 使用冷層以節省成本
    EnableSoftDelete = true,                 // 啟用虛刪除
    RetentionDays = 90,                      // 90 天保留期
    EnableVersioning = true                  // 啟用 Blob 版本控制
};

// 分散式儲存
var distributedStorage = new DistributedStorageProvider(new[]
{
    fileStorage,
    azureStorage
})
{
    PrimaryProvider = fileStorage,            // 主要儲存
    FailoverEnabled = true,                  // 啟用容錯移轉
    ConsistencyLevel = ConsistencyLevel.Eventual, // 最終一致性
    RetryPolicy = new ExponentialBackoffRetryPolicy(3, TimeSpan.FromSeconds(1))
};
```

## 疑難排解

### 常見問題

#### 檢查點建立失敗
```bash
# 問題：檢查點建立失敗
# 解決方案：檢查儲存權限和磁碟空間
EnableDetailedLogging = true;
StorageProvider = new FileSystemStorageProvider("./checkpoints");
```

#### 檢查點操作緩慢
```bash
# 問題：檢查點操作速度慢
# 解決方案：優化壓縮和儲存
CompressionLevel = CompressionLevel.Fastest;
EnableAsyncBackup = true;
StorageProvider = new FastStorageProvider();
```

#### 恢復失敗
```bash
# 問題：檢查點恢復失敗
# 解決方案：驗證檢查點完整性和儲存
EnableCheckpointValidation = true;
ValidateOnRestore = true;
```

### 偵錯模式

啟用詳細記錄以進行疑難排解：

```csharp
// 啟用偵錯記錄
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<CheckpointingExample>();

// 使用偵錯記錄配置執行器
var debugExecutor = new CheckpointingGraphExecutor(
    "DebugExample", "偵錯檢查點", logger);

debugExecutor.ConfigureCheckpointing(new CheckpointOptions
{
    EnableDetailedLogging = true,
    EnableMetrics = true,
    LogCheckpointOperations = true,
    LogStorageOperations = true
});
```

## 高級模式

### 自訂檢查點觸發器

```csharp
// 實現自訂檢查點觸發器
var customTrigger = new CustomCheckpointTrigger
{
    ShouldCheckpoint = (context) =>
    {
        // 在特定條件下建立檢查點
        var nodeId = context.CurrentNode?.NodeId;
        var executionStep = context.ExecutionStep;
        
        return nodeId == "critical-node" || 
               executionStep % 5 == 0 ||
               context.State.GetValue<int>("data_size") > 1000;
    }
};

checkpointingExecutor.CheckpointTrigger = customTrigger;
```

### 增量檢查點

```csharp
// 實現大型狀態的增量檢查點
var incrementalOptions = new IncrementalCheckpointOptions
{
    EnableIncrementalCheckpointing = true,
    IncrementThreshold = 1024 * 1024,        // 1MB 閾值
    DeltaCompression = true,                 // 壓縮差異
    MergeStrategy = MergeStrategy.Optimistic, // 樂觀合併
    ValidationStrategy = ValidationStrategy.Checksum // 校驗和驗證
};

checkpointingExecutor.ConfigureIncrementalCheckpointing(incrementalOptions);
```

### 檢查點協調

```csharp
// 跨多個工作流程協調檢查點
var orchestrator = new CheckpointOrchestrator
{
    GlobalCheckpointInterval = TimeSpan.FromMinutes(5),
    WorkflowDependencies = new Dictionary<string, string[]>
    {
        ["workflow_a"] = new[] { "workflow_b", "workflow_c" },
        ["workflow_b"] = new[] { "workflow_d" },
        ["workflow_c"] = new[] { "workflow_d" }
    },
    CheckpointStrategy = CheckpointStrategy.DependencyAware
};

orchestrator.RegisterWorkflow(checkpointingExecutor);
orchestrator.StartOrchestration();
```

## 相關範例

* [狀態管理](./state-management.md)：圖狀態和引數處理
* [串流執行](./streaming-execution.md)：即時執行監控
* [多代理](./multi-agent.md)：協調的多代理工作流程
* [圖指標](./graph-metrics.md)：效能監控和優化

## 另請參閱

* [檢查點概念](../concepts/checkpointing.md)：了解狀態持久化
* [狀態管理](../concepts/state.md)：圖狀態基礎
* [效能監控](../how-to/metrics-and-observability.md)：指標和優化
* [API 參考](../api/)：完整的 API 文件
