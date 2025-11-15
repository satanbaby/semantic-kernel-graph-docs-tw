# 主要節點類型

本文檔涵蓋 SemanticKernel.Graph 中的五種主要節點類型，它們為建構複雜工作流程提供基礎：`FunctionGraphNode`、`ConditionalGraphNode`、`ReasoningGraphNode`、`ReActLoopGraphNode` 和 `ObservationGraphNode`。

## FunctionGraphNode

`FunctionGraphNode` 封裝了 Semantic Kernel 函式，並圍繞現有的 `KernelFunction` 實例提供圖形特定的功能。

### 概述

此節點將執行轉發到底層 `KernelFunction`，並通過圖感知行為（包括導航、中繼資料鉤子和生命週期管理）來擴展它。

### 主要功能

* **函式封裝**：封裝 Semantic Kernel 中的任何 `KernelFunction`
* **導航支援**：連接無條件的後繼節點和條件轉換
* **中繼資料鉤子**：自訂設置、清理和錯誤處理邏輯
* **執行緒安全**：連接列表由私有鎖保護以進行變更
* **結果儲存**：自動將執行結果儲存在圖形狀態中

### 中繼資料鉤子

下列中繼資料鍵啟用自訂行為：

* **`"StoreResultAs"`**（字串）：將最後結果儲存到 `GraphState` 中的指定鍵下
* **`"BeforeExecute"`**（Action/Func）：在 `OnBeforeExecuteAsync` 中執行的自訂設置邏輯
* **`"AfterExecute"`**（Action/Func）：在 `OnAfterExecuteAsync` 中執行的自訂清理邏輯
* **`"OnExecutionFailed"`**（Action/Func）：在 `OnExecutionFailedAsync` 中執行的錯誤處理鉤子
* **`"StrictValidation"`**（bool）：如果為真，執行前驗證失敗會導致例外

### 使用範例

#### 基本函式封裝

```csharp
// 建立一個輕量級核心函式，用於轉換輸入字串。
var function = kernel.CreateFunctionFromMethod(
    (string input) => $"Processed: {input}",
    functionName: "process_input"
);

// 在 FunctionGraphNode 中封裝核心函式，並將結果保持在狀態中。
var node = new FunctionGraphNode(function, "process_node")
    .StoreResultAs("processed_result");

// 您可以直接連接節點或將它們新增到 GraphExecutor 並使用圖層級連接
// 範例：連接到另一個節點實例
node.ConnectTo(nextNode);
```

#### 從外掛程式函式

```csharp
// 從外掛程式函式建立
var node = FunctionGraphNode.FromPlugin(kernel, "math", "add")
    .StoreResultAs("sum");

// 新增條件邊
node.AddConditionalEdge(new ConditionalEdge(
    condition: state => state.GetValue<int>("sum") > 10,
    targetNode: highValueNode
));
```

#### 使用自訂中繼資料鉤子

```csharp
var node = new FunctionGraphNode(function, "custom_node")
    .StoreResultAs("result");

// 新增自訂生命週期鉤子
node.SetMetadata("BeforeExecute", (Action<KernelArguments>)(args => {
    args["execution_start"] = DateTime.UtcNow;
}));

node.SetMetadata("AfterExecute", (Action<KernelArguments, FunctionResult>)((args, result) => {
    args["execution_duration"] = DateTime.UtcNow - (DateTime)args["execution_start"];
}));
```

## ConditionalGraphNode

`ConditionalGraphNode` 基於圖形狀態實現條件 if/else 邏輯，評估條件並將執行路由到不同的路徑，而無需執行函式。

### 概述

此節點提供基於函式和基於範本的條件，具有進階快取、除錯支援和綜合指標追蹤。

### 主要功能

* **基於函式的條件**：使用 `Func<GraphState, bool>` 直接評估
* **基於範本的條件**：具有變數替換的類似 Handlebars 範本
* **進階快取**：自動快取評估結果以提高效能
* **除錯支援**：與 `ConditionalDebugger` 集成以進行逐步分析
* **指標追蹤**：綜合執行指標和效能監視
* **執行緒安全**：所有操作都是執行緒安全的，適合並行執行

### 條件類型

#### 基於函式的條件

```csharp
// 簡單布林條件
var conditionNode = new ConditionalGraphNode(
    condition: state => state.GetValue<int>("score") > 80,
    name: "High Score Check"
);

conditionNode.AddTrueNode(successNode);
conditionNode.AddFalseNode(retryNode);
```

#### 基於範本的條件

```csharp
// 類似 Handlebars 的範本
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

#### 多個正確/錯誤路徑

```csharp
var decisionNode = new ConditionalGraphNode(
    condition: state => state.GetValue<string>("status") == "completed",
    name: "Status Check"
);

// 多個正確路徑
decisionNode.AddTrueNode(successNode);
decisionNode.AddTrueNode(notificationNode);

// 多個錯誤路徑
decisionNode.AddFalseNode(retryNode);
decisionNode.AddFalseNode(errorHandlerNode);
```

## ReasoningGraphNode

`ReasoningGraphNode` 實現推理功能，用於分析當前情況並規劃下一步行動，設計為 ReAct 模式的一部分，用於結構化決策制定。

### 概述

此節點分析當前上下文、評估可用資訊，並使用可配置的提示範本生成有關應採取何種行動的結構化推理。

### 主要功能

* **上下文感知推理**：分析當前情況和可用資料
* **基於範本的提示**：為不同推理模式使用可自訂範本
* **品質指標**：追蹤推理品質和一致性
* **領域專門化**：可為特定問題領域配置
* **思維鏈支援**：支援逐步推理模式

### 領域專門化

該節點支援具有專門提示的預定義領域：

```csharp
// 針對特定領域建立
var mathReasoningNode = ReasoningGraphNode.CreateForDomain(
    ReasoningDomain.Mathematics,
    nodeId: "math_reasoning"
);

// 針對一般推理建立
var generalReasoningNode = new ReasoningGraphNode(
    reasoningPrompt: "Analyze the current situation and determine the next logical step.",
    name: "General Reasoning"
);
```

### 配置選項

#### 中繼資料配置

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

#### 範本引擎集成

```csharp
var templateEngine = new GraphTemplateEngine();
var reasoningNode = new ReasoningGraphNode(
    "Current context: {{context}}\nProblem: {{problem}}\nPlan the next action:",
    templateEngine: templateEngine
);
```

### 在 ReAct 模式中的用法

```csharp
// 為 ReAct 迴圈建立推理節點
var reasoningNode = new ReasoningGraphNode(
    "Based on the current situation: {{situation}}\n" +
    "Available actions: {{available_actions}}\n" +
    "What should be the next action?",
    name: "ReAct Reasoning"
);

// 針對迭代推理進行配置
reasoningNode.SetMetadata("MaxReasoningSteps", 3);
reasoningNode.SetMetadata("ConfidenceThreshold", 0.7);
```

## ReActLoopGraphNode

`ReActLoopGraphNode` 協調完整的 ReAct（推理 + 行動）模式迴圈，協調推理、行動執行和觀察的迭代週期，直到達成目標。

### 概述

此節點通過以協調方式協調推理、行動、觀察和迴圈控制來實現完整的 ReAct 模式，具有可配置的限制和複雜的目標評估。

### 主要功能

* **完整 ReAct 協調**：管理完整的推理-行動-觀察週期
* **靈活節點組成**：可使用自訂推理、行動和觀察節點
* **迭代限制**：可配置的最大迭代次數，支援提前終止
* **目標評估**：複雜的目標達成檢測
* **效能追蹤**：綜合指標和計時資訊
* **錯誤處理**：具有恢復策略的健全錯誤處理
* **上下文管理**：跨迭代維護和更新上下文

### 元件配置

#### 基本設置

```csharp
// 建立一個 ActionGraphNode，它從核心發現可執行的操作。
var actionNode = ActionGraphNode.CreateWithActions(
    kernel,
    new ActionSelectionCriteria { MinRequiredParameters = 0, MaxRequiredParameters = 5 },
    "action_node"
);

// 建立 ReAct 迴圈節點並組成推理、行動和觀察節點。
var reactLoopNode = new ReActLoopGraphNode(nodeId: "react_loop", name: "react_loop");
reactLoopNode.ConfigureNodes(reasoningNode, actionNode, observationNode);
```

#### 工廠方法

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

// 配置目標達成
reactLoopNode.SetMetadata("GoalAchievementThreshold", 0.95);
reactLoopNode.SetMetadata("EarlyTerminationEnabled", true);
```

#### 效能追蹤

```csharp
// 啟用綜合指標
reactLoopNode.SetMetadata("TrackMetrics", true);
reactLoopNode.SetMetadata("TrackTiming", true);
reactLoopNode.SetMetadata("TrackIterations", true);
```

### 中繼資料鍵

#### 計數器 (int)
* `"ExecutionCount"`：執行總次數
* `"FailureCount"`：失敗執行次數
* `"SuccessfulCompletions"`：成功完成次數
* `"TotalIterations"`：跨所有執行的總迭代次數

#### 指標
* `"AverageExecutionTime"`：每次執行的平均時間
* `"AverageIterationsPerExecution"`：每次執行的平均迭代次數
* `"SuccessRate"`：成功率百分比
* `"LastExecutedAt"`：上次執行的時間戳

#### 配置
* `"MaxIterations"`：每次執行的最大迭代次數
* `"GoalAchievementThreshold"`：目標達成閾值
* `"EarlyTerminationEnabled"`：是否啟用提前終止
* `"IterationTimeout"`：每次迭代的超時時間
* `"TotalTimeout"`：執行的總超時時間
* `"Domain"`：領域特定配置

## ObservationGraphNode

`ObservationGraphNode` 為 ReAct 模式實現觀察和分析功能，分析行動結果、提取見解，並確定是否已達成目標。

### 概述

此節點分析已執行行動的結果、評估其成功、提取相關資訊，並確定推理週期中的下一步。

### 主要功能

* **結果分析**：深入分析行動執行結果
* **目標評估**：確定目標是否已達成
* **資訊提取**：從結果中提取關鍵見解和資料
* **品質評估**：評估結果的品質和相關性
* **上下文更新**：為下一個推理迭代更新上下文
* **決策制定**：決定是繼續還是結束 ReAct 迴圈

### 領域專門化

```csharp
// 針對特定領域建立
var mathObservationNode = ObservationGraphNode.CreateForDomain(
    ObservationDomain.Mathematics,
    nodeId: "math_observation"
);

// 針對一般觀察建立
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

#### 範本引擎集成

```csharp
var templateEngine = new GraphTemplateEngine();
var observationNode = new ObservationGraphNode(
    "Result: {{action_result}}\n" +
    "Expected: {{expected_result}}\n" +
    "Analysis: {{analysis_request}}",
    templateEngine: templateEngine
);
```

### 中繼資料鍵

#### 計數器 (int)
* `"ExecutionCount"`：執行總次數
* `"FailureCount"`：失敗執行次數
* `"GoalAchievedCount"`：目標達成的次數

#### 指標
* `"AverageExecutionTime"`：每次執行的平均時間
* `"GoalAchievementRate"`：目標達成率
* `"AverageSuccessAssessment"`：平均成功評估分數
* `"LastExecutedAt"`：上次執行的時間戳

#### 配置
* `"Domain"`：領域特定配置
* `"DeepAnalysisEnabled"`：是否執行深度分析
* `"GoalAchievementThreshold"`：目標達成閾值

#### 行為自訂
* `"ExtractionPatterns"`：資訊提取的模式
* `"ResultTypePatterns"`：結果類型分析的模式
* `"GoalCriteria"`：目標評估的標準

## 集成模式

### 建構完整的 ReAct 工作流程

```csharp
// 1. 建立元件節點
var reasoningNode = new ReasoningGraphNode(
    "Analyze the problem: {{problem}}\nPlan the solution:",
    name: "Problem Analysis"
);

var actionNode = new ActionGraphNode(kernel, "action_execution");

var observationNode = new ObservationGraphNode(
    "Analyze result: {{action_result}}\nGoal achieved?",
    name: "Result Analysis"
);

// 2. 建立並配置 ReAct 迴圈
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

// 4. 新增到執行器並設置起始節點（使用節點 id）
executor.AddNode(reactLoopNode);
executor.SetStartNode(reactLoopNode.NodeId);
```

### 使用函式節點進行條件路由

```csharp
// 建立函式節點
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

## 效能考量

### 快取和最佳化

* **條件節點**：為複雜邏輯使用基於範本的條件以利用快取
* **函式節點**：僅在需要時啟用結果儲存，以避免記憶體開銷
* **ReAct 迴圈**：設定適當的迭代限制和超時以防止無限迴圈

### 記憶體管理

* **中繼資料**：謹慎使用中繼資料進行配置；避免儲存大型物件
* **狀態**：利用 `StoreResultAs` 儲存重要結果，而不是儲存所有內容
* **連接**：最小化條件邊的數量以獲得更好的效能

### 監視和除錯

* **指標**：為效能關鍵節點啟用指標追蹤
* **日誌**：使用內建日誌功能進行複雜工作流程的除錯
* **驗證**：實現適當的驗證以盡早發現問題

## 相關類型

* **IGraphNode**：所有圖形節點的基礎介面
* **GraphState**：KernelArguments 的封裝，包含執行中繼資料
* **ConditionalEdge**：定義節點之間的條件轉換
* **ActionGraphNode**：用於執行行動的專門節點
* **GraphExecutor**：協調圖形工作流程的執行

## 相關資訊

* [節點類型](../concepts/node-types.md) - 可用節點實現的綜合概述
* [執行模型](../concepts/execution-model.md) - 節點如何參與執行
* [ReAct 模式](../patterns/react.md) - 瞭解 ReAct 推理模式
* [條件節點](../how-to/conditional-nodes.md) - 建構條件工作流程
* [快速入門](../getting-started.md) - 建構您的第一個圖形
