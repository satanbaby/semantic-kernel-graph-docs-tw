# Nodes

Nodes 是 Graph 的基礎元件，每個 Node 都封裝特定的工作單位或控制邏輯。

## 概念與技術

**Graph Node**: 封裝工作、控制邏輯或特定操作的基本處理單位。

**Node Lifecycle**: 在執行期間發生的事件序列：Before → Execute → After。

**IGraphNode Interface**: 所有 Nodes 必須實現的基本契約，用於系統整合。

## Node 類型

### Function Nodes
```csharp
// 使用輕量級記憶體中函數封裝 Semantic Kernel 函數
var processFunction = kernel.CreateFunctionFromMethod(
    (string input) => $"Processed: {input}",
    functionName: "process_input"
);

// 包裝核心函數並將結果儲存在 Graph 狀態中
var functionNode = new FunctionGraphNode(processFunction, "process_node")
    .StoreResultAs("processed_result");
```

**特性**:
* **Encapsulation**: 包裝 `KernelFunction`
* **Synchronous Execution**: 直接函數處理
* **Shared State**: 存取全域 `GraphState`
* **Metrics**: 自動收集性能數據

### Conditional Nodes
```csharp
// Node 根據條件使用 Graph 狀態進行決策
var conditionalNode = new ConditionalGraphNode(
    condition: state => state.ContainsValue("processed_result") &&
                        !string.IsNullOrEmpty(state.GetValue<string>("processed_result")),
    name: "quality_check"
);
```

**特性**:
* **Condition Evaluation**: 對狀態的布林運算式評估
* **Dynamic Routing**: 執行時決策
* **SK Templates**: 使用 Semantic Kernel 函數進行決策
* **Fallbacks**: 未滿足條件的後備策略

### Reasoning Nodes
```csharp
// Node 實現推理模式（簡化範例）
var reasoningNode = new ReasoningGraphNode(
    reasoningPrompt: "Analyze the processed result and decide next steps.",
    name: "reasoning_node"
);
```

**特性**:
* **Chain of Thought**: 逐步推理
* **Few-shot Learning**: 指導推理的範例
* **Result Validation**: 回應品質驗證
* **Controlled Iteration**: 限制以避免無限迴圈

### Loop Nodes
```csharp
// Node 實現受控迭代；組成推理、操作和觀察
var reactLoopNode = new ReActLoopGraphNode(nodeId: "react_loop", name: "react_loop");
reactLoopNode.ConfigureNodes(reasoningNode, actionNode, observationNode);
```

**特性**:
* **ReAct Pattern**: 觀察 → 思考 → 操作
* **Clear Objectives**: 每次迭代的具體目標
* **Iteration Control**: 限制以避免無限迴圈
* **Persistent State**: 迭代之間的上下文維護

### Observation Nodes
```csharp
// Node 觀察並記錄資訊（範例中由提示驅動）
var observationNode = new ObservationGraphNode(
    observationPrompt: "Analyze the action result and say if the goal was achieved.",
    name: "observation_node"
);
```

**特性**:
* **Passive Observation**: 不修改狀態
* **Logging**: 執行資訊的記錄
* **Metrics**: 收集性能數據
* **Debug**: 故障排除支援

### Subgraph Nodes
```csharp
// Node 封裝另一個 Graph
var subgraphNode = new SubgraphGraphNode(
    subgraph: documentAnalysisGraph,
    name: "document_analysis",
    description: "Complete document analysis pipeline"
);
```

**特性**:
* **Composition**: 重用現有 Graphs
* **Encapsulation**: 複雜 Graphs 的乾淨介面
* **Isolated State**: 變數作用域控制
* **Reusability**: 在不同環境中可重用的模組

### Error Handler Nodes
```csharp
// Node 處理異常和故障
var errorHandlerNode = new ErrorHandlerGraphNode(
    errorPolicy: new RetryPolicy(maxRetries: 3),
    name: "error_handler",
    description: "Handles errors and implements retry policies"
);
```

**特性**:
* **Error Policies**: 重試、退避、斷路器
* **Recovery**: 處理故障的策略
* **Logging**: 詳細的錯誤記錄
* **Fallbacks**: 主要操作失敗時的替代方案

### Human Approval Nodes
```csharp
// Node 暫停以進行人工互動
var approvalNode = new HumanApprovalGraphNode(
    channel: new ConsoleHumanInteractionChannel(),
    timeout: TimeSpan.FromMinutes(30),
    name: "human_approval",
    description: "Waits for human approval to continue"
);
```

**特性**:
* **Human Interaction**: 暫停以進行人工輸入
* **Timeouts**: 回應的時間限制
* **Multiple Channels**: 控制台、網頁、電郵
* **Audit**: 人工決策的記錄

## Node 生命週期

### Before Phase
```csharp
public override async Task BeforeExecutionAsync(GraphExecutionContext context)
{
    // 輸入驗證
    await ValidateInputAsync(context.State);
    
    // 資源初始化
    await InitializeResourcesAsync();
    
    // 開始記錄日誌
    _logger.LogInformation($"Starting execution of node {Id}");
}
```

### Execute Phase
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

### After Phase
```csharp
public override async Task AfterExecutionAsync(GraphExecutionContext context)
{
    // 資源清理
    await CleanupResourcesAsync();
    
    // 性能記錄日誌
    _logger.LogInformation($"Node {Id} completed in {context.ExecutionTime}");
    
    // 計數器更新
    UpdateExecutionMetrics(context);
}
```

## 配置與選項

### Node 選項
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

## 監控與可觀測性

### Node 指標
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

### 結構化記錄日誌
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

* [Node Types](../concepts/node-types.md)
* [Conditional Nodes](../how-to/conditional-nodes.md)
* [Loops](../how-to/loops.md)
* [Human-in-the-Loop](../how-to/hitl.md)
* [Error Handling](../how-to/error-handling-and-resilience.md)
* [Node Examples](../examples/conditional-nodes.md)

## 參考資料

* `IGraphNode`: 所有 Nodes 的基礎介面
* `FunctionGraphNode`: 封裝 SK 函數的 Node
* `ConditionalGraphNode`: 用於條件決策的 Node
* `ReasoningGraphNode`: 用於逐步推理的 Node
* `ReActLoopGraphNode`: 用於 ReAct 迴圈的 Node
* `ObservationGraphNode`: 用於觀察和記錄的 Node
* `SubgraphGraphNode`: 封裝其他 Graphs 的 Node
* `ErrorHandlerGraphNode`: 用於錯誤處理的 Node
* `HumanApprovalGraphNode`: 用於人工互動的 Node
