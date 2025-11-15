# 5分鐘內建立第一個圖表

這個快速教程將在短短 5 分鐘內讓您開始使用 SemanticKernel.Graph。您將建立一個簡單的圖表、連接節點，並執行您的第一個工作流程。

## 您將建立什麼

一個簡單的「Hello World」圖表，展示核心概念：
* 建立支持圖表的核心
* 建立函數節點
* 連接節點以形成工作流程
* 執行圖表並取得結果

## 概念和技術

**圖表**：由節點（執行單元）和邊（連接）組成的有向圖結構，定義應用程式中資料和控制流。

**FunctionGraphNode**：節點類型，包裝 `KernelFunction` 實例，允許您在圖表工作流程中執行語義函數。

**GraphExecutor**：主要執行引擎，在圖表中導航，按正確的順序執行節點，並管理節點之間的資料流。

**KernelBuilderExtensions**：擴展方法，將圖表支持新增至語義核心建置器，啟用基於圖表的工作流程。

## 先決條件

* [已安裝 SemanticKernel.Graph](installation.md)
* .NET 8.0+ 運行時
* 已配置 LLM 提供程式（OpenAI、Azure OpenAI 等）

## 第 1 步：建立您的專案

```bash
dotnet new console -n MyFirstGraph
cd MyFirstGraph
dotnet add package Microsoft.SemanticKernel
dotnet add package SemanticKernel.Graph
```

## 第 2 步：建立您的第一個圖表

將 `Program.cs` 替換為以下程式碼：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("=== My First Graph ===\n");

        try
        {
            // 1. 建立核心並啟用圖表支持
            var builder = Kernel.CreateBuilder();
            builder.AddGraphSupport();
            var kernel = builder.Build();

            // 2. 建立簡單的函數節點
            var greetingNode = CreateGreetingNode(kernel);
            var followUpNode = CreateFollowUpNode(kernel);

            // 3. 建立並配置圖表
            var graph = new GraphExecutor("MyFirstGraph", "A simple greeting workflow");
            
            graph.AddNode(greetingNode);
            graph.AddNode(followUpNode);
            
            // 按順序連接節點
            graph.Connect(greetingNode.NodeId, followUpNode.NodeId);
            
            // 設定起始點
            graph.SetStartNode(greetingNode.NodeId);

            // 4. 執行圖表
            var initialState = new KernelArguments { ["name"] = "Developer" };
            
            Console.WriteLine("Executing graph...");
            var result = await graph.ExecuteAsync(kernel, initialState);
            
            Console.WriteLine("\n=== Results ===");
            
            // 從圖表狀態取得結果
            var graphState = initialState.GetOrCreateGraphState();
            var greeting = graphState.GetValue<string>("greeting") ?? "No greeting";
            var followup = graphState.GetValue<string>("followup") ?? "No follow-up";
            
            Console.WriteLine($"Greeting: {greeting}");
            Console.WriteLine($"Follow-up: {followup}");
            
            Console.WriteLine("\n✅ Graph executed successfully!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error executing graph: {ex.Message}");
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

## 第 3 步：設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

## 第 4 步：執行您的圖表

```bash
dotnet run
```

您應該會看到類似的輸出：

```
=== My First Graph ===

Executing graph...

=== Results ===
Greeting: Hello Developer! Welcome to SemanticKernel.Graph.
Follow-up: Based on: 'Hello Developer! Welcome to SemanticKernel.Graph.', here's a follow-up question: How can I help you today?

✅ Graph executed successfully!
```

## 發生了什麼？

### 1. **支持圖表的核心設定**
```csharp
builder.AddGraphSupport();
```
這一行啟用了您的語義核心實例中的所有圖表功能。

### 2. **函數圖表節點**
```csharp
var greetingNode = CreateGreetingNode(kernel);
// 其中 CreateGreetingNode 建立一個 FunctionGraphNode，具有：
// - kernel.CreateFunctionFromMethod(...)
// - .StoreResultAs("greeting") 以保存結果
```
建立一個節點，包裝簡單函數，並可連接到其他節點。`StoreResultAs` 方法確保結果保存在圖表狀態中。

### 3. **圖表組裝**
```csharp
graph.AddNode(greetingNode);
graph.AddNode(followUpNode);
graph.Connect(greetingNode.NodeId, followUpNode.NodeId);
```
將節點新增至圖表並使用其 NodeId 連接它們以定義執行流。

### 4. **執行**
```csharp
var result = await graph.ExecuteAsync(kernel, initialState);
```
圖表執行器從起始節點開始遍歷，按順序執行每個連接的節點。`kernel` 參數是執行函數所需的。

## 關鍵概念

* **圖表**：連接節點的有向結構，定義工作流程執行
* **節點**：個別工作單元（函數、決策、操作）
* **邊**：節點之間的連接，定義執行流
* **狀態**：通過 `KernelArguments` 和 `GraphState` 在圖表中流動的資料
* **執行器**：編排整個工作流程執行

## 存取結果

圖表執行的結果儲存在 `GraphState` 中。以下是存取方式：

```csharp
// 從參數取得圖表狀態
var graphState = initialState.GetOrCreateGraphState();

// 使用在 StoreResultAs() 中指定的鍵存取儲存的結果
var greeting = graphState.GetValue<string>("greeting") ?? "No greeting";
var followup = graphState.GetValue<string>("followup") ?? "No follow-up";
```

每個節點中的 `StoreResultAs("key")` 方法確保執行結果以指定的鍵儲存在圖表狀態中。

## 後續步驟

* **[狀態管理](state-tutorial.md)**：了解節點之間的資料流
* **[條件邏輯](conditional-nodes-tutorial.md)**：為工作流程新增決策功能
* **[核心概念](concepts/index.md)**：了解基本構建塊
* **[範例](examples/index.md)**：查看更多複雜的真實世界模式

## 故障排除

### **找不到 API 金鑰**
```
System.InvalidOperationException: OPENAI_API_KEY not found
```
**解決方案**：此範例可在沒有 API 金鑰的情況下運作，因為它使用簡單函數。如果您想使用 LLM 函數，請設定您的環境變數並重新啟動您的終端。

### **未配置起始節點**
```
System.InvalidOperationException: No start node configured
```
**解決方案**：使用有效的節點呼叫 `graph.SetStartNode()`。

### **節點未連接**
```
System.InvalidOperationException: No next nodes found
```
**解決方案**：使用 `graph.Connect()` 連結您的節點。

## 概念和技術

本教程介紹了幾個關鍵概念：

* **圖表**：定義工作流程執行的節點和邊的有向結構
* **節點**：個別工作單元，可執行函數、做決策或執行操作
* **邊**：節點之間的連接，定義執行順序
* **狀態**：通過圖表流動的資料，維持執行步驟間的上下文
* **執行**：遍歷圖表、執行節點和管理狀態轉換的過程

## 先決條件和最低配置

若要完成此教程，您需要：
* **.NET 8.0+** 運行時和 SDK
* 已安裝 **SemanticKernel.Graph** 套件
* 已配置 **LLM 提供程式**，具有有效的 API 金鑰
* 為 API 認證設定的 **環境變數**

## 另請參閱

* **[安裝指南](installation.md)**：在專案中設定 SemanticKernel.Graph
* **[核心概念](concepts/index.md)**：了解圖表、節點和執行
* **[操作指南](how-to/build-a-graph.md)**：建立更複雜的圖表工作流程
* **[API 參考](api/core.md)**：完整的 API 文檔

## 參考 API

* **[IGraphExecutor](../api/core.md#igraph-executor)**：核心執行介面
* **[FunctionGraphNode](../api/nodes.md#function-graph-node)**：函數包裝節點
* **[GraphExecutor](../api/core.md#graph-executor)**：主要執行引擎
* **[KernelBuilderExtensions](../api/extensions.md#kernel-builder-extensions)**：圖表支持擴展
* **[GraphState](../api/state-and-serialization.md)**：狀態管理和結果儲存
