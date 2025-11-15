# ReAct 代理程式範例

此範例示範了一個簡單、可擴展的 ReAct（推理→執行→觀察）代理程式，可以靈活地擴展許多工具。

## 目標

了解如何在基於圖形的工作流程中實作 ReAct 代理程式模式，以便：
* 建立最小的推理→執行→觀察迴圈
* 實作可擴展的工具註冊和發現
* 展示智慧型動作選擇和執行
* 說明如何在不修改代理程式結構的情況下添加新工具
* 實作參數驗證和智慧型工具匹配

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 基本了解[圖形概念](../concepts/graph-concepts.md)和 [ReAct 模式](../patterns/react.md)
* 熟悉[動作節點](../concepts/node-types.md)

## 主要元件

### 概念和技術

* **ReAct 模式**：用於智慧型問題解決的推理→執行→觀察迴圈
* **工具發現**：自動發現和註冊可用工具
* **動作選擇**：根據內容智慧型選擇適當的工具
* **參數驗證**：執行前驗證工具參數
* **可擴展性**：在不修改代理程式結構的情況下添加新工具

### 核心類別

* `GraphExecutor`：ReAct 代理程式工作流程的執行器
* `FunctionGraphNode`：用於推理和觀察的節點
* `ActionGraphNode`：用於具有自動發現功能的工具執行的節點
* `ActionSelectionCriteria`：用於工具選擇和篩選的條件
* `ConditionalEdge`：用於工作流程控制的圖形邊

## 執行範例

### 開始入門

此範例示範了 Semantic Kernel Graph 套件的 ReAct（推理+執行）模式。下面的程式碼片段顯示了如何在您自己的應用程式中實作此模式。

## 分步實作

### 1. 工具註冊

此範例首先註冊代理程式可以使用的基本工具。

```csharp
// 註冊一小組模擬工具（可自由取代/擴展）
RegisterBasicTools(kernel);

private static void RegisterBasicTools(Kernel kernel)
{
    // 天氣工具
    kernel.ImportPluginFromObject(new WeatherTool());
    
    // 計算機工具
    kernel.ImportPluginFromObject(new CalculatorTool());
    
    // 搜尋工具
    kernel.ImportPluginFromObject(new SearchTool());
}

// 範例工具實作
public class WeatherTool
{
    [KernelFunction, Description("Get current weather for a location")]
    public string GetWeather([Description("City name")] string city)
    {
        // 模擬天氣資料
        var weather = city.ToLowerInvariant() switch
        {
            "lisbon" => "晴朗，22°C，微風",
            "london" => "多雲，15°C，小雨",
            "paris" => "部分多雲，18°C，平靜",
            _ => $"無法取得 {city} 的天氣資料"
        };
        
        return $"{city} 目前天氣：{weather}";
    }
}

public class CalculatorTool
{
    [KernelFunction, Description("Perform mathematical calculations")]
    public string Calculate([Description("Mathematical expression")] string expression)
    {
        try
        {
            // 簡單的計算評估（在生產環境中，使用適當的表達式解析器）
            var result = EvaluateExpression(expression);
            return $"{expression} 的結果 = {result}";
        }
        catch (Exception ex)
        {
            return $"計算 {expression} 時出錯：{ex.Message}";
        }
    }
    
    private static double EvaluateExpression(string expression)
    {
        // 簡化的表達式評估
        if (expression.Contains("*"))
        {
            var parts = expression.Split('*');
            if (parts.Length == 2 && double.TryParse(parts[0], out var a) && double.TryParse(parts[1], out var b))
                return a * b;
        }
        throw new ArgumentException("不支援的表達式格式");
    }
}

public class SearchTool
{
    [KernelFunction, Description("Search for information on a topic")]
    public string Search([Description("Search query")] string query)
    {
        // 模擬搜尋結果
        var results = query.ToLowerInvariant() switch
        {
            var q when q.Contains("c#") && q.Contains("logging") => 
                "C# 日誌最佳實務：使用 ILogger<T>、結構化日誌、日誌等級和集中式配置。",
            var q when q.Contains("best practices") => 
                "一般最佳實務：遵循既定模式、記錄程式碼、徹底測試並保持一致性。",
            _ => $"搜尋 '{query}' 的結果：找到多個具有綜合資訊的相關來源。"
        };
        
        return results;
    }
}
```

### 2. 建立 ReAct 代理程式

代理程式使用最小的三節點結構構建：推理、執行和觀察。

```csharp
private static GraphExecutor CreateSimpleReActAgent(Kernel kernel)
{
    var executor = new GraphExecutor("SimpleReActAgent", "Minimal ReAct agent with extensible tools");

    var reasoning = new FunctionGraphNode(
        CreateReasoningFunction(kernel),
        "react_reason",
        "分析使用者查詢並建議動作"
    );

    // 自動發現所有外掛程式中的動作；保持簡單並讓節點選擇最匹配的
    var actions = ActionGraphNode.CreateWithActions(
        kernel,
        new ActionSelectionCriteria
        {
            // 預設保持開放；可透過 IncludedPlugins/FunctionNamePattern 進行限制
        },
        "react_act");
    actions.ConfigureExecution(ActionSelectionStrategy.Intelligent, enableParameterValidation: true);

    var observe = new FunctionGraphNode(
        CreateObservationFunction(kernel),
        "react_observe",
        "將動作結果摘要為最終答案"
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

推理函數分析使用者查詢並建議適當的動作。

```csharp
private static KernelFunction CreateReasoningFunction(Kernel kernel)
{
    // 建立決定性的方法型函數，以避免在範例中進行外部 LLM 呼叫
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var query = args.TryGetValue("user_query", out var q) ? q?.ToString() ?? string.Empty : string.Empty;

            // 簡單的啟發式方法來選擇適當的工具/動作
            var action = query.ToLowerInvariant() switch
            {
                var s when s.Contains("weather") => "GetWeather",
                var s when s.Contains("calculate") || s.Contains("*") || s.Contains("+") || s.Contains("-") => "Calculate",
                var s when s.Contains("search") || s.Contains("best practices") => "Search",
                var s when s.Contains("convert") && s.Contains("currency") => "ConvertCurrency",
                _ => "Search"
            };

            var parameters = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

            // 為選定的動作萃取最小參數（僅供展示）
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

            // 為下游節點儲存建議的動作和參數
            args["suggested_action"] = action;
            args["action_parameters"] = parameters;

            return $"推理：建議動作='{action}' 參數=[{string.Join(',', parameters.Select(kv => kv.Key + "=" + kv.Value))}]";
        },
        functionName: "react_reasoning",
        description: "分析使用者查詢並建議適當的動作"
    );
}
```

### 4. 動作執行

動作節點自動發現並執行適當的工具。

```csharp
// ActionGraphNode 自動處理：
// - 從註冊外掛程式發現工具
// - 參數映射和驗證
// - 具有適當錯誤處理的工具執行
// - 觀察步驟的結果格式化

// 智慧型動作選擇的配置
actions.ConfigureExecution(
    ActionSelectionStrategy.Intelligent, 
    enableParameterValidation: true
);
```

### 5. 觀察函數

觀察函數將動作結果摘要為最終答案。

```csharp
private static KernelFunction CreateObservationFunction(Kernel kernel)
{
    // 決定性的觀察函數，可格式化動作結果
    return kernel.CreateFunctionFromMethod(
        (KernelArguments args) =>
        {
            var action = args.TryGetValue("suggested_action", out var a) ? a?.ToString() ?? string.Empty : string.Empty;
            var result = args.TryGetValue("action_result", out var r) ? r?.ToString() ?? string.Empty : string.Empty;

            var answer = action switch
            {
                "GetWeather" => $"根據您的天氣查詢，我發現：{result}",
                "Calculate" => $"我為您計算了結果：{result}",
                "Search" => $"以下是我搜尋時發現的內容：{result}",
                "ConvertCurrency" => $"我為您轉換了貨幣：{result}",
                _ => $"我處理了您的請求，以下是我發現的內容：{result}"
            };

            args["final_answer"] = answer;
            return answer;
        },
        functionName: "react_observation",
        description: "將動作結果摘要為最終答案"
    );
}
```

### 6. 範例查詢處理

此範例處理多個範例查詢以展示代理程式的功能。

```csharp
// 執行幾個範例查詢，並展示如何添加工具仍然透明地工作
var sampleQueries = new[]
{
    "今天里斯本的天氣如何？",
    "計算：42 * 7",
    "搜尋：C# 日誌的最佳實務"
};

foreach (var query in sampleQueries)
{
    Console.WriteLine($"🧑‍💻 使用者：{query}");
    var args = new KernelArguments
    {
        ["user_query"] = query,
        ["max_steps"] = 3
    };

    var result = await executor.ExecuteAsync(kernel, args);
    var answer = result.GetValue<string>() ?? "沒有產生答案";
    Console.WriteLine($"🤖 代理程式：{answer}\n");
    await Task.Delay(250);
}
```

### 7. 工具擴展性

此範例展示了如何在不修改代理程式結構的情況下添加新工具。

```csharp
// 展示擴展性：添加新工具並重複使用相同的代理程式
AddCurrencyConversionTool(kernel);
Console.WriteLine("➕ 已添加新工具：currency_convert(amount, from, to)\n");

var extendedQuery = "將 100 美元轉換為歐元";
Console.WriteLine($"🧑‍💻 使用者：{extendedQuery}");
var extendedArgs = new KernelArguments { ["user_query"] = extendedQuery };
var extendedResult = await executor.ExecuteAsync(kernel, extendedArgs);
Console.WriteLine($"🤖 代理程式：{extendedResult.GetValue<string>() ?? "沒有產生答案"}\n");

private static void AddCurrencyConversionTool(Kernel kernel)
{
    kernel.ImportPluginFromObject(new CurrencyConversionTool());
}

public class CurrencyConversionTool
{
    [KernelFunction]
    public string ConvertCurrency(double amount, string from, string to)
    {
        // 模擬匯率轉換
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

        return $"無法轉換 {amount} {from} 至 {to} - 不支援的貨幣對";
    }
}
```

## 進階模式

### 多工具協調

```csharp
// 為複雜任務實作協調的工具使用
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

// 執行協調的工具使用
var coordinatedResult = await coordinatedAgent.ExecuteAsync(kernel, coordinatedArgs);
```

### 自適應推理

```csharp
// 根據任務複雜性實作自適應推理
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

// 自動選擇推理策略
var strategy = adaptiveAgent.SelectReasoningStrategy(userQuery);
var adaptiveResult = await adaptiveAgent.ExecuteAsync(kernel, args, strategy);
```

### 工具效能最佳化

```csharp
// 實作工具效能最佳化
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

// 追蹤並最佳化工具效能
await optimizedAgent.TrackToolPerformanceAsync("currency_convert", executionTime);
var optimizedTools = await optimizedAgent.GetOptimizedToolSetAsync();
```

## 預期輸出

此範例生成詳細的輸出，顯示：

* 🧑‍💻 使用者查詢和代理程式推理
* 🤖 智慧型動作選擇和工具執行
* 📊 工具參數萃取和驗證
* 🔄 ReAct 迴圈執行（推理→執行→觀察）
* ➕ 工具擴展性展示
* ✅ 完整 ReAct 代理程式工作流程執行

## 疑難排解

### 常見問題

1. **工具發現失敗**：確保工具已正確向 Semantic Kernel 註冊
2. **參數驗證錯誤**：檢查工具參數類型和驗證規則
3. **動作選擇問題**：驗證工具描述和函數屬性
4. **執行失敗**：監視工具執行和錯誤處理

### 除錯提示

* 啟用詳細日誌以追蹤 ReAct 迴圈執行
* 驗證核心中的工具註冊和發現
* 檢查推理和動作節點之間的參數映射
* 監視動作選擇條件和工具匹配

## 另請參閱

* [ReAct 模式](../patterns/react.md)
* [動作節點](../concepts/node-types.md)
* [工具整合](../how-to/tools.md)
* [代理程式模式](../patterns/agent-patterns.md)
* [函數節點](../concepts/node-types.md)
