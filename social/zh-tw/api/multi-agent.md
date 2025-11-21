# 多代理

本文件涵蓋 SemanticKernel.Graph 中的完整多代理協調系統，包括代理管理、工作分配、結果聚合和連接池。該系統支援複雜的工作流程，其中多個專門的代理透過智慧協調和狀態管理協作於共享任務。

## MultiAgentCoordinator

`MultiAgentCoordinator` 協調多個 Graph Executor 實例以啟用多代理執行，提供代理生命週期管理、共享狀態協調和結果聚合。

### 概述

這個中央協調器管理多個代理的完整生命週期，協調其執行，並提供智慧的工作分配和結果聚合。它與分散式追蹤、健康監控和容錯機制整合，以支持具有恢復力的多代理工作流程。

### 主要特性

* **代理生命週期管理**：代理實例的註冊、執行和処理
* **共享狀態協調**：與 `SharedStateManager` 的整合以進行狀態同步
* **工作分配**：委託 `WorkDistributor` 進行智慧任務指派
* **結果聚合**：使用 `ResultAggregator` 組合代理輸出
* **健康監控**：斷路器模式和容錯機制
* **分散式追蹤**：OpenTelemetry 整合以進行跨代理可觀測性
* **並行執行**：可配置上限的有界平行性

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
// Register agents with specific roles
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
// Create a multi-agent workflow
var workflow = new MultiAgentWorkflow
{
    Id = "document-analysis-001",
    Name = "Document Analysis Pipeline",
    Description = "Analyze documents using multiple specialized agents",
    Tasks = new List<WorkflowTask>
    {
        // Tasks do not embed a specific agent assignment; the coordinator/distributor
        // assigns tasks based on the workflow's RequiredAgents and configured distribution strategy.
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

// Execute the workflow
var arguments = new KernelArguments
{
    ["document_path"] = "/path/to/document.pdf",
    ["analysis_type"] = "comprehensive"
};

// Execute the workflow (note the signature: workflow, kernel, arguments)
var result = await coordinator.ExecuteWorkflowAsync(
    workflow,
    kernel,
    arguments,
    CancellationToken.None
);
```

### 簡單工作流程執行

```csharp
// Execute a simple workflow with automatic distribution
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

### 健康監控和容錯

```csharp
// Check agent health status
var healthStatus = coordinator.HealthMonitor.GetAgentHealthStatus("agent-1");
if (healthStatus.Status == AgentHealthStatus.Unhealthy)
{
    // Agent is unhealthy, consider failover
    var failoverResult = await coordinator.AttemptAgentFailoverAsync("agent-1");
    if (failoverResult.Success)
    {
        Console.WriteLine($"Agent failover successful: {failoverResult.NewAgentId}");
    }
}

// Get overall system health
var systemHealth = coordinator.HealthMonitor.GetSystemHealth();
Console.WriteLine($"System health: {systemHealth.OverallStatus}");
Console.WriteLine($"Healthy agents: {systemHealth.HealthyAgentCount}/{systemHealth.TotalAgentCount}");
```

## ResultAggregator

`ResultAggregator` 將多個代理的結果聚合為統一輸出，提供各種聚合策略和結果轉換功能。

### 概述

此組件提供使用可配置策略的智慧結果組合、性能快取和全面的結果驗證。它支持從簡單合併到複雜共識聚合的多種聚合方法。

### 主要特性

* **多種聚合策略**：合併、加權、共識和自訂策略
* **結果快取**：可配置的快取，支持過期和失效
* **結果驗證**：內建驗證和大小限制
* **元資料保留**：保持個別結果元資料和溯源
* **性能最佳化**：高效的聚合演算法和快取
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
// Available built-in strategies (matches library implementation)
public enum AggregationStrategy
{
    Merge = 0,    // Combine all successful results
    Concat = 1,   // Concatenate successful results
    First = 2,    // Use first successful result
    Last = 3,     // Use last successful result
    Majority = 4, // Majority / vote-based aggregation
    Weighted = 5, // Weighted combination based on agent priority or confidence
    Consensus = 6 // Require consensus among agents
}

// Aggregate results using specific strategy
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
// Register custom aggregation strategy
aggregator.RegisterStrategy("custom-merge", new CustomMergeStrategy());

// Custom strategy implementation
public class CustomMergeStrategy : IAggregationStrategy
{
    public async Task<FunctionResult> AggregateAsync(string workflowId, 
        IReadOnlyList<AgentExecutionResult> results)
    {
        // Custom aggregation logic
        var successfulResults = results.Where(r => r.Success).ToList();
        
        if (successfulResults.Count == 0)
        {
            throw new InvalidOperationException("No successful results to aggregate");
        }

        // Custom merge logic
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

### 快取和性能

```csharp
// Check cache statistics
var cacheStats = aggregator.GetCacheStatistics();
Console.WriteLine($"Cache size: {cacheStats["CacheSize"]}");
Console.WriteLine($"Active entries: {cacheStats["ActiveEntries"]}");
Console.WriteLine($"Expired entries: {cacheStats["ExpiredEntries"]}");

// Invalidate cache for specific workflow
var invalidatedCount = aggregator.InvalidateCacheForWorkflow("workflow-001");
Console.WriteLine($"Invalidated {invalidatedCount} cache entries");

// Clear entire cache
aggregator.ClearCache();
```

## AgentConnectionPool

`AgentConnectionPool` 管理每個代理的可重用 `IAgentConnection` 實例，在健康連接之間提供公平選擇和基本的健康感知租用語義。

### 概述

此執行緒安全的池為遠端代理通信提供高效的連接管理，具有健康監控、負載均衡和自動連接生命週期管理。它支持本地和遠端代理連接，具有可配置的池化策略。

### 主要特性

* **連接池**：代理連接的高效重用
* **健康感知選擇**：自動篩選不健康的連接
* **負載均衡**：輪詢和基於健康狀況的連接選擇
* **執行緒安全**：具有適當同步的並行存取
* **指標整合**：內建性能和健康指標
* **自動清理**：連接処理和資源管理

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
// Register connections for an agent
var connection1 = new MockAgentConnection("agent-1", "instance-1");
var connection2 = new MockAgentConnection("agent-1", "instance-2");

// The public API on the pool is `Register` and `RentAsync`
connectionPool.Register("agent-1", connection1);
connectionPool.Register("agent-1", connection2);

// Rent a connection for use
var rented = await connectionPool.RentAsync("agent-1", CancellationToken.None);
if (rented != null)
{
    try
    {
        // Use the connection's Executor to perform the work
        var execResult = await rented.Executor.ExecuteAsync(kernel, workItem.Arguments, CancellationToken.None);
        Console.WriteLine($"Execution result: {execResult.GetValue<object>()}");
    }
    finally
    {
        // Return connection resources by disposing the connection when done
        await rented.DisposeAsync();
    }
}
```

### 連接健康和指標

```csharp
// Inspect registered connection counts (public pool API exposes registration counts)
var counts = connectionPool.GetRegisteredConnectionCounts();
Console.WriteLine($"Registered connections for agent-1: {counts.GetValueOrDefault("agent-1", 0)}");

// Rent a connection and optionally probe its health via the connection's IsHealthyAsync API
var rented = await connectionPool.RentAsync("agent-1", CancellationToken.None);
if (rented != null)
{
    try
    {
        // Probe health (the pool itself will also use health probes internally)
        var isHealthy = await rented.IsHealthyAsync(CancellationToken.None);
        Console.WriteLine($"Rented connection {rented.Endpoint ?? rented.Executor.Name} healthy: {isHealthy}");
    }
    finally
    {
        await rented.DisposeAsync();
    }
}
```

### 連接介面

```csharp
// The pool's public contract for reusable remote connections
public interface IAgentConnection : IAsyncDisposable
{
    string AgentId { get; }
    IGraphExecutor Executor { get; }
    string? Endpoint { get; }
    Task<bool> IsHealthyAsync(CancellationToken cancellationToken = default);
}

// Minimal example connection used for documentation only
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

`WorkDistributor` 根據配置的策略在多個代理之間分配工作項，提供負載均衡、容量管理和工作項優先化。

### 概述

此組件實現考慮代理能力、當前負載和配置策略的智慧工作分配演算法。它支持多種分配方法，並提供全面的指標用於監控和最佳化。

### 主要特性

* **多種分配策略**：RoundRobin、LoadBased、RoleBased、CapacityBased
* **負載均衡**：根據代理容量和當前負載自動分配
* **優先化支持**：工作項優先化和排程
* **容量管理**：動態代理容量追蹤和更新
* **指標整合**：全面的分配指標和監控
* **策略後備**：自動後備到替代分配方法

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
// Available distribution strategies
public enum WorkDistributionStrategy
{
    RoundRobin = 0,      // Distribute work in round-robin fashion
    LoadBased = 1,       // Distribute based on current agent load
    RoleBased = 2,       // Distribute based on agent roles and capabilities
    CapacityBased = 3,   // Distribute based on agent capacity
    Custom = 4           // Custom distribution logic
}

// Distribute work for a workflow
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
// Update agent capacity information
var capacity = new AgentCapacity
{
    AgentId = "agent-1",
    MaxCapacity = 10,
    CurrentLoad = 3,
    Capabilities = { "text_processing", "data_analysis" },
    Metadata = { ["region"] = "us-east", ["version"] = "1.0" }
};

workDistributor.UpdateAgentCapacity("agent-1", capacity);

// Get capacity information
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

// Work item status enumeration
public enum WorkItemStatus
{
    Pending = 0,      // Work item is pending execution
    InProgress = 1,   // Work item is currently being executed
    Completed = 2,    // Work item completed successfully
    Failed = 3,       // Work item failed during execution
    Cancelled = 4     // Work item was cancelled
}
```

### 指標和監控

```csharp
// Get distribution metrics
var metrics = workDistributor.GetDistributionMetrics();
Console.WriteLine($"Distribution requests: {metrics.DistributionRequests}");
Console.WriteLine($"Distribution items: {metrics.DistributionItems}");
Console.WriteLine($"Strategy fallbacks: {metrics.StrategyFallbacks}");
Console.WriteLine($"Distribution errors: {metrics.DistributionErrors}");

// Get agent assignment statistics
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
// Agent instance representing a running agent
public sealed class AgentInstance : IDisposable
{
    public string AgentId { get; }
    public AgentRole Role { get; }
    public GraphState State { get; set; }
    public AgentStatus Status { get; set; }
    public DateTimeOffset CreatedAt { get; }
    public DateTimeOffset LastActivity { get; set; }
}

// Agent role definition
public sealed class AgentRole
{
    public required string Name { get; set; }
    public string? Description { get; set; }
    public int Priority { get; set; } = 0;
    public HashSet<string> Capabilities { get; set; } = new();
    public HashSet<string> Specializations { get; set; } = new();
    public Dictionary<string, object> Metadata { get; set; } = new();
}

// Agent status enumeration
public enum AgentStatus
{
    Idle = 0,         // Agent is idle and ready for work
    Running = 1,      // Agent is currently executing work
    Stopping = 2,     // Agent is in the process of stopping
    Stopped = 3,      // Agent has been stopped
    Failed = 4,       // Agent has failed
    Disposed = 5      // Agent has been disposed
}
```

### 工作流程類型

```csharp
// Multi-agent workflow definition
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

// Workflow task definition
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
// Multi-agent workflow result
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

// Individual agent execution result
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

// Aggregated result
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

* [多代理和共享狀態指南](../how-to/multi-agent-and-shared-state.md) - 實現多代理工作流程的全面指南
* [狀態和序列化參考](state-and-serialization.md) - 代理協調的狀態管理
* [錯誤策略參考](error-policies.md) - 多代理系統中的錯誤處理和恢復力
* [Graph Executor 參考](graph-executor.md) - 個別代理的核心執行引擎
* [整合參考](integration.md) - 多代理工作流程的外部系統整合
* [多代理範例](../examples/multi-agent-examples.md) - 多代理實現的實踐範例
