# 多代理範例

此範例示範了 Semantic Kernel Graph 中的多代理協調功能，展示如何創建、配置和執行具有多個協調代理的工作流程。

## 目標

學習如何在基於圖形的工作流程中實現多代理協調，以便：
* 創建和管理具有特定功能的專業化代理
* 使用不同策略在多個代理間分配工作
* 通過顯式任務定義協調複雜工作流程
* 監控代理健康狀況和系統性能
* 使用各種策略聚合來自多個代理的結果

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 密鑰**已在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 對[圖形概念](../concepts/graph-concepts.md)和[多代理協調](../how-to/multi-agent-and-shared-state.md)的基本理解
* 熟悉[工作流程管理](../concepts/execution.md)

## 主要組件

### 概念和技術

* **多代理協調**：在協調工作流程中管理多個專業化代理
* **工作分配**：自動和手動分配任務給各個代理
* **功能管理**：定義和要求特定代理的功能
* **健康監控**：追蹤代理狀態和系統性能
* **結果聚合**：使用各種策略組合來自多個代理的結果

### 核心類別

* `MultiAgentCoordinator`：管理多個代理的主要協調器
* `AgentInstance`：具有特定功能的個別代理實例
* `MultiAgentOptions`：協調行為的配置選項
* `WorkflowBuilder`：用於創建複雜工作流程的構建器模式
* `AgentHealthMonitor`：監控代理健康狀況和系統狀態

## 運行範例

### 開始使用

此範例示範了 Semantic Kernel Graph 套件的多代理協調和工作流程編排。以下代碼片段展示如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. 創建多代理協調器

該範例首先創建一個具有自訂配置選項的協調器。

```csharp
// 創建用於配置多代理行為的協調器選項。
// 註解解釋了每個設置，以便讀者可以安全地調整它們。
var options = new MultiAgentOptions
{
    // 可同時運行的最大代理數量。
    MaxConcurrentAgents = 5,

    // 協調操作的總超時時間。
    CoordinationTimeout = TimeSpan.FromMinutes(10),

    // 代理之間共享狀態處理的配置。
    SharedStateOptions = new SharedStateOptions
    {
        ConflictResolutionStrategy = ConflictResolutionStrategy.Merge,
        AllowOverwrite = true
    },

    // 工作如何在代理間分配（基於角色、輪詢等）。
    WorkDistributionOptions = new WorkDistributionOptions
    {
        DistributionStrategy = WorkDistributionStrategy.RoleBased,
        EnablePrioritization = true
    },

    // 來自多個代理的結果如何聚合。
    ResultAggregationOptions = new ResultAggregationOptions
    {
        DefaultAggregationStrategy = AggregationStrategy.Consensus,
        ConsensusThreshold = 0.6
    }
};

// 使用上述選項創建協調器實例。loggerFactory
// 符號被假定在周圍的範例應用程式中可用
//（在文檔中的其他地方有介紹）。在生產中使用真實的 ILoggerFactory。
using var coordinator = new MultiAgentCoordinator(options,
    new SemanticKernelGraphLogger(loggerFactory.CreateLogger<SemanticKernelGraphLogger>(), new GraphOptions()));
```

### 2. 基本多代理場景

#### 創建專業化代理

```csharp
// 創建並註冊此範例使用的專業化代理。每個輔助
// 方法返回一個已向協調器註冊的 AgentInstance。
var analysisAgent = await CreateAnalysisAgentAsync(coordinator, kernel, loggerFactory);
var processingAgent = await CreateProcessingAgentAsync(coordinator, kernel, loggerFactory);
var reportingAgent = await CreateReportingAgentAsync(coordinator, kernel, loggerFactory);

// 準備將傳遞給工作流程的核心參數。使用顯式
// 鍵，以便下游函數可以安全地檢索值。
var arguments = new KernelArguments
{
    ["input_text"] = "The quick brown fox jumps over the lazy dog. This is a sample text for analysis.",
    ["analysis_type"] = "comprehensive",
    ["output_format"] = "detailed_report"
};

// 執行一個具有自動分配和合併聚合的小型工作流程。
// 協調器將根據需要向已註冊的代理分發任務。
var result = await coordinator.ExecuteSimpleWorkflowAsync(
    kernel,
    arguments,
    new[] { analysisAgent.AgentId, processingAgent.AgentId, reportingAgent.AgentId },
    AggregationStrategy.Merge
);
```

#### 代理創建範例

```csharp
private static async Task<AgentInstance> CreateAnalysisAgentAsync(
    MultiAgentCoordinator coordinator,
    Kernel kernel,
    ILoggerFactory loggerFactory)
{
    // 創建一個為分析任務配置的 GraphExecutor。GraphExecutor
    // 是範例中使用的輕量級範例執行器；在生產代碼中替換為真實的
    // 執行器實現。
    var executor = new GraphExecutor(
        "Analysis Graph",
        "Specialized in text analysis",
        new SemanticKernelGraphLogger(loggerFactory.CreateLogger<SemanticKernelGraphLogger>(), new GraphOptions()));

    // 創建一個包裝 Kernel 函數的單個分析節點。我們設置
    // 存儲和元數據來指導下游代理並放鬆嚴格的提示
    // 對範例的驗證。
    var analysisNode = new FunctionGraphNode(CreateAnalysisFunction(kernel), "analyze-text", "Text Analysis");
    analysisNode.StoreResultAs("input");
    analysisNode.SetMetadata("StrictValidation", false);

    executor.AddNode(analysisNode);
    executor.SetStartNode(analysisNode.NodeId);

    // 向協調器註冊代理。功能幫助協調器
    // 為任務選擇合適的代理。
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

進階工作流程使用具有顯式任務定義的構建器模式。

```csharp
// 使用協調器的流暢構建器構建複雜的工作流程。
// 構建器允許以可讀的方式聲明所需代理、任務、參數和
// 聚合策略。
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

// 準備工作流程的參數。保持鍵明確且文檔完善，以便
// 任務可以毫不含糊地讀取它們。
var arguments = new KernelArguments
{
    ["document_content"] = GetSampleDocument(),
    ["analysis_requirements"] = "sentiment, topics, key_phrases, entities",
    ["output_preferences"] = "json_structured"
};

// 執行工作流程並等待聚合的結果。
var result = await coordinator.ExecuteWorkflowAsync(workflow, kernel, arguments);
```

### 4. 健康監控場景

健康監控場景追蹤代理狀態和系統性能。

```csharp
// 檢索所有已註冊的代理以進行監控和診斷。
var agents = coordinator.GetAllAgents();
logger.LogInformation($"Monitoring {agents.Count} agents...");

// 遍歷代理並執行同步和異步健康檢查。
foreach (var agent in agents)
{
    // 獲取快速檢查的緩存或計算的健康狀態。
    var healthStatus = agent.GetHealthStatus(coordinator);
    logger.LogInformation($"Agent {agent.AgentId}: {healthStatus?.Status ?? HealthStatus.Unknown}");

    // 執行顯式的健康檢查，可能會執行網絡或運行時檢查。
    var healthCheck = await agent.PerformHealthCheckAsync(coordinator);
    logger.LogInformation($"  Health Check: {(healthCheck.Success ? "Passed" : "Failed")} " +
                        $"(Response: {healthCheck.ResponseTime.TotalMilliseconds:F2} ms)");
}

// 從協調器監視器記錄聚合的系統健康指標。
var healthMonitor = coordinator.HealthMonitor;
logger.LogInformation($"System Health: {healthMonitor.HealthyAgentCount}/{healthMonitor.MonitoredAgentCount} agents healthy ({healthMonitor.SystemHealthRatio:P})");
```

### 5. 代理函數創建

該範例為不同代理類型創建專業化函數。

```csharp
// 創建一個在範例中使用的輕量級 KernelFunction 來執行分析。
// 該函數讀取參數、執行小型確定性計算、
// 將結果存儲回參數中，並返回人類友好的訊息。
private static KernelFunction CreateAnalysisFunction(Kernel kernel)
{
    return KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            // 安全地從參數中讀取輸入文本和分析類型。
            var input = args.TryGetValue("input_text", out var i) ? i?.ToString() ?? string.Empty : string.Empty;
            var analysisType = args.TryGetValue("analysis_type", out var a) ? a?.ToString() ?? "basic" : "basic";

            // 模擬一個簡單的分析結果。在實際場景中替換為
            // 對 LLM 或其他處理組件的呼叫。
            var analysisResult = new
            {
                TextLength = input.Length,
                WordCount = input.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length,
                AnalysisType = analysisType,
                Insights = new[] { "Sample insight 1", "Sample insight 2" },
                Confidence = 0.95
            };

            // 存儲結果，以便下游任務可以使用它。
            args["analysis_result"] = analysisResult;
            return $"Analysis completed: {analysisResult.WordCount} words, {analysisResult.Insights.Length} insights";
        },
        functionName: "analyze_text",
        description: "Performs comprehensive text analysis"
    );
}

// 創建一個處理分析結果的處理函數，並為
// 報告或聚合準備更豐富的處理結果。
private static KernelFunction CreateProcessingFunction(Kernel kernel)
{
    return KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var analysisResult = args.TryGetValue("analysis_result", out var ar) ? ar : null;

            // 模擬增強洞察和元數據標記。
            var processedResult = new
            {
                ProcessedAt = DateTime.UtcNow,
                EnhancedInsights = new[] { "Enhanced insight 1", "Enhanced insight 2", "Enhanced insight 3" },
                ProcessingQuality = "high",
                Metadata = new { Source = "analysis_agent", Version = "1.0" }
            };

            // 存儲處理的結果供後來的任務使用。
            args["processed_result"] = processedResult;
            return $"Processing completed: {processedResult.EnhancedInsights.Length} enhanced insights";
        },
        functionName: "process_analysis",
        description: "Processes analysis results and enhances insights"
    );
}
```

### 6. 工作流程結果日誌

該範例包含工作流程執行的全面結果日誌。

```csharp
// 幫助以簡潔、人類友好的方式記錄 WorkflowExecutionResult。
// 此函數顯示成功、時序、涉及的代理、聚合結果和
// 如果存在，則顯示錯誤樣本。
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

該範例產生全面的輸出，顯示：

* 🤖 多代理協調設置和配置
* 📋 具有任務分配的基本多代理場景
* 🔄 具有顯式任務定義的進階工作流程
* 🏥 健康監控和代理狀態追蹤
* 📊 工作流程執行結果和性能指標
* ✅ 跨多個專業化代理的成功協調

## 故障排除

### 常見問題

1. **代理註冊失敗**：確保代理 ID 是唯一的且功能定義正確
2. **工作流程執行錯誤**：檢查所需的代理和功能是否可用
3. **健康檢查失敗**：驗證代理連接和資源可用性
4. **協調超時**：為複雜工作流程調整超時設置

### 調試提示

* 啟用詳細日誌記錄以追蹤代理交互
* 監控代理健康狀況和性能指標
* 驗證工作流程要求和代理功能匹配
* 檢查協調超時和並發設置

## 另請參閱

* [多代理和共享狀態](../how-to/multi-agent-and-shared-state.md)
* [工作流程管理](../concepts/execution.md)
* [代理協調](../concepts/agent-coordination.md)
* [健康監控](../how-to/health-monitoring.md)
* [結果聚合](../concepts/result-aggregation.md)
