# 如何構建 Graph

本指南說明了在 SemanticKernel.Graph 中建立和配置 Graph 的基本步驟。你將學習如何定義 Node、使用條件 Edge 連接它們，以及執行生成的 Workflow。

## 概述

構建 Graph 涉及多個關鍵步驟：

1. **建立並配置 `Kernel`**，包含必要的外掛程式和函式
2. **定義 Node**（函式、條件、迴圈）代表 Workflow 的步驟
3. **使用條件 Edge 連接 Node**，控制執行流程
4. **使用 `GraphExecutor` 執行**完整的 Workflow

## 逐步流程

### 1. 建立並配置 Kernel

首先建立啟用 Graph 支援的 Semantic Kernel 執行個體。本存放庫中的範例使用為 Graph 情境配置的最小化 Kernel。

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;

// 建立 Kernel 並為範例啟用 Graph 支援
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport()
    .Build();
```

### 2. 定義 Graph Node

建立代表 Workflow 中不同步驟的 Node。針對小型可執行的文件片段，我們提供輕量級的 Kernel 函式，包裝在 `FunctionGraphNode` 執行個體中：

```csharp
// 為示範目的建立輕量級 Kernel 函式
var fnA = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
{
    // 返回簡單的問候訊息
    return "Hello from A";
}, "FnA");

var fnB = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
{
    // 從 Graph 狀態回應前一條訊息
    var prev = args.ContainsName("message") ? args["message"]?.ToString() : string.Empty;
    return $"B received: {prev}";
}, "FnB");

// 將函式包裝進 Graph Node
var nodeA = new FunctionGraphNode(fnA, "nodeA", "Start node A");
var nodeB = new FunctionGraphNode(fnB, "nodeB", "Receiver node B");
```

### 3. 使用 Edge 連接 Node

使用 `GraphExecutor` API 定義 Node 之間的流程。針對上述最小範例，我們將 `nodeA` 連接到 `nodeB` 並設定起始 Node：

```csharp
var graph = new GraphExecutor("ExampleGraph", "A tiny demo graph for docs");

// 將 Node 新增至 Graph
graph.AddNode(nodeA).AddNode(nodeB);

// 連接 A -> B 並設定起始 Node
graph.Connect("nodeA", "nodeB");
graph.SetStartNode("nodeA");
```

### 4. 執行 Graph

使用 `ExecuteAsync` 執行完整的 Workflow。範例使用 `KernelArguments` 作為初始 Graph 狀態並列印最終結果。

```csharp
// 準備初始 Kernel 引數 / Graph 狀態
var args = new KernelArguments();
args["message"] = "Initial message";

// 執行 Graph
var result = await graph.ExecuteAsync(kernel, args, CancellationToken.None);

Console.WriteLine("Graph execution completed.");
Console.WriteLine($"Final result: {result.GetValue<string>()}");
```

## 替代的 Builder 模式

對於更簡單的 Graph，你可以使用流暢的 Builder 模式：

```csharp
var graph = GraphBuilder.Create()
    .AddFunctionNode("plan", kernel, "Planner", "Plan")
    .When(state => state.GetString("needs_analysis") == "yes")
        .AddFunctionNode("analyze", kernel, "Analyzer", "Analyze")
    .AddFunctionNode("act", kernel, "Executor", "Act")
    .Build();
```

## 進階模式

### 條件執行

使用條件 Edge 建立複雜的分支邏輯：

```csharp
graph.AddConditionalEdge("start", "branch_a", 
    condition: state => state.GetInt("priority") > 5)
.AddConditionalEdge("start", "branch_b", 
    condition: state => state.GetInt("priority") <= 5);
```

### 迴圈控制

使用迴圈限制實作迴圈：

```csharp
var loopNode = new WhileGraphNode(
    condition: state => state.GetInt("attempt") < 3,
    maxIterations: 5,
    nodeId: "retry_loop"
);

graph.AddNode(loopNode)
     .AddEdge("start", "retry_loop")
     .AddEdge("retry_loop", "process");
```

### 錯誤處理

將錯誤處理 Node 新增至 Workflow：

```csharp
var errorHandler = new ErrorHandlerGraphNode(
    errorTypes: new[] { ErrorType.Transient, ErrorType.External },
    recoveryAction: RecoveryAction.Retry,
    maxRetries: 3,
    nodeId: "error_handler"
);

graph.AddNode(errorHandler)
     .AddEdge("process", "error_handler")
     .AddEdge("error_handler", "fallback");
```

## 最佳實踐

### Node 設計

1. **單一職責**：每個 Node 應有一個清楚的目的
2. **有意義的名稱**：使用描述性的 Node ID 來說明其功能
3. **狀態管理**：設計 Node 以有效地與 Graph 狀態協作
4. **錯誤處理**：為健全的 Workflow 包含錯誤處理 Node

### Graph 結構

1. **邏輯流程**：以邏輯順序組織 Node
2. **條件邏輯**：使用條件 Edge 進行動態路由
3. **迴圈預防**：設定適當的迴圈限制以防止無限迴圈
4. **起始 Node**：始終定義清楚的起點

### 效能考量

1. **Node 效率**：最佳化個別 Node 效能
2. **狀態大小**：保持 Graph 狀態可管理以提高記憶體效率
3. **平行執行**：在可能的地方使用平行 Node 以獲得更好的效能
4. **快取**：為昂貴的操作實施快取

## 故障排除

### 常見問題

**Graph 未執行**：確保你已使用 `SetStartNode()` 設定起始 Node

**Node 未連接**：驗證所有 Edge 是否使用 `AddEdge()` 或 `AddConditionalEdge()` 正確定義

**無限迴圈**：檢查迴圈條件並設定適當的 `maxIterations`

**狀態未保留**：在 Node 之間使用 `GraphState` 以進行持續狀態

### 偵錯秘訣

1. **啟用記錄**以追蹤執行流程
2. **在條件邏輯中使用中斷點**
3. **檢查每個 Node 執行處的狀態**
4. **執行前驗證 Graph 完整性**

## 概念和技術

**GraphExecutor**：負責執行 Graph Workflow 的主要類別。它管理 Node 執行順序、狀態轉換和 Workflow 生命週期中的錯誤處理。

**FunctionGraphNode**：包裝和執行 Semantic Kernel 函式的 Graph Node。它處理 Graph 狀態和基礎 Kernel 函式之間的輸入/輸出對應。

**ConditionalGraphNode**：評估述詞以決定執行流程的 Node。它根據 Graph 的目前狀態啟用動態路由。

**ConditionalEdge**：Node 之間的連線，包含執行的條件。它允許複雜的分支邏輯和動態 Workflow 路徑。

**GraphState**：圍繞 KernelArguments 的包裝程式，為 Graph Workflow 提供額外的中繼資料、執行歷史和驗證功能。

## 參閱

* [5分鐘內完成第一個 Graph](../first-graph-5-minutes.md) - 構建你第一個 Graph 的快速開始指南
* [條件 Node](conditional-nodes.md) - 了解分支和條件執行
* [迴圈](loops.md) - 使用迴圈 Node 實施反覆 Workflow
* [狀態管理](../state-quickstart.md) - 了解如何管理 Node 之間的資料流程
* [Graph 執行](../concepts/execution.md) - 了解執行生命週期和流程控制
* [範例：基本 Graph 構建](../examples/basic-graph-example.md) - Graph 構建的完整工作範例
