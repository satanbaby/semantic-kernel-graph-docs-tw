---
title: 從 Semantic Kernel 遷移至 SemanticKernel.Graph
---

## 從純粹的 Semantic Kernel 遷移

本指南說明如何透過最少的變更，從使用 Semantic Kernel (SK) 建立的臨時管線遷移到使用 SemanticKernel.Graph 的結構化 Graph。

### 先決條件
* SK 已配置到您的 LLM 供應商
* 您想要重新使用的現有外掛程式/函數

### 1) 安裝並配置
```csharp
var builder = Kernel.CreateBuilder();
// ... 您的 SK 配置 (models, memory, logging)
// 新增 Graph 支援
builder.AddGraphSupport(options =>
{
    options.EnableLogging = true;
});
var kernel = builder.Build();
```

### 2) 將現有函數包裝為 Node
```csharp
// 從外掛程式函數
var myNode = FunctionGraphNode.FromFunction(myPlugin["MyFunction"], nodeId: "my-node");

// REST 工具 → Node
var restNode = new RestToolGraphNode(new RestToolSchema { /* 對應輸入/輸出 */ });
```

### 3) 將 Node 連接到 Graph 中
```csharp
// 建立執行器並新增 Node
var graph = new GraphExecutor("my-graph");
graph.AddNode(myNode);
graph.AddNode(restNode);

// 按 Node ID 連接（建議）或使用接受 Node 實例的 Connect 多載
graph.Connect(myNode.NodeId, restNode.NodeId);
```

### 4) 在需要時新增控制流程
```csharp
var decision = new ConditionalGraphNode(state => (bool)state["should_call_api"]);
graph.AddNode(decision);

// 使用 AddTrueNode/AddFalseNode 明確連接條件路徑
decision.AddTrueNode(restNode);
decision.AddFalseNode(myNode);

// 將決策連接到主流程
graph.Connect(myNode.NodeId, decision.NodeId);
```

### 5) 使用共享狀態執行
```csharp
var args = new KernelArguments { ["input"] = userMessage };
var result = await graph.ExecuteAsync(kernel, args);
```

### 功能對應
* SK 函數管線 → `FunctionGraphNode` 鏈
* 條件分支 → `ConditionalGraphNode`/`SwitchGraphNode`
* 迴圈 → `WhileLoopGraphNode`/`ForeachLoopGraphNode`
* 錯誤處理/重試 → `ErrorHandlerGraphNode`/`RetryPolicyGraphNode`
* 可觀測性 → `GraphPerformanceMetrics` + `IGraphTelemetry`
* 檢查點/復原 → `CheckpointingExtensions`

### 遷移檢查清單
* 透過 `FunctionGraphNode` 重新使用外掛程式/函數
* 透過 `RestToolGraphNode` + `IToolSchemaConverter` 使用外部 API
* 用 Node 和 Edge 替換自訂流程程式碼
* 啟用指標/遙測和（選擇性）檢查點
* 如果您需要即時事件，請新增串流
