# 執行器和中介軟體

此參考涵蓋提供 SemanticKernel.Graph 中進階執行功能的特殊執行器實現和中介軟體系統。

## 概述

SemanticKernel.Graph 函式庫使用 decorator 模式實現分層執行器架構，其中特殊執行器包裝核心 `GraphExecutor` 以新增特定功能。此設計允許可組合的執行功能，同時保持清晰的關注點分離。

## 執行器架構

### 核心執行器層

基礎 `GraphExecutor` 提供基本執行引擎，而特殊執行器則新增特定功能：

```
┌─────────────────────────────────────────────────────────────┐
│                    特殊執行器                                │
├─────────────────────────────────────────────────────────────┤
│  CheckpointingGraphExecutor  │  StreamingGraphExecutor     │
│  (狀態持久化)                │  (實時事件)                  │
├─────────────────────────────────────────────────────────────┤
│                    核心 GraphExecutor                       │
│              (執行引擎 + 中介軟體)                         │
├─────────────────────────────────────────────────────────────┤
│                    IGraphExecutor                           │
│                    (介面合約)                               │
└─────────────────────────────────────────────────────────────┘
```

## CheckpointingGraphExecutor

一個特殊執行器，為 Graph 執行新增自動檢查點和狀態持久化功能。

### 核心功能

```csharp
public class CheckpointingGraphExecutor : IGraphExecutor
{
    // 檢查點管理
    public virtual ICheckpointManager CheckpointManager { get; }
    public CheckpointingOptions Options { get; }
    
    // 復原整合
    public virtual GraphRecoveryService? RecoveryService { get; set; }
    
    // 執行統計
    public string? LastExecutionId { get; }
}
```

### 檢查點選項

```csharp
public sealed class CheckpointingOptions
{
    // 自動檢查點
    public bool EnableAutomaticCheckpointing { get; set; } = true;
    public int CheckpointInterval { get; set; } = 10; // 每 N 個節點
    
    // 手動檢查點
    public bool EnableManualCheckpointing { get; set; } = true;
    public bool EnableCheckpointMetadata { get; set; } = true;
    
    // 儲存選項
    public bool EnableCompression { get; set; } = true;
    public bool EnableEncryption { get; set; } = false;
    public TimeSpan? CheckpointRetention { get; set; }
}
```

### 使用示例

```csharp
// 建立檢查點執行器
var checkpointManager = new MemoryCheckpointManager();
var executor = new CheckpointingGraphExecutor(
    "my-graph",
    checkpointManager,
    new CheckpointingOptions 
    { 
        CheckpointInterval = 5,
        EnableCompression = true 
    }
);

// 設定自動復原
var recoveryService = executor.ConfigureRecovery(new RecoveryOptions
{
    EnableAutomaticRecovery = true,
    MaxRecoveryAttempts = 3
});

// 執行自動檢查點
var result = await executor.ExecuteAsync(kernel, arguments);

// 手動建立檢查點
var checkpointId = await executor.CheckpointManager.CreateCheckpointAsync(
    "manual-checkpoint",
    new Dictionary<string, object> { ["reason"] = "before_risky_operation" }
);
```

### 檢查點生命週期

執行器在執行期間自動建立檢查點：

1. **執行前**：如果啟用，建立初始檢查點
2. **執行期間**：按配置間隔建立檢查點
3. **Node 執行後**：根據節點完成建立檢查點
4. **復原時**：從最後可用的檢查點復原

## StreamingGraphExecutor

一個特殊執行器，在 Graph 執行期間提供實時事件串流，用於監控和整合目的。

### 核心功能

```csharp
public sealed class StreamingGraphExecutor : IStreamingGraphExecutor, IDisposable
{
    // 串流功能
    public async Task<IGraphExecutionEventStream> ExecuteStreamingAsync(
        Kernel kernel, 
        KernelArguments arguments, 
        CancellationToken cancellationToken = default)
    
    // 事件串流管理
    public IReadOnlyDictionary<string, GraphExecutionEventStream> ActiveStreams { get; }
    
    // 處置
    public void Dispose();
}
```

### 事件串流類型

串流執行器在執行期間發出各種事件類型：

```csharp
// 執行生命週期事件
public class GraphExecutionStartedEvent : GraphExecutionEvent
public class GraphExecutionCompletedEvent : GraphExecutionEvent
public class GraphExecutionFailedEvent : GraphExecutionEvent

// Node 執行事件
public class NodeExecutionStartedEvent : GraphExecutionEvent
public class NodeExecutionCompletedEvent : GraphExecutionEvent
public class NodeExecutionFailedEvent : GraphExecutionEvent

// 狀態變更事件
public class StateChangedEvent : GraphExecutionEvent
public class CheckpointCreatedEvent : GraphExecutionEvent
```

### 使用示例

```csharp
// 建立串流執行器
var executor = new StreamingGraphExecutor("streaming-graph");

// 執行串流
var eventStream = await executor.ExecuteStreamingAsync(kernel, arguments);

// 即時使用事件
await foreach (var evt in eventStream.WithCancellation(cancellationToken))
{
    switch (evt)
    {
        case NodeExecutionStartedEvent started:
            Console.WriteLine($"Node {started.NodeId} started");
            break;
            
        case NodeExecutionCompletedEvent completed:
            Console.WriteLine($"Node {completed.NodeId} completed in {completed.Duration}");
            break;
            
        case StateChangedEvent stateChange:
            Console.WriteLine($"State changed: {stateChange.ChangedProperties.Count} properties");
            break;
    }
}
```

### 事件串流配置

```csharp
public sealed class StreamingExecutionOptions
{
    // 事件篩選
    public bool EnableNodeEvents { get; set; } = true;
    public bool EnableStateEvents { get; set; } = true;
    public bool EnableCheckpointEvents { get; set; } = true;
    
    // 效能選項
    public int EventBufferSize { get; set; } = 1000;
    public bool EnableEventCompression { get; set; } = false;
    public TimeSpan EventTimeout { get; set; } = TimeSpan.FromMinutes(5);
}
```

## GraphRecoveryService

提供 Graph 執行的自動故障偵測和復原管理的服務。

### 核心功能

```csharp
public sealed class GraphRecoveryService : IDisposable
{
    // 復原管理
    public async Task<RecoveryResult> AttemptRecoveryAsync(
        string executionId, 
        FailureContext failureContext, 
        Kernel kernel, 
        CancellationToken cancellationToken)
    
    // 健康監控
    public event EventHandler<BudgetExhaustedEventArgs>? BudgetExhausted;
    public long BudgetExhaustionCount { get; }
    public DateTimeOffset LastBudgetExhaustion { get; }
    
    // 工作階段管理
    public IReadOnlyDictionary<string, RecoverySession> ActiveSessions { get; }
}
```

### 復原選項

```csharp
public sealed class RecoveryOptions
{
    // 自動復原
    public bool EnableAutomaticRecovery { get; set; } = true;
    public int MaxRecoveryAttempts { get; set; } = 3;
    public TimeSpan RecoveryTimeout { get; set; } = TimeSpan.FromMinutes(10);
    
    // 回滾策略
    public bool EnableAutomaticRollback { get; set; } = true;
    public RollbackStrategy RollbackStrategy { get; set; } = RollbackStrategy.LastCheckpoint;
    
    // 通知
    public bool EnableNotifications { get; set; } = true;
    public TimeSpan NotificationTimeout { get; set; } = TimeSpan.FromSeconds(30);
}
```

### 復原策略

```csharp
public enum RollbackStrategy
{
    LastCheckpoint,      // 回滾到最後成功的檢查點
    SpecificCheckpoint,  // 回滾到指定檢查點
    PartialRollback,     // 只回滾失敗的節點
    FullRestart          // 重新啟動整個執行
}

public enum RecoveryStrategy
{
    Automatic,           // 使用原則的自動復原
    Manual,              // 需要手動介入
    Hybrid,              // 自動並需要手動批准
    Disabled            // 不嘗試復原
}
```

### 使用示例

```csharp
// 設定復原服務
var recoveryService = new GraphRecoveryService(
    checkpointManager,
    executor,
    new RecoveryOptions
    {
        EnableAutomaticRecovery = true,
        MaxRecoveryAttempts = 3,
        RollbackStrategy = RollbackStrategy.LastCheckpoint
    }
);

// 新增通知處理器
recoveryService.AddNotificationHandler(new LoggingRecoveryNotificationHandler(logger));
recoveryService.AddNotificationHandler(new EmailRecoveryNotificationHandler(emailService));

// 執行復原
try
{
    var result = await executor.ExecuteAsync(kernel, arguments);
}
catch (Exception ex)
{
    // 將嘗試自動復原
    var recoveryResult = await recoveryService.AttemptRecoveryAsync(
        executionId, 
        new FailureContext(ex), 
        kernel, 
        cancellationToken);
        
    if (recoveryResult.IsSuccessful)
    {
        Console.WriteLine("Recovery successful!");
    }
}
```

## ResourceGovernor

輕量級的進程內資源監管器，提供基於 CPU/記憶體使用量和執行優先順序的自適應速率限制和合作調度。

### 核心功能

```csharp
public sealed class ResourceGovernor : IDisposable
{
    // 資源獲取
    public async Task<IResourceLease> AcquireLeaseAsync(
        int cost, 
        ExecutionPriority priority, 
        CancellationToken cancellationToken = default)
    
    // 速率限制
    public double CurrentPermitsPerSecond { get; }
    public int AvailableBurst { get; }
    
    // 預算監控
    public event EventHandler<BudgetExhaustedEventArgs>? BudgetExhausted;
    public long BudgetExhaustionCount { get; }
    public DateTimeOffset LastBudgetExhaustion { get; }
}
```

### 資源選項

```csharp
public sealed class GraphResourceOptions
{
    // 資源監管
    public bool EnableResourceGovernance { get; set; } = false;
    
    // 速率限制
    public double BasePermitsPerSecond { get; set; } = 100.0;
    public int MaxBurstSize { get; set; } = 50;
    
    // 優先順序調度
    public bool EnablePriorityScheduling { get; set; } = true;
    public TimeSpan PriorityTimeout { get; set; } = TimeSpan.FromMinutes(5);
    
    // 自適應節流
    public bool EnableAdaptiveThrottling { get; set; } = true;
    public double ThrottlingThreshold { get; set; } = 0.8; // 80% 資源使用量
}
```

### 執行優先順序

```csharp
public enum ExecutionPriority
{
    Critical = 0,    // 最高優先順序，立即執行
    High = 1,        // 高優先順序，最小延遲
    Normal = 2,      // 一般優先順序，標準調度
    Low = 3,         // 低優先順序，可能延遲
    Background = 4   // 背景優先順序，最低優先順序
}
```

### 使用示例

```csharp
// 設定資源監管
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 50.0,
    MaxBurstSize = 25,
    EnablePriorityScheduling = true
};

var executor = new GraphExecutor("governed-graph")
    .ConfigureResources(resourceOptions);

// 執行資源限制
var result = await executor.ExecuteAsync(kernel, arguments);

// ResourceGovernor 將自動：
// - 根據許可限制並行執行
// - 根據優先順序調度工作
// - 根據系統負載自適應節流
// - 當預算耗盡時發出事件
```

## 中介軟體管道

執行器系統支援可配置的中介軟體管道，允許在執行期間的各個點注入自定義邏輯。

### 中介軟體介面

```csharp
public interface IGraphExecutionMiddleware
{
    // 執行順序（較低值較早執行）
    int Order { get; }
    
    // 生命週期勾點
    Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken);
    Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken);
    Task OnNodeFailedAsync(GraphExecutionContext context, IGraphNode node, Exception exception, CancellationToken cancellationToken);
}
```

### 中介軟體執行順序

中介軟體管道按以下順序執行：

1. **Node 執行前**：中介軟體按升序 `Order` 值執行
2. **Node 執行**：實際 Node 執行
3. **Node 執行後**：中介軟體按降序 `Order` 值執行
4. **失敗時**：中介軟體按降序 `Order` 值執行

### 內建中介軟體

```csharp
// 效能監控中介軟體
public class PerformanceMonitoringMiddleware : IGraphExecutionMiddleware
{
    public int Order => 100;

    public Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken)
    {
        // 在執行內容屬性中記錄開始時間戳
        context.SetProperty($"node:{node.NodeId}:start", DateTimeOffset.UtcNow);
        return Task.CompletedTask;
    }

    public Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken)
    {
        // 使用儲存的開始時間戳計算經過的時間
        var startObj = context.GetProperty<object>($"node:{node.NodeId}:start");
        if (startObj is DateTimeOffset start)
        {
            var elapsed = DateTimeOffset.UtcNow - start;
            Console.WriteLine($"[PERF] Node {node.NodeId} completed in {elapsed.TotalMilliseconds}ms");
        }
        return Task.CompletedTask;
    }
}

// 日誌中介軟體
public class LoggingMiddleware : IGraphExecutionMiddleware
{
    public int Order => 200;

    public Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken)
    {
        // 簡單的主控台日誌用於示例和文件
        Console.WriteLine($"[LOG] Starting node {node.NodeId}");
        return Task.CompletedTask;
    }

    public Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken)
    {
        // 列印簡潔的完成訊息，並在可用時包含結果值
        var value = "<unavailable>";
        try { value = result.GetValue<object>()?.ToString() ?? "null"; } catch { }
        Console.WriteLine($"[LOG] Completed node {node.NodeId} with result: {value}");
        return Task.CompletedTask;
    }
}
```

### 自定義中介軟體示例

```csharp
// 自定義驗證中介軟體
public class ValidationMiddleware : IGraphExecutionMiddleware
{
    public int Order => 50; // 在管道中較早執行

    public Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken)
    {
        // 使用節點的內建驗證針對 KernelArguments
        var validationResult = node.ValidateExecution(context.GraphState.KernelArguments);
        if (!validationResult.IsValid)
        {
            throw new ValidationException($"Node {node.NodeId} validation failed: {validationResult.CreateSummary()}");
        }
        return Task.CompletedTask;
    }

    public Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken)
    {
        // 基本的輸出理智檢查：在實際程式碼中偏好節點特定驗證
        try
        {
            var value = result.GetValue<object>();
            if (value == null)
            {
                Console.WriteLine($"[WARN] Node {node.NodeId} produced null result");
            }
        }
        catch
        {
            Console.WriteLine($"[WARN] Unable to inspect result for node {node.NodeId}");
        }
        return Task.CompletedTask;
    }

    public Task OnNodeFailedAsync(GraphExecutionContext context, IGraphNode node, Exception exception, CancellationToken cancellationToken)
    {
        // 將驗證相關故障日誌記錄到主控台以用於示例
        if (exception is ValidationException)
        {
            Console.WriteLine($"[ERROR] Validation failure in node {node.NodeId}: {exception.Message}");
        }
        return Task.CompletedTask;
    }
}

// 將中介軟體新增至執行器
var executor = new GraphExecutor("validated-graph")
    .UseMiddleware(new ValidationMiddleware())
    .UseMiddleware(new PerformanceMonitoringMiddleware())
    .UseMiddleware(new LoggingMiddleware());
```

## 整合模式

### 結合多個執行器

```csharp
// 建立具有串流功能的檢查點執行器
var baseExecutor = new GraphExecutor("base-graph");
var checkpointingExecutor = new CheckpointingGraphExecutor("checkpointing-graph", checkpointManager);
var streamingExecutor = new StreamingGraphExecutor("streaming-graph");

// 設定復原服務
var recoveryService = checkpointingExecutor.ConfigureRecovery(new RecoveryOptions
{
    EnableAutomaticRecovery = true,
    MaxRecoveryAttempts = 3
});

// 為橫跨關注點新增中介軟體
baseExecutor.UseMiddleware(new PerformanceMonitoringMiddleware())
    .UseMiddleware(new LoggingMiddleware())
    .UseMiddleware(new ValidationMiddleware());

// 執行完整功能
var result = await checkpointingExecutor.ExecuteAsync(kernel, arguments);
```

### 資源監管整合

```csharp
// 在所有執行器上設定資源監管
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 100.0,
    MaxBurstSize = 50
};

var baseExecutor = new GraphExecutor("governed-graph")
    .ConfigureResources(resourceOptions);

var checkpointingExecutor = new CheckpointingGraphExecutor("checkpointing-graph", checkpointManager)
    .ConfigureRecovery(new RecoveryOptions { EnableAutomaticRecovery = true });

// 資源監管將應用於所有執行
var result = await checkpointingExecutor.ExecuteAsync(kernel, arguments);
```

## 設定和選項

### 基於環境的配置

```csharp
// 環境變數可以控制執行器行為
// SKG_ENABLE_CHECKPOINTING=true
// SKG_ENABLE_STREAMING=true
// SKG_ENABLE_RECOVERY=true
// SKG_ENABLE_RESOURCE_GOVERNANCE=true

var builder = Kernel.CreateBuilder()
    .AddGraphModules(options => 
    {
        options.EnableCheckpointing = true;
        options.EnableStreaming = true;
        options.EnableRecovery = true;
        options.EnableMultiAgent = false;
    });
```

### 相依性注入整合

```csharp
// 註冊執行器和服務
services.AddSingleton<ICheckpointManager, FileCheckpointManager>();
services.AddSingleton<GraphRecoveryService>();
services.AddSingleton<ResourceGovernor>();

// 註冊中介軟體
services.AddTransient<ValidationMiddleware>();
services.AddTransient<PerformanceMonitoringMiddleware>();
services.AddTransient<LoggingMiddleware>();
```

## 另請參閱

* [GraphExecutor API](./graph-executor.md) - 核心執行器介面和實現
* [Execution Context](./execution-context.md) - 執行內容和事件公用程式
* [State and Serialization](./state-and-serialization.md) - 狀態管理和檢查點
* [Streaming Execution](../concepts/streaming.md) - 串流執行概念
* [Error Handling and Resilience](../how-to/error-handling-and-resilience.md) - 錯誤處理模式
* [Resource Governance and Concurrency](../how-to/resource-governance-and-concurrency.md) - 資源管理指南
