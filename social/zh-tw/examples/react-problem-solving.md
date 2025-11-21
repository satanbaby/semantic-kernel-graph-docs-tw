# ReAct 問題解決範例

本範例展示了使用 Semantic Kernel Graph 工作流進行系統化問題解決的高級 ReAct（推理 → 執行 → 觀察）代理。

## 目標

學習如何實現能夠：
* 通過系統化分析解決複雜的多步驟問題
* 處理具有反饋迴圈的迭代問題優化
* 管理利益相關者分析、約束條件評估和風險評估
* 生成包含實施路線圖的全面解決方案
* 支援不同的問題解決模式（基礎、全面、迭代）

## 前置條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 配置於 `appsettings.json`
* **Semantic Kernel Graph 套件**已安裝
* 基本了解 [ReAct Pattern](../concepts/react-pattern.md) 和 [Graph Execution](../concepts/graph-execution.md)
* 熟悉 [Action Nodes](../concepts/action-nodes.md) 和 [Conditional Routing](../concepts/conditional-routing.md)

## 關鍵元件

### 概念和技術

* **ReAct Pattern**：通過推理、執行和觀察循環進行系統化問題解決
* **多階段分析**：將複雜問題分解為可管理的分析階段
* **迭代優化**：通過反饋迴圈和收斂檢查實現持續改進
* **利益相關者管理**：識別和分析受問題影響的所有方
* **風險評估**：評估潛在風險和緩解策略
* **解決方案綜合**：將分析結果組合成可行的實施計劃

### 核心類別

* `GraphExecutor`：協調 ReAct 問題解決工作流
* `FunctionGraphNode`：執行推理、分析和綜合函數
* `ActionGraphNode`：根據上下文選擇和執行適當的操作
* `ConditionalEdge`：根據收斂條件和迭代狀態路由執行
* `ReActTemplateEngine`：為 ReAct 模式執行提供模板

## 執行範例

### 開始入門

本範例展示了使用 Semantic Kernel Graph 套件的 ReAct 問題解決模式。以下程式碼片段示範了如何在自己的應用程式中實現此模式。

## 逐步實施

### 1. 基礎問題解決

第一個範例展示了基本的 ReAct 問題解決能力。

```csharp
public static async Task RunAsync()
{
    Console.WriteLine("--- ReAct Problem Solving Example ---\n");

    // Create a minimal kernel with graph support (deterministic, no external LLM required).
    var kernel = Kernel.CreateBuilder()
        .AddGraphSupport()
        .Build();

    // Build a small ReAct executor using mock functions.
    var executor = CreateBasicReActSolver(kernel);

    var arguments = new KernelArguments
    {
        ["problem_title"] = "Budget Planning",
        ["task_description"] = "Reduce operational costs by 20% while maintaining service quality.",
        ["max_iterations"] = 3,
        ["solver_mode"] = "systematic",
        ["domain"] = "general"
    };

    var result = await executor.ExecuteAsync(kernel, arguments);
    var solution = result?.GetValue<string>() ?? "No solution generated";

    Console.WriteLine("💡 ReAct Solution:");
    Console.WriteLine($"   {solution}\n");
    Console.WriteLine("✅ ReAct problem solving example completed successfully!\n");
}
```

### 2. 基礎 ReAct 求解器建立

基礎求解器使用四個主要 Node 實現核心 ReAct 循環。

```csharp
private static GraphExecutor CreateBasicReActSolver(Kernel kernel)
{
    var executor = new GraphExecutor("BasicReActSolver", "Basic ReAct problem solving agent");

    // Reasoning node - deterministic mock function
    var reasoningNode = new FunctionGraphNode(
        CreateMockReasoningFunction(kernel),
        "reasoning_node",
        "Problem Solving Reasoning"
    );

    // Action node - discovers functions from the kernel
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

    // Observation node - deterministic mock
    var observationNode = new FunctionGraphNode(
        CreateMockObservationFunction(kernel),
        "observation_node",
        "Problem Solving Observation"
    );

    // Solution synthesis node - deterministic synthesis for the demo
    var solutionNode = new FunctionGraphNode(
        CreateSolutionSynthesisFunction(kernel),
        "solution_synthesis",
        "Solution Synthesis"
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
    Console.WriteLine("--- Example 2: Complex Multi-Step Problem Solving ---");

    try
    {
        var templateEngine = new ReActTemplateEngine();

        var complexSolver = await CreateComplexReActSolverAsync(kernel, templateEngine);

        // Complex problem scenario
        var complexProblem = @"
PROBLEM: Digital Transformation Strategy

CONTEXT:
Our traditional manufacturing company (500 employees) needs to undergo digital transformation to remain competitive. We face multiple challenges:

1. TECHNICAL CHALLENGES:
   - Legacy systems (20+ years old) running critical operations
   - Limited IT infrastructure and expertise
   - Cybersecurity concerns with increased connectivity
   - Integration difficulties between old and new systems

2. ORGANIZATIONAL CHALLENGES:
   - Resistance to change from long-term employees
   - Lack of digital skills across workforce
   - Limited budget for comprehensive transformation
   - Competing priorities and unclear ROI

3. MARKET PRESSURES:
   - Competitors adopting Industry 4.0 technologies
   - Customer expectations for digital services
   - Supply chain digitization requirements
   - Regulatory compliance for data handling

CONSTRAINTS:
* Budget: $2M over 24 months
* Cannot halt current operations during transition
* Must maintain current quality standards
* Regulatory compliance requirements

GOALS:
* Increase operational efficiency by 30%
* Reduce manual processes by 50%
* Improve customer satisfaction scores
* Establish foundation for future innovations
";

        Console.WriteLine("🎯 Solving Complex Digital Transformation Problem...\n");
        Console.WriteLine("📋 Problem Context:");
        Console.WriteLine(complexProblem.Substring(0, Math.Min(500, complexProblem.Length)) + "...");
        Console.WriteLine();

        var arguments = new KernelArguments
        {
            ["problem_title"] = "Digital Transformation Strategy",
            ["task_description"] = complexProblem,
            ["max_iterations"] = 5,
            ["solver_mode"] = "comprehensive",
            ["domain"] = "business_strategy",
            ["complexity_level"] = "high"
        };

        var result = await complexSolver.ExecuteAsync(kernel, arguments);
        var comprehensiveSolution = result.GetValue<string>() ?? "Complex solution not generated";

        Console.WriteLine($"💡 Comprehensive ReAct Solution:");
        Console.WriteLine($"   {comprehensiveSolution}");
        Console.WriteLine();

        Console.WriteLine("✅ Complex ReAct problem solving example completed successfully!\n");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Error in complex ReAct problem solving example: {ex.Message}\n");
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
    var executor = new GraphExecutor("ComplexReActSolver", "Advanced multi-stage ReAct problem solver");

    // Multi-stage ReAct nodes - using mock functions to avoid LLM dependencies
    var initialAnalysisNode = new FunctionGraphNode(
        CreateMockReasoningFunction(kernel),
        "initial_analysis",
        "Initial Problem Analysis"
    );

    var stakeholderAnalysisNode = new FunctionGraphNode(
        CreateStakeholderAnalysisFunction(kernel),
        "stakeholder_analysis",
        "Stakeholder Analysis"
    );

    var constraintAnalysisNode = new FunctionGraphNode(
        CreateConstraintAnalysisFunction(kernel),
        "constraint_analysis",
        "Constraint Analysis"
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
        "Risk Assessment"
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
        "Solution Evaluation"
    );

    var strategicSynthesisNode = new FunctionGraphNode(
        CreateStrategicSynthesisFunction(kernel),
        "strategic_synthesis",
        "Strategic Solution Synthesis"
    );

    // Add all nodes
    executor.AddNode(initialAnalysisNode);
    executor.AddNode(stakeholderAnalysisNode);
    executor.AddNode(constraintAnalysisNode);
    executor.AddNode(optionGenerationNode);
    executor.AddNode(riskAssessmentNode);
    executor.AddNode(implementationPlanNode);
    executor.AddNode(evaluationNode);
    executor.AddNode(strategicSynthesisNode);

    // Complex multi-stage flow
    executor.SetStartNode(initialAnalysisNode.NodeId);
    executor.AddEdge(ConditionalEdge.CreateUnconditional(initialAnalysisNode, stakeholderAnalysisNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(stakeholderAnalysisNode, constraintAnalysisNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(constraintAnalysisNode, optionGenerationNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(optionGenerationNode, riskAssessmentNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(riskAssessmentNode, implementationPlanNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(implementationPlanNode, evaluationNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(evaluationNode, strategicSynthesisNode));

    // Map or provide defaults for required inputs before next-node validation
    initialAnalysisNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("problem_description") && args.TryGetValue("task_description", out var desc))
            {
                args["problem_description"] = desc;
            }
            if (!args.ContainsName("solution_options"))
            {
                args["solution_options"] = "Option A; Option B; Option C";
            }
            return Task.CompletedTask;
        }));

    return executor;
}
```

### 5. 具有優化的迭代問題解決

第三個範例展示了具有反饋迴圈的迭代問題解決。

```csharp
private static async Task RunIterativeProblemSolvingAsync(Kernel kernel)
{
    Console.WriteLine("--- Example 3: Iterative Problem Solving with Refinement ---");

    try
    {
        var templateEngine = new ReActTemplateEngine();

        var iterativeSolver = await CreateIterativeReActSolverAsync(kernel, templateEngine);

        // Iterative problem scenario
        var iterativeProblem = @"
EVOLVING PROBLEM: Customer Service Optimization

INITIAL STATE:
* Customer satisfaction: 3.2/5.0
* Average response time: 24 hours
* Resolution rate: 65%
* Customer churn: 15% monthly

FEEDBACK CYCLE:
This problem requires iterative refinement based on:
1. Initial solution testing
2. Customer feedback analysis
3. Performance metrics monitoring
4. Continuous improvement adjustments

TARGET STATE:
* Customer satisfaction: >4.5/5.0
* Average response time: <4 hours
* Resolution rate: >90%
* Customer churn: <5% monthly
";

        Console.WriteLine("🔄 Solving problem with iterative refinement...\n");
        Console.WriteLine("📋 Iterative Problem Context:");
        Console.WriteLine(iterativeProblem);
        Console.WriteLine();

        var arguments = new KernelArguments
        {
            ["problem_title"] = "Customer Service Optimization",
            ["task_description"] = iterativeProblem,
            ["max_iterations"] = 4,
            ["solver_mode"] = "iterative",
            ["domain"] = "customer_service",
            ["refinement_cycles"] = 3,
            ["feedback_integration"] = true
        };

        var result = await iterativeSolver.ExecuteAsync(kernel, arguments);
        var iterativeSolution = result.GetValue<string>() ?? "Iterative solution not generated";

        Console.WriteLine($"💡 Iterative ReAct Solution:");
        Console.WriteLine($"   {iterativeSolution}");
        Console.WriteLine();

        Console.WriteLine("✅ Iterative ReAct problem solving example completed successfully!\n");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Error in iterative ReAct problem solving example: {ex.Message}\n");
    }
}
```

### 6. 具有反饋迴圈的迭代 ReAct 求解器

迭代求解器使用收斂檢查實現優化循環。

```csharp
private static async Task<GraphExecutor> CreateIterativeReActSolverAsync(
    Kernel kernel,
    ReActTemplateEngine templateEngine)
{
    var executor = new GraphExecutor("IterativeReActSolver", "Iterative ReAct solver with refinement loops");

    // Add some functions to the kernel for the ActionGraphNode to discover
    kernel.ImportPluginFromFunctions("react_actions", "Actions for ReAct pattern", new[]
    {
        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var action = args["action"]?.ToString() ?? "unknown";
                return $"Executed action: {action}";
            },
            functionName: "execute_action",
            description: "Executes a specified action"
        ),

        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var problem = args["problem"]?.ToString() ?? "unknown";
                return $"Analyzed problem: {problem}";
            },
            functionName: "analyze_problem",
            description: "Analyzes a given problem"
        ),

        kernel.CreateFunctionFromMethod(
            (KernelArguments args) =>
            {
                var solution = args["solution"]?.ToString() ?? "unknown";
                return $"Evaluated solution: {solution}";
            },
            functionName: "evaluate_solution",
            description: "Evaluates a proposed solution"
        )
    });

    // Create individual ReAct components manually to avoid the complex ReActLoopGraphNode
    var reasoningNode = new FunctionGraphNode(
        CreateMockReasoningFunction(kernel),
        "iterative_reasoning",
        "Iterative Problem Solving Reasoning"
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
        "Iterative Problem Solving Observation"
    );

    var feedbackAnalysisNode = new FunctionGraphNode(
        CreateFeedbackAnalysisFunction(kernel),
        "feedback_analysis",
        "Feedback Analysis"
    );

    var refinementNode = new FunctionGraphNode(
        CreateSolutionRefinementFunction(kernel),
        "solution_refinement",
        "Solution Refinement"
    );

    var convergenceNode = new FunctionGraphNode(
        CreateConvergenceCheckFunction(kernel),
        "convergence_check",
        "Convergence Assessment"
    );

    var finalSolutionNode = new FunctionGraphNode(
        CreateFinalSolutionFunction(kernel),
        "final_solution",
        "Final Solution Generation"
    );

    // Add nodes
    executor.AddNode(reasoningNode);
    executor.AddNode(actionNode);
    executor.AddNode(observationNode);
    executor.AddNode(feedbackAnalysisNode);
    executor.AddNode(refinementNode);
    executor.AddNode(convergenceNode);
    executor.AddNode(finalSolutionNode);

    // Iterative flow with feedback loops
    executor.SetStartNode(reasoningNode.NodeId);
    executor.AddEdge(ConditionalEdge.CreateUnconditional(reasoningNode, actionNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(actionNode, observationNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(observationNode, feedbackAnalysisNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(feedbackAnalysisNode, refinementNode));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(refinementNode, convergenceNode));

    // Conditional edges for iteration vs completion
    executor.AddEdge(new ConditionalEdge(
        convergenceNode,
        reasoningNode,
        args => ShouldContinueIterating(args),
        "Continue Iteration"
    ));

    executor.AddEdge(new ConditionalEdge(
        convergenceNode,
        finalSolutionNode,
        args => !ShouldContinueIterating(args),
        "Finalize Solution"
    ));

    // Persist intermediate results required by downstream prompts
    feedbackAnalysisNode.StoreResultAs("feedback_analysis");
    refinementNode.StoreResultAs("current_solution");

    // Provide defaults/mappings for required inputs prior to validation of subsequent nodes
    observationNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("iteration_count")) args["iteration_count"] = 1;
            if (!args.ContainsName("previous_results")) args["previous_results"] = "";
            if (!args.ContainsName("problem_description") && args.TryGetValue("task_description", out var desc))
            {
                args["problem_description"] = desc;
            }
            if (!args.ContainsName("target_criteria")) args["target_criteria"] = "Meets goals and constraints";
            return Task.CompletedTask;
        }));

    refinementNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("current_solution")) args["current_solution"] = result.GetValue<string>() ?? "Initial proposal";
            return Task.CompletedTask;
        }));

    convergenceNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("target_criteria"))
            {
                args["target_criteria"] = "Meets goals and constraints";
            }

            // Increment iteration counter and update a simple quality score to ensure convergence
            int currentIteration;
            try { currentIteration = Convert.ToInt32(args.GetValueOrDefault("iteration_count", 1), System.Globalization.CultureInfo.InvariantCulture); }
            catch { currentIteration = 1; }

            int maxIterations;
            try { maxIterations = Convert.ToInt32(args.GetValueOrDefault("max_iterations", 3), System.Globalization.CultureInfo.InvariantCulture); }
            catch { maxIterations = 3; }

            var nextIteration = currentIteration + 1;
            args["iteration_count"] = nextIteration;

            // Quality score increases with iterations toward 1.0, ensuring eventual convergence
            var denominator = Math.Max(1, maxIterations);
            double progress = Math.Min(1.0, nextIteration / (double)denominator);
            args["quality_score"] = progress;

            return Task.CompletedTask;
        }));

    finalSolutionNode.SetMetadata("AfterExecute",
        new Func<Kernel, KernelArguments, FunctionResult, CancellationToken, Task>((k, args, result, ct) =>
        {
            if (!args.ContainsName("refinement_history")) args["refinement_history"] = "No history";
            if (!args.ContainsName("final_analysis")) args["final_analysis"] = args.GetValueOrDefault("current_solution", "");
            return Task.CompletedTask;
        }));

    return executor;
}
```

### 7. 函數建立和模板

範例展示了為 ReAct 工作流建立函數的各種方法。

```csharp
// Mock reasoning function for problem solving
private static KernelFunction CreateMockReasoningFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var taskDescription = args["task_description"]?.ToString() ?? "unknown task";
            var problemTitle = args["problem_title"]?.ToString() ?? "unknown problem";

            return $"Analyzed problem '{problemTitle}': {taskDescription}. Based on analysis, the next step should be to identify key stakeholders and constraints.";
        },
        functionName: "mock_reasoning",
        description: "Mock reasoning function for problem solving"
    );
}

// Solution synthesis function using prompt templates
private static KernelFunction CreateSolutionSynthesisFunction(Kernel kernel)
{
    var prompt = @"
Synthesize a comprehensive solution based on ReAct analysis:

Problem: {{$problem_title}}
Description: {{$problem_description}}
Solver Mode: {{$solver_mode}}

Based on the ReAct reasoning, action planning, and observation:

1. Synthesize key insights from analysis
2. Prioritize the most effective actions
3. Create implementation roadmap
4. Identify success metrics
5. Highlight potential risks and mitigation

Provide comprehensive solution synthesis:";

    return kernel.CreateFunctionFromPrompt(
        prompt,
        functionName: "solution_synthesis",
        description: "Synthesizes comprehensive solutions from ReAct analysis"
    );
}

// Constraint analysis function with mock implementation
private static KernelFunction CreateConstraintAnalysisFunction(Kernel kernel)
{
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var problemDescription = args["problem_description"]?.ToString()
                ?? args["task_description"]?.ToString()
                ?? "unknown problem";
            var domain = args["domain"]?.ToString() ?? "general";

            var analysis = $"Constraint analysis for domain '{domain}':\n" +
                           "1) Resource constraints: Budget, time, personnel must be prioritized across phases; enforce strict scope control and staged funding.\n" +
                           "2) Technical constraints: Legacy systems and integrations require strangler patterns, API gateways, and phased modernization with strong observability.\n" +
                           "3) Organizational constraints: Change management, capability gaps, and training cadence must be embedded into the plan; designate transformation champions.\n" +
                           "4) Regulatory constraints: Data residency, privacy, and auditability shape architecture choices; implement policy-as-code and compliance-by-design.\n" +
                           "5) Market constraints: Customer expectations and competitive benchmarks set minimum viable feature baselines and SLAs.\n" +
                           "6) Risk tolerance: Define acceptable risk bands and mitigation triggers; adopt progressive rollouts and kill-switches.\n\n" +
                           $"Context considered: {problemDescription.Substring(0, Math.Min(200, problemDescription.Length))}...";

            return analysis;
        },
        functionName: "constraint_analysis",
        description: "Analyzes constraints and limitations"
    );
}
```

### 8. 收斂邏輯和迭代控制

範例為迭代優化實現了複雜的收斂檢查。

```csharp
// Determines if iteration should continue based on convergence criteria
private static bool ShouldContinueIterating(KernelArguments args)
{
    // Robust convergence check: tolerate int/double/string values
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

// Convergence check function
private static KernelFunction CreateConvergenceCheckFunction(Kernel kernel)
{
    // Use a deterministic, method-based function to avoid external LLM dependency and
    // eliminate transient failures (e.g., HTTP 503) in example runs.
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var shouldContinue = ShouldContinueIterating(args);
            var iteration = args.GetValueOrDefault("iteration_count", 1)?.ToString();
            var quality = args.GetValueOrDefault("quality_score", 0.0)?.ToString();
            var threshold = args.GetValueOrDefault("convergence_threshold", 0.85)?.ToString();

            return shouldContinue
                ? $"Convergence check (iteration {iteration}): quality={quality}, threshold={threshold}. Not converged yet — continue refinement."
                : $"Convergence check (iteration {iteration}): quality={quality}, threshold={threshold}. Converged — finalize solution.";
        },
        functionName: "convergence_check",
        description: "Checks if solution has converged to acceptable quality without external calls"
    );
}

## 高級模式

### 多目標問題解決

```csharp
// Implement multi-objective optimization with weighted scoring
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

// Solve multi-objective problem
var multiObjectiveResult = await multiObjectiveAgent.SolveAsync(kernel, multiObjectiveArgs);
```

### 自適應問題分解

```csharp
// Implement adaptive problem decomposition based on complexity
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

// Automatically decompose complex problems
var decomposition = await adaptiveDecomposer.DecomposeAsync(problemStatement);
var decomposedGraph = await adaptiveDecomposer.CreateDecomposedGraphAsync(decomposition);
```

### 協作問題解決

```csharp
// Implement collaborative problem solving with multiple agents
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

// Solve problem collaboratively
var collaborativeResult = await collaborativeSolver.SolveCollaborativelyAsync(kernel, collaborativeArgs);
```
```

## 預期輸出

範例產生全面的輸出，展示：

* 🎯 **基礎問題解決**：對預算規劃、系統效能和團隊生產力問題的系統化分析
* 🔍 **複雜多步驟分析**：針對數位轉型的全面利益相關者分析、約束條件評估和風險評估
* 🔄 **迭代優化**：客戶服務最佳化，包括反饋迴圈和收斂檢查
* 💡 **解決方案綜合**：可行的實施路線圖，包含成功指標和風險緩解
* 📊 **利益相關者管理**：關鍵方的識別和溝通策略
* ⚠️ **風險評估**：包含緩解策略的全面風險評估
* 🚀 **實施規劃**：包含資源分配和時間表的詳細執行計劃

## 故障排除

### 常見問題

1. **LLM API 故障**：範例使用 mock 函數來避免外部依賴
2. **狀態映射錯誤**：驗證 Node 之間的輸入/輸出映射
3. **收斂問題**：檢查迭代限制和品質閾值
4. **操作選擇故障**：確保 Kernel 具有適合 ActionGraphNode 的函數

### 除錯提示

* 在 AfterExecute 元資料處理程式中監控狀態轉換
* 驗證收斂邏輯和迭代計數
* 檢查迭代工作流的條件 Edge 路由
* 驗證 Node 之間的函數輸入和輸出

### 效能考量

* 使用 mock 函數進行確定性測試
* 實現適當的迭代限制以防止無限迴圈
* 在迭代優化期間監控狀態大小增長
* 考慮對長時間執行的迭代工作流進行檢查點

## 另請參閱

* [ReAct Pattern](../concepts/react-pattern.md)
* [Action Nodes](../concepts/action-nodes.md)
* [Conditional Routing](../concepts/conditional-routing.md)
* [State Management](../concepts/state.md)
* [Graph Execution](../concepts/graph-execution.md)
* [ReAct Agent Example](./react-agent.md)
* [Problem Solving Patterns](../patterns/problem-solving.md)
