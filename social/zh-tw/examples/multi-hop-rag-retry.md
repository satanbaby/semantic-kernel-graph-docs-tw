# 多跳躍 RAG 重試範例

此範例示範了具有重試機制和查詢優化的多跳躍檢索增強生成 (RAG) 在知識庫上的應用。

## 目標

學習如何在基於圖形的系統中實現進階 RAG 工作流程，以：
* 使用多次嘗試實現反覆檢索迴圈
* 基於背景評估優化搜尋查詢
* 動態調整搜尋參數 (top_k、min_score) 以獲得更好的結果
* 從累積背景合成全面的答案
* 處理需要多個檢索跳躍的複雜查詢

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件** 已安裝
* **Kernel Memory** 為知識庫操作配置完成
* 基本理解 [圖形概念](../concepts/graph-concepts.md) 和 [RAG 模式](../patterns/rag.md)
* 熟悉 [檢索和記憶](../concepts/memory.md)

## 關鍵元件

### 概念和技術

* **多跳躍 RAG**：反覆檢索程序，可優化查詢並累積背景
* **查詢優化**：基於背景評估動態調整搜尋參數
* **重試機制**：多次檢索嘗試，具有擴大的搜尋參數
* **背景評估**：評估檢索內容的品質和充分性
* **答案合成**：將多個檢索結果合併為全面的答案

### 核心類別

* `GraphExecutor`：多跳躍 RAG 工作流程的執行程式
* `FunctionGraphNode`：用於查詢分析、檢索、評估和合成的節點
* `KernelMemoryGraphProvider`：知識庫操作的提供者
* `ConditionalEdge`：控制重試迴圈和查詢優化的邊
* `GraphState`：累積背景和搜尋參數的狀態管理

## 執行範例

### 入門

此範例使用 Semantic Kernel Graph 套件示範具有重試機制的多跳躍 RAG。下面的程式碼片段展示如何在你的應用程式中實現此模式。

## 逐步實現

### 1. 建立多跳躍 RAG 執行程式

此範例建立了一個專門用於多跳躍 RAG 工作流程的執行程式。

```csharp
private static GraphExecutor CreateMultiHopRagExecutor(Kernel kernel, KernelMemoryGraphProvider provider, string collection)
{
    var executor = new GraphExecutor("MultiHopRagRetry", "Multi-hop RAG with retry and refinement");

    var analyze = new FunctionGraphNode(
        CreateInitialQueryFunction(kernel),
        "analyze_question",
        "Analyze the user question and produce an initial search query"
    ).StoreResultAs("search_query");

    var retrieve = new FunctionGraphNode(
        CreateAttemptRetrievalFunction(kernel, provider, collection),
        "attempt_retrieval",
        "Attempt to retrieve relevant context from the knowledge base"
    ).StoreResultAs("retrieved_context");

    var evaluate = new FunctionGraphNode(
        CreateEvaluateContextFunction(kernel),
        "evaluate_context",
        "Evaluate if retrieved context is sufficient or if we should retry"
    ).StoreResultAs("evaluation_message");

    var refine = new FunctionGraphNode(
        CreateRefineQueryFunction(kernel),
        "refine_query",
        "Refine the query and retry with wider parameters"
    ).StoreResultAs("search_query");

    var answer = new FunctionGraphNode(
        CreateSynthesizeAnswerFunction(kernel),
        "synthesize_answer",
        "Synthesize a final answer using the accumulated retrieved context"
    ).StoreResultAs("final_answer");

    executor.AddNode(analyze);
    executor.AddNode(retrieve);
    executor.AddNode(evaluate);
    executor.AddNode(refine);
    executor.AddNode(answer);

    executor.SetStartNode(analyze.NodeId);
    executor.AddEdge(ConditionalEdge.CreateUnconditional(analyze, retrieve));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(retrieve, evaluate));

    // Conditional routing: continue refining vs finalize
    executor.AddEdge(new ConditionalEdge(
        evaluate,
        refine,
        args => ShouldContinueRetrieval(args),
        "Retry Retrieval"
    ));

    executor.AddEdge(new ConditionalEdge(
        evaluate,
        answer,
        args => !ShouldContinueRetrieval(args),
        "Finalize Answer"
    ));

    executor.AddEdge(ConditionalEdge.CreateUnconditional(refine, retrieve));

    return executor;
}
```

### 2. 配置工作流程

工作流程透過條件邊配置以控制重試迴圈。此範例使用
`ConditionalEdge` 實例 (而不是內聯謂詞)，以便路由邏輯明確且可測試。

```csharp
// 注意：執行程式接線在範例中的 CreateMultiHopRagExecutor 內執行
// 設置起始節點並連接節點；條件邊決定是否重試或完成。
executor.SetStartNode(analyze.NodeId);
executor.AddEdge(ConditionalEdge.CreateUnconditional(analyze, retrieve));
executor.AddEdge(ConditionalEdge.CreateUnconditional(retrieve, evaluate));

executor.AddEdge(new ConditionalEdge(
    evaluate,
    refine,
    args => ShouldContinueRetrieval(args),
    "Retry Retrieval"
));

executor.AddEdge(new ConditionalEdge(
    evaluate,
    answer,
    args => !ShouldContinueRetrieval(args),
    "Finalize Answer"
));

executor.AddEdge(ConditionalEdge.CreateUnconditional(refine, retrieve));

return executor;
```

### 3. 查詢分析函數

初始查詢分析函數準備一個緊湊、規範化的搜尋查詢，並在缺少時初始化
迴圈控制引數。

```csharp
private static KernelFunction CreateInitialQueryFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var question = args.GetValueOrDefault("user_question")?.ToString() ?? string.Empty;

            // Initialize loop state if missing
            if (!args.ContainsName("attempt")) args["attempt"] = 0;
            if (!args.ContainsName("max_attempts")) args["max_attempts"] = 3;
            if (!args.ContainsName("min_required_chunks")) args["min_required_chunks"] = 2;
            if (!args.ContainsName("top_k")) args["top_k"] = 4;
            if (!args.ContainsName("min_score")) args["min_score"] = 0.45;

            // Produce a compact query removing question words and punctuation
            var query = question
                .Replace("What", string.Empty, StringComparison.OrdinalIgnoreCase)
                .Replace("How", string.Empty, StringComparison.OrdinalIgnoreCase)
                .Replace("Explain", string.Empty, StringComparison.OrdinalIgnoreCase)
                .Replace("?", string.Empty, StringComparison.OrdinalIgnoreCase)
                .Trim();

            return string.IsNullOrWhiteSpace(query) ? question : query;
        },
        functionName: "analyze_question",
        description: "Analyzes the user question and outputs a compact search query"
    );
}
```

### 4. 檢索函數

檢索函數嘗試從知識庫中取得相關背景；它從提供者串流
結果並返回連接的文字片段。

```csharp
private static KernelFunction CreateAttemptRetrievalFunction(Kernel kernel, KernelMemoryGraphProvider provider, string collection)
{
    return kernel.CreateFunctionFromMethod(
        async (KernelArguments args) =>
        {
            var query = args.GetValueOrDefault("search_query")?.ToString()
                ?? args.GetValueOrDefault("user_question")?.ToString()
                ?? string.Empty;

            var topK = TryGetInt(args, "top_k", 4);
            var minScore = TryGetDouble(args, "min_score", 0.45);

            var enumerator = await provider.SearchAsync(collection, query, Math.Max(1, topK), Math.Clamp(minScore, 0.0, 1.0));
            var snippets = new List<string>();
            await foreach (var item in enumerator)
            {
                snippets.Add(item.Text);
            }

            args["retrieved_count"] = snippets.Count;

            if (snippets.Count == 0)
            {
                return string.Empty;
            }

            // Cap accumulated context length to avoid overly long downstream prompts
            var joined = string.Join(" \n--- \n", snippets);
            return joined.Length > 4000 ? joined[..4000] + "…" : joined;
        },
        functionName: "attempt_retrieval",
        description: "Retrieves relevant context from the knowledge base for the current query"
    );
}
```

### 5. 背景評估函數

評估函數檢查檢索計數和閾值，並返回人類友好的
條件邊使用的狀態訊息。

```csharp
private static KernelFunction CreateEvaluateContextFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var attempt = TryGetInt(args, "attempt", 0);
            var maxAttempts = TryGetInt(args, "max_attempts", 3);
            var retrievedCount = TryGetInt(args, "retrieved_count", 0);
            var minRequired = TryGetInt(args, "min_required_chunks", 2);

            var status = retrievedCount >= minRequired
                ? $"✅ Sufficient context collected (chunks={retrievedCount})."
                : $"ℹ️ Insufficient context (chunks={retrievedCount} < required={minRequired}). Attempt {attempt}/{maxAttempts}.";

            return status;
        },
        functionName: "evaluate_context",
        description: "Evaluates sufficiency of the retrieved context"
    );
}
```

### 6. 查詢優化函數

優化函數遞增嘗試計數器，放寬閾值並應用簡單
後續檢索嘗試啟發式來擴大查詢。

```csharp
private static KernelFunction CreateRefineQueryFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var attempt = TryGetInt(args, "attempt", 0) + 1;
            args["attempt"] = attempt;

            var topK = TryGetInt(args, "top_k", 4);
            var minScore = TryGetDouble(args, "min_score", 0.45);
            var baseQuery = args.GetValueOrDefault("search_query")?.ToString() ?? string.Empty;

            // Widen search window progressively
            var newTopK = Math.Min(topK + 2, 12);
            var newMinScore = Math.Max(0.20, minScore - 0.05);
            args["top_k"] = newTopK;
            args["min_score"] = newMinScore;

            var refined = ApplyHeuristicRefinements(baseQuery, args.GetValueOrDefault("user_question")?.ToString() ?? string.Empty, attempt);
            return refined;
        },
        functionName: "refine_query",
        description: "Refines the search query and relaxes thresholds for the next attempt"
    );
}
```

### 7. 答案合成函數

合成函數從各嘗試中收集的任何背景格式化最終答案。如果沒有
檢索到背景，它會返回一個資訊性訊息。

```csharp
private static KernelFunction CreateSynthesizeAnswerFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var question = args.GetValueOrDefault("user_question")?.ToString() ?? string.Empty;
            var context = args.GetValueOrDefault("retrieved_context")?.ToString() ?? string.Empty;
            var attempt = TryGetInt(args, "attempt", 0);
            var retrievedCount = TryGetInt(args, "retrieved_count", 0);

            if (string.IsNullOrWhiteSpace(context))
            {
                return $"I could not retrieve sufficient information to answer: '{question}'. Attempts: {attempt}, retrieved chunks: {retrievedCount}.";
            }

            var preview = context.Length > 600 ? context[..600] + "…" : context;
            return $"Answer to: '{question}'\n\nBased on retrieved context (chunks={retrievedCount}, attempts={attempt}):\n{preview}";
        },
        functionName: "synthesize_answer",
        description: "Formats a final answer using retrieved context"
    );
}
```

### 8. 知識庫植入

此範例在知識庫中植入了幾個文件，以鼓勵不同的
檢索行為 (政策對報告對客戶內容)。

```csharp
private static async Task SeedKnowledgeBaseAsync(KernelMemoryGraphProvider provider, string collection)
{
    await provider.SaveInformationAsync(collection,
        "The data privacy policy mandates encryption at rest and in transit, requires multi-factor authentication (MFA), and limits data retention to 24 months.",
        "mh-001",
        "Corporate data privacy policy",
        "category:policy");

    await provider.SaveInformationAsync(collection,
        "Customer documentation must be handled securely with restricted access controls and audited storage locations.",
        "mh-002",
        "Customer documentation handling guidelines",
        "category:customer");

    await provider.SaveInformationAsync(collection,
        "Quarterly business reports indicate improved performance metrics due to optimized workflows and better resource allocation.",
        "mh-003",
        "Quarterly business report summary",
        "category:report");

    await provider.SaveInformationAsync(collection,
        "Performance tracking dashboards show a steady increase in throughput and a reduction in processing latency.",
        "mh-004",
        "Performance tracking overview",
        "category:metrics");
}
```

### 9. 執行情景

此範例執行多個情景以示範不同的檢索模式。

```csharp
var scenarios = new[]
{
    // Likely to be answered in 1-2 hops
    "What does the data privacy policy mandate about encryption and retention?",
    // Intentionally vague to trigger refinement and threshold relaxation
    "Tell me about customer docs and secure handling",
    // Another query that may need widened search
    "Summarize insights from the business reports and performance tracking"
};

foreach (var question in scenarios)
{
    Console.WriteLine($"🧑‍💻 User: {question}");
    var args = new KernelArguments
    {
        ["user_question"] = question,
        ["max_attempts"] = 4,
        ["min_required_chunks"] = 2,
        ["top_k"] = 4,
        ["min_score"] = 0.45
    };

    var result = await executor.ExecuteAsync(kernel, args);
    var answer = result.GetValue<string>() ?? "No answer produced";
    Console.WriteLine($"🤖 Agent: {answer}\n");
    await Task.Delay(250);
}
```

## 預期輸出

此範例產生全面的輸出，顯示：

* 🧑‍💻 使用者問題和搜尋查詢
* 🔍 具有不同參數的檢索嘗試
* 📊 背景評估和品質評估
* 🔄 查詢優化和重試機制
* 🤖 來自累積背景的最終合成答案
* ✅ 多跳躍 RAG 工作流程完成

## 故障排除

### 常見問題

1. **知識庫連接失敗**：確保 Kernel Memory 正確配置
2. **檢索品質問題**：調整 top_k 和 min_score 參數以獲得更好的結果
3. **無限重試迴圈**：設定適當的 max_attempts 和評估準則
4. **背景不足**：驗證知識庫內容和查詢優化邏輯

### 除錯提示

* 監視每次嘗試的檢索分數和區塊計數
* 檢查查詢優化參數及其進度
* 驗證背景評估邏輯和充分性準則
* 監視重試迴圈以防止無限反覆

## 另請參閱

* [RAG 模式](../patterns/rag.md)
* [記憶和檢索](../concepts/memory.md)
* [條件節點](../concepts/node-types.md)
* [圖形執行](../concepts/execution.md)
* [查詢優化](../how-to/query-optimization.md)
