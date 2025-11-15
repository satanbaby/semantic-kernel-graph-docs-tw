# 優化器與少樣本示例

此示例演示了如何在 Semantic Kernel Graph 工作流程中結合進階優化器與少樣本提示模式。

## 目標

了解如何在基於圖表的系統中實現和優化少樣本提示工作流程，以便：
* 建立少樣本分類和回應生成工作流程
* 啟用進階優化引擎以提高效能
* 使用增量學習實現機器學習優化
* 將少樣本模式與效能預測相結合
* 在簡單圖表結構中展示輕量級優化

## 前置要求

* **.NET 8.0** 或更高版本
* **OpenAI API 密鑰** 在 `appsettings.json` 中設定
* **Semantic Kernel Graph 套件** 已安裝
* 對 [圖表概念](../concepts/graph-concepts.md) 和 [優化](../how-to/advanced-optimizations.md) 的基本了解
* 熟悉 [少樣本學習](../concepts/few-shot-learning.md)

## 主要元件

### 概念與技術

* **少樣本提示**：使用示例來引導 AI 模型回應
* **進階優化**：基於執行指標的效能優化
* **機器學習優化**：基於 ML 的效能預測和改進
* **效能指標**：追蹤和分析執行效能
* **增量學習**：基於新數據的持續模型改進

### 核心類別

* `GraphExecutor`：具有優化功能的執行器
* `FunctionGraphNode`：用於少樣本分類和回應生成的節點
* `GraphPerformanceMetrics`：效能追蹤和分析
* `ConditionalEdge`：用於工作流程控制的圖表邊線
* `GraphConfiguration`：效能預測配置

## 運行示例

### 開始使用

此示例展示了使用 Semantic Kernel Graph 套件的提示優化和少樣本學習。下面的程式碼片段展示了如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 建立少樣本圖表

該示例首先使用少樣本提示函數建立最小圖表。

```csharp
// 為示例建立最小核心（本地文件不需要外部 API 密鑰）
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport()
    .Build();

// 使用少樣本提示函數建立最小圖表
var executor = new GraphExecutor("FewShotWithOptimizers", "Few-shot prompting with optimization engines");

var classify = new FunctionGraphNode(
    CreateFewShotClassifierFunction(kernel),
    "fewshot_classifier",
    "使用少樣本示例將使用者請求分類到某個類別"
).StoreResultAs("category");

var respond = new FunctionGraphNode(
    CreateFewShotAnswerFunction(kernel),
    "fewshot_answer",
    "使用少樣本指導生成簡潔的高品質回應"
).StoreResultAs("final_answer");

executor.AddNode(classify);
executor.AddNode(respond);
executor.SetStartNode(classify.NodeId);
executor.AddEdge(ConditionalEdge.CreateUnconditional(classify, respond));
```

### 2. 啟用進階優化

執行器配置有進階優化和機器學習功能。

```csharp
// 啟用優化器（進階 + ML）及輕量級預設值
executor.WithAdvancedOptimizations();
executor.WithMachineLearningOptimization(options =>
{
    // 為輕量級本地模擬啟用增量學習
    options.EnableIncrementalLearning = true;
});
```

### 3. 少樣本分類函數

分類函數使用少樣本示例對使用者請求進行分類。

```csharp
private static KernelFunction CreateFewShotClassifierFunction(Kernel kernel)
{
    // 建立一個輕量級核心函數，使用簡單的少樣本示例和
    // 關鍵字啟發式分類輸入。此函數將分類結果儲存到
    // 圖表狀態的「category」鍵下。
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var input = args.TryGetValue("input", out var i) ? i?.ToString() ?? string.Empty : string.Empty;

            // 少樣本示例（為了清晰起見）。該函數使用
            // 下面的關鍵字啟發式。保持示例簡潔。
            var examples = @"Examples:
Input: 'Summarize this article about distributed systems in simple terms.'
Category: summarization

Input: 'Translate the following text to Portuguese: The system achieved 99.9% uptime.'
Category: translation

Input: 'Classify the sentiment of: I love how responsive this app is!'
Category: sentiment_analysis
";

            // 基於輸入中的關鍵字進行簡單分類。
            var category = input.ToLowerInvariant() switch
            {
                var s when s.Contains("summarize") || s.Contains("summary") => "summarization",
                var s when s.Contains("translate") || s.Contains("portuguese") => "translation",
                var s when s.Contains("sentiment") || s.Contains("love") || s.Contains("hate") => "sentiment_analysis",
                var s when s.Contains("explain") || s.Contains("explanation") => "explanation",
                var s when s.Contains("story") || s.Contains("creative") => "creative_writing",
                _ => "general_query"
            };

            // 將類別儲存到圖表引數/狀態，並返回
            // 為演示目的的短人類可讀結果。
            args["category"] = category;
            return $"分類為：{category}";
        },
        functionName: "fewshot_classifier",
        description: "使用少樣本示例分類使用者請求"
    );
}
```

### 4. 少樣本回應函數

回應函數使用少樣本指導模式生成回應。

```csharp
private static KernelFunction CreateFewShotAnswerFunction(Kernel kernel)
{
    // 建立一個簡單的回應生成器，使用之前儲存的
    // 「category」來產生簡潔的人類可讀回覆。該函數
    // 也將最終回應儲存到圖表狀態下的「final_answer」。
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var input = args.TryGetValue("input", out var i) ? i?.ToString() ?? string.Empty : string.Empty;
            var category = args.TryGetValue("category", out var c) ? c?.ToString() ?? string.Empty : string.Empty;

            // 少樣本示例已為讀者記錄；實現
            // 下面使用直接的類別驅動範本。
            var examples = @"Examples:
Input: 'Summarize this article about distributed systems in simple terms.'
Category: summarization
Response: 'Distributed systems are networks of computers that work together to solve problems.'
";

            // 適用於文件的類別驅動範本回應
            var response = category switch
            {
                "summarization" => $"以下是簡單摘要：{input.Replace("summarize", "").Replace("in simple terms", "").Trim()}。",
                "translation" => $"翻譯：{input.Replace("Translate the following text to Portuguese:", "").Trim()}",
                "sentiment_analysis" => $"情感分析：{input.Replace("Classify the sentiment of:", "").Trim()} 顯示正面情感。",
                "explanation" => $"解釋：{input.Replace("Explain", "").Replace("in simple terms", "").Trim()}。",
                "creative_writing" => $"創意回應：一個關於 {input.Replace("Generate a creative story about", "").Trim()} 的創意看法。",
                _ => $"一般回應：{input}"
            };

            args["final_answer"] = response;
            return response;
        },
        functionName: "fewshot_answer",
        description: "使用少樣本指導模式生成回應"
    );
}
```

### 5. 樣本輸入處理

該示例處理多個樣本輸入來演示工作流程。

```csharp
// 通過執行器運行一些樣本輸入。每次運行演示
// 分類和回應生成步驟，並展示結果如何被
// 儲存在圖表狀態中以供稍後檢索。
var samples = new[]
{
    "以簡單的方式總結這篇關於分散式系統的文章。",
    "將以下文字翻譯成葡萄牙語：'系統達到了 99.9% 的正常運行時間。'",
    "分類以下情感：'我喜歡這個應用程式的反應速度！'"
};

foreach (var input in samples)
{
    Console.WriteLine($"🧑‍💻 使用者：{input}");
    var args = new KernelArguments { ["input"] = input };

    // 使用核心和提供的引數執行圖表
    var result = await executor.ExecuteAsync(kernel, args);

    // 從圖表狀態讀取值（category 和 final_answer）
    var state = args.GetOrCreateGraphState();
    var category = state.GetValue<string>("category") ?? "(未知)";
    var answer = state.GetValue<string>("final_answer") ?? result.GetValue<string>() ?? "未生成答案";

    Console.WriteLine($"📂 類別：{category}");
    Console.WriteLine($"🤖 回應：{answer}\n");
    await Task.Delay(150);
}
```

### 6. 效能指標和優化

該示例演示了優化器的使用和效能指標。

```csharp
// 簡要演示優化器用法：收集指標並運行本地
// 優化通過。該示例模擬節點執行計時以
// 生成優化器使用的基本效能指標。
var metrics = new GraphPerformanceMetrics(new GraphMetricsOptions(), executor.GetService<IGraphLogger>());

// 模擬一些節點運行以生成基本指標
for (int i = 0; i < 6; i++)
{
    var tracker = metrics.StartNodeTracking(classify.NodeId, "FewShotClassifier", $"exec_{i}");
    await Task.Delay(new Random(42).Next(30, 90));
    metrics.CompleteNodeTracking(tracker, success: true);
}

var optimizationResult = await executor.OptimizeAsync(metrics);
Console.WriteLine($"🔧 優化器建議：{optimizationResult.TotalOptimizations} " +
                 $"（路徑：{optimizationResult.PathOptimizations.Count}，節點：{optimizationResult.NodeOptimizations.Count})");
```

### 7. 機器學習訓練和預測

該示例演示了輕量級 ML 訓練和效能預測。

```csharp
// 使用生成的歷史進行輕量級 ML 訓練 + 預測。這
// 演示了如何要求執行器訓練和預測圖表
// 使用模擬歷史數據的效能。
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

    Console.WriteLine($"🔮 預測延遲：{prediction.PredictedLatency.TotalMilliseconds:F1}ms | 信心度：{prediction.Confidence:P1}");
}
```

### 8. 效能歷史生成

該示例為 ML 訓練生成模擬效能歷史。

```csharp
private static List<GraphPerformanceHistory> GenerateTinyPerformanceHistory()
{
    // 固定種子確保跨執行的一致生成歷史記錄，這
    // 對文件示例和測試很有用。
    var random = new Random(42);
    var history = new List<GraphPerformanceHistory>();

    // 生成一小組合成效能歷史條目。
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

該示例產生展示以下內容的全面輸出：

* 🧑‍💻 使用者輸入處理與少樣本分類
* 📂 類別分類結果
* 🤖 使用少樣本指導生成的回應
* 🔧 優化建議和效能指標
* 🔮 基於 ML 的效能預測
* ✅ 完整的少樣本工作流程與優化

## 疑難排解

### 常見問題

1. **少樣本分類失敗**：確保示例清晰且涵蓋預期的輸入類型
2. **優化錯誤**：檢查是否正確收集效能指標
3. **ML 訓練失敗**：驗證是否有足夠的歷史數據用於訓練
4. **效能問題**：監控優化建議並調整閾值

### 調試提示

* 啟用詳細日誌以追蹤少樣本分類
* 監控效能指標收集和優化結果
* 驗證 ML 訓練數據的品質和數量
* 檢查優化引擎配置和閾值

## 另見

* [進階優化](../how-to/advanced-optimizations.md)
* [少樣本學習](../concepts/few-shot-learning.md)
* [效能指標](../how-to/metrics-and-observability.md)
* [機器學習優化](../concepts/ml-optimization.md)
* [圖表優化](../how-to/graph-optimization.md)
