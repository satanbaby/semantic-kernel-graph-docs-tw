# 進階路由範例

本範例展示了 Semantic Kernel Graph 中的進階路由功能，包括語意路由、內容相似度、機率路由、上下文路由和回饋學習。

## 目標

學習如何在基於 Graph 的工作流程中實現進階路由策略：
* 使用具有 Embedding 的語意路由進行內容感知決策
* 使用歷史執行模式實現基於相似度的路由
* 配置具有動態權重的機率路由
* 基於執行歷史和狀態啟用上下文路由
* 實現回饋學習以隨著時間改進路由決策

## 前置條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 配置於 `appsettings.json`
* **Semantic Kernel Graph package** 已安裝
* **文本 Embedding 服務** 已配置（OpenAI、Azure OpenAI 或本機）
* 基本了解 [Graph Concepts](../concepts/graph-concepts.md) 和 [Routing](../concepts/routing.md)
* 熟悉 [Dynamic Routing](../how-to/advanced-routing.md)

## 關鍵元件

### 概念和技術

* **語意路由**: 使用文本 Embedding 和相似度進行內容感知路由
* **相似度路由**: 基於歷史執行模式和結果的路由
* **機率路由**: 具有加權機率和學習的動態路由
* **上下文路由**: 基於執行上下文和狀態的路由決策
* **回饋學習**: 透過回饋連續改進路由決策

### 核心類別

* `DynamicRoutingEngine`：具有多種策略的進階路由引擎
* `ITextEmbeddingGenerationService`：用於生成文本 Embedding 的服務
* `IGraphMemoryService`：用於儲存和檢索路由歷史的服務
* `GraphExecutor`：具有進階路由功能的增強執行器
* `FunctionGraphNode`：可使用進階策略進行路由的 Node

## 執行範例

### 開始使用

本範例展示了使用 Semantic Kernel Graph package 進行進階路由和決策制定。下面的程式碼片段向您展示如何在自己的應用程式中實現此模式。

## 逐步實施

### 1. 建立進階路由 Graph

此範例從建立針對展示進階路由情境優化的 Graph 開始。

```csharp
// Create a graph using a Kernel-aware constructor
var graph = new GraphExecutor(kernel, logger: null);

// Create nodes that simulate different types of decision points using Kernel functions
var startNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((string input) => $"Analyzed: {input}", functionName: "Analyze", description: "Analyze the input"),
    nodeId: "start",
    description: "Analyzes input and determines processing path").StoreResultAs("analysis");

var semanticNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((string input) => $"Semantic processed: {input}", functionName: "SemanticProcess", description: "Semantic processing"),
    nodeId: "semantic",
    description: "Processes content using semantic understanding and natural language analysis").StoreResultAs("semantic_out");

var statisticalNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((string input) => $"Stat result: {input}", functionName: "StatProcess", description: "Statistical processing"),
    nodeId: "statistical",
    description: "Processes content using statistical methods and numerical analysis").StoreResultAs("stat_out");

var hybridNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((string input) => $"Hybrid processed: {input}", functionName: "HybridProcess", description: "Hybrid processing"),
    nodeId: "hybrid",
    description: "Combines semantic and statistical approaches for comprehensive analysis").StoreResultAs("hybrid_out");

var errorHandlerNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(() => "Handled error", functionName: "HandleError", description: "Error handler"),
    nodeId: "error",
    description: "Handles errors and provides fallback processing").StoreResultAs("error_out");

var summaryNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((string input) => $"Summary: {input}", functionName: "Summary", description: "Generates final summary and results"),
    nodeId: "summary",
    description: "Generates final summary and results").StoreResultAs("summary");

// Add nodes to graph
graph.AddNode(startNode);
graph.AddNode(semanticNode);
graph.AddNode(statisticalNode);
graph.AddNode(hybridNode);
graph.AddNode(errorHandlerNode);
graph.AddNode(summaryNode);
graph.SetStartNode(startNode.NodeId);

// Create conditional edges. Note: ConnectWhen expects a predicate over KernelArguments.
graph.ConnectWhen(startNode.NodeId, semanticNode.NodeId, ka => ka.ContainsKey("input") && ka["input"]?.ToString()?.Contains("semantic", StringComparison.OrdinalIgnoreCase) == true);
graph.ConnectWhen(startNode.NodeId, statisticalNode.NodeId, ka => ka.ContainsKey("input") && ka["input"]?.ToString()?.Contains("stat", StringComparison.OrdinalIgnoreCase) == true);
graph.ConnectWhen(startNode.NodeId, hybridNode.NodeId, ka => ka.ContainsKey("input") && ka["input"]?.ToString()?.Contains("hybrid", StringComparison.OrdinalIgnoreCase) == true);
graph.ConnectWhen(startNode.NodeId, errorHandlerNode.NodeId, ka => ka.ContainsKey("error") && ka["error"]?.ToString() == "true");

// All processing nodes can go to summary
graph.Connect(semanticNode.NodeId, summaryNode.NodeId);
graph.Connect(statisticalNode.NodeId, summaryNode.NodeId);
graph.Connect(hybridNode.NodeId, summaryNode.NodeId);
graph.Connect(errorHandlerNode.NodeId, summaryNode.NodeId);
```

### 2. 配置進階路由引擎

```csharp
// Create advanced routing engine with all capabilities
var typedLogger = kernel.Services.GetService<ILogger<DynamicRoutingEngine>>();
var routingEngine = new DynamicRoutingEngine(
    templateEngine: null,
    options: new DynamicRoutingOptions { EnableCaching = true, EnableFallback = true },
    logger: typedLogger,
    embeddingService: embeddingService,
    memoryService: memoryService);

// Configure the graph to use advanced routing
graph.RoutingEngine = routingEngine;

logger.LogInformation("Advanced routing enabled: {IsEnabled}", routingEngine.IsAdvancedRoutingEnabled);
```

### 3. 語意路由演示

語意路由使用 Embedding 進行內容感知的路由決策。

```csharp
var semanticQueries = new[]
{
    "Analyze the emotional sentiment of this customer feedback: 'I love this product!'",
    "Calculate the mean and standard deviation of this dataset: [1, 2, 3, 4, 5]",
    "Process this complex research paper that combines qualitative interviews with quantitative surveys",
    "Handle this error: connection timeout occurred"
};

foreach (var query in semanticQueries)
{
    logger.LogInformation("Processing query: {Query}", query);

    var args = new KernelArguments { ["input"] = query };
    var result = await graph.ExecuteAsync(kernel, args);

    logger.LogInformation("Result: {Result}", result);
}
```

### 4. 相似度路由演示

相似度路由使用歷史執行模式進行路由決策。

```csharp
// Execute similar patterns to build history
var similarPatterns = new[]
{
    ("customer_feedback", "positive"),
    ("customer_feedback", "negative"),
    ("customer_feedback", "neutral"),
    ("data_analysis", "statistical"),
    ("data_analysis", "visualization")
};

foreach (var (category, type) in similarPatterns)
{
    var args = new KernelArguments
    {
        ["category"] = category,
        ["type"] = type,
        ["input"] = $"Process {category} of {type} nature"
    };

    logger.LogInformation("Executing pattern: {Category} - {Type}", category, type);
    await graph.ExecuteAsync(kernel, args);
}

logger.LogInformation("Similarity patterns established for future routing decisions");
```

### 5. 機率路由演示

機率路由使用動態權重和學習進行路由決策。

```csharp
// Execute multiple similar scenarios to show probabilistic selection
for (int i = 0; i < 10; i++)
{
    var args = new KernelArguments
    {
        ["input"] = $"Process customer feedback iteration {i}",
        ["priority"] = i % 3 == 0 ? "high" : "normal",
        ["category"] = "customer_feedback"
    };

    logger.LogInformation("Executing probabilistic routing iteration {Iteration}", i);
    var result = await graph.ExecuteAsync(kernel, args);
    
    // Simulate feedback for learning
    var feedback = new RoutingFeedback
    {
        ExecutionId = result.ExecutionId,
        // The FunctionResult does not expose routing metadata directly. Use the function output
        // or a dedicated graph state key to capture route information in a real integration.
        RouteSelected = result.GetValue<object>()?.ToString() ?? string.Empty,
        Success = Random.Shared.Next(100) < 85, // 85% success rate
        Performance = TimeSpan.FromMilliseconds(Random.Shared.Next(100, 500))
    };
    
    await routingEngine.ProvideFeedbackAsync(feedback);
}
```

### 6. 上下文路由演示

上下文路由在進行路由決策時考慮執行歷史和目前狀態。

```csharp
// Execute with different contexts to show contextual routing
var contexts = new[]
{
    new { TimeOfDay = "morning", Load = "low", Priority = "normal" },
    new { TimeOfDay = "afternoon", Load = "high", Priority = "urgent" },
    new { TimeOfDay = "evening", Load = "medium", Priority = "high" }
};

foreach (var context in contexts)
{
    var args = new KernelArguments
    {
        ["input"] = "Process customer request",
        ["time_of_day"] = context.TimeOfDay,
        ["system_load"] = context.Load,
        ["priority"] = context.Priority
    };

    logger.LogInformation("Executing with context: {Context}", context);
    var result = await graph.ExecuteAsync(kernel, args);
    
    // Show how context influenced routing (FunctionResult doesn't expose a route field)
    logger.LogInformation("Route taken (inferred): {Route} based on context {Context}",
        result.GetValue<object>()?.ToString() ?? string.Empty, context);
}
```

### 7. 回饋學習演示

回饋學習基於執行結果連續改進路由決策。

```csharp
// Simulate feedback collection and learning
var feedbackBatch = new List<RoutingFeedback>();

for (int i = 0; i < 20; i++)
{
    var args = new KernelArguments
    {
        ["input"] = $"Learning iteration {i}",
        ["category"] = i % 4 == 0 ? "urgent" : "normal",
        ["complexity"] = i % 3 == 0 ? "high" : "low"
    };

    var result = await graph.ExecuteAsync(kernel, args);
    
    // Collect feedback
    var feedback = new RoutingFeedback
    {
        ExecutionId = result.ExecutionId,
        // Use the function output as a fallback for route identification in the docs example
        RouteSelected = result.GetValue<object>()?.ToString() ?? string.Empty,
        Success = Random.Shared.Next(100) < 90, // 90% success rate
        Performance = TimeSpan.FromMilliseconds(Random.Shared.Next(50, 300)),
        UserSatisfaction = Random.Shared.Next(1, 6) // 1-5 scale
    };
    
    feedbackBatch.Add(feedback);
}

// Provide batch feedback for learning
await routingEngine.ProvideBatchFeedbackAsync(feedbackBatch);
logger.LogInformation("Provided feedback for {Count} executions", feedbackBatch.Count);
```

### 8. 路由分析和見解

此範例最後顯示全面的路由分析。

```csharp
// Show analytics
await DisplayRoutingAnalyticsAsync(routingEngine, logger);

// Cleanup
await routingEngine.DisposeAsync();
logger.LogInformation("=== Advanced Routing Demonstration Complete ===");
```

## 預期輸出

此範例產生的全面輸出顯示：

* ✅ 具有多種 Node 類型的進階路由 Graph 建立
* 🔀 基於內容分析的語意路由決策
* 📊 使用歷史模式的相似度路由
* 🎲 具有動態權重的機率路由
* 🧠 基於執行上下文的上下文路由
* 📈 回饋學習和連續改進
* 📋 全面的路由分析和見解

## 疑難排解

### 常見問題

1. **Embedding 服務錯誤**：確保文本 Embedding 服務已正確配置
2. **記憶體服務故障**：檢查記憶體服務配置和連線
3. **路由決策失敗**：驗證路由條件和 Edge 配置
4. **效能問題**：監控路由決策計時並優化閾值

### 偵錯提示

* 啟用詳細記錄以追蹤路由決策
* 監控相似度分數和信心水準
* 檢查回饋收集和學習進度
* 驗證上下文路由條件和狀態

## 另請參閱

* [Advanced Routing](../how-to/advanced-routing.md)
* [Dynamic Routing](../how-to/dynamic-routing.md)
* [Graph Concepts](../concepts/graph-concepts.md)
* [Routing](../concepts/routing.md)
* [State Management](../concepts/state.md)
