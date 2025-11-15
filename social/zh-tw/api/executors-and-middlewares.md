# 執行器和中介軟體

本參考涵蓋了提供 SemanticKernel.Graph 中進階執行能力的專門執行器實現和中介軟體系統。

## 概述

SemanticKernel.Graph 函式庫使用裝飾器模式實現了一個分層執行器架構，其中專門的執行器包裝核心 `GraphExecutor` 以添加特定功能。這種設計允許可組合的執行功能，同時保持清晰的關注點分離。

## 執行器架構

### 核心執行器層

基本的 `GraphExecutor` 提供了基礎執行引擎，而專門的執行器添加了特定的功能：

```
┌─────────────────────────────────────────────────────────────┐
│                    專門的執行器                              │
├─────────────────────────────────────────────────────────────┤
│  CheckpointingGraphExecutor  │  StreamingGraphExecutor     │
│  (狀態持久化)               │  (即時事件)                 │
├─────────────────────────────────────────────────────────────┤
│                    核心 GraphExecutor                       │
│              (執行引擎 + 中介軟體)                         │
├─────────────────────────────────────────────────────────────┤
│                    IGraphExecutor                           │
│                    (介面合約)                               │
└─────────────────────────────────────────────────────────────┘
```

## CheckpointingGraphExecutor

一個專門的執行器，為圖形執行添加了自動檢查點和狀態持久化功能。

### 核心功能

```csharp
public class CheckpointingGraphExecutor : IGraphExecutor
{
    // 檢查點管理
    public virtual ICheckpointManager CheckpointManager { get; }
    public CheckpointingOptions Options { get; }
    
    // 恢復整合
    public virtual GraphRecoveryService? RecoveryService { get; set; }
    
    // 執行統計資料
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

### 使用範例

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

// 配置自動恢復
var recoveryService = executor.ConfigureRecovery(new RecoveryOptions
{
    EnableAutomaticRecovery = true,
    MaxRecoveryAttempts = 3
});

// 執行自動檢查點
var result = await executor.ExecuteAsync(kernel, arguments);

// 建立手動檢查點
var checkpointId = await executor.CheckpointManager.CreateCheckpointAsync(
    "manual-checkpoint",
    new Dictionary<string, object> { ["reason"] = "before_risky_operation" }
);
```

### 檢查點生命週期

執行器在執行期間自動建立檢查點：

1. **執行前**：如果啟用，建立初始檢查點
2. **執行期間**：根據配置的間隔建立檢查點
3. **節點執行後**：根據節點完成情況建立檢查點
4. **恢復時**：從最後一個可用檢查點進行復原

## StreamingGraphExecutor

一個專門的執行器，提供了圖形執行期間的即時事件流，用於監控和整合目的。

### 核心功能

```csharp
public sealed class StreamingGraphExecutor : IStreamingGraphExecutor, IDisposable
{
    // 串流功能
    public async Task<IGraphExecutionEventStream> ExecuteStreamingAsync(
        Kernel kernel, 
        KernelArguments arguments, 
        CancellationToken cancellationToken = default)
    
    // 事件流管理
    public IReadOnlyDictionary<string, GraphExecutionEventStream> ActiveStreams { get; }
    
    // 處置
    public void Dispose();
}
```

### 事件流類型

串流執行器在執行期間發出各種事件類型：

```csharp
// 執行生命週期事件
public class GraphExecutionStartedEvent : GraphExecutionEvent
public class GraphExecutionCompletedEvent : GraphExecutionEvent
public class GraphExecutionFailedEvent : GraphExecutionEvent

// 節點執行事件
public class NodeExecutionStartedEvent : GraphExecutionEvent
public class NodeExecutionCompletedEvent : GraphExecutionEvent
public class NodeExecutionFailedEvent : GraphExecutionEvent

// 狀態變更事件
public class StateChangedEvent : GraphExecutionEvent
public class CheckpointCreatedEvent : GraphExecutionEvent
```

### 使用範例

```csharp
// 建立串流執行器
var executor = new StreamingGraphExecutor("streaming-graph");

// 使用串流執行
var eventStream = await executor.ExecuteStreamingAsync(kernel, arguments);

// 即時使用事件
await foreach (var evt in eventStream.WithCancellation(cancellationToken))
{
    switch (evt)
    {
        case NodeExecutionStartedEvent started:
            Console.WriteLine($"節點 {started.NodeId} 已開始");
            break;
            
        case NodeExecutionCompletedEvent completed:
            Console.WriteLine($"節點 {completed.NodeId} 在 {completed.Duration} 內完成");
            break;
            
        case StateChangedEvent stateChange:
            Console.WriteLine($"狀態已變更：{stateChange.ChangedProperties.Count} 個屬性");
            break;
    }
}
```

### 事件流配置

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

一個服務，為圖形執行提供自動故障檢測和恢復管理。

### 核心功能

```csharp
public sealed class GraphRecoveryService : IDisposable
{
    // 恢復管理
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

### 恢復選項

```csharp
public sealed class RecoveryOptions
{
    // 自動恢復
    public bool EnableAutomaticRecovery { get; set; } = true;
    public int MaxRecoveryAttempts { get; set; } = 3;
    public TimeSpan RecoveryTimeout { get; set; } = TimeSpan.FromMinutes(10);
    
    // 回復策略
    public bool EnableAutomaticRollback { get; set; } = true;
    public RollbackStrategy RollbackStrategy { get; set; } = RollbackStrategy.LastCheckpoint;
    
    // 通知
    public bool EnableNotifications { get; set; } = true;
    public TimeSpan NotificationTimeout { get; set; } = TimeSpan.FromSeconds(30);
}
```

### 恢復策略

```csharp
public enum RollbackStrategy
{
    LastCheckpoint,      // 回復到最後成功的檢查點
    SpecificCheckpoint,  // 回復到指定的檢查點
    PartialRollback,     // 僅回復失敗的節點
    FullRestart          // 重新啟動整個執行
}

public enum RecoveryStrategy
{
    Automatic,           // 使用原則自動恢復
    Manual,              // 需要手動介入
    Hybrid,              // 自動但需要手動批准
    Disabled            // 不嘗試恢復
}
```

### 使用範例

```csharp
// 配置恢復服務
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

// 執行恢復
try
{
    var result = await executor.ExecuteAsync(kernel, arguments);
}
catch (Exception ex)
{
    // 將嘗試自動恢復
    var recoveryResult = await recoveryService.AttemptRecoveryAsync(
        executionId, 
        new FailureContext(ex), 
        kernel, 
        cancellationToken);
        
    if (recoveryResult.IsSuccessful)
    {
        Console.WriteLine("恢復成功！");
    }
}
```

## ResourceGovernor

一個輕量級的進程內資源管理員，根據 CPU/記憶體使用率和執行優先級提供自適應速率限制和協作式排程。

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
    // 資源管理
    public bool EnableResourceGovernance { get; set; } = false;
    
    // 速率限制
    public double BasePermitsPerSecond { get; set; } = 100.0;
    public int MaxBurstSize { get; set; } = 50;
    
    // 優先級排程
    public bool EnablePriorityScheduling { get; set; } = true;
    public TimeSpan PriorityTimeout { get; set; } = TimeSpan.FromMinutes(5);
    
    // 自適應節流
    public bool EnableAdaptiveThrottling { get; set; } = true;
    public double ThrottlingThreshold { get; set; } = 0.8; // 80% 資源使用率
}
```

### 執行優先級

```csharp
public enum ExecutionPriority
{
    Critical = 0,    // 最高優先級，立即執行
    High = 1,        // 高優先級，最少延遲
    Normal = 2,      // 一般優先級，標準排程
    Low = 3,         // 低優先級，可能延遲
    Background = 4   // 背景優先級，最低優先級
}
```

### 使用範例

```csharp
// 配置資源管理
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 50.0,
    MaxBurstSize = 25,
    EnablePriorityScheduling = true
};

var executor = new GraphExecutor("governed-graph")
    .ConfigureResources(resourceOptions);

// 執行有資源限制的執行
var result = await executor.ExecuteAsync(kernel, arguments);

// ResourceGovernor 將自動：
// - 根據許可限制並行執行
// - 根據優先級排程工作
// - 根據系統負載自適應調整節流
// - 在預算耗盡時發出事件
```

## 中介軟體管道

執行器系統支援可配置的中介軟體管道，允許在執行期間的各個點注入自訂邏輯。

### 中介軟體介面

```csharp
public interface IGraphExecutionMiddleware
{
    // 執行順序（較低值先執行）
    int Order { get; }
    
    // 生命週期掛鉤
    Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken);
    Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken);
    Task OnNodeFailedAsync(GraphExecutionContext context, IGraphNode node, Exception exception, CancellationToken cancellationToken);
}
```

### 中介軟體執行順序

中介軟體管道按以下順序執行：

1. **節點執行前**：中介軟體按升序 `Order` 值執行
2. **節點執行**：實際節點執行
3. **節點執行後**：中介軟體按降序 `Order` 值執行
4. **執行失敗**：中介軟體按降序 `Order` 值執行

### 內建中介軟體

```csharp
// 效能監控中介軟體
public class PerformanceMonitoringMiddleware : IGraphExecutionMiddleware
{
    public int Order => 100;

    public Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken)
    {
        // 在執行上下文屬性中記錄開始時間戳
        context.SetProperty($"node:{node.NodeId}:start", DateTimeOffset.UtcNow);
        return Task.CompletedTask;
    }

    public Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken)
    {
        // 使用儲存的開始時間戳計算經過時間
        var startObj = context.GetProperty<object>($"node:{node.NodeId}:start");
        if (startObj is DateTimeOffset start)
        {
            var elapsed = DateTimeOffset.UtcNow - start;
            Console.WriteLine($"[PERF] 節點 {node.NodeId} 在 {elapsed.TotalMilliseconds}ms 內完成");
        }
        return Task.CompletedTask;
    }
}

// 記錄中介軟體
public class LoggingMiddleware : IGraphExecutionMiddleware
{
    public int Order => 200;

    public Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken)
    {
        // 簡單的主控台記錄用於範例和文件
        Console.WriteLine($"[LOG] 正在啟動節點 {node.NodeId}");
        return Task.CompletedTask;
    }

    public Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken)
    {
        // 列印簡潔的完成訊息，結果值可用時包括該訊息
        var value = "<unavailable>";
        try { value = result.GetValue<object>()?.ToString() ?? "null"; } catch { }
        Console.WriteLine($"[LOG] 完成節點 {node.NodeId}，結果：{value}");
        return Task.CompletedTask;
    }
}
```

### 自訂中介軟體範例

```csharp
// 自訂驗證中介軟體
public class ValidationMiddleware : IGraphExecutionMiddleware
{
    public int Order => 50; // 在管道中早期執行

    public Task OnBeforeNodeAsync(GraphExecutionContext context, IGraphNode node, CancellationToken cancellationToken)
    {
        // 使用節點的內建驗證進行 KernelArguments 驗證
        var validationResult = node.ValidateExecution(context.GraphState.KernelArguments);
        if (!validationResult.IsValid)
        {
            throw new ValidationException($"節點 {node.NodeId} 驗證失敗：{validationResult.CreateSummary()}");
        }
        return Task.CompletedTask;
    }

    public Task OnAfterNodeAsync(GraphExecutionContext context, IGraphNode node, FunctionResult result, CancellationToken cancellationToken)
    {
        // 基本輸出健全檢查：在實際程式碼中優先使用節點特定驗證
        try
        {
            var value = result.GetValue<object>();
            if (value == null)
            {
                Console.WriteLine($"[WARN] 節點 {node.NodeId} 產生空結果");
            }
        }
        catch
        {
            Console.WriteLine($"[WARN] 無法檢查節點 {node.NodeId} 的結果");
        }
        return Task.CompletedTask;
    }

    public Task OnNodeFailedAsync(GraphExecutionContext context, IGraphNode node, Exception exception, CancellationToken cancellationToken)
    {
        // 將驗證相關故障記錄到主控台用於範例
        if (exception is ValidationException)
        {
            Console.WriteLine($"[ERROR] 節點 {node.NodeId} 驗證失敗：{exception.Message}");
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

### 組合多個執行器

```csharp
// 建立具有串流功能的檢查點執行器
var baseExecutor = new GraphExecutor("base-graph");
var checkpointingExecutor = new CheckpointingGraphExecutor("checkpointing-graph", checkpointManager);
var streamingExecutor = new StreamingGraphExecutor("streaming-graph");

// 配置恢復服務
var recoveryService = checkpointingExecutor.ConfigureRecovery(new RecoveryOptions
{
    EnableAutomaticRecovery = true,
    MaxRecoveryAttempts = 3
});

// 新增中介軟體用於跨領域關注點
baseExecutor.UseMiddleware(new PerformanceMonitoringMiddleware())
    .UseMiddleware(new LoggingMiddleware())
    .UseMiddleware(new ValidationMiddleware());

// 使用完整功能執行
var result = await checkpointingExecutor.ExecuteAsync(kernel, arguments);
```

### 資源管理整合

```csharp
// 在所有執行器間配置資源管理
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

// 資源管理將套用於所有執行
var result = await checkpointingExecutor.ExecuteAsync(kernel, arguments);
```

## 配置和選項

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
* [執行上下文](./execution-context.md) - 執行上下文和事件工具
* [狀態和序列化](./state-and-serialization.md) - 狀態管理和檢查點
* [串流執行](../concepts/streaming.md) - 串流執行概念
* [錯誤處理和復原力](../how-to/error-handling-and-resilience.md) - 錯誤處理模式
* [資源管理和並行](../how-to/resource-governance-and-concurrency.md) - 資源管理指南
