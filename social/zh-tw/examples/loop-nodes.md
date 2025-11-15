# 迴圈節點範例

此範例示範如何在 Semantic Kernel Graph 工作流程中實現各種迴圈模式。它展示如何使用不同的迴圈節點類型來建立受控迴圈、反覆處理和基於迴圈的決策。

## 目標

學習如何在圖形工作流程中實現迴圈模式以：
* 建立具有退出條件的受控迴圈
* 實現具有狀態管理的反覆處理
* 處理基於迴圈的決策和路由
* 管理迴圈效能和資源消耗
* 實現迴圈監控和偵錯

## 先決條件

* **.NET 8.0** 或更新版本
* 在 `appsettings.json` 中配置的 **OpenAI API 金鑰**
* 已安裝 **Semantic Kernel Graph 套件**
* 對 [圖形概念](../concepts/graph-concepts.md) 和 [迴圈模式](../concepts/loops.md) 的基本理解

## 主要元件

### 概念與技術

* **迴圈控制**：管理迴圈執行和退出條件
* **反覆處理**：在重複週期中處理資料
* **狀態管理**：在迴圈反覆之間維護狀態
* **迴圈監控**：追蹤迴圈效能和進度
* **資源管理**：控制迴圈中的資源消耗

### 核心類別

* `LoopGraphNode`：基礎迴圈節點實現
* `ReActLoopGraphNode`：推理和動作迴圈模式
* `IterativeGraphNode`：簡單反覆處理
* `LoopControlManager`：迴圈執行控制
* `LoopPerformanceMetrics`：迴圈效能監控

## 執行範例

### 開始使用

此範例使用 Semantic Kernel Graph 套件示範迴圈控制和反覆模式。下面的程式碼片段展示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本迴圈實現

此範例示範基本迴圈建立和控制。

```csharp
// Minimal while-loop example using the documented loop node API.
// This snippet is compatible with the examples project and can be executed as a self-contained demo.

// Create a lightweight kernel for local execution
var kernel = Kernel.CreateBuilder().Build();

// Create a graph state and initialize counters
var state = new SemanticKernel.Graph.State.GraphState();
state.SetValue("counter", 0);
state.SetValue("max_count", 5);

// Create a WhileLoopGraphNode with a simple condition that reads from the GraphState
var whileLoop = new SemanticKernel.Graph.Nodes.WhileLoopGraphNode(
    condition: s => s.GetValue<int>("counter") < s.GetValue<int>("max_count"),
    maxIterations: 100,
    nodeId: "basic_while_loop",
    name: "basic_while_loop",
    description: "Increments counter until max_count"
);

// Create a KernelFunction that increments the captured GraphState counter
var incrementFn = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
{
    var current = state.GetValue<int>("counter");
    state.SetValue("counter", current + 1);
    return $"counter={current + 1}";
}, "doc_increment", "Increment counter");

var incrementNode = new SemanticKernel.Graph.Nodes.FunctionGraphNode(incrementFn, "increment_node");

// Add the increment node to the loop and execute
whileLoop.AddLoopNode(incrementNode);

Console.WriteLine("🔄 Testing basic while-loop implementation...");
var iterations = await whileLoop.ExecuteAsync(kernel, state.KernelArguments);

Console.WriteLine($"   Total Iterations: {iterations}");
Console.WriteLine($"   Final counter: {state.GetValue<int>("counter")}");
```

### 2. ReAct 迴圈模式

示範用於反覆問題解決的推理和動作迴圈模式。

```csharp
// Create ReAct loop workflow
var reActLoopWorkflow = new GraphExecutor("ReActLoopWorkflow", "ReAct loop pattern implementation", logger);

// Configure ReAct loop options
var reActLoopOptions = new ReActLoopOptions
{
    MaxIterations = 8,
    EnableReasoningValidation = true,
    EnableActionValidation = true,
    EnableGoalTracking = true,
    EnableProgressMonitoring = true,
    ReasoningTimeout = TimeSpan.FromSeconds(30),
    ActionTimeout = TimeSpan.FromSeconds(60)
};

reActLoopWorkflow.ConfigureReActLoop(reActLoopOptions);

// ReAct reasoning node (KernelFunction wrapper). Replace body with real reasoning logic as needed.
var reActReasoning = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // Example: read inputs from args and return a reasoning summary string.
        // Replace with actual reasoning implementation that updates graph state when running inside executor.
        return "Reasoning completed";
    }, "react_reasoning_fn", "Perform reasoning step"),
    "react-reasoning",
    "Perform reasoning step in ReAct loop");

// ReAct action node (KernelFunction wrapper). Replace body with action execution logic.
var reActAction = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // Execute action based on reasoning outputs (placeholder)
        return "Action executed";
    }, "react_action_fn", "Execute action"),
    "react-action",
    "Execute action based on reasoning");

// ReAct controller node (KernelFunction wrapper). Implement loop control logic here.
var reActController = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // Determine continuation / goal achieved based on action outputs (placeholder)
        return "Controller evaluated";
    }, "react_controller_fn", "Control ReAct loop"),
    "react-controller",
    "Control ReAct loop execution and determine continuation");

// Add nodes to ReAct workflow
reActLoopWorkflow.AddNode(reActReasoning);
reActLoopWorkflow.AddNode(reActAction);
reActLoopWorkflow.AddNode(reActController);

// Set start node
reActLoopWorkflow.SetStartNode(reActReasoning.NodeId);

// Test ReAct loop
Console.WriteLine("🧠 Testing ReAct loop pattern...");

var reActArguments = new KernelArguments
{
    ["iteration"] = 0,
    ["max_iterations"] = 6,
    ["problem"] = "Solve a complex mathematical problem step by step",
    ["current_state"] = "initial",
    ["previous_actions"] = new List<string>()
};

var reActResult = await reActLoopWorkflow.ExecuteAsync(kernel, reActArguments);

var reActSummary = reActResult.GetValue<Dictionary<string, object>>("react_summary");
var iteration = reActResult.GetValue<int>("iteration");
var goalAchieved = reActResult.GetValue<bool>("goal_achieved");

Console.WriteLine($"   Iteration: {iteration}");
Console.WriteLine($"   Goal Achieved: {goalAchieved}");
Console.WriteLine($"   Summary: {string.Join(", ", reActSummary.Select(kvp => $"{kvp.Key}={kvp.Value}"))}");
```

### 3. 反覆處理迴圈

展示如何使用資料轉換實現反覆處理。

```csharp
// Create iterative processing workflow
var iterativeWorkflow = new GraphExecutor("IterativeWorkflow", "Iterative data processing", logger);

// Configure iterative processing options
var iterativeOptions = new IterativeProcessingOptions
{
    MaxIterations = 15,
    EnableBatchProcessing = true,
    EnableProgressTracking = true,
    EnableQualityMetrics = true,
    BatchSize = 5,
    QualityThreshold = 0.8
};

iterativeWorkflow.ConfigureIterativeProcessing(iterativeOptions);

// Data generator node
var dataGenerator = new FunctionGraphNode(
    "data-generator",
    "Generate data for iterative processing",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration", 0);
        var batchSize = context.GetValue<int>("batch_size", 5);
        
        // Generate sample data
        var data = new List<string>();
        for (int i = 0; i < batchSize; i++)
        {
            data.Add($"Data_{iteration}_{i}_{DateTime.UtcNow:HHmmss}");
        }
        
        context.SetValue("generated_data", data);
        context.SetValue("data_count", data.Count);
        context.SetValue("generation_timestamp", DateTime.UtcNow);
        
        return $"Generated {data.Count} data items for iteration {iteration}";
    });

// Data processor node
var dataProcessor = new FunctionGraphNode(
    "data-processor",
    "Process data in current iteration",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration");
        var generatedData = context.GetValue<List<string>>("generated_data");
        var batchSize = context.GetValue<int>("batch_size");
        
        // Simulate data processing
        await Task.Delay(Random.Shared.Next(200, 600));
        
        var processedData = new List<string>();
        var processingQuality = new List<double>();
        
        foreach (var data in generatedData)
        {
            var processed = $"Processed_{data}";
            processedData.Add(processed);
            
            // Simulate quality score
            var quality = Random.Shared.NextDouble();
            processingQuality.Add(quality);
        }
        
        // Calculate quality metrics
        var averageQuality = processingQuality.Average();
        var qualityThreshold = context.GetValue<double>("quality_threshold", 0.8);
        var qualityMet = averageQuality >= qualityThreshold;
        
        // Update processing state
        context.SetValue("processed_data", processedData);
        context.SetValue("processing_quality", processingQuality);
        context.SetValue("average_quality", averageQuality);
        context.SetValue("quality_threshold_met", qualityMet);
        context.SetValue("processing_complete", true);
        
        return $"Processed {processedData.Count} items with quality {averageQuality:F2}";
    });

// Iteration controller
var iterationController = new FunctionGraphNode(
    "iteration-controller",
    "Control iteration flow and determine continuation",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration");
        var maxIterations = context.GetValue<int>("max_iterations", 15);
        var qualityThresholdMet = context.GetValue<bool>("quality_threshold_met");
        var averageQuality = context.GetValue<double>("average_quality");
        
        // Determine if iteration should continue
        var shouldContinue = iteration < maxIterations && qualityThresholdMet;
        var iterationComplete = !shouldContinue;
        
        // Update iteration state
        context.SetValue("should_continue", shouldContinue);
        context.SetValue("iteration_complete", iterationComplete);
        
        if (shouldContinue)
        {
            context.SetValue("next_iteration", iteration + 1);
        }
        
        // Update iteration summary
        var iterationSummary = new Dictionary<string, object>
        {
            ["current_iteration"] = iteration,
            ["max_iterations"] = maxIterations,
            ["quality_threshold_met"] = qualityThresholdMet,
            ["average_quality"] = averageQuality,
            ["should_continue"] = shouldContinue,
            ["iteration_complete"] = iterationComplete
        };
        
        context.SetValue("iteration_summary", iterationSummary);
        
        return $"Iteration {iteration} control: Continue={shouldContinue}";
    });

// Add nodes to iterative workflow
iterativeWorkflow.AddNode(dataGenerator);
iterativeWorkflow.AddNode(dataProcessor);
iterativeWorkflow.AddNode(iterationController);

// Set start node
iterativeWorkflow.SetStartNode(dataGenerator.NodeId);

// Test iterative processing
Console.WriteLine("📊 Testing iterative processing...");

var iterativeArguments = new KernelArguments
{
    ["iteration"] = 0,
    ["max_iterations"] = 8,
    ["batch_size"] = 3,
    ["quality_threshold"] = 0.75
};

var iterativeResult = await iterativeWorkflow.ExecuteAsync(kernel, iterativeArguments);

var iterationSummary = iterativeResult.GetValue<Dictionary<string, object>>("iteration_summary");
var currentIteration = iterativeResult.GetValue<int>("current_iteration");
var qualityThresholdMet = iterativeResult.GetValue<bool>("quality_threshold_met");

Console.WriteLine($"   Current Iteration: {currentIteration}");
Console.WriteLine($"   Quality Threshold Met: {qualityThresholdMet}");
Console.WriteLine($"   Summary: {string.Join(", ", iterationSummary.Select(kvp => $"{kvp.Key}={kvp.Value}"))}");
```

### 4. 進階迴圈模式

示範進階迴圈模式，包括巢狀迴圈和條件迴圈。

```csharp
// Create advanced loop workflow
var advancedLoopWorkflow = new GraphExecutor("AdvancedLoopWorkflow", "Advanced loop patterns", logger);

// Configure advanced loop options
var advancedLoopOptions = new AdvancedLoopOptions
{
    EnableNestedLoops = true,
    EnableConditionalLoops = true,
    EnableLoopOptimization = true,
    EnableResourceMonitoring = true,
    MaxNestingDepth = 3,
    ResourceThreshold = 0.8
};

advancedLoopWorkflow.ConfigureAdvancedLoop(advancedLoopOptions);

// Nested loop controller
var nestedLoopController = new FunctionGraphNode(
    "nested-loop-controller",
    "Control nested loop execution",
    async (context) =>
    {
        var outerIteration = context.GetValue<int>("outer_iteration", 0);
        var innerIteration = context.GetValue<int>("inner_iteration", 0);
        var maxOuterIterations = context.GetValue<int>("max_outer_iterations", 3);
        var maxInnerIterations = context.GetValue<int>("max_inner_iterations", 4);
        
        // Determine loop flow
        var outerComplete = outerIteration >= maxOuterIterations;
        var innerComplete = innerIteration >= maxInnerIterations;
        
        if (!outerComplete)
        {
            if (!innerComplete)
            {
                // Continue inner loop
                context.SetValue("next_inner_iteration", innerIteration + 1);
                context.SetValue("loop_level", "inner");
            }
            else
            {
                // Move to next outer iteration
                context.SetValue("next_outer_iteration", outerIteration + 1);
                context.SetValue("next_inner_iteration", 0);
                context.SetValue("loop_level", "outer");
            }
        }
        
        // Update loop state
        context.SetValue("outer_complete", outerComplete);
        context.SetValue("inner_complete", innerComplete);
        context.SetValue("nested_loop_complete", outerComplete);
        
        var loopState = new Dictionary<string, object>
        {
            ["outer_iteration"] = outerIteration,
            ["inner_iteration"] = innerIteration,
            ["loop_level"] = context.GetValue<string>("loop_level", "unknown"),
            ["outer_complete"] = outerComplete,
            ["inner_complete"] = innerComplete,
            ["nested_loop_complete"] = nestedLoopComplete
        };
        
        context.SetValue("nested_loop_state", loopState);
        
        return $"Nested loop: Outer={outerIteration}, Inner={innerIteration}, Level={loopState["loop_level"]}";
    });

// Conditional loop processor
var conditionalLoopProcessor = new FunctionGraphNode(
    "conditional-loop-processor",
    "Process data with conditional loop logic",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration", 0);
        var condition = context.GetValue<string>("condition", "default");
        var data = context.GetValue<string>("data", "sample");
        
        // Simulate conditional processing
        await Task.Delay(Random.Shared.Next(150, 400));
        
        var processingResult = "";
        var shouldContinue = false;
        
        switch (condition)
        {
            case "quality_check":
                var quality = Random.Shared.NextDouble();
                processingResult = $"Quality check result: {quality:F2}";
                shouldContinue = quality < 0.9; // Continue if quality < 90%
                break;
                
            case "convergence_check":
                var convergence = Random.Shared.NextDouble();
                processingResult = $"Convergence result: {convergence:F2}";
                shouldContinue = convergence < 0.95; // Continue if convergence < 95%
                break;
                
            case "error_check":
                var error = Random.Shared.NextDouble();
                processingResult = $"Error check result: {error:F2}";
                shouldContinue = error > 0.1; // Continue if error > 10%
                break;
                
            default:
                processingResult = $"Default processing: {data}";
                shouldContinue = iteration < 5; // Default limit
                break;
        }
        
        // Update conditional state
        context.SetValue("processing_result", processingResult);
        context.SetValue("should_continue", shouldContinue);
        context.SetValue("condition_met", !shouldContinue);
        context.SetValue("conditional_processing_complete", true);
        
        return processingResult;
    });

// Add nodes to advanced workflow
advancedLoopWorkflow.AddNode(nestedLoopController);
advancedLoopWorkflow.AddNode(conditionalLoopProcessor);

// Set start node
advancedLoopWorkflow.SetStartNode(nestedLoopController.NodeId);

// Test advanced loop patterns
Console.WriteLine("🚀 Testing advanced loop patterns...");

var advancedArguments = new KernelArguments
{
    ["outer_iteration"] = 0,
    ["inner_iteration"] = 0,
    ["max_outer_iterations"] = 3,
    ["max_inner_iterations"] = 4,
    ["condition"] = "quality_check",
    ["data"] = "Advanced loop data"
};

var advancedResult = await advancedLoopWorkflow.ExecuteAsync(kernel, advancedArguments);

var nestedLoopState = advancedResult.GetValue<Dictionary<string, object>>("nested_loop_state");
var conditionalProcessingComplete = advancedResult.GetValue<bool>("conditional_processing_complete");

Console.WriteLine($"   Nested Loop State: {string.Join(", ", nestedLoopState.Select(kvp => $"{kvp.Key}={kvp.Value}"))}");
Console.WriteLine($"   Conditional Processing Complete: {conditionalProcessingComplete}");
```

## 預期輸出

### 基本迴圈實現範例

```
🔄 Testing basic loop implementation...
   Total Iterations: 5
   Loop Complete: True
   Summary Keys: total_iterations, last_processed_data, last_processing_result, loop_complete, completion_timestamp
```

### ReAct 迴圈模式範例

```
🧠 Testing ReAct loop pattern...
   Iteration: 6
   Goal Achieved: False
   Summary: iteration=6, action_success=True, new_state=State_6, should_continue=False, goal_achieved=False, loop_complete=True
```

### 反覆處理範例

```
📊 Testing iterative processing...
   Current Iteration: 8
   Quality Threshold Met: True
   Summary: current_iteration=8, max_iterations=8, quality_threshold_met=True, average_quality=0.82, should_continue=False, iteration_complete=True
```

### 進階迴圈模式範例

```
🚀 Testing advanced loop patterns...
   Nested Loop State: outer_iteration=0, inner_iteration=0, loop_level=inner, outer_complete=False, inner_complete=False, nested_loop_complete=False
   Conditional Processing Complete: True
```

## 設定選項

### 迴圈設定

```csharp
var loopOptions = new LoopOptions
{
    MaxIterations = 10,                           // 最大反覆次數
    EnableLoopMonitoring = true,                   // 啟用迴圈監控
    EnablePerformanceMetrics = true,               // 啟用效能度量
    EnableStatePersistence = true,                 // 啟用狀態持久化
    LoopTimeout = TimeSpan.FromMinutes(5),         // 迴圈執行逾時
    EnableResourceMonitoring = true,               // 監控資源使用
    ResourceThreshold = 0.8,                       // 資源使用閾值
    EnableLoopOptimization = true,                 // 啟用迴圈最佳化
    EnableNestedLoops = true,                      // 允許巢狀迴圈
    MaxNestingDepth = 3                           // 最大巢狀深度
};
```

### ReAct 迴圈設定

```csharp
var reActLoopOptions = new ReActLoopOptions
{
    MaxIterations = 8,                             // 最大推理-動作週期數
    EnableReasoningValidation = true,               // 驗證推理步驟
    EnableActionValidation = true,                  // 驗證動作結果
    EnableGoalTracking = true,                      // 追蹤目標實現
    EnableProgressMonitoring = true,                // 監控進度
    ReasoningTimeout = TimeSpan.FromSeconds(30),    // 推理步驟逾時
    ActionTimeout = TimeSpan.FromSeconds(60),       // 動作執行逾時
    EnableConfidenceScoring = true,                 // 推理信心評分
    EnableActionSuccessTracking = true,             // 追蹤動作成功率
    GoalAchievementThreshold = 0.9                 // 目標實現閾值
};
```

### 反覆處理設定

```csharp
var iterativeOptions = new IterativeProcessingOptions
{
    MaxIterations = 15,                             // 最大反覆次數
    EnableBatchProcessing = true,                    // 啟用批次處理
    EnableProgressTracking = true,                   // 追蹤進度
    EnableQualityMetrics = true,                    // 追蹤品質度量
    BatchSize = 5,                                  // 每批項目數
    QualityThreshold = 0.8,                         // 品質閾值
    EnableConvergenceChecking = true,               // 檢查收斂
    ConvergenceThreshold = 0.001,                   // 收斂閾值
    EnableErrorTracking = true,                     // 追蹤錯誤
    ErrorThreshold = 0.1                            // 錯誤閾值
};
```

## 疑難排解

### 常見問題

#### 無限迴圈
```bash
# 問題：迴圈無限執行
# 解決方案：設定適當的退出條件和最大反覆次數
MaxIterations = 10;
EnableLoopMonitoring = true;
LoopTimeout = TimeSpan.FromMinutes(5);
```

#### 效能問題
```bash
# 問題：迴圈效能隨著反覆而降低
# 解決方案：啟用最佳化和資源監控
EnableLoopOptimization = true;
EnableResourceMonitoring = true;
ResourceThreshold = 0.8;
```

#### 狀態損毀
```bash
# 問題：迴圈狀態損毀
# 解決方案：啟用狀態持久化和驗證
EnableStatePersistence = true;
EnableStateValidation = true;
EnableStateRecovery = true;
```

### 偵錯模式

啟用詳細的迴圈監控以進行疑難排解：

```csharp
// Enable debug loop monitoring
var debugLoopOptions = new LoopOptions
{
    MaxIterations = 10,
    EnableLoopMonitoring = true,
    EnablePerformanceMetrics = true,
    EnableDebugLogging = true,
    EnableStateInspection = true,
    EnableLoopVisualization = true,
    LogLoopIterations = true,
    LogLoopState = true
};
```

## 進階模式

### 自訂迴圈控制器

```csharp
// Implement custom loop controller
public class CustomLoopController : ILoopController
{
    public async Task<LoopControlDecision> ShouldContinueAsync(LoopContext context)
    {
        var iteration = context.GetValue<int>("iteration");
        var customCondition = context.GetValue<string>("custom_condition");
        
        // Custom loop logic
        switch (customCondition)
        {
            case "adaptive":
                return await HandleAdaptiveLoop(context);
            case "quality_based":
                return await HandleQualityBasedLoop(context);
            case "resource_based":
                return await HandleResourceBasedLoop(context);
            default:
                return new LoopControlDecision { ShouldContinue = iteration < 10 };
        }
    }
    
    private async Task<LoopControlDecision> HandleAdaptiveLoop(LoopContext context)
    {
        // Implement adaptive loop logic
        var performance = context.GetValue<double>("performance", 0.0);
        var shouldContinue = performance < 0.9;
        
        return new LoopControlDecision 
        { 
            ShouldContinue = shouldContinue,
            Reason = $"Performance {performance:F2} below threshold 0.9"
        };
    }
}
```

### 迴圈效能最佳化

```csharp
// Implement loop performance optimizer
public class LoopPerformanceOptimizer : ILoopOptimizer
{
    public async Task<LoopOptimizationResult> OptimizeLoopAsync(LoopContext context)
    {
        var optimization = new LoopOptimizationResult();
        
        // Analyze loop performance
        var iterations = context.GetValue<int>("iteration");
        var averageTime = context.GetValue<double>("average_iteration_time");
        var resourceUsage = context.GetValue<double>("resource_usage");
        
        // Suggest optimizations
        if (averageTime > 1000) // More than 1 second
        {
            optimization.Suggestions.Add("Consider reducing processing complexity");
            optimization.Suggestions.Add("Enable parallel processing if possible");
        }
        
        if (resourceUsage > 0.8) // More than 80%
        {
            optimization.Suggestions.Add("Reduce batch size");
            optimization.Suggestions.Add("Implement resource throttling");
        }
        
        if (iterations > 20)
        {
            optimization.Suggestions.Add("Consider early termination conditions");
            optimization.Suggestions.Add("Implement convergence checking");
        }
        
        return optimization;
    }
}
```

### 迴圈狀態管理

```csharp
// Implement advanced loop state management
public class AdvancedLoopStateManager : ILoopStateManager
{
    public async Task<LoopState> GetLoopStateAsync(string loopId)
    {
        // Retrieve loop state from persistent storage
        var state = await LoadStateFromStorage(loopId);
        
        // Validate state integrity
        if (!await ValidateStateIntegrity(state))
        {
            state = await RecoverState(loopId);
        }
        
        return state;
    }
    
    public async Task SaveLoopStateAsync(string loopId, LoopState state)
    {
        // Add metadata
        state.Metadata["last_updated"] = DateTime.UtcNow;
        state.Metadata["version"] = state.Version + 1;
        
        // Compress state if large
        if (state.Size > 1024 * 1024) // 1MB
        {
            state = await CompressState(state);
        }
        
        // Save to persistent storage
        await SaveStateToStorage(loopId, state);
    }
}
```

## 相關範例

* [ReAct 代理](./react-agent.md)：進階推理和動作模式
* [圖形度量](./graph-metrics.md)：迴圈效能監控
* [狀態管理](./state-tutorial.md)：迴圈狀態持久化
* [效能最佳化](./performance-optimization.md)：迴圈最佳化技術

## 另請參閱

* [迴圈模式](../concepts/loops.md)：瞭解迴圈概念
* [效能監控](../how-to/performance-monitoring.md)：迴圈效能分析
* [狀態管理](../how-to/state-management.md)：迴圈狀態處理
* [API 參考](../api/)：完整 API 文件
