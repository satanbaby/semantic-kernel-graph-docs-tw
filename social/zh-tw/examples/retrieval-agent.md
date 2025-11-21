# 檢索代理範例

此範例演示一個問答代理，可從知識庫檢索相關內容，並使用檢索增強生成 (RAG) 合成答案。

## 目標

學習如何在 Semantic Kernel Graph 中實現檢索增強生成工作流程：
* 建立包含三個步驟的線性檢索問答管道
* 實現問題分析和搜尋查詢生成
* 從知識庫檢索相關內容
* 使用檢索到的內容合成完整答案
* 展示 RAG 風格的問答能力

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中設定
* **Semantic Kernel Graph 套件**已安裝
* **Kernel Memory** 已為知識庫操作設定
* 對 [Graph Concepts](../concepts/graph-concepts.md) 和 [RAG Patterns](../patterns/rag.md) 的基本了解
* 熟悉 [Memory and Retrieval](../concepts/memory.md)

## 關鍵元件

### 概念和技術

* **檢索增強生成 (RAG)**：結合檢索和生成以獲得準確答案
* **問題分析**：理解和重新表述使用者問題以改進檢索
* **上下文檢索**：從知識庫尋找相關資訊
* **答案合成**：使用檢索到的內容生成完整答案
* **知識庫管理**：索引和搜尋結構化資訊

### 核心類別

* `GraphExecutor`：檢索代理工作流程的執行器
* `FunctionGraphNode`：用於問題分析、檢索和答案合成的節點
* `KernelMemoryGraphProvider`：知識庫操作的提供者
* `ConditionalEdge`：工作流程控制的圖邊
* `GraphState`：檢索結果和內容的狀態管理

## 執行範例

### 開始使用

此範例使用 Semantic Kernel Graph 套件演示檢索增強生成 (RAG) 模式。下面的程式碼片段顯示如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. 知識庫設定

此範例首先使用範例內容設定知識庫。

```csharp
// Create a lightweight in-memory provider and seed the collection with sample docs
var memoryProvider = new SimpleMemoryProvider();
var collection = "kb_general";

await SeedKnowledgeBaseAsync(memoryProvider, collection);

private static async Task SeedKnowledgeBaseAsync(SimpleMemoryProvider provider, string collection)
{
    // Add a few short documents to the in-memory knowledge base
    await provider.SaveInformationAsync(collection,
        "The Semantic Kernel Graph is a powerful extension to build complex workflows with graphs, enabling conditional routing, memory integration, and performance metrics.",
        "kb-001",
        "Project overview",
        "category:overview");

    await provider.SaveInformationAsync(collection,
        "Data privacy is handled through encryption at rest and in transit, with role-based access controls and audit logging for compliance with GDPR and other regulations.",
        "kb-002",
        "Data privacy",
        "category:security");

    await provider.SaveInformationAsync(collection,
        "The quarterly business report shows 25% improvement in system performance, 40% reduction in response times, and 15% increase in user satisfaction scores.",
        "kb-003",
        "Business report",
        "category:performance");

    Console.WriteLine("✅ Knowledge base seeded with sample content");
}
```

### 2. 建立檢索代理

代理以線性三步管道構建：分析、檢索和答案。

```csharp
// Compose a simple linear graph: analyze -> retrieve -> synthesize
var executor = new GraphExecutor(kernel);

var analyze = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((KernelArguments args) =>
    {
        // Implementation provided below in the Analysis function snippet
        var question = args.TryGetValue("user_question", out var q) ? q?.ToString() ?? string.Empty : string.Empty;
        var searchQuery = question.ToLowerInvariant()
            .Replace("what", string.Empty)
            .Replace("how", string.Empty)
            .Replace("benefits", "benefits advantages features")
            .Trim();

        args["search_query"] = searchQuery;
        return $"Search query generated: {searchQuery}";
    }, functionName: "analyze_question", description: "Analyze the user question"),
    "analyze_question").StoreResultAs("search_query");

var retrieve = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(async (KernelArguments args) =>
    {
        // Implementation provided below in the Retrieval function snippet
        return "retrieved";
    }, functionName: "retrieve_context", description: "Retrieve relevant context"),
    "retrieve_context").StoreResultAs("retrieved_context");

var synth = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((KernelArguments args) =>
    {
        // Implementation provided below in the Synthesis snippet
        return "answer";
    }, functionName: "synthesize_answer", description: "Synthesize the final answer"),
    "synthesize_answer").StoreResultAs("final_answer");

executor.AddNode(analyze);
executor.AddNode(retrieve);
executor.AddNode(synth);

executor.SetStartNode(analyze.NodeId);
executor.AddEdge(ConditionalEdge.CreateUnconditional(analyze, retrieve));
executor.AddEdge(ConditionalEdge.CreateUnconditional(retrieve, synth));

return executor;
```

### 3. 問題分析函數

分析函數理解使用者問題並生成聚焦的搜尋查詢。

```csharp
// Analysis function: converts a free-form question into a compact search query
private static KernelFunction CreateAnalyzeQuestionFunction(Kernel kernel)
{
    return KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var question = args.TryGetValue("user_question", out var q) ? q?.ToString() ?? string.Empty : string.Empty;

            // Simplify question text and expand some terms to improve retrieval
            var searchQuery = question.ToLowerInvariant()
                .Replace("what", string.Empty)
                .Replace("how", string.Empty)
                .Replace("benefits", "benefits advantages features")
                .Replace("handled", "handled managed implemented")
                .Replace("improvements", "improvements enhancements progress")
                .Trim();

            if (question.Contains("semantic kernel graph", StringComparison.OrdinalIgnoreCase))
            {
                searchQuery += " semantic kernel graph workflow";
            }

            if (question.Contains("data privacy", StringComparison.OrdinalIgnoreCase) || question.Contains("encryption", StringComparison.OrdinalIgnoreCase))
            {
                searchQuery += " data privacy encryption security compliance";
            }

            args["search_query"] = searchQuery;
            return $"Search query generated: {searchQuery}";
        },
        functionName: "analyze_question",
        description: "Analyzes user questions and generates focused search queries"
    );
}
```

### 4. 內容檢索函數

檢索函數在知識庫中搜尋相關資訊。

```csharp
// Retrieval function: queries the knowledge base and formats results for synthesis
private static KernelFunction CreateRetrieveContextFunction(Kernel kernel, SimpleMemoryProvider memoryProvider, string collection)
{
    return KernelFunctionFactory.CreateFromMethod(
        async (KernelArguments args) =>
        {
            var query = args.TryGetValue("search_query", out var q) ? q?.ToString() ?? string.Empty : string.Empty;
            var topK = args.TryGetValue("top_k", out var tk) && tk is int k ? k : 5;
            var minScore = args.TryGetValue("min_score", out var ms) && ms is double s ? s : 0.0;

            // Retrieve relevant context from the in-memory provider
            var results = await memoryProvider.SearchAsync(collection, query, topK, minScore);

            if (!results.Any())
            {
                args["retrieved_context"] = "No relevant context found for the query.";
                return "No relevant context retrieved";
            }

            // Format retrieved context for answer synthesis
            var context = string.Join("\n\n", results.Select(r =>
                $"Source: {r.Metadata.GetValueOrDefault("source", "Unknown")}\nContent: {r.Text}"));

            args["retrieved_context"] = context;
            args["retrieval_count"] = results.Count;
            args["retrieval_score"] = results.Max(r => r.Score);

            return $"Retrieved {results.Count} relevant context items with max score {results.Max(r => r.Score):F3}";
        },
        functionName: "retrieve_context",
        description: "Retrieves relevant context from the knowledge base"
    );
}
```

### 5. 答案合成函數

合成函數將檢索到的內容合併為完整答案。

```csharp
// Synthesis function: combine retrieved context into a readable answer
private static KernelFunction CreateSynthesizeAnswerFunction(Kernel kernel)
{
    return KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var question = args.TryGetValue("user_question", out var q) ? q?.ToString() ?? string.Empty : string.Empty;
            var context = args.TryGetValue("retrieved_context", out var c) ? c?.ToString() ?? string.Empty : string.Empty;
            var retrievalCount = args.TryGetValue("retrieval_count", out var rc) && rc is int count ? count : 0;
            var retrievalScore = args.TryGetValue("retrieval_score", out var rs) && rs is double score ? score : 0.0;

            if (string.IsNullOrEmpty(context) || context.Contains("No relevant context found"))
            {
                return "I don't have enough information to answer that question accurately. Please try rephrasing.";
            }

            // Build a concise answer using retrieved context
            var answer = $"Based on the available information:\n\n{context}\n\n" +
                        $"This answer was synthesized from {retrievalCount} relevant sources (confidence: {retrievalScore:F2}).";

            args["final_answer"] = answer;
            return answer;
        },
        functionName: "synthesize_answer",
        description: "Synthesizes final answers using retrieved context"
    );
}
```

### 6. 問題處理

此範例透過檢索代理處理多個問題，以展示檢索功能。

```csharp
// Run a few sample questions through the retrieval agent to demonstrate behavior
var questions = new[]
{
    "What benefits does the Semantic Kernel Graph provide?",
    "How are data privacy and encryption handled?",
    "What improvements were reported in the quarterly business report?"
};

foreach (var q in questions)
{
    Console.WriteLine($"🧑‍💻 User: {q}");
    var args = new KernelArguments
    {
        ["user_question"] = q,
        ["top_k"] = 5,
        ["min_score"] = 0.0
    };

    var result = await executor.ExecuteAsync(kernel, args);
    var answer = result.GetValue<string>() ?? "No answer produced";
    Console.WriteLine($"🤖 Agent: {answer}\n");
    await Task.Delay(200);
}
```

### 7. 增強的知識庫內容

此範例包括更多全面的知識庫內容，以改進檢索。

```csharp
private static async Task SeedKnowledgeBaseAsync(KernelMemoryGraphProvider provider, string collection)
{
    var documents = new[]
    {
        new
        {
            Content = "The Semantic Kernel Graph is a powerful extension to build complex workflows with graphs, enabling conditional routing, memory integration, and performance metrics. It provides benefits such as improved workflow management, better error handling, and enhanced observability.",
            Id = "kb-001",
            Source = "Project overview",
            Tags = "category:overview,benefits,workflow"
        },
        new
        {
            Content = "Data privacy is handled through encryption at rest and in transit, with role-based access controls and audit logging for compliance with GDPR and other regulations. The system implements end-to-end encryption and provides granular permission management.",
            Id = "kb-002",
            Source = "Data privacy",
            Tags = "category:security,encryption,compliance"
        },
        new
        {
            Content = "The quarterly business report shows 25% improvement in system performance, 40% reduction in response times, and 15% increase in user satisfaction scores. These improvements were achieved through optimization efforts and infrastructure upgrades.",
            Id = "kb-003",
            Source = "Business report",
            Tags = "category:performance,metrics,improvements"
        },
        new
        {
            Content = "Semantic Kernel Graph features include advanced routing capabilities, checkpointing for long-running workflows, streaming execution support, and comprehensive monitoring and debugging tools.",
            Id = "kb-004",
            Source = "Feature overview",
            Tags = "category:features,routing,checkpointing"
        },
        new
        {
            Content = "Security measures include multi-factor authentication, encrypted communication channels, regular security audits, and compliance with industry standards like SOC 2 and ISO 27001.",
            Id = "kb-005",
            Source = "Security overview",
            Tags = "category:security,authentication,compliance"
        }
    };

    foreach (var doc in documents)
    {
        await provider.SaveInformationAsync(collection, doc.Content, doc.Id, doc.Source, doc.Tags);
    }

    Console.WriteLine($"✅ Knowledge base seeded with {documents.Length} documents");
}
```

### 8. 進階檢索選項

此範例支援可配置的檢索參數，適用於不同的使用情況。

```csharp
// Configure retrieval parameters based on question complexity
var retrievalParams = question.ToLowerInvariant() switch
{
    var q when q.Contains("benefits") || q.Contains("features") => 
        new { TopK = 3, MinScore = 0.4 }, // Focused retrieval for specific topics
    var q when q.Contains("how") || q.Contains("process") => 
        new { TopK = 5, MinScore = 0.35 }, // Broader retrieval for process questions
    var q when q.Contains("what") && q.Contains("improvements") => 
        new { TopK = 4, MinScore = 0.3 }, // Comprehensive retrieval for improvement questions
    _ => new { TopK = 5, MinScore = 0.35 } // Default parameters
};

var args = new KernelArguments
{
    ["user_question"] = question,
    ["top_k"] = retrievalParams.TopK,
    ["min_score"] = retrievalParams.MinScore
};
```

## 預期輸出

此範例生成詳細輸出，顯示：

* 🧑‍💻 使用者問題和搜尋查詢分析
* 🔍 從知識庫檢索內容
* 📊 檢索分數和結果計數
* 🤖 使用檢索到的內容合成答案
* ✅ 完整的 RAG 工作流程執行
* 📚 知識庫內容和檢索品質

## 故障排除

### 常見問題

1. **知識庫連線失敗**：確保 Kernel Memory 已正確設定
2. **檢索品質問題**：調整 top_k 和 min_score 參數以獲得更好的結果
3. **內容不足**：驗證知識庫內容和搜尋查詢生成
4. **答案合成失敗**：檢查內容格式和合成邏輯

### 調試提示

* 監控搜尋查詢生成和改進
* 驗證知識庫內容索引和搜尋功能
* 檢查檢索參數和計分閾值
* 監控答案合成品質和內容利用

## 另請參閱

* [RAG Patterns](../patterns/rag.md)
* [Memory and Retrieval](../concepts/memory.md)
* [Question Answering](../concepts/qa-systems.md)
* [Knowledge Base Management](../how-to/knowledge-base.md)
* [Context Retrieval](../concepts/retrieval.md)
