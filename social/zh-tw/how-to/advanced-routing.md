# 進階路由

SemanticKernel.Graph 中的進階路由超越簡單的條件邊，使用多種策略提供智能、上下文感知的節點選擇。本指南涵蓋了啟用動態、自適應圖形執行的高級路由功能。

## 概述

進階路由結合多種策略做出關於執行下一個節點的智能決策：

* **語義路由**：使用嵌入向量查找語義相似的節點
* **內容相似性**：利用執行歷史查找相似的模式
* **概率路由**：使用動態權重應用加權隨機選擇
* **上下文路由**：考慮執行歷史模式和轉移
* **反饋學習**：根據使用者反饋調整路由決策

## 核心組件

### AdvancedRoutingEngine

協調所有路由策略的主要協調器：

```csharp
var advancedRoutingEngine = new AdvancedRoutingEngine(
    embeddingService: embeddingService,
    memoryService: memoryService,
    options: new AdvancedRoutingOptions
    {
        EnableSemanticRouting = true,
        EnableSimilarityRouting = true,
        EnableProbabilisticRouting = true,
        EnableContextualRouting = true,
        EnableFeedbackLearning = true
    }
);
```

### DynamicRoutingEngine 整合

當嵌入或記憶體服務可用時，`DynamicRoutingEngine` 會自動整合進階路由：

```csharp
var routingEngine = new DynamicRoutingEngine(
    templateEngine: null,
    options: new DynamicRoutingOptions { EnableCaching = true, EnableFallback = true },
    logger: logger,
    embeddingService: embeddingService,
    memoryService: memoryService
);

// 配置圖形使用進階路由
graph.RoutingEngine = routingEngine;
```

## 路由策略

### 1. 語義路由策略

使用文本嵌入向量根據上下文查找語義相似的節點：

```csharp
public sealed class SemanticRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Semantic;
    public double GetWeight() => 0.3; // 語義相似性的高權重
    
    // 基於嵌入相似性選擇節點
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 為當前執行上下文生成嵌入向量
2. 檢索或建立候選節點的嵌入向量
3. 計算上下文和節點嵌入向量之間的餘弦相似度
4. 選擇相似度高於閾值的節點（預設值：0.5）

**配置：**
```csharp
var options = new AdvancedRoutingOptions
{
    EnableSemanticRouting = true,
    SemanticSimilarityThreshold = 0.7 // 可調整的閾值
};
```

### 2. 內容相似性路由策略

利用執行歷史尋找在相似情況下表現良好的節點：

```csharp
public sealed class ContentSimilarityRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Similarity;
    public double GetWeight() => 0.25;
    
    // 基於相似上下文中的歷史成功選擇節點
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 從記憶體服務分析相似的執行
2. 計算當前執行和歷史執行之間的狀態相似度
3. 識別具有高頻率和高成功率的節點
4. 選擇具有最佳頻率和成功率組合的節點

**需求：**
* `IGraphMemoryService` 實現
* 上下文中的相似執行（`context.SimilarExecutions`）

### 3. 概率路由策略

使用動態調整的權重應用加權隨機選擇：

```csharp
public sealed class ProbabilisticRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Probabilistic;
    public double GetWeight() => 0.2;
    
    // 使用動態權重的加權隨機選擇節點
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 根據歷史效能計算動態權重
2. 應用衰減因子以防止過度依賴舊資料
3. 規範化權重並執行加權隨機選擇
4. 根據執行信心度和近期性調整權重

**配置：**
```csharp
var options = new AdvancedRoutingOptions
{
    EnableProbabilisticRouting = true,
    ProbabilisticDecayFactor = 0.95, // 權重隨時間衰減
    MinimumConfidenceThreshold = 0.3  // 選擇的最小信心度
};
```

### 4. 上下文路由策略

考慮執行歷史模式和轉移機率：

```csharp
public sealed class ContextualRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Contextual;
    public double GetWeight() => 0.15;
    
    // 基於歷史轉移模式選擇節點
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 分析當前節點的路由歷史
2. 計算到候選節點的轉移機率
3. 考慮歷史轉移的成功率
4. 選擇具有最佳歷史效能模式的節點

**特性：**
* 查看最近的歷史（可配置的限制）
* 同時考慮頻率和成功率
* 適應不同的執行模式

### 5. 反饋學習路由策略

根據使用者反饋調整路由決策：

```csharp
public sealed class FeedbackLearningRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.FeedbackLearning;
    public double GetWeight() => 0.1;
    
    // 基於反饋調整的分數選擇節點
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
    }
    
    // 提供反饋以改進未來路由
    public async Task ProvideFeedbackAsync(string routingDecisionId, 
        RoutingFeedbackInfo feedbackInfo, CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 計算候選項目的反饋調整分數
2. 更重地權重最近的反饋
3. 選擇具有最高反饋分數的節點
4. 持續從使用者反饋中學習

**反饋類型：**
```csharp
public enum RoutingFeedbackType
{
    Positive,    // 良好的路由決策
    Negative,    // 較差的路由決策
    Neutral,     // 可接受但不是最優
    Correction   // 明確的更正
}
```

## 配置和選項

### AdvancedRoutingOptions

所有路由策略的全面配置：

```csharp
public sealed class AdvancedRoutingOptions
{
    // 啟用/禁用個別策略
    public bool EnableSemanticRouting { get; set; } = true;
    public bool EnableSimilarityRouting { get; set; } = true;
    public bool EnableProbabilisticRouting { get; set; } = true;
    public bool EnableContextualRouting { get; set; } = true;
    public bool EnableFeedbackLearning { get; set; } = true;
    
    // 閾值和限制
    public double SemanticSimilarityThreshold { get; set; } = 0.7;
    public int HistoryLookbackLimit { get; set; } = 10;
    public double MinimumConfidenceThreshold { get; set; } = 0.3;
    
    // 學習和適應參數
    public double FeedbackLearningRate { get; set; } = 0.1;
    public double ProbabilisticDecayFactor { get; set; } = 0.95;
}
```

### 策略權重

每種策略對最終決策的貢獻具有可配置的權重：

* **語義**：0.3（30%）- 語義理解的高權重
* **相似性**：0.25（25%）- 歷史模式的良好權重
* **概率**：0.2（20%）- 探索的平衡權重
* **上下文**：0.15（15%）- 模式的中等權重
* **反饋**：0.1（10%）- 學習的較低權重

## 使用示例

### 基本設定

```csharp
// 1. 建立核心並選擇性地新增嵌入服務。
// 如果您沒有嵌入提供程式，進階語義
// 策略將自動禁用。
var kernelBuilder = Kernel.CreateBuilder();
// kernelBuilder.AddTextEmbeddingGeneration("text-embedding-ada-002", "your-api-key");
var kernel = kernelBuilder.Build();

// 2. 建立（或獲取）記憶體服務。如果可用，僅使用 GraphMemory。
IGraphMemoryService? memoryService = null;
try
{
    memoryService = new GraphMemoryService(); // 替換為您的實現
}
catch
{
    // 記憶體服務對某些路由策略是可選的。
}

// 3. 僅在嵌入服務可用時建立進階路由引擎。
IAdvancedRoutingEngine? advancedRoutingEngine = null;
if (kernel.Services.GetService(typeof(ITextEmbeddingGenerationService)) is ITextEmbeddingGenerationService embeddingService)
{
    advancedRoutingEngine = new AdvancedRoutingEngine(
        embeddingService: embeddingService,
        memoryService: memoryService,
        options: new AdvancedRoutingOptions
        {
            EnableSemanticRouting = true,
            EnableSimilarityRouting = memoryService != null,
            EnableProbabilisticRouting = true,
            EnableContextualRouting = true,
            EnableFeedbackLearning = true
        }
    );
}

// 4. 配置圖形在可用時使用動態路由引擎。
var graph = kernel.CreateGraphWithDynamicRouting("AdvancedRoutingExample", "Advanced routing demo");
if (advancedRoutingEngine != null)
{
    graph.RoutingEngine = new DynamicRoutingEngine(
        templateEngine: graph.Metadata.TryGetValue("TemplateEngine", out var t) ? t as IGraphTemplateEngine : null,
        options: new DynamicRoutingOptions { EnableCaching = true, EnableFallback = true },
        logger: null,
        embeddingService: kernel.Services.GetService(typeof(ITextEmbeddingGenerationService)) as ITextEmbeddingGenerationService,
        memoryService: memoryService
    );
}
```

### 提供反饋

```csharp
// 直接向路由引擎提供路由決策的反饋
await routingEngine.ProvideFeedbackAsync(
    routingDecisionId: "decision-123",
    new RoutingFeedbackInfo
    {
        NodeId = "selected-node",
        FeedbackType = RoutingFeedbackType.Positive,
        Score = 0.9,
        Comments = "Excellent routing decision",
        Timestamp = DateTimeOffset.UtcNow
    }
);
```

### 自訂策略權重

```csharp
// 覆蓋預設策略權重
var customOptions = new AdvancedRoutingOptions
{
    EnableSemanticRouting = true,
    EnableSimilarityRouting = true,
    EnableProbabilisticRouting = false, // 禁用概率
    EnableContextualRouting = true,
    EnableFeedbackLearning = true,
    
    // 調整閾值
    SemanticSimilarityThreshold = 0.8,  // 更高的閾值
    HistoryLookbackLimit = 20,           // 更多歷史
    MinimumConfidenceThreshold = 0.5     // 需要更高的信心度
};
```

## 進階功能

### 路由上下文

`AdvancedRoutingContext` 為路由決策提供豐富的資訊：

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

### 策略聚合

多個策略對最終決策有所貢獻：

```csharp
// 來自不同策略的結果
var routingResults = new List<RoutingStrategyResult>();

// 新增來自啟用策略的結果
if (semanticResult != null) routingResults.Add(semanticResult);
if (similarityResult != null) routingResults.Add(similarityResult);
if (probabilisticResult != null) routingResults.Add(probabilisticResult);
if (contextualResult != null) routingResults.Add(contextualResult);
if (feedbackResult != null) routingResults.Add(feedbackResult);

// 聚合並選擇最終節點
var finalResult = AggregateRoutingResults(routingResults, routingContext);
```

### 路由歷史

追蹤和分析路由決策：

```csharp
public sealed class RoutingHistory
{
    public required string DecisionId { get; init; }
    public required string CurrentNodeId { get; init; }
    public required string SelectedNodeId { get; init; }
    public required List<RoutingStrategyType> UsedStrategies { get; init; }
    public required double FinalConfidence { get; init; }
    public required DateTimeOffset Timestamp { get; init; }
    public required string ContextSnapshot { get; init; }
}
```

## 效能考慮

### 快取

`DynamicRoutingEngine` 包含內置快取：

```csharp
var routingOptions = new DynamicRoutingOptions
{
    EnableCaching = true,
    MaxCacheSize = 1000,
    CacheExpiration = TimeSpan.FromMinutes(30)
};
```

### 記憶體管理

* 節點嵌入向量使用 TTL 進行快取（預設 24 小時）
* 路由歷史使用並發字典以保證執行緒安全
* 相似執行受 `HistoryLookbackLimit` 限制

### 回退機制

當進階路由失敗時，回退選項確保執行繼續：

```csharp
var routingOptions = new DynamicRoutingOptions
{
    EnableFallback = true,  // 始終選擇一個節點
    EnableCaching = true,   // 快取決策以提高效能
    MaxCacheSize = 100      // 限制記憶體使用
};
```

## 監視和偵錯

### 路由指標

追蹤路由效能和決策：

```csharp
// 獲取特定節點的路由指標
var nodeMetrics = routingEngine.GetRoutingMetrics("node-id");

// 獲取所有路由指標
var allMetrics = routingEngine.GetRoutingMetrics();
```

### 記錄

用於除錯路由決策的全面記錄：

```csharp
// 啟用路由的偵錯記錄
var logger = LoggerFactory.Create(builder => 
    builder.SetMinimumLevel(LogLevel.Debug)
.).CreateLogger<DynamicRoutingEngine>();

var routingEngine = new DynamicRoutingEngine(
    logger: logger,
    embeddingService: embeddingService,
    memoryService: memoryService
);
```

### 策略詳細資訊

每個路由結果都包括關於決策的詳細資訊：

```csharp
var result = await routingEngine.SelectNextNodeAsync(candidates, currentNode, state);

// 存取策略詳細資訊
foreach (var strategyResult in result.UsedStrategies)
{
    var details = strategyResult.StrategyDetails;
    // 處理策略特定的詳細資訊
}
```

## 最佳實踐

### 1. 服務可用性

* 在啟用策略之前，始終檢查所需服務是否可用
* 當服務不可用時提供回退機制
* 使用依賴注入進行服務管理

### 2. 閾值調整

* 從預設閾值開始，根據您的使用情況調整
* 監視路由信心分數以識別最優閾值
* 使用反饋學習自動調整參數

### 3. 記憶體管理

* 為歷史回顧和快取大小設定適當的限制
* 在生產環境中監視記憶體使用情況
* 實施舊路由資料的清理政策

### 4. 效能監視

* 追蹤路由決策延遲
* 監視快取命中率
* 分析策略貢獻模式

### 5. 反饋質量

* 提供一致且有意義的反饋
* 在不同情況下使用適當的反饋類型
* 定期檢查和清理反饋資料

## 疑難排解

### 常見問題

**路由信心度低：**
* 檢查嵌入服務是否正常運作
* 驗證記憶體服務是否具有相關的歷史資料
* 調整相似度閾值

**路由決策速度慢：**
* 為頻繁存取的路由啟用快取
* 減少歷史回顧限制
* 優化嵌入生成

**路由不一致：**
* 檢查策略權重和閾值
* 驗證反饋資料品質
* 監視路由歷史模式

### 除錯資訊

啟用詳細記錄以診斷路由問題：

```csharp
// 啟用偵錯記錄
var logger = LoggerFactory.Create(builder => 
    builder.SetMinimumLevel(LogLevel.Debug)
.).CreateLogger<AdvancedRoutingEngine>();

// 檢查策略結果
var result = await routingEngine.SelectNextNodeAsync(candidates, currentNode, state);
Console.WriteLine($"Used strategies: {string.Join(", ", result.UsedStrategies)}");
Console.WriteLine($"Final confidence: {result.FinalConfidence:F3}");
```

## 另參閱

* [條件節點](./conditional-nodes.md) - 基本條件路由
* [動態路由](./dynamic-routing.md) - 範本型路由
* [狀態管理](./state.md) - 圖形狀態和上下文
* [記憶體和範本](./templates-and-memory.md) - 記憶體服務和範本
* [效能指標](./metrics-and-observability.md) - 監視路由效能

## 示例

* [進階路由示例](../../examples/advanced-routing.md) - 完整演示
* [動態路由示例](../../examples/dynamic-routing.md) - 範本型路由
* [多代理工作流程](../../tutorials/multi-agent-workflow.md) - 複雜路由場景
