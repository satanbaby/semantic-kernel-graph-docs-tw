# 動態路由引擎

`DynamicRoutingEngine` 提供了超越簡單條件邊的進階節點選擇功能。它結合了多種路由策略、基於模板的決策、快取和後備機制，以根據執行上下文和狀態內容做出智能路由選擇。

## 概述

動態路由系統包含幾個關鍵元件：

* **`DynamicRoutingEngine`**: 主要協調器，協調路由策略
* **`AdvancedRoutingEngine`**: 使用嵌入和記憶體處理複雜的路由
* **Routing Strategies**: 多種節點選擇方法
* **Template Engine Integration**: 基於 Handlebars 的路由決策
* **Caching and Fallback**: 性能優化和可靠性

## 核心類別

### DynamicRoutingEngine

主要路由引擎，提供基於狀態內容、基於模板的路由、快取和後備機制的動態節點選擇。

```csharp
public sealed class DynamicRoutingEngine : IAsyncDisposable
{
    public DynamicRoutingEngine(
        IGraphTemplateEngine? templateEngine = null,
        DynamicRoutingOptions? options = null, 
        ILogger<DynamicRoutingEngine>? logger = null,
        ITextEmbeddingGenerationService? embeddingService = null, 
        IGraphMemoryService? memoryService = null);
}
```

**主要功能：**
* **Content-based routing**: 分析狀態內容和執行結果
* **Template-based routing**: 使用 Handlebars 模板進行動態決策
* **Caching**: 儲存路由決策以進行性能優化
* **Fallback mechanisms**: 確保路由始終成功
* **Advanced routing integration**: 當服務可用時自動啟用

**建構子參數：**
* `templateEngine`: 用於路由決策的可選模板引擎
* `options`: 快取和後備行為的配置選項
* `logger`: 用於偵錯和監控的可選記錄器
* `embeddingService`: 用於語義路由的可選服務
* `memoryService`: 用於上下文路由的可選服務

### DynamicRoutingOptions

動態路由引擎的配置選項：

```csharp
public sealed class DynamicRoutingOptions
{
    public bool EnableCaching { get; set; } = true;
    public bool EnableFallback { get; set; } = true;
    public int MaxCacheSize { get; set; } = 1000;
    public int CacheExpirationMinutes { get; set; } = 30;
}
```

**屬性：**
* `EnableCaching`: 是否快取路由決策以提高性能
* `EnableFallback`: 路由失敗時是否使用後備機制
* `MaxCacheSize`: 要儲存的最大快取決策數
* `CacheExpirationMinutes`: 快取決策保持有效的時間長度

## 進階路由整合

### AdvancedRoutingEngine

當嵌入或記憶體服務可用時，`DynamicRoutingEngine` 會自動初始化具有多個路由策略的 `AdvancedRoutingEngine`：

```csharp
// 當提供服務時自動初始化
var routingEngine = new DynamicRoutingEngine(
    templateEngine: null,
    options: new DynamicRoutingOptions { EnableCaching = true, EnableFallback = true },
    logger: logger,
    embeddingService: embeddingService,  // 啟用語義路由
    memoryService: memoryService         // 啟用上下文路由
);
```

### AdvancedRoutingOptions

進階路由功能的配置：

```csharp
public sealed class AdvancedRoutingOptions
{
    public bool EnableSemanticRouting { get; set; } = true;
    public bool EnableSimilarityRouting { get; set; } = true;
    public bool EnableProbabilisticRouting { get; set; } = true;
    public bool EnableContextualRouting { get; set; } = true;
    public bool EnableFeedbackLearning { get; set; } = true;
    public double SemanticSimilarityThreshold { get; set; } = 0.7;
    public int HistoryLookbackLimit { get; set; } = 10;
    public double FeedbackLearningRate { get; set; } = 0.1;
    public double ProbabilisticDecayFactor { get; set; } = 0.95;
    public double MinimumConfidenceThreshold { get; set; } = 0.3;
}
```

**策略控制：**
* `EnableSemanticRouting`: 使用文本嵌入進行基於相似度的路由
* `EnableSimilarityRouting`: 利用執行歷史進行模式匹配
* `EnableProbabilisticRouting`: 應用帶有動態權重的加權隨機選擇
* `EnableContextualRouting`: 考慮執行歷史模式和轉換
* `EnableFeedbackLearning`: 根據用戶反饋調整路由決策

**閾值和限制：**
* `SemanticSimilarityThreshold`: 語義路由的最小相似度分數（0.0 到 1.0）
* `HistoryLookbackLimit`: 要考慮的相似執行數
* `FeedbackLearningRate`: 反饋影響未來決策的速度（0.0 到 1.0）
* `ProbabilisticDecayFactor`: 權重隨時間衰減的因素（0.0 到 1.0）
* `MinimumConfidenceThreshold`: 路由決策所需的最小信心度

## 路由策略

進階路由系統實現了多個協同工作的策略：

### 1. Semantic Routing Strategy

使用文本嵌入根據上下文尋找語義相似的節點：

```csharp
public sealed class SemanticRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Semantic;
    public double GetWeight() => 0.3; // 語義相似度的高權重
}
```

**工作原理：**
1. 為目前執行上下文生成嵌入
2. 與儲存的節點嵌入進行比較
3. 選擇語義相似度最高的節點
4. 應用相似度閾值過濾

**要求：**
* `ITextEmbeddingGenerationService` 實現
* 儲存在 `_nodeEmbeddings` 快取中的節點嵌入

### 2. Content Similarity Routing Strategy

利用執行歷史尋找相似的模式：

```csharp
public sealed class ContentSimilarityRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Similarity;
    public double GetWeight() => 0.25;
}
```

**工作原理：**
1. 分析目前狀態參數和執行上下文
2. 在記憶體中搜索相似的執行模式
3. 使用 Jaccard 指數計算相似度分數
4. 根據歷史成功模式選擇節點

**要求：**
* `IGraphMemoryService` 實現
* 上下文中的相似執行（`context.SimilarExecutions`）

### 3. Probabilistic Routing Strategy

應用帶有動態調整權重的加權隨機選擇：

```csharp
public sealed class ProbabilisticRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Probabilistic;
    public double GetWeight() => 0.2;
}
```

**工作原理：**
1. 根據歷史性能計算動態權重
2. 應用衰減因素以防止過度依賴舊數據
3. 規範化權重並執行加權隨機選擇
4. 根據執行信心度和時近性調整權重

**配置：**
```csharp
var options = new AdvancedRoutingOptions
{
    EnableProbabilisticRouting = true,
    ProbabilisticDecayFactor = 0.95, // 隨時間衰減的權重
    MinimumConfidenceThreshold = 0.3  // 選擇的最小信心度
};
```

### 4. Contextual Routing Strategy

考慮執行歷史模式和轉換概率：

```csharp
public sealed class ContextualRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Contextual;
    public double GetWeight() => 0.15;
}
```

**工作原理：**
1. 分析目前節點的路由歷史
2. 計算到候選節點的轉換概率
3. 考慮歷史轉換的成功率
4. 選擇具有最佳歷史性能模式的節點

**功能：**
* 轉換概率分析
* 成功率加權
* 歷史模式識別
* 上下文感知決策制定

### 5. Feedback Learning Routing Strategy

根據用戶反饋調整路由決策：

```csharp
public sealed class FeedbackLearningRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.FeedbackLearning;
    public double GetWeight() => 0.1;
}
```

**工作原理：**
1. 收集有關路由決策的反饋
2. 根據反饋調整策略權重
3. 從成功和失敗的路由中學習
4. 隨時間改進決策品質

**配置：**
```csharp
var options = new AdvancedRoutingOptions
{
    EnableFeedbackLearning = true,
    FeedbackLearningRate = 0.1, // 適應反饋的速度
    MinimumConfidenceThreshold = 0.3
};
```

## Template Engine Integration

### IGraphTemplateEngine

路由系統與模板引擎集成以進行動態路由決策：

```csharp
public interface IGraphTemplateEngine
{
    Task<string> RenderAsync(string template, object context, CancellationToken cancellationToken = default);
    Task<string> RenderWithArgumentsAsync(string template, KernelArguments arguments, CancellationToken cancellationToken = default);
}
```

**可用實現：**
* `HandlebarsGraphTemplateEngine`: 基本的類似 Handlebars 的樣板
* `ChainOfThoughtTemplateEngine`: 針對推理模式進行專門化
* `ReActTemplateEngine`: 為 ReAct 模式提示進行優化

### Template-Based Routing

模板可用於根據狀態內容進行路由決策：

```csharp
// 基於模板的路由範例
var routingTemplate = "{{#if error}}ErrorHandler{{else}}{{#if complete}}CompleteNode{{else}}DefaultNode{{/if}}{{/if}}";

// 模板引擎使用目前狀態呈現此內容
var routingDecision = await templateEngine.RenderWithArgumentsAsync(
    routingTemplate, 
    context.Parameters, 
    cancellationToken);
```

**模板功能：**
* 變數替換：`{{variable}}`
* 條件陳述式：`{{#if condition}}...{{else}}...{{/if}}`
* 幫助函式：`{{helper arg1 arg2}}`
* 狀態感知呈現
* 用於性能的快取

## 路由上下文和結果

### AdvancedRoutingContext

用於路由決策的豐富上下文資訊：

```csharp
public sealed class AdvancedRoutingContext
{
    public required string CurrentNodeId { get; init; }
    public required string CurrentNodeName { get; init; }
    public required GraphState GraphState { get; init; }
    public FunctionResult? ExecutionResult { get; init; }
    public required DateTimeOffset Timestamp { get; init; }
    public required string ExecutionId { get; init; }
    public required int ExecutionStep { get; init; }
    public List<GraphExecutionMemory> SimilarExecutions { get; set; } = new();
    public Random Random { get; init; } = new();
}
```

### AdvancedRoutingResult

路由決策的綜合結果：

```csharp
public sealed class AdvancedRoutingResult
{
    public required IGraphNode SelectedNode { get; init; }
    public required double FinalConfidence { get; init; }
    public required List<RoutingStrategyType> UsedStrategies { get; init; }
    public required Dictionary<RoutingStrategyType, object> StrategyDetails { get; init; }
    public required string DecisionId { get; init; }
    public required DateTimeOffset Timestamp { get; init; }
}
```

**屬性：**
* `SelectedNode`: 路由引擎選擇的節點
* `FinalConfidence`: 總體信心分數（0.0 到 1.0）
* `UsedStrategies`: 有助於決策的策略列表
* `StrategyDetails`: 每個策略的詳細資訊
* `DecisionId`: 路由決策的唯一標識符
* `Timestamp`: 做出決策的時間

## 指標和監控

### RoutingMetrics

路由決策的性能指標：

```csharp
public sealed class RoutingMetrics
{
    public required string NodeId { get; init; }
    public required string NodeName { get; init; }
    public int TotalDecisions { get; set; }
    public int CachedDecisions { get; set; }
    public int FailedDecisions { get; set; }
    public double AverageDecisionTime { get; set; }
    public DateTimeOffset? LastDecisionAt { get; set; }
    public ConcurrentDictionary<string, string> SelectedNodes { get; } = new();
    
    public double CacheHitRatio => TotalDecisions > 0 ? (CachedDecisions / (double)TotalDecisions) * 100 : 0;
    public double SuccessRatio => TotalDecisions > 0 ? ((TotalDecisions - FailedDecisions) / (double)TotalDecisions) * 100 : 0;
}
```

**關鍵指標：**
* `TotalDecisions`: 進行的路由決策總數
* `CachedDecisions`: 從快取提供的決策數
* `FailedDecisions`: 失敗的路由嘗試次數
* `AverageDecisionTime`: 做出路由決策的平均時間
* `CacheHitRatio`: 從快取提供的決策百分比
* `SuccessRatio`: 成功路由決策的百分比

### RoutingAnalytics

所有路由策略的聚合分析：

```csharp
public sealed class RoutingAnalytics
{
    public int TotalDecisions { get; init; }
    public int SemanticRoutingUsage { get; init; }
    public int SimilarityRoutingUsage { get; init; }
    public int ProbabilisticRoutingUsage { get; init; }
    public int ContextualRoutingUsage { get; init; }
    public int FeedbackLearningUsage { get; init; }
    public double AverageConfidence { get; init; }
    public int FeedbackReceived { get; init; }
    public int PositiveFeedback { get; init; }
    public DateTimeOffset? LastDecisionAt { get; init; }
}
```

## 使用範例

### 基本動態路由設定

```csharp
// 建立具有動態路由的核心
var kernelBuilder = Kernel.CreateBuilder();
kernelBuilder.AddGraphSupport();

// 建立啟用動態路由的圖形（在建立核心之前）
var graph = kernelBuilder.CreateGraphWithDynamicRouting("DynamicDemo", "Dynamic routing example");

var kernel = kernelBuilder.Build();

// 新增節點和連線
var startNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string input) => $"Processed: {input}",
        functionName: "ProcessInput",
        description: "Process the input data"
    ),
    "start"
.).StoreResultAs("processed_input");

var processNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string processedInput) => $"Final result: {processedInput}",
        functionName: "ProcessData",
        description: "Process the input data"
    ),
    "process"
.).StoreResultAs("result");

var errorNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        () => "Error handled successfully",
        functionName: "HandleError",
        description: "Handle any errors"
    ),
    "error"
.).StoreResultAs("error_handled");

graph.AddNode(startNode)
     .AddNode(processNode)
     .AddNode(errorNode)
     .SetStartNode("start");

// 使用動態路由執行
var result = await graph.ExecuteAsync(kernel, new KernelArguments { ["input"] = "test" });
```

### 具有服務的進階路由

```csharp
// 建立具有嵌入和記憶體服務的進階路由
// 注意：在實際場景中，您將擁有實際的嵌入和記憶體服務
var templateEngine = new HandlebarsGraphTemplateEngine(
    new GraphTemplateOptions
    {
        EnableHandlebars = true,
        EnableCustomHelpers = true,
        TemplateCacheSize = 100
    }
);

var routingEngine = new DynamicRoutingEngine(
    templateEngine: templateEngine,
    options: new DynamicRoutingOptions 
    { 
        EnableCaching = true, 
        EnableFallback = true,
        MaxCacheSize = 500,
        CacheExpirationMinutes = 60
    },
    logger: null,  // 將是實際的記錄器
    embeddingService: null,  // 將是實際的嵌入服務
    memoryService: null      // 將是實際的記憶體服務
);

// 配置圖形以使用進階路由
graph.RoutingEngine = routingEngine;

// 使用進階路由功能執行
var result = await graph.ExecuteAsync(kernel, new KernelArguments { ["input"] = "test" });
```

### 基於範本的路由

```csharp
// 建立範本引擎
var templateEngine = new HandlebarsGraphTemplateEngine(new GraphTemplateOptions
{
    EnableHandlebars = true,
    EnableCustomHelpers = true,
    TemplateCacheSize = 100
});

// 建立支援範本的路由引擎
var routingEngine = new DynamicRoutingEngine(
    templateEngine: templateEngine,
    options: new DynamicRoutingOptions { EnableCaching = true, EnableFallback = true }
);

// 使用範本進行路由決策
// 注意：範本將根據執行上下文中的 'priority' 值進行評估
graph.ConnectWithTemplate("start", "process", 
    "{{#if (eq priority 'high')}}true{{else}}false{{/if}}", 
    templateEngine, "HighPriorityRoute");
```

## 擴充方法

### DynamicRoutingExtensions

用於配置動態路由的幫助方法：

```csharp
public static class DynamicRoutingExtensions
{
    // 使用預設選項啟用動態路由
    public static GraphExecutor EnableDynamicRouting(this GraphExecutor executor,
        IGraphTemplateEngine? templateEngine = null, 
        ILogger<DynamicRoutingEngine>? logger = null);
    
    // 使用自訂選項啟用動態路由
    public static GraphExecutor EnableDynamicRouting(this GraphExecutor executor,
        DynamicRoutingOptions options, 
        IGraphTemplateEngine? templateEngine = null,
        ILogger<DynamicRoutingEngine>? logger = null);
    
    // 停用動態路由
    public static GraphExecutor DisableDynamicRouting(this GraphExecutor executor);
    
    // 取得路由指標
    public static IReadOnlyDictionary<string, RoutingMetrics> GetRoutingMetrics(
        this GraphExecutor executor, string? nodeId = null);
}
```

## 性能考量

### 快取策略

路由引擎實現了智能快取：

* **Decision caching**: 儲存路由決策以避免重新計算
* **Template caching**: 編譯和快取範本以加快呈現速度
* **Embedding caching**: 儲存節點嵌入以避免重新生成
* **Configurable expiration**: 快取項目根據時間和使用情況過期

### 後備機制

多個後備策略確保路由始終成功：

1. **Advanced routing strategies** (語義、相似度、概率、上下文、反饋)
2. **Content-based selection** (分析狀態和執行結果)
3. **Template-based routing** (使用 Handlebars 範本)
4. **Fallback selection** (當其他方法都失敗時進行隨機或輪循)

### 資源管理

引擎實現了適當的資源管理：

* **Async disposal**: 實現 `IAsyncDisposable` 以進行清理
* **Memory management**: 可配置的快取大小和過期時間
* **Concurrent access**: 使用並行集合進行線程安全操作
* **Performance monitoring**: 內建指標和記錄

## 錯誤處理

### 路由失敗

當路由失敗時，引擎提供詳細的錯誤資訊：

* **Exception details**: 特定的錯誤消息和堆疊跟蹤
* **Fallback behavior**: 啟用時自動後備
* **Logging**: 路由決策和失敗的全面記錄
* **Metrics tracking**: 失敗的決策被追蹤以進行分析

### 復甦策略

引擎實現了多個復甦策略：

* **Automatic fallback**: 使用替代路由方法
* **Cache invalidation**: 移除無效的快取決策
* **Strategy adjustment**: 根據失敗調整策略權重
* **Feedback learning**: 從路由失敗中學習以改進未來決策

## 另請參閱

* [Advanced Routing Guide](../how-to/advanced-routing.md) - 進階路由概念和技術的綜合指南
* [Templates and Memory](../how-to/templates-and-memory.md) - 範本引擎系統和記憶體整合
* [Graph Executor](./graph-executor.md) - 使用路由的核心執行引擎
* [Graph State](./graph-state.md) - 用於路由決策的狀態管理
* [Dynamic Routing Example](../../examples/dynamic-routing-example.md) - 演示動態路由功能的完整範例
