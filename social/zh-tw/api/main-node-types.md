# 主要Node類型

本文件涵蓋SemanticKernel.Graph中的五種主要Node類型，這些類型為構建複雜工作流程提供了基礎：`FunctionGraphNode`、`ConditionalGraphNode`、`ReasoningGraphNode`、`ReActLoopGraphNode`和`ObservationGraphNode`。

## FunctionGraphNode

`FunctionGraphNode`封裝一個Semantic Kernel函數，並圍繞現有的`KernelFunction`實例提供Graph特定的功能。

### 概述

此Node將執行轉發到基礎`KernelFunction`，並使用Graph感知行為增強它，包括導航、元資料掛鉤和生命週期管理。

### 主要特性

* **Function Encapsulation（函數封裝）**: 封裝來自Semantic Kernel的任何`KernelFunction`
* **Navigation Support（導航支持）**: 連接無條件的後繼節點和條件轉換
* **Metadata Hooks（元資料掛鉤）**: 自訂設置、清理和錯誤處理邏輯
* **Thread Safety（線程安全）**: 連接列表由私有鎖保護以進行變更
* **Result Storage（結果儲存）**: 自動將執行結果儲存在Graph狀態中

### Metadata Hooks

以下元資料鍵啟用自訂行為：

* **`"StoreResultAs"`** (string): 將最後結果儲存到`GraphState`中的指定鍵
* **`"BeforeExecute"`** (Action/Func): 在`OnBeforeExecuteAsync`中執行的自訂設置邏輯
* **`"AfterExecute"`** (Action/Func): 在`OnAfterExecuteAsync`中執行的自訂清理邏輯
* **`"OnExecutionFailed"`** (Action/Func): 在`OnExecutionFailedAsync`中執行的錯誤處理掛鉤
* **`"StrictValidation"`** (bool): 若為true，執行前驗證失敗會導致異常

### 使用示例

#### 基本Function包裝

```csharp
// 建立輕量級kernel函數，將輸入字符串進行轉換。
var function = kernel.CreateFunctionFromMethod(
    (string input) => $"Processed: {input}",
    functionName: "process_input"
);

// 將kernel函數包裝在FunctionGraphNode中，並在狀態中保存結果。
var node = new FunctionGraphNode(function, "process_node")
    .StoreResultAs("processed_result");

// 您可以直接連接Node，或將它們添加到GraphExecutor並使用圖級別連接
// 示例：連接到另一個Node實例
node.ConnectTo(nextNode);
```

#### 來自插件函數

```csharp
// 從插件函數建立
var node = FunctionGraphNode.FromPlugin(kernel, "math", "add")
    .StoreResultAs("sum");

// 添加條件Edge
node.AddConditionalEdge(new ConditionalEdge(
    condition: state => state.GetValue<int>("sum") > 10,
    targetNode: highValueNode
));
```

#### 帶有自訂Metadata掛鉤

```csharp
var node = new FunctionGraphNode(function, "custom_node")
    .StoreResultAs("result");

// 添加自訂生命週期掛鉤
node.SetMetadata("BeforeExecute", (Action<KernelArguments>)(args => {
    args["execution_start"] = DateTime.UtcNow;
}));

node.SetMetadata("AfterExecute", (Action<KernelArguments, FunctionResult>)((args, result) => {
    args["execution_duration"] = DateTime.UtcNow - (DateTime)args["execution_start"];
}));
```

## ConditionalGraphNode

`ConditionalGraphNode`基於Graph狀態實現條件if/else邏輯，評估條件並將執行路由到不同的路徑，而無需執行函數。

### 概述

此Node提供基於函數和基於範本的條件，具有高級快取、調試支持和綜合指標追蹤。

### 主要特性

* **Function-based Conditions（基於函數的條件）**: 使用`Func<GraphState, bool>`進行直接評估
* **Template-based Conditions（基於範本的條件）**: Handlebars型範本，具有變數替換
* **Advanced Caching（高級快取）**: 評估結果的自動快取以提高性能
* **Debugging Support（調試支持）**: 與`ConditionalDebugger`集成以進行逐步分析
* **Metrics Tracking（指標追蹤）**: 綜合執行指標和性能監控
* **Thread Safety（線程安全）**: 所有操作都是線程安全的，以支持並發執行

### 條件類型

#### 基於函數的條件

```csharp
// 簡單布爾條件
var conditionNode = new ConditionalGraphNode(
    condition: state => state.GetValue<int>("score") > 80,
    name: "High Score Check"
);

conditionNode.AddTrueNode(successNode);
conditionNode.AddFalseNode(retryNode);
```

#### 基於範本的條件

```csharp
// Handlebars型範本
var templateNode = new ConditionalGraphNode(
    conditionTemplate: "{{ gt score 0.8 }}",
    name: "Score Threshold Check"
);

templateNode.AddTrueNode(successNode);
templateNode.AddFalseNode(retryNode);
```

### 進階使用

#### 複雜條件

```csharp
var complexCondition = new ConditionalGraphNode(
    condition: state => {
        var score = state.GetValue<int>("score");
        var attempts = state.GetValue<int>("attempts");
        var maxAttempts = state.GetValue<int>("max_attempts");
        
        return score >= 90 || attempts >= maxAttempts;
    },
    name: "Complex Decision Logic"
);
```

#### 多個真/假路徑

```csharp
var decisionNode = new ConditionalGraphNode(
    condition: state => state.GetValue<string>("status") == "completed",
    name: "Status Check"
);

// 多個真路徑
decisionNode.AddTrueNode(successNode);
decisionNode.AddTrueNode(notificationNode);

// 多個假路徑
decisionNode.AddFalseNode(retryNode);
decisionNode.AddFalseNode(errorHandlerNode);
```

## ReasoningGraphNode

`ReasoningGraphNode`實現推理功能，用於分析當前情況和規劃下一步行動，設計為ReAct模式的一部分，用於結構化決策。

### 概述

此Node分析當前上下文、評估可用資訊，並使用可配置的提示範本生成關於應採取何種行動的結構化推理。

### 主要特性

* **Context-aware Reasoning（上下文感知推理）**: 分析當前情況和可用數據
* **Template-based Prompts（基於範本的提示）**: 使用可自訂的範本以支持不同的推理模式
* **Quality Metrics（質量指標）**: 追蹤推理質量和一致性
* **Domain Specialization（領域專業化）**: 可針對特定問題領域進行配置
* **Chain-of-thought Support（思維鏈支持）**: 支持逐步推理模式

### 領域專業化

Node支持具有專門提示的預定義領域：

```csharp
// 為特定領域建立
var mathReasoningNode = ReasoningGraphNode.CreateForDomain(
    ReasoningDomain.Mathematics,
    nodeId: "math_reasoning"
);

// 為通用推理建立
var generalReasoningNode = new ReasoningGraphNode(
    reasoningPrompt: "Analyze the current situation and determine the next logical step.",
    name: "General Reasoning"
);
```

### 配置選項

#### Metadata配置

```csharp
var reasoningNode = new ReasoningGraphNode(
    "Analyze the problem and plan the solution step by step.",
    name: "Problem Analysis"
);

// 配置推理行為
reasoningNode.SetMetadata("ChainOfThoughtEnabled", true);
reasoningNode.SetMetadata("MaxReasoningSteps", 5);
reasoningNode.SetMetadata("ConfidenceThreshold", 0.8);
reasoningNode.SetMetadata("Domain", "problem_solving");
```

#### Template Engine集成

```csharp
var templateEngine = new GraphTemplateEngine();
var reasoningNode = new ReasoningGraphNode(
    "Current context: {{context}}\nProblem: {{problem}}\nPlan the next action:",
    templateEngine: templateEngine
);
```

### 在ReAct模式中的使用

```csharp
// 為ReAct迴圈建立推理Node
var reasoningNode = new ReasoningGraphNode(
    "Based on the current situation: {{situation}}\n" +
    "Available actions: {{available_actions}}\n" +
    "What should be the next action?",
    name: "ReAct Reasoning"
);

// 配置以進行迭代推理
reasoningNode.SetMetadata("MaxReasoningSteps", 3);
reasoningNode.SetMetadata("ConfidenceThreshold", 0.7);
```

## ReActLoopGraphNode

`ReActLoopGraphNode`協調完整的ReAct（推理+行動）模式迴圈，在迭代週期中協調推理、行動執行和觀察，直到實現目標。

### 概述

此Node通過協調推理、執行、觀察和迴圈控制，以協調的方式實現完整的ReAct模式，具有可配置的限制和複雜的目標評估。

### 主要特性

* **Complete ReAct Orchestration（完整的ReAct協調）**: 管理完整的推理-執行-觀察週期
* **Flexible Node Composition（靈活的Node組合）**: 可使用自訂推理、行動和觀察Node
* **Iteration Limits（迭代限制）**: 可配置的最大迭代，具有提前終止
* **Goal Evaluation（目標評估）**: 複雜的目標實現檢測
* **Performance Tracking（性能追蹤）**: 綜合指標和計時資訊
* **Error Handling（錯誤處理）**: 具有恢復策略的強大錯誤處理
* **Context Management（上下文管理）**: 在迭代期間維護和更新上下文

### 組件配置

#### 基本設置

```csharp
// 構建ActionGraphNode，從kernel發現可執行的操作。
var actionNode = ActionGraphNode.CreateWithActions(
    kernel,
    new ActionSelectionCriteria { MinRequiredParameters = 0, MaxRequiredParameters = 5 },
    "action_node"
);

// 建立ReAct迴圈Node並組合推理、行動和觀察Node。
var reactLoopNode = new ReActLoopGraphNode(nodeId: "react_loop", name: "react_loop");
reactLoopNode.ConfigureNodes(reasoningNode, actionNode, observationNode);
```

#### Factory方法

```csharp
var reactLoopNode = ReActLoopGraphNode.CreateWithNodes(
    reasoningNode: reasoningNode,
    actionNode: actionNode,
    observationNode: observationNode,
    nodeId: "react_loop"
);
```

### 配置選項

#### 迴圈行為

```csharp
// 配置迭代限制
reactLoopNode.SetMetadata("MaxIterations", 10);
reactLoopNode.SetMetadata("IterationTimeout", TimeSpan.FromMinutes(5));
reactLoopNode.SetMetadata("TotalTimeout", TimeSpan.FromMinutes(30));

// 配置目標實現
reactLoopNode.SetMetadata("GoalAchievementThreshold", 0.95);
reactLoopNode.SetMetadata("EarlyTerminationEnabled", true);
```

#### 性能追蹤

```csharp
// 啟用綜合指標
reactLoopNode.SetMetadata("TrackMetrics", true);
reactLoopNode.SetMetadata("TrackTiming", true);
reactLoopNode.SetMetadata("TrackIterations", true);
```

### Metadata鍵

#### 計數器 (int)
* `"ExecutionCount"`: 執行總次數
* `"FailureCount"`: 失敗執行次數
* `"SuccessfulCompletions"`: 成功完成次數
* `"TotalIterations"`: 所有執行中的總迭代次數

#### 指標
* `"AverageExecutionTime"`: 每次執行的平均時間
* `"AverageIterationsPerExecution"`: 每次執行的平均迭代次數
* `"SuccessRate"`: 成功率百分比
* `"LastExecutedAt"`: 最後執行的時間戳

#### 配置
* `"MaxIterations"`: 每次執行的最大迭代次數
* `"GoalAchievementThreshold"`: 目標實現的閾值
* `"EarlyTerminationEnabled"`: 是否啟用提前終止
* `"IterationTimeout"`: 每個迭代的超時
* `"TotalTimeout"`: 執行的總超時
* `"Domain"`: 領域特定配置

## ObservationGraphNode

`ObservationGraphNode`實現ReAct模式的觀察和分析功能，分析行動結果、提取見解，並確定目標是否已實現。

### 概述

此Node分析已執行行動的結果、評估其成功、提取相關資訊，並確定推理週期中的後續步驟。

### 主要特性

* **Result Analysis（結果分析）**: 對行動執行結果的深入分析
* **Goal Evaluation（目標評估）**: 確定是否已達到目標
* **Information Extraction（資訊提取）**: 從結果中提取關鍵見解和數據
* **Quality Assessment（質量評估）**: 評估結果的質量和相關性
* **Context Update（上下文更新）**: 為下一個推理迭代更新上下文
* **Decision Making（決策制定）**: 確定是繼續還是結束ReAct迴圈

### 領域專業化

```csharp
// 為特定領域建立
var mathObservationNode = ObservationGraphNode.CreateForDomain(
    ObservationDomain.Mathematics,
    nodeId: "math_observation"
);

// 為通用觀察建立
var generalObservationNode = new ObservationGraphNode(
    observationPrompt: "Analyze the action result and determine if the goal was achieved.",
    name: "General Observation"
);
```

### 配置選項

#### 分析行為

```csharp
var observationNode = new ObservationGraphNode(
    "Analyze the result: {{result}}\nGoal: {{goal}}\nWas the goal achieved?",
    name: "Result Analysis"
);

// 配置觀察行為
observationNode.SetMetadata("DeepAnalysisEnabled", true);
observationNode.SetMetadata("GoalAchievementThreshold", 0.9);
observationNode.SetMetadata("ExtractionPatterns", new[] { "result", "insight", "next_step" });
```

#### Template Engine集成

```csharp
var templateEngine = new GraphTemplateEngine();
var observationNode = new ObservationGraphNode(
    "Result: {{action_result}}\n" +
    "Expected: {{expected_result}}\n" +
    "Analysis: {{analysis_request}}",
    templateEngine: templateEngine
);
```

### Metadata鍵

#### 計數器 (int)
* `"ExecutionCount"`: 執行總次數
* `"FailureCount"`: 失敗執行次數
* `"GoalAchievedCount"`: 實現目標的次數

#### 指標
* `"AverageExecutionTime"`: 每次執行的平均時間
* `"GoalAchievementRate"`: 目標實現率
* `"AverageSuccessAssessment"`: 平均成功評估分數
* `"LastExecutedAt"`: 最後執行的時間戳

#### 配置
* `"Domain"`: 領域特定配置
* `"DeepAnalysisEnabled"`: 是否執行深入分析
* `"GoalAchievementThreshold"`: 目標實現的閾值

#### 行為自訂
* `"ExtractionPatterns"`: 資訊提取的模式
* `"ResultTypePatterns"`: 結果類型分析的模式
* `"GoalCriteria"`: 目標評估的準則

## 集成模式

### 構建完整的ReAct工作流程

```csharp
// 1. 建立組件Node
var reasoningNode = new ReasoningGraphNode(
    "Analyze the problem: {{problem}}\nPlan the solution:",
    name: "Problem Analysis"
);

var actionNode = new ActionGraphNode(kernel, "action_execution");

var observationNode = new ObservationGraphNode(
    "Analyze result: {{action_result}}\nGoal achieved?",
    name: "Result Analysis"
);

// 2. 建立並配置ReAct迴圈
var actionNode = ActionGraphNode.CreateWithActions(
    kernel,
    new ActionSelectionCriteria { MinRequiredParameters = 0, MaxRequiredParameters = 5 },
    "action_execution"
);

var reactLoopNode = new ReActLoopGraphNode(nodeId: "complete_react_workflow", name: "complete_react_workflow");
reactLoopNode.ConfigureNodes(reasoningNode, actionNode, observationNode);

// 3. 配置迴圈行為
reactLoopNode.SetMetadata("MaxIterations", 5);
reactLoopNode.SetMetadata("GoalAchievementThreshold", 0.9);
reactLoopNode.SetMetadata("EarlyTerminationEnabled", true);

// 4. 新增到executor並設置啟動Node（使用Node ID）
executor.AddNode(reactLoopNode);
executor.SetStartNode(reactLoopNode.NodeId);
```

### 使用Function Node進行條件路由

```csharp
// 建立function Node
var processNode = new FunctionGraphNode(processFunction, "process")
    .StoreResultAs("processed_result");

var validateNode = new FunctionGraphNode(validateFunction, "validate")
    .StoreResultAs("validation_result");

// 建立條件路由
var qualityCheck = new ConditionalGraphNode(
    condition: state => state.GetValue<double>("quality_score") > 0.8,
    name: "Quality Check"
);

qualityCheck.AddTrueNode(highQualityNode);
qualityCheck.AddFalseNode(improvementNode);

// 連接工作流程
processNode.ConnectTo(validateNode);
validateNode.ConnectTo(qualityCheck);
```

## 性能考量

### 快取和優化

* **Conditional Nodes**: 使用基於範本的條件進行複雜邏輯，以利用快取
* **Function Nodes**: 僅在需要時啟用結果儲存，以避免記憶體開銷
* **ReAct Loops**: 設置適當的迭代限制和超時以防止無限迴圈

### 記憶體管理

* **Metadata**: 謹慎使用元資料進行配置；避免儲存大型物件
* **State**: 利用`StoreResultAs`儲存重要結果，而不是儲存所有內容
* **Connections**: 最小化條件Edge的數量以提高性能

### 監控和調試

* **Metrics**: 為性能關鍵Node啟用指標追蹤
* **Logging**: 使用內建日誌記錄功能調試複雜工作流程
* **Validation**: 實施適當的驗證以及早發現問題

## 相關類型

* **IGraphNode**: 所有Graph Node的基介面
* **GraphState**: KernelArguments的包裝器，具有執行元資料
* **ConditionalEdge**: 定義Node之間的條件轉換
* **ActionGraphNode**: 用於執行操作的專門Node
* **GraphExecutor**: 協調Graph工作流程的執行

## 另請參閱

* [Node Types](../concepts/node-types.md) - 可用Node實現的綜合概覽
* [Execution Model](../concepts/execution-model.md) - Node如何參與執行
* [ReAct Pattern](../patterns/react.md) - 了解ReAct推理模式
* [Conditional Nodes](../how-to/conditional-nodes.md) - 構建條件工作流程
* [Getting Started](../getting-started.md) - 構建您的第一個Graph
