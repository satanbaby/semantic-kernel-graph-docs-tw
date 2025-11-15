# 5 分鐘內建立第一個圖

本快速教學將讓您在短短 5 分鐘內開始使用 SemanticKernel.Graph。您將建立一個簡單的圖、連接節點，並執行您的第一個工作流程。

## 您將建立什麼

一個展示核心概念的簡單「Hello World」圖：
* 建立具有圖支援的核心
* 建立函式節點
* 連接節點以形成工作流程
* 執行圖並取得結果

## 概念與技術

**圖**：由節點（執行單元）和邊（連接）組成的有向圖結構，定義了應用程式中資料和控制的流程。

**FunctionGraphNode**：包裝 `KernelFunction` 實例的節點類型，讓您能夠在圖工作流程中執行語義函式。

**GraphExecutor**：主要的執行引擎，可導航圖、按正確順序執行節點，並管理節點之間的資料流。

**KernelBuilderExtensions**：將圖支援新增至 Semantic Kernel 建構器的擴充方法，啟用基於圖的工作流程。

## 先決條件

* [已安裝 SemanticKernel.Graph](installation.md)
* .NET 8.0+ 執行階段
* 已設定 LLM 提供者（OpenAI、Azure OpenAI 等）

## 步驟 1：建立您的專案

```bash
dotnet new console -n MyFirstGraph
cd MyFirstGraph
dotnet add package Microsoft.SemanticKernel
dotnet add package SemanticKernel.Graph
```

## 步驟 2：建立您的第一個圖

將 `Program.cs` 替換為此程式碼：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("=== 我的第一個圖 ===\n");

        try
        {
            // 1. 建立核心並啟用圖支援
            var builder = Kernel.CreateBuilder();
            builder.AddGraphSupport();
            var kernel = builder.Build();

            // 2. 建立簡單的函式節點
            var greetingNode = CreateGreetingNode(kernel);
            var followUpNode = CreateFollowUpNode(kernel);

            // 3. 建立並設定圖
            var graph = new GraphExecutor("MyFirstGraph", "A simple greeting workflow");
            
            graph.AddNode(greetingNode);
            graph.AddNode(followUpNode);
            
            // 循序連接節點
            graph.Connect(greetingNode.NodeId, followUpNode.NodeId);
            
            // 設定起始點
            graph.SetStartNode(greetingNode.NodeId);

            // 4. 執行圖
            var initialState = new KernelArguments { ["name"] = "Developer" };
            
            Console.WriteLine("執行圖中...");
            var result = await graph.ExecuteAsync(kernel, initialState);
            
            Console.WriteLine("\n=== 結果 ===");
            
            // 從圖狀態取得結果
            var graphState = initialState.GetOrCreateGraphState();
            var greeting = graphState.GetValue<string>("greeting") ?? "No greeting";
            var followup = graphState.GetValue<string>("followup") ?? "No follow-up";
            
            Console.WriteLine($"問候語: {greeting}");
            Console.WriteLine($"後續問題: {followup}");
            
            Console.WriteLine("\n✅ 圖執行成功！");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ 執行圖時發生錯誤: {ex.Message}");
        }
    }

    private static FunctionGraphNode CreateGreetingNode(Kernel kernel)
    {
        var greetingFunction = kernel.CreateFunctionFromMethod(
            (string name) => $"Hello {name}! Welcome to SemanticKernel.Graph.",
            functionName: "GenerateGreeting",
            description: "Creates a personalized greeting"
        );

        var node = new FunctionGraphNode(greetingFunction, "greeting_node")
            .StoreResultAs("greeting");

        return node;
    }

    private static FunctionGraphNode CreateFollowUpNode(Kernel kernel)
    {
        var followUpFunction = kernel.CreateFunctionFromMethod(
            (string greeting) => $"Based on: '{greeting}', here's a follow-up question: How can I help you today?",
            functionName: "GenerateFollowUp",
            description: "Creates a follow-up question"
        );

        var node = new FunctionGraphNode(followUpFunction, "followup_node")
            .StoreResultAs("followup");

        return node;
    }
}
```

## 步驟 3：設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

## 步驟 4：執行您的圖

```bash
dotnet run
```

您應該會看到類似以下的輸出：

```
=== 我的第一個圖 ===

執行圖中...

=== 結果 ===
問候語: Hello Developer! Welcome to SemanticKernel.Graph.
後續問題: Based on: 'Hello Developer! Welcome to SemanticKernel.Graph.', here's a follow-up question: How can I help you today?

✅ 圖執行成功！
```

## 剛才發生了什麼？

### 1. **具有圖支援的核心設定**
```csharp
builder.AddGraphSupport();
```
這一行就能啟用 Semantic Kernel 實例中的所有圖功能。

### 2. **函式圖節點**
```csharp
var greetingNode = CreateGreetingNode(kernel);
// CreateGreetingNode 建立一個 FunctionGraphNode，包含：
// - kernel.CreateFunctionFromMethod(...)
// - .StoreResultAs("greeting") 儲存結果
```
建立一個包裝簡單函式的節點，可以連接到其他節點。`StoreResultAs` 方法確保結果儲存在圖狀態中。

### 3. **圖組裝**
```csharp
graph.AddNode(greetingNode);
graph.AddNode(followUpNode);
graph.Connect(greetingNode.NodeId, followUpNode.NodeId);
```
將節點新增至圖，並使用它們的 NodeId 連接它們以定義執行流程。

### 4. **執行**
```csharp
var result = await graph.ExecuteAsync(kernel, initialState);
```
圖執行器從起始節點遍歷，循序執行每個連接的節點。`kernel` 參數是函式執行所必需的。

## 關鍵概念

* **圖**：定義工作流程執行的連接節點的有向結構
* **節點**：個別的工作單元（函式、決策、操作）
* **邊**：定義執行流程的節點之間的連接
* **狀態**：透過 `KernelArguments` 和 `GraphState` 流經圖的資料
* **執行器**：編排整個工作流程執行

## 存取結果

圖執行的結果儲存在 `GraphState` 中。以下是存取它們的方法：

```csharp
// 從參數取得圖狀態
var graphState = initialState.GetOrCreateGraphState();

// 使用 StoreResultAs() 中指定的鍵存取儲存的結果
var greeting = graphState.GetValue<string>("greeting") ?? "No greeting";
var followup = graphState.GetValue<string>("followup") ?? "No follow-up";
```

每個節點中的 `StoreResultAs("key")` 方法確保執行結果儲存在圖狀態中的指定鍵下。

## 下一步

* **[狀態管理](state-tutorial.md)**：學習處理節點之間的資料流
* **[條件式邏輯](conditional-nodes-tutorial.md)**：為您的工作流程新增決策功能
* **[核心概念](concepts/index.md)**：了解基本建構區塊
* **[範例](examples/index.md)**：查看更複雜的實際模式

## 疑難排解

### **找不到 API 金鑰**
```
System.InvalidOperationException: OPENAI_API_KEY not found
```
**解決方案**：此範例不需要 API 金鑰即可運作，因為它使用簡單函式。如果您想使用 LLM 函式，請設定環境變數並重新啟動終端機。

### **未設定起始節點**
```
System.InvalidOperationException: No start node configured
```
**解決方案**：使用有效的節點呼叫 `graph.SetStartNode()`。

### **節點未連接**
```
System.InvalidOperationException: No next nodes found
```
**解決方案**：使用 `graph.Connect()` 連結您的節點。

## 概念與技術

本教學介紹了幾個關鍵概念：

* **圖**：定義工作流程執行的節點和邊的有向結構
* **節點**：可以執行函式、做出決策或執行操作的個別工作單元
* **邊**：定義執行順序的節點之間的連接
* **狀態**：流經圖的資料，在執行步驟之間維護上下文
* **執行**：遍歷圖、執行節點和管理狀態轉換的過程

## Prerequisites and Minimum Configuration

To complete this tutorial, you need:
* **.NET 8.0+** runtime and SDK
* **SemanticKernel.Graph** package installed
* **LLM Provider** configured with valid API keys
* **Environment Variables** set up for your API credentials

## See Also

* **[Installation Guide](installation.md)**: Set up SemanticKernel.Graph in your project
* **[Core Concepts](concepts/index.md)**: Understanding graphs, nodes, and execution
* **[How-to Guides](how-to/build-a-graph.md)**: Building more complex graph workflows
* **[API Reference](api/core.md)**: Complete API documentation

## Reference APIs

* **[IGraphExecutor](../api/core.md#igraph-executor)**: Core execution interface
* **[FunctionGraphNode](../api/nodes.md#function-graph-node)**: Function wrapper node
* **[GraphExecutor](../api/core.md#graph-executor)**: Main execution engine
* **[KernelBuilderExtensions](../api/extensions.md#kernel-builder-extensions)**: Graph support extensions
* **[GraphState](../api/state-and-serialization.md)**: State management and result storage
