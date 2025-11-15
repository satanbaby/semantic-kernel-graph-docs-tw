# 條件節點

本指南說明如何在 SemanticKernel.Graph 中使用條件節點和邊，以建立動態、分支化的工作流程。你將學習如何實現決策邏輯、路由執行流程，以及建立複雜的工作流程模式。

## 概述

條件節點使你能夠建立動態工作流程，可以：
* **根據狀態值或條件進行分支執行**
* **將資料路由到不同的處理路徑**
* **為複雜的商業邏輯實現決策樹**
* **在單一圖形中處理多個場景**

## 基本條件邏輯

### 簡單的述語型分支

使用述語來評估條件並路由執行：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;

// 建立一個具有述語的條件節點。
// 述語安全地檢查 "ok" 鍵的存在，
// 並在返回值前驗證它是否為布林值。
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

// 使用安全檢查根據結果新增條件邊。
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

使用範本表達式進行更複雜的條件邏輯：

```csharp
// 基於範本的條件範例。
// 使用型別的存取器和本地變數來提高清晰度和更簡單的除錯。
var templateCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        var score = state.GetInt("confidence_score", 0);
        var threshold = state.GetInt("threshold", 50);
        return score >= threshold;
    },
    nodeId: "confidence_check"
);

// 根據信心水準以清晰的閾值進行路由。
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

### 多路分支

使用多個路徑建立複雜的決策樹：

```csharp
// 多路分支：確保述語返回布林值並檢查空值/空字串。
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

### 狀態相依路由

根據多個狀態條件路由執行：

```csharp
// 狀態相依路由：保持檢查明確且易於閱讀。
var analysisNode = new ConditionalGraphNode(
    predicate: state =>
    {
        var hasData = state.ContainsKey("input_data");
        var dataSize = state.GetInt("data_size", 0);
        // 複雜性在遺失時預設為 "simple"
        var complexity = state.GetString("complexity", "simple");

        return hasData && dataSize > 0;
    },
    nodeId: "analysis_decision"
);

// 具有清晰閾值和明確比較的複雜路由邏輯。
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

使用狀態值來決定動態閾值：

```csharp
// 動態閾值：計算並使用從狀態衍生的閾值。
var adaptiveNode = new ConditionalGraphNode(
    predicate: state =>
    {
        var baseThreshold = state.GetInt("base_threshold", 50);
        var multiplier = state.GetFloat("threshold_multiplier", 1.0f);
        var dynamicThreshold = (int)Math.Round(baseThreshold * multiplier);

        var currentValue = state.GetInt("current_value", 0);
        // 當目前值達到或超過動態閾值時返回 true
        return currentValue >= dynamicThreshold;
    },
    nodeId: "adaptive_threshold"
);

// 在圖形狀態中儲存計算的閾值以供稍後使用。
graph.AddEdge("adaptive_threshold", "store_threshold");
```

## 條件邊類型

### 布林條件

簡單的是/否路由：

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

基於數值路由：

```csharp
// 使用清晰閾值定義的數值比較。
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

根據字串值和模式路由：

```csharp
// 字串匹配：使用 StringComparison 並防範空值。
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

### 複雜的邏輯表達式

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

## 性能最佳化

### 快取評估

快取條件評估以獲得更好的性能：

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

對昂貴的條件使用延遲評估：

```csharp
// 延遲評估：僅在必要時執行昂貴的檢查並快取結果。
var lazyCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        // 只有在我們尚未決定時才評估
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

### 條件除錯

將除錯資訊新增到條件節點：

```csharp
// 條件除錯：在圖形狀態中儲存結構化的除錯資訊以供檢查。
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
// 決策追蹤：將決策項目附加到儲存在狀態中的歷史記錄清單。
var traceCondition = new ConditionalGraphNode(
    predicate: state =>
    {
        var decision = EvaluateCondition(state);

        // 新增到決策歷史記錄（如果遺失則初始化清單）
        var history = state.GetValue<List<string>>("decision_history") ?? new List<string>();
        history.Add($"Node: trace_condition, Decision: {decision}, Timestamp: {DateTimeOffset.UtcNow}");
        state["decision_history"] = history;

        return decision;
    },
    nodeId: "trace_condition"
);
```

## 最佳實踐

### 條件設計

1. **保持條件簡單** - 複雜邏輯應在單獨的函數中
2. **使用有意義的名稱** - 命名條件以反映其目的
3. **處理邊界情況** - 始終提供後備路徑
4. **驗證輸入** - 在評估前檢查必要的狀態值

### 性能考量

1. **快取昂貴的評估** - 儲存結果以避免重新計算
2. **使用延遲評估** - 僅在必要時評估
3. **最佳化狀態存取** - 最小化條件中的狀態查詢
4. **批次決策** - 在可能的情況下分組相關條件

### 錯誤處理

1. **提供後備** - 始終有預設路徑
2. **驗證狀態** - 在評估前檢查必要的值
3. **記錄決策** - 追蹤決策路徑以進行除錯
4. **處理例外** - 在 try-catch 區塊中包裝條件

## 故障排除

### 常見問題

**條件未評估**：檢查狀態是否包含必要的值，且型別相符

**意外的路由**：驗證條件邏輯並新增除錯記錄

**性能問題**：快取昂貴的評估並最佳化狀態存取

**無限迴圈**：確保條件最終解析為終端狀態

### 除錯提示

1. **啟用除錯記錄**以追蹤條件評估
2. **新增決策追蹤**以追蹤執行路徑
3. **在條件邏輯中使用中斷點**
4. **檢查決策點處的狀態值**

## 概念和技術

**ConditionalGraphNode**：一個專門的圖形節點，評估述語以決定執行流程。它根據圖形的目前狀態啟用動態路由。

**ConditionalEdge**：節點之間的連接，包含執行條件。它允許複雜的分支邏輯和基於狀態評估的動態工作流程路徑。

**述語**：評估目前圖形狀態並返回布林值的函數。述語決定在條件路由中採用哪個執行路徑。

**範本表達式**：一個更複雜的條件表達式，可以評估多個狀態值並執行計算來決定路由決策。

**狀態相依路由**：一個模式，其中執行路徑根據圖形狀態中的目前值動態決定，啟用自適應工作流程。

## 另請參閱

* [建立圖形](build-a-graph.md) - 學習圖形建構的基礎
* [迴圈](loops.md) - 使用迴圈節點實現迭代工作流程
* [進階路由](advanced-routing.md) - 探索複雜的路由模式和策略
* [狀態管理](../state-quickstart.md) - 了解如何管理節點之間的資料流
* [除錯和檢查](debug-and-inspection.md) - 學習如何除錯條件邏輯
* [範例：條件工作流程](../examples/conditional-nodes-example.md) - 條件路由的完整工作範例
