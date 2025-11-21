# 檢查點範例

此範例示範如何使用 Semantic Kernel Graph 檢查點系統進行執行狀態的持久化和復原。它展示了如何保存、復原和管理執行狀態以實現有韌性的工作流程。

## 目標

學習如何在基於圖表的工作流程中實現檢查點功能以：
* 在關鍵點保存執行狀態
* 從先前的檢查點復原工作流程
* 實現自動檢查點管理
* 處理分散式檢查點儲存
* 監控並優化檢查點效能

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph package** 已安裝
* 對 [Graph Concepts](../concepts/graph-concepts.md) 和 [State Management](../concepts/state.md) 的基本理解

## 關鍵元件

### 概念和技術

* **Checkpointing**: 在特定時間點保存執行狀態以供稍後復原
* **State Serialization**: 將圖表狀態轉換為持久儲存格式
* **Recovery**: 從已保存的檢查點復原工作流程執行
* **Distributed Storage**: 在多個儲存位置管理檢查點

### 核心類別

* `CheckpointManager`: 管理檢查點建立、儲存和檢索
* `CheckpointingGraphExecutor`: 具有內建檢查點支援的執行器
* `StateHelpers`: 用於狀態序列化和驗證的工具程式
* `CheckpointOptions`: 檢查點行為的配置選項

## 執行此範例

### 入門

此範例示範 Semantic Kernel Graph package 的檢查點和狀態持久化功能。以下程式碼片段展示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本檢查點系統

此範例示範基本的檢查點建立和復原。

```csharp
// Create kernel with checkpointing support
var kernel = CreateKernel();

// Create checkpointing executor
var checkpointingExecutor = new CheckpointingGraphExecutor(
    "CheckpointingExample",
    "Basic checkpointing demonstration",
    logger);

// Configure checkpoint options
var checkpointOptions = new CheckpointOptions
{
    EnableAutoCheckpointing = true,
    CheckpointInterval = 2, // Checkpoint every 2 nodes
    EnableCompression = true,
    MaxCheckpointSize = 1024 * 1024, // 1MB
    StorageProvider = new FileSystemStorageProvider("./checkpoints")
};

checkpointingExecutor.ConfigureCheckpointing(checkpointOptions);

// Create a simple workflow
var workflow = CreateCheckpointingWorkflow();
checkpointingExecutor.AddGraph(workflow);

// Execute with checkpointing
var arguments = new KernelArguments
{
    ["input_data"] = "Sample data for processing",
    ["checkpoint_id"] = Guid.NewGuid().ToString()
};

Console.WriteLine("🚀 Starting workflow execution with checkpointing...");
var result = await checkpointingExecutor.ExecuteAsync(kernel, arguments);

Console.WriteLine($"✅ Workflow completed. Final result: {result.GetValue<string>()}");
Console.WriteLine($"📊 Checkpoints created: {checkpointingExecutor.CheckpointManager.GetCheckpointCount()}");
```

### 2. 檢查點復原範例

示範如何從檢查點復原工作流程執行。

```csharp
// Simulate workflow interruption and recovery
Console.WriteLine("\n🔄 Simulating workflow interruption...");

// Create a long-running workflow
var longWorkflow = CreateLongRunningWorkflow();
var recoveryExecutor = new CheckpointingGraphExecutor(
    "RecoveryExample",
    "Checkpoint recovery demonstration",
    logger);

recoveryExecutor.ConfigureCheckpointing(new CheckpointOptions
{
    EnableAutoCheckpointing = true,
    CheckpointInterval = 1, // Checkpoint after each node
    EnableCompression = true,
    StorageProvider = new FileSystemStorageProvider("./recovery-checkpoints")
});

recoveryExecutor.AddGraph(longWorkflow);

// Start execution
var recoveryArgs = new KernelArguments
{
    ["workflow_id"] = "recovery_001",
    ["data"] = "Large dataset for processing"
};

try
{
    Console.WriteLine("🚀 Starting long workflow...");
    var recoveryResult = await recoveryExecutor.ExecuteAsync(kernel, recoveryArgs);
    Console.WriteLine($"✅ Workflow completed: {recoveryResult.GetValue<string>()}");
}
catch (OperationCanceledException)
{
    Console.WriteLine("⏸️ Workflow was interrupted. Checkpoints saved.");
    
    // Simulate recovery
    Console.WriteLine("🔄 Recovering from checkpoint...");
    var recoveredResult = await recoveryExecutor.RecoverFromLatestCheckpointAsync(
        kernel, recoveryArgs);
    
    Console.WriteLine($"✅ Recovery successful: {recoveredResult.GetValue<string>()}");
}
```

### 3. 分散式備份範例

展示如何實現分散式檢查點儲存以實現高可用性。

```csharp
// Create distributed storage providers
var localStorage = new FileSystemStorageProvider("./local-checkpoints");
var cloudStorage = new AzureBlobStorageProvider(connectionString, containerName);
var distributedStorage = new DistributedStorageProvider(new[]
{
    localStorage,
    cloudStorage
});

// Configure distributed checkpointing
var distributedExecutor = new CheckpointingGraphExecutor(
    "DistributedExample",
    "Distributed checkpointing demonstration",
    logger);

distributedExecutor.ConfigureCheckpointing(new CheckpointOptions
{
    EnableAutoCheckpointing = true,
    CheckpointInterval = 3,
    EnableCompression = true,
    StorageProvider = distributedStorage,
    ReplicationFactor = 2, // Store in 2 locations
    EnableAsyncBackup = true
});

// Create and execute workflow
var distributedWorkflow = CreateDistributedWorkflow();
distributedExecutor.AddGraph(distributedWorkflow);

var distributedArgs = new KernelArguments
{
    ["workflow_id"] = "distributed_001",
    ["data"] = "Critical data requiring backup"
};

Console.WriteLine("🚀 Starting distributed checkpointing workflow...");
var distributedResult = await distributedExecutor.ExecuteAsync(kernel, distributedArgs);

Console.WriteLine($"✅ Distributed workflow completed: {distributedResult.GetValue<string>()}");
Console.WriteLine($"📊 Checkpoints stored in {distributedStorage.GetActiveProviders().Count()} locations");
```

### 4. 監控和分析範例

示範檢查點監控和效能分析。

```csharp
// Create monitoring-enabled executor
var monitoringExecutor = new CheckpointingGraphExecutor(
    "MonitoringExample",
    "Checkpoint monitoring demonstration",
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

// Subscribe to checkpoint events
monitoringExecutor.CheckpointManager.CheckpointCreated += (sender, e) =>
{
    Console.WriteLine($"📝 Checkpoint created: {e.CheckpointId} at {e.Timestamp}");
    Console.WriteLine($"   Size: {e.SizeBytes} bytes, Compression: {e.CompressionRatio:P1}");
};

monitoringExecutor.CheckpointManager.CheckpointRestored += (sender, e) =>
{
    Console.WriteLine($"🔄 Checkpoint restored: {e.CheckpointId} in {e.RestoreTimeMs}ms");
};

// Execute workflow with monitoring
var monitoringWorkflow = CreateMonitoringWorkflow();
monitoringExecutor.AddGraph(monitoringWorkflow);

var monitoringArgs = new KernelArguments
{
    ["workflow_id"] = "monitoring_001",
    ["data"] = "Data for monitoring demonstration"
};

Console.WriteLine("🚀 Starting monitored workflow...");
var monitoringResult = await monitoringExecutor.ExecuteAsync(kernel, monitoringArgs);

// Display checkpoint analytics
var analytics = monitoringExecutor.CheckpointManager.GetAnalytics();
Console.WriteLine("\n📊 Checkpoint Analytics:");
Console.WriteLine($"   Total checkpoints: {analytics.TotalCheckpoints}");
Console.WriteLine($"   Average size: {analytics.AverageSizeBytes} bytes");
Console.WriteLine($"   Compression ratio: {analytics.AverageCompressionRatio:P1}");
Console.WriteLine($"   Storage efficiency: {analytics.StorageEfficiency:P1}");
```

## 預期輸出

### 基本檢查點範例

```
🚀 Starting workflow execution with checkpointing...
📝 Creating checkpoint after node: data-processor
📝 Creating checkpoint after node: data-validator
📝 Creating checkpoint after node: result-generator
✅ Workflow completed. Final result: Processed data with validation
📊 Checkpoints created: 3
📁 Checkpoints stored in: ./checkpoints/
   - checkpoint_001.json (2.3 KB)
   - checkpoint_002.json (2.1 KB)
   - checkpoint_003.json (1.8 KB)
```

### 復原範例

```
🚀 Starting long workflow...
📝 Creating checkpoint after node: data-loader
📝 Creating checkpoint after node: data-processor
⏸️ Workflow was interrupted. Checkpoints saved.

🔄 Recovering from checkpoint...
📝 Restoring from checkpoint: checkpoint_002.json
🔄 Resuming execution from node: data-validator
📝 Creating checkpoint after node: data-validator
📝 Creating checkpoint after node: result-generator
✅ Recovery successful: Processed large dataset with recovery
📊 Recovery time: 1.2 seconds
📊 Checkpoints used: 1
```

### 分散式備份範例

```
🚀 Starting distributed checkpointing workflow...
📝 Creating checkpoint after node: data-processor
   📤 Backing up to local storage
   📤 Backing up to cloud storage
📝 Creating checkpoint after node: data-validator
   📤 Backing up to local storage
   📤 Backing up to cloud storage
📝 Creating checkpoint after node: result-generator
   📤 Backing up to local storage
   📤 Backing up to cloud storage

✅ Distributed workflow completed: Critical data processed with backup
📊 Checkpoints stored in 2 locations
📁 Local storage: 3 checkpoints
☁️ Cloud storage: 3 checkpoints
🔒 Replication factor: 2x
```

### 監控範例

```
🚀 Starting monitored workflow...
📝 Checkpoint created: cp_001 at 2025-08-15 10:30:15
   Size: 2048 bytes, Compression: 75.2%
📝 Checkpoint created: cp_002 at 2025-08-15 10:30:18
   Size: 1920 bytes, Compression: 78.1%
📝 Checkpoint created: cp_003 at 2025-08-15 10:30:21
   Size: 1856 bytes, Compression: 79.8%
🔄 Checkpoint restored: cp_002 in 45ms

✅ Monitored workflow completed: Data processed with monitoring
📊 Checkpoint Analytics:
   Total checkpoints: 3
   Average size: 1941 bytes
   Compression ratio: 77.7%
   Storage efficiency: 85.2%
```

## 配置選項

### 檢查點選項

```csharp
var checkpointOptions = new CheckpointOptions
{
    EnableAutoCheckpointing = true,           // Automatic checkpointing
    CheckpointInterval = 2,                   // Checkpoint every N nodes
    EnableCompression = true,                 // Compress checkpoint data
    MaxCheckpointSize = 1024 * 1024,         // Maximum checkpoint size
    StorageProvider = storageProvider,        // Storage provider
    ReplicationFactor = 2,                   // Number of storage locations
    EnableAsyncBackup = true,                // Asynchronous backup
    EnableMetrics = true,                    // Enable performance metrics
    EnableDetailedLogging = true,            // Detailed logging
    CompressionLevel = CompressionLevel.Optimal, // Compression level
    EncryptionEnabled = false,               // Enable encryption
    RetentionPolicy = new RetentionPolicy    // Checkpoint retention
    {
        MaxCheckpoints = 100,
        MaxAge = TimeSpan.FromDays(30),
        EnableAutoCleanup = true
    }
};
```

### 儲存提供者配置

```csharp
// File system storage
var fileStorage = new FileSystemStorageProvider("./checkpoints")
{
    MaxFileSize = 10 * 1024 * 1024,         // 10MB max file size
    EnableFileRotation = true,               // Rotate old files
    CompressionEnabled = true,               // Enable file compression
    EncryptionEnabled = false                // Disable encryption
};

// Azure Blob storage
var azureStorage = new AzureBlobStorageProvider(connectionString, containerName)
{
    BlobTier = BlobTier.Cool,                // Use cool tier for cost
    EnableSoftDelete = true,                 // Enable soft delete
    RetentionDays = 90,                      // 90-day retention
    EnableVersioning = true                  // Enable blob versioning
};

// Distributed storage
var distributedStorage = new DistributedStorageProvider(new[]
{
    fileStorage,
    azureStorage
})
{
    PrimaryProvider = fileStorage,            // Primary storage
    FailoverEnabled = true,                  // Enable failover
    ConsistencyLevel = ConsistencyLevel.Eventual, // Eventual consistency
    RetryPolicy = new ExponentialBackoffRetryPolicy(3, TimeSpan.FromSeconds(1))
};
```

## 故障排除

### 常見問題

#### 檢查點建立失敗
```bash
# Problem: Checkpoints fail to create
# Solution: Check storage permissions and disk space
EnableDetailedLogging = true;
StorageProvider = new FileSystemStorageProvider("./checkpoints");
```

#### 檢查點操作緩慢
```bash
# Problem: Checkpoint operations are slow
# Solution: Optimize compression and storage
CompressionLevel = CompressionLevel.Fastest;
EnableAsyncBackup = true;
StorageProvider = new FastStorageProvider();
```

#### 復原失敗
```bash
# Problem: Checkpoint recovery fails
# Solution: Validate checkpoint integrity and storage
EnableCheckpointValidation = true;
ValidateOnRestore = true;
```

### 除錯模式

啟用詳細記錄以進行故障排除：

```csharp
// Enable debug logging
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<CheckpointingExample>();

// Configure executor with debug logging
var debugExecutor = new CheckpointingGraphExecutor(
    "DebugExample", "Debug checkpointing", logger);

debugExecutor.ConfigureCheckpointing(new CheckpointOptions
{
    EnableDetailedLogging = true,
    EnableMetrics = true,
    LogCheckpointOperations = true,
    LogStorageOperations = true
});
```

## 進階模式

### 自訂檢查點觸發程序

```csharp
// Implement custom checkpoint triggers
var customTrigger = new CustomCheckpointTrigger
{
    ShouldCheckpoint = (context) =>
    {
        // Checkpoint on specific conditions
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
// Implement incremental checkpointing for large states
var incrementalOptions = new IncrementalCheckpointOptions
{
    EnableIncrementalCheckpointing = true,
    IncrementThreshold = 1024 * 1024,        // 1MB threshold
    DeltaCompression = true,                 // Compress deltas
    MergeStrategy = MergeStrategy.Optimistic, // Optimistic merging
    ValidationStrategy = ValidationStrategy.Checksum // Checksum validation
};

checkpointingExecutor.ConfigureIncrementalCheckpointing(incrementalOptions);
```

### 檢查點協調

```csharp
// Orchestrate checkpoints across multiple workflows
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

* [State Management](./state-management.md): 圖表狀態和引數處理
* [Streaming Execution](./streaming-execution.md): 即時執行監控
* [Multi-Agent](./multi-agent.md): 協調的多代理工作流程
* [Graph Metrics](./graph-metrics.md): 效能監控和優化

## 參閱

* [Checkpointing Concepts](../concepts/checkpointing.md): 瞭解狀態持久化
* [State Management](../concepts/state.md): Graph 狀態基礎
* [Performance Monitoring](../how-to/metrics-and-observability.md): 指標和優化
* [API Reference](../api/): 完整 API 文件
