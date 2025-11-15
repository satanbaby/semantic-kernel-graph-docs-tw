# 如何建立圖表

本指南說明在 SemanticKernel.Graph 中建立和設定圖表的基本步驟。您將學習如何定義節點、使用條件邊連接它們，以及執行產生的工作流程。

## 概述

建立圖表涉及幾個關鍵步驟：

1. **建立並設定 `Kernel`**，其中包含必要的外掛程式和函數
2. **定義節點**（函數、條件、迴圈）代表您的工作流程步驟
3. **連接節點**，使用條件邊控制執行流程
4. **執行**使用 `GraphExecutor` 運行完整的工作流程

## 逐步過程

### 1. 建立並設定核心

首先建立已啟用圖表支援的 Semantic Kernel 執行個體。本儲存庫中的範例使用為圖表場景設定的最小核心。

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;

// 建立核心並啟用圖表支援
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport()
    .Build();
```

### 2. 定義圖表節點

建立代表工作流程中不同步驟的節點。對於小型可執行文件片段，我們提供輕量級核心函數，包裝成 `FunctionGraphNode` 執行個體：

```csharp
// 為示範目的建立輕量級核心函數
var fnA = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
{
    // 傳回簡單的問候訊息
    return "Hello from A";
}, "FnA");

var fnB = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
{
    // 從圖表狀態回應上一個訊息
    var prev = args.ContainsName("message") ? args["message"]?.ToString() : string.Empty;
    return $"B received: {prev}";
}, "FnB");

// 將函數包裝至圖表節點
var nodeA = new FunctionGraphNode(fnA, "nodeA", "Start node A");
var nodeB = new FunctionGraphNode(fnB, "nodeB", "Receiver node B");
```

### 3. 連接節點與邊

使用 `GraphExecutor` API 定義節點之間的流程。針對上面的最小範例，我們連接 `nodeA` 至 `nodeB` 並設定起始節點：

```csharp
var graph = new GraphExecutor("ExampleGraph", "A tiny demo graph for docs");

// 將節點新增至圖表
graph.AddNode(nodeA).AddNode(nodeB);

// 連接 A -> B 並設定起始節點
graph.Connect("nodeA", "nodeB");
graph.SetStartNode("nodeA");
```

### 4. 執行圖表

使用 `ExecuteAsync` 執行完整的工作流程。範例使用 `KernelArguments` 作為初始圖表狀態並列印最終結果。

```csharp
// 準備初始核心引數 / 圖表狀態
var args = new KernelArguments();
args["message"] = "Initial message";

// 執行圖表
var result = await graph.ExecuteAsync(kernel, args, CancellationToken.None);

Console.WriteLine("Graph execution completed.");
Console.WriteLine($"Final result: {result.GetValue<string>()}");
```

## 替代建造器模式

對於較簡單的圖表，您可以使用流暢的建造器模式：

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

使用條件邊建立複雜的分支邏輯：

```csharp
graph.AddConditionalEdge("start", "branch_a", 
    condition: state => state.GetInt("priority") > 5)
.AddConditionalEdge("start", "branch_b", 
    condition: state => state.GetInt("priority") <= 5);
```

### 迴圈控制

使用迴圈反覆限制實現迴圈：

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

將錯誤處理節點新增至您的工作流程：

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

## 最佳做法

### 節點設計

1. **單一責任**：每個節點應該有一個清楚的目的
2. **有意義的名稱**：使用描述性節點 ID 來說明其功能
3. **狀態管理**：設計節點以有效地處理圖表狀態
4. **錯誤處理**：包含錯誤處理節點以實現強大的工作流程

### 圖表結構

1. **邏輯流程**：以邏輯順序組織節點
2. **條件邏輯**：使用條件邊進行動態路由
3. **迴圈預防**：設定適當的反覆限制以防止無限迴圈
4. **起始節點**：始終定義清晰的起點

### 效能考量

1. **節點效率**：優化個別節點效能
2. **狀態大小**：保持圖表狀態可管理性以提高記憶體效率
3. **平行執行**：盡可能使用平行節點以改善效能
4. **快取**：為昂貴的操作實現快取

## 疑難排解

### 常見問題

**圖表不執行**：確保您已使用 `SetStartNode()` 設定起始節點

**節點未連接**：驗證所有邊都已使用 `AddEdge()` 或 `AddConditionalEdge()` 正確定義

**無限迴圈**：檢查迴圈條件並設定適當的 `maxIterations`

**狀態未保留**：使用 `GraphState` 進行整個節點的持續狀態

### 偵錯秘訣

1. **啟用記錄**追蹤執行流程
2. **使用中斷點**在條件邏輯中
3. **檢查狀態**在每個節點執行時
4. **驗證圖表完整性**在執行前

## 概念與技術

**GraphExecutor**：負責執行圖表工作流程的主要類別。它管理節點執行順序、狀態轉換和整個工作流程生命週期的錯誤處理。

**FunctionGraphNode**：包裝和執行 Semantic Kernel 函數的圖表節點。它處理圖表狀態和基礎核心函數之間的輸入/輸出對應。

**ConditionalGraphNode**：評估述詞以確定執行流程的節點。它根據圖表的目前狀態啟用動態路由。

**ConditionalEdge**：節點之間的連接，包含執行條件。它允許複雜的分支邏輯和動態工作流程路徑。

**GraphState**：KernelArguments 的包裝，為圖表工作流程提供其他中繼資料、執行歷史記錄和驗證功能。

## 另請參閱

* [5 分鐘內的首個圖表](../first-graph-5-minutes.md) - 建立首個圖表的快速入門指南
* [條件節點](conditional-nodes.md) - 深入瞭解分支和條件執行
* [迴圈](loops.md) - 使用迴圈節點實現反覆性工作流程
* [狀態管理](../state-quickstart.md) - 瞭解如何管理節點之間的資料流程
* [圖表執行](../concepts/execution.md) - 瞭解執行生命週期和流程控制
* [範例：基本圖表建立](../examples/basic-graph-example.md) - 圖表建立的完整工作範例
