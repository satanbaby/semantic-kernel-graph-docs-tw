# 除錯與檢查

SemanticKernel.Graph 中的除錯和檢查功能提供了全面的工具，用於理解、解決問題和分析圖執行。本指南涵蓋除錯工作階段、中斷點、GraphInspectionApi、圖視覺化和執行重播。

## 您將學到的內容

* 如何建立和設置除錯工作階段
* 設置不同類型的中斷點
* 使用 GraphInspectionApi 進行運行時監控
* 以多種格式生成圖視覺化
* 重播執行歷史進行分析
* 複雜工作流程除錯的最佳實踐

## 概念和技術

**除錯工作階段**：受控的執行環境，允許在圖執行過程中進行逐步執行、中斷點管理和狀態檢查。

**中斷點**：暫停在特定節點執行的條件，允許在該點檢查狀態和變數。

**GraphInspectionApi**：運行時 API，用於實時檢查圖結構、執行狀態和效能指標。

**圖視覺化**：導出功能，用於生成 DOT、Mermaid、JSON 和其他格式的圖表，並突出顯示執行路徑。

**執行重播**：能夠逐步重播已完成的執行進行分析和除錯。

## 先決條件

* 已完成[首個圖表教程](../first-graph-5-minutes.md)
* 對圖執行概念的基本理解
* 熟悉狀態管理和條件節點

## 除錯工作階段

### 建立除錯工作階段

除錯工作階段提供逐步執行控制和全面的除錯功能：

```csharp
using SemanticKernel.Graph.Debug;
using SemanticKernel.Graph.Core;

// 建立 GraphExecutor（如果您的情況需要，請關聯 Kernel）
var graphExecutor = new GraphExecutor(kernel);

// 建立執行上下文（kernel + 初始圖狀態）
var graphState = new GraphState(new KernelArguments { ["input"] = "demo" });
var executionContext = new GraphExecutionContext(kernel, graphState);

// 流暢的建構器：設置中斷點和初始模式，然後建立工作階段
var debugSession = await DebugSessionBuilder
    .ForExecution(graphExecutor, executionContext)
    .WithInitialMode(DebugExecutionMode.StepOver)
    .WithBreakpoint("decision_node", "{{user_score}} > 80", "高分數中斷點")
    .WithBreakpoint("error_handler", state => state.GetValue<bool>("has_error"), "錯誤條件")
    .BuildAsync();

// 替代方案（便利）：運行執行並通過幫助器獲得除錯工作階段
var (result, session) = await graphExecutor.ExecuteWithDebugAsync(kernel, arguments, DebugExecutionMode.StepOver);
```

### 除錯執行模式

不同的模式控制在除錯期間執行如何流動：

```csharp
// 逐步跳過：執行當前節點並暫停在下一個
await debugSession.ResumeAsync(DebugExecutionMode.StepOver);

// 逐步進入：如果可用，進入子圖執行
await debugSession.ResumeAsync(DebugExecutionMode.StepInto);

// 逐步退出：繼續直到退出當前上下文
await debugSession.ResumeAsync(DebugExecutionMode.StepOut);

// 繼續：執行到下一個中斷點
await debugSession.ResumeAsync(DebugExecutionMode.Continue);

// 暫停：在當前點停止執行
await debugSession.PauseAsync();
```

### 除錯工作階段控制

管理除錯工作階段的生命週期和執行流：

```csharp
// 啟動工作階段
await debugSession.StartAsync(DebugExecutionMode.StepOver);

// 檢查工作階段狀態
if (debugSession.IsPaused)
{
    var pausedNode = debugSession.PausedAtNode;
    var currentState = debugSession.CurrentState;
    Console.WriteLine($"暫停於：{pausedNode?.Name}");
}

// 逐步執行
await debugSession.StepAsync();

// 恢復執行
await debugSession.ResumeAsync(DebugExecutionMode.Continue);

// 停止工作階段
await debugSession.StopAsync();
```

## 中斷點

### 中斷點類型

SemanticKernel.Graph 支持多種中斷點類型，用於不同的除錯情景：

#### 條件中斷點

當滿足特定條件時中斷：

```csharp
// 基於函數的條件
var breakpointId = debugSession.AddBreakpoint(
    "validation_node",
    state => state.GetValue<int>("attempt_count") > 3,
    "嘗試 3 次後中斷"
);

// 使用樣板的基於表達式的條件
var expressionBreakpoint = debugSession.AddBreakpoint(
    "decision_node",
    "{{user_role}} == 'admin' && {{permission_level}} >= 5",
    "管理員權限檢查"
);
```

#### 數據中斷點

當特定變數改變時暫停執行：

```csharp
// 當 error_count 改變時中斷
var dataBreakpoint = debugSession.AddDataBreakpoint(
    "error_count",
    "監控錯誤計數變化"
);

// 當組中的任何變數改變時中斷
var groupBreakpoint = debugSession.AddDataBreakpoint(
    "user_preferences",
    "監控使用者偏好設置變化"
);
```

#### 自動過期中斷點

被擊中後自動移除自身的中斷點：

```csharp
// 僅在前 3 次中斷
var limitedBreakpoint = debugSession.AddBreakpoint(
    "retry_node",
    "{{retry_count}} > 0",
    3, // 最大擊中計數
    "在前 3 次重試時中斷"
);

// 基於表達式且有擊中限制
var expressionLimited = debugSession.AddBreakpoint(
    "validation_node",
    "{{validation_errors}}.Count > 5",
    2, // 最大擊中計數
    "驗證錯誤超過 5 時中斷"
);
```

### 中斷點管理

在整個除錯工作階段管理中斷點：

```csharp
// 獲取所有活動的中斷點
var breakpoints = debugSession.GetBreakpoints();
foreach (var bp in breakpoints)
{
    Console.WriteLine($"中斷點：{bp.BreakpointId} 在 {bp.NodeId}");
    Console.WriteLine($"描述：{bp.Description}");
    Console.WriteLine($"擊中計數：{bp.HitCount}");
}

// 移除特定中斷點
debugSession.RemoveBreakpoint(breakpointId);

// 清除所有中斷點
debugSession.ClearBreakpoints();
```

## 狀態檢查

### 檢查當前狀態

在除錯期間檢查變數和狀態：

```csharp
// 獲取所有當前變數
var variables = debugSession.GetCurrentVariables();
foreach (var kvp in variables)
{
    Console.WriteLine($"{kvp.Key}：{kvp.Value}");
}

// 獲取具有類型安全性的特定變數
var userName = debugSession.GetVariable<string>("user_name");
var userScore = debugSession.GetVariable<int>("user_score");
var isActive = debugSession.GetVariable<bool>("is_active");

// 在除錯期間設置變數
debugSession.SetVariable("debug_mode", true);
debugSession.SetVariable("test_value", 42);
```

### 執行歷史

追蹤和分析執行步驟：

```csharp
// 獲取完整的執行歷史
var history = debugSession.GetExecutionHistory();
foreach (var step in history)
{
    Console.WriteLine($"步驟：{step.Node.Name} ({step.Node.NodeId})");
    Console.WriteLine($"耗時：{step.Duration.TotalMilliseconds:F2}ms");
    Console.WriteLine($"狀態：{step.Status}");
    
    // 存取執行前後的狀態
    var stateBefore = step.StateBefore;
    var stateAfter = step.StateAfter;
}

// 從當前位置獲取可用的下一個節點
var nextNodes = debugSession.GetAvailableNextNodes();
foreach (var node in nextNodes)
{
    Console.WriteLine($"下一個：{node.Name} ({node.NodeId})");
}
```

## GraphInspectionApi

### 運行時檢查

GraphInspectionApi 提供全面的運行時監控功能：

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

// 獲取圖結構資訊
var structureInfo = inspectionApi.GetGraphStructure(executionId);
Console.WriteLine($"圖：{structureInfo.GraphName}");
Console.WriteLine($"節點：{structureInfo.NodeCount}");
Console.WriteLine($"邊：{structureInfo.EdgeCount}");

// 獲取執行狀態
var status = inspectionApi.GetExecutionStatus(executionId);
Console.WriteLine($"狀態：{status.Status}");
Console.WriteLine($"開始時間：{status.StartTime}");
Console.WriteLine($"耗時：{status.Duration}");
```

### 效能監控

監控執行效能和指標：

```csharp
// 獲取特定節點的效能指標
var nodeMetrics = inspectionApi.GetNodeMetrics(executionId, "processing_node");
if (nodeMetrics != null)
{
    Console.WriteLine($"總執行次數：{nodeMetrics.TotalExecutions}");
    Console.WriteLine($"平均時間：{nodeMetrics.AverageExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"成功率：{nodeMetrics.SuccessRate:P}");
}

// 獲取整體效能摘要
var performanceSummary = inspectionApi.GetPerformanceSummary(executionId);
Console.WriteLine($"總執行時間：{performanceSummary.TotalExecutionTime.TotalMilliseconds:F2}ms");
Console.WriteLine($"平均節點時間：{performanceSummary.AverageNodeExecutionTime.TotalMilliseconds:F2}ms");
Console.WriteLine($"最慢節點：{performanceSummary.SlowestNode?.NodeId}");
```

### 除錯資訊

在執行期間存取除錯特定資訊：

```csharp
// 獲取特定節點的除錯資訊
var debugInfo = inspectionApi.GetNodeDebugInfo(executionId, "decision_node");
if (debugInfo != null)
{
    Console.WriteLine($"有中斷點：{debugInfo.HasBreakpoints}");
    Console.WriteLine($"已暫停：{debugInfo.IsPaused}");
    
    if (debugInfo.Breakpoints != null)
    {
        foreach (var bp in debugInfo.Breakpoints)
        {
            Console.WriteLine($"中斷點：{bp.Description}");
            Console.WriteLine($"擊中計數：{bp.HitCount}");
        }
    }
}
```

## 圖視覺化

### 導出格式

為不同用例生成多種格式的視覺化：

```csharp
using SemanticKernel.Graph.Core;

var visualizationEngine = new GraphVisualizationEngine(
    new GraphVisualizationOptions
    {
        EnableExecutionPathHighlighting = true,
        IncludePerformanceMetrics = true
    }
);

// 生成 GraphViz 的 DOT 格式
var dotOptions = new DotSerializationOptions
{
    GraphName = "我的工作流程",
    LayoutDirection = DotLayoutDirection.LeftToRight,
    EnableClustering = true
};
var dotGraph = visualizationEngine.SerializeToDot(visualizationData, dotOptions);

// 生成 Mermaid 圖表
var mermaidOptions = new MermaidGenerationOptions
{
    Direction = "TB", // 從上到下
    IncludeTitle = true,
    EnableStyling = true,
    HighlightExecutionPath = true
};
var mermaidDiagram = visualizationEngine.GenerateEnhancedMermaidDiagram(
    visualizationData, 
    mermaidOptions
);

// 生成用於 API 使用的 JSON
var jsonOptions = new JsonSerializationOptions
{
    Indented = true,
    UseCamelCase = true,
    IncludeMetadata = true
};
var jsonGraph = visualizationEngine.SerializeToJson(visualizationData, jsonOptions);
```

### 除錯工作階段視覺化

在除錯工作階段期間生成視覺化：

```csharp
// 使用當前狀態突出顯示生成視覺化
var visualization = debugSession.GenerateVisualization(highlightCurrent: true);

// 導出工作階段數據進行分析
var sessionData = debugSession.ExportSessionData(includeHistory: true);

// 為除錯上下文生成 Mermaid 圖表
var debugDiagram = debugSession.GenerateMermaidDiagram(highlightCurrent: true);
Console.WriteLine(debugDiagram);
```

### 實時更新

視覺化可以包含實時執行資訊：

```csharp
// 使用執行路徑建立視覺化數據
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

## 執行重播

### 建立重播

重播已完成的執行進行分析和除錯：

```csharp
// 從除錯工作階段建立重播
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

### 重播控制

控制重播執行和分析：

```csharp
// 啟動重播
await replay.StartAsync();

// 逐步向前進行重播
await replay.StepForwardAsync();
await replay.StepBackwardAsync();

// 跳轉到特定步驟
await replay.JumpToStepAsync(5);

// 獲取當前重播狀態
var currentStep = replay.CurrentStep;
var currentState = replay.CurrentState;
var stepIndex = replay.CurrentStepIndex;

// 檢查重播狀態
if (replay.IsAtEnd)
{
    Console.WriteLine("重播完成");
}
else if (replay.IsAtBeginning)
{
    Console.WriteLine("重播在開始");
}
```

### 假設分析

在重播期間修改變數以測試不同情景：

```csharp
// 修改當前步驟的變數
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

使用條件表達式實現複雜的中斷點邏輯：

```csharp
// 複雜的條件中斷點
var complexBreakpoint = debugSession.AddBreakpoint(
    "workflow_node",
    "{{user_role}} == 'admin' && {{permission_level}} >= 5 && {{session_duration}}.TotalMinutes > 30",
    "具有高權限和長工作階段的管理員"
);

// 帶有狀態比較的中斷點
var stateBreakpoint = debugSession.AddBreakpoint(
    "validation_node",
    state => {
        var errors = state.GetValue<List<string>>("validation_errors") ?? new();
        var warnings = state.GetValue<List<string>>("validation_warnings") ?? new();
        return errors.Count > 5 || warnings.Count > 10;
    },
    "高錯誤/警告計數"
);
```

### 效能除錯

使用專門的中斷點除錯效能問題：

```csharp
// 在執行緩慢時中斷
var performanceBreakpoint = debugSession.AddBreakpoint(
    "slow_node",
    state => {
        var executionTime = state.GetValue<TimeSpan>("node_execution_time");
        return executionTime.TotalMilliseconds > 1000; // 1 秒
    },
    "在執行緩慢時中斷"
);

// 在記憶體使用時中斷
var memoryBreakpoint = debugSession.AddBreakpoint(
    "memory_intensive_node",
    state => {
        var memoryUsage = state.GetValue<long>("memory_usage_bytes");
        return memoryUsage > 100 * 1024 * 1024; // 100 MB
    },
    "在高記憶體使用時中斷"
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
    "在嚴重錯誤時中斷"
);

// 在重試嘗試時中斷
var retryBreakpoint = debugSession.AddBreakpoint(
    "retry_node",
    "{{retry_count}} > {{max_retries}} * 0.8", // 在最大重試的 80% 時中斷
    "在重試限制附近中斷"
);
```

## 最佳實踐

### 除錯工作階段管理

* **工作階段生命週期**：始終處置除錯工作階段以釋放資源
* **模式選擇**：為不同的情景選擇適當的除錯模式
* **中斷點策略**：謹慎使用條件中斷點以避免過度暫停
* **狀態檢查**：在關鍵決策點而不是每個節點檢查狀態

### 效能考量

* **中斷點影響**：每個中斷點為執行增加了開銷
* **歷史大小**：大的執行歷史消耗記憶體
* **視覺化生成**：複雜的視覺化對於大型圖表可能很昂貴
* **重播記憶體**：長重播需要大量記憶體來進行狀態快照

### 除錯工作流程

* **開始簡單**：使用基本的逐步跳過除錯開始以理解流程
* **添加中斷點**：逐步在關鍵決策點添加中斷點
* **使用重播**：利用重播進行執行後分析
* **記錄問題**：使用除錯工作階段導出進行問題報告

## 故障排除

### 常見問題

**除錯工作階段未暫停**：確保中斷點已正確設置且條件得以滿足。

**效能下降**：限制活動中斷點的數量並謹慎使用條件中斷點。

**記憶體問題**：監控執行歷史大小並清除舊的除錯工作階段。

**視覺化錯誤**：檢查圖結構數據是否有效且完整。

### 除錯工作階段恢復

```csharp
// 從已處置的工作階段恢復
if (debugSession.IsDisposed)
{
    // 從現有上下文建立新工作階段
    var newSession = executor.CreateDebugSession(context);
    await newSession.StartAsync(DebugExecutionMode.Continue);
}

// 在處置前導出工作階段數據
var sessionData = debugSession.ExportSessionData(includeHistory: true);
// 保存到文件或數據庫以供稍後分析
```

## 另請參閱

* [條件節點](../conditional-nodes.md) - 理解條件邏輯和路由
* [狀態管理](../state.md) - 使用圖狀態和變數
* [圖執行](../execution.md) - 理解執行流和生命週期
* [示例](../../examples/) - 除錯工作流程的實踐示例
