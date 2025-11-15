# 條件節點教學

本教學將教導你如何在 SemanticKernel.Graph 中使用條件節點和邊緣，以建立動態且智慧化的工作流，可以根據狀態和 AI 回應進行決策和路由執行。

## 你將學到什麼

* 如何建立進行路由決策的條件節點
* 使用條件邊緣實現動態工作流路徑
* 建立可適應不同場景的智慧化工作流
* 圖形中條件邏輯的最佳實踐

## 前置需求

在開始之前，請確保你已經：
* 完成 [第一個圖形教學](first-graph.md)
* 了解 [狀態管理](state-tutorial.md)
* 掌握 SemanticKernel.Graph 基本概念

## 理解條件節點

### 什麼是條件節點？

條件節點是特殊節點，用於評估條件並決定工作流應該採取的下一條路徑。它們就像交通指揮官一樣，根據當前狀態指導執行流程。

### 條件類型

* **簡單布林條件**：基本的是/否決策
* **基於狀態的條件**：根據狀態中的資料進行決策
* **AI 生成的條件**：由 AI 分析做出的複雜決策
* **基於樣板的條件**：以自然語言表示的條件

## 基本條件節點

### 建立簡單條件節點

```csharp
using SemanticKernel.Graph.Nodes;

// 帶有簡單布林函數的基本條件節點
var isPositiveNode = new ConditionalGraphNode("IsPositive",
    state => 
    {
        var sentiment = state.GetValueOrDefault("sentiment", "neutral");
        return sentiment.ToString().ToLower().Contains("positive");
    }
);
```

### 使用條件節點

```csharp
var graph = new GraphExecutor("ConditionalExample");

// 新增節點
graph.AddNode(inputNode);
graph.AddNode(isPositiveNode);
graph.AddNode(positiveResponseNode);
graph.AddNode(negativeResponseNode);

// 使用條件路由進行連接
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
        分析此文本：{{$input}}
        以 JSON 格式返回：
        {
            "sentiment": "positive|negative|neutral",
            "urgency": "high|medium|low",
            "category": "technical|personal|business"
        }
    ")
).StoreResultAs("analysis");

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

// 連接到不同的處理程序
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
        根據此情況：{{$context}}
        和當前狀態：{{$currentState}}
        
        決定下一步應採取的行動。只傳回以下其中一個選項：
        - "continue" - 如果我們應該正常進行
        - "escalate" - 如果這需要人工干預
        - "retry" - 如果我們應該使用不同的參數重試
        - "abort" - 如果我們應該停止工作流
        
        簡要說明你的理由。
    ")
).StoreResultAs("decision");

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

## 完整條件工作流範例

讓我們建立一個完整的範例來展示條件路由：

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

        // 1. 輸入分析節點
        var inputNode = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                分析此客戶請求：{{$customerRequest}}
                
                以 JSON 格式提供分析：
                {
                    "complexity": "simple|moderate|complex",
                    "urgency": "low|medium|high",
                    "category": "technical|billing|general",
                    "estimatedTime": "minutes|hours|days"
                }
            ")
        ).StoreResultAs("analysis");

        // 2. 基於複雜性的路由
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

        // 3. 簡單請求處理程序
        var simpleHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                處理此簡單請求：{{$customerRequest}}
                分析：{{$analysis}}
                
                提供直接有幫助的回應以解決問題。
            ")
        ).StoreResultAs("response");

        // 4. 中等複雜性請求處理程序
        var moderateHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                處理此中等複雜性請求：{{$customerRequest}}
                分析：{{$analysis}}
                
                提供包含步驟和資源的詳細回應。
                包含任何必要的後續行動。
            ")
        ).StoreResultAs("response");

        // 5. 複雜請求處理程序
        var complexHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                這是一個複雜的請求：{{$customerRequest}}
                分析：{{$analysis}}
                
                提供全面的回應，應該：
                1. 承認複雜性
                2. 概述逐步方法
                3. 如果需要建議升級
                4. 設定清晰的期望
            ")
        ).StoreResultAs("response");

        // 6. 緊急性檢查
        var urgencyCheck = new ConditionalGraphNode("CheckUrgency",
            state => 
            {
                var analysis = state.GetValueOrDefault("analysis", "");
                return analysis.ToString().Contains("\"urgency\": \"high\"");
            }
        );

        // 7. 高緊急性處理程序
        var highUrgencyHandler = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                這是一個高緊急性請求：{{$customerRequest}}
                目前回應：{{$response}}
                
                增強回應以強調緊急性並提供立即行動項目。
                包含升級聯絡資訊。
            ")
        ).StoreResultAs("finalResponse");

        // 8. 最終回應格式化器
        var responseFormatter = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                為客戶格式化最終回應：
                請求：{{$customerRequest}}
                回應：{{$finalResponse}}
                分析：{{$analysis}}
                
                建立一個專業且結構良好的回應，解決所有方面。
            ")
        ).StoreResultAs("formattedResponse");

        // 建立圖形
        var graph = new GraphExecutor("ConditionalWorkflowExample");

        // 新增所有節點
        graph.AddNode(inputNode);
        graph.AddNode(complexityRouter);
        graph.AddNode(simpleHandler);
        graph.AddNode(moderateHandler);
        graph.AddNode(complexHandler);
        graph.AddNode(urgencyCheck);
        graph.AddNode(highUrgencyHandler);
        graph.AddNode(responseFormatter);

        // 連接工作流
        graph.Connect(inputNode, complexityRouter);
        
        // 複雜性路由
        graph.Connect(complexityRouter, simpleHandler, 
            edge => edge.When(state => complexityRouter.EvaluateCondition(state) == "simple"));
        graph.Connect(complexityRouter, moderateHandler, 
            edge => edge.When(state => complexityRouter.EvaluateCondition(state) == "moderate"));
        graph.Connect(complexityRouter, complexHandler, 
            edge => edge.When(state => complexityRouter.EvaluateCondition(state) == "complex"));
        
        // 所有路徑進入緊急性檢查
        graph.Connect(simpleHandler, urgencyCheck);
        graph.Connect(moderateHandler, urgencyCheck);
        graph.Connect(complexHandler, urgencyCheck);
        
        // 緊急性路由
        graph.Connect(urgencyCheck, highUrgencyHandler, 
            edge => edge.When(state => urgencyCheck.EvaluateCondition(state)));
        graph.Connect(urgencyCheck, responseFormatter, 
            edge => edge.When(state => !urgencyCheck.EvaluateCondition(state)));
        
        // 高緊急性路徑
        graph.Connect(highUrgencyHandler, responseFormatter);
        
        graph.SetStartNode(inputNode);

        // 以不同的輸入進行測試
        var testRequests = new[]
        {
            "I can't log into my account", // 簡單
            "I need help setting up advanced security features", // 中等
            "My entire system is down and I have a critical presentation in 2 hours" // 複雜 + 高緊急性
        };

        foreach (var request in testRequests)
        {
            Console.WriteLine($"\n=== 測試：{request} ===");
            
            var state = new KernelArguments { ["customerRequest"] = request };
            var result = await graph.ExecuteAsync(state);
            
            Console.WriteLine($"複雜性：{result.GetValueOrDefault("analysis", "No analysis")}");
            Console.WriteLine($"回應：{result.GetValueOrDefault("formattedResponse", "No response")}");
        }
    }
}
```

## 條件邊緣模式

### 基本條件邊緣

```csharp
// 簡單布林條件
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => state.ContainsKey("success") && (bool)state["success"]));

// 基於字串的條件
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => state.GetValueOrDefault("status", "").ToString() == "approved"));

// 數值條件
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => 
    {
        var count = state.GetValueOrDefault("itemCount", 0);
        return count is int i && i > 10;
    }));
```

### 複雜的條件邏輯

```csharp
// 多個條件
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => 
    {
        var hasPermission = state.GetValueOrDefault("userRole", "").ToString() == "admin";
        var isBusinessHours = DateTime.Now.Hour >= 9 && DateTime.Now.Hour <= 17;
        var isUrgent = state.GetValueOrDefault("priority", "").ToString() == "high";
        
        return hasPermission && (isBusinessHours || isUrgent);
    }));

// AI 生成的條件
graph.Connect(nodeA, nodeB, 
    edge => edge.When(state => 
    {
        var aiDecision = state.GetValueOrDefault("aiDecision", "").ToString();
        return aiDecision.Contains("proceed") || aiDecision.Contains("continue");
    }));
```

### 回退和預設路由

```csharp
// 帶有回退的主要路由
graph.Connect(decisionNode, primaryHandler, 
    edge => edge.When(state => primaryHandler.CanHandle(state)));
graph.Connect(decisionNode, fallbackHandler, 
    edge => edge.When(state => !primaryHandler.CanHandle(state)));

// 多個回退級別
graph.Connect(decisionNode, handlerA, 
    edge => edge.When(state => conditionA(state)));
graph.Connect(decisionNode, handlerB, 
    edge => edge.When(state => !conditionA(state) && conditionB(state)));
graph.Connect(decisionNode, defaultHandler, 
    edge => edge.When(state => !conditionA(state) && !conditionB(state)));
```

## 最佳實踐

### 1. **保持條件簡單且易讀**
```csharp
// 好的 - 清晰且易讀
var isAdmin = new ConditionalGraphNode("IsAdmin",
    state => state.GetValueOrDefault("userRole", "").ToString() == "admin");

// 應避免 - 複雜的內嵌邏輯
var complexCondition = new ConditionalGraphNode("Complex",
    state => state.ContainsKey("a") && state.ContainsKey("b") && 
             state.GetValueOrDefault("c", 0) is int i && i > 10 && 
             state.GetValueOrDefault("d", "").ToString().Length > 5);
```

### 2. **使用描述性名稱**
```csharp
// 好的 - 描述性名稱
var shouldEscalate = new ConditionalGraphNode("ShouldEscalate", condition);
var isHighPriority = new ConditionalGraphNode("IsHighPriority", condition);

// 應避免 - 通用名稱
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
            return false; // 預設為安全路徑
        }
    });
```

### 4. **測試不同的場景**
```csharp
// 測試各種輸入組合
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
    Console.WriteLine($"輸入：{testCase.input}，結果：{result.GetValueOrDefault("output", "default")}");
}
```

## 常見模式

### **類似 Switch 的路由**
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

## 故障排除

### **常見問題**

#### 條件總是傳回 False
```
System.InvalidOperationException: No next nodes found for node 'ConditionalNode'
```
**解決方案**：檢查你的條件邏輯，並確保至少有一個邊界條件評估為 true。

#### 無限迴圈
```
System.InvalidOperationException: Maximum execution steps exceeded
```
**解決方案**：確保你的條件邏輯不會建立循環路徑或無限迴圈。

#### 意外路由
```
Node 'HandlerA' executed instead of expected 'HandlerB'
```
**解決方案**：除錯你的條件邏輯，並驗證被評估的狀態值。

### **除錯提示**

1. **在條件中新增日誌記錄**
```csharp
var debugNode = new ConditionalGraphNode("DebugCondition",
    state => 
    {
        var result = state.GetValueOrDefault("key", "").ToString().Contains("expected");
        Console.WriteLine($"條件評估：{result}，狀態：{state["key"]}");
        return result;
    });
```

2. **隔離測試條件**
```csharp
// 直接測試你的條件函數
var testState = new KernelArguments { ["key"] = "test_value" };
var result = myCondition(testState);
Console.WriteLine($"條件結果：{result}");
```

3. **驗證決策點的狀態**
```csharp
var validationNode = new ConditionalGraphNode("ValidateState",
    state => 
    {
        Console.WriteLine($"決策點的狀態：{JsonSerializer.Serialize(state)}");
        return myCondition(state);
    });
```

## 後續步驟

現在你已經理解了條件節點，請探索這些進階主題：

* **[迴圈教學](loops-tutorial.md)** - 學習迴圈節點和反覆工作流
* **[錯誤處理指南](how-to/error-handling.md)** - 處理工作流中的錯誤和異常
* **[進階路由](how-to/advanced-routing.md)** - 掌握複雜的路由模式
* **[模式](patterns/index.md)** - 探索常見的工作流模式

## 概念和技術

本教學涵蓋了幾個關鍵概念：

* **條件節點** - 一個評估條件並根據結果路由執行的節點
* **條件邊緣** - 只有在其條件評估為 true 時才允許執行的邊緣
* **路由邏輯** - 決定工作流執行路徑的決策過程
* **狀態評估** - 條件如何分析當前狀態以進行路由決策
* **多路徑工作流** - 建立可以根據條件採取不同路徑的工作流

## 前置需求和最小設定

要完成本教學，你需要：
* **SemanticKernel.Graph** 套件已安裝和配置
* **LLM 提供者**帶有有效的 API 金鑰
* **理解**基本圖形概念和狀態管理
* **.NET 8.0+** 執行時環境

## 另請參閱

* **[狀態管理教學](state-tutorial.md)** - 了解資料如何流過你的圖形
* **[第一個圖形教學](first-graph.md)** - 建立你的第一個完整圖形工作流
* **[操作指南](how-to/conditional-nodes.md)** - 進階條件節點技術
* **[API 參考](api/nodes.md)** - 完整的節點 API 文件
