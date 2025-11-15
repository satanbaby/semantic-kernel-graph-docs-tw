# 進階路由範例

本範例展示語義核心圖中的進階路由功能，包括語義路由、內容相似性、概率性路由、上下文路由和回饋學習。

## 目標

學習如何在基於圖的工作流中實現進階路由策略，以便：
* 使用語義路由搭配嵌入進行內容感知決策
* 使用歷史執行模式實現基於相似性的路由
* 設定具動態權重的概率性路由
* 根據執行歷史和狀態啟用上下文路由
* 實現回饋學習以長期改進路由決策

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中設定
* **語義核心圖套件**已安裝
* **文字嵌入服務**已設定（OpenAI、Azure OpenAI 或本機）
* 基本瞭解 [圖概念](../concepts/graph-concepts.md) 和 [路由](../concepts/routing.md)
* 熟悉 [動態路由](../how-to/advanced-routing.md)

## 關鍵元件

### 概念和技術

* **語義路由**：使用文字嵌入和相似性進行內容感知路由
* **相似性路由**：根據歷史執行模式和結果進行路由
* **概率性路由**：具有加權機率和學習的動態路由
* **上下文路由**：根據執行上下文和狀態進行路由決策
* **回饋學習**：通過回饋持續改進路由決策

### 核心類別

* `DynamicRoutingEngine`：具有多個策略的進階路由引擎
* `ITextEmbeddingGenerationService`：用於產生文字嵌入的服務
* `IGraphMemoryService`：用於儲存和檢索路由歷史的服務
* `GraphExecutor`：具有進階路由功能的增強執行器
* `FunctionGraphNode`：可使用進階策略進行路由的節點

## 執行範例

### 快速入門

本範例展示語義核心圖套件中的進階路由和決策制定。下方程式碼片段說明如何在自己的應用程式中實現此模式。

## 逐步實作

### 1. 建立進階路由圖

範例首先建立針對展示進階路由案例最佳化的圖。

```csharp
// 使用核心感知建構式建立圖
var graph = new GraphExecutor(kernel, logger: null);

// 建立模擬不同決策點類型的節點（使用核心函數）
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

// 將節點新增到圖
graph.AddNode(startNode);
graph.AddNode(semanticNode);
graph.AddNode(statisticalNode);
graph.AddNode(hybridNode);
graph.AddNode(errorHandlerNode);
graph.AddNode(summaryNode);
graph.SetStartNode(startNode.NodeId);

// 建立條件邊。注意：ConnectWhen 需要 KernelArguments 的述詞。
graph.ConnectWhen(startNode.NodeId, semanticNode.NodeId, ka => ka.ContainsKey("input") && ka["input"]?.ToString()?.Contains("semantic", StringComparison.OrdinalIgnoreCase) == true);
graph.ConnectWhen(startNode.NodeId, statisticalNode.NodeId, ka => ka.ContainsKey("input") && ka["input"]?.ToString()?.Contains("stat", StringComparison.OrdinalIgnoreCase) == true);
graph.ConnectWhen(startNode.NodeId, hybridNode.NodeId, ka => ka.ContainsKey("input") && ka["input"]?.ToString()?.Contains("hybrid", StringComparison.OrdinalIgnoreCase) == true);
graph.ConnectWhen(startNode.NodeId, errorHandlerNode.NodeId, ka => ka.ContainsKey("error") && ka["error"]?.ToString() == "true");

// 所有處理節點都可前往摘要節點
graph.Connect(semanticNode.NodeId, summaryNode.NodeId);
graph.Connect(statisticalNode.NodeId, summaryNode.NodeId);
graph.Connect(hybridNode.NodeId, summaryNode.NodeId);
graph.Connect(errorHandlerNode.NodeId, summaryNode.NodeId);
```

### 2. 設定進階路由引擎

```csharp
// 建立具有所有功能的進階路由引擎
var typedLogger = kernel.Services.GetService<ILogger<DynamicRoutingEngine>>();
var routingEngine = new DynamicRoutingEngine(
    templateEngine: null,
    options: new DynamicRoutingOptions { EnableCaching = true, EnableFallback = true },
    logger: typedLogger,
    embeddingService: embeddingService,
    memoryService: memoryService);

// 設定圖使用進階路由
graph.RoutingEngine = routingEngine;

logger.LogInformation("Advanced routing enabled: {IsEnabled}", routingEngine.IsAdvancedRoutingEnabled);
```

### 3. 語義路由演示

語義路由使用嵌入進行內容感知的路由決策。

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

### 4. 相似性路由演示

相似性路由使用歷史執行模式進行路由決策。

```csharp
// 執行相似的模式以建立歷史
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

### 5. 概率性路由演示

概率性路由使用動態權重和學習進行路由決策。

```csharp
// 執行多個類似案例以展示概率選擇
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
    
    // 模擬學習回饋
    var feedback = new RoutingFeedback
    {
        ExecutionId = result.ExecutionId,
        // FunctionResult 不直接公開路由中繼資料。使用函數輸出
        // 或專用的圖狀態金鑰在實際整合中擷取路由資訊。
        RouteSelected = result.GetValue<object>()?.ToString() ?? string.Empty,
        Success = Random.Shared.Next(100) < 85, // 85% 成功率
        Performance = TimeSpan.FromMilliseconds(Random.Shared.Next(100, 500))
    };
    
    await routingEngine.ProvideFeedbackAsync(feedback);
}
```

### 6. 上下文路由演示

上下文路由考慮執行歷史和目前狀態以進行路由決策。

```csharp
// 使用不同上下文執行以展示上下文路由
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
    
    // 展示上下文如何影響路由（FunctionResult 不公開路由欄位）
    logger.LogInformation("Route taken (inferred): {Route} based on context {Context}",
        result.GetValue<object>()?.ToString() ?? string.Empty, context);
}
```

### 7. 回饋學習演示

回饋學習根據執行結果持續改進路由決策。

```csharp
// 模擬回饋收集和學習
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
    
    // 收集回饋
    var feedback = new RoutingFeedback
    {
        ExecutionId = result.ExecutionId,
        // 在文件範例中使用函數輸出作為路由識別的後備
        RouteSelected = result.GetValue<object>()?.ToString() ?? string.Empty,
        Success = Random.Shared.Next(100) < 90, // 90% 成功率
        Performance = TimeSpan.FromMilliseconds(Random.Shared.Next(50, 300)),
        UserSatisfaction = Random.Shared.Next(1, 6) // 1-5 刻度
    };
    
    feedbackBatch.Add(feedback);
}

// 提供批次回饋以進行學習
await routingEngine.ProvideBatchFeedbackAsync(feedbackBatch);
logger.LogInformation("Provided feedback for {Count} executions", feedbackBatch.Count);
```

### 8. 路由分析和見解

範例結論透過顯示綜合路由分析。

```csharp
// 顯示分析
await DisplayRoutingAnalyticsAsync(routingEngine, logger);

// 清理
await routingEngine.DisposeAsync();
logger.LogInformation("=== Advanced Routing Demonstration Complete ===");
```

## 預期輸出

範例產生的綜合輸出顯示：

* ✅ 使用多個節點類型建立的進階路由圖
* 🔀 根據內容分析進行的語義路由決策
* 📊 使用歷史模式進行的相似性路由
* 🎲 具有動態權重的概率性路由
* 🧠 根據執行上下文進行的上下文路由
* 📈 回饋學習和持續改進
* 📋 綜合路由分析和見解

## 疑難排解

### 常見問題

1. **嵌入服務錯誤**：確保文字嵌入服務已正確設定
2. **記憶體服務故障**：檢查記憶體服務組態和連線能力
3. **路由決策故障**：驗證路由條件和邊設定
4. **效能問題**：監視路由決策計時並最佳化臨界值

### 除錯提示

* 啟用詳細記錄以追蹤路由決策
* 監視相似性分數和信心等級
* 檢查回饋收集和學習進度
* 驗證上下文路由條件和狀態

## 另請參閱

* [進階路由](../how-to/advanced-routing.md)
* [動態路由](../how-to/dynamic-routing.md)
* [圖概念](../concepts/graph-concepts.md)
* [路由](../concepts/routing.md)
* [狀態管理](../concepts/state.md)
