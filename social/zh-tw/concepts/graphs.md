# 圖表

圖表是由邊連接的節點的有向網絡。執行從入口節點開始，並通過評估路由條件進行。

## 概念和技術

**計算圖**：透過節點和連接表示工作流程或處理管道的資料結構。

**入口節點**：圖表執行的起點，定義為 `StartNode`。

**有向邊**：兩個節點之間的連接，定義執行流程的方向。

**圖表驗證**：在執行前進行完整性驗證，以確保圖表有效。

## 圖表結構

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

### 節點和邊
* **節點**：封裝工作（SK 函數、迴圈、子圖、工具）
* **邊**：執行可選條件以控制流程
* **驗證**：引擎在執行前確保有效性

## 圖表類型

### 線性圖表
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

### 條件圖表
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

### 迴圈圖表
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
* **連接性**：所有節點必須可到達
* **迴圈**：無限迴圈的檢測
* **類型**：輸入/輸出類型的驗證
* **依賴關係**：循環依賴檢查

## 圖表構建

### 程式化構建
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

### 模板構建
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

### DSL 構建
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

## 元資料和文檔

### 圖表資訊
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

### 自動文檔生成
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

## 監控和可觀測性

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

### 日誌記錄和追蹤
```csharp
var logger = new SemanticKernelGraphLogger();
logger.LogGraphExecutionStart(graph.Id, executionId);
logger.LogGraphExecutionComplete(graph.Id, executionId, result);
logger.LogGraphValidation(graph.Id, validationResult);
```

## 另請參閱

* [圖表概念](../concepts/graph-concepts.md)
* [節點類型](../concepts/node-types.md)
* [路由](../concepts/routing.md)
* [執行](../concepts/execution.md)
* [構建圖表](../how-to/build-a-graph.md)
* [子圖示例](../examples/subgraph-examples.md)

## 參考

* `Graph`：表示計算圖的主類別
* `GraphBuilder`：圖表的流暢建構器
* `WorkflowValidator`：圖表完整性驗證器
* `GraphExecutor`：主圖表執行器
* `GraphDocumentationGenerator`：自動文檔生成器
* `GraphPerformanceMetrics`：執行效能指標

### 示例

文檔中的程式碼片段可作為 `examples` 專案中可執行的 C# 示例使用。您可以透過 Examples 專案執行 `graph-concepts` 示例，以驗證程式碼片段如圖所示執行：

```bash
dotnet run --project semantic-kernel-graph-docs/examples/Examples.csproj -- graph-concepts
```
