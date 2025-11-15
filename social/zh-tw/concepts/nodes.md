# 節點

節點是圖形的基本元件，每個節點都封裝一個特定的工作單元或控制邏輯。

## 概念和技術

**圖形節點**：基礎處理單元，封裝工作、控制邏輯或特定操作。

**節點生命週期**：執行期間發生的一系列事件：前置 → 執行 → 後置。

**IGraphNode 介面**：所有節點都必須實現的基礎契約，用於系統整合。

## 節點類型

### 函數節點
```csharp
// 使用輕量級記憶體內函數來封裝語義核心函數
var processFunction = kernel.CreateFunctionFromMethod(
    (string input) => $"Processed: {input}",
    functionName: "process_input"
);

// 包裝核心函數並將結果存儲在圖形狀態中
var functionNode = new FunctionGraphNode(processFunction, "process_node")
    .StoreResultAs("processed_result");
```

**特性**：
* **封裝**：包裝 `KernelFunction`
* **同步執行**：直接函數處理
* **共享狀態**：存取全域 `GraphState`
* **指標**：自動效能收集

### 條件節點
```csharp
// 基於圖形狀態中的條件進行決策的節點
var conditionalNode = new ConditionalGraphNode(
    condition: state => state.ContainsValue("processed_result") &&
                        !string.IsNullOrEmpty(state.GetValue<string>("processed_result")),
    name: "quality_check"
);
```

**特性**：
* **條件評估**：狀態上的布林表達式
* **動態路由**：執行時間決策
* **SK 範本**：使用語義核心函數進行決策
* **回退**：未滿足條件的回退策略

### 推理節點
```csharp
// 實現推理模式的節點（簡化範例）
var reasoningNode = new ReasoningGraphNode(
    reasoningPrompt: "Analyze the processed result and decide next steps.",
    name: "reasoning_node"
);
```

**特性**：
* **思維鏈**：逐步推理
* **少樣本學習**：指導推理的範例
* **結果驗證**：回應的品質驗證
* **受控迭代**：避免無限迴圈的限制

### 迴圈節點
```csharp
// 實現受控迭代的節點；組合推理、動作和觀察
var reactLoopNode = new ReActLoopGraphNode(nodeId: "react_loop", name: "react_loop");
reactLoopNode.ConfigureNodes(reasoningNode, actionNode, observationNode);
```

**特性**：
* **ReAct 模式**：觀察 → 思考 → 動作
* **明確目標**：每次迭代的具體目標
* **迭代控制**：避免無限迴圈的限制
* **持久狀態**：迭代之間的上下文維護

### 觀察節點
```csharp
// 觀察和記錄資訊的節點（在範例中由提示驅動）
var observationNode = new ObservationGraphNode(
    observationPrompt: "Analyze the action result and say if the goal was achieved.",
    name: "observation_node"
);
```

**特性**：
* **被動觀察**：不修改狀態
* **日誌記錄**：執行資訊的記錄
* **指標**：效能資料收集
* **除錯**：故障排除支援

### 子圖節點
```csharp
// 封裝另一個圖形的節點
var subgraphNode = new SubgraphGraphNode(
    subgraph: documentAnalysisGraph,
    name: "document_analysis",
    description: "Complete document analysis pipeline"
);
```

**特性**：
* **組合**：現有圖形的重複使用
* **封裝**：複雜圖形的清潔介面
* **隔離狀態**：變數範圍控制
* **可重複使用性**：在不同上下文中可重複使用的模組

### 錯誤處理節點
```csharp
// 處理例外和失敗的節點
var errorHandlerNode = new ErrorHandlerGraphNode(
    errorPolicy: new RetryPolicy(maxRetries: 3),
    name: "error_handler",
    description: "Handles errors and implements retry policies"
);
```

**特性**：
* **錯誤原則**：重試、退避、斷路器
* **復原**：處理失敗的策略
* **日誌記錄**：詳細的錯誤記錄
* **回退**：主操作失敗時的替代方案

### 人工核准節點
```csharp
// 暫停進行人工互動的節點
var approvalNode = new HumanApprovalGraphNode(
    channel: new ConsoleHumanInteractionChannel(),
    timeout: TimeSpan.FromMinutes(30),
    name: "human_approval",
    description: "Waits for human approval to continue"
);
```

**特性**：
* **人工互動**：暫停以獲得使用者輸入
* **逾時**：回應的時間限制
* **多個通道**：主控台、網頁、電子郵件
* **稽核**：人工決策的記錄

## 節點生命週期

### 前置階段
```csharp
public override async Task BeforeExecutionAsync(GraphExecutionContext context)
{
    // 輸入驗證
    await ValidateInputAsync(context.State);
    
    // 資源初始化
    await InitializeResourcesAsync();
    
    // 啟動日誌記錄
    _logger.LogInformation($"Starting execution of node {Id}");
}
```

### 執行階段
```csharp
public override async Task<GraphExecutionResult> ExecuteAsync(GraphExecutionContext context)
{
    try
    {
        // 主要執行
        var result = await ProcessAsync(context.State);
        
        // 狀態更新
        context.State.SetValue("output", result);
        
        return GraphExecutionResult.Success(result);
    }
    catch (Exception ex)
    {
        return GraphExecutionResult.Failure(ex);
    }
}
```

### 後置階段
```csharp
public override async Task AfterExecutionAsync(GraphExecutionContext context)
{
    // 資源清理
    await CleanupResourcesAsync();
    
    // 效能日誌記錄
    _logger.LogInformation($"Node {Id} completed in {context.ExecutionTime}");
    
    // 計數器更新
    UpdateExecutionMetrics(context);
}
```

## 設定和選項

### 節點選項
```csharp
var nodeOptions = new GraphNodeOptions
{
    EnableMetrics = true,
    EnableLogging = true,
    MaxExecutionTime = TimeSpan.FromMinutes(5),
    RetryPolicy = new ExponentialBackoffRetryPolicy(maxRetries: 3),
    CircuitBreaker = new CircuitBreakerOptions
    {
        FailureThreshold = 5,
        RecoveryTimeout = TimeSpan.FromMinutes(1)
    }
};
```

### 輸入/輸出驗證
```csharp
var inputSchema = new GraphNodeInputSchema
{
    Required = new[] { "document", "language" },
    Optional = new[] { "confidence_threshold" },
    Types = new Dictionary<string, Type>
    {
        ["document"] = typeof(string),
        ["language"] = typeof(string),
        ["confidence_threshold"] = typeof(double)
    }
};

var outputSchema = new GraphNodeOutputSchema
{
    Properties = new[] { "analysis_result", "confidence_score" },
    Types = new Dictionary<string, Type>
    {
        ["analysis_result"] = typeof(string),
        ["confidence_score"] = typeof(double)
    }
};
```

## 監控和可觀測性

### 節點指標
```csharp
var nodeMetrics = new NodeExecutionMetrics
{
    ExecutionCount = 150,
    AverageExecutionTime = TimeSpan.FromMilliseconds(250),
    SuccessRate = 0.98,
    LastExecutionTime = DateTime.UtcNow,
    ErrorCount = 3,
    ResourceUsage = new ResourceUsageMetrics()
};
```

### 結構化日誌記錄
```csharp
_logger.LogInformation("Node execution started", new
{
    NodeId = Id,
    NodeType = GetType().Name,
    InputKeys = context.State.GetKeys(),
    ExecutionId = context.ExecutionId,
    Timestamp = DateTime.UtcNow
});
```

## 另請參閱

* [節點類型](../concepts/node-types.md)
* [條件節點](../how-to/conditional-nodes.md)
* [迴圈](../how-to/loops.md)
* [人機迴圈](../how-to/hitl.md)
* [錯誤處理](../how-to/error-handling-and-resilience.md)
* [節點範例](../examples/conditional-nodes.md)

## 參考資料

* `IGraphNode`：所有節點的基礎介面
* `FunctionGraphNode`：封裝 SK 函數的節點
* `ConditionalGraphNode`：用於條件決策的節點
* `ReasoningGraphNode`：用於逐步推理的節點
* `ReActLoopGraphNode`：用於 ReAct 迴圈的節點
* `ObservationGraphNode`：用於觀察和日誌記錄的節點
* `SubgraphGraphNode`：封裝其他圖形的節點
* `ErrorHandlerGraphNode`：用於錯誤處理的節點
* `HumanApprovalGraphNode`：用於人工互動的節點
