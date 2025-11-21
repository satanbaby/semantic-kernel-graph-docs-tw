# ReAct Agent 範例

此範例演示一個簡單且可擴展的 ReAct（推理 → 行動 → 觀察）Agent，可靈活擴展以支援多種工具。

## 目標

學習如何在基於圖形的工作流程中實現 ReAct Agent 模式，以：
* 建立一個最小的推理 → 行動 → 觀察迴圈
* 實現可擴展的工具註冊和發現
* 展示智能的行動選擇和執行
* 演示如何在不修改 Agent 結構的情況下新增工具
* 實現參數驗證和智能工具匹配

## 前置需求

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 基本了解 [Graph Concepts](../concepts/graph-concepts.md) 和 [ReAct Patterns](../patterns/react.md)
* 熟悉 [Action Nodes](../concepts/node-types.md)

## 主要組件

### 概念和技術

* **ReAct Pattern**：推理 → 行動 → 觀察迴圈，用於智能問題解決
* **Tool Discovery**：自動發現和註冊可用工具
* **Action Selection**：根據上下文智能選擇適當的工具
* **Parameter Validation**：在執行前驗證工具參數
* **Extensibility**：在不修改 Agent 結構的情況下新增工具

### 核心類別

* `GraphExecutor`：ReAct Agent 工作流程的執行器
* `FunctionGraphNode`：用於推理和觀察的 Node
* `ActionGraphNode`：具有自動發現功能的工具執行 Node
* `ActionSelectionCriteria`：用於工具選擇和篩選的準則
* `ConditionalEdge`：用於工作流程控制的 Graph Edge

## 執行範例

### 開始使用

此範例使用 Semantic Kernel Graph 套件演示 ReAct（推理 + 行動）模式。下面的程式碼片段展示如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. 工具註冊

此範例首先註冊 Agent 可以使用的基本工具。

```csharp
// Register a small set of mock tools (can be replaced/extended freely)
RegisterBasicTools(kernel);

private static void RegisterBasicTools(Kernel kernel)
{
    // Weather tool
    kernel.ImportPluginFromObject(new WeatherTool());
    
    // Calculator tool
    kernel.ImportPluginFromObject(new CalculatorTool());
    
    // Search tool
    kernel.ImportPluginFromObject(new SearchTool());
}

// Example tool implementations
public class WeatherTool
{
    [KernelFunction, Description("Get current weather for a location")]
    public string GetWeather([Description("City name")] string city)
    {
        // Simulate weather data
        var weather = city.ToLowerInvariant() switch
        {
            "lisbon" => "Sunny, 22°C, light breeze",
            "london" => "Cloudy, 15°C, light rain",
            "paris" => "Partly cloudy, 18°C, calm",
            _ => $"Weather data unavailable for {city}"
        };
        
        return $"Current weather in {city}: {weather}";
    }
}

public class CalculatorTool
{
    [KernelFunction, Description("Perform mathematical calculations")]
    public string Calculate([Description("Mathematical expression")] string expression)
    {
        try
        {
            // Simple calculation evaluation (in production, use proper expression parser)
            var result = EvaluateExpression(expression);
            return $"Result of {expression} = {result}";
        }
        catch (Exception ex)
        {
            return $"Error calculating {expression}: {ex.Message}";
        }
    }
    
    private static double EvaluateExpression(string expression)
    {
        // Simplified expression evaluation
        if (expression.Contains("*"))
        {
            var parts = expression.Split('*');
            if (parts.Length == 2 && double.TryParse(parts[0], out var a) && double.TryParse(parts[1], out var b))
                return a * b;
        }
        throw new ArgumentException("Unsupported expression format");
    }
}

public class SearchTool
{
    [KernelFunction, Description("Search for information on a topic")]
    public string Search([Description("Search query")] string query)
    {
        // Simulate search results
        var results = query.ToLowerInvariant() switch
        {
            var q when q.Contains("c#") && q.Contains("logging") => 
                "C# logging best practices: Use ILogger<T>, structured logging, log levels, and centralized configuration.",
            var q when q.Contains("best practices") => 
                "General best practices: Follow established patterns, document code, test thoroughly, and maintain consistency.",
            _ => $"Search results for '{query}': Multiple relevant sources found with comprehensive information."
        };
        
        return results;
    }
}
```

### 2. 建立 ReAct Agent

此 Agent 使用最小的三個 Node 結構建立：推理、行動和觀察。

```csharp
private static GraphExecutor CreateSimpleReActAgent(Kernel kernel)
{
    var executor = new GraphExecutor("SimpleReActAgent", "Minimal ReAct agent with extensible tools");

    var reasoning = new FunctionGraphNode(
        CreateReasoningFunction(kernel),
        "react_reason",
        "Analyze the user query and suggest an action"
    );

    // Auto-discover actions from all plugins; keep it simple and let the node pick best matching
    var actions = ActionGraphNode.CreateWithActions(
        kernel,
        new ActionSelectionCriteria
        {
            // Keep open by default; can be restricted via IncludedPlugins/FunctionNamePattern
        },
        "react_act");
    actions.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

    var observe = new FunctionGraphNode(
        CreateObservationFunction(kernel),
        "react_observe",
        "Summarize action result as a final answer"
    ).StoreResultAs("final_answer");

    executor.AddNode(reasoning);
    executor.AddNode(actions);
    executor.AddNode(observe);

    executor.SetStartNode(reasoning.NodeId);
    executor.AddEdge(ConditionalEdge.CreateUnconditional(reasoning, actions));
    executor.AddEdge(ConditionalEdge.CreateUnconditional(actions, observe));

    return executor;
}
```

### 3. 推理函數

推理函數分析使用者查詢並建議適當的行動。

```csharp
private static KernelFunction CreateReasoningFunction(Kernel kernel)
{
    // Create a deterministic, method-based function to avoid external LLM calls in examples
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var query = args.TryGetValue("user_query", out var q) ? q?.ToString() ?? string.Empty : string.Empty;

            // Simple heuristics to choose the appropriate tool/action
            var action = query.ToLowerInvariant() switch
            {
                var s when s.Contains("weather") => "GetWeather",
                var s when s.Contains("calculate") || s.Contains("*") || s.Contains("+") || s.Contains("-") => "Calculate",
                var s when s.Contains("search") || s.Contains("best practices") => "Search",
                var s when s.Contains("convert") && s.Contains("currency") => "ConvertCurrency",
                _ => "Search"
            };

            var parameters = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

            // Extract minimal parameters for the selected action (demonstration only)
            if (action == "GetWeather")
            {
                var cityMatch = System.Text.RegularExpressions.Regex.Match(query, @"in ([A-Za-z]+)", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (cityMatch.Success) parameters["city"] = cityMatch.Groups[1].Value;
            }

            if (action == "Calculate")
            {
                var calcMatch = System.Text.RegularExpressions.Regex.Match(query, @"(\d+\s*[\*\+\-]\s*\d+)");
                if (calcMatch.Success) parameters["expression"] = calcMatch.Groups[1].Value;
            }

            if (action == "Search")
            {
                parameters["query"] = query.Replace("Search:", string.Empty, StringComparison.OrdinalIgnoreCase).Trim();
            }

            // Store suggested action and parameters for downstream nodes
            args["suggested_action"] = action;
            args["action_parameters"] = parameters;

            return $"Reasoning: suggested action='{action}' parameters=[{string.Join(',', parameters.Select(kv => kv.Key + "=" + kv.Value))}]";
        },
        functionName: "react_reasoning",
        description: "Analyzes user queries and suggests appropriate actions"
    );
}
```

### 4. 行動執行

行動 Node 自動發現和執行適當的工具。

```csharp
// The ActionGraphNode automatically handles:
// - Tool discovery from registered plugins
// - Parameter mapping and validation
// - Tool execution with proper error handling
// - Result formatting for the observation step

// Configuration for intelligent action selection
actions.ConfigureExecution(
    ActionSelectionStrategy.Intelligent, 
    enableParameterValidation: true
);
```

### 5. 觀察函數

觀察函數將行動結果總結為最終答案。

```csharp
private static KernelFunction CreateObservationFunction(Kernel kernel)
{
    // Deterministic observation function that formats action results
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var action = args.TryGetValue("suggested_action", out var a) ? a?.ToString() ?? string.Empty : string.Empty;
            var result = args.TryGetValue("action_result", out var r) ? r?.ToString() ?? string.Empty : string.Empty;

            var answer = action switch
            {
                "GetWeather" => $"Based on your query about weather, I found: {result}",
                "Calculate" => $"I calculated the result for you: {result}",
                "Search" => $"Here's what I found when searching: {result}",
                "ConvertCurrency" => $"I converted the currency for you: {result}",
                _ => $"I processed your request and here's what I found: {result}"
            };

            args["final_answer"] = answer;
            return answer;
        },
        functionName: "react_observation",
        description: "Summarizes action results into final answers"
    );
}
```

### 6. 範例查詢處理

此範例處理多個範例查詢以展示 Agent 的功能。

```csharp
// Run a few sample queries and show how adding a tool still works transparently
var sampleQueries = new[]
{
    "What's the weather in Lisbon today?",
    "Calculate: 42 * 7",
    "Search: best practices for C# logging"
};

foreach (var query in sampleQueries)
{
    Console.WriteLine($"🧑‍💻 User: {query}");
    var args = new KernelArguments
    {
        ["user_query"] = query,
        ["max_steps"] = 3
    };

    var result = await executor.ExecuteAsync(kernel, args);
    var answer = result.GetValue<string>() ?? "No answer produced";
    Console.WriteLine($"🤖 Agent: {answer}\n");
    await Task.Delay(250);
}
```

### 7. 工具可擴展性

此範例演示如何在不修改 Agent 結構的情況下新增工具。

```csharp
// Demonstrate extensibility: add a new tool and reuse the same agent
AddCurrencyConversionTool(kernel);
Console.WriteLine("➕ Added new tool: currency_convert(amount, from, to)\n");

var extendedQuery = "Convert 100 USD to EUR";
Console.WriteLine($"🧑‍💻 User: {extendedQuery}");
var extendedArgs = new KernelArguments { ["user_query"] = extendedQuery };
var extendedResult = await executor.ExecuteAsync(kernel, extendedArgs);
Console.WriteLine($"🤖 Agent: {extendedResult.GetValue<string>() ?? "No answer produced"}\n");

private static void AddCurrencyConversionTool(Kernel kernel)
{
    kernel.ImportPluginFromObject(new CurrencyConversionTool());
}

public class CurrencyConversionTool
{
    [KernelFunction]
    public string ConvertCurrency(double amount, string from, string to)
    {
        // Simulate currency conversion rates
        var rates = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase)
        {
            ["USD"] = 1.0,
            ["EUR"] = 0.85,
            ["GBP"] = 0.73,
            ["JPY"] = 110.0
        };

        if (rates.TryGetValue(from, out var fromRate) && rates.TryGetValue(to, out var toRate))
        {
            var convertedAmount = amount * (toRate / fromRate);
            return $"{amount} {from.ToUpper()} = {convertedAmount:F2} {to.ToUpper()}";
        }

        return $"Unable to convert {amount} {from} to {to} - unsupported currency pair";
    }
}
```

## 進階模式

### 多工具協調

```csharp
// Implement coordinated tool usage for complex tasks
var coordinatedAgent = new CoordinatedReActAgent
{
    ToolCoordinationStrategy = new SequentialCoordinationStrategy
    {
        MaxParallelTools = 2,
        CoordinationRules = new Dictionary<string, string[]>
        {
            ["data_analysis"] = new[] { "data_clean", "data_transform", "data_analyze" },
            ["report_generation"] = new[] { "data_analyze", "format_report", "validate_report" }
        }
    },
    FallbackStrategy = new FallbackStrategy
    {
        PrimaryTools = new[] { "primary_tool" },
        BackupTools = new[] { "backup_tool" },
        RetryAttempts = 3
    }
};

// Execute coordinated tool usage
var coordinatedResult = await coordinatedAgent.ExecuteAsync(kernel, coordinatedArgs);
```

### 自適應推理

```csharp
// Implement adaptive reasoning based on task complexity
var adaptiveAgent = new AdaptiveReActAgent
{
    ReasoningStrategies = new Dictionary<string, IReasoningStrategy>
    {
        ["simple"] = new SimpleReasoningStrategy { MaxSteps = 2 },
        ["moderate"] = new ModerateReasoningStrategy { MaxSteps = 4 },
        ["complex"] = new ComplexReasoningStrategy { MaxSteps = 6 }
    },
    ComplexityAnalyzer = new TaskComplexityAnalyzer
    {
        ComplexityMetrics = new[] { "query_length", "tool_count", "domain_specificity" },
        Thresholds = new Dictionary<string, double>
        {
            ["simple"] = 0.3,
            ["moderate"] = 0.7,
            ["complex"] = 1.0
        }
    }
};

// Automatically select reasoning strategy
var strategy = adaptiveAgent.SelectReasoningStrategy(userQuery);
var adaptiveResult = await adaptiveAgent.ExecuteAsync(kernel, args, strategy);
```

### 工具效能最佳化

```csharp
// Implement tool performance optimization
var optimizedAgent = new OptimizedReActAgent
{
    ToolPerformanceTracker = new ToolPerformanceTracker
    {
        PerformanceMetrics = new Dictionary<string, ToolMetrics>(),
        OptimizationThreshold = TimeSpan.FromSeconds(2)
    },
    ToolSelectionOptimizer = new ToolSelectionOptimizer
    {
        SelectionCriteria = new[] { "accuracy", "speed", "reliability" },
        WeightedScoring = true,
        HistoricalPerformanceWeight = 0.7
    }
};

// Track and optimize tool performance
await optimizedAgent.TrackToolPerformanceAsync("currency_convert", executionTime);
var optimizedTools = await optimizedAgent.GetOptimizedToolSetAsync();
```

## 預期輸出

此範例產生全面的輸出，顯示：

* 🧑‍💻 使用者查詢和 Agent 推理
* 🤖 智能的行動選擇和工具執行
* 📊 工具參數提取和驗證
* 🔄 ReAct 迴圈執行（推理 → 行動 → 觀察）
* ➕ 工具可擴展性演示
* ✅ 完整的 ReAct Agent 工作流程執行

## 故障排除

### 常見問題

1. **工具發現失敗**：確保工具已正確向 Semantic Kernel 註冊
2. **參數驗證錯誤**：檢查工具參數型別和驗證規則
3. **行動選擇問題**：驗證工具描述和函數屬性
4. **執行失敗**：監控工具執行和錯誤處理

### 除錯提示

* 啟用詳細日誌記錄以追蹤 ReAct 迴圈執行
* 在 Kernel 中驗證工具註冊和發現
* 檢查推理和行動 Node 之間的參數對應
* 監控行動選擇準則和工具匹配

## 另請參閱

* [ReAct Patterns](../patterns/react.md)
* [Action Nodes](../concepts/node-types.md)
* [Tool Integration](../how-to/tools.md)
* [Agent Patterns](../patterns/agent-patterns.md)
* [Function Nodes](../concepts/node-types.md)
