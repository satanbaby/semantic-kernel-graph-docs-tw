# 路由

路由使用條件邊或動態策略決定下一個執行的 Node。

## 概念和技術

**Routing（路由）**: 基於條件、狀態或動態策略決定下一個要執行的 Node 的過程。

**Conditional Edge（條件邊）**: 兩個 Node 之間的連接，僅當滿足特定條件時才允許通過。

**Routing Strategy（路由策略）**: 基於預定義條件決定執行路徑的演算法或邏輯。

## 路由類型

### Simple Predicate Routing（簡單謂詞路由）
* **State Conditions（狀態條件）**: 直接評估 `GraphState` 屬性
* **Boolean Expressions（布林運算式）**: 簡單條件，如 `state.Value > 10`
* **Comparisons（比較）**: 相等、不相等和範圍運算子

### Template-Based Routing（基於模板的路由）
* **SK Evaluation（SK 評估）**: 使用 Semantic Kernel 函式進行複雜決策
* **Prompt-based Routing（基於提示的路由）**: 基於文本或上下文分析的決策
* **Semantic Matching（語義匹配）**: 根據語義相似性進行路由

### Advanced Routing（進階路由）
* **Semantic Similarity（語義相似性）**: 使用嵌入式表示法尋找最佳路徑
* **Probabilistic Routing（概率路由）**: 帶有權重和概率的決策
* **Learning from Feedback（從反饋中學習）**: 根據先前結果的適應

## 主要元件

### ConditionalEdge / Conditional Routing Node
```csharp
// Example using the project's conditional routing node implementation
var conditionalNode = new ConditionalNodeExample(
    nodeId: "checkStatus",
    name: "CheckStatus",
    condition: args => args.Get<int>("status") == 200
);

// Add next nodes that should be selected when the condition is true
var successNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(() => "Success", functionName: "SuccessHandler"),
    "success"
);
conditionalNode.AddNextNode(successNode);
```

### DynamicRoutingEngine
```csharp
// Create a template engine (optional) and a dynamic routing engine with options
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
* **SemanticRoutingStrategy**: 按語義相似性進行路由
* **ProbabilisticRoutingStrategy**: 使用概率權重進行路由
* **ContextualRoutingStrategy**: 基於執行歷史的路由

## 使用範例

### Simple Conditional Routing（簡單條件路由）
```csharp
// Routing based on a numeric value: use a conditional routing node together
// with normal FunctionGraphNode instances. This mirrors the examples.
var kernelBuilder = Kernel.CreateBuilder();
kernelBuilder.AddGraphSupport();
var kernel = kernelBuilder.Build();

var startNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod((string input) => $"Processed: {input}", functionName: "ProcessInput"),
    "start"
.).StoreResultAs("processed_input");

var conditional = new ConditionalNodeExample("cond", "IsSuccess", args => args.Get<int>("status") == 200);
var successNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(() => "OK", functionName: "Success"),
    "success"
);

conditional.AddNextNode(successNode);
// Add nodes to a GraphExecutor and set the start node to wire this routing.
```

### Template-Based Routing（基於模板的路由）
```csharp
// Template-based routing using the project's template engine (Handlebars example)
var templateEngine = new HandlebarsGraphTemplateEngine(new GraphTemplateOptions { EnableHandlebars = true });
var routingEngine = new DynamicRoutingEngine(templateEngine: templateEngine, options: new DynamicRoutingOptions { EnableCaching = true });

var template = "{{#if (eq priority 'high')}}high{{else}}low{{/if}}";
var context = new KernelArguments { ["priority"] = "high" };
var rendered = await templateEngine.RenderWithArgumentsAsync(template, context, CancellationToken.None);
// Use the rendered value to decide which node to route to.
```

### Dynamic Routing（動態路由）
```csharp
// Adaptive routing using the DynamicRoutingEngine. In practice you may
// combine multiple strategies (performance, load, semantic similarity).
var dynamicRouter = new DynamicRoutingEngine(
    options: new DynamicRoutingOptions { EnableCaching = true }
);

// Real deployments would add or configure strategies such as
// PerformanceBasedRoutingStrategy or LoadBalancingRoutingStrategy.
```

## 設定和選項

### Routing Options（路由選項）
```csharp
// Use the project's dynamic routing options for configuration
var options = new DynamicRoutingOptions
{
    EnableCaching = true,
    EnableFallback = true,
    MaxCacheSize = 500,
    CacheExpirationMinutes = 60
};
```

### Routing Policies（路由原則）
* **Retry Policy（重試原則）**: 失敗時進行多次重試
* **Circuit Breaker（斷路器）**: 發生問題時暫時中斷
* **Load Balancing（負載平衡）**: 平衡的負載分配

## 監控和除錯

### Routing Metrics（路由指標）
* **Decision Time（決策時間）**: 確定下一個 Node 的延遲
* **Success Rate（成功率）**: 成功路由的百分比
* **Path Distribution（路徑分佈）**: 每條路線的使用頻率

### Routing Debugging（路由除錯）
```csharp
// Enable logging/diagnostics on your routing engine or use the project's
// debug helpers (if available) to trace decisions.
// Example: enable verbose logs from the routing engine via your logger
// or inspect routingEngine internals in tests.
```

## 另請參閱

* [Conditional Nodes（條件 Node）](../how-to/conditional-nodes.md)
* [Advanced Routing（進階路由）](../how-to/advanced-routing.md)
* [Routing Examples（路由範例）](../examples/dynamic-routing.md)
* [Advanced Routing Examples（進階路由範例）](../examples/advanced-routing.md)
* [Nodes（Node）](../concepts/node-types.md)
* [Execution（執行）](../concepts/execution-model.md)

## 參考資源

* `ConditionalEdge`: 用於建立帶有條件的邊的類別
* `DynamicRoutingEngine`: 適應性路由引擎
* `RoutingStrategies`: 預定義的路由策略
* `GraphRoutingOptions`: 路由設定
* `ConditionalDebugger`: 路由的除錯工具
