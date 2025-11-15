# 多代理系統

本文檔涵蓋 SemanticKernel.Graph 中的完整多代理協調系統，包括代理管理、工作分配、結果聚合和連接池管理。該系統能夠實現複雜的工作流程，其中多個專業化的代理通過智能協調和狀態管理在共享任務上進行協作。

## MultiAgentCoordinator

`MultiAgentCoordinator` 協調多個圖執行器實例以實現多代理執行，提供代理生命週期管理、共享狀態協調和結果聚合。

### 概述

這個中央協調器管理多個代理的完整生命週期，協調它們的執行，並提供智能工作分配和結果聚合。它與分佈式追蹤、健康監控和故障轉移機制集成，用於實現彈性多代理工作流程。

### 主要功能

* **代理生命週期管理**：代理實例的註冊、執行和釋放
* **共享狀態協調**：與 `SharedStateManager` 的集成以實現狀態同步
* **工作分配**：委派給 `WorkDistributor` 進行智能任務分配
* **結果聚合**：使用 `ResultAggregator` 組合代理輸出
* **健康監控**：電路破壞器模式和故障轉移機制
* **分佈式追蹤**：OpenTelemetry 集成用於跨代理可觀測性
* **並發執行**：具有可配置限制的有限並行性

### 配置

```csharp
var options = new MultiAgentOptions
{
    MaxConcurrentAgents = 5,
    CoordinationTimeout = TimeSpan.FromMinutes(10),
    EnableDistributedTracing = true,
    EnableAgentFailover = true,
    MaxFailoverAttempts = 3,
    SharedStateOptions = new SharedStateOptions
    {
        ConflictResolutionStrategy = ConflictResolutionStrategy.Merge,
        AllowOverwrite = true
    },
    WorkDistributionOptions = new WorkDistributionOptions
    {
        DistributionStrategy = WorkDistributionStrategy.RoleBased,
        EnablePrioritization = true
    },
    ResultAggregationOptions = new ResultAggregationOptions
    {
        DefaultAggregationStrategy = AggregationStrategy.Consensus,
        ConsensusThreshold = 0.6
    }
};

var coordinator = new MultiAgentCoordinator(options, logger);
```

### 代理註冊

```csharp
// 註冊具有特定角色的代理
var analysisAgent = await coordinator.RegisterAgentAsync(
    agentId: "analysis-agent-1",
    executor: analysisExecutor,
    role: new AgentRole
    {
        Name = "Data Analyst",
        Priority = 7,
        Capabilities = new HashSet<string> { "text_analysis", "data_extraction", "pattern_recognition" },
        Specializations = new HashSet<string> { "nlp", "ml" }
    },
    initialState: new GraphState(new KernelArguments { ["agent_type"] = "analyst" })
);

var processingAgent = await coordinator.RegisterAgentAsync(
    agentId: "processing-agent-1",
    executor: processingExecutor,
    role: new AgentRole
    {
        Name = "Data Processor",
        Priority = 6,
        Capabilities = new HashSet<string> { "data_transformation", "validation", "enrichment" }
    }
);
```

### 工作流程執行

```csharp
// 建立多代理工作流程
var workflow = new MultiAgentWorkflow
{
    Id = "document-analysis-001",
    Name = "Document Analysis Pipeline",
    Description = "Analyze documents using multiple specialized agents",
    Tasks = new List<WorkflowTask>
    {
        // 任務不嵌入特定的代理分配；協調器/分配器
        // 根據工作流程的 RequiredAgents 和配置的分配策略分配任務。
        new WorkflowTask
        {
            Id = "extract-text",
            Name = "Text Extraction",
            Description = "Extract text from documents",
            Priority = 8,
            DependsOn = new List<string>()
        },
        new WorkflowTask
        {
            Id = "process-content",
            Name = "Content Processing",
            Description = "Process extracted content",
            Priority = 7,
            DependsOn = new List<string> { "extract-text" }
        }
    },
    RequiredAgents = new List<string> { "analysis-agent-1", "processing-agent-1" },
    AggregationStrategy = AggregationStrategy.Merge
};

// 執行工作流程
var arguments = new KernelArguments
{
    ["document_path"] = "/path/to/document.pdf",
    ["analysis_type"] = "comprehensive"
};

// 執行工作流程（注意簽名：workflow、kernel、arguments）
var result = await coordinator.ExecuteWorkflowAsync(
    workflow,
    kernel,
    arguments,
    CancellationToken.None
);
```

### 簡易工作流程執行

```csharp
// 使用自動分配執行簡易工作流程
var result = await coordinator.ExecuteSimpleWorkflowAsync(
    kernel: kernel,
    arguments: new KernelArguments { ["input"] = "sample data" },
    agentIds: new[] { "agent-1", "agent-2", "agent-3" },
    aggregationStrategy: AggregationStrategy.Consensus
);

if (result.Success)
{
    Console.WriteLine($"Workflow completed in {result.Duration.TotalMilliseconds}ms");
    Console.WriteLine($"Aggregated result: {result.AggregatedResult?.GetValue<object>()}");
}
```

### 健康監控和故障轉移

```csharp
// 檢查代理健康狀態
var healthStatus = coordinator.HealthMonitor.GetAgentHealthStatus("agent-1");
if (healthStatus.Status == AgentHealthStatus.Unhealthy)
{
    // 代理不健康，考慮故障轉移
    var failoverResult = await coordinator.AttemptAgentFailoverAsync("agent-1");
    if (failoverResult.Success)
    {
        Console.WriteLine($"Agent failover successful: {failoverResult.NewAgentId}");
    }
}

// 取得整體系統健康狀態
var systemHealth = coordinator.HealthMonitor.GetSystemHealth();
Console.WriteLine($"System health: {systemHealth.OverallStatus}");
Console.WriteLine($"Healthy agents: {systemHealth.HealthyAgentCount}/{systemHealth.TotalAgentCount}");
```

## ResultAggregator

`ResultAggregator` 將多個代理的結果聚合為統一輸出，提供各種聚合策略和結果轉換功能。

### 概述

該組件使用可配置的策略提供智能結果組合、性能緩存和綜合結果驗證。它支持多種聚合方法，從簡單的合併到複雜的基於共識的聚合。

### 主要功能

* **多種聚合策略**：合併、加權、共識和自訂策略
* **結果緩存**：可配置的緩存與過期和失效機制
* **結果驗證**：內置驗證和大小限制
* **元數據保留**：維護各個結果的元數據和來源信息
* **性能優化**：高效的聚合演算法和緩存
* **可擴展架構**：自訂聚合策略註冊

### 配置

```csharp
var options = new ResultAggregationOptions
{
    DefaultAggregationStrategy = AggregationStrategy.Consensus,
    AggregationTimeout = TimeSpan.FromMinutes(5),
    IncludeMetadata = true,
    PreserveIndividualResults = true,
    ConsensusThreshold = 0.6,
    MaxResultSizeBytes = 10 * 1024 * 1024, // 10MB
    EnableResultValidation = true,
    EnableCaching = true,
    MaxCacheEntries = 1000,
    CacheExpiration = TimeSpan.FromHours(1)
};

var aggregator = new ResultAggregator(options, logger);
```

### 聚合策略

```csharp
// 可用的內置策略（與庫實現相符）
public enum AggregationStrategy
{
    Merge = 0,    // 組合所有成功結果
    Concat = 1,   // 連接成功結果
    First = 2,    // 使用第一個成功結果
    Last = 3,     // 使用最後一個成功結果
    Majority = 4, // 多數 / 投票式聚合
    Weighted = 5, // 基於代理優先級或置信度的加權組合
    Consensus = 6 // 需要代理之間的共識
}

// 使用特定策略聚合結果
var aggregatedResult = await aggregator.AggregateResultsAsync(
    workflowId: "workflow-001",
    agentResults: agentResults,
    strategy: AggregationStrategy.Consensus
);

if (aggregatedResult.Success)
{
    Console.WriteLine($"Aggregation successful using {aggregatedResult.Strategy}");
    Console.WriteLine($"Result: {aggregatedResult.Result?.GetValue<object>()}");
    Console.WriteLine($"Duration: {aggregatedResult.AggregationDuration.TotalMilliseconds}ms");
}
```

### 自訂聚合策略

```csharp
// 註冊自訂聚合策略
aggregator.RegisterStrategy("custom-merge", new CustomMergeStrategy());

// 自訂策略實現
public class CustomMergeStrategy : IAggregationStrategy
{
    public async Task<FunctionResult> AggregateAsync(string workflowId, 
        IReadOnlyList<AgentExecutionResult> results)
    {
        // 自訂聚合邏輯
        var successfulResults = results.Where(r => r.Success).ToList();
        
        if (successfulResults.Count == 0)
        {
            throw new InvalidOperationException("No successful results to aggregate");
        }

        // 自訂合併邏輯
        var mergedData = new Dictionary<string, object>();
        foreach (var result in successfulResults)
        {
            if (result.Result?.GetValue<object>() is Dictionary<string, object> data)
            {
                foreach (var kvp in data)
                {
                    if (!mergedData.ContainsKey(kvp.Key))
                    {
                        mergedData[kvp.Key] = kvp.Value;
                    }
                }
            }
        }

        return new FunctionResult(
            function: null,
            value: mergedData,
            culture: null,
            metadata: new Dictionary<string, object>
            {
                ["strategy"] = "custom-merge",
                ["source_count"] = successfulResults.Count
            }
        );
    }
}
```

### 緩存和性能

```csharp
// 檢查緩存統計信息
var cacheStats = aggregator.GetCacheStatistics();
Console.WriteLine($"Cache size: {cacheStats["CacheSize"]}");
Console.WriteLine($"Active entries: {cacheStats["ActiveEntries"]}");
Console.WriteLine($"Expired entries: {cacheStats["ExpiredEntries"]}");

// 失效特定工作流程的緩存
var invalidatedCount = aggregator.InvalidateCacheForWorkflow("workflow-001");
Console.WriteLine($"Invalidated {invalidatedCount} cache entries");

// 清除整個緩存
aggregator.ClearCache();
```

## AgentConnectionPool

`AgentConnectionPool` 管理每個代理的可重用 `IAgentConnection` 實例，在健康連接中提供公平選擇和基本的健康感知租賃語義。

### 概述

這個線程安全的池提供遠程代理通信的高效連接管理，具有健康監控、負載平衡和自動連接生命週期管理。它支持本地和遠程代理連接，具有可配置的池策略。

### 主要功能

* **連接池**：代理連接的高效重用
* **健康感知選擇**：自動篩選不健康的連接
* **負載平衡**：輪詢和基於健康的連接選擇
* **線程安全**：具有適當同步的並發訪問
* **度量集成**：內置性能和健康度量
* **自動清理**：連接釋放和資源管理

### 配置

```csharp
var options = new AgentConnectionPoolOptions
{
    MaxConcurrentRentals = 100,
    EnableMetrics = true,
    MetricsMeterName = "skg.agent_pool",
    ConnectionHealthCheckInterval = TimeSpan.FromSeconds(30),
    MaxConnectionAge = TimeSpan.FromMinutes(10),
    EnableConnectionCompression = true
};

var connectionPool = new AgentConnectionPool(options);
```

### 連接管理

```csharp
// 為代理註冊連接
var connection1 = new MockAgentConnection("agent-1", "instance-1");
var connection2 = new MockAgentConnection("agent-1", "instance-2");

// 池上的公共 API 是 `Register` 和 `RentAsync`
connectionPool.Register("agent-1", connection1);
connectionPool.Register("agent-1", connection2);

// 租用連接以供使用
var rented = await connectionPool.RentAsync("agent-1", CancellationToken.None);
if (rented != null)
{
    try
    {
        // 使用連接的 Executor 執行工作
        var execResult = await rented.Executor.ExecuteAsync(kernel, workItem.Arguments, CancellationToken.None);
        Console.WriteLine($"Execution result: {execResult.GetValue<object>()}");
    }
    finally
    {
        // 完成後透過釋放連接來歸還連接資源
        await rented.DisposeAsync();
    }
}
```

### 連接健康和度量

```csharp
// 檢查已註冊的連接數量（公共池 API 公開註冊計數）
var counts = connectionPool.GetRegisteredConnectionCounts();
Console.WriteLine($"Registered connections for agent-1: {counts.GetValueOrDefault("agent-1", 0)}");

// 租用連接並可選地透過連接的 IsHealthyAsync API 探測其健康狀態
var rented = await connectionPool.RentAsync("agent-1", CancellationToken.None);
if (rented != null)
{
    try
    {
        // 探測健康（池本身也會在內部使用健康探測）
        var isHealthy = await rented.IsHealthyAsync(CancellationToken.None);
        Console.WriteLine($"Rented connection {rented.Endpoint ?? rented.Executor.Name} healthy: {isHealthy}");
    }
    finally
    {
        await rented.DisposeAsync();
    }
}
```

### 連接接口

```csharp
// 池針對可重用遠程連接的公共契約
public interface IAgentConnection : IAsyncDisposable
{
    string AgentId { get; }
    IGraphExecutor Executor { get; }
    string? Endpoint { get; }
    Task<bool> IsHealthyAsync(CancellationToken cancellationToken = default);
}

// 僅用於文檔的最小示例連接
public class MockAgentConnection : IAgentConnection
{
    public string AgentId { get; }
    public string ConnectionId { get; }
    public IGraphExecutor Executor { get; }
    public string? Endpoint { get; }

    public MockAgentConnection(string agentId, string connectionId, IGraphExecutor executor, string? endpoint = null)
    {
        AgentId = agentId;
        ConnectionId = connectionId;
        Executor = executor;
        Endpoint = endpoint;
    }

    public async Task<bool> IsHealthyAsync(CancellationToken cancellationToken = default)
    {
        await Task.Delay(10, cancellationToken).ConfigureAwait(false);
        return true;
    }

    public ValueTask DisposeAsync()
    {
        return ValueTask.CompletedTask;
    }
}
```

## WorkDistributor

`WorkDistributor` 根據配置的策略在多個代理之間分配工作項，提供負載平衡、容量管理和工作項優先級。

### 概述

該組件實現智能工作分配演算法，考慮代理的能力、當前負載和配置的策略。它支持多種分配方法，並為監控和優化提供綜合度量。

### 主要功能

* **多種分配策略**：輪詢、基於負載、基於角色、基於容量
* **負載平衡**：基於代理容量和當前負載的自動分配
* **優先級支持**：工作項優先級和調度
* **容量管理**：動態代理容量追蹤和更新
* **度量集成**：綜合分配度量和監控
* **策略回退**：自動回退到替代分配方法

### 配置

```csharp
var options = new WorkDistributionOptions
{
    DistributionStrategy = WorkDistributionStrategy.LoadBased,
    EnablePrioritization = true,
    MaxParallelWorkItems = 10,
    DefaultAgentMaxCapacity = 5,
    LoadBalancingThreshold = 0.8,
    EnableMetrics = true,
    MetricsMeterName = "skg.work_distributor"
};

var workDistributor = new WorkDistributor(options, logger);
```

### 分配策略

```csharp
// 可用的分配策略
public enum WorkDistributionStrategy
{
    RoundRobin = 0,      // 以輪詢方式分配工作
    LoadBased = 1,       // 基於當前代理負載進行分配
    RoleBased = 2,       // 基於代理角色和能力進行分配
    CapacityBased = 3,   // 基於代理容量進行分配
    Custom = 4           // 自訂分配邏輯
}

// 為工作流程分配工作
var workItems = await workDistributor.DistributeWorkAsync(workflow, arguments);
Console.WriteLine($"Distributed {workItems.Count} work items");

foreach (var workItem in workItems)
{
    Console.WriteLine($"Work item {workItem.Id} assigned to agent {workItem.AgentId}");
    Console.WriteLine($"Priority: {workItem.Priority}, Status: {workItem.Status}");
}
```

### 代理容量管理

```csharp
// 更新代理容量信息
var capacity = new AgentCapacity
{
    AgentId = "agent-1",
    MaxCapacity = 10,
    CurrentLoad = 3,
    Capabilities = { "text_processing", "data_analysis" },
    Metadata = { ["region"] = "us-east", ["version"] = "1.0" }
};

workDistributor.UpdateAgentCapacity("agent-1", capacity);

// 取得容量信息
var agentCapacity = workDistributor.GetAgentCapacity("agent-1");
if (agentCapacity != null)
{
    Console.WriteLine($"Agent {agentCapacity.AgentId}: {agentCapacity.CurrentLoad}/{agentCapacity.MaxCapacity}");
    Console.WriteLine($"Available capacity: {agentCapacity.AvailableCapacity}");
}
```

### 工作項結構

```csharp
public class WorkItem
{
    public required string Id { get; set; }
    public required string WorkflowId { get; set; }
    public required string AgentId { get; set; }
    public required WorkflowTask Task { get; set; }
    public required KernelArguments Arguments { get; set; }
    public int Priority { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public WorkItemStatus Status { get; set; } = WorkItemStatus.Pending;
    public Dictionary<string, object> Metadata { get; set; } = new();
}

// 工作項狀態列舉
public enum WorkItemStatus
{
    Pending = 0,      // 工作項等待執行
    InProgress = 1,   // 工作項目前正在執行
    Completed = 2,    // 工作項成功完成
    Failed = 3,       // 工作項執行失敗
    Cancelled = 4     // 工作項已取消
}
```

### 度量和監控

```csharp
// 取得分配度量
var metrics = workDistributor.GetDistributionMetrics();
Console.WriteLine($"Distribution requests: {metrics.DistributionRequests}");
Console.WriteLine($"Distribution items: {metrics.DistributionItems}");
Console.WriteLine($"Strategy fallbacks: {metrics.StrategyFallbacks}");
Console.WriteLine($"Distribution errors: {metrics.DistributionErrors}");

// 取得代理分配統計
var assignmentStats = workDistributor.GetAgentAssignmentStatistics();
foreach (var stat in assignmentStats)
{
    Console.WriteLine($"Agent {stat.AgentId}: {stat.AssignedWorkItems} work items");
    Console.WriteLine($"  Average load: {stat.AverageLoad:F2}");
    Console.WriteLine($"  Peak load: {stat.PeakLoad}");
}
```

## 多代理類型和列舉

### 代理類型

```csharp
// 代理實例表示正在運行的代理
public sealed class AgentInstance : IDisposable
{
    public string AgentId { get; }
    public AgentRole Role { get; }
    public GraphState State { get; set; }
    public AgentStatus Status { get; set; }
    public DateTimeOffset CreatedAt { get; }
    public DateTimeOffset LastActivity { get; set; }
}

// 代理角色定義
public sealed class AgentRole
{
    public required string Name { get; set; }
    public string? Description { get; set; }
    public int Priority { get; set; } = 0;
    public HashSet<string> Capabilities { get; set; } = new();
    public HashSet<string> Specializations { get; set; } = new();
    public Dictionary<string, object> Metadata { get; set; } = new();
}

// 代理狀態列舉
public enum AgentStatus
{
    Idle = 0,         // 代理處於閒置狀態並準備好執行工作
    Running = 1,      // 代理目前正在執行工作
    Stopping = 2,     // 代理正在停止進程中
    Stopped = 3,      // 代理已停止
    Failed = 4,       // 代理已失敗
    Disposed = 5      // 代理已釋放
}
```

### 工作流程類型

```csharp
// 多代理工作流程定義
public sealed class MultiAgentWorkflow
{
    public required string Id { get; set; }
    public required string Name { get; set; }
    public string? Description { get; set; }
    public required List<WorkflowTask> Tasks { get; set; }
    public required List<string> RequiredAgents { get; set; }
    public AggregationStrategy AggregationStrategy { get; set; } = AggregationStrategy.Merge;
    public Dictionary<string, object> Metadata { get; set; } = new();
}

// 工作流程任務定義
public sealed class WorkflowTask
{
    public required string Id { get; set; }
    public required string Name { get; set; }
    public string? Description { get; set; }
    public required string AgentId { get; set; }
    public int Priority { get; set; } = 5;
    public List<string> DependsOn { get; set; } = new();
    public Dictionary<string, object> Configuration { get; set; } = new();
}
```

### 結果類型

```csharp
// 多代理工作流程結果
public sealed class MultiAgentResult
{
    public required string WorkflowId { get; set; }
    public bool Success { get; set; }
    public List<AgentExecutionResult> Results { get; set; } = new();
    public FunctionResult? AggregatedResult { get; set; }
    public TimeSpan Duration { get; set; }
    public List<string> AgentsInvolved { get; set; } = new();
    public Exception? Error { get; set; }
}

// 個別代理執行結果
public sealed class AgentExecutionResult
{
    public required string AgentId { get; set; }
    public required string WorkflowId { get; set; }
    public required string TaskId { get; set; }
    public bool Success { get; set; }
    public FunctionResult? Result { get; set; }
    public TimeSpan Duration { get; set; }
    public Exception? Error { get; set; }
    public Dictionary<string, object> Metadata { get; set; } = new();
}

// 聚合結果
public sealed class AggregatedResult
{
    public required string WorkflowId { get; set; }
    public AggregationStrategy Strategy { get; set; }
    public bool Success { get; set; }
    public FunctionResult? Result { get; set; }
    public List<AgentExecutionResult> SourceResults { get; set; } = new();
    public TimeSpan AggregationDuration { get; set; }
    public Exception? Error { get; set; }
    public Dictionary<string, object> Metadata { get; set; } = new();
}
```

## 另請參閱

* [多代理和共享狀態指南](../how-to/multi-agent-and-shared-state.md) - 實現多代理工作流程的綜合指南
* [狀態和序列化參考](state-and-serialization.md) - 代理協調的狀態管理
* [錯誤策略參考](error-policies.md) - 多代理系統中的錯誤處理和彈性
* [圖執行器參考](graph-executor.md) - 個別代理的核心執行引擎
* [整合參考](integration.md) - 多代理工作流程的外部系統整合
* [多代理示例](../examples/multi-agent-examples.md) - 多代理實現的實際示例
