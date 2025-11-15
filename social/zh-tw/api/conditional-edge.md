# ConditionalEdge

`ConditionalEdge` 類別代表兩個圖形節點之間的有向且可選受保護的轉移。它封裝了導航規則，這些規則根據運行時條件決定執行何時可以從源節點流向目標節點。

## 概述

條件邊緣在圖形工作流中充當把關者，允許你建立動態執行路徑來回應當前狀態。邊緣評估針對 `KernelArguments` 或 `GraphState` 的謂詞函數，以決定是否允許遍歷。

## 關鍵概念

**條件路由**：僅在滿足特定條件時允許遍歷的邊緣，實現動態工作流分支。

**謂詞評估**：檢查當前執行上下文並傳回真假值來決定路由決策的函數。

**基於狀態的決策**：可以訪問簡單參數和豐富圖形狀態資訊的條件。

**合併配置**：控制當多個平行分支聚合時狀態如何組合的設定。

## 核心屬性

### 邊緣標識
* **`EdgeId`**：在構造時生成的唯一、不可變識別碼
* **`Name`**：用於診斷和視覺化的人類可讀名稱
* **`SourceNode`**：遍歷開始的源節點
* **`TargetNode`**：條件為真時到達的目標節點

### 條件評估
* **`Condition`**：針對 `KernelArguments` 評估的謂詞函數
* **`StateCondition`**：針對 `GraphState` 評估的可選謂詞函數
* **`CreatedAt`**：建立邊緣時的 UTC 時間戳

### 執行元數據
* **`TraversalCount`**：此邊緣被遍歷的次數
* **`LastTraversedAt`**：最後一次遍歷的 UTC 時間戳
* **`HasBeenTraversed`**：指示邊緣是否已被使用的布林值

### 配置
* **`Metadata`**：用於儲存路由權重、視覺化提示或出處資訊的可變集合
* **`MergeConfiguration`**：平行分支聚合期間狀態聯接的設定

## 構造函數

### 基本條件邊緣

```csharp
public ConditionalEdge(
    IGraphNode sourceNode, 
    IGraphNode targetNode, 
    Func<KernelArguments, bool> condition, 
    string? name = null)
```

建立一個邊緣，其謂詞在 `KernelArguments` 上評估。

**參數：**
* `sourceNode`：源節點
* `targetNode`：目標節點
* `condition`：無副作用的謂詞函數
* `name`：選用的人類可讀名稱（預設為「Source -> Target」）

**範例：**
```csharp
var edge = new ConditionalEdge(
    sourceNode: startNode,
    targetNode: successNode,
    condition: args => args.ContainsKey("success") && (bool)args["success"],
    name: "Success Path"
);
```

### 基於狀態的條件邊緣

```csharp
public ConditionalEdge(
    IGraphNode sourceNode, 
    IGraphNode targetNode, 
    Func<GraphState, bool> stateCondition, 
    string? name = null)
```

建立一個邊緣，其謂詞在 `GraphState` 上評估。

**參數：**
* `sourceNode`：源節點
* `targetNode`：目標節點
* `stateCondition`：針對圖形狀態的無副作用謂詞函數
* `name`：選用的人類可讀名稱

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

建立一個始終可遍歷的邊緣（條件始終傳回真）。

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

建立一個邊緣，僅當特定引數等於預期值時才可遍歷。

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

建立一個邊緣，僅當特定引數存在時才可遍歷。

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

針對提供的引數評估條件。

**參數：**
* `arguments`：要評估的引數包

**傳回值：** 如果滿足條件則為 `true`，否則為 `false`

**例外狀況：**
* `ArgumentNullException`：當引數為空值時
* `InvalidOperationException`：當基礎謂詞拋出時

**範例：**
```csharp
var args = new KernelArguments { ["status"] = "approved" };
if (edge.EvaluateCondition(args))
{
    // 遍歷到目標節點
}
```

### EvaluateCondition (GraphState)

```csharp
public bool EvaluateCondition(GraphState graphState)
```

使用 `GraphState` 評估條件（如果可用），否則回退到 `KernelArguments` 謂詞。

**參數：**
* `graphState`：要評估的圖形狀態

**傳回值：** 如果滿足條件則為 `true`，否則為 `false`

**範例：**
```csharp
var state = new GraphState(new KernelArguments { ["score"] = 85 });
if (edge.EvaluateCondition(state))
{
    // 遍歷到目標節點
}
```

## 合併配置

### WithMergePolicy

```csharp
public ConditionalEdge WithMergePolicy(StateMergeConflictPolicy defaultPolicy)
```

配置邊緣以針對所有參數使用特定的合併原則。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithMergePolicy(StateMergeConflictPolicy.PreferFirst);
```

### WithMergeConfiguration

```csharp
public ConditionalEdge WithMergeConfiguration(StateMergeConfiguration configuration)
```

配置邊緣以針對平行分支聯接設定詳細的合併設定。

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

為特定參數鍵配置合併原則。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithKeyMergePolicy("userData", StateMergeConflictPolicy.PreferSecond);
```

### WithTypeMergePolicy

```csharp
public ConditionalEdge WithTypeMergePolicy(Type type, StateMergeConflictPolicy policy)
```

為特定 .NET 型別配置合併原則。

**範例：**
```csharp
var edge = ConditionalEdge.CreateUnconditional(source, target)
    .WithTypeMergePolicy(typeof(List<string>), StateMergeConflictPolicy.Reduce);
```

### WithCustomKeyMerger

```csharp
public ConditionalEdge WithCustomKeyMerger(string key, Func<object?, object?, object?> merger)
```

為特定參數鍵配置自訂合併函數。

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

配置邊緣以對常見型別使用減少語義和預設化簡工具。

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

驗證邊緣的潛在問題，如自迴圈和無效條件函數。

**傳回值：** 包含警告和錯誤的 `ValidationResult`

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
// 建立包含函數的節點
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

// 建立條件邊緣
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

// 新增到執行器
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

### 平行分支的合併配置

```csharp
var mergeEdge = ConditionalEdge.CreateUnconditional(source, target)
    .WithMergePolicy(StateMergeConflictPolicy.Reduce)
    .WithKeyMergePolicy("counters", StateMergeConflictPolicy.Reduce)
    .WithTypeMergePolicy(typeof(List<string>), StateMergeConflictPolicy.Reduce)
    .WithCustomKeyMerger("userData", (baseVal, overlayVal) => 
    {
        // 自訂使用者資料的合併邏輯
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

## 與圖形執行器的整合

### 直接邊緣新增

```csharp
var edge = new ConditionalEdge(sourceNode, targetNode, condition);
executor.AddEdge(edge);
```

### 使用 ConnectWhen 擴充方法

```csharp
executor.ConnectWhen("sourceNode", "targetNode", 
    args => args.ContainsKey("condition") && (bool)args["condition"],
    "Conditional Route");
```

### 範本型路由

```csharp
executor.ConnectWithTemplate("sourceNode", "targetNode", 
    "{{priority}} > 7 && {{isUrgent}} == true",
    templateEngine,
    "High Priority Urgent Route");
```

## 效能考量

* **條件函數**：保持謂詞快速且無副作用
* **狀態訪問**：使用 `GraphState` 方法（如 `GetValue<T>()`）進行型別安全訪問
* **快取**：考慮快取成本高昂的條件評估
* **驗證**：在開發期間使用 `ValidateIntegrity()` 及早發現問題

## 執行緒安全性

* 執行個體對並行讀取是安全的
* `Metadata` 包和遍歷計數器未同步
* 當多個執行緒可能同時變更時需要外部同步
* 當精確計數很重要時，使用 `RecordTraversal()` 進行原子更新

## 錯誤處理

* 拋出的條件包裝在 `InvalidOperationException` 中
* 在生產程式碼中，在條件評估周圍使用 try-catch 區塊
* 在新增到圖形前驗證邊緣完整性
* 監控遍歷指標以查找意外行為

## 另請參閱

* [條件節點指南](../how-to/conditional-nodes.md)
* [狀態管理](../concepts/state.md)
* [圖形執行模型](../concepts/execution-model.md)
* [路由概念](../concepts/routing.md)
* [StateMergeConfiguration](state-merge-configuration.md)
* [StateMergeConflictPolicy](state-merge-conflict-policy.md)
