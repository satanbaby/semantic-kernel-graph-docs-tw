# 5 分鐘內建立您的第一個圖形工作流

本教程將引導您使用 SemanticKernel.Graph 建立第一個圖形工作流。您將學習如何建立核心、啟用圖形支援、建立節點、連接節點，以及執行您的第一個圖形。

## 您將建立什麼

您將建立一個簡單的「Hello World」圖形，展示基本概念：
* 一個處理輸入的函數節點
* 一個做出決策的條件節點
* 基本的狀態管理
* 圖形執行

## 前置條件

開始之前，請確保您已具備：
* [已在專案中安裝 SemanticKernel.Graph](installation.md)
* 已設定的 LLM 提供者（OpenAI、Azure OpenAI 等）
* 已在環境變數中設定 API 金鑰

## 步驟 1：設定您的專案

### 建立新的主控台應用程式

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

## 步驟 2：建立您的第一個圖形

將 `Program.cs` 的內容替換為此程式碼：

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

## 步驟 3：執行您的圖形

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

讓我們分解您的圖形完成了什麼：

### 1. **模組化程式碼結構**
程式碼現在組織成清晰、專注的方法：
- `CreateKernelWithGraphSupport()`：使用圖形功能設定核心
- `CreateGraphNodes()`：建立工作流所需的所有節點
- `BuildAndConfigureGraph()`：組合圖形結構和連接
- `ExecuteGraphWithSampleInputAsync()`：執行圖形並顯示結果

### 2. **核心建立和圖形支援**
```csharp
var builder = Kernel.CreateBuilder();
builder.AddGraphSupport(); // This enables all graph functionality
```

`AddGraphSupport()` 擴充方法註冊所有必要的圖形執行服務，包括：
* 圖形執行器工廠
* 節點轉換器
* 狀態管理
* 錯誤處理原則

### 3. **具有結果儲存的函數圖形節點**
```csharp
var greetingNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string name) => $"Hello {name}! It's wonderful to meet you today...",
        functionName: "GenerateGreeting",
        description: "Creates a personalized greeting message"
    ),
    "greeting_node"
).StoreResultAs("greeting");
```

這會建立一個節點，其功能如下：
* 包裝語義核心函數（使用 `CreateFunctionFromMethod` 以確保可靠性）
* 可以連接到其他節點
* 使用 `StoreResultAs("greeting")` 自動將其結果儲存在圖形狀態中
* 具有描述性名稱和描述，以便更好地進行偵錯

### 4. **具有 GraphState 的條件節點**
```csharp
var decisionNode = new ConditionalGraphNode(
    (state) => state.ContainsValue("greeting") && 
              state.GetValue<string>("greeting")?.Length > 20,
    "decision_node"
);
```

此節點的功能：
* 根據目前 `GraphState` 評估條件
* 使用 `ContainsValue()` 和 `GetValue<T>()` 方法進行類型安全的狀態存取
* 根據結果將執行路由到不同的路徑
* 啟用動態工作流行為

### 5. **使用清晰連接的圖形組合**
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

您將節點新增到圖形，然後使用其 `NodeId` 屬性連接它們以定義流程。

### 6. **使用 ConnectWhen 的條件路由**
```csharp
graph.ConnectWhen(decisionNode.NodeId, followUpNode.NodeId,
    args => args.ContainsKey("greeting") && 
            args["greeting"]?.ToString()?.Length > 20);
```

`ConnectWhen` 方法建立條件邊，其功能如下：
* 僅當條件評估為 `true` 時才執行
* 接收 `KernelArguments` 進行條件評估
* 根據執行時狀態啟用動態工作流行為

### 7. **執行和狀態管理**
```csharp
var result = await graph.ExecuteAsync(kernel, initialState);
var greeting = initialState.GetValueOrDefault("greeting", "No greeting generated");
```

圖形執行器的功能：
* 從開始節點開始遍歷圖形
* 按順序執行每個節點
* 管理節點之間的狀態轉換
* 將結果儲存在 `KernelArguments` 中以便輕鬆存取
* 傳回代表最終執行結果的 `FunctionResult`

## 關鍵概念演示

### **模組化程式碼組織**
* **關注點分離**：每個方法都有單一、清晰的責任
* **可重用性**：方法可以輕鬆修改或擴展
* **可維護性**：程式碼更容易讀取、測試和偵錯
* **最佳實踐**：遵循 C# 編碼標準和模式

### **使用 GraphState 的狀態管理**
* **輸入狀態**：`{ "name": "Alice" }`
* **中間狀態**：`{ "name": "Alice", "greeting": "Hello Alice!..." }`
* **最終狀態**：包含具有適當中繼資料的輸入和產生的內容
* **類型安全**：使用 `GetValue<T>()` 和 `ContainsValue()` 方法

### **使用 GraphState 的條件執行**
* 決策節點使用 `GraphState` 方法評估問候語長度
* 僅在問候語實質內容充分時才執行後續操作（> 20 個字元）
* 展示根據執行時條件的動態工作流行為
* 顯示 `GraphState`（用於節點條件）和 `KernelArguments`（用於邊界條件）之間的差異

### **結果儲存和檢索**
* **StoreResultAs**：自動將節點結果儲存在圖形狀態中
* **狀態存取**：執行後可以透過 `KernelArguments` 存取結果
* **中繼資料追蹤**：自動擷取執行內容和計時資訊
* **偵錯支援**：豐富的狀態資訊以便故障排除

### **節點類型及其角色**
* **FunctionGraphNode**：執行函數並儲存結果
* **ConditionalGraphNode**：根據狀態做出路由決策
* **GraphExecutor**：協調整個工作流並管理執行流程

## 實驗和自訂

嘗試這些修改以了解更多資訊：

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

### **新增更多節點**
```csharp
var summaryNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string greeting, string followup) => 
            $"Summary: Greeting was '{greeting}' and follow-up was '{followup}'",
        functionName: "GenerateSummary",
        description: "Creates a conversation summary"
    ),
    "summary_node"
).StoreResultAs("summary");

graph.AddNode(summaryNode);
graph.Connect(followUpNode.NodeId, summaryNode.NodeId);
```

### **測試不同的情景**
此範例包含一個內建的實驗方法，您可以呼叫：

```csharp
// Test with different names and see how the conditional logic behaves
await RunExperimentationExamplesAsync();
```

這將使用各種輸入測試圖形，並展示條件路由在不同情景中的工作方式。

## 常見問題和解決方案

### **找不到 API 金鑰**
```
⚠️  OPENAI_API_KEY not found. Using mock functions for demonstration.
```
**解決方案**：此範例將適用於模擬函數，但要獲得真實的 LLM 功能，請確保您的環境變數設定正確，並重新啟動您的終端。

### **圖形執行失敗**
```
System.InvalidOperationException: No start node configured
```
**解決方案**：確保您使用有效的節點 ID（而非節點物件本身）呼叫了 `graph.SetStartNode(nodeId)`。

### **節點未連接**
```
System.InvalidOperationException: No next nodes found for node 'NodeName'
```
**解決方案**：驗證所有節點是否正確連接，使用 `graph.Connect(sourceNodeId, targetNodeId)` 和 `graph.ConnectWhen(sourceNodeId, targetNodeId, condition)`。

### **結果未儲存在狀態中**
```
Greeting: No greeting generated
```
**解決方案**：確保您在 FunctionGraphNode 實例上呼叫了 `.StoreResultAs("keyName")` 以指定結果的儲存位置。

### **條件節點條件失敗**
```
System.InvalidOperationException: Condition evaluation failed
```
**解決方案**：確保您的條件節點的條件函數接收 `GraphState` 並使用 `ContainsValue()` 和 `GetValue<T>()` 等方法，而不是字典風格的存取。

### **類型轉換錯誤**
```
System.InvalidCastException: Unable to cast object of type 'System.String' to type 'System.Int32'
```
**解決方案**：使用泛型 `GetValue<T>()` 方法進行類型安全的狀態存取：`state.GetValue<string>("keyName")` 而不是 `(string)state["keyName"]`。

## 後續步驟

恭喜！您已成功建立了第一個圖形。以下是接下來要探索的內容：

* **[狀態管理教程](state-tutorial.md)**：了解如何使用圖形狀態和資料流
* **[條件節點指南](how-to/conditional-nodes.md)**：掌握條件邏輯和路由
* **[核心概念](concepts/index.md)**：了解基本建構塊
* **[範例](examples/index.md)**：查看更複雜的真實模式

## 概念和技術

本教程介紹了幾個關鍵概念：

* **圖形**：定義工作流執行的節點和邊的有向結構
* **節點**：可以執行函數、做出決策或執行操作的個別工作單位
* **邊**：節點之間的連接，可以包括用於動態路由的條件邏輯
* **狀態**：流經圖形的資料，在執行步驟中保持上下文
* **執行**：遍歷圖形、執行節點和管理狀態轉換的過程
* **模組化設計**：程式碼組織，分離關注點並提高可維護性
* **結果儲存**：自動將節點執行結果儲存在圖形狀態中
* **類型安全**：使用泛型方法和適當的類型檢查安全地存取狀態值
* **條件路由**：根據執行時狀態評估的動態工作流路徑
* **錯誤處理**：包含 try-catch 區塊和使用者友善訊息的全面錯誤處理

## 前置條件和最低設定

要完成本教程，您需要：
* **.NET 8.0+** 執行時和 SDK
* **SemanticKernel.Graph** 套件已安裝
* **LLM 提供者**已設定有效的 API 金鑰（可選 - 範例可搭配模擬函數使用）
* **環境變數**已設定用於您的 API 認證（可選）

### **執行範例**

完整的可運作範例位於 `examples` 資料夾：

```bash
# Navigate to the examples directory
cd semantic-kernel-graph-docs/examples

# Run the first graph example
dotnet run -- first-graph

# Run all examples
dotnet run -- all
```

### **範例功能**

此範例展示：
* **模組化程式碼結構**：使用專注的方法清晰分離關注點
* **模擬函數支援**：無需 LLM API 金鑰即可進行演示
* **全面的錯誤處理**：帶有資訊豐富的錯誤訊息的 Try-catch 區塊
* **分步進度**：執行期間的視覺回饋
* **實驗模式**：使用不同輸入的內建測試
* **狀態視覺化**：最終執行狀態的完整檢視

## 另請參閱

* **[安裝指南](installation.md)**：在您的專案中設定 SemanticKernel.Graph
* **[核心概念](concepts/index.md)**：了解圖形、節點和執行
* **[操作方法指南](how-to/build-a-graph.md)**：建立更複雜的圖形工作流
* **[API 參考](api/core.md)**：完整的 API 文件
* **[範例](examples/index.md)**：更多真實圖形模式和使用案例
* **[狀態管理](concepts/state.md)**：使用圖形狀態和資料流
* **[條件節點](how-to/conditional-nodes.md)**：進階條件邏輯和路由
* **[執行範例](running-examples.md)**：如何執行和測試提供的範例
