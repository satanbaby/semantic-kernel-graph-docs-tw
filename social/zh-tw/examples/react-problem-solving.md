# ReAct 問題解決範例

此範例展示了使用 Semantic Kernel Graph 工作流進行系統化問題解決的進階 ReAct (推理 → 行動 → 觀察) 代理。

## 目標

學習如何實現可以進行以下操作的複雜 ReAct 代理：
* 透過系統化分析解決複雜的多步驟問題
* 使用回饋迴圈處理反覆性問題精進
* 管理利益相關者分析、約束條件評估和風險評估
* 生成帶有實施路線圖的全面解決方案
* 支援不同的問題解決模式（基本、全面、反覆）

## 前置條件

* **.NET 8.0** 或更高版本
* **OpenAI API 金鑰**在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 對 [ReAct 模式](../concepts/react-pattern.md) 和 [圖執行](../concepts/graph-execution.md) 的基本理解
* 熟悉 [動作節點](../concepts/action-nodes.md) 和 [條件路由](../concepts/conditional-routing.md)

## 關鍵元件

### 概念和技術

* **ReAct 模式**：透過推理、行動和觀察循環進行系統化問題解決
* **多階段分析**：將複雜問題分解為可管理的分析階段
* **反覆精進**：透過回饋迴圈和收斂檢查進行持續改進
* **利益相關者管理**：識別和分析受問題影響的各方
* **風險評估**：評估潛在風險和風險緩解策略
* **解決方案綜合**：將分析結果整合為可執行的實施計畫

### 核心類別

* `GraphExecutor`：協調 ReAct 問題解決工作流
* `FunctionGraphNode`：執行推理、分析和綜合函數
* `ActionGraphNode`：根據上下文選擇並執行適當的行動
* `ConditionalEdge`：根據收斂標準和反覆狀態路由執行
* `ReActTemplateEngine`：為 ReAct 模式執行提供範本

## 執行範例

### 入門

此範例展示了使用 Semantic Kernel Graph 套件的 ReAct 問題解決模式。下面的程式碼片段展示了如何在自己的應用程式中實現此模式。

## 逐步實施

### 1. 基本問題解決

第一個範例展示了基礎的 ReAct 問題解決功能。

```csharp
public static async Task RunAsync()
{
    Console.WriteLine("--- ReAct 問題解決範例 ---\n");

    // 建立具有圖支援的最小核心（確定性，不需要外部 LLM）。
    var kernel = Kernel.CreateBuilder()
        .AddGraphSupport()
        .Build();

    // 使用模擬函數構建小型 ReAct 執行器。
    var executor = CreateBasicReActSolver(kernel);

    var arguments = new KernelArguments
    {
        ["problem_title"] = "預算規劃",
        ["task_description"] = "在保持服務品質的同時將營運成本降低 20%。",
        ["max_iterations"] = 3,
        ["solver_mode"] = "systematic",
        ["domain"] = "general"
    };

    var result = await executor.ExecuteAsync(kernel, arguments);
    var solution = result?.GetValue<string>() ?? "未生成解決方案";

    Console.WriteLine("💡 ReAct 解決方案：");
    Console.WriteLine($"   {solution}\n");
    Console.WriteLine("✅ ReAct 問題解決範例已成功完成！\n");
}
```

### 2. 基本 ReAct 求解器建立

基本求解器使用四個主要節點實現核心 ReAct 循環。

```csharp
private static GraphExecutor CreateBasicReActSolver(Kernel kernel)
{
    var executor = new GraphExecutor("BasicReActSolver", "基本 ReAct 問題解決代理");

    // 推理節點 - 確定性模擬函數
    var reasoningNode = new FunctionGraphNode(
        CreateMockReasoningFunction(kernel),
        "reasoning_node",
        "問題解決推理"
    );

    // 動作節點 - 從核心發現函數
    var actionNode = ActionGraphNode.CreateWithActions(
        kernel,
        new ActionSelectionCriteria
        {
            FunctionNamePattern = null,
            MinRequiredParameters = 0,
            MaxRequiredParameters = 5
        },
        "action_node");
    actionNode.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

    // 觀察節點 - 確定性模擬
    var observationNode = new FunctionGraphNode(
        CreateMockObservationFunction(kernel),
        "observation_node",
        "問題解決觀察"
    );

    // 解決方案綜合節點 - 用於演示的確定性綜合
    var solutionNode = new FunctionGraphNode(
        CreateSolutionSynthesisFunction(kernel),
        "solution_synthesis",
        "解決方案綜合"
    );

    executor.AddNode(reasoningNode);
    executor.AddNode(actionNode);
    executor.AddNode(observationNode);
    executor.AddNode(solutionNode);

    executor.SetStartNode(reasoningNode.NodeId);
    executor.AddEdge(ConditionalEdge.CreateUnconditional(reasoningNode, actionNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(actionNode, observationNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(observationNode, solutionNode));

    observationNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("problem_description") && args.TryGetValue("task_description", out var desc))
            {
                args["problem_description"] = desc;
            }
            return Task.CompletedTask;
        }));

    return executor;
}
```

### 3. 複雜的多步驟問題解決

第二個範例處理需要多個分析階段的複雜問題。

```csharp
private static async Task RunComplexProblemSolvingAsync(Kernel kernel)
{
    Console.WriteLine("--- 範例 2：複雜多步驟問題解決 ---");

    try
    {
        var templateEngine = new ReActTemplateEngine();

        var complexSolver = await CreateComplexReActSolverAsync(kernel, templateEngine);

        // 複雜問題場景
        var complexProblem = @"
問題：數位轉型策略

背景：
我們的傳統製造公司（500 名員工）需要進行數位轉型以保持競爭力。我們面臨多項挑戰：

1. 技術挑戰：
   - 運行關鍵操作的舊系統（已有 20 多年）
   - IT 基礎設施和專業知識有限
   - 增加連接性的網路安全隱憂
   - 舊系統和新系統之間的整合困難

2. 組織挑戰：
   - 長期員工對變革的抵觸
   - 整個員工隊伍缺乏數位技能
   - 全面轉型的預算有限
   - 優先事項衝突和投資回報率不清楚

3. 市場壓力：
   - 競爭對手採用工業 4.0 技術
   - 客戶對數位服務的期望
   - 供應鏈數位化要求
   - 資料處理的監管合規要求

約束條件：
* 預算：24 個月內 200 萬美元
* 轉型期間無法停止目前營運
* 必須維持目前的品質標準
* 監管合規要求

目標：
* 營運效率提高 30%
* 減少手動流程 50%
* 提高客戶滿意度評分
* 為未來創新奠定基礎
";

        Console.WriteLine("🎯 解決複雜數位轉型問題...\n");
        Console.WriteLine("📋 問題背景：");
        Console.WriteLine(complexProblem.Substring(0, Math.Min(500, complexProblem.Length)) + "...");
        Console.WriteLine();

        var arguments = new KernelArguments
        {
            ["problem_title"] = "數位轉型策略",
            ["task_description"] = complexProblem,
            ["max_iterations"] = 5,
            ["solver_mode"] = "comprehensive",
            ["domain"] = "business_strategy",
            ["complexity_level"] = "high"
        };

        var result = await complexSolver.ExecuteAsync(kernel, arguments);
        var comprehensiveSolution = result.GetValue<string>() ?? "未生成複雜解決方案";

        Console.WriteLine($"💡 全面 ReAct 解決方案：");
        Console.WriteLine($"   {comprehensiveSolution}");
        Console.WriteLine();

        Console.WriteLine("✅ 複雜 ReAct 問題解決範例已成功完成！\n");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ 複雜 ReAct 問題解決範例中出錯：{ex.Message}\n");
    }
}
```

### 4. 具有多個階段的複雜 ReAct 求解器

複雜求解器實現多階段分析工作流。

```csharp
private static async Task<GraphExecutor> CreateComplexReActSolverAsync(
    Kernel kernel,
    ReActTemplateEngine templateEngine)
{
    var executor = new GraphExecutor("ComplexReActSolver", "進階多階段 ReAct 問題求解器");

    // 多階段 ReAct 節點 - 使用模擬函數避免 LLM 依賴
    var initialAnalysisNode = new FunctionGraphNode(
        CreateMockReasoningFunction(kernel),
        "initial_analysis",
        "初始問題分析"
    );

    var stakeholderAnalysisNode = new FunctionGraphNode(
        CreateStakeholderAnalysisFunction(kernel),
        "stakeholder_analysis",
        "利益相關者分析"
    );

    var constraintAnalysisNode = new FunctionGraphNode(
        CreateConstraintAnalysisFunction(kernel),
        "constraint_analysis",
        "約束條件分析"
    );

    var optionGenerationNode = ActionGraphNode.CreateWithActions(
        kernel,
        new ActionSelectionCriteria
        {
            MinRequiredParameters = 0,
            MaxRequiredParameters = 6
        },
        "option_generation");
    optionGenerationNode.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

    var riskAssessmentNode = new FunctionGraphNode(
        CreateRiskAssessmentFunction(kernel),
        "risk_assessment",
        "風險評估"
    );

    var implementationPlanNode = ActionGraphNode.CreateWithActions(
        kernel,
        new ActionSelectionCriteria
        {
            MinRequiredParameters = 0,
            MaxRequiredParameters = 6
        },
        "implementation_plan");
    implementationPlanNode.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

    var evaluationNode = new FunctionGraphNode(
        CreateMockObservationFunction(kernel),
        "solution_evaluation",
        "解決方案評估"
    );

    var strategicSynthesisNode = new FunctionGraphNode(
        CreateStrategicSynthesisFunction(kernel),
        "strategic_synthesis",
        "策略解決方案綜合"
    );

    // 新增所有節點
    executor.AddNode(initialAnalysisNode);
    executor.AddNode(stakeholderAnalysisNode);
    executor.AddNode(constraintAnalysisNode);
    executor.AddNode(optionGenerationNode);
    executor.AddNode(riskAssessmentNode);
    executor.AddNode(implementationPlanNode);
    executor.AddNode(evaluationNode);
    executor.AddNode(strategicSynthesisNode);

    // 複雜多階段流程
    executor.SetStartNode(initialAnalysisNode.NodeId);
    executor.AddEdge(ConditionalEdge.CreateUnconditional(initialAnalysisNode, stakeholderAnalysisNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(stakeholderAnalysisNode, constraintAnalysisNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(constraintAnalysisNode, optionGenerationNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(optionGenerationNode, riskAssessmentNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(riskAssessmentNode, implementationPlanNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(implementationPlanNode, evaluationNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(evaluationNode, strategicSynthesisNode));

    // 在下一個節點驗證之前對所需輸入進行映射或提供預設值
    initialAnalysisNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("problem_description") && args.TryGetValue("task_description", out var desc))
            {
                args["problem_description"] = desc;
            }
            if (!args.ContainsName("solution_options"))
            {
                args["solution_options"] = "選項 A；選項 B；選項 C";
            }
            return Task.CompletedTask;
        }));

    return executor;
}
```

### 5. 帶有精進的反覆性問題解決

第三個範例展示了帶有回饋迴圈的反覆性問題解決。

```csharp
private static async Task RunIterativeProblemSolvingAsync(Kernel kernel)
{
    Console.WriteLine("--- 範例 3：帶有精進的反覆性問題解決 ---");

    try
    {
        var templateEngine = new ReActTemplateEngine();

        var iterativeSolver = await CreateIterativeReActSolverAsync(kernel, templateEngine);

        // 反覆性問題場景
        var iterativeProblem = @"
演變問題：客戶服務最佳化

初始狀態：
* 客戶滿意度：3.2/5.0
* 平均回應時間：24 小時
* 解決率：65%
* 客戶流失率：月 15%

回饋循環：
此問題需要基於以下方面的反覆性精進：
1. 初始解決方案測試
2. 客戶回饋分析
3. 效能指標監控
4. 持續改進調整

目標狀態：
* 客戶滿意度：>4.5/5.0
* 平均回應時間：<4 小時
* 解決率：>90%
* 客戶流失率：月 <5%
";

        Console.WriteLine("🔄 使用反覆精進解決問題...\n");
        Console.WriteLine("📋 反覆性問題背景：");
        Console.WriteLine(iterativeProblem);
        Console.WriteLine();

        var arguments = new KernelArguments
        {
            ["problem_title"] = "客戶服務最佳化",
            ["task_description"] = iterativeProblem,
            ["max_iterations"] = 4,
            ["solver_mode"] = "iterative",
            ["domain"] = "customer_service",
            ["refinement_cycles"] = 3,
            ["feedback_integration"] = true
        };

        var result = await iterativeSolver.ExecuteAsync(kernel, arguments);
        var iterativeSolution = result.GetValue<string>() ?? "未生成反覆性解決方案";

        Console.WriteLine($"💡 反覆性 ReAct 解決方案：");
        Console.WriteLine($"   {iterativeSolution}");
        Console.WriteLine();

        Console.WriteLine("✅ 反覆性 ReAct 問題解決範例已成功完成！\n");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ 反覆性 ReAct 問題解決範例中出錯：{ex.Message}\n");
    }
}
```

### 6. 帶有回饋迴圈的反覆性 ReAct 求解器

反覆性求解器實現帶有收斂檢查的精進循環。

```csharp
private static async Task<GraphExecutor> CreateIterativeReActSolverAsync(
    Kernel kernel,
    ReActTemplateEngine templateEngine)
{
    var executor = new GraphExecutor("IterativeReActSolver", "帶有精進迴圈的反覆性 ReAct 求解器");

    // 向核心新增一些函數供 ActionGraphNode 發現
    kernel.ImportPluginFromFunctions("react_actions", "ReAct 模式的動作", new[]
    {
        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var action = args["action"]?.ToString() ?? "unknown";
                return $"已執行動作：{action}";
            },
            functionName: "execute_action",
            description: "執行指定的動作"
        ),

        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var problem = args["problem"]?.ToString() ?? "unknown";
                return $"已分析問題：{problem}";
            },
            functionName: "analyze_problem",
            description: "分析給定的問題"
        ),

        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var solution = args["solution"]?.ToString() ?? "unknown";
                return $"已評估解決方案：{solution}";
            },
            functionName: "evaluate_solution",
            description: "評估提議的解決方案"
        )
    });

    // 手動建立個別 ReAct 元件以避免複雜的 ReActLoopGraphNode
    var reasoningNode = new FunctionGraphNode(
        CreateMockReasoningFunction(kernel),
        "iterative_reasoning",
        "反覆性問題解決推理"
    );

    var actionNode = ActionGraphNode.CreateWithActions(
        kernel,
        new ActionSelectionCriteria
        {
            MinRequiredParameters = 0,
            MaxRequiredParameters = 6
        },
        "iterative_action");
    actionNode.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

    var observationNode = new FunctionGraphNode(
        CreateMockObservationFunction(kernel),
        "iterative_observation",
        "反覆性問題解決觀察"
    );

    var feedbackAnalysisNode = new FunctionGraphNode(
        CreateFeedbackAnalysisFunction(kernel),
        "feedback_analysis",
        "回饋分析"
    );

    var refinementNode = new FunctionGraphNode(
        CreateSolutionRefinementFunction(kernel),
        "solution_refinement",
        "解決方案精進"
    );

    var convergenceNode = new FunctionGraphNode(
        CreateConvergenceCheckFunction(kernel),
        "convergence_check",
        "收斂評估"
    );

    var finalSolutionNode = new FunctionGraphNode(
        CreateFinalSolutionFunction(kernel),
        "final_solution",
        "最終解決方案生成"
    );

    // 新增節點
    executor.AddNode(reasoningNode);
    executor.AddNode(actionNode);
    executor.AddNode(observationNode);
    executor.AddNode(feedbackAnalysisNode);
    executor.AddNode(refinementNode);
    executor.AddNode(convergenceNode);
    executor.AddNode(finalSolutionNode);

    // 帶有回饋迴圈的反覆性流程
    executor.SetStartNode(reasoningNode.NodeId);
    executor.AddEdge(ConditionalEdge.CreateUnconditional(reasoningNode, actionNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(actionNode, observationNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(observationNode, feedbackAnalysisNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(feedbackAnalysisNode, refinementNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(refinementNode, convergenceNode));

    // 用於反覆與完成的條件邊
    executor.AddEdge(new ConditionalEdge(
        convergenceNode,
        reasoningNode,
        args => ShouldContinueIterating(args),
        "繼續反覆"
    ));

    executor.AddEdge(new ConditionalEdge(
        convergenceNode,
        finalSolutionNode,
        args => !ShouldContinueIterating(args),
        "完成解決方案"
    ));

    // 保留下游提示所需的中間結果
    feedbackAnalysisNode.StoreResultAs("feedback_analysis");
    refinementNode.StoreResultAs("current_solution");

    // 在下一個節點驗證之前提供預設值/映射所需的輸入
    observationNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("iteration_count")) args["iteration_count"] = 1;
            if (!args.ContainsName("previous_results")) args["previous_results"] = "";
            if (!args.ContainsName("problem_description") && args.TryGetValue("task_description", out var desc))
            {
                args["problem_description"] = desc;
            }
            if (!args.ContainsName("target_criteria")) args["target_criteria"] = "符合目標和約束條件";
            return Task.CompletedTask;
        }));

    refinementNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("current_solution")) args["current_solution"] = result.GetValue<string>() ?? "初始提議";
            return Task.CompletedTask;
        }));

    convergenceNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("target_criteria"))
            {
                args["target_criteria"] = "符合目標和約束條件";
            }

            // 增加反覆計數器並更新簡單品質分數以確保收斂
            int currentIteration;
            try { currentIteration = Convert.ToInt32(args.GetValueOrDefault("iteration_count", 1), System.Globalization.CultureInfo.InvariantCulture); }
            catch { currentIteration = 1; }

            int maxIterations;
            try { maxIterations = Convert.ToInt32(args.GetValueOrDefault("max_iterations", 3), System.Globalization.CultureInfo.InvariantCulture); }
            catch { maxIterations = 3; }

            var nextIteration = currentIteration + 1;
            args["iteration_count"] = nextIteration;

            // 品質分數隨反覆次數向 1.0 增加，確保最終收斂
            var denominator = Math.Max(1, maxIterations);
            double progress = Math.Min(1.0, nextIteration / (double)denominator);
            args["quality_score"] = progress;

            return Task.CompletedTask;
        }));

    finalSolutionNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("refinement_history")) args["refinement_history"] = "無歷史";
            if (!args.ContainsName("final_analysis")) args["final_analysis"] = args.GetValueOrDefault("current_solution", "");
            return Task.CompletedTask;
        }));

    return executor;
}
```

### 7. 函數建立和範本

範例展示了為 ReAct 工作流建立函數的各種方法。

```csharp
// 用於問題解決的模擬推理函數
private static KernelFunction CreateMockReasoningFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var taskDescription = args["task_description"]?.ToString() ?? "unknown task";
            var problemTitle = args["problem_title"]?.ToString() ?? "unknown problem";

            return $"分析問題 '{problemTitle}'：{taskDescription}。根據分析，下一步應該是識別關鍵利益相關者和約束條件。";
        },
        functionName: "mock_reasoning",
        description: "用於問題解決的模擬推理函數"
    );
}

// 使用提示範本的解決方案綜合函數
private static KernelFunction CreateSolutionSynthesisFunction(Kernel kernel)
{
    var prompt = @"
基於 ReAct 分析綜合全面解決方案：

問題：{{$problem_title}}
說明：{{$problem_description}}
求解器模式：{{$solver_mode}}

根據 ReAct 推理、行動規劃和觀察：

1. 綜合分析的關鍵見解
2. 優先考慮最有效的行動
3. 建立實施路線圖
4. 識別成功指標
5. 突出潛在風險和風險緩解

提供全面的解決方案綜合：";

    return kernel.CreateFunctionFromPrompt(
        prompt,
        functionName: "solution_synthesis",
        description: "從 ReAct 分析綜合全面解決方案"
    );
}

// 帶有模擬實現的約束條件分析函數
private static KernelFunction CreateConstraintAnalysisFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var problemDescription = args["problem_description"]?.ToString()
                ?? args["task_description"]?.ToString()
                ?? "unknown problem";
            var domain = args["domain"]?.ToString() ?? "general";

            var analysis = $"域 '{domain}' 的約束條件分析：\n" +
                           "1) 資源約束：預算、時間、人員必須在各個階段中優先考慮；強制執行嚴格的範圍控制和分階段融資。\n" +
                           "2) 技術約束：舊系統和整合需要 strangler 模式、API 閘道和分階段現代化，具有強大的可觀測性。\n" +
                           "3) 組織約束：變革管理、能力差距和培訓節奏必須嵌入計畫中；指定轉型倡導者。\n" +
                           "4) 監管約束：資料駐留、隱私和可稽核性制約架構選擇；實施政策即程式碼和合規即設計。\n" +
                           "5) 市場約束：客戶期望和競爭基準設定最小可行功能基線和 SLA。\n" +
                           "6) 風險承受度：定義可接受的風險範圍和風險緩解觸發器；採用漸進式推出和終止開關。\n\n" +
                           $"考慮的背景：{problemDescription.Substring(0, Math.Min(200, problemDescription.Length))}...";

            return analysis;
        },
        functionName: "constraint_analysis",
        description: "分析約束條件和限制"
    );
}
```

### 8. 收斂邏輯和反覆控制

範例為反覆精進實現複雜的收斂檢查。

```csharp
// 根據收斂標準決定是否應該繼續反覆
private static bool ShouldContinueIterating(KernelArguments args)
{
    // 強大的收斂檢查：容忍 int/double/string 值
    static int ToInt(object? value, int defaultValue)
    {
        if (value is null) return defaultValue;
        try
        {
            return Convert.ToInt32(value, System.Globalization.CultureInfo.InvariantCulture);
        }
        catch
        {
            return defaultValue;
        }
    }

    static double ToDouble(object? value, double defaultValue)
    {
        if (value is null) return defaultValue;
        try
        {
            return Convert.ToDouble(value, System.Globalization.CultureInfo.InvariantCulture);
        }
        catch
        {
            return defaultValue;
        }
    }

    var iterationCount = ToInt(args.GetValueOrDefault("iteration_count", 0), 0);
    var maxIterations = ToInt(args.GetValueOrDefault("max_iterations", 3), 3);
    var qualityScore = ToDouble(args.GetValueOrDefault("quality_score", 0.5), 0.5);
    var convergenceThreshold = ToDouble(args.GetValueOrDefault("convergence_threshold", 0.85), 0.85);

    return iterationCount < maxIterations && qualityScore < convergenceThreshold;
}

// 收斂檢查函數
private static KernelFunction CreateConvergenceCheckFunction(Kernel kernel)
{
    // 使用確定性的方法型函數以避免外部 LLM 依賴和消除
    // 範例執行中的短暫故障（例如 HTTP 503）。
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var shouldContinue = ShouldContinueIterating(args);
            var iteration = args.GetValueOrDefault("iteration_count", 1)?.ToString();
            var quality = args.GetValueOrDefault("quality_score", 0.0)?.ToString();
            var threshold = args.GetValueOrDefault("convergence_threshold", 0.85)?.ToString();

            return shouldContinue
                ? $"收斂檢查（反覆 {iteration}）：品質={quality}，閾值={threshold}。尚未收斂 — 繼續精進。"
                : $"收斂檢查（反覆 {iteration}）：品質={quality}，閾值={threshold}。已收斂 — 完成解決方案。";
        },
        functionName: "convergence_check",
        description: "檢查解決方案是否已收斂到可接受的品質，無需外部呼叫"
    );
}
```

## 進階模式

### 多目標問題解決

```csharp
// 使用加權評分實現多目標最佳化
var multiObjectiveAgent = new MultiObjectiveReActAgent
{
    ObjectiveWeights = new Dictionary<string, double>
    {
        ["cost"] = 0.3,
        ["quality"] = 0.4,
        ["time"] = 0.2,
        ["risk"] = 0.1
    },
    ParetoFrontierAnalysis = new ParetoFrontierAnalyzer
    {
        MaxSolutions = 10,
        DominanceThreshold = 0.1,
        ConvergenceCriteria = new MultiObjectiveConvergenceCriteria
        {
            HypervolumeImprovement = 0.01,
            MaxGenerations = 50
        }
    }
};

// 解決多目標問題
var multiObjectiveResult = await multiObjectiveAgent.SolveAsync(kernel, multiObjectiveArgs);
```

### 自適應問題分解

```csharp
// 根據複雜性實現自適應問題分解
var adaptiveDecomposer = new AdaptiveProblemDecomposer
{
    DecompositionStrategies = new Dictionary<string, IDecompositionStrategy>
    {
        ["hierarchical"] = new HierarchicalDecompositionStrategy(),
        ["parallel"] = new ParallelDecompositionStrategy(),
        ["iterative"] = new IterativeDecompositionStrategy()
    },
    ComplexityAnalyzer = new ProblemComplexityAnalyzer
    {
        ComplexityFactors = new[] { "stakeholder_count", "constraint_count", "domain_count" },
        StrategySelectionRules = new Dictionary<string, string>
        {
            ["low"] = "hierarchical",
            ["medium"] = "parallel",
            ["high"] = "iterative"
        }
    }
};

// 自動分解複雜問題
var decomposition = await adaptiveDecomposer.DecomposeAsync(problemStatement);
var decomposedGraph = await adaptiveDecomposer.CreateDecomposedGraphAsync(decomposition);
```

### 協作問題解決

```csharp
// 使用多個代理實現協作問題解決
var collaborativeSolver = new CollaborativeProblemSolver
{
    AgentSpecializations = new Dictionary<string, AgentSpecialization>
    {
        ["analyst"] = new AnalystAgent { Domain = "business_analysis" },
        ["engineer"] = new EngineerAgent { Domain = "technical_implementation" },
        ["strategist"] = new StrategistAgent { Domain = "strategic_planning" }
    },
    CollaborationProtocol = new ConsensusProtocol
    {
        VotingMechanism = VotingMechanism.WeightedMajority,
        ConsensusThreshold = 0.75,
        ConflictResolution = ConflictResolution.Mediation
    },
    KnowledgeSharing = new KnowledgeSharingStrategy
    {
        SharedMemory = new SharedMemoryManager(),
        KnowledgeTransfer = KnowledgeTransfer.Continuous,
        LearningRate = 0.1
    }
};

// 協作解決問題
var collaborativeResult = await collaborativeSolver.SolveCollaborativelyAsync(kernel, collaborativeArgs);
```

## 預期輸出

範例產生全面的輸出，顯示：

* 🎯 **基本問題解決**：預算規劃、系統效能和團隊生產力問題的系統化分析
* 🔍 **複雜多步驟分析**：數位轉型的全面利益相關者分析、約束條件評估和風險評估
* 🔄 **反覆精進**：具有回饋迴圈和收斂檢查的客戶服務最佳化
* 💡 **解決方案綜合**：具有成功指標和風險緩解的可執行實施路線圖
* 📊 **利益相關者管理**：關鍵方的識別和溝通策略
* ⚠️ **風險評估**：全面的風險評估和風險緩解策略
* 🚀 **實施規劃**：詳細的執行計畫，包括資源分配和時程表

## 故障排除

### 常見問題

1. **LLM API 故障**：範例使用模擬函數以避免外部依賴
2. **狀態映射錯誤**：驗證節點之間的輸入/輸出映射
3. **收斂問題**：檢查反覆限制和品質閾值
4. **動作選擇故障**：確保核心具有適合 ActionGraphNode 的函數

### 除錯提示

* 監控 AfterExecute 中繼資料處理器中的狀態轉換
* 驗證收斂邏輯和反覆計數
* 檢查反覆工作流的條件邊路由
* 驗證節點之間的函數輸入和輸出

### 效能考量

* 使用模擬函數進行確定性測試
* 實施適當的反覆限制以防止無限迴圈
* 在反覆精進期間監控狀態大小增長
* 為長期執行的反覆工作流考慮檢查點

## 另請參閱

* [ReAct 模式](../concepts/react-pattern.md)
* [動作節點](../concepts/action-nodes.md)
* [條件路由](../concepts/conditional-routing.md)
* [狀態管理](../concepts/state.md)
* [圖執行](../concepts/graph-execution.md)
* [ReAct 代理範例](./react-agent.md)
* [問題解決模式](../patterns/problem-solving.md)
