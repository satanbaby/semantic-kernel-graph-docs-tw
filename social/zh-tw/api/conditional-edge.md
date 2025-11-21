# ConditionalEdge

`ConditionalEdge` 類別代表兩個 Graph Node 之間的有向、可選擇受保護的過渡。它封裝了導航規則，這些規則根據運行時條件決定執行何時可以從源 Node 流向目標 Node。

## 概述

條件 Edge 在您的 Graph 工作流中充當守門人，允許您創建動態執行路徑以響應當前狀態。Edge 針對 `KernelArguments` 或 `GraphState` 評估謂詞函數，以確定是否允許遍歷。

## 關鍵概念

**條件路由**：只有在滿足特定條件時才允許遍歷的 Edge，啟用動態工作流分支。

**謂詞評估**：檢查當前執行上下文並返回 true/false 來確定路由決策的函數。

**基於狀態的決策**：可以訪問簡單參數和豐富 Graph 狀態信息的條件。

**合併配置**：控制多個並行分支收斂時狀態如何組合的設置。

## 核心屬性

### Edge Identity
* **`EdgeId`**：在構造時生成的唯一、不可變識別符
* **`Name`**：用於診斷和可視化的人類可讀名稱
* **`SourceNode`**：遍歷開始的源 Node
* **`TargetNode`**：條件為真時到達的目標 Node

### 條件評估
* **`Condition`**：針對 `KernelArguments` 進行評估的謂詞函數
* **`StateCondition`**：針對 `GraphState` 進行評估的可選謂詞函數
* **`CreatedAt`**：Edge 創建時的 UTC 時間戳

### 執行元數據
* **`TraversalCount`**：此 Edge 被遍歷的次數
* **`LastTraversedAt`**：最後一次遍歷的 UTC 時間戳
* **`HasBeenTraversed`**：表示 Edge 是否已被使用的布林值

### 配置
* **`Metadata`**：用於存儲路由權重、可視化提示或來源信息的可變集合
* **`MergeConfiguration`**：並行分支收斂期間狀態聯接的設置

## 建構函式

### 基本條件 Edge

```csharp
public ConditionalEdge(
    IGraphNode sourceNode, 
    IGraphNode targetNode, 
    Func<KernelArguments, bool> condition, 
    string? name = null)
```

創建一個使用針對 `KernelArguments` 進行評估的謂詞的 Edge。

**參數：**
* `sourceNode`：源 Node
* `targetNode`：目標 Node
* `condition`：無副作用謂詞函數
* `name`：可選的人類可讀名稱（默認為「Source -> Target」）

**範例：**
```csharp
var edge = new ConditionalEdge(
    sourceNode: startNode,
    targetNode: successNode,
    condition: args => args.ContainsKey("success") && (bool)args["success"],
    name: "Success Path"
);
```

### 基於狀態的條件 Edge

```csharp
public ConditionalEdge(
    IGraphNode sourceNode, 
    IGraphNode targetNode, 
    Func<GraphState, bool> stateCondition, 
    string? name = null)
```

創建一個使用針對 `GraphState` 進行評估的謂詞的 Edge。

**參數：**
* `sourceNode`：源 Node
* `targetNode`：目標 Node
* `stateCondition`：用於 Graph 狀態的無副作用謂詞函數
* `name`：可選的人類可讀名稱

**範例：**
```csharp
var edge = new ConditionalEdge(
    sourceNode: decisionNode,
    targetNode: highPriorityNode,
    stateCondition: state => state.GetValue<int>("priority") > 7,
    name: "High Priority Route"
);
```

## 工廠方法

### CreateUnconditional

```csharp
public static ConditionalEdge CreateUnconditional(
    IGraphNode sourceNode, 
    IGraphNode targetNode, 
    string? name = null)
```

創建始終可遍歷的 Edge（條件始終返回 true）。

**範例：**
```csharp
var alwaysEdge = ConditionalEdge.CreateUnconditional(
    sourceNode: startNode,
    targetNode: nextNode,
    name: "Default Path"
);
```

### CreateParameterEquals

```csharp
public static ConditionalEdge CreateParameterEquals(
    IGraphNode sourceNode, 
    IGraphNode targetNode,
    string parameterName, 
    object expectedValue, 
    string? name = null)
```

創建只有當特定參數等於預期值時才可遍歷的 Edge。

**範例：**
```csharp
var modeEdge = ConditionalEdge.CreateParameterEquals(
    sourceNode: inputNode,
    targetNode: advancedNode,
    parameterName: "mode",
    expectedValue: "advanced",
    name: "Advanced Mode Route"
);
```

### CreateParameterExists

```csharp
public static ConditionalEdge CreateParameterExists(
    IGraphNode sourceNode, 
    IGraphNode targetNode,
    string parameterName, 
    string? name = null)
```

創建只有當特定參數存在時才可遍歷的 Edge。

**範例：**
```csharp
var authEdge = ConditionalEdge.CreateParameterExists(
    sourceNode: loginNode,
    targetNode: protectedNode,
    parameterName: "authToken",
    name: "Authenticated Route"
);
```

## 條件評估

### EvaluateCondition (KernelArguments)

```csharp
public bool EvaluateCondition(KernelArguments arguments)
```

針對提供的參數評估條件。

**參數：**
* `arguments`：要評估的參數集

**返回值：** 如果滿足條件則為 `true`，否則為 `false`

**異常：**
* `ArgumentNullException`：當參數為 null 時
* `InvalidOperationException`：當基礎謂詞拋出異常時

**範例：**
```csharp
var args = new KernelArguments { ["status"] = "approved" };
if (edge.EvaluateCondition(args))
{
    // 遍歷到目標 Node
}
```

### EvaluateCondition (GraphState)

```csharp
public bool EvaluateCondition(GraphState graphState)
```

當可用時使用 `GraphState` 評估條件，否則回退到 `KernelArguments` 謂詞。

**參數：**
* `graphState`：要評估的 Graph 狀態

**返回值：** 如果滿足條件則為 `true`，否則為 `false`

**範例：**
```csharp
var state = new GraphState(new KernelArguments { ["score"] = 85 });
if (edge.EvaluateCondition(state))
{
    // 遍歷到目標 Node
}
```

## 合併配置

### WithMergePolicy

```csharp
public ConditionalEdge WithMergePolicy(StateMergeConflictPolicy defaultPolicy)
```

配置 Edge 為所有參數使用特定的合併策略。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithMergePolicy(StateMergeConflictPolicy.PreferFirst);
```

### WithMergeConfiguration

```csharp
public ConditionalEdge WithMergeConfiguration(StateMergeConfiguration configuration)
```

使用用於並行分支聯接的詳細合併設置配置 Edge。

**範例：**
```csharp
var config = new StateMergeConfiguration 
{ 
    DefaultPolicy = StateMergeConflictPolicy.Reduce 
};
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithMergeConfiguration(config);
```

### WithKeyMergePolicy

```csharp
public ConditionalEdge WithKeyMergePolicy(string key, StateMergeConflictPolicy policy)
```

為特定參數鍵配置合併策略。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithKeyMergePolicy("userData", StateMergeConflictPolicy.PreferSecond);
```

### WithTypeMergePolicy

```csharp
public ConditionalEdge WithTypeMergePolicy(Type type, StateMergeConflictPolicy policy)
```

為特定的 .NET 類型配置合併策略。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithTypeMergePolicy(typeof(List<string>), StateMergeConflictPolicy.Reduce);
```

### WithCustomKeyMerger

```csharp
public ConditionalEdge WithCustomKeyMerger(string key, Func<object?, object?, object?> merger)
```

為特定參數鍵配置自定義合併函數。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithCustomKeyMerger("counters", (baseVal, overlayVal) => 
    {
        var baseCount = baseVal as int? ?? 0;
        var overlayCount = overlayVal as int? ?? 0;
        return baseCount + overlayCount;
    });
```

### WithReduceSemantics

```csharp
public ConditionalEdge WithReduceSemantics()
```

配置 Edge 使用具有常見類型默認 Reducer 的 Reduce 語義。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithReduceSemantics();
```

## 驗證和完整性

### ValidateIntegrity

```csharp
public ValidationResult ValidateIntegrity()
```

驗證 Edge 是否存在潛在問題，如自我循環和無效條件函數。

**返回值：** 包含警告和錯誤的 `ValidationResult`

**範例：**
```csharp
var validation = edge.ValidateIntegrity();
if (validation.HasErrors)
{
    foreach (var error in validation.Errors)
    {
        Console.WriteLine($"Edge validation error: {error}");
    }
}
```

## 使用模式

### 基本條件路由

```csharp
// 使用函數創建 Node
var startNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) => "Start executed",
        "StartNode",
        "Start processing"
    ),
    "start"
);

var successNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) => "Success executed",
        "SuccessNode", 
        "Handle success case"
    ),
    "success"
);

var failureNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) => "Failure executed",
        "FailureNode",
        "Handle failure case"
    ),
    "failure"
);

// 創建條件 Edge
var successEdge = new ConditionalEdge(
    startNode, 
    successNode,
    args => args.ContainsKey("result") && (bool)args["result"],
    "Success Path"
);

var failureEdge = new ConditionalEdge(
    startNode, 
    failureNode,
    args => !args.ContainsKey("result") || !(bool)args["result"],
    "Failure Path"
);

// 添加到執行器
executor.AddEdge(successEdge);
executor.AddEdge(failureEdge);
```

### 複雜的基於狀態的條件

```csharp
var decisionEdge = new ConditionalEdge(
    decisionNode,
    actionNode,
    state => 
    {
        var priority = state.GetValue<int>("priority");
        var isUrgent = state.GetValue<bool>("isUrgent");
        var hasPermission = state.GetValue<string>("userRole") == "admin";
        
        return priority > 7 || (isUrgent && hasPermission);
    },
    name: "High Priority or Urgent Admin Route"
);
```

### 使用工廠方法

```csharp
// 簡單參數檢查
var authEdge = ConditionalEdge.CreateParameterExists(
    loginNode, 
    dashboardNode, 
    "authToken"
);

// 值比較
var premiumEdge = ConditionalEdge.CreateParameterEquals(
    userNode, 
    premiumNode, 
    "subscription", 
    "premium"
);

// 始終可遍歷
var defaultEdge = ConditionalEdge.CreateUnconditional(
    fallbackNode, 
    endNode
);
```

### 並行分支的合併配置

```csharp
var mergeEdge = ConditionalEdge.CreateUnconditional(source, target)
    .WithMergePolicy(StateMergeConflictPolicy.Reduce)
    .WithKeyMergePolicy("counters", StateMergeConflictPolicy.Reduce)
    .WithTypeMergePolicy(typeof(List<string>), StateMergeConflictPolicy.Reduce)
    .WithCustomKeyMerger("userData", (baseVal, overlayVal) => 
    {
        // 用戶數據的自定義合併邏輯
        if (baseVal is Dictionary<string, object> baseDict && 
            overlayVal is Dictionary<string, object> overlayDict)
        {
            var merged = new Dictionary<string, object>(baseDict);
            foreach (var kvp in overlayDict)
            {
                merged[kvp.Key] = kvp.Value;
            }
            return merged;
        }
        return overlayVal;
    });
```

## 與 Graph 執行器整合

### 直接 Edge 添加

```csharp
var edge = new ConditionalEdge(sourceNode, targetNode, condition);
executor.AddEdge(edge);
```

### 使用 ConnectWhen 擴展

```csharp
executor.ConnectWhen("sourceNode", "targetNode", 
    args => args.ContainsKey("condition") && (bool)args["condition"],
    "Conditional Route");
```

### 基於範本的路由

```csharp
executor.ConnectWithTemplate("sourceNode", "targetNode", 
    "{{priority}} > 7 && {{isUrgent}} == true",
    templateEngine,
    "High Priority Urgent Route");
```

## 性能考慮

* **條件函數**：保持謂詞快速且無副作用
* **狀態訪問**：使用 `GraphState` 方法如 `GetValue<T>()` 進行類型安全訪問
* **緩存**：考慮緩存昂貴的條件評估
* **驗證**：在開發期間使用 `ValidateIntegrity()` 提早發現問題

## 線程安全

* 實例對於並發讀取是安全的
* `Metadata` 包和遍歷計數器未同步
* 當多個線程可能並發變動時需要外部同步
* 當精確計數很重要時使用 `RecordTraversal()` 進行原子更新

## 錯誤處理

* 拋出異常的條件被包裝在 `InvalidOperationException` 中
* 在生產代碼中的條件評估周圍使用 try-catch 塊
* 驗證邊缘完整性，然後再添加到 Graph
* 監視遍歷指標以查找意外行為

## 另請參閱

* [條件 Node 指南](../how-to/conditional-nodes.md)
* [狀態管理](../concepts/state.md)
* [Graph 執行模型](../concepts/execution-model.md)
* [路由概念](../concepts/routing.md)
* [StateMergeConfiguration](state-merge-configuration.md)
* [StateMergeConflictPolicy](state-merge-conflict-policy.md)
