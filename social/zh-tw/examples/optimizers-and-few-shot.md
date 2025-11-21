# 優化器和少樣本示例

本示例展示如何在 Semantic Kernel Graph 工作流中結合高級優化器與少樣本提示模式。

## 目標

了解如何在基於 Graph 的系統中實現和優化少樣本提示工作流：
* 建立少樣本分類和回應生成工作流
* 啟用高級優化引擎以改進效能
* 使用機器學習優化實現增量學習
* 將少樣本模式與效能預測相結合
* 在簡單的 Graph 結構中展示輕量級優化

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 對 [Graph Concepts](../concepts/graph-concepts.md) 和 [Optimization](../how-to/advanced-optimizations.md) 的基本了解
* 熟悉 [Few-Shot Learning](../concepts/few-shot-learning.md)

## 主要元件

### 概念和技術

* **Few-Shot Prompting**：使用示例來引導 AI 模型回應
* **Advanced Optimizations**：基於執行指標的效能優化
* **Machine Learning Optimization**：基於 ML 的效能預測和改進
* **Performance Metrics**：追蹤和分析執行效能
* **Incremental Learning**：基於新資料的持續模型改進

### 核心類別

* `GraphExecutor`：具有優化功能的執行器
* `FunctionGraphNode`：用於少樣本分類和回應生成的 Node
* `GraphPerformanceMetrics`：效能追蹤和分析
* `ConditionalEdge`：用於工作流控制的 Graph Edge
* `GraphConfiguration`：效能預測配置

## 執行示例

### 開始使用

本示例展示使用 Semantic Kernel Graph 套件的提示優化和少樣本學習。以下代碼片段展示如何在你自己的應用程式中實現此模式。

## 分步實現

### 1. 建立少樣本 Graph

示例從建立包含少樣本提示函數的最小 Graph 開始。

```csharp
// Create a minimal kernel for the example (no external API keys required for local docs)
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport()
    .Build();

// Build a minimal graph with few-shot prompt functions
var executor = new GraphExecutor("FewShotWithOptimizers", "Few-shot prompting with optimization engines");

var classify = new FunctionGraphNode(
    CreateFewShotClassifierFunction(kernel),
    "fewshot_classifier",
    "Classify the user request into a category using few-shot examples"
.).StoreResultAs("category");

var respond = new FunctionGraphNode(
    CreateFewShotAnswerFunction(kernel),
    "fewshot_answer",
    "Generate a concise, high-quality answer using few-shot guidance"
.).StoreResultAs("final_answer");

executor.AddNode(classify);
executor.AddNode(respond);
executor.SetStartNode(classify.NodeId);
executor.AddEdge(ConditionalEdge.CreateUnconditional(classify, respond));
```

### 2. 啟用高級優化

執行器配置有高級優化和機器學習功能。

```csharp
// Enable optimizers (advanced + ML) with lightweight defaults
executor.WithAdvancedOptimizations();
executor.WithMachineLearningOptimization(options =>
{
    // Enable incremental learning for lightweight local simulations
    options.EnableIncrementalLearning = true;
});
```

### 3. 少樣本分類函數

分類函數使用少樣本示例對使用者請求進行分類。

```csharp
private static KernelFunction CreateFewShotClassifierFunction(Kernel kernel)
{
    // Create a lightweight kernel function that classifies input using simple
    // few-shot examples and keyword heuristics. This function stores the
    // classification result into the graph state under the key "category".
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var input = args.TryGetValue("input", out var i) ? i?.ToString() ?? string.Empty : string.Empty;

            // Few-shot examples (documented for illustration; the function uses
            // keyword heuristics below). Keep examples concise for clarity.
            var examples = @"Examples:
Input: 'Summarize this article about distributed systems in simple terms.'
Category: summarization

Input: 'Translate the following text to Portuguese: The system achieved 99.9% uptime.'
Category: translation

Input: 'Classify the sentiment of: I love how responsive this app is!'
Category: sentiment_analysis
";

            // Simple classification based on keywords in the input.
            var category = input.ToLowerInvariant() switch
            {
                var s when s.Contains("summarize") || s.Contains("summary") => "summarization",
                var s when s.Contains("translate") || s.Contains("portuguese") => "translation",
                var s when s.Contains("sentiment") || s.Contains("love") || s.Contains("hate") => "sentiment_analysis",
                var s when s.Contains("explain") || s.Contains("explanation") => "explanation",
                var s when s.Contains("story") || s.Contains("creative") => "creative_writing",
                _ => "general_query"
            };

            // Store the category into the graph arguments/state and return a short
            // human-readable result for demonstration purposes.
            args["category"] = category;
            return $"Classified as: {category}";
        },
        functionName: "fewshot_classifier",
        description: "Classifies user requests using few-shot examples"
    );
}
```

### 4. 少樣本答案函數

答案函數使用少樣本引導模式生成回應。

```csharp
private static KernelFunction CreateFewShotAnswerFunction(Kernel kernel)
{
    // Create a simple response generator that uses the previously stored
    // "category" to produce a concise, human-readable reply. The function
    // also stores the final answer into the graph state under "final_answer".
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var input = args.TryGetValue("input", out var i) ? i?.ToString() ?? string.Empty : string.Empty;
            var category = args.TryGetValue("category", out var c) ? c?.ToString() ?? string.Empty : string.Empty;

            // Few-shot examples are documented for readers; the implementation
            // uses straightforward category-driven templates below.
            var examples = @"Examples:
Input: 'Summarize this article about distributed systems in simple terms.'
Category: summarization
Response: 'Distributed systems are networks of computers that work together to solve problems.'
";

            // Category-driven templated responses suitable for documentation
            var response = category switch
            {
                "summarization" => $"Here's a simple summary: {input.Replace("summarize", "").Replace("in simple terms", "").Trim()}.",
                "translation" => $"Translation: {input.Replace("Translate the following text to Portuguese:", "").Trim()}",
                "sentiment_analysis" => $"Sentiment Analysis: {input.Replace("Classify the sentiment of:", "").Trim()} shows positive sentiment.",
                "explanation" => $"Explanation: {input.Replace("Explain", "").Replace("in simple terms", "").Trim()}.",
                "creative_writing" => $"Creative Response: A creative take on {input.Replace("Generate a creative story about", "").Trim()}.",
                _ => $"General Response: {input}"
            };

            args["final_answer"] = response;
            return response;
        },
        functionName: "fewshot_answer",
        description: "Generates responses using few-shot guidance patterns"
    );
}
```

### 5. 樣本輸入處理

示例處理多個樣本輸入以展示工作流。

```csharp
// Run a few sample inputs through the executor. Each run demonstrates the
// classification and answer generation steps and shows how results are
// stored in the graph state for later retrieval.
var samples = new[]
{
    "Summarize this article about distributed systems in simple terms.",
    "Translate the following text to Portuguese: 'The system achieved 99.9% uptime.'",
    "Classify the sentiment of: 'I love how responsive this app is!'"
};

foreach (var input in samples)
{
    Console.WriteLine($"🧑‍💻 User: {input}");
    var args = new KernelArguments { ["input"] = input };

    // Execute the graph with the kernel and provided arguments
    var result = await executor.ExecuteAsync(kernel, args);

    // Read values from the graph state (category and final_answer)
    var state = args.GetOrCreateGraphState();
    var category = state.GetValue<string>("category") ?? "(unknown)";
    var answer = state.GetValue<string>("final_answer") ?? result.GetValue<string>() ?? "No answer produced";

    Console.WriteLine($"📂 Category: {category}");
    Console.WriteLine($"🤖 Answer: {answer}\n");
    await Task.Delay(150);
}
```

### 6. 效能指標和優化

示例展示優化器的使用與效能指標。

```csharp
// Demonstrate optimizers usage briefly: collect metrics and run a local
// optimization pass. The example simulates node execution timings to
// generate basic performance metrics used by the optimizer.
var metrics = new GraphPerformanceMetrics(new GraphMetricsOptions(), executor.GetService<IGraphLogger>());

// Simulate a few node runs to generate basic metrics
for (int i = 0; i < 6; i++)
{
    var tracker = metrics.StartNodeTracking(classify.NodeId, "FewShotClassifier", $"exec_{i}");
    await Task.Delay(new Random(42).Next(30, 90));
    metrics.CompleteNodeTracking(tracker, success: true);
}

var optimizationResult = await executor.OptimizeAsync(metrics);
Console.WriteLine($"🔧 Optimizer suggestions: {optimizationResult.TotalOptimizations} " +
                 $"(paths: {optimizationResult.PathOptimizations.Count}, nodes: {optimizationResult.NodeOptimizations.Count})");
```

### 7. 機器學習訓練和預測

示例展示輕量級 ML 訓練和效能預測。

```csharp
// Lightweight ML training + prediction using the generated history. This
// demonstrates how the executor can be asked to train and predict graph
// performance using simulated historical data.
var history = GenerateTinyPerformanceHistory();
var training = await executor.TrainModelsAsync(history);

if (training.Success)
{
    var prediction = await executor.PredictPerformanceAsync(new GraphConfiguration
    {
        NodeCount = 2,
        AveragePathLength = 2,
        ConditionalNodeCount = 0,
        LoopNodeCount = 0,
        ParallelNodeCount = 0
    });

    Console.WriteLine($"🔮 Predicted latency: {prediction.PredictedLatency.TotalMilliseconds:F1}ms | Confidence: {prediction.Confidence:P1}");
}
```

### 8. 效能歷史生成

示例為 ML 訓練生成模擬效能歷史。

```csharp
private static List<GraphPerformanceHistory> GenerateTinyPerformanceHistory()
{
    // Fixed seed ensures consistent generated history across runs which is
    // useful for documentation examples and tests.
    var random = new Random(42);
    var history = new List<GraphPerformanceHistory>();

    // Generate a small set of synthetic performance history entries.
    for (int i = 0; i < 8; i++)
    {
        var entry = new GraphPerformanceHistory
        {
            Timestamp = DateTimeOffset.UtcNow.AddMinutes(-i),
            GraphConfiguration = new GraphConfiguration
            {
                NodeCount = 2,
                AveragePathLength = 2.0,
                ConditionalNodeCount = 0,
                LoopNodeCount = 0,
                ParallelNodeCount = 0
            },
            AverageLatency = TimeSpan.FromMilliseconds(40 + random.Next(40)),
            Throughput = 50 + random.Next(50),
            SuccessRate = 90 + random.Next(10),
            AppliedOptimizations = random.Next(100) < 30 ? new[] { "caching" } : Array.Empty<string>()
        };

        history.Add(entry);
    }

    return history;
}
```

## 預期輸出

示例產生全面的輸出，顯示：

* 🧑‍💻 使用少樣本分類的使用者輸入處理
* 📂 分類結果
* 🤖 使用少樣本引導生成的答案
* 🔧 優化建議和效能指標
* 🔮 基於 ML 的效能預測
* ✅ 完整的少樣本工作流與優化

## 故障排除

### 常見問題

1. **少樣本分類失敗**：確保示例清晰且涵蓋預期的輸入類型
2. **優化錯誤**：檢查效能指標是否正確收集
3. **ML 訓練失敗**：驗證是否有足夠的歷史資料用於訓練
4. **效能問題**：監控優化建議並調整閾值

### 除錯提示

* 啟用詳細日誌來追蹤少樣本分類
* 監控效能指標收集和優化結果
* 驗證 ML 訓練資料的品質和數量
* 檢查優化引擎配置和閾值

## 另請參閱

* [Advanced Optimizations](../how-to/advanced-optimizations.md)
* [Few-Shot Learning](../concepts/few-shot-learning.md)
* [Performance Metrics](../how-to/metrics-and-observability.md)
* [Machine Learning Optimization](../concepts/ml-optimization.md)
* [Graph Optimization](../how-to/graph-optimization.md)
