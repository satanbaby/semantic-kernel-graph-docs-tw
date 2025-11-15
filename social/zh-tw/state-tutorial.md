# 狀態管理教程

本教程將教您如何在 SemanticKernel.Graph 中使用狀態。您將學習如何使用 `KernelArguments` 和 `GraphState`、管理節點之間的資料流，以及利用強大的狀態管理功能。

## 您將學到什麼

* 狀態如何在圖表中流動
* 使用 `KernelArguments` 進行輸入和輸出
* 使用 `GraphState` 進行增強的狀態管理
* 狀態驗證和版本控制
* 狀態設計的最佳實踐

## 先決條件

開始之前，請確保您有：
* 完成了[首個圖表教程](first-graph.md)
* 對 SemanticKernel.Graph 概念的基本理解
* 已配置的 LLM 提供者

## 理解圖表中的狀態

### 什麼是狀態？

SemanticKernel.Graph 中的狀態代表在您的工作流程中流動的資料。它就像一個背包，從一個節點傳遞到另一個節點，在整個執行過程中收集和傳遞資訊。

### 狀態組件

* **輸入狀態**：圖表啟動時的初始資料
* **中間狀態**：執行期間每個節點修改的資料
* **輸出狀態**：包含所有結果和中間資料的最終狀態

## 基本狀態管理

### 建立輸入狀態

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;

// 帶有簡單值的基本狀態
var state = new KernelArguments
{
    ["userName"] = "Alice",
    ["userAge"] = 30,
    ["preferences"] = new[] { "AI", "Machine Learning", "Graphs" }
};

// 帶有複雜物件的狀態
var userProfile = new
{
    Name = "Bob",
    Department = "Engineering",
    Skills = new[] { "C#", ".NET", "AI" }
};

var stateWithObjects = new KernelArguments
{
    ["userProfile"] = userProfile,
    ["requestId"] = Guid.NewGuid().ToString(),
    ["timestamp"] = DateTimeOffset.UtcNow
};
```

### 在節點中讀取狀態

```csharp
var analysisNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Analyze this user profile:
        Name: {{$userProfile.Name}}
        Department: {{$userProfile.Department}}
        Skills: {{$userProfile.Skills}}
        
        Provide insights about their technical background and suggest learning paths.
    ")
);
```

### 寫入狀態

```csharp
var processingNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Process the user profile and provide:
        1. Technical assessment
        2. Learning recommendations
        3. Career suggestions
        
        Format as JSON with keys: assessment, recommendations, career
    ")
);

// 將結果儲存在特定的金鑰中
processingNode.StoreResultAs("analysis");
```

## 使用 GraphState 的增強狀態

### 什麼是 GraphState？

`GraphState` 是 `KernelArguments` 的增強包裝器，提供額外的功能，例如：
* 狀態版本控制和驗證
* 執行歷史追蹤
* 元資料管理
* 序列化功能

### 使用 GraphState

```csharp
using SemanticKernel.Graph.State;

// 建立增強的狀態
var graphState = new GraphState(new KernelArguments
{
    ["input"] = "Hello World",
    ["metadata"] = new Dictionary<string, object>
    {
        ["source"] = "tutorial",
        ["version"] = "1.0"
    }
});

// 使用增強功能存取狀態
var input = graphState.GetValue<string>("input");
var metadata = graphState.GetValue<Dictionary<string, object>>("metadata");

        // GraphState 會自動追蹤執行元資料
        Console.WriteLine($"State ID: {graphState.StateId}");
        Console.WriteLine($"Created At: {graphState.CreatedAt}");
```

## 節點間的狀態流

### 建立狀態感知圖表

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

        // 建立與狀態一起工作的節點
        var inputNode = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                Analyze this text: {{$input}}
                Provide:
                1. Sentiment (positive/negative/neutral)
                2. Key topics
                3. Word count
                
                Format as JSON with keys: sentiment, topics, wordCount
            ")
        ).StoreResultAs("analysis");

        var decisionNode = new ConditionalGraphNode(
            state => state.GetValue<string>("analysis")?.Contains("positive") == true,
            name: "RouteBySentiment");

        var positiveNode = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                The analysis shows positive sentiment: {{$analysis}}
                Generate an encouraging response with suggestions for next steps.
            ")
        ).StoreResultAs("response");

        var negativeNode = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                The analysis shows negative sentiment: {{$analysis}}
                Provide empathetic support and constructive feedback.
            ")
        ).StoreResultAs("response");

        var summaryNode = new FunctionGraphNode(
            kernel.CreateFunctionFromPrompt(@"
                Create a summary of this interaction:
                Input: {{$input}}
                Analysis: {{$analysis}}
                Response: {{$response}}
                
                Format as a concise summary paragraph.
            ")
        ).StoreResultAs("summary");

        // 建立圖表
        var graph = new GraphExecutor("StateManagementExample");

        graph.AddNode(inputNode);
        graph.AddNode(decisionNode);
        graph.AddNode(positiveNode);
        graph.AddNode(negativeNode);
        graph.AddNode(summaryNode);

        // 使用條件路由進行連接
        graph.Connect(inputNode.NodeId, decisionNode.NodeId);
        graph.ConnectWhen(decisionNode.NodeId, positiveNode.NodeId, 
            args => args.ToGraphState().GetValue<string>("analysis")?.Contains("positive") == true);
        graph.ConnectWhen(decisionNode.NodeId, negativeNode.NodeId, 
            args => args.ToGraphState().GetValue<string>("analysis")?.Contains("positive") != true);
        graph.Connect(positiveNode.NodeId, summaryNode.NodeId);
        graph.Connect(negativeNode.NodeId, summaryNode.NodeId);

        graph.SetStartNode(inputNode.NodeId);

        // 使用不同的輸入進行執行
        var testInputs = new[]
        {
            "I love working with AI and machine learning!",
            "I'm struggling with this programming problem.",
            "The weather is beautiful today and I feel great!"
        };

        foreach (var input in testInputs)
        {
            Console.WriteLine($"\n=== Testing with: {input} ===");
            
            var state = new KernelArguments { ["input"] = input };
            var result = await graph.ExecuteAsync(kernel, state);
            
            // 執行後從狀態存取結果
            var analysis = state.TryGetValue("analysis", out var analysisValue) ? analysisValue?.ToString() : "No analysis";
            var response = state.TryGetValue("response", out var responseValue) ? responseValue?.ToString() : "No response";
            var summary = state.TryGetValue("summary", out var summaryValue) ? summaryValue?.ToString() : "No summary";
            
            Console.WriteLine($"Sentiment: {analysis}");
            Console.WriteLine($"Response: {response}");
            Console.WriteLine($"Summary: {summary}");
        }
    }
}
```

## 狀態驗證和類型安全

### 類型安全的狀態存取

```csharp
// 使用擴充方法進行類型安全的存取
var state = new KernelArguments
{
    ["count"] = 42,
    ["name"] = "Alice",
    ["isActive"] = true
};

// 使用 TryGetValue 進行類型安全的檢索，包括預設值
var count = state.TryGetValue("count", out var countValue) && countValue is int countInt ? countInt : 0;
var name = state.TryGetValue("name", out var nameValue) && nameValue is string nameString ? nameString : "Unknown";
var isActive = state.TryGetValue("isActive", out var isActiveValue) && isActiveValue is bool isActiveBool ? isActiveBool : false;

// 嘗試取得值並進行類型檢查
if (state.TryGetValue("count", out var countValue) && countValue is int safeCount)
{
    Console.WriteLine($"Count is: {safeCount}");
}
```

### 狀態驗證

```csharp
var validationNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Validate this user data:
        Name: {{$userName}}
        Age: {{$userAge}}
        Email: {{$userEmail}}
        
        Return JSON with validation results:
        {
            "isValid": boolean,
            "errors": [string],
            "warnings": [string]
        }
    ")
).StoreResultAs("validation");

// 新增驗證邏輯
var decisionNode = new ConditionalGraphNode("IsValidUser",
    state => 
    {
        var validation = state.TryGetValue("validation", out var validationValue) ? validationValue?.ToString() : "";
        return validation.Contains("\"isValid\": true");
    });
```

## 進階狀態模式

### 狀態累積

```csharp
var accumulationNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Based on the current conversation history: {{$conversationHistory}}
        And the new input: {{$newInput}}
        
        Update the conversation with the new interaction.
        Return the updated conversation history.
    ")
).StoreResultAs("conversationHistory");

// 使用空的歷史進行初始化
var state = new KernelArguments
{
    ["conversationHistory"] = new List<string>(),
    ["newInput"] = "Hello, I need help with AI"
};
```

### 狀態轉換

```csharp
var transformNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Transform this data structure: {{$rawData}}
        
        Extract and structure the following information:
        - Key insights
        - Action items
        - Priority levels
        
        Return as structured JSON.
    ")
).StoreResultAs("structuredData");
```

## 狀態持久化和檢查點

### 基本檢查點

```csharp
// 在圖表選項中啟用檢查點
builder.AddGraphSupport(options =>
{
    options.Checkpointing.Enabled = true;
    options.Checkpointing.Interval = 3; // 每 3 個節點檢查點一次
});

// 狀態會自動儲存並可以還原
var checkpointManager = kernel.GetRequiredService<ICheckpointManager>();
var savedState = await checkpointManager.SaveCheckpointAsync(graphId, executionId, state);
```

### 狀態序列化

```csharp
// 狀態可以序列化以供外部儲存
var serializedState = JsonSerializer.Serialize(state, new JsonSerializerOptions
{
    WriteIndented = true
});

// 並反序列化回來
var restoredState = JsonSerializer.Deserialize<KernelArguments>(serializedState);
```

## 最佳實踐

### 1. **使用描述性金鑰**
```csharp
// 好的做法
state["userProfile"] = userData;
state["analysisResults"] = analysis;

// 避免
state["data"] = userData;
state["result"] = analysis;
```

### 2. **在關鍵點驗證狀態**
```csharp
var validationNode = new ConditionalGraphNode("ValidateState",
    state => 
    {
        // 檢查必要的欄位是否存在
        var required = new[] { "userProfile", "analysisResults" };
        return required.All(key => state.ContainsKey(key));
    });
```

### 3. **使用類型安全的存取方式**
```csharp
// 使用 TryGetValue 以確保安全性
var count = state.TryGetValue("count", out var countValue) && countValue is int countInt ? countInt : 0;
var name = state.TryGetValue("name", out var nameValue) && nameValue is string nameString ? nameString : "Unknown";
```

### 4. **結構化複雜狀態**
```csharp
// 將相關資料分組
state["user"] = new
{
    Profile = userProfile,
    Preferences = userPreferences,
    History = userHistory
};
```

### 5. **優雅地處理狀態錯誤**
```csharp
var errorHandlerNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt(@"
        Handle this error gracefully: {{$error}}
        Provide a user-friendly message and recovery suggestions.
    ")
).StoreResultAs("errorResponse");
```

## 常見狀態模式

### **設定狀態**
```csharp
var configState = new KernelArguments
{
    ["maxRetries"] = 3,
    ["timeout"] = TimeSpan.FromSeconds(30),
    ["logLevel"] = "Information"
};
```

### **工作階段狀態**
```csharp
var sessionState = new KernelArguments
{
    ["sessionId"] = Guid.NewGuid().ToString(),
    ["startTime"] = DateTimeOffset.UtcNow,
    ["userContext"] = userContext
};
```

### **工作流程狀態**
```csharp
var workflowState = new KernelArguments
{
    ["currentStep"] = "analysis",
    ["completedSteps"] = new[] { "input", "validation" },
    ["nextSteps"] = new[] { "processing", "output" }
};
```

## 狀態問題疑難排解

### **常見問題**

#### 狀態未在節點之間持久化
```
System.Collections.Generic.KeyNotFoundException: The given key 'result' was not present in the dictionary.
```
**解決方案**：確保節點使用 `StoreResultAs()` 或手動狀態賦值來正確儲存結果。

#### 類型轉換錯誤
```
System.InvalidCastException: Unable to cast object of type 'System.String' to type 'System.Int32'.
```
**解決方案**：使用類型安全的存取方法，如 `TryGetValue` 進行類型檢查，或在轉換前驗證類型。

#### 狀態損壞
```
System.Text.Json.JsonException: The JSON value could not be converted to KernelArguments.
```
**解決方案**：檢查狀態序列化/反序列化邏輯，並確保所有物件都是可序列化的。

## 後續步驟

現在您已經理解了狀態管理，請探索這些進階主題：

* **[條件節點指南](how-to/conditional-nodes.md)**：精通條件邏輯和路由
* **[檢查點教程](checkpointing-tutorial.md)**：瞭解狀態持久化和恢復
* **[錯誤處理指南](how-to/error-handling.md)**：處理狀態錯誤和例外
* **[進階模式](patterns/index.md)**：探索複雜的狀態管理模式

## 概念和技術

本教程涵蓋了幾個關鍵概念：

* **狀態**：在圖表中流動的資料，在執行步驟中維持上下文
* **KernelArguments**：保存鍵值對的基本狀態容器
* **GraphState**：具有版本控制、驗證和元資料的增強狀態包裝器
* **狀態流**：資料如何在節點之間移動並在執行期間進行轉換
* **狀態驗證**：確保整個工作流程中的資料完整性和類型安全

## 先決條件和最低配置

要完成本教程，您需要：
* **SemanticKernel.Graph** 套件已安裝並配置
* **LLM 提供者**，包括有效的 API 金鑰
* 從第一個教程獲得的**圖表概念基本理解**
* **.NET 8.0+** 執行環境

## 另請參閱

* **[首個圖表教程](first-graph.md)**：建立您的第一個完整圖表工作流程
* **[核心概念](concepts/index.md)**：理解圖表、節點和執行
* **[API 參考](api/core.md)**：完整的 API 文件
* **[範例](examples/index.md)**：真實使用模式和實現
