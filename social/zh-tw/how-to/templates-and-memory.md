# 範本與記憶體整合

本指南說明如何使用 SemanticKernel.Graph 的範本引擎系統，以及與記憶體服務進行整合以增強圖形執行功能。

## 概述

SemanticKernel.Graph 提供了一套完整的範本與記憶體系統，可實現以下功能：

* **動態提示詞生成**：使用範本引擎進行變數替換
* **工作流程範本**：可重複使用的圖形模式
* **記憶體整合**：儲存和擷取執行內容
* **向量與語義搜尋**：增強決策能力

## 範本引擎系統

### 核心元件

範本系統包含多個主要元件：

* **`IGraphTemplateEngine`**：範本渲染引擎介面
* **`GraphTemplateOptions`**：範本功能的配置選項
* **`IWorkflowTemplate`**：可執行圖形的藍圖
* **`WorkflowTemplateRegistry`**：用於發現和使用範本的中央登錄

### 範本引擎類型

#### HandlebarsGraphTemplateEngine

提供類似 Handlebars 語法的預設範本引擎：

```csharp
// 啟用 Handlebars 範本
builder.AddGraphTemplates(opts =>
{
    opts.EnableHandlebars = true;
    opts.EnableCustomHelpers = true;
    opts.TemplateCacheSize = 100;
});
```

**功能：**
* 變數替換：`{{variable}}`
* 輔助函數：`{{helper arg1 arg2}}`
* 條件陳述式：`{{#if condition}}...{{else}}...{{/if}}`
* 範本編譯與快取
* 自訂輔助函數註冊

#### 特化範本引擎

**ChainOfThoughtTemplateEngine**：針對推理模式最佳化，提供特定領域的範本和漸進式步驟調整。

**ReActTemplateEngine**：為 ReAct 模式提示詞特化，具有領域最佳化和上下文感知的渲染。

### 在圖形節點中使用範本

可直接在圖形節點中使用範本進行動態內容生成：

```csharp
var templateEngine = serviceProvider.GetService<IGraphTemplateEngine>();

// 以內容渲染範本
var prompt = await templateEngine.RenderAsync(
    "Hello {{name}}, your current status is {{status}}",
    new { name = "User", status = "active" }
);

// 以圖形狀態渲染
var statePrompt = await templateEngine.RenderWithStateAsync(
    "Previous result: {{previous_result}}",
    graphState
);
```

### 自訂範本輔助函數

註冊自訂函數以在範本中使用：

```csharp
// 同步輔助函數
templateEngine.RegisterHelper("formatDate", args =>
{
    if (args.Length > 0 && args[0] is DateTime date)
        return date.ToString("yyyy-MM-dd");
    return "Invalid date";
});

// 非同步輔助函數（適用於記憶體查詢）
templateEngine.RegisterAsyncHelper("searchMemory", async args =>
{
    var query = args[0]?.ToString() ?? "";
    var memoryService = serviceProvider.GetService<IGraphMemoryService>();
    var results = await memoryService.SearchRelevantMemoryAsync("node1", query);
    return string.Join(", ", results.Select(r => r.Content));
});
```

## 工作流程範本

### 內建範本

SemanticKernel.Graph 包含多個預先建立的工作流程範本：

#### 聊天機器人範本（`chatbot/basic`）

建立基本的聊天機器人工作流程，可選擇推理：

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

#### 思維鏈範本（`reasoning/cot-basic`）

建立具有可配置參數的推理節點：

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

#### ReAct 範本（`react/loop-basic`）

建立具有推理和行動選擇的 ReAct 循環：

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

#### 文件分析範本（`analysis/document-basic`）

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

### 範本分類與功能

範本按用途分類並聲明所需的功能：

```csharp
public enum TemplateCategory
{
    Chatbot,      // 對話工作流程
    Analysis,     // 資料處理管線
    Reasoning,    // 認知推理模式
    MultiAgent,   // 多代理協調
    Integration,  // 外部系統整合
    Custom        // 使用者定義的範本
}

[Flags]
public enum TemplateCapabilities
{
    None = 0,
    Templates = 1 << 0,        // 基本範本支援
    DynamicRouting = 1 << 1,   // 動態路由功能
    Memory = 1 << 2,           // 需要記憶體整合
    Streaming = 1 << 3,        // 串流執行支援
    Checkpointing = 1 << 4,    // 檢查點功能
    Recovery = 1 << 5,         // 恢復機制
}
```

### 建立自訂範本

實作 `IWorkflowTemplate` 以建立自訂工作流程範本：

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
        
        // 在此處建立自訂圖形
        // 新增節點、連線等
        
        return executor;
    }
}
```

## 記憶體整合

### 記憶體服務配置

啟用可配置選項的記憶體整合：

```csharp
builder.AddGraphMemory(opts =>
{
    opts.EnableVectorSearch = true;
    opts.EnableSemanticSearch = true;
    opts.DefaultCollectionName = "graph-memory";
    opts.SimilarityThreshold = 0.7;
});
```

### 記憶體服務功能

`IGraphMemoryService` 提供多個主要功能：

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

#### 查詢相似執行

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

#### 節點特定記憶體

```csharp
// 儲存節點執行結果
await memoryService.StoreNodeExecutionAsync(
    nodeId: "reasoning-node",
    input: inputArgs,
    output: functionResult,
    executionContext: "exec-123"
);

// 搜尋節點的相關記憶體
var relevantMemory = await memoryService.SearchRelevantMemoryAsync(
    nodeId: "reasoning-node",
    query: "How to solve this type of problem?",
    limit: 10
);
```

### 記憶體提供者整合

針對進階記憶體情境，實作 `IGraphMemoryProvider`：

```csharp
public sealed class CustomMemoryProvider : IGraphMemoryProvider
{
    public bool IsAvailable => true;

    public Task SaveInformationAsync(string collectionName, string text, string id,
        string? description = null, string? additionalMetadata = null,
        CancellationToken cancellationToken = default)
    {
        // 實作自訂儲存邏輯
        // 例如：儲存到資料庫、向量存儲等
        return Task.CompletedTask;
    }

    public async IAsyncEnumerable<MemorySearchResult> SearchAsync(
        string collectionName, string query, int limit = 10, 
        double minRelevanceScore = 0.7, CancellationToken cancellationToken = default)
    {
        // 實作自訂搜尋邏輯
        // 例如：向量相似性搜尋、語義搜尋等
        yield break;
    }
}
```

## 進階配置

### 完整圖形支援

對所有功能使用全面的配置：

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

根據需要選擇特定的範本引擎：

```csharp
// 適用於推理密集型工作流程
builder.Services.AddSingleton<IGraphTemplateEngine, ChainOfThoughtTemplateEngine>();

// 適用於 ReAct 模式
builder.Services.AddSingleton<IGraphTemplateEngine, ReActTemplateEngine>();

// 適用於一般用途
builder.Services.AddSingleton<IGraphTemplateEngine, HandlebarsGraphTemplateEngine>();
```

## 最佳實踐

### 範本設計

1. **參數驗證**：建立圖形前始終驗證範本參數
2. **預設值**：為可選參數提供合理的預設值
3. **功能聲明**：準確聲明所需的功能
4. **版本化**：對範本更新使用語義化版本

### 記憶體使用

1. **上下文儲存**：儲存執行上下文以供未來參考和學習
2. **相似度閾值**：根據使用案例調整相似度閾值
3. **記憶體清理**：實作舊記憶體項目的清理策略
4. **元數據**：使用元數據對記憶體項目進行分類和篩選

### 效能考量

1. **範本快取**：利用範本編譯和快取
2. **記憶體限制**：設定記憶體儲存和搜尋的適當限制
3. **非同步操作**：對外部服務呼叫使用非同步輔助函數
4. **批次操作**：在可能時批次執行記憶體操作

## 疑難排解

### 常見問題

**範本渲染錯誤**
* 確保在上下文中提供了所有必需的變數
* 檢查範本語法是否符合正確的 Handlebars 格式
* 驗證自訂輔助函數已正確註冊

**記憶體整合問題**
* 確認記憶體服務已正確配置和註冊
* 檢查相似度閾值是否適合您的資料
* 驗證記憶體提供者的可用性

**範本登錄問題**
* 確保範本在 DI 容器中已正確註冊
* 檢查範本 ID 和版本的唯一性
* 驗證範本參數驗證邏輯

### 偵錯提示

1. **啟用日誌**：使用內建日誌追蹤範本和記憶體操作
2. **範本驗證**：使用 `ValidateParameters` 提早捕捉配置問題
3. **記憶體檢查**：檢查記憶體服務日誌以進行儲存和擷取操作
4. **範本編譯**：在執行前驗證範本編譯正確

## 另外參見

* [圖形概念](../concepts/graph-concepts.md) - 核心圖形概念與術語
* [狀態管理](../how-to/state-management.md) - 使用圖形狀態和引數
* [條件節點](../how-to/conditional-nodes.md) - 動態路由與決策制定
* [多代理工作流程](../how-to/multi-agent-and-shared-state.md) - 協調多個代理
* [API 參考](../api/) - 範本和記憶體類型的完整 API 文件
