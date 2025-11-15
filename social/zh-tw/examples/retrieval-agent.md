# 檢索代理範例

此範例演示了一個問答代理，該代理從知識庫中檢索相關內容，並使用檢索增強生成（RAG）綜合答案。

## 目標

了解如何在語義核心圖中實現檢索增強生成工作流，以：
* 創建具有三個步驟的線性檢索問答管道
* 實現問題分析和搜尋查詢生成
* 從知識庫檢索相關內容
* 使用檢索到的內容綜合全面的答案
* 演示 RAG 風格的問答能力

## 先決條件

* **.NET 8.0** 或更高版本
* **OpenAI API 金鑰**在 `appsettings.json` 中配置
* **語義核心圖套件**已安裝
* **內核記憶體**為知識庫操作配置
* 對[圖概念](../concepts/graph-concepts.md)和 [RAG 模式](../patterns/rag.md)的基本理解
* 熟悉[記憶和檢索](../concepts/memory.md)

## 主要組件

### 概念和技術

* **檢索增強生成（RAG）**：將檢索與生成結合以獲得準確答案
* **問題分析**：理解和重新表述用戶問題以改善檢索
* **內容檢索**：從知識庫尋找相關信息
* **答案綜合**：使用檢索到的內容生成全面答案
* **知識庫管理**：索引和搜尋結構化信息

### 核心類別

* `GraphExecutor`：檢索代理工作流的執行器
* `FunctionGraphNode`：用於問題分析、檢索和答案綜合的節點
* `KernelMemoryGraphProvider`：用於知識庫操作的提供者
* `ConditionalEdge`：用於工作流控制的圖邊
* `GraphState`：用於檢索結果和內容的狀態管理

## 執行範例

### 入門

此範例演示了語義核心圖套件中的檢索增強生成（RAG）模式。下面的代碼片段展示了如何在自己的應用程序中實現此模式。

## 分步實現

### 1. 知識庫設置

該範例首先設置一個包含示例內容的知識庫。

```csharp
// 創建一個輕量級的內存提供者，並用示例文件為集合填充
var memoryProvider = new SimpleMemoryProvider();
var collection = "kb_general";

await SeedKnowledgeBaseAsync(memoryProvider, collection);

private static async Task SeedKnowledgeBaseAsync(SimpleMemoryProvider provider, string collection)
{
    // 將幾個簡短的文件添加到內存知識庫
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

### 2. 創建檢索代理

該代理由線性三步管道組成：分析、檢索和綜合。

```csharp
// 組合一個簡單的線性圖：分析 -> 檢索 -> 綜合
var executor = new GraphExecutor(kernel);

var analyze = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((KernelArguments args) =>
    {
        // 實現在下面的分析函數片段中提供
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
        // 實現在下面的檢索函數片段中提供
        return "retrieved";
    }, functionName: "retrieve_context", description: "Retrieve relevant context"),
    "retrieve_context").StoreResultAs("retrieved_context");

var synth = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((KernelArguments args) =>
    {
        // 實現在下面的綜合片段中提供
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

分析函數理解用戶問題並生成重點搜尋查詢。

```csharp
// 分析函數：將自由形式的問題轉換為簡潔搜尋查詢
private static KernelFunction CreateAnalyzeQuestionFunction(Kernel kernel)
{
    return KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var question = args.TryGetValue("user_question", out var q) ? q?.ToString() ?? string.Empty : string.Empty;

            // 簡化問題文本並擴展某些術語以改善檢索
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

檢索函數搜尋知識庫以查找相關信息。

```csharp
// 檢索函數：查詢知識庫並格式化結果以進行綜合
private static KernelFunction CreateRetrieveContextFunction(Kernel kernel, SimpleMemoryProvider memoryProvider, string collection)
{
    return KernelFunctionFactory.CreateFromMethod(
        async (KernelArguments args) =>
        {
            var query = args.TryGetValue("search_query", out var q) ? q?.ToString() ?? string.Empty : string.Empty;
            var topK = args.TryGetValue("top_k", out var tk) && tk is int k ? k : 5;
            var minScore = args.TryGetValue("min_score", out var ms) && ms is double s ? s : 0.0;

            // 從內存提供者檢索相關內容
            var results = await memoryProvider.SearchAsync(collection, query, topK, minScore);

            if (!results.Any())
            {
                args["retrieved_context"] = "No relevant context found for the query.";
                return "No relevant context retrieved";
            }

            // 為答案綜合格式化檢索到的內容
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

### 5. 答案綜合函數

綜合函數將檢索到的內容組合成全面的答案。

```csharp
// 綜合函數：將檢索到的內容組合成可讀答案
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

            // 使用檢索到的內容構建簡潔答案
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

該範例處理多個問題以演示檢索能力。

```csharp
// 通過檢索代理執行幾個示例問題以演示行為
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

該範例包括更全面的知識庫內容以改善檢索。

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

### 8. 高級檢索選項

該範例支持可配置的檢索參數以適應不同用例。

```csharp
// 根據問題複雜性配置檢索參數
var retrievalParams = question.ToLowerInvariant() switch
{
    var q when q.Contains("benefits") || q.Contains("features") => 
        new { TopK = 3, MinScore = 0.4 }, // 特定主題的重點檢索
    var q when q.Contains("how") || q.Contains("process") => 
        new { TopK = 5, MinScore = 0.35 }, // 用於流程問題的更廣泛檢索
    var q when q.Contains("what") && q.Contains("improvements") => 
        new { TopK = 4, MinScore = 0.3 }, // 用於改進問題的全面檢索
    _ => new { TopK = 5, MinScore = 0.35 } // 默認參數
};

var args = new KernelArguments
{
    ["user_question"] = question,
    ["top_k"] = retrievalParams.TopK,
    ["min_score"] = retrievalParams.MinScore
};
```

## 預期輸出

該範例生成全面的輸出，顯示：

* 🧑‍💻 用戶問題和搜尋查詢分析
* 🔍 從知識庫檢索內容
* 📊 檢索分數和結果計數
* 🤖 使用檢索到的內容綜合的答案
* ✅ 完整的 RAG 工作流執行
* 📚 知識庫內容和檢索質量

## 故障排除

### 常見問題

1. **知識庫連接失敗**：確保內核記憶體正確配置
2. **檢索質量問題**：調整 top_k 和 min_score 參數以獲得更好的結果
3. **內容不足**：驗證知識庫內容和搜尋查詢生成
4. **答案綜合失敗**：檢查內容格式化和綜合邏輯

### 調試提示

* 監視搜尋查詢生成和改進
* 驗證知識庫內容索引和搜尋功能
* 檢查檢索參數和評分閾值
* 監視答案綜合質量和內容利用

## 另請參閱

* [RAG 模式](../patterns/rag.md)
* [記憶和檢索](../concepts/memory.md)
* [問答系統](../concepts/qa-systems.md)
* [知識庫管理](../how-to/knowledge-base.md)
* [內容檢索](../concepts/retrieval.md)
