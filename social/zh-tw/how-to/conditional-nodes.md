# 條件式 Node

本指南說明如何在 SemanticKernel.Graph 中使用條件式 Node 和 Edge，建立動態、分支式的工作流程。您將學習如何實現決策邏輯、路由執行流程，以及建立複雜的工作流程模式。

## 概述

條件式 Node 使您能夠建立動態工作流程，可以：
* **根據狀態值或條件分支執行**
* **將資料路由到不同的處理路徑**
* **實現決策樹以處理複雜的商業邏輯**
* **在單一 Graph 中處理多個場景**

## 基本條件邏輯

### 簡單的謂詞型分支

使用謂詞評估條件並路由執行：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;

// 建立具有謂詞的條件式 Node。
// 謂詞安全地檢查 "ok" 鍵的存在性，
// 並在傳回值之前驗證它是布林值。
var conditionalNode = new ConditionalGraphNode(
    predicate: state =>
    {
        if (state.TryGetValue("ok", out var okObj) && okObj is bool ok)
        {
            return ok;
        }

        return false; // 當鍵遺失或不是布林值時的預設值
    },
    nodeId: "decision_point"
);

// 使用安全檢查，根據結果新增條件式 Edge。
graph.AddConditionalEdge(
    "decision_point",
    "success_path",
    condition: state => state.TryGetValue("ok", out var okObj) && okObj is bool ok && ok)
.AddConditionalEdge(
    "decision_point",
    "fallback_path",
    condition: state => !(state.TryGetValue("ok", out var okObj2) && okObj2 is bool ok2 && ok2));
```

### 基於範本的條件

使用範本運算式進行更複雜的條件邏輯：

```csharp
// 基於範本的條件範例。
// 使用型別化存取器和本機變數以提高清晰度和更易於除錯。
var templateCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        var score = state.GetInt("confidence_score", 0);
        var threshold = state.GetInt("threshold", 50);
        return score >= threshold;
    },
    nodeId: "confidence_check"
);

// 根據信心等級，使用明確的閾值進行路由。
graph.AddConditionalEdge(
        "confidence_check",
        "high_confidence",
        condition: state => state.GetInt("confidence_score", 0) >= 80)
    .AddConditionalEdge(
        "confidence_check",
        "medium_confidence",
        condition: state =>
        {
            var score = state.GetInt("confidence_score", 0);
            return score >= 50 && score < 80;
        })
    .AddConditionalEdge(
        "confidence_check",
        "low_confidence",
        condition: state => state.GetInt("confidence_score", 0) < 50);
```

## 進階條件模式

### 多向分支

建立具有多條路徑的複雜決策樹：

```csharp
// 多向分支：確保謂詞傳回布林值並檢查空值/空字串。
var priorityNode = new ConditionalGraphNode(
    predicate: state => !string.IsNullOrEmpty(state.GetString("priority")),
    nodeId: "priority_router"
);

// 根據優先級值路由到不同的處理路徑。
graph.AddConditionalEdge(
        "priority_router",
        "urgent_processing",
        condition: state => string.Equals(state.GetString("priority"), "urgent", StringComparison.OrdinalIgnoreCase))
    .AddConditionalEdge(
        "priority_router",
        "normal_processing",
        condition: state => string.Equals(state.GetString("priority"), "normal", StringComparison.OrdinalIgnoreCase))
    .AddConditionalEdge(
        "priority_router",
        "low_priority_processing",
        condition: state => string.Equals(state.GetString("priority"), "low", StringComparison.OrdinalIgnoreCase))
    .AddConditionalEdge(
        "priority_router",
        "default_processing",
        condition: state =>
        {
            var value = state.GetString("priority");
            return string.IsNullOrEmpty(value) || !(new[] { "urgent", "normal", "low" }.Contains(value, StringComparer.OrdinalIgnoreCase));
        });
```

### 狀態相依的路由

根據多個狀態條件路由執行：

```csharp
// 狀態相依的路由：保持檢查明確且可讀。
var analysisNode = new ConditionalGraphNode(
    predicate: state =>
    {
        var hasData = state.ContainsKey("input_data");
        var dataSize = state.GetInt("data_size", 0);
        // 當遺失時，複雜度預設為 "simple"
        var complexity = state.GetString("complexity", "simple");

        return hasData && dataSize > 0;
    },
    nodeId: "analysis_decision"
);

// 具有明確閾值和顯式比較的複雜路由邏輯。
graph.AddConditionalEdge(
        "analysis_decision",
        "deep_analysis",
        condition: state =>
        {
            var dataSize = state.GetInt("data_size", 0);
            var complexity = state.GetString("complexity", "simple");
            return dataSize > 1000 && string.Equals(complexity, "complex", StringComparison.OrdinalIgnoreCase);
        })
    .AddConditionalEdge(
        "analysis_decision",
        "standard_analysis",
        condition: state =>
        {
            var dataSize = state.GetInt("data_size", 0);
            var complexity = state.GetString("complexity", "simple");
            return dataSize > 100 && !string.Equals(complexity, "complex", StringComparison.OrdinalIgnoreCase);
        })
    .AddConditionalEdge(
        "analysis_decision",
        "quick_analysis",
        condition: state => state.GetInt("data_size", 0) <= 100);
```

### 動態閾值

使用狀態值決定動態閾值：

```csharp
// 動態閾值：計算並使用從狀態衍生的閾值。
var adaptiveNode = new ConditionalGraphNode(
    predicate: state =>
    {
        var baseThreshold = state.GetInt("base_threshold", 50);
        var multiplier = state.GetFloat("threshold_multiplier", 1.0f);
        var dynamicThreshold = (int)Math.Round(baseThreshold * multiplier);

        var currentValue = state.GetInt("current_value", 0);
        // 當目前值滿足或超過動態閾值時傳回 true
        return currentValue >= dynamicThreshold;
    },
    nodeId: "adaptive_threshold"
);

// 將計算的閾值儲存以供稍後在 Graph 狀態中使用。
graph.AddEdge("adaptive_threshold", "store_threshold");
```

## 條件式 Edge 類型

### 布林條件

簡單的真/假路由：

```csharp
// 布林條件路由：偏好明確的預設值和安全存取。
graph.AddConditionalEdge(
    "start",
    "success",
    condition: state => state.GetBool("is_valid", false))
.AddConditionalEdge(
    "start",
    "failure",
    condition: state => !state.GetBool("is_valid", false));
```

### 數值比較

根據數值進行路由：

```csharp
// 具有明確閾值定義的數值比較。
graph.AddConditionalEdge(
    "start",
    "high_priority",
    condition: state => state.GetInt("priority", 0) > 7)
.AddConditionalEdge(
    "start",
    "medium_priority",
    condition: state =>
    {
        var priority = state.GetInt("priority", 0);
        return priority > 3 && priority <= 7;
    })
.AddConditionalEdge(
    "start",
    "low_priority",
    condition: state => state.GetInt("priority", 0) <= 3);
```

### 字串匹配

根據字串值和模式進行路由：

```csharp
// 字串匹配：使用 StringComparison 並防範 null。
graph.AddConditionalEdge(
    "start",
    "email_processing",
    condition: state => state.GetString("input_type", string.Empty).IndexOf("email", StringComparison.OrdinalIgnoreCase) >= 0)
.AddConditionalEdge(
    "start",
    "document_processing",
    condition: state => state.GetString("input_type", string.Empty).IndexOf("document", StringComparison.OrdinalIgnoreCase) >= 0)
.AddConditionalEdge(
    "start",
    "image_processing",
    condition: state => state.GetString("input_type", string.Empty).IndexOf("image", StringComparison.OrdinalIgnoreCase) >= 0);
```

### 複雜邏輯運算式

使用邏輯運算子組合多個條件：

```csharp
graph.AddConditionalEdge("start", "premium_processing", 
    condition: state => {
        var isPremium = state.GetBool("is_premium_user", false);
        var hasCredits = state.GetInt("credits", 0) > 0;
        var isBusinessHours = IsBusinessHours(state.GetDateTime("timestamp"));
        
        return isPremium && hasCredits && isBusinessHours;
    })
.AddConditionalEdge("start", "standard_processing", 
    condition: state => {
        var isPremium = state.GetBool("is_premium_user", false);
        var hasCredits = state.GetInt("credits", 0) > 0;
        
        return !isPremium || !hasCredits;
    });
```

## 效能最佳化

### 快取評估

快取條件評估以提高效能：

```csharp
// 快取評估：在狀態中儲存昂貴計算的結果。
var cachedCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        // 快取結果以避免重複計算
        if (state.TryGetValue("cached_decision", out var cached) && cached is bool cachedBool)
        {
            return cachedBool;
        }

        var result = ExpensiveCalculation(state);
        state["cached_decision"] = result;
        return result;
    },
    nodeId: "cached_decision"
);
```

### 延遲評估

使用延遲評估進行昂貴的條件：

```csharp
// 延遲評估：僅在必要時執行昂貴的檢查並快取結果。
var lazyCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        // 僅在尚未決定時評估
        if (state.ContainsKey("route_decided") && state.GetBool("route_decided", false))
        {
            return state.GetBool("route_decided", false);
        }

        // 執行昂貴的評估並快取結果
        var result = EvaluateComplexCondition(state);
        state["route_decided"] = result;
        return result;
    },
    nodeId: "lazy_evaluation"
);
```

## 除錯和檢查

### 條件式除錯

將除錯資訊新增至條件式 Node：

```csharp
// 條件式除錯：在 Graph 狀態中儲存結構化除錯資訊以供檢查。
var debugCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        var condition = state.GetString("condition", string.Empty);
        var value = state.GetInt("value", 0);
        var threshold = state.GetInt("threshold", 50);

        var result = value >= threshold;

        // 在結構化物件中記錄決策以供除錯
        state["debug_info"] = new
        {
            Condition = condition,
            Value = value,
            Threshold = threshold,
            Result = result,
            Timestamp = DateTimeOffset.UtcNow
        };

        return result;
    },
    nodeId: "debug_condition"
);
```

### 決策追蹤

追蹤工作流程中的決策路徑：

```csharp
// 決策追蹤：將決策項目附加到儲存在狀態中的歷史清單。
var traceCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        var decision = EvaluateCondition(state);

        // 新增至決策歷史（如果遺失則初始化清單）
        var history = state.GetValue<List<string>>("decision_history") ?? new List<string>();
        history.Add($"Node: trace_condition, Decision: {decision}, Timestamp: {DateTimeOffset.UtcNow}");
        state["decision_history"] = history;

        return decision;
    },
    nodeId: "trace_condition"
);
```

## 最佳實務

### 條件設計

1. **保持條件簡單** - 複雜邏輯應在個別函式中處理
2. **使用有意義的名稱** - 命名條件以反映其目的
3. **處理邊緣情況** - 始終提供後備路徑
4. **驗證輸入** - 在評估前檢查必需的狀態值

### 效能考量

1. **快取昂貴的評估** - 儲存結果以避免重新計算
2. **使用延遲評估** - 僅在必要時評估
3. **最佳化狀態存取** - 最小化條件中的狀態查閱
4. **批次決策** - 盡可能分組相關條件

### 錯誤處理

1. **提供後備** - 始終有預設路徑
2. **驗證狀態** - 在評估前檢查必需值
3. **記錄決策** - 追蹤決策路徑以便除錯
4. **處理例外** - 在 try-catch 區塊中包裝條件

## 疑難排解

### 常見問題

**條件未評估**：檢查狀態是否包含必需值且型別相符

**非預期的路由**：驗證條件邏輯並新增除錯記錄

**效能問題**：快取昂貴的評估並最佳化狀態存取

**無限迴圈**：確保條件最終解析為終端狀態

### 除錯提示

1. **啟用除錯記錄**以追蹤條件評估
2. **新增決策追蹤**以追蹤執行路徑
3. **在條件邏輯中使用中斷點**
4. **檢查決策點的狀態值**

## 概念和技術

**ConditionalGraphNode**：一種特殊化的 Graph Node，評估謂詞以決定執行流程。它可根據 Graph 的目前狀態啟用動態路由。

**ConditionalEdge**：Node 之間的連線，包括執行條件。它允許複雜的分支邏輯和基於狀態評估的動態工作流程路徑。

**Predicate**：評估目前 Graph 狀態並傳回布林值的函式。謂詞決定在條件式路由中採取哪條執行路徑。

**Template Expression**：更複雜的條件運算式，可評估多個狀態值並執行計算以決定路由決策。

**State-Dependent Routing**：一種模式，其中執行路徑根據 Graph 狀態中的目前值動態決定，啟用自適應工作流程。

## 另請參閱

* [Build a Graph](build-a-graph.md) - 了解 Graph 構造的基礎
* [Loops](loops.md) - 使用迴圈 Node 實現反覆式工作流程
* [Advanced Routing](advanced-routing.md) - 探索複雜的路由模式和策略
* [State Management](../state-quickstart.md) - 了解如何管理 Node 之間的資料流
* [Debug and Inspection](debug-and-inspection.md) - 了解如何除錯條件邏輯
* [Examples: Conditional Workflows](../examples/conditional-nodes-example.md) - 條件式路由的完整工作範例
