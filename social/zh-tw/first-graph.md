# 5 分鐘內建立您的第一個 Graph

本教學將引導您使用 SemanticKernel.Graph 建立您的第一個 Graph 工作流程。您將學習如何建立 Kernel、啟用 Graph 支援、建置 Node、連接它們，以及執行您的第一個 Graph。

## 您將建立什麼

您將建立一個簡單的「Hello World」Graph，示範基本概念：
* 一個處理輸入的 Function Node
* 一個做出決策的 Conditional Node
* 基本的狀態管理
* Graph 執行

## 先決條件

開始之前，請確保您有：
* [已在您的專案中安裝 SemanticKernel.Graph](installation.md)
* 一個配置好的 LLM 提供者（OpenAI、Azure OpenAI 等）
* 在環境變數中設定的 API 金鑰

## 步驟 1：設定您的專案

### 建立新的控制台應用程式

```bash
dotnet new console -n MyFirstGraph
cd MyFirstGraph
```

### 新增必要的套件

```bash
dotnet add package Microsoft.SemanticKernel
dotnet add package SemanticKernel.Graph
```

### 設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

## 步驟 2：建立您的第一個 Graph

將 `Program.cs` 的內容替換為此代碼：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("=== My First Graph ===\n");

        try
        {
            // Step 1: Create and configure your kernel with graph support
            var kernel = CreateKernelWithGraphSupport();

            // Step 2: Create all the nodes for our graph workflow
            var (greetingNode, decisionNode, followUpNode) = CreateGraphNodes(kernel);

            // Step 3: Build and configure the complete graph
            var graph = BuildAndConfigureGraph(greetingNode, decisionNode, followUpNode);

            // Step 4: Execute the graph with sample input
            await ExecuteGraphWithSampleInputAsync(graph, kernel);

            Console.WriteLine("\n✅ Your first graph executed successfully!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error executing first graph: {ex.Message}");
        }
    }

    /// <summary>
    /// Creates and configures a kernel with graph support enabled.
    /// This demonstrates the basic setup required for graph-based workflows.
    /// </summary>
    /// <returns>A configured kernel instance with graph support</returns>
    private static Kernel CreateKernelWithGraphSupport()
    {
        Console.WriteLine("Step 1: Creating kernel with graph support...");

        // Create a new kernel builder instance
        var builder = Kernel.CreateBuilder();

        // Add OpenAI chat completion service (you can replace with your preferred LLM)
        // Note: In a real application, you would use your actual API key
        var apiKey = Environment.GetEnvironmentVariable("OPENAI_API_KEY");
        if (!string.IsNullOrEmpty(apiKey))
        {
            builder.AddOpenAIChatCompletion("gpt-4", apiKey);
        }
        else
        {
            // Fallback to a mock function for demonstration purposes
            Console.WriteLine("⚠️  OPENAI_API_KEY not found. Using mock functions for demonstration.");
        }

        // Enable graph functionality with a single line - this registers all necessary services
        builder.AddGraphSupport();

        // Build the kernel with all configured services
        var kernel = builder.Build();

        Console.WriteLine("✅ Kernel created successfully with graph support enabled");
        return kernel;
    }

    /// <summary>
    /// Creates all the nodes needed for the graph workflow.
    /// Demonstrates different node types: function nodes and conditional nodes.
    /// </summary>
    /// <param name="kernel">The configured kernel instance</param>
    /// <returns>A tuple containing all created nodes</returns>
    private static (FunctionGraphNode greetingNode, ConditionalGraphNode decisionNode, FunctionGraphNode followUpNode) 
        CreateGraphNodes(Kernel kernel)
    {
        Console.WriteLine("Step 2: Creating graph nodes...");

        // Create a function node that generates personalized greetings
        // This node will process the input name and generate a friendly greeting
        var greetingNode = new FunctionGraphNode(
            kernel.CreateFunctionFromMethod(
                (string name) => $"Hello {name}! It's wonderful to meet you today. I hope you're having a fantastic day filled with joy and positivity.",
                functionName: "GenerateGreeting",
                description: "Creates a personalized greeting message"
            ),
            "greeting_node"
        ).StoreResultAs("greeting");

        // Create a conditional node for decision making
        // This node evaluates whether the greeting is substantial enough to continue
        // Note: The condition function receives GraphState, not KernelArguments
        var decisionNode = new ConditionalGraphNode(
            (state) => state.ContainsValue("greeting") && 
                      state.GetValue<string>("greeting")?.Length > 20,
            "decision_node"
        );

        // Create a follow-up node that generates conversation continuations
        // This node only executes when the decision node allows it
        var followUpNode = new FunctionGraphNode(
            kernel.CreateFunctionFromMethod(
                (string greeting) => $"Based on this greeting: '{greeting}', here's a follow-up question: What's something that's bringing you joy today, or is there a particular topic you'd like to explore together?",
                functionName: "GenerateFollowUp",
                description: "Creates engaging follow-up questions"
            ),
            "followup_node"
        ).StoreResultAs("output");

        Console.WriteLine("✅ All graph nodes created successfully");
        return (greetingNode, decisionNode, followUpNode);
    }

    /// <summary>
    /// Builds and configures the complete graph structure.
    /// This method demonstrates how to assemble nodes and define execution flow.
    /// </summary>
    /// <param name="greetingNode">The greeting generation node</param>
    /// <param name="decisionNode">The conditional decision node</param>
    /// <param name="followUpNode">The follow-up generation node</param>
    /// <returns>A fully configured graph executor</returns>
    private static GraphExecutor BuildAndConfigureGraph(
        FunctionGraphNode greetingNode,
        ConditionalGraphNode decisionNode,
        FunctionGraphNode followUpNode)
    {
        Console.WriteLine("Step 3: Building and configuring the graph...");

        // Create a new graph executor with a descriptive name and description
        var graph = new GraphExecutor(
            "MyFirstGraph",
            "A simple greeting workflow that demonstrates basic graph concepts"
        );

        // Add all nodes to the graph
        // Nodes must be added before they can be connected
        graph.AddNode(greetingNode);
        graph.AddNode(decisionNode);
        graph.AddNode(followUpNode);

        // Connect the nodes to define the execution flow
        // Start with the greeting node flowing to the decision node
        graph.Connect(greetingNode.NodeId, decisionNode.NodeId);

        // Connect decision node to follow-up node when condition is met
        // This creates a conditional edge that only executes when the greeting is substantial
        // Note: The condition function receives KernelArguments, not GraphState
        graph.ConnectWhen(decisionNode.NodeId, followUpNode.NodeId,
            args => args.ContainsKey("greeting") && 
                    args["greeting"]?.ToString()?.Length > 20);

        // Connect decision node to end when condition is not met
        // This creates an exit path for short greetings
        // Note: We don't need to explicitly connect to null - the graph will naturally end
        // when no more edges are available

        // Set the starting point of the graph
        // Execution always begins at this node
        graph.SetStartNode(greetingNode.NodeId);

        Console.WriteLine("✅ Graph built and configured successfully");
        return graph;
    }

    /// <summary>
    /// Executes the graph with sample input data.
    /// Demonstrates how to provide input and retrieve results from graph execution.
    /// </summary>
    /// <param name="graph">The configured graph executor</param>
    /// <param name="kernel">The kernel instance for execution</param>
    private static async Task ExecuteGraphWithSampleInputAsync(GraphExecutor graph, Kernel kernel)
    {
        Console.WriteLine("Step 4: Executing the graph...");

        // Create initial state with input data
        // This demonstrates how to pass data into your graph workflow
        var initialState = new KernelArguments { ["name"] = "Alice" };

        Console.WriteLine($"Input state: {{ \"name\": \"{initialState["name"]}\" }}");

        // Execute the graph with the initial state
        // The graph executor will traverse all nodes according to the defined flow
        var result = await graph.ExecuteAsync(kernel, initialState);

        // Display the execution results
        Console.WriteLine("\n=== Execution Results ===");
        
        // Extract and display the greeting result from the final state
        // The result is a FunctionResult, but the actual data is stored in the arguments
        var greeting = initialState.GetValueOrDefault("greeting", "No greeting generated");
        Console.WriteLine($"Greeting: {greeting}");

        // Check if follow-up was generated (depends on conditional execution)
        if (initialState.ContainsKey("output"))
        {
            Console.WriteLine($"Follow-up: {initialState["output"]}");
        }
        else
        {
            Console.WriteLine("Follow-up: Not generated (greeting was too short)");
        }

        // Display the complete final state for analysis
        Console.WriteLine("\n=== Complete Final State ===");
        foreach (var kvp in initialState)
        {
            Console.WriteLine($"  {kvp.Key}: {kvp.Value}");
        }
    }
}
```

## 步驟 3：執行您的 Graph

執行您的應用程式：

```bash
dotnet run
```

您應該會看到類似的輸出：

```
=== My First Graph ===

Step 1: Creating kernel with graph support...
⚠️  OPENAI_API_KEY not found. Using mock functions for demonstration.
✅ Kernel created successfully with graph support enabled
Step 2: Creating graph nodes...
✅ All graph nodes created successfully
Step 3: Building and configuring the graph...
✅ Graph built and configured successfully
Step 4: Executing the graph...
Input state: { "name": "Alice" }

=== Execution Results ===
Greeting: Hello Alice! It's wonderful to meet you today. I hope you're having a fantastic day filled with joy and positivity.

Follow-up: Based on this greeting: 'Hello Alice! It's wonderful to meet you today. I hope you're having a fantastic day filled with joy and positivity.', here's a follow-up question: What's something that's bringing you joy today, or is there a particular topic you'd like to explore together?

=== Complete Final State ===
  name: Alice
  greeting: Hello Alice! It's wonderful to meet you today. I hope you're having a fantastic day filled with joy and positivity.
  output: Based on this greeting: 'Hello Alice! It's wonderful to meet you today. I hope you're having a fantastic day filled with joy and positivity.', here's a follow-up question: What's something that's bringing you joy today, or is there a particular topic you'd like to explore together?

✅ Your first graph executed successfully!
```

## 了解發生了什麼

讓我們分解您的 Graph 完成了什麼：

### 1. **模組化代碼結構**
代碼現在被組織成清晰、專注的方法：
- `CreateKernelWithGraphSupport()`：設定具有 Graph 功能的 Kernel
- `CreateGraphNodes()`：建立工作流程所需的所有 Node
- `BuildAndConfigureGraph()`：組合 Graph 結構和連接
- `ExecuteGraphWithSampleInputAsync()`：執行 Graph 並顯示結果

### 2. **Kernel 建立和 Graph 支援**
```csharp
var builder = Kernel.CreateBuilder();
builder.AddGraphSupport(); // This enables all graph functionality
```

`AddGraphSupport()` 擴充方法註冊所有必要的 Graph 執行服務，包括：
* Graph 執行程式工廠
* Node 轉換器
* 狀態管理
* 錯誤處理原則

### 3. **具有結果儲存的 Function Graph Node**
```csharp
var greetingNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string name) => $"Hello {name}! It's wonderful to meet you today...",
        functionName: "GenerateGreeting",
        description: "Creates a personalized greeting message"
    ),
    "greeting_node"
()).StoreResultAs("greeting");
```

此 Node 會：
* 包裝 Semantic Kernel 函式（使用 `CreateFunctionFromMethod` 以確保可靠性）
* 可連接到其他 Node
* 使用 `StoreResultAs("greeting")` 自動將其結果存儲在 Graph 狀態中
* 有描述性的名稱和描述，以便更好地調試

### 4. **使用 GraphState 的 Conditional Node**
```csharp
var decisionNode = new ConditionalGraphNode(
    (state) => state.ContainsValue("greeting") && 
              state.GetValue<string>("greeting")?.Length > 20,
    "decision_node"
);
```

此 Node 會：
* 根據當前 `GraphState` 評估條件
* 使用 `ContainsValue()` 和 `GetValue<T>()` 方法進行型別安全的狀態存取
* 根據結果將執行路由到不同的路徑
* 啟用動態工作流程行為

### 5. **具有清晰連接的 Graph 組合**
```csharp
graph.AddNode(greetingNode);
graph.AddNode(decisionNode);
graph.AddNode(followUpNode);

// Connect nodes using their IDs
graph.Connect(greetingNode.NodeId, decisionNode.NodeId);
graph.ConnectWhen(decisionNode.NodeId, followUpNode.NodeId,
    args => args.ContainsKey("greeting") && 
            args["greeting"]?.ToString()?.Length > 20);
```

您將 Node 新增到 Graph，然後使用它們的 `NodeId` 屬性連接它們以定義流程。

### 6. **使用 ConnectWhen 的條件路由**
```csharp
graph.ConnectWhen(decisionNode.NodeId, followUpNode.NodeId,
    args => args.ContainsKey("greeting") && 
            args["greeting"]?.ToString()?.Length > 20);
```

`ConnectWhen` 方法會建立條件 Edge，其中：
* 僅在條件評估為 `true` 時執行
* 接收 `KernelArguments` 進行條件評估
* 根據執行階段狀態啟用動態工作流程行為

### 7. **執行和狀態管理**
```csharp
var result = await graph.ExecuteAsync(kernel, initialState);
var greeting = initialState.GetValueOrDefault("greeting", "No greeting generated");
```

Graph 執行程式會：
* 從起始 Node 開始遍歷 Graph
* 依序執行每個 Node
* 管理 Node 之間的狀態轉換
* 將結果儲存在 `KernelArguments` 中以便輕鬆存取
* 傳回代表最終執行結果的 `FunctionResult`

## 關鍵概念示範

### **模組化代碼組織**
* **關注點分離**：每個方法都有單一、清晰的責任
* **可重用性**：方法可以輕鬆修改或擴展
* **可維護性**：代碼更容易閱讀、測試和調試
* **最佳實踐**：遵循 C# 編碼標準和模式

### **使用 GraphState 的狀態管理**
* **輸入狀態**：`{ "name": "Alice" }`
* **中間狀態**：`{ "name": "Alice", "greeting": "Hello Alice!..." }`
* **最終狀態**：包含具有適當中繼資料的輸入和生成的內容
* **型別安全**：使用 `GetValue<T>()` 和 `ContainsValue()` 方法

### **使用 GraphState 的條件執行**
* 決策 Node 使用 `GraphState` 方法評估問候語長度
* 僅當問候語實質性時才執行後續操作（> 20 個字元）
* 演示根據執行階段條件的動態工作流程行為
* 顯示 `GraphState`（用於 Node 條件）和 `KernelArguments`（用於 Edge 條件）之間的差異

### **結果儲存和檢索**
* **StoreResultAs**：自動將 Node 結果儲存在 Graph 狀態中
* **狀態存取**：執行後可透過 `KernelArguments` 存取結果
* **中繼資料追蹤**：自動捕獲執行環境和時序資訊
* **調試支援**：豐富的狀態資訊用於故障排除

### **Node 類型及其角色**
* **FunctionGraphNode**：執行函式並儲存結果
* **ConditionalGraphNode**：根據狀態做出路由決策
* **GraphExecutor**：協調整個工作流程並管理執行流程

## 實驗和自訂

嘗試這些修改以深入了解：

### **變更輸入**
```csharp
var state = new KernelArguments { ["name"] = "Bob" };
```

### **修改條件**
```csharp
var decisionNode = new ConditionalGraphNode(
    (state) => state.ContainsValue("greeting") && 
              state.GetValue<string>("greeting")?.Contains("wonderful"),
    "decision_node"
);
```

### **新增更多 Node**
```csharp
var summaryNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string greeting, string followup) => 
            $"Summary: Greeting was '{greeting}' and follow-up was '{followup}'",
        functionName: "GenerateSummary",
        description: "Creates a conversation summary"
    ),
    "summary_node"
()).StoreResultAs("summary");

graph.AddNode(summaryNode);
graph.Connect(followUpNode.NodeId, summaryNode.NodeId);
```

### **測試不同場景**
此範例包含可調用的內置實驗方法：

```csharp
// Test with different names and see how the conditional logic behaves
await RunExperimentationExamplesAsync();
```

這將使用各種輸入測試 Graph，並演示條件路由在不同場景中的工作方式。

## 常見問題和解決方案

### **找不到 API 金鑰**
```
⚠️  OPENAI_API_KEY not found. Using mock functions for demonstration.
```
**解決方案**：該範例將使用 Mock 函式，但如果要實際使用 LLM 功能，請確保環境變數設定正確並重新啟動終端機。

### **Graph 執行失敗**
```
System.InvalidOperationException: No start node configured
```
**解決方案**：確保您已使用有效的 Node ID（而不是 Node 物件本身）呼叫 `graph.SetStartNode(nodeId)`。

### **Node 未連接**
```
System.InvalidOperationException: No next nodes found for node 'NodeName'
```
**解決方案**：驗證所有 Node 都已正確連接，使用 `graph.Connect(sourceNodeId, targetNodeId)` 和 `graph.ConnectWhen(sourceNodeId, targetNodeId, condition)`。

### **結果未儲存在狀態中**
```
Greeting: No greeting generated
```
**解決方案**：確保您已在 FunctionGraphNode 實例上呼叫 `.StoreResultAs("keyName")` 以指定結果應儲存的位置。

### **Conditional Node 條件失敗**
```
System.InvalidOperationException: Condition evaluation failed
```
**解決方案**：確保您的 Conditional Node 的條件函式接收 `GraphState` 並使用 `ContainsValue()` 和 `GetValue<T>()` 之類的方法，而不是字典風格的存取。

### **型別轉換錯誤**
```
System.InvalidCastException: Unable to cast object of type 'System.String' to type 'System.Int32'
```
**解決方案**：對型別安全的狀態存取使用泛型 `GetValue<T>()` 方法：`state.GetValue<string>("keyName")` 而不是 `(string)state["keyName"]`。

## 後續步驟

恭喜！您已成功建立您的第一個 Graph。以下是要探索的內容：

* **[狀態管理教學](state-tutorial.md)**：了解如何使用 Graph 狀態和資料流
* **[Conditional Node 指南](how-to/conditional-nodes.md)**：掌握條件邏輯和路由
* **[核心概念](concepts/index.md)**：了解基本構建塊
* **[範例](examples/index.md)**：查看更多複雜的實際模式

## 概念和技術

本教學介紹了多個關鍵概念：

* **Graph**：定義工作流程執行的 Node 和 Edge 的有向結構
* **Node**：可執行函式、做出決策或執行操作的個別工作單位
* **Edge**：Node 之間的連接，可包括用於動態路由的條件邏輯
* **State**：流經 Graph 的資料，維護執行步驟之間的環境
* **Execution**：遍歷 Graph、執行 Node 並管理狀態轉換的程序
* **模組化設計**：分離關注點並提高可維護性的代碼組織
* **結果儲存**：自動將 Node 執行結果儲存在 Graph 狀態中
* **型別安全**：使用泛型方法和適當的型別檢查進行安全的狀態值存取
* **條件路由**：基於執行階段狀態評估的動態工作流程路徑
* **錯誤處理**：包含 try-catch 區塊的全面錯誤處理和使用者友善的訊息

## 先決條件和最少配置

要完成本教學，您需要：
* **.NET 8.0+** 執行階段和 SDK
* 已安裝的 **SemanticKernel.Graph** 套件
* 已配置有效 API 金鑰的 **LLM 提供者**（選擇性 - 範例使用 Mock 函式）
* 為您的 API 認證設定的 **環境變數**（選擇性）

### **執行範例**

完整的工作範例可在 `examples` 資料夾中獲得：

```bash
# Navigate to the examples directory
cd semantic-kernel-graph-docs/examples

# Run the first graph example
dotnet run -- first-graph

# Run all examples
dotnet run -- all
```

### **範例功能**

該範例演示：
* **模組化代碼結構**：具有專注方法的清晰關注點分離
* **Mock 函式支援**：無需 LLM API 金鑰即可用於演示
* **全面的錯誤處理**：包含信息性錯誤訊息的 try-catch 區塊
* **逐步進度**：執行期間的視覺回饋
* **實驗模式**：具有不同輸入的內置測試
* **狀態視覺化**：最終執行狀態的完整檢視

## 另請參閱

* **[安裝指南](installation.md)**：在您的專案中設定 SemanticKernel.Graph
* **[核心概念](concepts/index.md)**：了解 Graph、Node 和執行
* **[操作說明指南](how-to/build-a-graph.md)**：建立更複雜的 Graph 工作流程
* **[API 參考](api/core.md)**：完整的 API 文件
* **[範例](examples/index.md)**：更多實際 Graph 模式和使用案例
* **[狀態管理](concepts/state.md)**：使用 Graph 狀態和資料流
* **[Conditional Node](how-to/conditional-nodes.md)**：進階條件邏輯和路由
* **[執行範例](running-examples.md)**：如何執行和測試提供的範例
