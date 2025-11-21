# 除錯與檢查

SemanticKernel.Graph 中的除錯和檢查功能提供了全面的工具，用於理解、排查故障和分析 Graph 執行。本指南涵蓋除錯工作階段、斷點、GraphInspectionApi、Graph 視覺化和執行重新播放。

## 您將學到的內容

* 如何建立和配置除錯工作階段
* 設定不同類型的斷點
* 使用 GraphInspectionApi 進行執行時監控
* 以多種格式產生 Graph 視覺化
* 重新播放執行歷史進行分析
* 複雜工作流程的除錯最佳實踐

## 概念與技術

**Debug Session（除錯工作階段）**：一個受控執行環境，允許在 Graph 執行期間進行逐步執行、斷點管理和狀態檢查。

**Breakpoint（斷點）**：一個條件，在特定 Node 處暫停執行，允許檢查該點的狀態和變數。

**GraphInspectionApi**：用於即時檢查 Graph 結構、執行狀態和效能指標的執行時 API。

**Graph Visualization（Graph 視覺化）**：可匯出功能，用於以 DOT、Mermaid、JSON 和其他格式產生圖表，並突出顯示執行路徑。

**Execution Replay（執行重新播放）**：能夠逐步重新播放已完成的執行以進行分析和除錯。

## 必要條件

* [First Graph Tutorial](../first-graph-5-minutes.md) 已完成
* 對 Graph 執行概念有基本了解
* 熟悉狀態管理和條件 Node

## 除錯工作階段

### 建立除錯工作階段

除錯工作階段提供逐步執行控制和全面的除錯功能：

```csharp
using SemanticKernel.Graph.Debug;
using SemanticKernel.Graph.Core;

// 建立 GraphExecutor（根據場景需要關聯 Kernel）
var graphExecutor = new GraphExecutor(kernel);

// 建立執行內容（kernel + 初始 Graph 狀態）
var graphState = new GraphState(new KernelArguments { ["input"] = "demo" });
var executionContext = new GraphExecutionContext(kernel, graphState);

// Fluent builder：配置斷點和初始模式，然後建立工作階段
var debugSession = await DebugSessionBuilder
    .ForExecution(graphExecutor, executionContext)
    .WithInitialMode(DebugExecutionMode.StepOver)
    .WithBreakpoint("decision_node", "{{user_score}} > 80", "High score breakpoint")
    .WithBreakpoint("error_handler", state => state.GetValue<bool>("has_error"), "Error condition")
    .BuildAsync();

// 替代方案（便利）：執行並通過幫助程式取得除錯工作階段
var (result, session) = await graphExecutor.ExecuteWithDebugAsync(kernel, arguments, DebugExecutionMode.StepOver);
```

### 除錯執行模式

不同的模式控制除錯期間的執行流程：

```csharp
// Step-over：執行目前 Node 並在下一個暫停
await debugSession.ResumeAsync(DebugExecutionMode.StepOver);

// Step-into：如果可用，進入子 Graph 執行
await debugSession.ResumeAsync(DebugExecutionMode.StepInto);

// Step-out：繼續執行直到退出目前內容
await debugSession.ResumeAsync(DebugExecutionMode.StepOut);

// Continue：執行到下一個斷點
await debugSession.ResumeAsync(DebugExecutionMode.Continue);

// Pause：在目前位置停止執行
await debugSession.PauseAsync();
```

### 除錯工作階段控制

管理除錯工作階段的生命週期和執行流程：

```csharp
// 啟動工作階段
await debugSession.StartAsync(DebugExecutionMode.StepOver);

// 檢查工作階段狀態
if (debugSession.IsPaused)
{
    var pausedNode = debugSession.PausedAtNode;
    var currentState = debugSession.CurrentState;
    Console.WriteLine($"Paused at: {pausedNode?.Name}");
}

// 逐步執行
await debugSession.StepAsync();

// 繼續執行
await debugSession.ResumeAsync(DebugExecutionMode.Continue);

// 停止工作階段
await debugSession.StopAsync();
```

## 斷點

### 斷點類型

SemanticKernel.Graph 支援多種斷點類型以應對不同的除錯場景：

#### 條件斷點

在符合特定條件時中斷：

```csharp
// 基於函式的條件
var breakpointId = debugSession.AddBreakpoint(
    "validation_node",
    state => state.GetValue<int>("attempt_count") > 3,
    "Break after 3 attempts"
);

// 使用範本的基於運算式的條件
var expressionBreakpoint = debugSession.AddBreakpoint(
    "decision_node",
    "{{user_role}} == 'admin' && {{permission_level}} >= 5",
    "Admin permission check"
);
```

#### 資料斷點

當特定變數發生變化時暫停執行：

```csharp
// 當 error_count 變化時中斷
var dataBreakpoint = debugSession.AddDataBreakpoint(
    "error_count",
    "Monitor error count changes"
);

// 當群組中的任何變數變化時中斷
var groupBreakpoint = debugSession.AddDataBreakpoint(
    "user_preferences",
    "Monitor user preference changes"
);
```

#### 自動過期斷點

在被觸發後自動移除本身的斷點：

```csharp
// 僅中斷前 3 次
var limitedBreakpoint = debugSession.AddBreakpoint(
    "retry_node",
    "{{retry_count}} > 0",
    3, // Max hit count
    "Break on first 3 retries"
);

// 基於運算式，並且有觸發次數限制
var expressionLimited = debugSession.AddBreakpoint(
    "validation_node",
    "{{validation_errors}}.Count > 5",
    2, // Max hit count
    "Break when validation errors exceed 5"
);
```

### 斷點管理

在整個除錯工作階段中管理斷點：

```csharp
// 取得所有作用中的斷點
var breakpoints = debugSession.GetBreakpoints();
foreach (var bp in breakpoints)
{
    Console.WriteLine($"Breakpoint: {bp.BreakpointId} at {bp.NodeId}");
    Console.WriteLine($"Description: {bp.Description}");
    Console.WriteLine($"Hit count: {bp.HitCount}");
}

// 移除特定斷點
debugSession.RemoveBreakpoint(breakpointId);

// 清除所有斷點
debugSession.ClearBreakpoints();
```

## 狀態檢查

### 檢查目前狀態

在除錯期間檢查變數和狀態：

```csharp
// 取得所有目前變數
var variables = debugSession.GetCurrentVariables();
foreach (var kvp in variables)
{
    Console.WriteLine($"{kvp.Key}: {kvp.Value}");
}

// 使用類型安全取得特定變數
var userName = debugSession.GetVariable<string>("user_name");
var userScore = debugSession.GetVariable<int>("user_score");
var isActive = debugSession.GetVariable<bool>("is_active");

// 在除錯期間設定變數
debugSession.SetVariable("debug_mode", true);
debugSession.SetVariable("test_value", 42);
```

### 執行歷史

追蹤和分析執行步驟：

```csharp
// 取得完整執行歷史
var history = debugSession.GetExecutionHistory();
foreach (var step in history)
{
    Console.WriteLine($"Step: {step.Node.Name} ({step.Node.NodeId})");
    Console.WriteLine($"Duration: {step.Duration.TotalMilliseconds:F2}ms");
    Console.WriteLine($"Status: {step.Status}");
    
    // 存取執行前後的狀態
    var stateBefore = step.StateBefore;
    var stateAfter = step.StateAfter;
}

// 從目前位置取得可用的下一個 Node
var nextNodes = debugSession.GetAvailableNextNodes();
foreach (var node in nextNodes)
{
    Console.WriteLine($"Next: {node.Name} ({node.NodeId})");
}
```

## GraphInspectionApi

### 執行時檢查

GraphInspectionApi 提供全面的執行時監控功能：

```csharp
using SemanticKernel.Graph.Core;

// 建立檢查 API
var inspectionApi = new GraphInspectionApi(
    new GraphInspectionOptions
    {
        IncludeDebugInfo = true,
        IncludePerformanceHeatmaps = true
    }
);

// 取得 Graph 結構資訊
var structureInfo = inspectionApi.GetGraphStructure(executionId);
Console.WriteLine($"Graph: {structureInfo.GraphName}");
Console.WriteLine($"Nodes: {structureInfo.NodeCount}");
Console.WriteLine($"Edges: {structureInfo.EdgeCount}");

// 取得執行狀態
var status = inspectionApi.GetExecutionStatus(executionId);
Console.WriteLine($"Status: {status.Status}");
Console.WriteLine($"Start time: {status.StartTime}");
Console.WriteLine($"Duration: {status.Duration}");
```

### 效能監控

監控執行效能和指標：

```csharp
// 取得特定 Node 的效能指標
var nodeMetrics = inspectionApi.GetNodeMetrics(executionId, "processing_node");
if (nodeMetrics != null)
{
    Console.WriteLine($"Total executions: {nodeMetrics.TotalExecutions}");
    Console.WriteLine($"Average time: {nodeMetrics.AverageExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"Success rate: {nodeMetrics.SuccessRate:P}");
}

// 取得整體效能摘要
var performanceSummary = inspectionApi.GetPerformanceSummary(executionId);
Console.WriteLine($"Total execution time: {performanceSummary.TotalExecutionTime.TotalMilliseconds:F2}ms");
Console.WriteLine($"Average node time: {performanceSummary.AverageNodeExecutionTime.TotalMilliseconds:F2}ms");
Console.WriteLine($"Slowest node: {performanceSummary.SlowestNode?.NodeId}");
```

### 除錯資訊

在執行期間存取除錯特定資訊：

```csharp
// 取得特定 Node 的除錯資訊
var debugInfo = inspectionApi.GetNodeDebugInfo(executionId, "decision_node");
if (debugInfo != null)
{
    Console.WriteLine($"Has breakpoints: {debugInfo.HasBreakpoints}");
    Console.WriteLine($"Is paused: {debugInfo.IsPaused}");
    
    if (debugInfo.Breakpoints != null)
    {
        foreach (var bp in debugInfo.Breakpoints)
        {
            Console.WriteLine($"Breakpoint: {bp.Description}");
            Console.WriteLine($"Hit count: {bp.HitCount}");
        }
    }
}
```

## Graph 視覺化

### 匯出格式

為不同的用例以多種格式產生視覺化：

```csharp
using SemanticKernel.Graph.Core;

var visualizationEngine = new GraphVisualizationEngine(
    new GraphVisualizationOptions
    {
        EnableExecutionPathHighlighting = true,
        IncludePerformanceMetrics = true
    }
);

// 產生 DOT 格式供 GraphViz 使用
var dotOptions = new DotSerializationOptions
{
    GraphName = "My Workflow",
    LayoutDirection = DotLayoutDirection.LeftToRight,
    EnableClustering = true
};
var dotGraph = visualizationEngine.SerializeToDot(visualizationData, dotOptions);

// 產生 Mermaid 圖表
var mermaidOptions = new MermaidGenerationOptions
{
    Direction = "TB", // Top to bottom
    IncludeTitle = true,
    EnableStyling = true,
    HighlightExecutionPath = true
};
var mermaidDiagram = visualizationEngine.GenerateEnhancedMermaidDiagram(
    visualizationData, 
    mermaidOptions
);

// 產生 JSON 供 API 使用
var jsonOptions = new JsonSerializationOptions
{
    Indented = true,
    UseCamelCase = true,
    IncludeMetadata = true
};
var jsonGraph = visualizationEngine.SerializeToJson(visualizationData, jsonOptions);
```

### 除錯工作階段視覺化

在除錯工作階段期間產生視覺化：

```csharp
// 使用目前狀態突顯產生視覺化
var visualization = debugSession.GenerateVisualization(highlightCurrent: true);

// 匯出工作階段資料進行分析
var sessionData = debugSession.ExportSessionData(includeHistory: true);

// 為除錯內容產生 Mermaid 圖表
var debugDiagram = debugSession.GenerateMermaidDiagram(highlightCurrent: true);
Console.WriteLine(debugDiagram);
```

### 即時更新

視覺化可以包含即時執行資訊：

```csharp
// 建立包含執行路徑的視覺化資料
var visualizationData = new GraphVisualizationData
{
    Nodes = graphNodes.Select(n => new NodeVisualizationData
    {
        NodeId = n.NodeId,
        Name = n.Name,
        NodeType = n.GetType().Name,
        IsExecuted = executedNodes.Contains(n.NodeId),
        ExecutionTime = nodeMetrics.GetValueOrDefault(n.NodeId)?.AverageExecutionTime
    }).ToList(),
    
    Edges = graphEdges.Select(e => new EdgeVisualizationData
    {
        FromNodeId = e.FromNodeId,
        ToNodeId = e.ToNodeId,
        Label = e.Condition?.ToString(),
        IsExecuted = executedEdges.Contains($"{e.FromNodeId}->{e.ToNodeId}")
    }).ToList(),
    
    ExecutionPath = executedNodes.ToList(),
    CurrentNode = currentExecutingNode,
    GeneratedAt = DateTimeOffset.UtcNow
};
```

## 執行重新播放

### 建立重新播放

重新播放已完成的執行以進行分析和除錯：

```csharp
// 從除錯工作階段建立重新播放
var replay = debugSession.CreateReplay();

// 或從執行歷史建立
var replayFromHistory = new ExecutionReplay(
    executionHistory,
    initialVariables,
    executionId,
    startTime,
    endTime,
    status
);
```

### 重新播放控制

控制重新播放執行和分析：

```csharp
// 啟動重新播放
await replay.StartAsync();

// 逐步執行重新播放
await replay.StepForwardAsync();
await replay.StepBackwardAsync();

// 跳至特定步驟
await replay.JumpToStepAsync(5);

// 取得目前重新播放狀態
var currentStep = replay.CurrentStep;
var currentState = replay.CurrentState;
var stepIndex = replay.CurrentStepIndex;

// 檢查重新播放狀態
if (replay.IsAtEnd)
{
    Console.WriteLine("Replay completed");
}
else if (replay.IsAtBeginning)
{
    Console.WriteLine("Replay at start");
}
```

### 假設分析

在重新播放期間修改變數以測試不同的場景：

```csharp
// 在目前步驟修改變數
replay.ModifyVariable("user_score", 95);
replay.ModifyVariable("user_role", "admin");

// 套用變更並繼續
await replay.ApplyChangesAsync();
await replay.StepForwardAsync();

// 與原始執行比較
var originalResult = replay.GetOriginalResult();
var modifiedResult = replay.GetModifiedResult();
```

## 進階除錯模式

### 條件除錯

使用條件運算式進行複雜的斷點邏輯：

```csharp
// 複雜的條件斷點
var complexBreakpoint = debugSession.AddBreakpoint(
    "workflow_node",
    "{{user_role}} == 'admin' && {{permission_level}} >= 5 && {{session_duration}}.TotalMinutes > 30",
    "Admin with high permissions and long session"
);

// 含有狀態比較的斷點
var stateBreakpoint = debugSession.AddBreakpoint(
    "validation_node",
    state => {
        var errors = state.GetValue<List<string>>("validation_errors") ?? new();
        var warnings = state.GetValue<List<string>>("validation_warnings") ?? new();
        return errors.Count > 5 || warnings.Count > 10;
    },
    "High error/warning count"
);
```

### 效能除錯

使用特殊斷點除錯效能問題：

```csharp
// 在執行緩慢時中斷
var performanceBreakpoint = debugSession.AddBreakpoint(
    "slow_node",
    state => {
        var executionTime = state.GetValue<TimeSpan>("node_execution_time");
        return executionTime.TotalMilliseconds > 1000; // 1 second
    },
    "Break on slow execution"
);

// 在記憶體使用量高時中斷
var memoryBreakpoint = debugSession.AddBreakpoint(
    "memory_intensive_node",
    state => {
        var memoryUsage = state.GetValue<long>("memory_usage_bytes");
        return memoryUsage > 100 * 1024 * 1024; // 100 MB
    },
    "Break on high memory usage"
);
```

### 錯誤除錯

除錯錯誤條件和恢復情景：

```csharp
// 在錯誤條件時中斷
var errorBreakpoint = debugSession.AddBreakpoint(
    "error_handler",
    state => {
        var hasError = state.GetValue<bool>("has_error");
        var errorCount = state.GetValue<int>("error_count");
        var lastError = state.GetValue<string>("last_error_message");
        
        return hasError && (errorCount > 3 || lastError?.Contains("timeout") == true);
    },
    "Break on critical errors"
);

// 在重試嘗試時中斷
var retryBreakpoint = debugSession.AddBreakpoint(
    "retry_node",
    "{{retry_count}} > {{max_retries}} * 0.8", // Break at 80% of max retries
    "Break near retry limit"
);
```

## 最佳實踐

### 除錯工作階段管理

* **工作階段生命週期**：始終釋放除錯工作階段以釋放資源
* **模式選擇**：為不同的場景選擇適當的除錯模式
* **斷點策略**：謹慎使用條件斷點以避免過度暫停
* **狀態檢查**：在關鍵決策點檢查狀態，而不是每個 Node

### 效能考量

* **斷點影響**：每個斷點都會對執行增加額外開銷
* **歷史大小**：大型執行歷史會消耗記憶體
* **視覺化產生**：複雜視覺化對大型 Graph 可能很昂貴
* **重新播放記憶體**：長重新播放需要大量記憶體來進行狀態快照

### 除錯工作流程

* **從簡單開始**：開始使用基本的逐步執行除錯來了解流程
* **新增斷點**：逐漸在關鍵決策點新增斷點
* **使用重新播放**：利用重新播放進行執行後分析
* **記錄問題**：使用除錯工作階段匯出進行問題報告

## 疑難排解

### 常見問題

**除錯工作階段不暫停**：確保斷點已正確配置且條件已符合。

**效能降低**：限制作用中斷點的數量，並明智地使用條件斷點。

**記憶體問題**：監控執行歷史大小並清除舊的除錯工作階段。

**視覺化錯誤**：檢查 Graph 結構資料是否有效且完整。

### 除錯工作階段恢復

```csharp
// 從已釋放的工作階段復原
if (debugSession.IsDisposed)
{
    // 從現有內容建立新工作階段
    var newSession = executor.CreateDebugSession(context);
    await newSession.StartAsync(DebugExecutionMode.Continue);
}

// 在釋放前匯出工作階段資料
var sessionData = debugSession.ExportSessionData(includeHistory: true);
// 儲存到檔案或資料庫以進行後續分析
```

## 另請參閱

* [Conditional Nodes](../conditional-nodes.md) - 了解條件邏輯和路由
* [State Management](../state.md) - 使用 Graph 狀態和變數
* [Graph Execution](../execution.md) - 了解執行流程和生命週期
* [Examples](../../examples/) - 除錯工作流程的實際範例
