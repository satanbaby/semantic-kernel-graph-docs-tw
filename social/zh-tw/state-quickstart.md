# 狀態快速入門

本快速教程將教您如何在 SemanticKernel.Graph 中處理狀態。您將學習如何使用 `KernelArguments` 和 `GraphState` 與擴充方法來管理節點間的資料流動。

## 您將學習的內容

* 使用 `KernelArguments` 建立和管理狀態
* 使用 `GraphState` 進行增強的狀態管理
* 使用擴充方法讀寫變數
* 節點間的狀態流動
* 基本狀態驗證和追蹤

## 概念和技術

**KernelArguments**: 一個類似字典的容器，包含代表圖形執行狀態和上下文的鍵值對。

**GraphState**: 圍繞 `KernelArguments` 的增強包裝器，提供額外的後設資料、驗證和序列化功能。

**State Flow**: 當圖形執行時，資料在節點間移動，其中每個節點都可以讀取和寫入共享狀態。

**Extension Methods**: 使用圖形特定功能擴充 `KernelArguments` 的實用方法，便於狀態管理。

## 先決條件

* [第一個圖形教程](first-graph-5-minutes.md)已完成
* 對 SemanticKernel.Graph 概念的基本理解
* .NET 8.0+ 執行時

## 步驟 1：基本狀態建立

### 使用 KernelArguments 的簡單狀態

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;

// 建立基本狀態
var state = new KernelArguments
{
    ["userName"] = "Alice",
    ["userAge"] = 30,
    ["preferences"] = new[] { "AI", "Machine Learning", "Graphs" }
};

// 新增更多值
state["timestamp"] = DateTimeOffset.UtcNow;
state["requestId"] = Guid.NewGuid().ToString();
```

### 狀態中的複雜物件

```csharp
// 複雜物件
var userProfile = new
{
    Name = "Bob",
    Department = "Engineering",
    Skills = new[] { "C#", ".NET", "AI" },
    Experience = 5
};

var stateWithObjects = new KernelArguments
{
    ["userProfile"] = userProfile,
    ["metadata"] = new Dictionary<string, object>
    {
        ["source"] = "tutorial",
        ["version"] = "1.0"
    }
};
```

## 步驟 2：讀取狀態值

### 基本讀取

```csharp
// 讀取簡單值
var name = state["userName"]; // 返回物件
var age = state.TryGetValue("userAge", out var ageValue) ? ageValue : 0; // 安全讀取
var preferences = state.TryGetValue("preferences", out var prefValue) ? prefValue : new string[0];

// 使用預設值進行安全讀取
var department = state.TryGetValue("department", out var deptValue) ? deptValue : "Unknown";
var score = state.TryGetValue("score", out var scoreValue) ? scoreValue : 0;
```

### 讀取複雜物件

```csharp
// 讀取複雜物件
var profile = state.TryGetValue("userProfile", out var profileValue) ? profileValue : null;
var metadata = state.TryGetValue("metadata", out var metadataValue) ? metadataValue : null;

// 檢查鍵是否存在
if (state.ContainsKey("userProfile"))
{
    var userName = state["userProfile"];
    // 處理使用者設定檔
}
```

## 步驟 3：寫入狀態

### 基本寫入

```csharp
// 設定值
state["processed"] = true;
state["result"] = "Success";
state["score"] = 95.5;

// 更新現有值
state["userAge"] = 31; // 覆寫現有值
```

### 使用擴充方法

```csharp
// 轉換為 GraphState 以獲得增強功能
var graphState = state.ToGraphState();

// 新增執行追蹤
state.StartExecutionStep("analysis_node", "AnalyzeUser");
state.SetCurrentNode("analysis_node");

// 完成執行步驟
state.CompleteExecutionStep("Analysis completed successfully");
```

## 步驟 4：使用 GraphState 增強狀態

### 建立 GraphState

```csharp
using SemanticKernel.Graph.State;

// 從 KernelArguments 建立 GraphState
var graphState = new GraphState(state);

// 或使用擴充方法
var enhancedState = state.ToGraphState();

// 存取增強功能
var stateId = enhancedState.StateId;
var version = enhancedState.Version;
var createdAt = enhancedState.CreatedAt;
```

### 狀態驗證和後設資料

```csharp
// 新增後設資料
enhancedState.SetMetadata("source", "user_input");
enhancedState.SetMetadata("priority", "high");

// 取得執行歷史
var history = enhancedState.ExecutionHistory;
var stepCount = enhancedState.ExecutionStepCount;
```

## 步驟 5：節點間的狀態流動

### 建立狀態感知圖形

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

class Program
{
    static async Task Main(string[] args)
    {
        var builder = Kernel.CreateBuilder();
        builder.AddOpenAIChatCompletion("gpt-3.5-turbo", Environment.GetEnvironmentVariable("OPENAI_API_KEY"));
        builder.AddGraphSupport();
        var kernel = builder.Build();

        // 節點 1：輸入處理
        var inputNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var input = args.TryGetValue("input", out var inputValue) ? inputValue?.ToString() : "No input";
                    var processed = $"Processed: {input?.ToUpper()}";
                    
                    // 寫入狀態
                    args["processedInput"] = processed;
                    args["wordCount"] = input?.Split(' ')?.Length ?? 0;
                    args["timestamp"] = DateTimeOffset.UtcNow;
                    
                    return processed;
                },
                "ProcessInput",
                "Processes and analyzes input text"
            ),
            "input_node"
        ).StoreResultAs("inputResult");

        // 節點 2：分析
        var analysisNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var processedInput = args.TryGetValue("processedInput", out var processedValue) ? processedValue?.ToString() : "";
                    var wordCount = args.TryGetValue("wordCount", out var wordCountValue) ? Convert.ToInt32(wordCountValue) : 0;
                    
                    // 執行分析
                    var sentiment = wordCount > 5 ? "Detailed" : "Brief";
                    var complexity = wordCount > 10 ? "High" : "Low";
                    
                    // 將分析寫入狀態
                    args["sentiment"] = sentiment;
                    args["complexity"] = complexity;
                    args["analysisComplete"] = true;
                    
                    return $"Analysis: {sentiment} content with {complexity} complexity";
                },
                "AnalyzeContent",
                "Analyzes content characteristics"
            ),
            "analysis_node"
        ).StoreResultAs("analysisResult");

        // 節點 3：摘要
        var summaryNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    // 讀取所有狀態值
                    var input = args.TryGetValue("input", out var inputValue) ? inputValue?.ToString() : "No input";
                    var processed = args.TryGetValue("processedInput", out var processedValue) ? processedValue?.ToString() : "No processed input";
                    var wordCount = args.TryGetValue("wordCount", out var wordCountValue) ? Convert.ToInt32(wordCountValue) : 0;
                    var sentiment = args.TryGetValue("sentiment", out var sentimentValue) ? sentimentValue?.ToString() : "No sentiment";
                    var complexity = args.TryGetValue("complexity", out var complexityValue) ? complexityValue?.ToString() : "No complexity";
                    
                    var summary = $"Input: '{input}' -> Processed: '{processed}' -> " +
                                $"Word Count: {wordCount}, Sentiment: {sentiment}, Complexity: {complexity}";
                    
                    args["finalSummary"] = summary;
                    return summary;
                },
                "CreateSummary",
                "Creates final summary from all state data"
            ),
            "summary_node"
        ).StoreResultAs("summaryResult");

        // 建立和配置圖形
        var graph = new GraphExecutor("StateFlowExample", "Demonstrates state flow between nodes");
        
        graph.AddNode(inputNode);
        graph.AddNode(analysisNode);
        graph.AddNode(summaryNode);
        
        // 使用節點名稱連接節點
        graph.Connect("input_node", "analysis_node");
        graph.Connect("analysis_node", "summary_node");
        
        graph.SetStartNode("input_node");

        // 使用初始狀態執行
        var initialState = new KernelArguments
        {
            ["input"] = "Hello world from SemanticKernel.Graph"
        };
        
        Console.WriteLine("=== State Flow Example ===\n");
        Console.WriteLine("Executing graph...");
        
        var result = await graph.ExecuteAsync(kernel, initialState);
        
        Console.WriteLine("\n=== Final State ===");
        Console.WriteLine($"Input: {initialState.TryGetValue("input", out var input) ? input : "Not found"}");
        Console.WriteLine($"Processed: {initialState.TryGetValue("processedInput", out var processed) ? processed : "Not found"}");
        Console.WriteLine($"Word Count: {initialState.TryGetValue("wordCount", out var wordCount) ? wordCount : "Not found"}");
        Console.WriteLine($"Sentiment: {initialState.TryGetValue("sentiment", out var sentiment) ? sentiment : "Not found"}");
        Console.WriteLine($"Complexity: {initialState.TryGetValue("complexity", out var complexity) ? complexity : "Not found"}");
        Console.WriteLine($"Summary: {initialState.TryGetValue("finalSummary", out var summary) ? summary : "Not found"}");
        
        Console.WriteLine($"\nFinal Result: {result.GetValueAsString()}");
        
        Console.WriteLine("\n✅ State flow completed successfully!");
    }
}
```

## 步驟 6：執行您的狀態範例

### 設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

### 執行圖形

```bash
dotnet run
```

您應該看到如下輸出：

```
=== State Flow Example ===

Executing graph...

=== Final State ===
Input: Hello world from SemanticKernel.Graph
Processed: Processed: HELLO WORLD FROM SEMANTICKERNEL.GRAPH
Word Count: 5
Sentiment: Brief
Complexity: Low
Summary: Input: 'Hello world from SemanticKernel.Graph' -> Processed: 'Processed: HELLO WORLD FROM SEMANTICKERNEL.GRAPH' -> Word Count: 5, Sentiment: Brief, Complexity: Low

Final Result: Input: 'Hello world from SemanticKernel.Graph' -> Processed: 'Processed: HELLO WORLD FROM SEMANTICKERNEL.GRAPH' -> Word Count: 5, Sentiment: Brief, Complexity: Low

✅ State flow completed successfully!
```

## 剛才發生了什麼？

### 1. **狀態建立和管理**
```csharp
var state = new KernelArguments { ["userName"] = "Alice" };
```
`KernelArguments` 提供一個靈活的類似字典的結構來儲存狀態資料。

### 2. **類型安全的狀態讀取**
```csharp
var age = state.TryGetValue("userAge", out var ageValue) ? ageValue : 0;
var name = state.TryGetValue("name", out var nameValue) ? nameValue : "Unknown";
```
使用 `TryGetValue` 進行帶回退值的安全讀取。

### 3. **狀態寫入和更新**
```csharp
state["processed"] = true;
state["result"] = "Success";
```
簡單的鍵值指派用於寫入狀態。

### 4. **使用 GraphState 增強狀態**
```csharp
var graphState = state.ToGraphState();
```
`GraphState` 新增執行追蹤、後設資料和驗證功能。

### 5. **節點間的狀態流動**
每個節點讀取和寫入共享狀態，建立通過圖形流動的資料管道。

## 關鍵概念

* **State**: 通過圖形流動的資料，維護在 `KernelArguments` 中
* **GraphState**: 增強包裝器，新增執行追蹤和後設資料
* **State Flow**: 資料通過圖形從節點移動到節點，每個節點讀取輸入並寫入輸出
* **Safe Reading**: 使用 `TryGetValue` 進行帶回退預設值的安全讀取狀態值
* **Type Safety**: 讀取狀態值時使用適當的類型檢查和轉換

## 常見模式

### 狀態初始化
```csharp
var state = new KernelArguments
{
    ["input"] = userInput,
    ["metadata"] = new Dictionary<string, object>(),
    ["timestamp"] = DateTimeOffset.UtcNow
};
```

### 帶驗證的狀態讀取
```csharp
if (state.TryGetValue("requiredField", out var value))
{
    var typedValue = value as string;
    if (!string.IsNullOrEmpty(typedValue))
    {
        // 處理值
    }
}
```

### 帶後設資料的狀態寫入
```csharp
state["result"] = processedData;
state["processingTime"] = stopwatch.ElapsedMilliseconds;
state["nodeId"] = "processor_node";
```

## 疑難排解

### **找不到狀態鍵**
```
System.Collections.Generic.KeyNotFoundException: The given key 'missingKey' was not present
```
**解決方案**: 使用 `TryGetValue` 或在讀取前使用 `ContainsKey()` 檢查。

### **類型轉換錯誤**
```
System.InvalidCastException: Unable to cast object of type 'System.Int32' to type 'System.String'
```
**解決方案**: 讀取狀態值時使用適當的類型檢查和轉換。

### **狀態未在節點間保留**
```
State values are missing in subsequent nodes
```
**解決方案**: 確保節點已正確連接，並正確配置圖形執行器。

## 後續步驟

* **[條件邏輯](conditional-nodes-tutorial.md)**: 根據狀態值新增決策
* **[狀態管理教程](state-tutorial.md)**: 進階狀態功能和模式
* **[檢查點](how-to/checkpointing.md)**: 儲存和恢復圖形狀態
* **[核心概念](concepts/index.md)**: 理解基本構建塊

## 概念和技術

本教程介紹了幾個關鍵概念：

* **State**: 通過圖形流動的資料，跨執行步驟維護上下文
* **KernelArguments**: Semantic Kernel 中狀態資料的主要容器
* **GraphState**: 具有執行追蹤和後設資料的增強狀態包裝器
* **State Flow**: 資料通過圖形從節點移動到節點的模式

## 先決條件和最低配置

要完成本教程，您需要：
* **.NET 8.0+** 執行時和 SDK
* **SemanticKernel.Graph** 套件已安裝
* **LLM Provider** 已配置有效的 API 金鑰
* **環境變數** 為您的 API 認證設定

## 參見

* **[第一個圖形教程](first-graph-5-minutes.md)**: 建立您的第一個圖形工作流
* **[狀態管理教程](state-tutorial.md)**: 進階狀態管理概念
* **[核心概念](concepts/index.md)**: 理解圖形、節點和執行
* **[API 參考](api/state.md)**: 完整狀態管理 API 文件

## 參考 API

* **[KernelArguments](../api/core.md#kernel-arguments)**: 核心狀態容器
* **[GraphState](../api/state.md#graph-state)**: 增強狀態包裝器
* **[State Extensions](../api/extensions.md)**: 狀態擴充方法
* **[ISerializableState](../api/state.md#iserializable-state)**: 狀態序列化介面
