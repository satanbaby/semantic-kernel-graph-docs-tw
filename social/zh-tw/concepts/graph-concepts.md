# Graph 概念

本指南說明 SemanticKernel.Graph 的基礎概念，包括 Node、條件式 Edge、執行路徑和受控迴圈。

## 概述

SemanticKernel.Graph 擴展 Semantic Kernel，提供基於 Graph 的執行模型，讓您可以透過條件邏輯連接 Node 來建立複雜的工作流。與傳統的線性執行不同，Graph 支援分支、迴圈和基於執行狀態的動態路由。

## 核心元件

### Node

Node 是 Graph 的基礎構建塊。每個 Node 代表一個可執行的工作單位，它們透過共享的狀態進行通訊。

**關鍵屬性：**
* **NodeId**：Node 的唯一識別符
* **Name**：便於偵錯和視覺化的易讀名稱
* **Description**：Node 的功能描述
* **IsExecutable**：Node 是否可以被執行
* **InputParameters**：預期的輸入參數
* **OutputParameters**：產生的輸出參數

**生命週期方法：**
* `OnBeforeExecuteAsync`：執行前的設定和驗證
* `ExecuteAsync`：主要執行邏輯
* `OnAfterExecuteAsync`：清理和後置處理
* `OnExecutionFailedAsync`：錯誤處理和恢復

### 條件式 Edge

Edge 定義 Node 之間的連接並控制執行流程。它們可以是無條件的（始終執行）或條件式的（僅在特定條件符合時執行）。

**Edge 類型：**
* **無條件**：在源 Node 執行後始終被遍歷
* **基於參數**：根據特定參數值進行評估
* **基於狀態**：根據整個 Graph 狀態進行評估
* **基於樣板**：使用類似 Handlebars 的樣板進行複雜條件

**Edge 屬性：**
* **SourceNode**：原始 Node
* **TargetNode**：目標 Node
* **Condition**：決定遍歷的謂詞函數
* **Metadata**：用於路由和視覺化的額外資訊
* **MergeConfiguration**：多個路徑匯聚時的狀態處理方式

## 執行模型

### 執行流程

Graph 執行器遵循系統化的方法來導航和執行 Node：

1. **開始 Node**：執行從指定的開始 Node 開始
2. **Node 執行**：當前 Node 在存取共享狀態的情況下執行
3. **下一個 Node 選擇**：執行器決定接下來執行哪些 Node
4. **狀態傳播**：結果和狀態變化流向後續 Node
5. **終止**：當沒有更多 Node 可用時執行停止

### 導航邏輯

每個 Node 實作 `GetNextNodes()` 以指定應接下來執行的 Node：

```csharp
public IEnumerable<IGraphNode> GetNextNodes(FunctionResult? executionResult, GraphState graphState)
{
    // 根據執行結果和當前狀態返回下一個 Node
    if (executionResult?.GetValue<bool>("should_continue") == true)
    {
        return new[] { nextNode };
    }
    return Enumerable.Empty<IGraphNode>(); // 終止執行
}
```

### 條件式路由

條件式 Edge 可基於執行狀態實現動態路由：

```csharp
// 建立只在符合條件時才採用的 Edge
var edge = new ConditionalEdge(
    sourceNode, 
    targetNode, 
    state => state.GetValue<int>("score") >= 80
);

// 或使用工廠方法處理常見模式
var edge = ConditionalEdge.CreateParameterEquals(
    sourceNode, 
    targetNode, 
    "status", 
    "success"
);
```

## 執行路徑

### 線性路徑

簡單的工作流遵循線性序列：

```
Node A → Node B → Node C
```

### 分支路徑

條件邏輯建立分支執行：

```
        ┌─ Condition True ─→ Node B
Node A ─┤
        └─ Condition False ─→ Node C
```

### 平行路徑

多個路徑可以並行執行，然後匯聚：

```
Node A ─┬─→ Node B ─┐
        │            │
        └─→ Node C ─┼─→ Node D
                     │
        └─→ Node E ─┘
```

### 迴圈路徑

Node 可建立迴圈進行迭代處理：

```
Node A → Node B → Condition → Node A (if condition met)
```

## 受控迴圈

### 迴圈預防

Graph 執行器包含內建的防護措施以防止無限迴圈：

* **最大迭代次數**：可配置的迴圈執行限制
* **執行深度**：執行深度跟蹤以檢測過度巢狀
* **逾時控制**：長時間執行操作的可配置逾時
* **斷路器**：問題執行路徑的自動終止

### 迴圈控制

Node 可實作迴圈控制邏輯：

```csharp
public bool ShouldExecute(GraphState graphState)
{
    var iterationCount = graphState.GetValue<int>("iteration_count", 0);
    var maxIterations = graphState.GetValue<int>("max_iterations", 10);
    
    return iterationCount < maxIterations;
}
```

### 迴圈中的狀態管理

迴圈 Node 在迭代間維護狀態：

```csharp
// 儲存迭代計數
graphState.SetValue("iteration_count", 
    graphState.GetValue<int>("iteration_count", 0) + 1);

// 檢查終止條件
if (goalAchieved || maxIterationsReached)
{
    graphState.SetValue("loop_terminated", true);
}
```

## 狀態管理

### 共享狀態

所有 Node 共享一個通用的 `GraphState`，它包裝了 `KernelArguments`：

```csharp
// 在狀態中設定值
graphState.SetValue("user_input", "Hello, world!");
graphState.SetValue("processing_step", 1);

// 從狀態中檢索值
var input = graphState.GetValue<string>("user_input");
var step = graphState.GetValue<int>("processing_step");
```

### 狀態持久化

Graph 狀態可以被序列化和持久化：

```csharp
// 將狀態儲存到檢查點
var checkpoint = await stateHelpers.SaveCheckpointAsync(graphState);

// 從檢查點還原狀態
var restoredState = await stateHelpers.RestoreCheckpointAsync(checkpoint);
```

### 狀態驗證

Node 可在執行前驗證狀態：

```csharp
public ValidationResult ValidateExecution(KernelArguments arguments)
{
    var result = new ValidationResult();
    
    if (!arguments.ContainsName("required_parameter"))
    {
        result.AddError("Required parameter 'required_parameter' is missing");
    }
    
    return result;
}
```

## 進階模式

### ReAct 模式

ReAct（推理 + 行動）模式實現迭代式問題解決：

```csharp
var reactNode = new ReActLoopGraphNode()
    .ConfigureNodes(
        reasoningNode,    // 分析和規劃
        actionNode,       // 執行行動
        observationNode   // 觀察結果
    );
```

### 多代理協調

多個代理可透過共享狀態協同工作：

```csharp
var coordinator = new MultiAgentCoordinator();
coordinator.AddAgent("researcher", researchAgent);
coordinator.AddAgent("analyzer", analysisAgent);
coordinator.AddAgent("summarizer", summaryAgent);
```

### Human-in-the-Loop

Graph 可暫停執行以等待人工批准：

```csharp
var approvalNode = new HumanApprovalGraphNode(
    "approval_required",
    "Requires human approval to proceed"
);
```

## 最佳實踐

### Node 設計

* **單一職責**：每個 Node 應有一個清晰的目的
* **狀態驗證**：執行前始終驗證輸入
* **錯誤處理**：實作穩健的錯誤處理和恢復
* **元資料**：使用元資料提供除錯上下文

### Edge 設計

* **清晰的條件**：使條件邏輯明確且易讀
* **效能**：保持條件評估速度快且無副作用
* **文件**：為複雜的路由邏輯提供文件

### 狀態管理

* **不可變更新**：避免直接修改現有狀態
* **驗證**：驗證狀態變化並提供有意義的錯誤訊息
* **序列化**：設計狀態時考慮序列化需求

### 效能

* **延遲評估**：僅在必要時評估條件
* **快取**：在可能的情況下快取昂貴的計算
* **並行化**：對獨立路徑使用並行執行

## 參考

* [Execution Model](execution.md) - 詳細的執行生命週期
* [Node Types](nodes.md) - 可用的 Node 實作
* [State Management](state.md) - 進階狀態處理
* [Routing Strategies](routing.md) - 動態路由技術
* [Examples](../examples/) - 實務範例和用例

**可執行的範例**：請參見範例專案中的 `Examples/GraphConceptsExample.cs` 以了解與本文件相符的可執行程式碼片段。執行方式：在 `semantic-kernel-graph-docs/examples` 資料夾中執行 `dotnet run graph-concepts`。
