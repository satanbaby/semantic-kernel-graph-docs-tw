# Node 型別

本指南涵蓋 SemanticKernel.Graph 中所有可用的 Node 型別，說明其用途、功能以及如何在您的工作流程中有效使用它們。

## 概述

Node 是 SemanticKernel.Graph 中圖表的基本建構塊。每種 Node 型別服務於特定目的，可以被設定和連接以建立複雜的工作流程。理解不同的 Node 型別有助於您選擇適合您用例的正確元件。

## 核心 Node 型別

### FunctionGraphNode

`FunctionGraphNode` 封裝了語意內核函式，並圍繞現有的 `ISKFunction` 實例提供圖表特定的功能。

**主要功能：**
* **函式封裝**：使用圖表感知行為包裝任何 `KernelFunction`
* **導航控制**：連接到無條件的後繼者或條件轉換
* **中繼資料勾點**：自訂設定、清理和錯誤處理邏輯
* **結果儲存**：自動將執行結果儲存在圖表狀態中

**使用範例：**
```csharp
// Create a function node from a kernel plugin
var mathNode = FunctionGraphNode.FromPlugin(kernel, "math", "add")
    .StoreResultAs("sum_result");

// Create a function node from a custom function
var customFunction = KernelFunctionFactory.CreateFromMethod(
    (string input) => $"Processed: {input}",
    "ProcessInput",
    "Processes input text"
);

var processNode = new FunctionGraphNode(customFunction, "process_input")
    .StoreResultAs("processed_result");

// Connect nodes
mathNode.ConnectTo(processNode);
```

**中繼資料鍵：**
* `"StoreResultAs"` (string)：將最後結果儲存到 `GraphState` 中給定的鍵下
* `"BeforeExecute"` (Action/Func)：在 `OnBeforeExecuteAsync` 中執行的自訂設定邏輯
* `"AfterExecute"` (Action/Func)：在 `OnAfterExecuteAsync` 中執行的自訂清理邏輯
* `"OnExecutionFailed"` (Action/Func)：在 `OnExecutionFailedAsync` 中執行的錯誤處理勾點
* `"StrictValidation"` (bool)：如果為 true，執行前驗證失敗將導致異常

### ConditionalGraphNode

`ConditionalGraphNode` 根據圖表狀態實現條件 if/else 邏輯，實現動態路由而不執行函式。

**主要功能：**
* **基於函式的條件**：使用 `Func<GraphState, bool>` 進行直接評估
* **基於範本的條件**：具有變數替換的類 Handlebars 範本
* **進階快取**：自動快取評估結果以提高效能
* **偵錯支援**：與 `ConditionalDebugger` 整合以進行逐步分析
* **指標追蹤**：綜合執行指標和效能監控

**使用範例：**
```csharp
// Function-based condition
var discountCondition = new ConditionalGraphNode(
    state =>
    {
        var age = state.GetValue<int>("user_age");
        var isPremium = state.GetValue<bool>("user_premium");
        return age >= 18 && isPremium;
    },
    nodeId: "discount_check",
    name: "DiscountEligibilityCheck"
);

// Template-based condition
var templateCondition = new ConditionalGraphNode(
    "{{user_age}} >= 18 && {{user_premium}} == true",
    nodeId: "template_discount_check",
    name: "TemplateDiscountCheck"
);

// Configure conditional paths
discountCondition
    .AddTrueNode(discountNode)   // Execute if condition is true
    .AddFalseNode(noDiscountNode); // Execute if condition is false
```

**中繼資料鍵：**
* `"ExecutionCount"`、`"FailureCount"`：彙總計數器 (int)
* `"AverageExecutionTime"`、`"LastExecutedAt"`：指標
* `"ConditionTemplate"`：基於範本的條件的範本字串
* `"CacheEnabled"`、`"CacheTimeout"`：快取設定

### SwitchGraphNode

`SwitchGraphNode` 提供類似於 switch 陳述式的多向分支邏輯，具有多個案例和相關的 Node。

**主要功能：**
* **多個案例**：每個案例都有自己的條件和相關的 Node
* **範本支援**：用於案例條件的 Handlebars 範本
* **案例管理**：動態新增、移除和設定案例
* **預設案例**：針對不符合條件的可選預設案例

**使用範例：**
```csharp
var switchNode = new SwitchGraphNode("user_type_switch", "Routes users based on their type");

// Add cases with function-based conditions
switchNode.AddCase(new SwitchCase("premium", state => 
    state.GetValue<bool>("is_premium") && state.GetValue<int>("account_age") > 365));

// Add cases with template-based conditions
switchNode.AddCase(new SwitchCase("new_user", "{{account_age}} <= 30"));

// Add cases with associated nodes
var premiumCase = switchNode.GetCase("premium");
premiumCase.AddNode(premiumFeaturesNode);

var newUserCase = switchNode.GetCase("new_user");
newUserCase.AddNode(onboardingNode);

// Set default case
switchNode.SetDefaultCase(defaultCase);
```

**SwitchCase 屬性：**
* `CaseId`：案例的唯一識別碼
* `Name`：易讀的名稱
* `Condition`：評估案例條件的函式
* `ConditionTemplate`：Handlebars 範本 (如提供)
* `Nodes`：與此案例相關的 Node 清單
* `CreatedAt`：建立案例時的時間戳

## ReAct 模式 Node

### ReasoningGraphNode

`ReasoningGraphNode` 實現分析當前情況和規劃下一步行動的推理功能，設計為用作 ReAct 模式的一部分。

**主要功能：**
* **情境感知推理**：分析當前情況和可用資料
* **基於範本的提示**：針對不同的推理模式使用可自訂的範本
* **品質指標**：追蹤推理品質和一致性
* **領域特殊化**：可為特定問題領域配置
* **思維鏈支援**：支援逐步推理模式

**使用範例：**
```csharp
// Create reasoning node with custom prompt
var reasoningNode = new ReasoningGraphNode(
    "Analyze the current situation: {{context}}. " +
    "Based on available actions: {{available_actions}}, " +
    "what should be done next?",
    nodeId: "analyze_situation",
    name: "Situation Analysis"
);

// Create domain-specific reasoning node
var mathReasoning = ReasoningGraphNode.CreateForDomain(
    ReasoningDomain.Mathematics,
    nodeId: "math_reasoning"
);

// Configure reasoning behavior
reasoningNode.SetMetadata("ChainOfThoughtEnabled", true);
reasoningNode.SetMetadata("MaxReasoningSteps", 5);
reasoningNode.SetMetadata("ConfidenceThreshold", 0.8);
```

**中繼資料鍵：**
* `"ExecutionCount"`、`"FailureCount"`：彙總計數器 (int)
* `"AverageExecutionTime"`、`"AverageConfidenceScore"`、`"LastExecutedAt"`：指標
* `"Domain"`、`"ChainOfThoughtEnabled"`、`"MaxReasoningSteps"`、`"ConfidenceThreshold"`：設定

### ActionGraphNode

`ActionGraphNode` 執行 ReAct 風格工作流程的行動選擇和執行，根據推理輸出和情境選擇要叫用的函式。

**主要功能：**
* **行動選擇**：直接、智慧 (情境/推理感知) 或隨機策略
* **安全執行**：時間限制執行，具有重試和取消支援
* **參數對應**：從圖表引數到函式參數的選擇性對應
* **可觀測性**：每個行動的成功/失敗計數、平均延遲、最後執行時間
* **動態路由**：由 Edge 述詞和成功/失敗結果驅動的下一 Node 選擇

**使用範例：**
```csharp
// Create action node with auto-discovered actions
var actions = ActionGraphNode.CreateWithActions(
    kernel,
    new ActionSelectionCriteria
    {
        // Keep open by default; can be restricted via IncludedPlugins/FunctionNamePattern
    },
    "react_act"
);

// Configure execution strategy
actions.ConfigureExecution(
    ActionSelectionStrategy.Intelligent, 
    enableParameterValidation: true
);

// Add custom actions
actions.AddAction("custom_action", customFunction);

// Configure parameter mapping
actions.ConfigureParameterMapping("custom_action", args =>
{
    var mappedArgs = new KernelArguments();
    mappedArgs["input"] = args.GetValue<string>("user_input");
    mappedArgs["context"] = args.GetValue<string>("context");
    return mappedArgs;
});
```

**中繼資料鍵：**
* `"ExecutionCount"`、`"FailureCount"`：彙總計數器 (int)
* `"SuccessfulActionCounts"`、`"FailedActionCounts"`：每個行動的計數器 (Dictionary<string,int>)
* `"AverageExecutionTime"`、`"TotalExecutionTime"`、`"LastExecutedAt"`：計時
* `"SelectionStrategy"`、`"ParameterValidationEnabled"`、`"MaxExecutionTime"`、`"EnableRetryOnFailure"`、`"MaxRetries"`：設定

### ObservationGraphNode

`ObservationGraphNode` 分析行動結果、提取見解，並確定是否實現了 ReAct 模式的目標。

**主要功能：**
* **結果分析**：對行動執行結果進行深入分析
* **目標評估**：確定目標是否已達成
* **資訊提取**：從結果中提取關鍵見解和資料
* **品質評估**：評估結果的品質和相關性
* **情境更新**：為下一推理迭代更新情境
* **決策制定**：確定是否繼續或結束 ReAct 迴圈

**使用範例：**
```csharp
// Create observation node with custom prompt
var observationNode = new ObservationGraphNode(
    "Analyze the result: {{action_result}}. " +
    "Has the goal been achieved? Extract key insights.",
    nodeId: "analyze_results",
    name: "Result Analysis"
);

// Create domain-specific observation node
var mathObservation = ObservationGraphNode.CreateForDomain(
    ObservationDomain.Mathematics,
    nodeId: "math_observation"
);

// Configure observation behavior
observationNode.SetMetadata("DeepAnalysisEnabled", true);
observationNode.SetMetadata("GoalAchievementThreshold", 0.9);
observationNode.SetMetadata("ExtractionPatterns", new[] { "result", "insight", "next_step" });
```

**中繼資料鍵：**
* `"ExecutionCount"`、`"FailureCount"`、`"GoalAchievedCount"`：彙總計數器 (int)
* `"AverageExecutionTime"`、`"GoalAchievementRate"`、`"AverageSuccessAssessment"`、`"LastExecutedAt"`：指標
* `"Domain"`、`"DeepAnalysisEnabled"`、`"GoalAchievementThreshold"`：設定
* `"ExtractionPatterns"`、`"ResultTypePatterns"`、`"GoalCriteria"`：行為自訂

### ReActLoopGraphNode

`ReActLoopGraphNode` 協調完整的 ReAct (推理 + 行動) 模式迴圈，協調推理、行動執行和觀察，在迭代週期中進行直到達成目標。

**主要功能：**
* **完整 ReAct 協調**：管理完整的推理-行動-觀察週期
* **彈性 Node 組成**：可以使用自訂推理、行動和觀察 Node
* **迭代限制**：可配置的最大迭代次數，具有早期終止
* **目標評估**：複雜的目標達成檢測
* **效能追蹤**：綜合指標和計時資訊
* **錯誤處理**：具有復原策略的強大錯誤處理
* **情境管理**：在迭代中維持和更新情境

**使用範例：**
```csharp
// Create ReAct loop node
var reactNode = new ReActLoopGraphNode(
    nodeId: "react_loop",
    name: "ReAct Problem Solver",
    description: "Solves problems using reasoning, action, and observation cycles"
);

// Configure component nodes
reactNode.ConfigureNodes(
    reasoningNode,    // Analyze and plan
    actionNode,       // Execute actions
    observationNode   // Observe results
);

// Configure loop behavior
reactNode.SetMetadata("MaxIterations", 10);
reactNode.SetMetadata("GoalAchievementThreshold", 0.95);
reactNode.SetMetadata("EarlyTerminationEnabled", true);
reactNode.SetMetadata("IterationTimeout", TimeSpan.FromMinutes(5));

// Connect to next nodes after loop completion
reactNode.ConnectTo(finalResultNode);
```

**中繼資料鍵：**
* `"ExecutionCount"`、`"FailureCount"`、`"SuccessfulCompletions"`、`"TotalIterations"`：彙總計數器 (int)
* `"AverageExecutionTime"`、`"AverageIterationsPerExecution"`、`"SuccessRate"`、`"LastExecutedAt"`：指標
* `"MaxIterations"`、`"GoalAchievementThreshold"`、`"EarlyTerminationEnabled"`、`"IterationTimeout"`、`"TotalTimeout"`、`"Domain"`：設定

## 迴圈控制 Node

### WhileLoopGraphNode

`WhileLoopGraphNode` 實現具有可配置條件和迭代限制的 while-迴圈語義。

**主要功能：**
* **基於條件的迴圈**：在條件評估為 true 時繼續
* **迭代限制**：可配置的最大迭代次數以防止無限迴圈
* **狀態管理**：在迭代中維持迴圈狀態
* **早期終止**：支援提早中斷迴圈
* **效能追蹤**：監控迴圈效能和效率

**使用範例：**
```csharp
var whileLoop = new WhileLoopGraphNode(
    state => state.GetValue<int>("counter") < 100,
    nodeId: "counter_loop",
    name: "Counter Loop"
);

// Configure loop behavior
whileLoop.SetMetadata("MaxIterations", 1000);
whileLoop.SetMetadata("IterationTimeout", TimeSpan.FromMinutes(10));

// Add loop body nodes
whileLoop.AddLoopBodyNode(incrementNode);
whileLoop.AddLoopBodyNode(processNode);

// Set loop exit condition
whileLoop.SetExitCondition(state => 
    state.GetValue<bool>("should_exit") || 
    state.GetValue<int>("counter") >= 100);
```

### ForeachLoopGraphNode

`ForeachLoopGraphNode` 迭代集合，為每個項目執行 Node。

**主要功能：**
* **集合迭代**：處理集合中的每個項目
* **並行執行**：可選的集合項目並行處理
* **狀態隔離**：每次迭代都有自己的狀態情境
* **進度追蹤**：監控迭代進度和完成情況
* **錯誤處理**：適用於單個迭代的可配置錯誤處理

**使用範例：**
```csharp
var foreachLoop = new ForeachLoopGraphNode(
    state => state.GetValue<List<string>>("items"),
    nodeId: "process_items",
    name: "Process Items Loop"
);

// Configure loop behavior
foreachLoop.SetMetadata("MaxConcurrency", 5);
foreachLoop.SetMetadata("ContinueOnError", true);

// Add loop body nodes
foreachLoop.AddLoopBodyNode(processItemNode);
foreachLoop.AddLoopBodyNode(validateItemNode);

// Set item processing logic
foreachLoop.ConfigureItemProcessing(
    itemKey: "current_item",
    resultKey: "processed_result"
);
```

## 專門 Node

### HumanApprovalGraphNode

`HumanApprovalGraphNode` 暫停執行以進行人工核准，實現人工在迴圈中的工作流程。

**主要功能：**
* **人工互動**：暫停執行直到收到人工核准
* **多個通道**：主控台、Web API 和自訂互動通道
* **逾時支援**：核准請求的可配置逾時
* **稽核軌跡**：追蹤核准決策和時間戳
* **條件路由**：根據核准決策路由執行

**使用範例：**
```csharp
var approvalNode = new HumanApprovalGraphNode(
    "approval_required",
    "Requires human approval to proceed",
    nodeId: "human_approval"
);

// Configure approval behavior
approvalNode.SetMetadata("ApprovalTimeout", TimeSpan.FromHours(24));
approvalNode.SetMetadata("RequireJustification", true);
approvalNode.SetMetadata("ApprovalThreshold", 1); // Number of approvals required

// Set approval channels
approvalNode.AddChannel(new ConsoleHumanInteractionChannel());
approvalNode.AddChannel(new WebApiHumanInteractionChannel("https://api.example.com/approvals"));

// Configure routing based on approval result
approvalNode.AddApprovedNode(approvedProcessNode);
approvalNode.AddRejectedNode(rejectedProcessNode);
```

### ConfidenceGateGraphNode

`ConfidenceGateGraphNode` 根據信心分數路由執行，實現基於品質的決策制定。

**主要功能：**
* **信心評估**：根據前面 Node 的信心分數進行路由
* **可配置的閾值**：為不同路徑設定最小信心級別
* **品質指標**：追蹤信心分佈和品質趨勢
* **備用路徑**：當信心不足時路由到備用 Node
* **動態閾值**：根據情境調整閾值

**使用範例：**
```csharp
var confidenceGate = new ConfidenceGateGraphNode(
    nodeId: "quality_gate",
    name: "Quality Confidence Gate"
);

// Configure confidence thresholds
confidenceGate.SetMetadata("HighConfidenceThreshold", 0.9);
confidenceGate.SetMetadata("MediumConfidenceThreshold", 0.7);
confidenceGate.SetMetadata("LowConfidenceThreshold", 0.5);

// Set routing paths
confidenceGate.AddHighConfidenceNode(highQualityProcessNode);
confidenceGate.AddMediumConfidenceNode(mediumQualityProcessNode);
confidenceGate.AddLowConfidenceNode(lowQualityProcessNode);
confidenceGate.AddInsufficientConfidenceNode(fallbackNode);

// Configure confidence source
confidenceGate.SetConfidenceSource(state => 
    state.GetValue<double>("confidence_score"));
```

### ErrorHandlerGraphNode

`ErrorHandlerGraphNode` 為圖表執行提供集中式錯誤處理和復原。

**主要功能：**
* **錯誤分類**：按類型和嚴重性對錯誤進行分類
* **復原策略**：實現重試、回滾和補償邏輯
* **錯誤指標**：追蹤錯誤模式和復原成功率
* **情境保留**：在錯誤處理期間維持執行情境
* **備用機制**：在發生錯誤時路由到替代執行路徑

**使用範例：**
```csharp
var errorHandler = new ErrorHandlerGraphNode(
    nodeId: "error_handler",
    name: "Centralized Error Handler"
);

// Configure error handling policies
errorHandler.SetMetadata("MaxRetries", 3);
errorHandler.SetMetadata("RetryDelay", TimeSpan.FromSeconds(5));
errorHandler.SetMetadata("EnableCircuitBreaker", true);

// Add error handling strategies
errorHandler.AddRetryStrategy(RetryStrategy.ExponentialBackoff);
errorHandler.AddRollbackStrategy(RollbackStrategy.PartialState);

// Set error routing
errorHandler.AddErrorRoute(ErrorType.Transient, retryNode);
errorHandler.AddErrorRoute(ErrorType.Permanent, fallbackNode);
errorHandler.AddErrorRoute(ErrorType.Critical, emergencyNode);
```

## 公用程式 Node

### SubgraphGraphNode

`SubgraphGraphNode` 允許您在另一個圖表中嵌入一個圖表，實現模組化圖表組成。

**主要功能：**
* **圖表組成**：將完整圖表嵌入為 Node
* **狀態隔離**：為子圖維持單獨的狀態情境
* **參數傳遞**：在父圖表和子圖表之間傳遞參數
* **結果彙總**：收集和處理子圖結果
* **錯誤傳播**：處理子圖執行的錯誤

**使用範例：**
```csharp
var subgraphNode = new SubgraphGraphNode(
    childGraph,
    nodeId: "data_processing",
    name: "Data Processing Subgraph"
);

// Configure parameter mapping
subgraphNode.SetInputMapping("input_data", "raw_data");
subgraphNode.SetInputMapping("processing_config", "config");

// Configure result mapping
subgraphNode.SetOutputMapping("processed_result", "final_result");
subgraphNode.SetOutputMapping("processing_metrics", "metrics");

// Set execution options
subgraphNode.SetMetadata("IsolationLevel", "Full");
subgraphNode.SetMetadata("Timeout", TimeSpan.FromMinutes(30));
```

### PythonGraphNode

`PythonGraphNode` 實現與 Python 程式碼的整合，允許您利用 Python 程式庫和指令碼。

**主要功能：**
* **Python 整合**：執行 Python 指令碼和函式
* **環境管理**：管理 Python 虛擬環境
* **參數傳遞**：在 C# 和 Python 之間傳遞資料
* **結果處理**：處理 Python 執行結果
* **錯誤處理**：管理 Python 執行錯誤

**使用範例：**
```csharp
var pythonNode = new PythonGraphNode(
    "process_data.py",
    nodeId: "python_processor",
    name: "Python Data Processor"
);

// Configure Python environment
pythonNode.SetMetadata("PythonPath", "/usr/bin/python3");
pythonNode.SetMetadata("VirtualEnv", "data_processing_env");
pythonNode.SetMetadata("WorkingDirectory", "/scripts");

// Set input/output parameters
pythonNode.SetInputParameter("input_file", "data.csv");
pythonNode.SetOutputParameter("result_file", "processed_data.csv");
pythonNode.SetOutputParameter("metrics", "processing_metrics.json");
```

## 最佳實踐

### Node 選擇

* **選擇正確的型別**：選擇與您的工作流程要求相符的 Node 型別
* **組成優於複雜性**：使用簡單 Node 組合而不是複雜的單體 Node
* **重用模式**：利用現有 Node 型別處理常見模式，例如 ReAct 迴圈
* **自訂 Node**：僅當現有型別不符合您的需求時才建立自訂 Node

### 設定

* **中繼資料管理**：使用中繼資料來設定 Node 行為和追蹤指標
* **參數對應**：設定參數對應以實現 Node 之間的無縫資料流程
* **錯誤處理**：為每種 Node 型別實現適當的錯誤處理策略
* **效能監控**：啟用指標收集以監控 Node 效能

### 整合

* **狀態管理**：確保不同 Node 型別之間的適當狀態流程
* **Edge 設定**：使用條件 Edge 根據 Node 結果建立動態路由
* **中介軟體**：利用中介軟體處理所有 Node 型別的跨領域關注點
* **測試**：測試各個 Node 及其組合，以確保適當的整合

## 另請參閱

* [Graph 概念](graph-concepts.md) - 基本圖表概念和元件
* [執行模型](execution-model.md) - Node 如何執行和管理
* [狀態管理](state.md) - 資料如何在 Node 之間流動
* [路由策略](routing.md) - 如何連接和路由 Node
* [範例](../examples/) - Node 使用模式的實務範例
