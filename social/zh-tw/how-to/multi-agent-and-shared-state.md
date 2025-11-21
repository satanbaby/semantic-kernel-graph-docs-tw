# 多代理和共享狀態

SemanticKernel.Graph 中的多代理協調和共享狀態管理能夠實現複雜的工作流，其中多個專業代理在共享任務上協作。本指南涵蓋代理協調、共享狀態管理、衝突解決策略和版本管理機制。

## 您將學到的內容

* 如何建立和協調多個專業代理
* 使用衝突解決的代理間共享狀態管理
* 實現不同的工作分配策略
* 處理代理故障和健康監控
* 多代理工作流設計的最佳實踐

## 概念和技術

**MultiAgentCoordinator**：中央協調器，管理代理生命週期、跨多個圖形執行器實例的工作分配和結果彙總。

**SharedStateManager**：線程安全的狀態同步管理器，處理協作代理之間的衝突、版本管理和狀態持久化。

**Conflict Resolution Strategies**：可配置的狀態衝突解決策略，包括 LastWriterWins、FirstWriterWins、Merge 和 AgentPriority 方法。

**Work Distribution**：智能任務分配策略，包括 RoundRobin、LoadBased、RoleBased 和 CapacityBased 分配。

**Agent Health Monitoring**：用於彈性多代理執行的斷路器模式和故障轉移機制。

## 前置要求

* [第一個圖形教程](../first-graph-5-minutes.md)已完成
* 理解 [Graph 概念](../concepts/graph-concepts.md)
* 熟悉 [狀態管理](state-tutorial.md)
* 基本並發程式設計概念知識

## 多代理架構

### 核心元件

多代理系統由幾個關鍵元件組成：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Integration;

// 多代理協調器協調所有代理
var coordinator = new MultiAgentCoordinator(options);

// 共享狀態管理器處理狀態同步
var sharedStateManager = new SharedStateManager(sharedStateOptions);

// 工作分配器將任務分配給代理
var workDistributor = new WorkDistributor(distributionOptions);

// 結果彙總器組合代理輸出
var resultAggregator = new ResultAggregator(aggregationOptions);
```

### 代理類型和角色

定義具有特定功能的專業代理：

```csharp
public class AgentRole
{
    public string Name { get; set; } = string.Empty;
    public int Priority { get; set; } = 5;
    public List<string> Capabilities { get; set; } = new();
    public Dictionary<string, object> Configuration { get; set; } = new();
}

// 代理角色範例
var analysisAgentRole = new AgentRole
{
    Name = "Data Analyst",
    Priority = 7,
    Capabilities = { "text_analysis", "data_extraction", "pattern_recognition" },
    Configuration = { ["max_text_length"] = 10000 }
};

var processingAgentRole = new AgentRole
{
    Name = "Data Processor",
    Priority = 6,
    Capabilities = { "data_transformation", "validation", "enrichment" },
    Configuration = { ["batch_size"] = 1000 }
};

var reportingAgentRole = new AgentRole
{
    Name = "Report Generator",
    Priority = 5,
    Capabilities = { "report_generation", "formatting", "export" },
    Configuration = { ["output_formats"] = new[] { "json", "csv", "pdf" } }
};
```

## 建立多代理工作流

### 基本多代理設置

建立簡單的多代理工作流：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;

// 配置多代理選項
var multiAgentOptions = new MultiAgentOptions
{
    MaxConcurrentAgents = 5,
    CoordinationTimeout = TimeSpan.FromMinutes(10),
    EnableDistributedTracing = true,
    EnableAgentFailover = true,
    MaxFailoverAttempts = 3
};

// 配置共享狀態選項
var sharedStateOptions = new SharedStateOptions
{
    ConflictResolutionStrategy = ConflictResolutionStrategy.Merge,
    AllowOverwrite = true,
    MinimumPriorityForOverride = 5,
    EnableAutomaticCleanup = true,
    CleanupInterval = TimeSpan.FromMinutes(30),
    StateRetentionPeriod = TimeSpan.FromHours(6)
};

// 配置工作分配選項
var workDistributionOptions = new WorkDistributionOptions
{
    DistributionStrategy = WorkDistributionStrategy.RoleBased,
    EnablePrioritization = true,
    MaxParallelWorkItems = 3,
    LoadBalancingThreshold = 0.8
};

// 配置結果彙總選項
var resultAggregationOptions = new ResultAggregationOptions
{
    DefaultAggregationStrategy = AggregationStrategy.Consensus,
    ConsensusThreshold = 0.6,
    EnableConflictResolution = true,
    MaxAggregationTime = TimeSpan.FromMinutes(5)
};

// 使用所有選項建立協調器
var coordinator = new MultiAgentCoordinator(
    new MultiAgentOptions
    {
        SharedStateOptions = sharedStateOptions,
        WorkDistributionOptions = workDistributionOptions,
        ResultAggregationOptions = resultAggregationOptions
    },
    logger
);
```

### 代理註冊

向協調器註冊代理：

```csharp
// 建立和註冊分析代理
var analysisAgent = new AgentInstance(
    "analysis-agent-001",
    "Data Analysis Specialist",
    analysisAgentRole,
    analysisGraph,
    new GraphState()
);

await coordinator.RegisterAgentAsync(analysisAgent);

// 建立和註冊處理代理
var processingAgent = new AgentInstance(
    "processing-agent-001",
    "Data Processing Specialist",
    processingAgentRole,
    processingGraph,
    new GraphState()
);

await coordinator.RegisterAgentAsync(processingAgent);

// 建立和註冊報告代理
var reportingAgent = new AgentInstance(
    "reporting-agent-001",
    "Report Generation Specialist",
    reportingAgentRole,
    reportingGraph,
    new GraphState()
);

await coordinator.RegisterAgentAsync(reportingAgent);
```

### 簡單工作流執行

使用自動任務分配執行基本工作流：

```csharp
// 準備輸入參數
var arguments = new KernelArguments
{
    ["input_text"] = "The quick brown fox jumps over the lazy dog. This is a sample text for analysis.",
    ["analysis_type"] = "comprehensive",
    ["output_format"] = "detailed_report"
};

// 使用指定的代理執行工作流
var result = await coordinator.ExecuteSimpleWorkflowAsync(
    kernel,
    arguments,
    new[] { "analysis-agent-001", "processing-agent-001", "reporting-agent-001" },
    AggregationStrategy.Merge
);

// 檢查結果
if (result.Success)
{
    Console.WriteLine($"工作流完成於 {result.Duration.TotalMilliseconds}ms");
    Console.WriteLine($"最終結果：{result.AggregatedResult}");
    Console.WriteLine($"涉及的代理：{string.Join(", ", result.AgentsInvolved)}");
}
else
{
    Console.WriteLine($"工作流失敗：{result.Error?.Message}");
}
```

## 進階工作流定義

### 具有依賴關係的複雜工作流

建立具有明確任務依賴關係的工作流：

```csharp
// 定義具有依賴關係的工作流任務
var workflow = new MultiAgentWorkflow
{
    Id = "document-analysis-workflow",
    Name = "Document Analysis and Reporting",
    Description = "多階段文件處理工作流",
    RequiredAgents = { "analysis-agent-001", "processing-agent-001", "reporting-agent-001" },
    Tasks = new List<WorkflowTask>
    {
        new WorkflowTask
        {
            Id = "text-extraction",
            Name = "Extract Text Content",
            Description = "提取和清理輸入文件中的文字",
            AgentId = "analysis-agent-001",
            RequiredCapabilities = { "text_analysis", "data_extraction" },
            DependsOn = new List<string>(), // 沒有依賴關係
            Priority = 1
        },
        new WorkflowTask
        {
            Id = "content-analysis",
            Name = "Analyze Content",
            Description = "執行語義分析並提取見解",
            AgentId = "analysis-agent-001",
            RequiredCapabilities = { "text_analysis", "pattern_recognition" },
            DependsOn = { "text-extraction" },
            Priority = 2
        },
        new WorkflowTask
        {
            Id = "data-enrichment",
            Name = "Enrich Data",
            Description = "添加元資料和增強提取的資訊",
            AgentId = "processing-agent-001",
            RequiredCapabilities = { "data_transformation", "enrichment" },
            DependsOn = { "content-analysis" },
            Priority = 3
        },
        new WorkflowTask
        {
            Id = "report-generation",
            Name = "Generate Report",
            Description = "建立所請求格式的最終報告",
            AgentId = "reporting-agent-001",
            RequiredCapabilities = { "report_generation", "formatting" },
            DependsOn = { "data-enrichment" },
            Priority = 4
        }
    },
    AggregationStrategy = AggregationStrategy.Sequential
};

// 執行複雜工作流
var result = await coordinator.ExecuteWorkflowAsync(workflow, kernel, arguments);
```

### 自訂工作流構建器

為複雜場景使用流暢的工作流構建器：

```csharp
var workflow = MultiAgentWorkflowBuilder
    .Create("advanced-workflow")
    .WithDescription("具有自訂邏輯的進階多代理工作流")
    .RequiringAgents("analysis-agent-001", "processing-agent-001", "reporting-agent-001")
    .WithTask("extract", "Text Extraction")
        .AssignedTo("analysis-agent-001")
        .WithCapabilities("text_analysis", "data_extraction")
        .WithPriority(1)
        .Build()
    .WithTask("analyze", "Content Analysis")
        .AssignedTo("analysis-agent-001")
        .WithCapabilities("text_analysis", "pattern_recognition")
        .DependsOn("extract")
        .WithPriority(2)
        .Build()
    .WithTask("enrich", "Data Enrichment")
        .AssignedTo("processing-agent-001")
        .WithCapabilities("data_transformation", "enrichment")
        .DependsOn("analyze")
        .WithPriority(3)
        .Build()
    .WithTask("report", "Report Generation")
        .AssignedTo("reporting-agent-001")
        .WithCapabilities("report_generation", "formatting")
        .DependsOn("enrich")
        .WithPriority(4)
        .Build()
    .WithAggregationStrategy(AggregationStrategy.Sequential)
    .Build();
```

## 共享狀態管理

### 狀態初始化和存取

初始化工作流的共享狀態：

```csharp
// 初始化工作流的共享狀態
await coordinator.SharedStateManager.InitializeWorkflowStateAsync(
    "workflow-001",
    new GraphState
    {
        ["workflow_id"] = "workflow-001",
        ["start_time"] = DateTimeOffset.UtcNow,
        ["status"] = "running"
    }
);

// 取得目前共享狀態
var sharedState = await coordinator.SharedStateManager.GetSharedStateAsync("workflow-001");

// 存取共享狀態值
var workflowId = sharedState.GetValue<string>("workflow_id");
var startTime = sharedState.GetValue<DateTimeOffset>("start_time");
var status = sharedState.GetValue<string>("status");
```

### 狀態更新和衝突解決

使用自動衝突解決更新共享狀態：

```csharp
// 從代理更新共享狀態
var updatedState = new GraphState();
updatedState.Set("analysis_results", analysisResults);
updatedState.Set("processing_status", "completed");
updatedState.Set("last_updated", DateTimeOffset.UtcNow);

// 更新共享狀態（自動解決衝突）
await coordinator.SharedStateManager.UpdateSharedStateAsync(
    "workflow-001",
    "analysis-agent-001",
    updatedState
);

// 取得更新後的狀態
var currentState = await coordinator.SharedStateManager.GetSharedStateAsync("workflow-001");
```

### 衝突解決策略

配置不同的衝突解決方法：

```csharp
// 最後寫入者贏（高優先順序更新的預設值）
var lastWriterWinsOptions = new SharedStateOptions
{
    ConflictResolutionStrategy = ConflictResolutionStrategy.LastWriterWins,
    AllowOverwrite = true
};

// 第一寫入者贏（保留初始值）
var firstWriterWinsOptions = new SharedStateOptions
{
    ConflictResolutionStrategy = ConflictResolutionStrategy.FirstWriterWins,
    AllowOverwrite = false
};

// 合併策略（智能組合變更）
var mergeOptions = new SharedStateOptions
{
    ConflictResolutionStrategy = ConflictResolutionStrategy.Merge,
    AllowOverwrite = true
};

// 代理優先順序（較高優先順序的代理可以覆蓋）
var priorityOptions = new SharedStateOptions
{
    ConflictResolutionStrategy = ConflictResolutionStrategy.AgentPriority,
    MinimumPriorityForOverride = 7,
    AllowOverwrite = true
};
```

## 工作分配策略

### 輪詢分配

在代理之間均勻分配工作：

```csharp
var roundRobinOptions = new WorkDistributionOptions
{
    DistributionStrategy = WorkDistributionStrategy.RoundRobin,
    EnablePrioritization = false,
    MaxParallelWorkItems = 5
};

// 工作按順序分配：Agent1、Agent2、Agent3、Agent1、Agent2...
```

### 基於負載的分配

根據代理負載分配工作：

```csharp
var loadBasedOptions = new WorkDistributionOptions
{
    DistributionStrategy = WorkDistributionStrategy.LoadBased,
    LoadBalancingThreshold = 0.8,
    MaxParallelWorkItems = 3
};

// 工作分配給當前負載最低的代理
```

### 基於角色的分配

根據代理功能分配工作：

```csharp
var roleBasedOptions = new WorkDistributionOptions
{
    DistributionStrategy = WorkDistributionStrategy.RoleBased,
    EnablePrioritization = true,
    MaxParallelWorkItems = 4
};

// 工作分配給具有匹配功能的代理
```

### 基於容量的分配

考慮代理容量和健康狀態：

```csharp
var capacityBasedOptions = new WorkDistributionOptions
{
    DistributionStrategy = WorkDistributionStrategy.CapacityBased,
    EnablePrioritization = true,
    MaxParallelWorkItems = 2
};

// 考慮代理容量、健康狀態和目前工作負荷進行任務分配
```

## 結果彙總

### 彙總策略

配置代理結果的組合方式：

```csharp
// 合併所有結果（預設值）
var mergeOptions = new ResultAggregationOptions
{
    DefaultAggregationStrategy = AggregationStrategy.Merge,
    EnableConflictResolution = true
};

// 基於共識的彙總
var consensusOptions = new ResultAggregationOptions
{
    DefaultAggregationStrategy = AggregationStrategy.Consensus,
    ConsensusThreshold = 0.7,
    EnableConflictResolution = true
};

// 加權彙總
var weightedOptions = new ResultAggregationOptions
{
    DefaultAggregationStrategy = AggregationStrategy.Weighted,
    EnableConflictResolution = true
};

// 順序彙總
var sequentialOptions = new ResultAggregationOptions
{
    DefaultAggregationStrategy = AggregationStrategy.Sequential,
    EnableConflictResolution = false
};
```

### 自訂彙總邏輯

實現自訂彙總策略：

```csharp
public class CustomAggregator : IResultAggregator
{
    public async Task<AggregationResult> AggregateResultsAsync(
        string workflowId,
        IReadOnlyList<AgentExecutionResult> results,
        AggregationStrategy strategy)
    {
        // 自訂彙總邏輯
        var aggregatedData = new Dictionary<string, object>();
        
        foreach (var result in results)
        {
            if (result.Success && result.Result != null)
            {
                // 根據自訂邏輯合併結果
                foreach (var kvp in result.Result)
                {
                    if (!aggregatedData.ContainsKey(kvp.Key))
                    {
                        aggregatedData[kvp.Key] = kvp.Value;
                    }
                    else
                    {
                        // 自訂合併邏輯
                        aggregatedData[kvp.Key] = MergeValues(aggregatedData[kvp.Key], kvp.Value);
                    }
                }
            }
        }
        
        return new AggregationResult
        {
            Success = true,
            Result = new GraphState(aggregatedData),
            Strategy = strategy,
            AgentCount = results.Count
        };
    }
    
    private object MergeValues(object existing, object newValue)
    {
        // 實現自訂合併邏輯
        if (existing is List<object> existingList && newValue is List<object> newList)
        {
            return existingList.Concat(newList).ToList();
        }
        
        // 預設使用新值
        return newValue;
    }
}
```

## 健康監控和故障轉移

### 代理健康監控

監控代理健康和效能：

```csharp
// 配置健康監控
var healthOptions = new AgentHealthMonitorOptions
{
    EnableAgentCircuitBreaker = true,
    CircuitBreakerThreshold = 5,
    CircuitBreakerTimeout = TimeSpan.FromMinutes(5),
    HealthCheckInterval = TimeSpan.FromSeconds(30),
    MaxConsecutiveFailures = 3
};

// 取得代理健康狀態
var healthStatus = coordinator.HealthMonitor.GetAgentHealth("analysis-agent-001");
if (healthStatus?.IsHealthy == true)
{
    Console.WriteLine($"代理 {healthStatus.AgentId} 狀態良好");
    Console.WriteLine($"最後成功執行：{healthStatus.LastSuccessfulExecution}");
    Console.WriteLine($"成功率：{healthStatus.SuccessRate:P2}");
}
else
{
    Console.WriteLine($"代理 {healthStatus?.AgentId} 狀態不良");
    Console.WriteLine($"斷路器狀態：{healthStatus?.CircuitBreakerStatus}");
    Console.WriteLine($"最後錯誤：{healthStatus?.LastError?.Message}");
}
```

### 自動故障轉移

配置代理故障時的自動故障轉移：

```csharp
var failoverOptions = new MultiAgentOptions
{
    EnableAgentFailover = true,
    MaxFailoverAttempts = 3,
    CoordinationTimeout = TimeSpan.FromMinutes(10)
};

// 當代理故障時，協調器會自動嘗試具有匹配功能的替代代理
```

## 進階模式

### 具有依賴關係的並行執行

當依賴關係允許時以並行執行任務：

```csharp
var workflow = MultiAgentWorkflowBuilder
    .Create("parallel-workflow")
    .RequiringAgents("agent-1", "agent-2", "agent-3", "agent-4")
    .WithTask("task-a", "Task A")
        .AssignedTo("agent-1")
        .Build()
    .WithTask("task-b", "Task B")
        .AssignedTo("agent-2")
        .Build()
    .WithTask("task-c", "Task C")
        .AssignedTo("agent-3")
        .DependsOn("task-a", "task-b") // A 和 B 並行執行，然後執行 C
        .Build()
    .WithTask("task-d", "Task D")
        .AssignedTo("agent-4")
        .DependsOn("task-c")
        .Build()
    .WithAggregationStrategy(AggregationStrategy.Sequential)
    .Build();
```

### 狀態版本管理和歷史

追蹤一段時間內的狀態變更：

```csharp
// 取得狀態版本歷史
var stateHistory = await coordinator.SharedStateManager.GetStateHistoryAsync("workflow-001");

foreach (var version in stateHistory)
{
    Console.WriteLine($"版本 {version.Version}：{version.Timestamp}");
    Console.WriteLine($"更新者：{version.UpdatedBy}");
    Console.WriteLine($"變更：{string.Join(", ", version.Changes)}");
}

// 恢復到特定版本
var restoredState = await coordinator.SharedStateManager.RestoreStateVersionAsync(
    "workflow-001",
    targetVersion
);
```

### 分散式追蹤

在代理間啟用分散式追蹤：

```csharp
var tracingOptions = new MultiAgentOptions
{
    EnableDistributedTracing = true,
    DistributedTracingSourceName = "MyMultiAgentSystem"
};

// 活動在代理間自動建立和關聯
// 使用 Activity.Current 存取目前執行內容
if (Activity.Current != null)
{
    Activity.Current.SetTag("workflow.id", workflowId);
    Activity.Current.SetTag("agent.id", agentId);
    Activity.Current.SetTag("task.id", taskId);
}
```

## 最佳實踐

### 工作流設計

* **任務粒度**：設計既不太小也不太大的任務
* **依賴關係管理**：最小化不必要的依賴關係以最大化並行性
* **代理專業化**：建立具有專注功能而非通用型的代理
* **資源規劃**：設計工作流時考慮代理容量和工作負荷

### 狀態管理

* **衝突解決**：為您的使用案例選擇適當的衝突解決策略
* **狀態大小**：保持共享狀態最小化以減少同步開銷
* **版本管理**：使用狀態版本管理進行稽核追蹤和除錯
* **清理**：配置自動清理以防止記憶體洩漏

### 效能最佳化

* **並行性**：盡可能在依賴關係允許的地方最大化並行執行
* **負載平衡**：為您的工作負荷使用適當的分配策略
* **健康監控**：監控代理健康以防止瓶頸
* **故障轉移**：配置故障轉移以優雅處理代理故障

### 監控和除錯

* **分散式追蹤**：啟用追蹤以獲得端到端可見性
* **指標收集**：監控執行時間和成功率
* **紀錄記錄**：使用結構化紀錄記錄以提高可觀測性
* **健康檢查**：實現全面的健康監控

## 疑難排解

### 常見問題

**代理註冊失敗**：確保在執行工作流之前註冊所有必需的代理。

**狀態衝突**：檢查衝突解決策略，並考慮為關鍵資料使用更特定的策略。

**效能問題**：檢查代理健康、工作負荷分配和並行執行機會。

**故障轉移失敗**：驗證替代代理具有必需的功能並處於健康狀態。

### 除錯多代理工作流

```csharp
// 啟用詳細紀錄記錄
var debugOptions = new MultiAgentOptions
{
    EnableDistributedTracing = true,
    SharedStateOptions = new SharedStateOptions
    {
        EnableAutomaticCleanup = false, // 保持狀態以進行除錯
        StateRetentionPeriod = TimeSpan.FromDays(1)
    }
};

// 監控工作流執行
var workflow = await coordinator.ExecuteWorkflowAsync(workflow, kernel, arguments);

// 檢查單個代理結果
foreach (var result in workflow.Results)
{
    Console.WriteLine($"代理 {result.AgentId}：{(result.Success ? "成功" : "失敗")}");
    if (!result.Success)
    {
        Console.WriteLine($"  錯誤：{result.Error?.Message}");
    }
    Console.WriteLine($"  耗時：{result.Duration.TotalMilliseconds}ms");
}
```

## 另請參閱

* [狀態管理](state-tutorial.md) - 管理圖形狀態和持久化
* [資源治理](resource-governance-and-concurrency.md) - 管理資源配置和執行策略
* [指標和可觀測性](metrics-and-observability.md) - 監控和效能分析
* [範例](../../examples/) - 多代理協調的實際範例

附錄：可執行的範例位於 `semantic-kernel-graph-docs/examples/MultiAgentExample.cs`。若要從範例專案執行，請使用 Program 範例執行器和 `multi-agent` 金鑰，如下所示：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- "multi-agent"
```

## 概念和技術

**MultiAgentCoordinator**：中央協調器，管理代理生命週期、跨多個圖形執行器實例的工作分配和結果彙總。提供協調、故障轉移和健康監控功能。

**SharedStateManager**：線程安全的狀態同步管理器，處理協作代理之間的衝突、版本管理和狀態持久化。支援多種衝突解決策略和自動清理。

**Conflict Resolution Strategies**：可配置的狀態衝突解決策略，包括 LastWriterWins、FirstWriterWins、Merge 和 AgentPriority 方法。每個策略根據業務需求以不同方式處理並發更新。

**Work Distribution**：智能任務分配策略，包括 RoundRobin、LoadBased、RoleBased 和 CapacityBased 分配。考慮代理功能、目前負載和健康狀態進行最優分配。

**Agent Health Monitoring**：用於彈性多代理執行的斷路器模式和故障轉移機制。監控代理效能並自動將工作路由到健康的代理。
