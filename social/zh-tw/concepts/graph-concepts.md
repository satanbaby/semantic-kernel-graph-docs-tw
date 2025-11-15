# 圖形概念

本指南說明 SemanticKernel.Graph 的基本概念，包括節點、條件邊、執行路徑和受控循環。

## 概述

SemanticKernel.Graph 使用圖形執行模型擴展 Semantic Kernel，允許您通過使用條件邏輯連接節點來建立複雜的工作流程。與傳統的線性執行不同，圖形支持根據執行狀態進行分支、迴圈和動態路由。

## 核心組件

### 節點

節點是圖形的基本構建塊。每個節點代表可以執行的工作單位，並通過共享狀態進行通訊。

**關鍵屬性：**
* **NodeId**: 節點的唯一標識符
* **Name**: 用於除錯和視覺化的人類可讀名稱
* **Description**: 節點的功能說明
* **IsExecutable**: 節點是否可以執行
* **InputParameters**: 預期的輸入參數
* **OutputParameters**: 產生的輸出參數

**生命週期方法：**
* `OnBeforeExecuteAsync`: 執行前的設置和驗證
* `ExecuteAsync`: 主要執行邏輯
* `OnAfterExecuteAsync`: 清理和後置處理
* `OnExecutionFailedAsync`: 錯誤處理和恢復

### 條件邊

邊定義了節點之間的連接並控制執行流程。它們可以是無條件的（總是被選中）或有條件的（僅在滿足特定條件時被選中）。

**邊的類型：**
* **無條件**: 在源節點執行後總是被遍歷
* **基於參數**: 根據特定的參數值進行評估
* **基於狀態**: 根據整個圖形狀態進行評估
* **基於範本**: 使用類似 Handlebars 的範本進行複雜條件判斷

**邊的屬性：**
* **SourceNode**: 原始節點
* **TargetNode**: 目標節點
* **Condition**: 判斷是否遍歷的謂詞函數
* **Metadata**: 用於路由和視覺化的附加信息
* **MergeConfiguration**: 多條路徑匯聚時如何處理狀態

## 執行模型

### 執行流程

圖形執行器按照系統方法導航和執行節點：

1. **開始節點**: 執行從指定的開始節點開始
2. **節點執行**: 當前節點使用共享狀態執行
3. **下一節點選擇**: 執行器確定接下來應執行哪些節點
4. **狀態傳播**: 結果和狀態變化流向後續節點
5. **終止**: 當沒有更多節點可用時執行停止

### 導航邏輯

每個節點實現 `GetNextNodes()` 來指定應執行哪些節點：

```csharp
public IEnumerable<IGraphNode> GetNextNodes(FunctionResult? executionResult, GraphState graphState)
{
    // 根據執行結果和當前狀態返回下一個節點
    if (executionResult?.GetValue<bool>("should_continue") == true)
    {
        return new[] { nextNode };
    }
    return Enumerable.Empty<IGraphNode>(); // 終止執行
}
```

### 條件路由

條件邊根據執行狀態啟用動態路由：

```csharp
// 建立僅在滿足條件時才採用的邊
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

簡單的工作流程遵循線性序列：

```
Node A → Node B → Node C
```

### 分支路徑

條件邏輯建立分支執行：

```
        ┌─ 條件為真 ─→ Node B
Node A ─┤
        └─ 條件為假 ─→ Node C
```

### 平行路徑

多條路徑可以並行執行然後匯聚：

```
Node A ─┬─→ Node B ─┐
        │            │
        └─→ Node C ─┼─→ Node D
                     │
        └─→ Node E ─┘
```

### 循環路徑

節點可以建立循環以進行反覆處理：

```
Node A → Node B → 條件 → Node A（如果滿足條件）
```

## 受控循環

### 迴圈防止

圖形執行器包括內置的防護措施以防止無限迴圈：

* **最大迭代次數**: 對迴圈執行的可配置限制
* **執行深度**: 追蹤執行深度以檢測過度嵌套
* **超時控制**: 長時間執行操作的可配置超時
* **斷路器**: 自動終止有問題的執行路徑

### 迴圈控制

節點可以實現迴圈控制邏輯：

```csharp
public bool ShouldExecute(GraphState graphState)
{
    var iterationCount = graphState.GetValue<int>("iteration_count", 0);
    var maxIterations = graphState.GetValue<int>("max_iterations", 10);
    
    return iterationCount < maxIterations;
}
```

### 迴圈中的狀態管理

迴圈節點在迭代間維持狀態：

```csharp
// 存儲迭代計數
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

所有節點共享一個包裝 `KernelArguments` 的通用 `GraphState`：

```csharp
// 在狀態中設置值
graphState.SetValue("user_input", "Hello, world!");
graphState.SetValue("processing_step", 1);

// 從狀態檢索值
var input = graphState.GetValue<string>("user_input");
var step = graphState.GetValue<int>("processing_step");
```

### 狀態持久化

圖形狀態可以序列化和持久化：

```csharp
// 將狀態保存至檢查點
var checkpoint = await stateHelpers.SaveCheckpointAsync(graphState);

// 從檢查點恢復狀態
var restoredState = await stateHelpers.RestoreCheckpointAsync(checkpoint);
```

### 狀態驗證

節點可以在執行前驗證狀態：

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

ReAct（推理 + 執行）模式實現反覆問題解決：

```csharp
var reactNode = new ReActLoopGraphNode()
    .ConfigureNodes(
        reasoningNode,    // 分析和規劃
        actionNode,       // 執行操作
        observationNode   // 觀察結果
    );
```

### 多代理協調

多個代理可以使用共享狀態協同工作：

```csharp
var coordinator = new MultiAgentCoordinator();
coordinator.AddAgent("researcher", researchAgent);
coordinator.AddAgent("analyzer", analysisAgent);
coordinator.AddAgent("summarizer", summaryAgent);
```

### 人類參與循環

圖形可以暫停執行以獲得人類批准：

```csharp
var approvalNode = new HumanApprovalGraphNode(
    "approval_required",
    "Requires human approval to proceed"
);
```

## 最佳實踐

### 節點設計

* **單一責任**: 每個節點應有一個明確的目的
* **狀態驗證**: 執行前始終驗證輸入
* **錯誤處理**: 實現強大的錯誤處理和恢復
* **元數據**: 使用元數據提供除錯的上下文

### 邊設計

* **明確的條件**: 使條件邏輯明確和易於閱讀
* **性能**: 保持條件評估快速且無副作用
* **文檔**: 記錄複雜的路由邏輯

### 狀態管理

* **不可變更新**: 避免直接修改現有狀態
* **驗證**: 驗證狀態變化並提供有意義的錯誤消息
* **序列化**: 設計狀態時考慮序列化要求

### 性能

* **延遲評估**: 僅在必要時評估條件
* **緩存**: 盡可能緩存昂貴的計算
* **並行化**: 對獨立路徑使用並行執行

## 另見

* [執行模型](execution.md) - 詳細的執行生命週期
* [節點類型](nodes.md) - 可用的節點實現
* [狀態管理](state.md) - 進階狀態處理
* [路由策略](routing.md) - 動態路由技術
* [示例](../examples/) - 實際示例和用例

**可運行示例**: 請查看示例項目中的 `Examples/GraphConceptsExample.cs` 以獲取與本文檔對應的可運行代碼片段。在 `semantic-kernel-graph-docs/examples` 資料夾中使用以下命令運行：`dotnet run graph-concepts`。
