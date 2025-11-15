# 節點類型

本指南涵蓋了 SemanticKernel.Graph 中所有可用的節點類型，說明它們的用途、功能以及如何在工作流程中有效地使用它們。

## 概述

節點是 SemanticKernel.Graph 中圖的基本構建塊。每種節點類型都有特定的用途，可以配置和連接以創建複雜的工作流程。了解不同的節點類型可以幫助您為用例選擇合適的組件。

## 核心節點類型

### FunctionGraphNode

`FunctionGraphNode` 封裝了 Semantic Kernel 函數，並在現有的 `ISKFunction` 實例周圍提供了圖特定的功能。

**主要特性：**
* **函數封裝**：用圖感知行為包裝任何 `KernelFunction`
* **導航控制**：連接到無條件後繼或條件轉移
* **元數據鉤子**：自定義設置、清理和錯誤處理邏輯
* **結果存儲**：自動將執行結果存儲在圖狀態中

**使用示例：**
```csharp
// 從核心插件創建函數節點
var mathNode = FunctionGraphNode.FromPlugin(kernel, "math", "add")
    .StoreResultAs("sum_result");

// 從自定義函數創建函數節點
var customFunction = KernelFunctionFactory.CreateFromMethod(
    (string input) => $"Processed: {input}",
    "ProcessInput",
    "Processes input text"
);

var processNode = new FunctionGraphNode(customFunction, "process_input")
    .StoreResultAs("processed_result");

// 連接節點
mathNode.ConnectTo(processNode);
```

**元數據鍵：**
* `"StoreResultAs"` (字符串)：將最後的結果存儲到 `GraphState` 中使用給定的鍵
* `"BeforeExecute"` (Action/Func)：在 `OnBeforeExecuteAsync` 中執行的自定義設置邏輯
* `"AfterExecute"` (Action/Func)：在 `OnAfterExecuteAsync` 中執行的自定義清理邏輯
* `"OnExecutionFailed"` (Action/Func)：在 `OnExecutionFailedAsync` 中執行的錯誤處理鉤子
* `"StrictValidation"` (bool)：如果為 true，執行前驗證失敗會導致異常

### ConditionalGraphNode

`ConditionalGraphNode` 實現了基於圖狀態的條件 if/else 邏輯，無需執行函數即可實現動態路由。

**主要特性：**
* **基於函數的條件**：使用 `Func<GraphState, bool>` 直接評估
* **基於模板的條件**：類似 Handlebars 的模板，支持變量替換
* **高級緩存**：自動緩存評估結果以提高性能
* **調試支持**：與 `ConditionalDebugger` 集成，用於逐步分析
* **指標跟踪**：全面的執行指標和性能監控

**使用示例：**
```csharp
// 基於函數的條件
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

// 基於模板的條件
var templateCondition = new ConditionalGraphNode(
    "{{user_age}} >= 18 && {{user_premium}} == true",
    nodeId: "template_discount_check",
    name: "TemplateDiscountCheck"
);

// 配置條件路徑
discountCondition
    .AddTrueNode(discountNode)   // 如果條件為真則執行
    .AddFalseNode(noDiscountNode); // 如果條件為假則執行
```

**元數據鍵：**
* `"ExecutionCount"`、`"FailureCount"`：聚合計數器 (int)
* `"AverageExecutionTime"`、`"LastExecutedAt"`：指標
* `"ConditionTemplate"`：基於模板條件的模板字符串
* `"CacheEnabled"`、`"CacheTimeout"`：緩存配置

### SwitchGraphNode

`SwitchGraphNode` 提供類似於 switch 語句的多路分支邏輯，具有多個案例和相關的節點。

**主要特性：**
* **多個案例**：每個案例都有其自己的條件和相關的節點
* **模板支持**：案例條件的 Handlebars 模板
* **案例管理**：動態添加、刪除和配置案例
* **默認案例**：用於未匹配條件的可選默認案例

**使用示例：**
```csharp
var switchNode = new SwitchGraphNode("user_type_switch", "Routes users based on their type");

// 使用基於函數的條件添加案例
switchNode.AddCase(new SwitchCase("premium", state => 
    state.GetValue<bool>("is_premium") && state.GetValue<int>("account_age") > 365));

// 使用基於模板的條件添加案例
switchNode.AddCase(new SwitchCase("new_user", "{{account_age}} <= 30"));

// 添加具有關聯節點的案例
var premiumCase = switchNode.GetCase("premium");
premiumCase.AddNode(premiumFeaturesNode);

var newUserCase = switchNode.GetCase("new_user");
newUserCase.AddNode(onboardingNode);

// 設置默認案例
switchNode.SetDefaultCase(defaultCase);
```

**SwitchCase 屬性：**
* `CaseId`：案例的唯一標識符
* `Name`：人類可讀的名稱
* `Condition`：評估案例條件的函數
* `ConditionTemplate`：Handlebars 模板（如果提供）
* `Nodes`：與此案例相關的節點列表
* `CreatedAt`：創建案例的時間戳

## ReAct 模式節點

### ReasoningGraphNode

`ReasoningGraphNode` 實現了分析當前情況和計劃下一步操作的推理功能，設計用作 ReAct 模式的一部分。

**主要特性：**
* **上下文感知推理**：分析當前情況和可用數據
* **基於模板的提示**：使用可自定義的模板應用於不同的推理模式
* **質量指標**：跟踪推理質量和一致性
* **域專業化**：可以針對特定問題域進行配置
* **思維鏈支持**：支持逐步推理模式

**使用示例：**
```csharp
// 使用自定義提示創建推理節點
var reasoningNode = new ReasoningGraphNode(
    "Analyze the current situation: {{context}}. " +
    "Based on available actions: {{available_actions}}, " +
    "what should be done next?",
    nodeId: "analyze_situation",
    name: "Situation Analysis"
);

// 創建域特定的推理節點
var mathReasoning = ReasoningGraphNode.CreateForDomain(
    ReasoningDomain.Mathematics,
    nodeId: "math_reasoning"
);

// 配置推理行為
reasoningNode.SetMetadata("ChainOfThoughtEnabled", true);
reasoningNode.SetMetadata("MaxReasoningSteps", 5);
reasoningNode.SetMetadata("ConfidenceThreshold", 0.8);
```

**元數據鍵：**
* `"ExecutionCount"`、`"FailureCount"`：聚合計數器 (int)
* `"AverageExecutionTime"`、`"AverageConfidenceScore"`、`"LastExecutedAt"`：指標
* `"Domain"`、`"ChainOfThoughtEnabled"`、`"MaxReasoningSteps"`、`"ConfidenceThreshold"`：配置

### ActionGraphNode

`ActionGraphNode` 對 ReAct 風格的工作流程執行操作選擇和執行，根據推理輸出和上下文選擇要調用的函數。

**主要特性：**
* **操作選擇**：直接、智能（上下文/推理感知）或隨機策略
* **安全執行**：有時間限制的執行，支持重試和取消
* **參數映射**：可選地將圖參數映射到函數參數
* **可觀測性**：每個操作的成功/失敗計數、平均延遲、最後執行時間
* **動態路由**：由邊界謂詞和成功/失敗結果驅動的下一個節點選擇

**使用示例：**
```csharp
// 使用自動發現的操作創建操作節點
var actions = ActionGraphNode.CreateWithActions(
    kernel,
    new ActionSelectionCriteria
    {
        // 默認保持打開；可以通過 IncludedPlugins/FunctionNamePattern 限制
    },
    "react_act"
);

// 配置執行策略
actions.ConfigureExecution(
    ActionSelectionStrategy.Intelligent, 
    enableParameterValidation: true
);

// 添加自定義操作
actions.AddAction("custom_action", customFunction);

// 配置參數映射
actions.ConfigureParameterMapping("custom_action", args =>
{
    var mappedArgs = new KernelArguments();
    mappedArgs["input"] = args.GetValue<string>("user_input");
    mappedArgs["context"] = args.GetValue<string>("context");
    return mappedArgs;
});
```

**元數據鍵：**
* `"ExecutionCount"`、`"FailureCount"`：聚合計數器 (int)
* `"SuccessfulActionCounts"`、`"FailedActionCounts"`：每個操作計數器 (Dictionary<string,int>)
* `"AverageExecutionTime"`、`"TotalExecutionTime"`、`"LastExecutedAt"`：計時
* `"SelectionStrategy"`、`"ParameterValidationEnabled"`、`"MaxExecutionTime"`、`"EnableRetryOnFailure"`、`"MaxRetries"`：配置

### ObservationGraphNode

`ObservationGraphNode` 分析操作結果、提取見解，並確定是否已實現 ReAct 模式的目標。

**主要特性：**
* **結果分析**：對操作執行結果進行深入分析
* **目標評估**：確定目標是否已滿足
* **信息提取**：從結果中提取關鍵見解和數據
* **質量評估**：評估結果的質量和相關性
* **上下文更新**：為下一個推理迭代更新上下文
* **決策制定**：確定是否繼續或結束 ReAct 循環

**使用示例：**
```csharp
// 使用自定義提示創建觀察節點
var observationNode = new ObservationGraphNode(
    "Analyze the result: {{action_result}}. " +
    "Has the goal been achieved? Extract key insights.",
    nodeId: "analyze_results",
    name: "Result Analysis"
);

// 創建域特定的觀察節點
var mathObservation = ObservationGraphNode.CreateForDomain(
    ObservationDomain.Mathematics,
    nodeId: "math_observation"
);

// 配置觀察行為
observationNode.SetMetadata("DeepAnalysisEnabled", true);
observationNode.SetMetadata("GoalAchievementThreshold", 0.9);
observationNode.SetMetadata("ExtractionPatterns", new[] { "result", "insight", "next_step" });
```

**元數據鍵：**
* `"ExecutionCount"`、`"FailureCount"`、`"GoalAchievedCount"`：聚合計數器 (int)
* `"AverageExecutionTime"`、`"GoalAchievementRate"`、`"AverageSuccessAssessment"`、`"LastExecutedAt"`：指標
* `"Domain"`、`"DeepAnalysisEnabled"`、`"GoalAchievementThreshold"`：配置
* `"ExtractionPatterns"`、`"ResultTypePatterns"`、`"GoalCriteria"`：行為自定義

### ReActLoopGraphNode

`ReActLoopGraphNode` 協調完整的 ReAct（推理 + 操作）模式循環，在迭代周期中協調推理、操作執行和觀察，直到實現目標。

**主要特性：**
* **完整的 ReAct 協調**：管理完整的推理-操作-觀察循環
* **靈活的節點組合**：可以使用自定義推理、操作和觀察節點
* **迭代限制**：可配置的最大迭代次數，支持提前終止
* **目標評估**：複雜的目標實現檢測
* **性能跟踪**：全面的指標和計時信息
* **錯誤處理**：具有恢復策略的穩健錯誤處理
* **上下文管理**：在迭代間維護和更新上下文

**使用示例：**
```csharp
// 創建 ReAct 循環節點
var reactNode = new ReActLoopGraphNode(
    nodeId: "react_loop",
    name: "ReAct Problem Solver",
    description: "Solves problems using reasoning, action, and observation cycles"
);

// 配置組件節點
reactNode.ConfigureNodes(
    reasoningNode,    // 分析和計劃
    actionNode,       // 執行操作
    observationNode   // 觀察結果
);

// 配置循環行為
reactNode.SetMetadata("MaxIterations", 10);
reactNode.SetMetadata("GoalAchievementThreshold", 0.95);
reactNode.SetMetadata("EarlyTerminationEnabled", true);
reactNode.SetMetadata("IterationTimeout", TimeSpan.FromMinutes(5));

// 連接到循環完成後的下一個節點
reactNode.ConnectTo(finalResultNode);
```

**元數據鍵：**
* `"ExecutionCount"`、`"FailureCount"`、`"SuccessfulCompletions"`、`"TotalIterations"`：聚合計數器 (int)
* `"AverageExecutionTime"`、`"AverageIterationsPerExecution"`、`"SuccessRate"`、`"LastExecutedAt"`：指標
* `"MaxIterations"`、`"GoalAchievementThreshold"`、`"EarlyTerminationEnabled"`、`"IterationTimeout"`、`"TotalTimeout"`、`"Domain"`：配置

## 循環控制節點

### WhileLoopGraphNode

`WhileLoopGraphNode` 實現了具有可配置條件和迭代限制的 while 循環語義。

**主要特性：**
* **基於條件的循環**：當條件評估為真時繼續
* **迭代限制**：可配置的最大迭代次數，防止無限循環
* **狀態管理**：在迭代間維護循環狀態
* **提前終止**：支持提前跳出循環
* **性能跟踪**：監控循環性能和效率

**使用示例：**
```csharp
var whileLoop = new WhileLoopGraphNode(
    state => state.GetValue<int>("counter") < 100,
    nodeId: "counter_loop",
    name: "Counter Loop"
);

// 配置循環行為
whileLoop.SetMetadata("MaxIterations", 1000);
whileLoop.SetMetadata("IterationTimeout", TimeSpan.FromMinutes(10));

// 添加循環體節點
whileLoop.AddLoopBodyNode(incrementNode);
whileLoop.AddLoopBodyNode(processNode);

// 設置循環退出條件
whileLoop.SetExitCondition(state => 
    state.GetValue<bool>("should_exit") || 
    state.GetValue<int>("counter") >= 100);
```

### ForeachLoopGraphNode

`ForeachLoopGraphNode` 遍歷集合，為每個項目執行節點。

**主要特性：**
* **集合迭代**：處理集合中的每個項目
* **並行執行**：可選的集合項目並行處理
* **狀態隔離**：每個迭代都有其自己的狀態上下文
* **進度跟踪**：監控迭代進度和完成
* **錯誤處理**：可配置的個別迭代錯誤處理

**使用示例：**
```csharp
var foreachLoop = new ForeachLoopGraphNode(
    state => state.GetValue<List<string>>("items"),
    nodeId: "process_items",
    name: "Process Items Loop"
);

// 配置循環行為
foreachLoop.SetMetadata("MaxConcurrency", 5);
foreachLoop.SetMetadata("ContinueOnError", true);

// 添加循環體節點
foreachLoop.AddLoopBodyNode(processItemNode);
foreachLoop.AddLoopBodyNode(validateItemNode);

// 設置項目處理邏輯
foreachLoop.ConfigureItemProcessing(
    itemKey: "current_item",
    resultKey: "processed_result"
);
```

## 專門節點

### HumanApprovalGraphNode

`HumanApprovalGraphNode` 暫停執行以獲得人工批准，實現人工在環工作流程。

**主要特性：**
* **人類交互**：暫停執行直到收到人工批准
* **多個渠道**：控制台、Web API 和自定義交互渠道
* **超時支持**：可配置的批准請求超時
* **審計跟蹤**：跟踪批准決定和時間戳
* **條件路由**：基於批准決定的路由執行

**使用示例：**
```csharp
var approvalNode = new HumanApprovalGraphNode(
    "approval_required",
    "Requires human approval to proceed",
    nodeId: "human_approval"
);

// 配置批准行為
approvalNode.SetMetadata("ApprovalTimeout", TimeSpan.FromHours(24));
approvalNode.SetMetadata("RequireJustification", true);
approvalNode.SetMetadata("ApprovalThreshold", 1); // 所需的批准數量

// 設置批准渠道
approvalNode.AddChannel(new ConsoleHumanInteractionChannel());
approvalNode.AddChannel(new WebApiHumanInteractionChannel("https://api.example.com/approvals"));

// 根據批准結果配置路由
approvalNode.AddApprovedNode(approvedProcessNode);
approvalNode.AddRejectedNode(rejectedProcessNode);
```

### ConfidenceGateGraphNode

`ConfidenceGateGraphNode` 基於信心分數路由執行，實現基於質量的決策制定。

**主要特性：**
* **信心評估**：基於之前節點的信心分數路由
* **可配置的閾值**：為不同的路徑設置最小信心級別
* **質量指標**：跟踪信心分佈和質量趨勢
* **備用路徑**：當信心不足時路由到備用節點
* **動態閾值**：基於上下文的可調整閾值

**使用示例：**
```csharp
var confidenceGate = new ConfidenceGateGraphNode(
    nodeId: "quality_gate",
    name: "Quality Confidence Gate"
);

// 配置信心閾值
confidenceGate.SetMetadata("HighConfidenceThreshold", 0.9);
confidenceGate.SetMetadata("MediumConfidenceThreshold", 0.7);
confidenceGate.SetMetadata("LowConfidenceThreshold", 0.5);

// 設置路由路徑
confidenceGate.AddHighConfidenceNode(highQualityProcessNode);
confidenceGate.AddMediumConfidenceNode(mediumQualityProcessNode);
confidenceGate.AddLowConfidenceNode(lowQualityProcessNode);
confidenceGate.AddInsufficientConfidenceNode(fallbackNode);

// 配置信心來源
confidenceGate.SetConfidenceSource(state => 
    state.GetValue<double>("confidence_score"));
```

### ErrorHandlerGraphNode

`ErrorHandlerGraphNode` 為圖執行提供集中式錯誤處理和恢復。

**主要特性：**
* **錯誤分類**：按類型和嚴重程度對錯誤進行分類
* **恢復策略**：實現重試、回滾和補償邏輯
* **錯誤指標**：跟踪錯誤模式和恢復成功率
* **上下文保留**：在錯誤處理期間維護執行上下文
* **備用機制**：錯誤時路由到替代執行路徑

**使用示例：**
```csharp
var errorHandler = new ErrorHandlerGraphNode(
    nodeId: "error_handler",
    name: "Centralized Error Handler"
);

// 配置錯誤處理策略
errorHandler.SetMetadata("MaxRetries", 3);
errorHandler.SetMetadata("RetryDelay", TimeSpan.FromSeconds(5));
errorHandler.SetMetadata("EnableCircuitBreaker", true);

// 添加錯誤處理策略
errorHandler.AddRetryStrategy(RetryStrategy.ExponentialBackoff);
errorHandler.AddRollbackStrategy(RollbackStrategy.PartialState);

// 設置錯誤路由
errorHandler.AddErrorRoute(ErrorType.Transient, retryNode);
errorHandler.AddErrorRoute(ErrorType.Permanent, fallbackNode);
errorHandler.AddErrorRoute(ErrorType.Critical, emergencyNode);
```

## 實用程序節點

### SubgraphGraphNode

`SubgraphGraphNode` 允許您在另一個圖中嵌入一個圖，實現模塊化圖組合。

**主要特性：**
* **圖組合**：將完整的圖嵌入為節點
* **狀態隔離**：為子圖維護單獨的狀態上下文
* **參數傳遞**：在父圖和子圖之間傳遞參數
* **結果聚合**：收集和處理子圖結果
* **錯誤傳播**：處理子圖執行中的錯誤

**使用示例：**
```csharp
var subgraphNode = new SubgraphGraphNode(
    childGraph,
    nodeId: "data_processing",
    name: "Data Processing Subgraph"
);

// 配置參數映射
subgraphNode.SetInputMapping("input_data", "raw_data");
subgraphNode.SetInputMapping("processing_config", "config");

// 配置結果映射
subgraphNode.SetOutputMapping("processed_result", "final_result");
subgraphNode.SetOutputMapping("processing_metrics", "metrics");

// 設置執行選項
subgraphNode.SetMetadata("IsolationLevel", "Full");
subgraphNode.SetMetadata("Timeout", TimeSpan.FromMinutes(30));
```

### PythonGraphNode

`PythonGraphNode` 啟用與 Python 代碼的集成，允許您利用 Python 庫和腳本。

**主要特性：**
* **Python 集成**：執行 Python 腳本和函數
* **環境管理**：管理 Python 虛擬環境
* **參數傳遞**：在 C# 和 Python 之間傳遞數據
* **結果處理**：處理 Python 執行結果
* **錯誤處理**：管理 Python 執行錯誤

**使用示例：**
```csharp
var pythonNode = new PythonGraphNode(
    "process_data.py",
    nodeId: "python_processor",
    name: "Python Data Processor"
);

// 配置 Python 環境
pythonNode.SetMetadata("PythonPath", "/usr/bin/python3");
pythonNode.SetMetadata("VirtualEnv", "data_processing_env");
pythonNode.SetMetadata("WorkingDirectory", "/scripts");

// 設置輸入/輸出參數
pythonNode.SetInputParameter("input_file", "data.csv");
pythonNode.SetOutputParameter("result_file", "processed_data.csv");
pythonNode.SetOutputParameter("metrics", "processing_metrics.json");
```

## 最佳實踐

### 節點選擇

* **選擇正確的類型**：選擇與工作流程要求相匹配的節點類型
* **組合優於複雜性**：使用簡單節點的組合而不是複雜的單一節點
* **重用模式**：利用現有節點類型實現常見模式，如 ReAct 循環
* **自定義節點**：僅當現有類型無法滿足需求時才創建自定義節點

### 配置

* **元數據管理**：使用元數據配置節點行為和跟踪指標
* **參數映射**：為節點之間的無縫數據流配置參數映射
* **錯誤處理**：為每種節點類型實現適當的錯誤處理策略
* **性能監控**：啟用指標收集以監控節點性能

### 集成

* **狀態管理**：確保不同節點類型之間的適當狀態流
* **邊界配置**：使用條件邊界基於節點結果創建動態路由
* **中間件**：利用中間件解決所有節點類型的橫切問題
* **測試**：測試個別節點及其組合以確保適當的集成

## 另請參閱

* [圖概念](graph-concepts.md) - 基本的圖概念和組件
* [執行模型](execution-model.md) - 節點如何被執行和管理
* [狀態管理](state.md) - 數據如何在節點之間流動
* [路由策略](routing.md) - 如何在節點之間連接和路由
* [示例](../examples/) - 節點使用模式的實際示例
