# Loop Nodes 範例

本範例示範如何在 Semantic Kernel Graph 工作流中實現各種類型的迴圈模式。它展示了如何使用不同的 Loop Node 類型建立受控迴圈、反覆式處理和基於迴圈的決策制定。

## 目標

學習如何在基於 Graph 的工作流中實現迴圈模式，以：
* 建立具有結束條件的受控迴圈
* 實現具有狀態管理的反覆式處理
* 處理基於迴圈的決策制定和路由
* 管理迴圈效能和資源消耗
* 實現迴圈監控和除錯

## 先決條件

* **.NET 8.0** 或更新版本
* 在 `appsettings.json` 中設定的 **OpenAI API Key**
* 已安裝 **Semantic Kernel Graph 套件**
* 對 [Graph 概念](../concepts/graph-concepts.md) 和 [Loop 模式](../concepts/loops.md) 的基本了解

## 關鍵元件

### 概念和技術

* **Loop Control**：管理迴圈執行和結束條件
* **Iterative Processing**：在重複週期中處理資料
* **State Management**：在迴圈反覆運算中維持狀態
* **Loop Monitoring**：追蹤迴圈效能和進度
* **Resource Management**：控制迴圈中的資源消耗

### Core Classes

* `LoopGraphNode`：基本 Loop Node 實現
* `ReActLoopGraphNode`：推理和操作迴圈模式
* `IterativeGraphNode`：簡單反覆式處理
* `LoopControlManager`：迴圈執行控制
* `LoopPerformanceMetrics`：迴圈效能監控

## 執行範例

### 開始使用

本範例使用 Semantic Kernel Graph 套件示範迴圈控制和反覆運算模式。下面的程式碼片段展示如何在您的應用程式中實現這個模式。

## 逐步實現

### 1. 基本 Loop 實現

本範例示範基本迴圈建立和控制。

```csharp
// 使用記錄的 Loop Node API 的最小 while-loop 範例。
// 此片段與範例專案相容，可以作為獨立的示範執行。

// 為本機執行建立輕量級 Kernel
var kernel = Kernel.CreateBuilder().Build();

// 建立 Graph 狀態並初始化計數器
var state = new SemanticKernel.Graph.State.GraphState();
state.SetValue("counter", 0);
state.SetValue("max_count", 5);

// 建立 WhileLoopGraphNode，條件從 GraphState 讀取
var whileLoop = new SemanticKernel.Graph.Nodes.WhileLoopGraphNode(
    condition: s => s.GetValue<int>("counter") < s.GetValue<int>("max_count"),
    maxIterations: 100,
    nodeId: "basic_while_loop",
    name: "basic_while_loop",
    description: "Increments counter until max_count"
);

// 建立 KernelFunction 來遞增捕獲的 GraphState 計數器
var incrementFn = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
{
    var current = state.GetValue<int>("counter");
    state.SetValue("counter", current + 1);
    return $"counter={current + 1}";
}, "doc_increment", "Increment counter");

var incrementNode = new SemanticKernel.Graph.Nodes.FunctionGraphNode(incrementFn, "increment_node");

// 將遞增 Node 新增至迴圈並執行
whileLoop.AddLoopNode(incrementNode);

Console.WriteLine("🔄 Testing basic while-loop implementation...");
var iterations = await whileLoop.ExecuteAsync(kernel, state.KernelArguments);

Console.WriteLine($"   Total Iterations: {iterations}");
Console.WriteLine($"   Final counter: {state.GetValue<int>("counter")}");
```

### 2. ReAct Loop 模式

示範用於反覆式問題解決的推理和操作迴圈模式。

```csharp
// 建立 ReAct Loop 工作流
var reActLoopWorkflow = new GraphExecutor("ReActLoopWorkflow", "ReAct loop pattern implementation", logger);

// 設定 ReAct Loop 選項
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

// ReAct 推理 Node (KernelFunction 包裝)。根據需要用實際推理邏輯取代主體。
var reActReasoning = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // 範例：從 args 讀取輸入並傳回推理摘要字串。
        // 取代為實際的推理實現，在執行器內執行時更新 Graph 狀態。
        return "Reasoning completed";
    }, "react_reasoning_fn", "Perform reasoning step"),
    "react-reasoning",
    "Perform reasoning step in ReAct loop");

// ReAct 操作 Node (KernelFunction 包裝)。根據需要用操作執行邏輯取代主體。
var reActAction = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // 根據推理輸出執行操作 (預留位置)
        return "Action executed";
    }, "react_action_fn", "Execute action"),
    "react-action",
    "Execute action based on reasoning");

// ReAct 控制器 Node (KernelFunction 包裝)。在此實現迴圈控制邏輯。
var reActController = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        // 根據操作輸出判斷繼續 / 達成目標 (預留位置)
        return "Controller evaluated";
    }, "react_controller_fn", "Control ReAct loop"),
    "react-controller",
    "Control ReAct loop execution and determine continuation");

// 將 Node 新增至 ReAct 工作流
reActLoopWorkflow.AddNode(reActReasoning);
reActLoopWorkflow.AddNode(reActAction);
reActLoopWorkflow.AddNode(reActController);

// 設定起始 Node
reActLoopWorkflow.SetStartNode(reActReasoning.NodeId);

// 測試 ReAct Loop
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

### 3. 反覆式處理迴圈

展示如何使用資料轉換實現反覆式處理。

```csharp
// 建立反覆式處理工作流
var iterativeWorkflow = new GraphExecutor("IterativeWorkflow", "Iterative data processing", logger);

// 設定反覆式處理選項
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

// 資料產生器 Node
var dataGenerator = new FunctionGraphNode(
    "data-generator",
    "Generate data for iterative processing",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration", 0);
        var batchSize = context.GetValue<int>("batch_size", 5);
        
        // 產生樣本資料
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

// 資料處理器 Node
var dataProcessor = new FunctionGraphNode(
    "data-processor",
    "Process data in current iteration",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration");
        var generatedData = context.GetValue<List<string>>("generated_data");
        var batchSize = context.GetValue<int>("batch_size");
        
        // 模擬資料處理
        await Task.Delay(Random.Shared.Next(200, 600));
        
        var processedData = new List<string>();
        var processingQuality = new List<double>();
        
        foreach (var data in generatedData)
        {
            var processed = $"Processed_{data}";
            processedData.Add(processed);
            
            // 模擬品質分數
            var quality = Random.Shared.NextDouble();
            processingQuality.Add(quality);
        }
        
        // 計算品質指標
        var averageQuality = processingQuality.Average();
        var qualityThreshold = context.GetValue<double>("quality_threshold", 0.8);
        var qualityMet = averageQuality >= qualityThreshold;
        
        // 更新處理狀態
        context.SetValue("processed_data", processedData);
        context.SetValue("processing_quality", processingQuality);
        context.SetValue("average_quality", averageQuality);
        context.SetValue("quality_threshold_met", qualityMet);
        context.SetValue("processing_complete", true);
        
        return $"Processed {processedData.Count} items with quality {averageQuality:F2}";
    });

// 反覆運算控制器
var iterationController = new FunctionGraphNode(
    "iteration-controller",
    "Control iteration flow and determine continuation",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration");
        var maxIterations = context.GetValue<int>("max_iterations", 15);
        var qualityThresholdMet = context.GetValue<bool>("quality_threshold_met");
        var averageQuality = context.GetValue<double>("average_quality");
        
        // 判斷反覆運算是否應繼續
        var shouldContinue = iteration < maxIterations && qualityThresholdMet;
        var iterationComplete = !shouldContinue;
        
        // 更新反覆運算狀態
        context.SetValue("should_continue", shouldContinue);
        context.SetValue("iteration_complete", iterationComplete);
        
        if (shouldContinue)
        {
            context.SetValue("next_iteration", iteration + 1);
        }
        
        // 更新反覆運算摘要
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

// 將 Node 新增至反覆式工作流
iterativeWorkflow.AddNode(dataGenerator);
iterativeWorkflow.AddNode(dataProcessor);
iterativeWorkflow.AddNode(iterationController);

// 設定起始 Node
iterativeWorkflow.SetStartNode(dataGenerator.NodeId);

// 測試反覆式處理
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

### 4. 進階 Loop 模式

示範進階迴圈模式，包括巢狀迴圈和條件迴圈。

```csharp
// 建立進階 Loop 工作流
var advancedLoopWorkflow = new GraphExecutor("AdvancedLoopWorkflow", "Advanced loop patterns", logger);

// 設定進階 Loop 選項
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

// 巢狀迴圈控制器
var nestedLoopController = new FunctionGraphNode(
    "nested-loop-controller",
    "Control nested loop execution",
    async (context) =>
    {
        var outerIteration = context.GetValue<int>("outer_iteration", 0);
        var innerIteration = context.GetValue<int>("inner_iteration", 0);
        var maxOuterIterations = context.GetValue<int>("max_outer_iterations", 3);
        var maxInnerIterations = context.GetValue<int>("max_inner_iterations", 4);
        
        // 判斷迴圈流程
        var outerComplete = outerIteration >= maxOuterIterations;
        var innerComplete = innerIteration >= maxInnerIterations;
        
        if (!outerComplete)
        {
            if (!innerComplete)
            {
                // 繼續內迴圈
                context.SetValue("next_inner_iteration", innerIteration + 1);
                context.SetValue("loop_level", "inner");
            }
            else
            {
                // 移至下一個外迴圈反覆運算
                context.SetValue("next_outer_iteration", outerIteration + 1);
                context.SetValue("next_inner_iteration", 0);
                context.SetValue("loop_level", "outer");
            }
        }
        
        // 更新迴圈狀態
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

// 條件迴圈處理器
var conditionalLoopProcessor = new FunctionGraphNode(
    "conditional-loop-processor",
    "Process data with conditional loop logic",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration", 0);
        var condition = context.GetValue<string>("condition", "default");
        var data = context.GetValue<string>("data", "sample");
        
        // 模擬條件處理
        await Task.Delay(Random.Shared.Next(150, 400));
        
        var processingResult = "";
        var shouldContinue = false;
        
        switch (condition)
        {
            case "quality_check":
                var quality = Random.Shared.NextDouble();
                processingResult = $"Quality check result: {quality:F2}";
                shouldContinue = quality < 0.9; // 品質 < 90% 時繼續
                break;
                
            case "convergence_check":
                var convergence = Random.Shared.NextDouble();
                processingResult = $"Convergence result: {convergence:F2}";
                shouldContinue = convergence < 0.95; // 收斂 < 95% 時繼續
                break;
                
            case "error_check":
                var error = Random.Shared.NextDouble();
                processingResult = $"Error check result: {error:F2}";
                shouldContinue = error > 0.1; // 錯誤 > 10% 時繼續
                break;
                
            default:
                processingResult = $"Default processing: {data}";
                shouldContinue = iteration < 5; // 預設限制
                break;
        }
        
        // 更新條件狀態
        context.SetValue("processing_result", processingResult);
        context.SetValue("should_continue", shouldContinue);
        context.SetValue("condition_met", !shouldContinue);
        context.SetValue("conditional_processing_complete", true);
        
        return processingResult;
    });

// 將 Node 新增至進階工作流
advancedLoopWorkflow.AddNode(nestedLoopController);
advancedLoopWorkflow.AddNode(conditionalLoopProcessor);

// 設定起始 Node
advancedLoopWorkflow.SetStartNode(nestedLoopController.NodeId);

// 測試進階迴圈模式
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

### 基本 Loop 實現範例

```
🔄 Testing basic loop implementation...
   Total Iterations: 5
   Loop Complete: True
   Summary Keys: total_iterations, last_processed_data, last_processing_result, loop_complete, completion_timestamp
```

### ReAct Loop 模式範例

```
🧠 Testing ReAct loop pattern...
   Iteration: 6
   Goal Achieved: False
   Summary: iteration=6, action_success=True, new_state=State_6, should_continue=False, goal_achieved=False, loop_complete=True
```

### 反覆式處理範例

```
📊 Testing iterative processing...
   Current Iteration: 8
   Quality Threshold Met: True
   Summary: current_iteration=8, max_iterations=8, quality_threshold_met=True, average_quality=0.82, should_continue=False, iteration_complete=True
```

### 進階 Loop 模式範例

```
🚀 Testing advanced loop patterns...
   Nested Loop State: outer_iteration=0, inner_iteration=0, loop_level=inner, outer_complete=False, inner_complete=False, nested_loop_complete=False
   Conditional Processing Complete: True
```

## 設定選項

### Loop 設定

```csharp
var loopOptions = new LoopOptions
{
    MaxIterations = 10,                           // 最大反覆運算次數
    EnableLoopMonitoring = true,                   // 啟用迴圈監控
    EnablePerformanceMetrics = true,               // 啟用效能指標
    EnableStatePersistence = true,                 // 啟用狀態持久性
    LoopTimeout = TimeSpan.FromMinutes(5),         // 迴圈執行逾時
    EnableResourceMonitoring = true,               // 監控資源使用量
    ResourceThreshold = 0.8,                       // 資源使用閾值
    EnableLoopOptimization = true,                 // 啟用迴圈最佳化
    EnableNestedLoops = true,                      // 允許巢狀迴圈
    MaxNestingDepth = 3                           // 最大巢狀深度
};
```

### ReAct Loop 設定

```csharp
var reActLoopOptions = new ReActLoopOptions
{
    MaxIterations = 8,                             // 最大推理-操作週期
    EnableReasoningValidation = true,               // 驗證推理步驟
    EnableActionValidation = true,                  // 驗證操作結果
    EnableGoalTracking = true,                      // 追蹤目標達成
    EnableProgressMonitoring = true,                // 監控進度
    ReasoningTimeout = TimeSpan.FromSeconds(30),    // 推理步驟逾時
    ActionTimeout = TimeSpan.FromSeconds(60),       // 操作執行逾時
    EnableConfidenceScoring = true,                 // 推理信心評分
    EnableActionSuccessTracking = true,             // 追蹤操作成功率
    GoalAchievementThreshold = 0.9                 // 目標達成閾值
};
```

### 反覆式處理設定

```csharp
var iterativeOptions = new IterativeProcessingOptions
{
    MaxIterations = 15,                             // 最大反覆運算次數
    EnableBatchProcessing = true,                    // 啟用批次處理
    EnableProgressTracking = true,                   // 追蹤進度
    EnableQualityMetrics = true,                    // 追蹤品質指標
    BatchSize = 5,                                  // 每個批次的項目
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
# 解決方案：設定適當的結束條件和最大反覆運算次數
MaxIterations = 10;
EnableLoopMonitoring = true;
LoopTimeout = TimeSpan.FromMinutes(5);
```

#### 效能問題
```bash
# 問題：迴圈效能在反覆運算中逐漸下降
# 解決方案：啟用最佳化和資源監控
EnableLoopOptimization = true;
EnableResourceMonitoring = true;
ResourceThreshold = 0.8;
```

#### 狀態損毀
```bash
# 問題：迴圈狀態損毀
# 解決方案：啟用狀態持久性和驗證
EnableStatePersistence = true;
EnableStateValidation = true;
EnableStateRecovery = true;
```

### 除錯模式

啟用詳細的迴圈監控以進行疑難排解：

```csharp
// 啟用除錯迴圈監控
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

### 自訂 Loop 控制器

```csharp
// 實現自訂迴圈控制器
public class CustomLoopController : ILoopController
{
    public async Task<LoopControlDecision> ShouldContinueAsync(LoopContext context)
    {
        var iteration = context.GetValue<int>("iteration");
        var customCondition = context.GetValue<string>("custom_condition");
        
        // 自訂迴圈邏輯
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
        // 實現自適應迴圈邏輯
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

### Loop 效能最佳化

```csharp
// 實現迴圈效能最佳化程式
public class LoopPerformanceOptimizer : ILoopOptimizer
{
    public async Task<LoopOptimizationResult> OptimizeLoopAsync(LoopContext context)
    {
        var optimization = new LoopOptimizationResult();
        
        // 分析迴圈效能
        var iterations = context.GetValue<int>("iteration");
        var averageTime = context.GetValue<double>("average_iteration_time");
        var resourceUsage = context.GetValue<double>("resource_usage");
        
        // 建議最佳化
        if (averageTime > 1000) // 超過 1 秒
        {
            optimization.Suggestions.Add("Consider reducing processing complexity");
            optimization.Suggestions.Add("Enable parallel processing if possible");
        }
        
        if (resourceUsage > 0.8) // 超過 80%
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

### Loop 狀態管理

```csharp
// 實現進階迴圈狀態管理
public class AdvancedLoopStateManager : ILoopStateManager
{
    public async Task<LoopState> GetLoopStateAsync(string loopId)
    {
        // 從持久性存放區擷取迴圈狀態
        var state = await LoadStateFromStorage(loopId);
        
        // 驗證狀態完整性
        if (!await ValidateStateIntegrity(state))
        {
            state = await RecoverState(loopId);
        }
        
        return state;
    }
    
    public async Task SaveLoopStateAsync(string loopId, LoopState state)
    {
        // 新增中繼資料
        state.Metadata["last_updated"] = DateTime.UtcNow;
        state.Metadata["version"] = state.Version + 1;
        
        // 如果狀態很大，壓縮狀態
        if (state.Size > 1024 * 1024) // 1MB
        {
            state = await CompressState(state);
        }
        
        // 儲存至持久性存放區
        await SaveStateToStorage(loopId, state);
    }
}
```

## 相關範例

* [ReAct Agent](./react-agent.md)：進階推理和操作模式
* [Graph Metrics](./graph-metrics.md)：Loop 效能監控
* [State Management](./state-tutorial.md)：Loop 狀態持久性
* [Performance Optimization](./performance-optimization.md)：Loop 最佳化技術

## 另請參閱

* [Loop 模式](../concepts/loops.md)：了解 Loop 概念
* [效能監控](../how-to/performance-monitoring.md)：Loop 效能分析
* [狀態管理](../how-to/state-management.md)：Loop 狀態處理
* [API 參考](../api/)：完整 API 文件
