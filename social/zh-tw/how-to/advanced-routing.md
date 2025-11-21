# 進階路由

SemanticKernel.Graph 中的進階路由超越簡單的條件邊緣，提供使用多種策略的智能、上下文感知節點選擇。本指南涵蓋了啟用動態、自適應 Graph 執行的複雜路由能力。

## 概述

進階路由結合多種策略來對執行下一個 Node 做出明智決定：

* **Semantic Routing（語義路由）**: 使用 embeddings 尋找語義相似的 Nodes
* **Content Similarity（內容相似度）**: 利用執行歷史尋找相似的模式
* **Probabilistic Routing（概率路由）**: 應用帶有動態權重的加權隨機選擇
* **Contextual Routing（上下文路由）**: 考慮執行歷史模式和轉換
* **Feedback Learning（反饋學習）**: 根據用戶反饋自適應路由決策

## 核心組件

### AdvancedRoutingEngine

主要協調器，協調所有路由策略：

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

`DynamicRoutingEngine` 在有 embedding 或記憶體服務可用時自動整合進階路由：

```csharp
var routingEngine = new DynamicRoutingEngine(
    templateEngine: null,
    options: new DynamicRoutingOptions { EnableCaching = true, EnableFallback = true },
    logger: logger,
    embeddingService: embeddingService,
    memoryService: memoryService
);

// 配置 Graph 使用進階路由
graph.RoutingEngine = routingEngine;
```

## 路由策略

### 1. Semantic Routing 策略

使用文本 embeddings 基於上下文尋找語義相似的 Nodes：

```csharp
public sealed class SemanticRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Semantic;
    public double GetWeight() => 0.3; // 語義相似度的高權重
    
    // 基於 embedding 相似度選擇 Node
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 為當前執行上下文生成 embedding
2. 檢索或為候選 Nodes 建立 embeddings
3. 計算上下文與 Node embeddings 之間的餘弦相似度
4. 選擇相似度最高且高於閾值的 Node（預設值：0.5）

**配置：**
```csharp
var options = new AdvancedRoutingOptions
{
    EnableSemanticRouting = true,
    SemanticSimilarityThreshold = 0.7 // 可調整的閾值
};
```

### 2. Content Similarity Routing 策略

利用執行歷史尋找在相似情況下表現良好的 Nodes：

```csharp
public sealed class ContentSimilarityRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Similarity;
    public double GetWeight() => 0.25;
    
    // 基於類似上下文中的歷史成功選擇 Node
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 從記憶體服務分析相似的執行
2. 計算當前與歷史執行間的狀態相似度
3. 辨識具有高頻率和成功率的 Nodes
4. 選擇頻率和成功率結合最佳的 Node

**需求：**
* `IGraphMemoryService` 實現
* 上下文中的相似執行（`context.SimilarExecutions`）

### 3. Probabilistic Routing 策略

應用帶有動態調整權重的加權隨機選擇：

```csharp
public sealed class ProbabilisticRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Probabilistic;
    public double GetWeight() => 0.2;
    
    // 使用動態權重的加權隨機選擇 Node
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 根據歷史表現計算動態權重
2. 套用衰減因子以防止過度依賴舊數據
3. 正規化權重並執行加權隨機選擇
4. 根據執行信心度和最近度自適應權重

**配置：**
```csharp
var options = new AdvancedRoutingOptions
{
    EnableProbabilisticRouting = true,
    ProbabilisticDecayFactor = 0.95, // 隨時間衰減的權重
    MinimumConfidenceThreshold = 0.3  // 選擇的最小信心度
};
```

### 4. Contextual Routing 策略

考慮執行歷史模式和轉換概率：

```csharp
public sealed class ContextualRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.Contextual;
    public double GetWeight() => 0.15;
    
    // 基於歷史轉換模式選擇 Node
    public async Task<RoutingStrategyResult?> SelectNodeAsync(
        List<IGraphNode> candidates,
        AdvancedRoutingContext context,
        CancellationToken cancellationToken = default)
}
```

**工作原理：**
1. 分析當前 Node 的路由歷史
2. 計算到候選 Nodes 的轉換概率
3. 考慮歷史轉換的成功率
4. 選擇歷史表現模式最佳的 Node

**特性：**
* 查看最近歷史（可配置限制）
* 同時考慮頻率和成功率
* 適應改變的執行模式

### 5. Feedback Learning Routing 策略

根據用戶反饋自適應路由決策：

```csharp
public sealed class FeedbackLearningRoutingStrategy : IRoutingStrategy
{
    public RoutingStrategyType Type => RoutingStrategyType.FeedbackLearning;
    public double GetWeight() => 0.1;
    
    // 基於反饋調整的分數選擇 Node
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
1. 為候選項計算反饋調整的分數
2. 更重地加權最近的反饋
3. 選擇反饋分數最高的 Node
4. 持續從用戶反饋中學習

**反饋類型：**
```csharp
public enum RoutingFeedbackType
{
    Positive,    // 良好的路由決策
    Negative,    // 差的路由決策
    Neutral,     // 可接受但不是最優
    Correction   // 明確的更正
}
```

## 配置和選項

### AdvancedRoutingOptions

所有路由策略的綜合配置：

```csharp
public sealed class AdvancedRoutingOptions
{
    // 啟用/停用個別策略
    public bool EnableSemanticRouting { get; set; } = true;
    public bool EnableSimilarityRouting { get; set; } = true;
    public bool EnableProbabilisticRouting { get; set; } = true;
    public bool EnableContextualRouting { get; set; } = true;
    public bool EnableFeedbackLearning { get; set; } = true;
    
    // 閾值和限制
    public double SemanticSimilarityThreshold { get; set; } = 0.7;
    public int HistoryLookbackLimit { get; set; } = 10;
    public double MinimumConfidenceThreshold { get; set; } = 0.3;
    
    // 學習和自適應參數
    public double FeedbackLearningRate { get; set; } = 0.1;
    public double ProbabilisticDecayFactor { get; set; } = 0.95;
}
```

### 策略權重

每個策略對最終決定的貢獻都有可配置的權重：

* **語義**: 0.3 (30%) - 語義理解的高權重
* **相似度**: 0.25 (25%) - 歷史模式的良好權重
* **概率**: 0.2 (20%) - 探索的平衡權重
* **上下文**: 0.15 (15%) - 模式的中等權重
* **反饋**: 0.1 (10%) - 學習的較低權重

## 使用範例

### 基本設置

```csharp
// 1. 建立 kernel 並可選地新增 embedding 服務。
// 如果您沒有 embedding 提供者，進階語義
// 策略將自動停用。
var kernelBuilder = Kernel.CreateBuilder();
// kernelBuilder.AddTextEmbeddingGeneration("text-embedding-ada-002", "your-api-key");
var kernel = kernelBuilder.Build();

// 2. 建立（或獲得）記憶體服務。如果可用，僅使用 GraphMemory。
IGraphMemoryService? memoryService = null;
try
{
    memoryService = new GraphMemoryService(); // 用您的實現替換
}
catch
{
    // 記憶體服務對某些路由策略是可選的。
}

// 3. 僅當 embedding 服務可用時建立進階路由引擎。
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

// 4. 配置 Graph 在可用時使用動態路由引擎。
var graph = kernel.CreateGraphWithDynamicRouting("AdvancedRoutingExample", "進階路由演示");
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
        Comments = "優秀的路由決策",
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
    EnableProbabilisticRouting = false, // 停用概率
    EnableContextualRouting = true,
    EnableFeedbackLearning = true,
    
    // 調整閾值
    SemanticSimilarityThreshold = 0.8,  // 更高的閾值
    HistoryLookbackLimit = 20,           // 更多歷史
    MinimumConfidenceThreshold = 0.5     // 要求更高的信心度
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

多個策略對最終決定有貢獻：

```csharp
// 來自不同策略的結果
var routingResults = new List<RoutingStrategyResult>();

// 新增來自啟用的策略的結果
if (semanticResult != null) routingResults.Add(semanticResult);
if (similarityResult != null) routingResults.Add(similarityResult);
if (probabilisticResult != null) routingResults.Add(probabilisticResult);
if (contextualResult != null) routingResults.Add(contextualResult);
if (feedbackResult != null) routingResults.Add(feedbackResult);

// 聚合並選擇最終 Node
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

## 效能考量

### 快取

`DynamicRoutingEngine` 包含內建快取：

```csharp
var routingOptions = new DynamicRoutingOptions
{
    EnableCaching = true,
    MaxCacheSize = 1000,
    CacheExpiration = TimeSpan.FromMinutes(30)
};
```

### 記憶體管理

* Node embeddings 使用 TTL 進行快取（預設 24 小時）
* 路由歷史為執行緒安全使用並行字典
* 相似執行受 `HistoryLookbackLimit` 限制

### 回退機制

當進階路由失敗時，回退選項確保執行繼續進行：

```csharp
var routingOptions = new DynamicRoutingOptions
{
    EnableFallback = true,  // 總是選擇一個 Node
    EnableCaching = true,   // 為了效能快取決策
    MaxCacheSize = 100      // 限制記憶體使用
};
```

## 監控和偵錯

### 路由指標

追蹤路由效能和決策：

```csharp
// 取得特定 Node 的路由指標
var nodeMetrics = routingEngine.GetRoutingMetrics("node-id");

// 取得所有路由指標
var allMetrics = routingEngine.GetRoutingMetrics();
```

### 日誌記錄

路由決策的綜合日誌記錄：

```csharp
// 啟用路由的偵錯日誌
var logger = LoggerFactory.Create(builder => 
    builder.SetMinimumLevel(LogLevel.Debug)
).CreateLogger<DynamicRoutingEngine>();

var routingEngine = new DynamicRoutingEngine(
    logger: logger,
    embeddingService: embeddingService,
    memoryService: memoryService
);
```

### 策略詳情

每個路由結果都包含關於決策的詳細資訊：

```csharp
var result = await routingEngine.SelectNextNodeAsync(candidates, currentNode, state);

// 存取策略詳情
foreach (var strategyResult in result.UsedStrategies)
{
    var details = strategyResult.StrategyDetails;
    // 處理策略特定的詳情
}
```

## 最佳實踐

### 1. 服務可用性

* 在啟用策略前始終檢查必需的服務是否可用
* 在服務無法使用時提供回退機制
* 使用相依性注入進行服務管理

### 2. 閾值調整

* 從預設閾值開始，根據您的用例進行調整
* 監控路由信心度分數以辨識最優閾值
* 使用反饋學習自動調整參數

### 3. 記憶體管理

* 為歷史回溯和快取大小設定適當的限制
* 在生產環境中監控記憶體使用
* 為舊路由數據實現清理策略

### 4. 效能監控

* 追蹤路由決策延遲
* 監控快取命中率
* 分析策略貢獻模式

### 5. 反饋品質

* 提供一致和有意義的反饋
* 對不同情況使用適當的反饋類型
* 定期審查和清理反饋數據

## 疑難排解

### 常見問題

**低路由信心度：**
* 檢查 embedding 服務是否正常運作
* 驗證記憶體服務是否有相關的歷史數據
* 調整相似度閾值

**路由決策緩慢：**
* 為經常存取的路由啟用快取
* 減少歷史回溯限制
* 最佳化 embedding 生成

**路由不一致：**
* 檢查策略權重和閾值
* 驗證反饋數據品質
* 監控路由歷史模式

### 偵錯資訊

啟用詳細日誌記錄以診斷路由問題：

```csharp
// 啟用偵錯日誌
var logger = LoggerFactory.Create(builder => 
    builder.SetMinimumLevel(LogLevel.Debug)
).CreateLogger<AdvancedRoutingEngine>();

// 檢查策略結果
var result = await routingEngine.SelectNextNodeAsync(candidates, currentNode, state);
Console.WriteLine($"已使用的策略: {string.Join(", ", result.UsedStrategies)}");
Console.WriteLine($"最終信心度: {result.FinalConfidence:F3}");
```

## 另請參閱

* [條件 Nodes](./conditional-nodes.md) - 基本條件路由
* [動態路由](./dynamic-routing.md) - 基於範本的路由
* [狀態管理](./state.md) - Graph 狀態和上下文
* [記憶體和範本](./templates-and-memory.md) - 記憶體服務和範本
* [效能指標](./metrics-and-observability.md) - 監控路由效能

## 範例

* [進階路由範例](../../examples/advanced-routing.md) - 完整演示
* [動態路由範例](../../examples/dynamic-routing.md) - 基於範本的路由
* [多代理工作流](../../tutorials/multi-agent-workflow.md) - 複雜路由情境
