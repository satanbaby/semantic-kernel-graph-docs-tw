---
title: 從 Semantic Kernel 遷移到 SemanticKernel.Graph
---

## 從純 Semantic Kernel 遷移

本指南說明如何以最少變動，將使用 Semantic Kernel (SK) 建立的臨時管道遷移至使用 SemanticKernel.Graph 的結構化圖表。

### 先決條件
* SK 已設定您的 LLM 提供者
* 要重複使用的現有外掛程式/函式

### 1) 安裝並設定

```csharp
var builder = Kernel.CreateBuilder();
// ... 您的 SK 設定（模型、記憶體、日誌記錄）
// 加入圖表支援
builder.AddGraphSupport(options =>
{
    options.EnableLogging = true;
});
var kernel = builder.Build();
```

### 2) 將現有函式包裝為節點

```csharp
// 來自外掛程式函式
var myNode = FunctionGraphNode.FromFunction(myPlugin["MyFunction"], nodeId: "my-node");

// REST 工具 → 節點
var restNode = new RestToolGraphNode(new RestToolSchema { /* 對應輸入/輸出 */ });
```

### 3) 將節點連接至圖表

```csharp
// 建立執行器並新增節點
var graph = new GraphExecutor("my-graph");
graph.AddNode(myNode);
graph.AddNode(restNode);

// 依節點識別碼連接（建議）或使用接受節點執行個體的 Connect 多載
graph.Connect(myNode.NodeId, restNode.NodeId);
```

### 4) 在需要時新增控制流程

```csharp
var decision = new ConditionalGraphNode(state => (bool)state["should_call_api"]);
graph.AddNode(decision);

// 使用 AddTrueNode/AddFalseNode 明確連接條件路徑
decision.AddTrueNode(restNode);
decision.AddFalseNode(myNode);

// 將決策連接至主要流程
graph.Connect(myNode.NodeId, decision.NodeId);
```

### 5) 以共用狀態執行

```csharp
var args = new KernelArguments { ["input"] = userMessage };
var result = await graph.ExecuteAsync(kernel, args);
```

### 功能對應
* SK 函式管道 → `FunctionGraphNode` 鏈
* 條件分支 → `ConditionalGraphNode`/`SwitchGraphNode`
* 迴圈 → `WhileLoopGraphNode`/`ForeachLoopGraphNode`
* 錯誤處理/重試 → `ErrorHandlerGraphNode`/`RetryPolicyGraphNode`
* 可觀測性 → `GraphPerformanceMetrics` + `IGraphTelemetry`
* 檢查點/復原 → `CheckpointingExtensions`

### 遷移檢查清單
* 透過 `FunctionGraphNode` 重複使用外掛程式/函式
* 透過 `RestToolGraphNode` + `IToolSchemaConverter` 處理外部 API
* 使用節點/邊替換自訂流程程式碼
* 啟用指標/遙測和（選擇性）檢查點功能
* 如果需要即時事件，請新增串流功能
