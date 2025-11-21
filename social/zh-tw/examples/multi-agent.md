# 多代理示例

此示例演示了 Semantic Kernel Graph 中的多代理協調功能，展示如何使用多個協調代理創建、配置和執行工作流程。

## 目標

學習如何在基於圖的工作流程中實現多代理協調：
* 創建和管理具有特定功能的專業化代理
* 使用不同的策略在多個代理之間分配工作
* 使用明確的任務定義協調複雜的工作流程
* 監控代理健康狀況和系統性能
* 使用各種策略聚合多個代理的結果

## 先決條件

* **.NET 8.0** 或更高版本
* **OpenAI API 金鑰**在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 基本了解 [Graph 概念](../concepts/graph-concepts.md) 和 [多代理協調](../how-to/multi-agent-and-shared-state.md)
* 熟悉 [工作流程管理](../concepts/execution.md)

## 主要組件

### 概念和技術

* **多代理協調**：在協調的工作流程中管理多個專業化代理
* **工作分配**：在代理之間自動和手動分配任務
* **功能管理**：定義和要求特定的代理功能
* **健康監控**：跟蹤代理狀態和系統性能
* **結果聚合**：使用各種策略從多個代理組合結果

### 核心類別

* `MultiAgentCoordinator`：用於管理多個代理的主要協調器
* `AgentInstance`：具有特定功能的個別代理實例
* `MultiAgentOptions`：協調行為的配置選項
* `WorkflowBuilder`：用於創建複雜工作流程的建造者模式
* `AgentHealthMonitor`：監控代理健康狀況和系統狀態

## 運行示例

### 開始使用

此示例演示了 Semantic Kernel Graph 套件的多代理協調和工作流程編排。下面的程式碼片段展示了如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 創建多代理協調器

示例首先創建具有自訂配置選項的協調器。

```csharp
// Create coordinator options used to configure multi-agent behavior.
// Comments explain each setting so readers can adapt them safely.
var options = new MultiAgentOptions
{
    // Maximum number of agents that may run concurrently.
    MaxConcurrentAgents = 5,

    // Overall timeout for coordination operations.
    CoordinationTimeout = TimeSpan.FromMinutes(10),

    // Configuration for shared state handling between agents.
    SharedStateOptions = new SharedStateOptions
    {
        ConflictResolutionStrategy = ConflictResolutionStrategy.Merge,
        AllowOverwrite = true
    },

    // How work is distributed among agents (role-based, round-robin, etc.).
    WorkDistributionOptions = new WorkDistributionOptions
    {
        DistributionStrategy = WorkDistributionStrategy.RoleBased,
        EnablePrioritization = true
    },

    // How results from multiple agents are aggregated.
    ResultAggregationOptions = new ResultAggregationOptions
    {
        DefaultAggregationStrategy = AggregationStrategy.Consensus,
        ConsensusThreshold = 0.6
    }
};

// Create the coordinator instance using the options above. The loggerFactory
// symbol is assumed to be available in the surrounding example application
// (it's shown elsewhere in the docs). Use a real ILoggerFactory in production.
using var coordinator = new MultiAgentCoordinator(options,
    new SemanticKernelGraphLogger(loggerFactory.CreateLogger<SemanticKernelGraphLogger>(), new GraphOptions()));
```

### 2. 基本多代理場景

#### 創建專業化代理

```csharp
// Create and register specialized agents used by this example. Each helper
// method returns an AgentInstance already registered with the coordinator.
var analysisAgent = await CreateAnalysisAgentAsync(coordinator, kernel, loggerFactory);
var processingAgent = await CreateProcessingAgentAsync(coordinator, kernel, loggerFactory);
var reportingAgent = await CreateReportingAgentAsync(coordinator, kernel, loggerFactory);

// Prepare kernel arguments that will be passed to the workflow. Use explicit
// keys so downstream functions can retrieve values safely.
var arguments = new KernelArguments
{
    ["input_text"] = "The quick brown fox jumps over the lazy dog. This is a sample text for analysis.",
    ["analysis_type"] = "comprehensive",
    ["output_format"] = "detailed_report"
};

// Execute a small workflow with automatic distribution and merge aggregation.
// The coordinator will dispatch tasks to the registered agents as required.
var result = await coordinator.ExecuteSimpleWorkflowAsync(
    kernel,
    arguments,
    new[] { analysisAgent.AgentId, processingAgent.AgentId, reportingAgent.AgentId },
    AggregationStrategy.Merge
);
```

#### 代理創建示例

```csharp
private static async Task<AgentInstance> CreateAnalysisAgentAsync(
    MultiAgentCoordinator coordinator,
    Kernel kernel,
    ILoggerFactory loggerFactory)
{
    // Create a GraphExecutor configured for analysis tasks. The GraphExecutor
    // is a lightweight example executor used in examples; replace with a real
    // executor implementation in production code.
    var executor = new GraphExecutor(
        "Analysis Graph",
        "Specialized in text analysis",
        new SemanticKernelGraphLogger(loggerFactory.CreateLogger<SemanticKernelGraphLogger>(), new GraphOptions()));

    // Create a single analysis node that wraps a Kernel function. We set
    // storage and metadata to guide downstream agents and relax strict prompt
    // validation for examples.
    var analysisNode = new FunctionGraphNode(CreateAnalysisFunction(kernel), "analyze-text", "Text Analysis");
    analysisNode.StoreResultAs("input");
    analysisNode.SetMetadata("StrictValidation", false);

    executor.AddNode(analysisNode);
    executor.SetStartNode(analysisNode.NodeId);

    // Register the agent with the coordinator. Capabilities help the
    // coordinator select suitable agents for tasks.
    var agent = await coordinator.RegisterAgentAsync(
        agentId: "analysis-agent",
        name: "Text Analysis Agent",
        description: "Specialized in comprehensive text analysis",
        executor: executor,
        capabilities: new[] { "text-analysis", "pattern-recognition", "insight-extraction" },
        metadata: new Dictionary<string, object>
        {
            ["specialization"] = "text_analysis",
            ["version"] = "1.0",
            ["performance_profile"] = "high_accuracy"
        });

    return agent;
}
```

### 3. 進階工作流程場景

進階工作流程使用具有明確任務定義的建造者模式。

```csharp
// Build a complex workflow using the coordinator's fluent builder. The
// builder allows declaring required agents, tasks, parameters, and
// aggregation strategies in a readable way.
var workflow = coordinator.CreateWorkflow("advanced-analysis", "Advanced Text Analysis Workflow")
    .WithDescription("Comprehensive text analysis using multiple specialized agents")
    .RequireAgents("analysis-agent", "processing-agent", "reporting-agent")
    .AddTask("analyze-content", "Content Analysis", task => task
        .WithDescription("Analyze text content for patterns and insights")
        .WithPriority(10)
        .RequireCapabilities("text-analysis", "pattern-recognition")
        .WithParameter("analysis_depth", "deep")
        .WithEstimatedDuration(TimeSpan.FromMinutes(2)))
    .AddTask("process-results", "Result Processing", task => task
        .WithDescription("Process analysis results and extract key findings")
        .WithPriority(8)
        .RequireCapabilities("data-processing", "extraction")
        .WithParameter("processing_mode", "comprehensive")
        .WithEstimatedDuration(TimeSpan.FromMinutes(3)))
    .AddTask("generate-report", "Report Generation", task => task
        .WithDescription("Generate comprehensive report from processed data")
        .WithPriority(5)
        .RequireCapabilities("report-generation", "formatting")
        .WithParameter("report_format", "executive_summary")
        .WithEstimatedDuration(TimeSpan.FromMinutes(1)))
    .WithAggregationStrategy(AggregationStrategy.Weighted)
    .WithMetadata("workflow_type", "analysis")
    .WithMetadata("complexity", "high")
    .Build();

// Prepare arguments for the workflow. Keep keys explicit and documented so
// tasks can read them without ambiguity.
var arguments = new KernelArguments
{
    ["document_content"] = GetSampleDocument(),
    ["analysis_requirements"] = "sentiment, topics, key_phrases, entities",
    ["output_preferences"] = "json_structured"
};

// Execute the workflow and await the aggregated result.
var result = await coordinator.ExecuteWorkflowAsync(workflow, kernel, arguments);
```

### 4. 健康監控場景

健康監控場景跟蹤代理狀態和系統性能。

```csharp
// Retrieve all registered agents for monitoring and diagnostics.
var agents = coordinator.GetAllAgents();
logger.LogInformation($"Monitoring {agents.Count} agents...");

// Iterate agents and perform synchronous and asynchronous health checks.
foreach (var agent in agents)
{
    // Get cached or computed health status for quick inspection.
    var healthStatus = agent.GetHealthStatus(coordinator);
    logger.LogInformation($"Agent {agent.AgentId}: {healthStatus?.Status ?? HealthStatus.Unknown}");

    // Perform an explicit health check which may perform network or runtime checks.
    var healthCheck = await agent.PerformHealthCheckAsync(coordinator);
    logger.LogInformation($"  Health Check: {(healthCheck.Success ? "Passed" : "Failed")} " +
                        $"(Response: {healthCheck.ResponseTime.TotalMilliseconds:F2} ms)");
}

// Log aggregated system health metrics from the coordinator's monitor.
var healthMonitor = coordinator.HealthMonitor;
logger.LogInformation($"System Health: {healthMonitor.HealthyAgentCount}/{healthMonitor.MonitoredAgentCount} agents healthy ({healthMonitor.SystemHealthRatio:P})");
```

### 5. 代理函數創建

此示例為不同的代理類型創建了專業化函數。

```csharp
// Create a lightweight KernelFunction used in examples to perform analysis.
// The function reads arguments, performs a small deterministic computation,
// stores results back into the arguments, and returns a human-friendly message.
private static KernelFunction CreateAnalysisFunction(Kernel kernel)
{
    return KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            // Safely read the input text and analysis type from arguments.
            var input = args.TryGetValue("input_text", out var i) ? i?.ToString() ?? string.Empty : string.Empty;
            var analysisType = args.TryGetValue("analysis_type", out var a) ? a?.ToString() ?? "basic" : "basic";

            // Simulate a simple analysis result. In real scenarios replace with
            // calls to LLMs or other processing components.
            var analysisResult = new
            {
                TextLength = input.Length,
                WordCount = input.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length,
                AnalysisType = analysisType,
                Insights = new[] { "Sample insight 1", "Sample insight 2" },
                Confidence = 0.95
            };

            // Store the result so downstream tasks can use it.
            args["analysis_result"] = analysisResult;
            return $"Analysis completed: {analysisResult.WordCount} words, {analysisResult.Insights.Length} insights";
        },
        functionName: "analyze_text",
        description: "Performs comprehensive text analysis"
    );
}

// Create a processing function that consumes the analysis result and prepares
// a richer processed result for reporting or aggregation.
private static KernelFunction CreateProcessingFunction(Kernel kernel)
{
    return KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var analysisResult = args.TryGetValue("analysis_result", out var ar) ? ar : null;

            // Simulate enhancement of insights and metadata tagging.
            var processedResult = new
            {
                ProcessedAt = DateTime.UtcNow,
                EnhancedInsights = new[] { "Enhanced insight 1", "Enhanced insight 2", "Enhanced insight 3" },
                ProcessingQuality = "high",
                Metadata = new { Source = "analysis_agent", Version = "1.0" }
            };

            // Store processed result for later tasks.
            args["processed_result"] = processedResult;
            return $"Processing completed: {processedResult.EnhancedInsights.Length} enhanced insights";
        },
        functionName: "process_analysis",
        description: "Processes analysis results and enhances insights"
    );
}
```

### 6. 工作流程結果日誌記錄

此示例包括工作流程執行的全面結果日誌記錄。

```csharp
// Helper to log a WorkflowExecutionResult in a concise, human-friendly way.
// This function shows success, timing, agents involved, aggregated result and
// a sample of errors if present.
private static void LogWorkflowResult(WorkflowExecutionResult result, ILogger logger)
{
    logger.LogInformation("\nWorkflow Execution Results:");
    logger.LogInformation($"  Success: {result.Success}");
    logger.LogInformation($"  Execution ID: {result.ExecutionId}");
    logger.LogInformation($"  Duration: {result.Duration.TotalMilliseconds:F2} ms");
    logger.LogInformation($"  Agents Used: {result.AgentsUsed.Count}");

    foreach (var agent in result.AgentsUsed)
    {
        logger.LogInformation($"    - {agent.AgentId}: {agent.Status}");
    }

    if (result.AggregatedResult != null)
    {
        logger.LogInformation($"  Aggregated Result: {result.AggregatedResult}");
    }

    if (result.Errors.Any())
    {
        logger.LogInformation($"  Errors (showing up to 3): {result.Errors.Count}");
        foreach (var error in result.Errors.Take(3))
        {
            logger.LogInformation($"    - {error}");
        }
    }
}
```

## 預期輸出

此示例生成全面的輸出，包括：

* 🤖 多代理協調設置和配置
* 📋 具有任務分配的基本多代理場景
* 🔄 具有明確任務定義的進階工作流程
* 🏥 健康監控和代理狀態跟蹤
* 📊 工作流程執行結果和性能指標
* ✅ 多個專業化代理之間的成功協調

## 故障排除

### 常見問題

1. **代理註冊失敗**：確保代理 ID 是唯一的並且功能已正確定義
2. **工作流程執行錯誤**：檢查所需的代理和功能是否可用
3. **健康檢查失敗**：驗證代理連接和資源可用性
4. **協調超時**：調整複雜工作流程的超時設置

### 調試提示

* 啟用詳細日誌記錄以追蹤代理交互
* 監控代理健康狀況和性能指標
* 驗證工作流程要求和代理功能是否匹配
* 檢查協調超時和並發設置

## 另請參閱

* [多代理和共享狀態](../how-to/multi-agent-and-shared-state.md)
* [工作流程管理](../concepts/execution.md)
* [代理協調](../concepts/agent-coordination.md)
* [健康監控](../how-to/health-monitoring.md)
* [結果聚合](../concepts/result-aggregation.md)
