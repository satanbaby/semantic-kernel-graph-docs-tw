# 路由

路由使用條件邊或動態策略來決定下一個要執行的節點。

## 概念與技術

**路由**：根據條件、狀態或動態策略來決定下一個要執行的節點的過程。

**條件邊**：節點之間的連接，僅在特定條件被滿足時才允許通過。

**路由策略**：根據預定義標準決定執行路徑的演算法或邏輯。

## 路由類型

### 簡單謂詞路由
* **狀態條件**：直接評估 `GraphState` 屬性
* **布林表達式**：簡單條件，如 `state.Value > 10`
* **比較**：相等性、不相等性和範圍運算符

### 基於範本的路由
* **SK 評估**：使用語義核心函數進行複雜決策
* **基於提示的路由**：根據文本或上下文分析進行決策
* **語義匹配**：根據語義相似性進行路由

### 進階路由
* **語義相似性**：使用嵌入向量找到最佳路徑
* **概率路由**：具有權重和概率的決策
* **從反饋中學習**：根據前面的結果進行調整

## 主要組件

### ConditionalEdge / 條件路由節點
```csharp
// 使用該項目的條件路由節點實現的示例
var conditionalNode = new ConditionalNodeExample(
    nodeId: "checkStatus",
    name: "CheckStatus",
    condition: args => args.Get<int>("status") == 200
);

// 添加當條件為真時應該被選中的下一個節點
var successNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(() => "Success", functionName: "SuccessHandler"),
    "success"
);
conditionalNode.AddNextNode(successNode);
```

### DynamicRoutingEngine
```csharp
// 創建範本引擎（可選）和帶有選項的動態路由引擎
var templateEngine = new HandlebarsGraphTemplateEngine(new GraphTemplateOptions
{
    EnableHandlebars = true,
    EnableCustomHelpers = true,
    TemplateCacheSize = 100
});

var routingEngine = new DynamicRoutingEngine(
    templateEngine: templateEngine,
    options: new DynamicRoutingOptions
    {
        EnableCaching = true,
        EnableFallback = true,
        MaxCacheSize = 500,
        CacheExpirationMinutes = 60
    },
    logger: null,
    embeddingService: null,
    memoryService: null
);
```

### RoutingStrategies
* **SemanticRoutingStrategy**：根據語義相似性進行路由
* **ProbabilisticRoutingStrategy**：使用概率權重進行路由
* **ContextualRoutingStrategy**：根據執行歷史進行路由

## 使用範例

### 簡單條件路由
```csharp
// 基於數值的路由：使用條件路由節點與
// 普通 FunctionGraphNode 實例結合。這反映了示例。
var kernelBuilder = Kernel.CreateBuilder();
kernelBuilder.AddGraphSupport();
var kernel = kernelBuilder.Build();

var startNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((string input) => $"Processed: {input}", functionName: "ProcessInput"),
    "start"
).StoreResultAs("processed_input");

var conditional = new ConditionalNodeExample("cond", "IsSuccess", args => args.Get<int>("status") == 200);
var successNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(() => "OK", functionName: "Success"),
    "success"
);

conditional.AddNextNode(successNode);
// 將節點添加到 GraphExecutor 並設置起始節點以連接此路由。
```

### 基於範本的路由
```csharp
// 使用該項目的範本引擎進行基於範本的路由（Handlebars 示例）
var templateEngine = new HandlebarsGraphTemplateEngine(new GraphTemplateOptions { EnableHandlebars = true });
var routingEngine = new DynamicRoutingEngine(templateEngine: templateEngine, options: new DynamicRoutingOptions { EnableCaching = true });

var template = "{{#if (eq priority 'high')}}high{{else}}low{{/if}}";
var context = new KernelArguments { ["priority"] = "high" };
var rendered = await templateEngine.RenderWithArgumentsAsync(template, context, CancellationToken.None);
// 使用呈現的值決定要路由到哪個節點。
```

### 動態路由
```csharp
// 使用 DynamicRoutingEngine 進行自適應路由。實際上，您可能會
// 結合多個策略（性能、負載、語義相似性）。
var dynamicRouter = new DynamicRoutingEngine(
    options: new DynamicRoutingOptions { EnableCaching = true }
);

// 實際部署將添加或配置策略，例如
// PerformanceBasedRoutingStrategy 或 LoadBalancingRoutingStrategy。
```

## 配置和選項

### 路由選項
```csharp
// 使用該項目的動態路由選項進行配置
var options = new DynamicRoutingOptions
{
    EnableCaching = true,
    EnableFallback = true,
    MaxCacheSize = 500,
    CacheExpirationMinutes = 60
};
```

### 路由策略
* **重試策略**：發生故障時多次重試
* **斷路器**：問題發生時暫時中斷
* **負載平衡**：均衡的負載分配

## 監控和除錯

### 路由指標
* **決策時間**：決定下一個節點的延遲時間
* **成功率**：成功路由的百分比
* **路徑分佈**：每條路線使用頻率

### 路由除錯
```csharp
// 在您的路由引擎上啟用日誌記錄/診斷，或使用該項目的
// 除錯助手（如果可用）來追蹤決策。
// 示例：通過您的記錄器從路由引擎啟用詳細日誌
// 或在測試中檢查 routingEngine 內部。
```

## 參考資源

* [條件節點](../how-to/conditional-nodes.md)
* [進階路由](../how-to/advanced-routing.md)
* [路由示例](../examples/dynamic-routing.md)
* [進階路由示例](../examples/advanced-routing.md)
* [節點](../concepts/node-types.md)
* [執行模型](../concepts/execution-model.md)

## 參考

* `ConditionalEdge`：用於創建具有條件的邊的類別
* `DynamicRoutingEngine`：自適應路由引擎
* `RoutingStrategies`：預定義的路由策略
* `GraphRoutingOptions`：路由配置
* `ConditionalDebugger`：路由的除錯工具
