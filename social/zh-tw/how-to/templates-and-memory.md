# 模板和記憶整合

本指南說明如何使用 SemanticKernel.Graph 的範本引擎系統，並與記憶服務整合以增強圖表執行功能。

## 概觀

SemanticKernel.Graph 提供了全面的範本和記憶系統，能夠實現：

* **動態提示生成** 使用具有變數替代的範本引擎
* **工作流範本** 用於可重複使用的圖表模式
* **記憶整合** 用於儲存和擷取執行上下文
* **向量和語義搜尋** 功能以增強決策能力

## 範本引擎系統

### 核心組件

範本系統包含幾個關鍵元件：

* **`IGraphTemplateEngine`**: 範本呈現引擎的介面
* **`GraphTemplateOptions`**: 範本功能的配置選項
* **`IWorkflowTemplate`**: 用於建立可執行圖表的藍圖
* **`WorkflowTemplateRegistry`**: 用於探索和使用範本的中央登錄

### 範本引擎類型

#### HandlebarsGraphTemplateEngine

提供類似 Handlebars 語法的預設範本引擎：

```csharp
// Enable Handlebars templates
builder.AddGraphTemplates(opts =>
{
    opts.EnableHandlebars = true;
    opts.EnableCustomHelpers = true;
    opts.TemplateCacheSize = 100;
});
```

**特性:**
* 變數替代: `{{variable}}`
* 輔助函數: `{{helper arg1 arg2}}`
* 條件陳述: `{{#if condition}}...{{else}}...{{/if}}`
* 範本編譯和快取
* 自訂輔助函數註冊

#### 專用範本引擎

**ChainOfThoughtTemplateEngine**: 針對推理模式進行最佳化，提供領域特定範本和漸進步驟調整。

**ReActTemplateEngine**: 為 ReAct 模式提示進行專門優化，具有領域最佳化和上下文感知呈現。

### 在圖表節點中使用範本

範本可直接在圖表節點中用於動態內容生成：

```csharp
var templateEngine = serviceProvider.GetService<IGraphTemplateEngine>();

// Render template with context
var prompt = await templateEngine.RenderAsync(
    "Hello {{name}}, your current status is {{status}}",
    new { name = "User", status = "active" }
);

// Render with graph state
var statePrompt = await templateEngine.RenderWithStateAsync(
    "Previous result: {{previous_result}}",
    graphState
);
```

### 自訂範本輔助函數

註冊自訂函數以在範本中使用：

```csharp
// Synchronous helper
templateEngine.RegisterHelper("formatDate", args =>
{
    if (args.Length > 0 && args[0] is DateTime date)
        return date.ToString("yyyy-MM-dd");
    return "Invalid date";
});

// Asynchronous helper (useful for memory lookups)
templateEngine.RegisterAsyncHelper("searchMemory", async args =>
{
    var query = args[0]?.ToString() ?? "";
    var memoryService = serviceProvider.GetService<IGraphMemoryService>();
    var results = await memoryService.SearchRelevantMemoryAsync("node1", query);
    return string.Join(", ", results.Select(r => r.Content));
});
```

## 工作流範本

### 內建範本

SemanticKernel.Graph 包含幾個預先建立的工作流範本：

#### 聊天機器人範本 (`chatbot/basic`)

使用選用推理建立基本聊天機器人工作流：

```csharp
var template = registry.GetLatest("chatbot/basic");
var parameters = new Dictionary<string, object>
{
    ["graph_name"] = "my-chatbot",
    ["use_reasoning"] = true,
    ["responder_plugin"] = "ChatPlugin",
    ["responder_function"] = "Respond"
};

var executor = template.BuildGraph(kernel, parameters, serviceProvider);
```

#### 思考鏈範本 (`reasoning/cot-basic`)

使用可配置參數建立推理節點：

```csharp
var template = registry.GetLatest("reasoning/cot-basic");
var parameters = new Dictionary<string, object>
{
    ["graph_name"] = "reasoning-graph",
    ["type"] = ChainOfThoughtType.ProblemSolving,
    ["max_steps"] = 8
};

var executor = template.BuildGraph(kernel, parameters, serviceProvider);
```

#### ReAct 範本 (`react/loop-basic`)

使用推理和動作選擇建立 ReAct 迴圈：

```csharp
var template = registry.GetLatest("react/loop-basic");
var parameters = new Dictionary<string, object>
{
    ["graph_name"] = "react-agent",
    ["domain"] = ReActDomain.ProblemSolving,
    ["max_iterations"] = 15,
    ["goal_threshold"] = 0.9
};

var executor = template.BuildGraph(kernel, parameters, serviceProvider);
```

#### 文件分析範本 (`analysis/document-basic`)

建立文件處理管線：

```csharp
var template = registry.GetLatest("analysis/document-basic");
var parameters = new Dictionary<string, object>
{
    ["graph_name"] = "doc-pipeline",
    ["ingest_plugin"] = "DocumentPlugin",
    ["ingest_function"] = "IngestDocument",
    ["analyze_plugin"] = "AnalysisPlugin",
    ["analyze_function"] = "AnalyzeContent",
    ["summarize_plugin"] = "SummaryPlugin",
    ["summarize_function"] = "GenerateSummary"
};

var executor = template.BuildGraph(kernel, parameters, serviceProvider);
```

### 範本分類和功能

範本按目的分類並聲明所需功能：

```csharp
public enum TemplateCategory
{
    Chatbot,      // Conversational workflows
    Analysis,     // Data processing pipelines
    Reasoning,    // Cognitive reasoning patterns
    MultiAgent,   // Multi-agent coordination
    Integration,  // External system integration
    Custom        // User-defined templates
}

[Flags]
public enum TemplateCapabilities
{
    None = 0,
    Templates = 1 << 0,        // Basic template support
    DynamicRouting = 1 << 1,   // Dynamic routing capabilities
    Memory = 1 << 2,           // Memory integration required
    Streaming = 1 << 3,        // Streaming execution support
    Checkpointing = 1 << 4,    // Checkpointing capabilities
    Recovery = 1 << 5,         // Recovery mechanisms
}
```

### 建立自訂範本

實作 `IWorkflowTemplate` 以建立自訂工作流範本：

```csharp
public sealed class CustomWorkflowTemplate : IWorkflowTemplate
{
    public string TemplateId => "custom/my-workflow";
    public string Name => "Custom Workflow";
    public string Version => "1.0.0";
    public TemplateCategory Category => TemplateCategory.Custom;
    public string Description => "Custom workflow for specific use case";
    public TemplateCapabilities RequiredCapabilities => TemplateCapabilities.Templates;

    public IReadOnlyList<TemplateParameter> Parameters => new List<TemplateParameter>
    {
        new() { Name = "graph_name", Required = true },
        new() { Name = "custom_param", Description = "Custom parameter", DefaultValue = "default" }
    }.AsReadOnly();

    public WorkflowTemplateValidationResult ValidateParameters(IDictionary<string, object> parameters)
    {
        var errors = new List<string>();
        if (!parameters.ContainsKey("graph_name"))
            errors.Add("Missing required parameter 'graph_name'");
        
        return errors.Count == 0 
            ? WorkflowTemplateValidationResult.Success() 
            : WorkflowTemplateValidationResult.Failure(errors);
    }

    public GraphExecutor BuildGraph(Kernel kernel, IDictionary<string, object> parameters, IServiceProvider serviceProvider)
    {
        var validation = ValidateParameters(parameters);
        if (!validation.IsValid)
            throw new ArgumentException($"Invalid parameters: {string.Join(", ", validation.Errors)}");

        var name = parameters["graph_name"].ToString()!;
        var executor = new GraphExecutor(name, $"Custom workflow ({Name} {Version})");
        
        // Build your custom graph here
        // Add nodes, connections, etc.
        
        return executor;
    }
}
```

## 記憶整合

### 記憶服務配置

使用可配置選項啟用記憶整合：

```csharp
builder.AddGraphMemory(opts =>
{
    opts.EnableVectorSearch = true;
    opts.EnableSemanticSearch = true;
    opts.DefaultCollectionName = "graph-memory";
    opts.SimilarityThreshold = 0.7;
});
```

### 記憶服務特性

`IGraphMemoryService` 提供幾個關鍵功能：

#### 儲存執行上下文

```csharp
var memoryService = serviceProvider.GetService<IGraphMemoryService>();

await memoryService.StoreExecutionContextAsync(
    executionId: "exec-123",
    graphState: currentState,
    metadata: new Dictionary<string, object>
    {
        ["nodeCount"] = 5,
        ["executionTime"] = TimeSpan.FromSeconds(10)
    }
);
```

#### 尋找類似的執行

```csharp
var similarExecutions = await memoryService.FindSimilarExecutionsAsync(
    currentState: currentState,
    limit: 5,
    minSimilarity: 0.8
);

foreach (var execution in similarExecutions)
{
    Console.WriteLine($"Similar execution: {execution.ExecutionId} (score: {execution.SimilarityScore:F3})");
}
```

#### 節點特定記憶

```csharp
// Store node execution results
await memoryService.StoreNodeExecutionAsync(
    nodeId: "reasoning-node",
    input: inputArgs,
    output: functionResult,
    executionContext: "exec-123"
);

// Search relevant memory for a node
var relevantMemory = await memoryService.SearchRelevantMemoryAsync(
    nodeId: "reasoning-node",
    query: "How to solve this type of problem?",
    limit: 10
);
```

### 記憶提供者整合

針對進階記憶情景，實作 `IGraphMemoryProvider`：

```csharp
public sealed class CustomMemoryProvider : IGraphMemoryProvider
{
    public bool IsAvailable => true;

    public Task SaveInformationAsync(string collectionName, string text, string id,
        string? description = null, string? additionalMetadata = null,
        CancellationToken cancellationToken = default)
    {
        // Implement custom storage logic
        // e.g., save to database, vector store, etc.
        return Task.CompletedTask;
    }

    public async IAsyncEnumerable<MemorySearchResult> SearchAsync(
        string collectionName, string query, int limit = 10, 
        double minRelevanceScore = 0.7, CancellationToken cancellationToken = default)
    {
        // Implement custom search logic
        // e.g., vector similarity search, semantic search, etc.
        yield break;
    }
}
```

## 進階配置

### 完整圖表支援

使用所有功能的全面配置：

```csharp
builder.AddCompleteGraphSupport(opts =>
{
    opts.EnableTemplates = true;
    opts.EnableMemory = true;
    opts.EnableVectorSearch = true;
    opts.EnableSemanticSearch = true;
    opts.EnableCustomHelpers = true;
    opts.MaxExecutionSteps = 1000;
});
```

### 範本引擎選擇

根據您的需求選擇特定的範本引擎：

```csharp
// For reasoning-heavy workflows
builder.Services.AddSingleton<IGraphTemplateEngine, ChainOfThoughtTemplateEngine>();

// For ReAct patterns
builder.Services.AddSingleton<IGraphTemplateEngine, ReActTemplateEngine>();

// For general purpose
builder.Services.AddSingleton<IGraphTemplateEngine, HandlebarsGraphTemplateEngine>();
```

## 最佳實踐

### 範本設計

1. **參數驗證**: 在建立圖表前一律驗證範本參數
2. **預設值**: 為選用參數提供合理的預設值
3. **功能聲明**: 準確聲明所需功能
4. **版本控制**: 對範本更新使用語義版本控制

### 記憶使用

1. **上下文儲存**: 儲存執行上下文以供日後參考和學習
2. **相似性閾值**: 根據您的使用情況調整相似性閾值
3. **記憶清理**: 為舊記憶項目實作清理策略
4. **後設資料**: 使用後設資料分類和篩選記憶項目

### 效能考量

1. **範本快取**: 利用範本編譯和快取
2. **記憶限制**: 為記憶儲存和搜尋設定適當的限制
3. **非同步操作**: 對外部服務呼叫使用非同步輔助函數
4. **批次操作**: 盡可能分組記憶操作

## 疑難排解

### 常見問題

**範本呈現錯誤**
* 確保所有必要的變數都在上下文中提供
* 檢查範本語法是否正確符合 Handlebars 格式
* 驗證自訂輔助函數是否正確註冊

**記憶整合問題**
* 確認記憶服務已正確配置和登錄
* 檢查相似性閾值是否適合您的資料
* 驗證記憶提供者可用性

**範本登錄問題**
* 確保範本已在 DI 容器中正確登錄
* 檢查範本 ID 和版本的唯一性
* 驗證範本參數驗證邏輯

### 除錯提示

1. **啟用記錄**: 使用內建記錄來追蹤範本和記憶操作
2. **範本驗證**: 使用 `ValidateParameters` 及早捕捉配置問題
3. **記憶檢查**: 檢查記憶服務日誌以進行儲存和擷取操作
4. **範本編譯**: 在執行前驗證範本編譯正確

## 另請參閱

* [圖表概念](../concepts/graph-concepts.md) - 核心圖表概念和術語
* [狀態管理](../how-to/state-management.md) - 使用圖表狀態和引數
* [條件節點](../how-to/conditional-nodes.md) - 動態路由和決策制定
* [多代理工作流](../how-to/multi-agent-and-shared-state.md) - 協調多個代理
* [API 參考](../api/) - 範本和記憶類型的完整 API 文件
