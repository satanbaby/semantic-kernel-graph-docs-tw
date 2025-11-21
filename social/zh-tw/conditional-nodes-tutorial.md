# 條件 Node 教學

本教學將教您如何在 SemanticKernel.Graph 中使用條件 Node 和 Edge，以建立動態、智能的工作流程，可以根據狀態和 AI 回應做出決策並路由執行。

## 您將學習什麼

* 如何建立做出路由決策的條件 Node
* 使用條件 Edge 進行動態工作流程路徑
* 建立適應不同場景的智能工作流程
* Graph 中條件邏輯的最佳實踐

## 先決條件

開始前，請確保您已：
* 完成 [First Graph 教學](first-graph.md)
* 了解 [State Management](state-tutorial.md)
* 具有 SemanticKernel.Graph 概念的基礎知識

## 了解條件 Node

### 什麼是條件 Node？

條件 Node 是特殊的 Node，用於評估條件並決定工作流程應該採取的下一個路徑。它們就像交通管制員，根據目前的狀態指引執行流程。

### 條件的類型

* **Simple Boolean Conditions（簡單布林條件）**：基本的真/假決策
* **State-Based Conditions（基於狀態的條件）**：根據狀態中的資料做決策
* **AI-Generated Conditions（AI 生成的條件）**：由 AI 分析做出的複雜決策
* **Template-Based Conditions（基於範本的條件）**：以自然語言表達的條件

## 基本條件 Node

### 建立簡單的條件 Node

```csharp
using SemanticKernel.Graph.Nodes;

// Basic conditional node with a simple boolean function
var isPositiveNode = new ConditionalGraphNode("IsPositive",
    state => 
    {
        var sentiment = state.GetValueOrDefault("sentiment", "neutral");
        return sentiment.ToString().ToLower().Contains("positive");
    }
);
```

### 使用條件 Node

```csharp
var graph = new GraphExecutor("ConditionalExample");

// Add nodes
graph.AddNode(inputNode);
graph.AddNode(isPositiveNode);
graph.AddNode(positiveResponseNode);
graph.AddNode(negativeResponseNode);

// Connect with conditional routing
graph.Connect(inputNode, isPositiveNode);
graph.Connect(isPositiveNode, positiveResponseNode, 
    edge => edge.When(state => state.GetValueOrDefault("sentiment", "").ToString().Contains("positive")));
graph.Connect(isPositiveNode, negativeResponseNode, 
    edge => edge.When(state => !state.GetValueOrDefault("sentiment", "").ToString().Contains("positive")));

graph.SetStartNode(inputNode);
```

## 進階條件模式

### 多路徑路由

```csharp
var analysisNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Analyze this text: {{$input}}
        Return JSON with:
        {
            "sentiment": "positive|negative|neutral",
            "urgency": "high|medium|low",
            "category": "technical|personal|business"
        }
    ")
.).StoreResultAs("analysis");

var routingNode = new ConditionalGraphNode("RouteByAnalysis",
    state => 
    {
        var analysis = state.GetValueOrDefault("analysis", "");
        if (analysis.ToString().Contains("\"urgency\": \"high\""))
            return "high";
        if (analysis.ToString().Contains("\"sentiment\": \"negative\""))
            return "negative";
        return "normal";
    }
);

// Connect to different handlers
graph.Connect(routingNode, highPriorityNode, 
    edge => edge.When(state => routingNode.EvaluateCondition(state) == "high"));
graph.Connect(routingNode, negativeHandlerNode, 
    edge => edge.When(state => routingNode.EvaluateCondition(state) == "negative"));
graph.Connect(routingNode, normalHandlerNode, 
    edge => edge.When(state => routingNode.EvaluateCondition(state) == "normal"));
```

### AI 驅動的決策制定

```csharp
var decisionNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Based on this situation: {{$context}}
        And the current state: {{$currentState}}
        
        Decide what action to take next. Return only one of these options:
        - "continue" - if we should proceed normally
        - "escalate" - if this needs human intervention
        - "retry" - if we should try again with different parameters
        - "abort" - if we should stop the workflow
        
        Explain your reasoning briefly.
    ")
.).StoreResultAs("decision");

var actionRouter = new ConditionalGraphNode("RouteByDecision",
    state => 
    {
        var decision = state.GetValueOrDefault("decision", "").ToString().ToLower();
        if (decision.Contains("continue")) return "continue";
        if (decision.Contains("escalate")) return "escalate";
        if (decision.Contains("retry")) return "retry";
        if (decision.Contains("abort")) return "abort";
        return "default";
    }
);
```

## 完整條件工作流程範例

讓我們建立一個完整的範例來演示條件路由：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

class Program
{
    static async Task Main(string[] args)
    {
        var builder = Kernel.CreateBuilder();
        builder.AddOpenAIChatCompletion("gpt-4", Environment.GetEnvironmentVariable("OPENAI_API_KEY"));
        builder.AddGraphSupport();
        var kernel = builder.Build();

        // 1. Input analysis node
        var inputNode = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                Analyze this customer request: {{$customerRequest}}
                
                Provide analysis in JSON format:
                {
                    "complexity": "simple|moderate|complex",
                    "urgency": "low|medium|high",
                    "category": "technical|billing|general",
                    "estimatedTime": "minutes|hours|days"
                }
            ")
        ).StoreResultAs("analysis");

        // 2. Complexity-based routing
        var complexityRouter = new ConditionalGraphNode("RouteByComplexity",
            state => 
            {
                var analysis = state.GetValueOrDefault("analysis", "");
                if (analysis.ToString().Contains("\"complexity\": \"simple\""))
                    return "simple";
                if (analysis.ToString().Contains("\"complexity\": \"moderate\""))
                    return "moderate";
                return "complex";
            }
        );

        // 3. Simple request handler
        var simpleHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                Handle this simple request: {{$customerRequest}}
                Analysis: {{$analysis}}
                
                Provide a direct, helpful response that resolves the issue.
            ")
        ).StoreResultAs("response");

        // 4. Moderate request handler
        var moderateHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                Handle this moderate complexity request: {{$customerRequest}}
                Analysis: {{$analysis}}
                
                Provide a detailed response with steps and resources.
                Include any necessary follow-up actions.
            ")
        ).StoreResultAs("response");

        // 5. Complex request handler
        var complexHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                This is a complex request: {{$customerRequest}}
                Analysis: {{$analysis}}
                
                Provide a comprehensive response that:
                1. Acknowledges the complexity
                2. Outlines a step-by-step approach
                3. Suggests escalation if needed
                4. Sets clear expectations
            ")
        ).StoreResultAs("response");

        // 6. Urgency check
        var urgencyCheck = new ConditionalGraphNode("CheckUrgency",
            state => 
            {
                var analysis = state.GetValueOrDefault("analysis", "");
                return analysis.ToString().Contains("\"urgency\": \"high\"");
            }
        );

        // 7. High urgency handler
        var highUrgencyHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                This is a HIGH URGENCY request: {{$customerRequest}}
                Current response: {{$response}}
                
                Enhance the response to emphasize urgency and provide immediate action items.
                Include escalation contact information.
            ")
        ).StoreResultAs("finalResponse");

        // 8. Final response formatter
        var responseFormatter = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                Format the final response for the customer:
                Request: {{$customerRequest}}
                Response: {{$finalResponse}}
                Analysis: {{$analysis}}
                
                Create a professional, well-structured response that addresses all aspects.
            ")
        ).StoreResultAs("formattedResponse");

        // Build the graph
        var graph = new GraphExecutor("ConditionalWorkflowExample");

        // Add all nodes
        graph.AddNode(inputNode);
        graph.AddNode(complexityRouter);
        graph.AddNode(simpleHandler);
        graph.AddNode(moderateHandler);
        graph.AddNode(complexHandler);
        graph.AddNode(urgencyCheck);
        graph.AddNode(highUrgencyHandler);
        graph.AddNode(responseFormatter);

        // Connect the workflow
        graph.Connect(inputNode, complexityRouter);
        
        // Complexity routing
        graph.Connect(complexityRouter, simpleHandler, 
            edge => edge.When(state => complexityRouter.EvaluateCondition(state) == "simple"));
        graph.Connect(complexityRouter, moderateHandler, 
            edge => edge.When(state => complexityRouter.EvaluateCondition(state) == "moderate"));
        graph.Connect(complexityRouter, complexHandler, 
            edge => edge.When(state => complexityRouter.EvaluateCondition(state) == "complex"));
        
        // All paths go to urgency check
        graph.Connect(simpleHandler, urgencyCheck);
        graph.Connect(moderateHandler, urgencyCheck);
        graph.Connect(complexHandler, urgencyCheck);
        
        // Urgency routing
        graph.Connect(urgencyCheck, highUrgencyHandler, 
            edge => edge.When(state => urgencyCheck.EvaluateCondition(state)));
        graph.Connect(urgencyCheck, responseFormatter, 
            edge => edge.When(state => !urgencyCheck.EvaluateCondition(state)));
        
        // High urgency path
        graph.Connect(highUrgencyHandler, responseFormatter);
        
        graph.SetStartNode(inputNode);

        // Test with different inputs
        var testRequests = new[]
        {
            "I can't log into my account", // Simple
            "I need help setting up advanced security features", // Moderate
            "My entire system is down and I have a critical presentation in 2 hours" // Complex + High urgency
        };

        foreach (var request in testRequests)
        {
            Console.WriteLine($"\n=== Testing: {request} ===");
            
            var state = new KernelArguments { ["customerRequest"] = request };
            var result = await graph.ExecuteAsync(state);
            
            Console.WriteLine($"Complexity: {result.GetValueOrDefault("analysis", "No analysis")}");
            Console.WriteLine($"Response: {result.GetValueOrDefault("formattedResponse", "No response")}");
        }
    }
}
```

## 條件 Edge 模式

### 基本條件 Edge

```csharp
// Simple boolean condition
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => state.ContainsKey("success") && (bool)state["success"]));

// String-based condition
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => state.GetValueOrDefault("status", "").ToString() == "approved"));

// Numeric condition
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => 
    {
        var count = state.GetValueOrDefault("itemCount", 0);
        return count is int i && i > 10;
    }));
```

### 複雜的條件邏輯

```csharp
// Multiple conditions
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => 
    {
        var hasPermission = state.GetValueOrDefault("userRole", "").ToString() == "admin";
        var isBusinessHours = DateTime.Now.Hour >= 9 && DateTime.Now.Hour <= 17;
        var isUrgent = state.GetValueOrDefault("priority", "").ToString() == "high";
        
        return hasPermission && (isBusinessHours || isUrgent);
    }));

// AI-generated condition
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => 
    {
        var aiDecision = state.GetValueOrDefault("aiDecision", "").ToString();
        return aiDecision.Contains("proceed") || aiDecision.Contains("continue");
    }));
```

### 後備和預設路由

```csharp
// Primary route with fallback
graph.Connect(decisionNode, primaryHandler, 
    edge => edge.When(state => primaryHandler.CanHandle(state)));
graph.Connect(decisionNode, fallbackHandler, 
    edge => edge.When(state => !primaryHandler.CanHandle(state)));

// Multiple fallback levels
graph.Connect(decisionNode, handlerA, 
    edge => edge.When(state => conditionA(state)));
graph.Connect(decisionNode, handlerB, 
    edge => edge.When(state => !conditionA(state) && conditionB(state)));
graph.Connect(decisionNode, defaultHandler, 
    edge => edge.When(state => !conditionA(state) && !conditionB(state)));
```

## 最佳實踐

### 1. **保持條件簡單且易於閱讀**
```csharp
// Good - clear and readable
var isAdmin = new ConditionalGraphNode("IsAdmin",
    state => state.GetValueOrDefault("userRole", "").ToString() == "admin");

// Avoid - complex inline logic
var complexCondition = new ConditionalGraphNode("Complex",
    state => state.ContainsKey("a") && state.ContainsKey("b") && 
             state.GetValueOrDefault("c", 0) is int i && i > 10 && 
             state.GetValueOrDefault("d", "").ToString().Length > 5);
```

### 2. **使用描述性名稱**
```csharp
// Good - descriptive names
var shouldEscalate = new ConditionalGraphNode("ShouldEscalate", condition);
var isHighPriority = new ConditionalGraphNode("IsHighPriority", condition);

// Avoid - generic names
var check1 = new ConditionalGraphNode("Check1", condition);
var decision = new ConditionalGraphNode("Decision", condition);
```

### 3. **處理邊界情況**
```csharp
var safeCondition = new ConditionalGraphNode("SafeCondition",
    state => 
    {
        try
        {
            var value = state.GetValueOrDefault("key", "");
            return value?.ToString()?.Contains("expected") == true;
        }
        catch
        {
            return false; // Default to safe path
        }
    });
```

### 4. **測試不同的場景**
```csharp
// Test various input combinations
var testCases = new[]
{
    new { input = "positive", expected = "positive" },
    new { input = "negative", expected = "negative" },
    new { input = "", expected = "default" },
    new { input = null, expected = "default" }
};

foreach (var testCase in testCases)
{
    var state = new KernelArguments { ["input"] = testCase.input };
    var result = await graph.ExecuteAsync(state);
    Console.WriteLine($"Input: {testCase.input}, Result: {result.GetValueOrDefault("output", "default")}");
}
```

## 常見模式

### **Switch 型路由**
```csharp
var router = new ConditionalGraphNode("Router",
    state => 
    {
        var action = state.GetValueOrDefault("action", "").ToString().ToLower();
        return action switch
        {
            "create" => "create",
            "read" => "read",
            "update" => "update",
            "delete" => "delete",
            _ => "default"
        };
    });
```

### **基於閾值的決策**
```csharp
var thresholdNode = new ConditionalGraphNode("ThresholdCheck",
    state => 
    {
        var score = state.GetValueOrDefault("score", 0);
        return score switch
        {
            >= 90 => "excellent",
            >= 80 => "good",
            >= 70 => "fair",
            >= 60 => "poor",
            _ => "failing"
        };
    });
```

### **多因素決策**
```csharp
var multiFactorNode = new ConditionalGraphNode("MultiFactorDecision",
    state => 
    {
        var risk = state.GetValueOrDefault("riskLevel", "low").ToString();
        var amount = state.GetValueOrDefault("amount", 0m);
        var userType = state.GetValueOrDefault("userType", "standard").ToString();
        
        if (risk == "high" || amount > 10000m)
            return "manual_review";
        if (userType == "premium" && amount <= 5000m)
            return "auto_approve";
        return "standard_review";
    });
```

## 疑難排解

### **常見問題**

#### 條件始終返回 False
```
System.InvalidOperationException: No next nodes found for node 'ConditionalNode'
```
**解決方案**：檢查您的條件邏輯，並確保至少一個 Edge 條件評估為 true。

#### 無限迴圈
```
System.InvalidOperationException: Maximum execution steps exceeded
```
**解決方案**：確保您的條件邏輯不會建立迴圈路徑或無限迴圈。

#### 意外路由
```
Node 'HandlerA' executed instead of expected 'HandlerB'
```
**解決方案**：除錯您的條件邏輯，並驗證正在評估的狀態值。

### **除錯提示**

1. **在條件中加入日誌**
```csharp
var debugNode = new ConditionalGraphNode("DebugCondition",
    state => 
    {
        var result = state.GetValueOrDefault("key", "").ToString().Contains("expected");
        Console.WriteLine($"Condition evaluated: {result} for state: {state["key"]}");
        return result;
    });
```

2. **獨立測試條件**
```csharp
// Test your condition function directly
var testState = new KernelArguments { ["key"] = "test_value" };
var result = myCondition(testState);
Console.WriteLine($"Condition result: {result}");
```

3. **在決策點驗證狀態**
```csharp
var validationNode = new ConditionalGraphNode("ValidateState",
    state => 
    {
        Console.WriteLine($"State at decision point: {JsonSerializer.Serialize(state)}");
        return myCondition(state);
    });
```

## 下一步

現在您已了解條件 Node，請探索這些進階主題：

* **[迴圈教學](loops-tutorial.md)**：了解迴圈 Node 和反覆工作流程
* **[錯誤處理指南](how-to/error-handling.md)**：在您的工作流程中處理錯誤和異常
* **[進階路由](how-to/advanced-routing.md)**：掌握複雜的路由模式
* **[模式](patterns/index.md)**：發現常見的工作流程模式

## 概念和技術

本教學涵蓋多個關鍵概念：

* **Conditional Node**：評估條件並根據結果路由執行的 Node
* **Conditional Edge**：只有在其條件評估為 true 時才允許執行的 Edge
* **Routing Logic（路由邏輯）**：決定工作流程執行路徑的決策過程
* **State Evaluation（狀態評估）**：條件如何分析目前狀態以做出路由決策
* **Multi-path Workflows（多路徑工作流程）**：建立可根據條件採取不同路徑的工作流程

## 先決條件和最低設定

若要完成本教學，您需要：
* **SemanticKernel.Graph** 封裝已安裝並設定
* **LLM Provider** 具有有效的 API 金鑰
* **Understanding** 基本的 Graph 概念和狀態管理
* **.NET 8.0+** 執行階段環境

## 另請參閱

* **[State Management 教學](state-tutorial.md)**：了解資料如何在 Graph 中流動
* **[First Graph 教學](first-graph.md)**：建立您的第一個完整 Graph 工作流程
* **[How-to 指南](how-to/conditional-nodes.md)**：進階條件 Node 技術
* **[API 參考](api/nodes.md)**：完整的 Node API 文件
