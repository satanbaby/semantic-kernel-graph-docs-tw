# 圖形

Graph 是由 Edge 連接的 Node 所組成的有向網路。執行從進入節點開始，並通過評估路由條件來進行。

## 概念和技術

**Computational Graph**: 代表工作流程或處理管道的資料結構，通過節點和連接。

**Entry Node**: 圖形執行的起始點，定義為 `StartNode`。

**Directed Edge**: 定義執行流方向的兩個節點之間的連接。

**Graph Validation**: 在執行前的完整性驗證，確保圖形有效。

## Graph 結構

### 基本組件
```csharp
var graph = new Graph
{
    Id = "workflow-001",
    Name = "Document Processing",
    Description = "Pipeline for document analysis and classification",
    StartNode = startNode,
    Nodes = new[] { startNode, processNode, classifyNode, endNode },
    Edges = new[] { edge1, edge2, edge3 }
};
```

### Nodes 和 Edges
* **Nodes**: 封裝工作（SK 函數、迴圈、子圖、工具）
* **Edges**: 攜帶可選條件以控制流程
* **Validation**: 引擎在執行前確保有效性

## Graph 類型

### 線性圖形
```csharp
// Simple sequence: A → B → C
var linearGraph = new Graph
{
    StartNode = nodeA,
    Nodes = new[] { nodeA, nodeB, nodeC },
    Edges = new[] 
    { 
        new Edge(nodeA, nodeB),
        new Edge(nodeB, nodeC)
    }
};
```

### 條件圖形
```csharp
// Graph with conditional branches
var conditionalGraph = new Graph
{
    StartNode = startNode,
    Nodes = new[] { startNode, processNode, successNode, failureNode },
    Edges = new[] 
    { 
        new ConditionalEdge(startNode, processNode),
        new ConditionalEdge(processNode, successNode, 
            condition: state => state.GetValue<int>("status") == 200),
        new ConditionalEdge(processNode, failureNode, 
            condition: state => state.GetValue<int>("status") != 200)
    }
};
```

### 迴圈圖形
```csharp
// Graph with controlled iteration
var loopGraph = new Graph
{
    StartNode = startNode,
    Nodes = new[] { startNode, loopNode, endNode },
    Edges = new[] 
    { 
        new Edge(startNode, loopNode),
        new ConditionalEdge(loopNode, loopNode, 
            condition: state => state.GetValue<int>("counter") < 10),
        new ConditionalEdge(loopNode, endNode, 
            condition: state => state.GetValue<int>("counter") >= 10)
    }
};
```

## 驗證和完整性

### 驗證檢查
```csharp
var validator = new WorkflowValidator();
var validationResult = await validator.ValidateAsync(graph);

if (!validationResult.IsValid)
{
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"Validation error: {error.Message}");
    }
}
```

### 驗證規則
* **Connectivity**: 所有節點必須可達
* **Cycles**: 無限迴圈的檢測
* **Types**: 輸入/輸出類型驗證
* **Dependencies**: 循環依賴檢查

## Graph 建構

### 程式化建構
```csharp
var graphBuilder = new GraphBuilder();

var graph = await graphBuilder
    .AddNode(startNode)
    .AddNode(processNode)
    .AddNode(endNode)
    .AddEdge(startNode, processNode)
    .AddEdge(processNode, endNode)
    .SetStartNode(startNode)
    .BuildAsync();
```

### 範本建構
```csharp
var template = new ChainOfThoughtWorkflowTemplate();
var graph = await template.CreateGraphAsync(
    kernel: kernel,
    options: new TemplateOptions
    {
        MaxSteps = 5,
        EnableReasoning = true
    }
);
```

### DSL 建構
```csharp
var dslParser = new GraphDslParser();
var graphDefinition = @"
    start -> process -> classify -> end
    process -> retry if error
    retry -> process if attempts < 3
";

var graph = await dslParser.ParseAsync(dslDefinition);
```

## 執行和控制

### 基本執行
```csharp
var executor = new GraphExecutor();
var arguments = new KernelArguments
{
    ["input"] = "documento.pdf",
    ["maxRetries"] = 3
};

var result = await executor.ExecuteAsync(graph, arguments);
```

### 串流執行
```csharp
var streamingExecutor = new StreamingGraphExecutor();
var eventStream = await streamingExecutor.ExecuteStreamingAsync(graph, arguments);

await foreach (var evt in eventStream)
{
    Console.WriteLine($"Event: {evt.Type} at node {evt.NodeId}");
}
```

### 檢查點執行
```csharp
var checkpointingExecutor = new CheckpointingGraphExecutor();
var result = await checkpointingExecutor.ExecuteAsync(graph, arguments);

// Save checkpoint
var checkpoint = await checkpointingExecutor.CreateCheckpointAsync();

// Restore execution
var restoredResult = await checkpointingExecutor.RestoreFromCheckpointAsync(checkpoint);
```

## 中繼資料和文件

### Graph 資訊
```csharp
var graphMetadata = new GraphMetadata
{
    Version = "1.0.0",
    Author = "Development Team",
    CreatedAt = DateTime.UtcNow,
    Tags = new[] { "documents", "classification", "AI" },
    EstimatedExecutionTime = TimeSpan.FromMinutes(5),
    ResourceRequirements = new ResourceRequirements
    {
        MaxMemory = "2GB",
        MaxCpu = "4 cores"
    }
};
```

### 自動文件生成
```csharp
var docGenerator = new GraphDocumentationGenerator();
var documentation = await docGenerator.GenerateAsync(graph, 
    new DocumentationOptions
    {
        IncludeCodeExamples = true,
        IncludeDiagrams = true,
        Format = DocumentationFormat.Markdown
    }
);
```

## 監視和可觀察性

### 執行指標
```csharp
var metrics = new GraphPerformanceMetrics
{
    TotalExecutionTime = TimeSpan.FromSeconds(45),
    NodeExecutionTimes = new Dictionary<string, TimeSpan>(),
    ExecutionPath = new[] { "start", "process", "classify", "end" },
    ResourceUsage = new ResourceUsageMetrics()
};
```

### 日誌和追蹤
```csharp
var logger = new SemanticKernelGraphLogger();
logger.LogGraphExecutionStart(graph.Id, executionId);
logger.LogGraphExecutionComplete(graph.Id, executionId, result);
logger.LogGraphValidation(graph.Id, validationResult);
```

## 參考閱讀

* [Graph 概念](../concepts/graph-concepts.md)
* [Node 類型](../concepts/node-types.md)
* [路由](../concepts/routing.md)
* [執行](../concepts/execution.md)
* [建構 Graph](../how-to/build-a-graph.md)
* [子圖例範](../examples/subgraph-examples.md)

## 參考資料

* `Graph`: 代表計算圖的主要類別
* `GraphBuilder`: 圖形的流暢建構器
* `WorkflowValidator`: 圖形完整性驗證器
* `GraphExecutor`: 主要圖形執行器
* `GraphDocumentationGenerator`: 自動文件生成器
* `GraphPerformanceMetrics`: 執行效能指標

### 範例

文件化的程式碼片段可在 `examples` 專案中作為可執行的 C# 範例使用。您可以通過 Examples 專案執行 `graph-concepts` 範例來驗證程式碼片段按如下方式執行：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- graph-concepts
```
