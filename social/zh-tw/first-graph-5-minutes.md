# 5分鐘完成第一個 Graph

這個快速教學將在5分鐘內幫助你快速上手 SemanticKernel.Graph。你將建立一個簡單的 Graph、連接 Node，並執行你的第一個工作流。

## 你將建立什麼

一個簡單的「Hello World」Graph，用於展示核心概念：
* 建立支持 Graph 的 kernel
* 建立函數 Node
* 連接 Node 形成工作流
* 執行 Graph 並取得結果

## 概念和技術

**Graph**: 一種由 Node（執行單位）和 Edge（連接）組成的有向圖結構，定義了應用程式中的資料和控制流。

**FunctionGraphNode**: 一種 Node 型別，包裝了 `KernelFunction` 實例，允許你將語義函數作為 Graph 工作流的一部分執行。

**GraphExecutor**: 主要執行引擎，在圖中導航，以正確的順序執行 Node，並管理 Node 之間的資料流。

**KernelBuilderExtensions**: 擴展方法，將 Graph 支持新增到 Semantic Kernel 建構器，啟用基於 Graph 的工作流。

## 先決條件

* [已安裝 SemanticKernel.Graph](installation.md)
* .NET 8.0+ 執行時
* LLM 提供者已設定（OpenAI、Azure OpenAI 等）

## 步驟 1：建立你的專案

```bash
dotnet new console -n MyFirstGraph
cd MyFirstGraph
dotnet add package Microsoft.SemanticKernel
dotnet add package SemanticKernel.Graph
```

## 步驟 2：建立你的第一個 Graph

用以下程式碼替換 `Program.cs`：

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
            // 1. Create kernel and enable graph support
            var builder = Kernel.CreateBuilder();
            builder.AddGraphSupport();
            var kernel = builder.Build();

            // 2. Create simple function nodes
            var greetingNode = CreateGreetingNode(kernel);
            var followUpNode = CreateFollowUpNode(kernel);

            // 3. Build and configure the graph
            var graph = new GraphExecutor("MyFirstGraph", "A simple greeting workflow");
            
            graph.AddNode(greetingNode);
            graph.AddNode(followUpNode);
            
            // Connect nodes in sequence
            graph.Connect(greetingNode.NodeId, followUpNode.NodeId);
            
            // Set the starting point
            graph.SetStartNode(greetingNode.NodeId);

            // 4. Execute the graph
            var initialState = new KernelArguments { ["name"] = "Developer" };
            
            Console.WriteLine("Executing graph...");
            var result = await graph.ExecuteAsync(kernel, initialState);
            
            Console.WriteLine("\n=== Results ===");
            
            // Get results from the graph state
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

## 步驟 3：設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

## 步驟 4：執行你的 Graph

```bash
dotnet run
```

你應該會看到類似的輸出：

```
=== My First Graph ===

Executing graph...

=== Results ===
Greeting: Hello Developer! Welcome to SemanticKernel.Graph.
Follow-up: Based on: 'Hello Developer! Welcome to SemanticKernel.Graph.', here's a follow-up question: How can I help you today?

✅ Graph executed successfully!
```

## 剛剛發生了什麼？

### 1. **Kernel 設定與 Graph 支持**
```csharp
builder.AddGraphSupport();
```
這一行啟用了 Semantic Kernel 實例中的所有 Graph 功能。

### 2. **函數 Graph Node**
```csharp
var greetingNode = CreateGreetingNode(kernel);
// Where CreateGreetingNode creates a FunctionGraphNode with:
// - kernel.CreateFunctionFromMethod(...)
// - .StoreResultAs("greeting") to save the result
```
建立一個包裝簡單函數的 Node，並可以連接到其他 Node。`StoreResultAs` 方法確保結果被保存在 Graph 狀態中。

### 3. **Graph 組裝**
```csharp
graph.AddNode(greetingNode);
graph.AddNode(followUpNode);
graph.Connect(greetingNode.NodeId, followUpNode.NodeId);
```
將 Node 新增到 Graph 中，並使用它們的 NodeId 連接它們以定義執行流。

### 4. **執行**
```csharp
var result = await graph.ExecuteAsync(kernel, initialState);
```
Graph 執行器從起始 Node 開始遍歷，依序執行每個連接的 Node。`kernel` 參數是執行函數所需的。

## 關鍵概念

* **Graph**: 定義工作流執行的已連接 Node 的有向結構
* **Node**: 個別的工作單位（函數、決策、操作）
* **Edge**: 定義執行流的 Node 之間的連接
* **State**: 透過 `KernelArguments` 和 `GraphState` 在 Graph 中流動的資料
* **Executor**: 協調整個工作流的執行

## 存取結果

你的 Graph 執行結果儲存在 `GraphState` 中。以下是存取方式：

```csharp
// Get the graph state from the arguments
var graphState = initialState.GetOrCreateGraphState();

// Access stored results using the keys specified in StoreResultAs()
var greeting = graphState.GetValue<string>("greeting") ?? "No greeting";
var followup = graphState.GetValue<string>("followup") ?? "No follow-up";
```

每個 Node 中的 `StoreResultAs("key")` 方法確保執行結果儲存在 Graph 狀態中的指定鍵下。

## 後續步驟

* **[狀態管理](state-tutorial.md)**: 學習 Node 之間的資料流
* **[條件邏輯](conditional-nodes-tutorial.md)**: 為工作流新增決策功能
* **[核心概念](concepts/index.md)**: 了解基本構件
* **[範例](examples/index.md)**: 查看更多複雜的真實世界模式

## 故障排除

### **找不到 API 金鑰**
```
System.InvalidOperationException: OPENAI_API_KEY not found
```
**解決方案**: 此範例無需 API 金鑰即可運作，因為它使用簡單函數。如果要使用 LLM 函數，請設定環境變數並重新啟動終端機。

### **未設定起始 Node**
```
System.InvalidOperationException: No start node configured
```
**解決方案**: 用有效的 Node 呼叫 `graph.SetStartNode()`。

### **Node 未連接**
```
System.InvalidOperationException: No next nodes found
```
**解決方案**: 使用 `graph.Connect()` 連接你的 Node。

## 概念和技術

本教學介紹了幾個關鍵概念：

* **Graph**: 定義工作流執行的 Node 和 Edge 的有向結構
* **Node**: 可以執行函數、做出決策或執行操作的個別工作單位
* **Edge**: 定義執行序列的 Node 之間的連接
* **State**: 在 Graph 中流動的資料，在執行步驟之間維護上下文
* **執行**: 遍歷 Graph、執行 Node 並管理狀態轉換的過程

## 先決條件和最小設定

若要完成本教學，你需要：
* **.NET 8.0+** 執行時和 SDK
* 已安裝 **SemanticKernel.Graph** 套件
* 已設定 **LLM 提供者**且有效的 API 金鑰
* 已設定 **環境變數**用於 API 認證

## 另請參閱

* **[安裝指南](installation.md)**: 在你的專案中設定 SemanticKernel.Graph
* **[核心概念](concepts/index.md)**: 了解 Graph、Node 和執行
* **[操作指南](how-to/build-a-graph.md)**: 建立更複雜的 Graph 工作流
* **[API 參考](api/core.md)**: 完整的 API 文件

## 參考 API

* **[IGraphExecutor](../api/core.md#igraph-executor)**: 核心執行介面
* **[FunctionGraphNode](../api/nodes.md#function-graph-node)**: 函數包裝器 Node
* **[GraphExecutor](../api/core.md#graph-executor)**: 主要執行引擎
* **[KernelBuilderExtensions](../api/extensions.md#kernel-builder-extensions)**: Graph 支持擴展
* **[GraphState](../api/state-and-serialization.md)**: 狀態管理和結果儲存
