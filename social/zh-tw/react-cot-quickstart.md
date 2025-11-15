# ReAct 和思維鏈快速入門

學習如何在 SemanticKernel.Graph 中實現推理和行動模式，使用 ReAct（推理 + 行動）迴圈和思維鏈推理。本指南向您展示如何構建能夠思考、行動和從行動中學習的智能代理。

## 概念和技術

**ReAct 模式**：一個推理迴圈，其中代理分析當前情況（推理）、執行動作（行動）和觀察結果（觀察）在反覆迴圈中，直到達成目標。

**思維鏈**：一種結構化推理方法，將複雜問題分解為順序驗證的步驟，具有回溯功能以進行強大的問題解決。

**推理節點**：專門的節點，如 `FunctionGraphNode`（用於自訂推理邏輯）、`ReActLoopGraphNode`（用於內建 ReAct 迴圈）和 `ChainOfThoughtGraphNode`，它們實現不同的推理策略，並可組成複雜的推理工作流程。

## 先決條件和最小配置

* .NET 8.0 或更新版本
* 已安裝 SemanticKernel.Graph 套件
* 具有聊天完成功能的 Semantic Kernel
* 對圖形執行和節點組合的基本理解

## 快速設置

**重要**：在建立任何 ReAct 迴圈之前，請確保模擬動作已向核心註冊。這對於 `ActionGraphNode` 發現和執行函式是必需的。

### 1. 建立簡單的 ReAct 迴圈

使用三個核心元件構建基本推理迴圈：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;

// 建立推理節點
var reasoningNode = new FunctionGraphNode(
    CreateReasoningFunction(kernel),
    "reasoning",
    "Problem Analysis");

// 使用 CreateWithActions 建立行動執行節點以自動發現核心函式
var actionNode = ActionGraphNode.CreateWithActions(
    kernel,
    new ActionSelectionCriteria
    {
        MinRequiredParameters = 0,
        MaxRequiredParameters = 5
    },
    "action");
actionNode.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

// 建立觀察節點
var observationNode = new FunctionGraphNode(
    CreateObservationFunction(kernel),
    "observation",
    "Result Analysis");

// 配置節點以儲存結果供下遊使用
reasoningNode.StoreResultAs("reasoning_result");
// ActionGraphNode 自動將結果儲存為 "action_result"
observationNode.StoreResultAs("final_answer");

// 構建 ReAct 迴圈
var executor = new GraphExecutor("SimpleReAct", "Basic ReAct reasoning loop");
executor.AddNode(reasoningNode)
        .AddNode(actionNode)
        .AddNode(observationNode)
        .Connect("reasoning", "action")
        .Connect("action", "observation")
        .SetStartNode("reasoning");
```

### 2. 實現核心函式

建立推理、行動和觀察函式。首先，確保模擬動作已向核心註冊：

```csharp
private void AddMockActionsToKernel()
{
    // 檢查外掛程式是否已存在以避免重複
    if (kernel.Plugins.Any(p => p.Name == "react_actions"))
    {
        return;
    }

    // 將所有函式作為外掛程式匯入，以便 ActionGraphNode 可以發現它們
    kernel.ImportPluginFromFunctions("react_actions", "Mock actions for ReAct examples", new[]
    {
        // 天氣動作
        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var location = args.GetValueOrDefault("location", "unknown location");
                return $"The weather in {location} is sunny with 22°C temperature and light breeze.";
            },
            functionName: "get_weather",
            description: "Gets weather information for a specified location"
        ),
        // 計算器動作
        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var expression = args.GetValueOrDefault("expression", "0");
                return $"Calculation result for '{expression}': 42 (mock result)";
            },
            functionName: "calculate",
            description: "Performs mathematical calculations"
        ),
        // 搜尋動作
        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var query = args.GetValueOrDefault("query", "unknown query");
                return $"Search results for '{query}': Found 5 relevant articles about the topic.";
            },
            functionName: "search",
            description: "Searches for information on the internet"
        ),
        // 用於業務問題的通用動作
        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var problem = args.GetValueOrDefault("problem", "unknown problem");
                return $"Analysis of '{problem}': Identified 3 key areas for improvement with cost reduction potential.";
            },
            functionName: "analyze_problem",
            description: "Analyzes business problems and provides insights"
        ),
        // 解決方案評估動作
        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var solution = args.GetValueOrDefault("solution", "unknown solution");
                return $"Evaluation of '{solution}': Feasible solution with 85% success probability and moderate implementation complexity.";
            },
            functionName: "evaluate_solution",
            description: "Evaluates proposed solutions for feasibility and impact"
        )
    });
}
```

現在建立推理、行動和觀察函式：

```csharp
private static KernelFunction CreateReasoningFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var query = args["user_query"]?.ToString() ?? string.Empty;
            
            // 簡單推理邏輯
            var suggestedAction = query.ToLowerInvariant() switch
            {
                var q when q.Contains("weather") => "get_weather",
                var q when q.Contains("calculate") => "calculate",
                var q when q.Contains("search") => "search",
                _ => "search"
            };

            args["suggested_action"] = suggestedAction;
            args["reasoning_result"] = $"Selected action '{suggestedAction}' based on query analysis.";
            
            return $"Reasoning completed. Proposed action: {suggestedAction}";
        },
        functionName: "simple_reasoning",
        description: "Analyzes user query and suggests appropriate actions"
    );
}

private static KernelFunction CreateObservationFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var actionResult = args["action_result"]?.ToString() ?? "No result";
            var reasoningResult = args["reasoning_result"]?.ToString() ?? "No reasoning";
            
            var observation = $"Based on reasoning: {reasoningResult}\n" +
                            $"Action executed with result: {actionResult}\n" +
                            $"Task completed successfully.";
            
            args["final_answer"] = observation;
            return observation;
        },
        functionName: "simple_observation",
        description: "Analyzes action results and provides final answer"
    );
}
```

### 3. 執行 ReAct 迴圈

執行您的推理代理：

```csharp
var arguments = new KernelArguments
{
    ["user_query"] = "What's the weather like today?",
    ["max_steps"] = 3
};

var result = await executor.ExecuteAsync(kernel, arguments);
var answer = result.GetValue<string>() ?? "No answer produced";
Console.WriteLine($"🤖 Agent: {answer}");
```

## 具有自訂函式的進階 ReAct

### 使用 FunctionGraphNode 進行進階推理

對於不需要外部 LLM 呼叫的獨立範例，您可以使用自訂函式實現進階推理：

以下是進階推理和觀察函式的實作：

```csharp
using SemanticKernel.Graph.Nodes;

// 建立專門的推理、行動和觀察節點
// 使用 FunctionGraphNode 搭配自訂函式以避免 LLM 依賴
var reasoningNode = new FunctionGraphNode(
    CreateAdvancedReasoningFunction(kernel),
    "advanced_reasoning",
    "Advanced Problem Analysis");

var actionNode = ActionGraphNode.CreateWithActions(
    kernel,
    new ActionSelectionCriteria
    {
        MinRequiredParameters = 0,
        MaxRequiredParameters = 5
    },
    "advanced_action");
actionNode.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

var observationNode = new FunctionGraphNode(
    CreateAdvancedObservationFunction(kernel),
    "advanced_observation",
    "Advanced Result Analysis");

// 配置節點以儲存結果供下遊使用
reasoningNode.StoreResultAs("advanced_reasoning_result");
observationNode.StoreResultAs("advanced_final_answer");

// 通過按順序連接節點來構建進階 ReAct 迴圈
var executor = new GraphExecutor("AdvancedReAct", "Advanced ReAct reasoning agent");
executor.AddNode(reasoningNode)
        .AddNode(actionNode)
        .AddNode(observationNode)
        .Connect("advanced_reasoning", "advanced_action")
        .Connect("advanced_action", "advanced_observation")
        .SetStartNode("advanced_reasoning");
```

### 進階函式實作

以下是進階推理和觀察函式的實作：

```csharp
private static KernelFunction CreateAdvancedReasoningFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var problemTitle = args.GetValueOrDefault("problem_title", "Unknown Problem")?.ToString() ?? "Unknown Problem";
            var taskDescription = args.GetValueOrDefault("task_description", "No description provided")?.ToString() ?? "No description provided";
            
            // 業務問題的進階推理邏輯
            var suggestedAction = taskDescription.ToLowerInvariant() switch
            {
                var desc when desc.Contains("cost") && desc.Contains("reduce") => "analyze_problem",
                var desc when desc.Contains("budget") => "analyze_problem", 
                var desc when desc.Contains("performance") => "analyze_problem",
                var desc when desc.Contains("efficiency") => "analyze_problem",
                _ => "analyze_problem"
            };

            // 生成綜合推理結果
            var reasoning = $"Advanced Analysis of '{problemTitle}':\n" +
                          $"1. Problem Context: {taskDescription}\n" +
                          $"2. Strategic Assessment: This appears to be a {(taskDescription.Contains("cost") ? "cost optimization" : "operational improvement")} challenge.\n" +
                          $"3. Recommended Approach: Systematic analysis with stakeholder consideration.\n" +
                          $"4. Next Action: {suggestedAction} - Deep dive into root causes and impact analysis.";

            // 將推理結果儲存在參數中供稍後使用
            args["suggested_action"] = suggestedAction;
            args["reasoning_result"] = reasoning;
            args["problem_title"] = problemTitle;
            args["task_description"] = taskDescription;
            
            return reasoning;
        },
        functionName: "advanced_reasoning",
        description: "Performs advanced business problem analysis and strategic reasoning"
    );
}

private static KernelFunction CreateAdvancedObservationFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var actionResult = args.GetValueOrDefault("action_result", "No action result")?.ToString() ?? "No action result";
            var reasoningResult = args.GetValueOrDefault("advanced_reasoning_result", "No reasoning result")?.ToString() ?? "No reasoning result";
            
            // 進階觀察分析
            var observation = $"Advanced Result Analysis:\n" +
                            $"1. Previous Reasoning: {reasoningResult}\n" +
                            $"2. Action Execution: {actionResult}\n" +
                            $"3. Strategic Insights: The analysis reveals key improvement opportunities.\n" +
                            $"4. Recommendations: Implement systematic changes with stakeholder buy-in.\n" +
                            $"5. Next Steps: Evaluate solution feasibility and create implementation timeline.";

            args["advanced_final_answer"] = observation;
            return observation;
        },
        functionName: "advanced_observation",
        description: "Performs advanced result analysis and provides strategic recommendations"
    );
}
```

### 配置 ReAct 迴圈行為

針對使用 `ReActLoopGraphNode` 的進階 ReAct 迴圈，您可以自訂推理迴圈參數：

```csharp
// 注意：此範例顯示 ReActLoopGraphNode API 結構
// 對於獨立範例，請考慮使用上面所示的順序方法
var reactLoopNode = ReActLoopGraphNode.CreateWithNodes(
    reasoningNode,
    actionNode,
    observationNode,
    "custom_react_loop")
    .ConfigureLoop(
        maxIterations: 10,
        goalAchievementThreshold: 0.9,
        enableEarlyTermination: true,
        iterationTimeout: TimeSpan.FromSeconds(60),
        totalTimeout: TimeSpan.FromMinutes(10));
```

## 思維鏈推理

### 基本思維鏈

使用 `ChainOfThoughtGraphNode` 實現逐步推理：

```csharp
using SemanticKernel.Graph.Nodes;

// 建立執行逐步推理的思維鏈函式
var cotNode = new FunctionGraphNode(
    CreateChainOfThoughtFunction(kernel),
    "chain_of_thought",
    "Step-by-step Problem Solving");

// 配置以儲存結果
cotNode.StoreResultAs("chain_of_thought_result");

// 構建執行器
var executor = new GraphExecutor("ChainOfThought", "Chain-of-Thought reasoning example");
executor.AddNode(cotNode);
executor.SetStartNode(cotNode.NodeId);
```

### 思維鏈函式實作

以下是思維鏈函式的實作：

```csharp
private static KernelFunction CreateChainOfThoughtFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var problemStatement = args.GetValueOrDefault("problem_statement", "No problem statement")?.ToString() ?? "No problem statement";
            var context = args.GetValueOrDefault("context", "No context provided")?.ToString() ?? "No context provided";
            var constraints = args.GetValueOrDefault("constraints", "No constraints specified")?.ToString() ?? "No constraints specified";
            var expectedOutcome = args.GetValueOrDefault("expected_outcome", "No expected outcome")?.ToString() ?? "No expected outcome";
            var reasoningDepth = args.GetValueOrDefault("reasoning_depth", 3);

            // 模擬逐步推理過程
            var reasoningSteps = new List<string>
            {
                $"Step 1: Problem Analysis\nAnalyzing the problem: {problemStatement}\nContext: {context}",
                $"Step 2: Constraint Identification\nConstraints identified: {constraints}",
                $"Step 3: Solution Development\nExpected outcome: {expectedOutcome}\nDeveloping solution approach...",
                $"Step 4: Solution Validation\nValidating solution against constraints and requirements...",
                $"Step 5: Final Recommendation\nProviding comprehensive solution with implementation steps."
            };

            // 只取得所請求的步驟數
            var stepsToUse = reasoningSteps.Take(Math.Min((int)reasoningDepth, reasoningSteps.Count)).ToList();
            
            // 生成最終答案
            var finalAnswer = $"Chain of Thought Analysis Complete:\n\n" +
                             $"Problem: {problemStatement}\n" +
                             $"Context: {context}\n" +
                             $"Constraints: {constraints}\n" +
                             $"Expected Outcome: {expectedOutcome}\n\n" +
                             $"Reasoning Steps ({stepsToUse.Count}):\n" +
                             string.Join("\n\n", stepsToUse) +
                             $"\n\nFinal Recommendation: Implement a systematic approach focusing on stakeholder engagement, " +
                             $"data-driven analysis, and phased implementation to achieve the desired {expectedOutcome}.";

            // 將推理結果儲存在參數中
            args["reasoning_steps"] = stepsToUse;
            args["final_answer"] = finalAnswer;
            args["problem_statement"] = problemStatement;
            args["context"] = context;
            args["constraints"] = constraints;
            args["expected_outcome"] = expectedOutcome;
            args["reasoning_depth"] = reasoningDepth;
            
            return finalAnswer;
        },
        functionName: "chain_of_thought",
        description: "Performs step-by-step reasoning for complex problem solving"
    );
}

// 準備推理的參數
var arguments = new KernelArguments
{
    ["problem_statement"] = "A company needs to reduce operational costs by 20% while maintaining employee satisfaction.",
    ["context"] = "The company operates in a competitive tech market with high talent retention challenges.",
    ["constraints"] = "Cannot reduce headcount by more than 5%, must maintain current benefit levels.",
    ["expected_outcome"] = "A comprehensive cost reduction plan with specific actionable steps",
    ["reasoning_depth"] = 4
};

var result = await executor.ExecuteAsync(kernel, arguments);
var finalAnswer = result.GetValue<string>() ?? "(no result)";
Console.WriteLine($"🧠 Final Answer: {finalAnswer}");
```

### 自訂思維鏈範本

為不同領域建立專門的推理範本：

```csharp
// 建立分析的自訂範本
var customTemplates = new Dictionary<string, string>
{
    ["step_1"] = @"You are analyzing a complex situation. This is step {{step_number}}.

Situation: {{problem_statement}}
Context: {{context}}

Start by identifying the key stakeholders and their interests. Who are the main parties involved and what do they care about?

Your analysis:",

    ["analysis_step"] = @"Continue your analysis. This is step {{step_number}} of {{max_steps}}.

Previous analysis:
{{previous_steps}}

Now examine the following aspect: What are the underlying causes and contributing factors? Look deeper than surface-level observations.

Your analysis:"
};

// 使用自訂範本建立思維鏈節點
// 注意：此範例顯示 API 結構，但對於獨立範例，
// 請考慮使用 FunctionGraphNode 搭配自訂推理邏輯
var cotNode = ChainOfThoughtGraphNode.CreateWithCustomization(
    ChainOfThoughtType.Analysis,
    customTemplates,
    customRules: null,  // 使用預設驗證規則
    maxSteps: 4);
```

## 問題解決範例

### 業務問題分析

使用 ReAct 解決複雜的業務問題：

```csharp
var arguments = new KernelArguments
{
    ["problem_title"] = "Budget Planning",
    ["task_description"] = "Our team needs to reduce operational costs by 20% while maintaining service quality. Current monthly spending is $50,000 across 5 departments.",
    ["max_iterations"] = 3,
    ["solver_mode"] = "systematic",
    ["domain"] = "business"
};

var result = await executor.ExecuteAsync(kernel, arguments);
var solution = result.GetValue<string>() ?? "No solution generated";
Console.WriteLine($"💡 ReAct Solution: {solution}");
```

### 技術問題解決

將 ReAct 應用於技術挑戰：

```csharp
var arguments = new KernelArguments
{
    ["problem_title"] = "System Performance",
    ["task_description"] = "Our web application is experiencing slow response times (>3 seconds) during peak hours. The database queries seem to be the bottleneck.",
    ["max_iterations"] = 4,
    ["solver_mode"] = "technical",
    ["domain"] = "software"
};

var result = await executor.ExecuteAsync(kernel, arguments);
var solution = result.GetValue<string>() ?? "No solution generated";
Console.WriteLine($"💻 Technical Solution: {solution}");
```

## 監控和除錯

### 追蹤推理效能

監控您的推理代理：

```csharp
// 獲得執行統計資料
// 注意：對於基於 FunctionGraphNode 的實作，您可以追蹤執行
// 通過自訂中繼資料或實施您自己的統計資料追蹤
var executionCount = 1; // 範例值
var successRate = 1.0; // 範例值
var averageIterations = 1.0; // 範例值

Console.WriteLine($"ReAct Loop Statistics:");
Console.WriteLine($"  Executions: {executionCount}");
Console.WriteLine($"  Success Rate: {successRate:P1}");
Console.WriteLine($"  Avg Iterations: {averageIterations:F1}");

// 思維鏈統計資料
// 注意：對於基於 FunctionGraphNode 的實作，您可以追蹤執行
// 通過自訂中繼資料或實施您自己的統計資料追蹤
var cotStats = new { ExecutionCount = 1, AverageQualityScore = 0.85, AverageStepsUsed = 3.0 }; // 範例值
Console.WriteLine($"Chain of Thought Statistics:");
Console.WriteLine($"  Executions: {cotStats.ExecutionCount}");
Console.WriteLine($"  Quality Score: {cotStats.AverageQualityScore:P1}");
Console.WriteLine($"  Steps Used: {cotStats.AverageStepsUsed:F1}");
```

### 除錯推理步驟

檢查推理過程：

```csharp
// 獲得詳細的執行中繼資料
var metadata = result.Metadata;
if (metadata.ContainsKey("reasoning_steps"))
{
    var steps = metadata["reasoning_steps"] as List<object>;
    Console.WriteLine("Reasoning Steps:");
    foreach (var step in steps ?? new List<object>())
    {
        Console.WriteLine($"  - {step}");
    }
}

if (metadata.ContainsKey("iterations"))
{
    var iterations = metadata["iterations"] as List<object>;
    Console.WriteLine($"Total Iterations: {iterations?.Count ?? 0}");
}
```

## 故障排除

### 常見問題

**ReAct 迴圈卡住**：檢查您的目標評估函式並確保它能夠正確偵測目標何時達成。

**思維鏈驗證失敗**：調整 `MinimumStepConfidence` 閾值或改進您的驗證規則。

**推理品質很差**：檢查您的推理範本並確保它們為每個步驟提供清晰的指導。

**動作未執行**：驗證您的動作節點是否可以存取所需的核心函式和參數。

### 效能建議

* 根據問題複雜性使用適當的反覆運算限制
* 為思維鏈啟用快取以避免冗餘推理
* 設定合理的逾時以防止無限迴圈
* 監控推理品質分數並調整信心閾值
* 盡可能使用提前終止以提高效率

## 另請參閱

* **參考**：[FunctionGraphNode](../api/FunctionGraphNode.md)、[ActionGraphNode](../api/ActionGraphNode.md)、[ReActLoopGraphNode](../api/ReActLoopGraphNode.md)、[ChainOfThoughtGraphNode](../api/ChainOfThoughtGraphNode.md)
* **指南**：[進階推理模式](../guides/advanced-reasoning.md)、[代理架構](../guides/agent-architecture.md)
* **範例**：[ReActAgentExample](../examples/react-agent.md)、[ChainOfThoughtExample](../examples/chain-of-thought.md)、[ReActProblemSolvingExample](../examples/react-problem-solving.md)

## 參考 API

* **[FunctionGraphNode](../api/nodes.md#function-graph-node)**：用於自訂邏輯的函式執行節點
* **[ActionGraphNode](../api/nodes.md#action-graph-node)**：具有函式發現的動作執行節點
* **[ReActLoopGraphNode](../api/nodes.md#react-loop-graph-node)**：ReAct 推理迴圈實作
* **[ChainOfThoughtGraphNode](../api/nodes.md#chain-of-thought-graph-node)**：思維鏈推理節點
