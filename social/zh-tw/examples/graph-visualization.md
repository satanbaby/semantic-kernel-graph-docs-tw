# 圖表視覺化範例

此範例示範如何使用 Semantic Kernel Graph 的視覺化功能來視覺化和檢查圖表結構。它展示如何以各種格式匯出圖表、建立即時視覺化，以及實現互動式圖表檢查。

## 目標

學習如何在基於圖表的工作流中實現圖表視覺化和檢查：
* 以多種格式匯出圖表（DOT、JSON、Mermaid）
* 使用執行突出顯示建立即時視覺化
* 實現互動式圖表檢查和偵錯
* 為文件和分析生成視覺表示
* 使用視覺回饋監控圖表執行

## 前置條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件** 已安裝
* 基本瞭解 [圖表概念](../concepts/graph-concepts.md) 和 [視覺化概念](../concepts/visualization.md)

## 關鍵元件

### 概念和技術

* **圖表視覺化**：將圖表結構轉換為視覺表示
* **匯出格式**：支援多種視覺化格式（DOT、JSON、Mermaid）
* **即時突出顯示**：在圖表執行期間提供視覺回饋
* **互動式檢查**：圖表結構的偵錯和分析
* **執行疊加圖**：執行流程的視覺表示

### 核心類別

* `GraphVisualizationEngine`：核心視覺化引擎
* `GraphRealtimeHighlighter`：即時執行突出顯示
* `GraphInspectionApi`：互動式圖表檢查
* `GraphVisualizationOptions`：視覺化配置

## 執行範例

### 入門

此範例使用 Semantic Kernel Graph 套件示範圖表視覺化和匯出功能。以下代碼片段展示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本圖表視覺化

此範例示範基本的圖表匯出和視覺化功能。以下片段是最小的、獨立的範例，與 `semantic-kernel-graph-docs/examples/GraphVisualizationExample.cs` 中的測試範例相符。

```csharp
// 為需要它的 API 建立最小內核實例。
var kernel = Kernel.CreateBuilder().Build();

// 使用工廠協助程式建立兩個簡單函數節點。
// 這些函數很簡單，為了演示目的返回靜態字符串。
var fn1 = KernelFunctionFactory.CreateFromMethod(() => "node1-output", "Fn1");
var fn2 = KernelFunctionFactory.CreateFromMethod(() => "node2-output", "Fn2");

var node1 = new FunctionGraphNode(fn1, "node1", "Node 1");
var node2 = new FunctionGraphNode(fn2, "node2", "Node 2");

// 為演示目的手動建立視覺化數據。
var nodes = new List<IGraphNode> { node1, node2 };
var edges = new List<GraphEdgeInfo> { new GraphEdgeInfo("node1", "node2", "to-node2") };
var visualizationData = new GraphVisualizationData(nodes, edges, currentNode: node2, executionPath: nodes);

// 建立引擎並以多種格式生成輸出。
using var engine = new GraphVisualizationEngine();

// DOT (Graphviz) 輸出
var dot = engine.SerializeToDot(visualizationData, new DotSerializationOptions { GraphName = "VizExample" });
Console.WriteLine("--- DOT 輸出 ---");
Console.WriteLine(dot);

// Mermaid 輸出
var mermaid = engine.GenerateEnhancedMermaidDiagram(visualizationData, new MermaidGenerationOptions { Direction = "TD" });
Console.WriteLine("--- Mermaid 輸出 ---");
Console.WriteLine(mermaid);

// JSON 輸出（格式化）
var json = engine.SerializeToJson(visualizationData, new JsonSerializationOptions { Indented = true });
Console.WriteLine("--- JSON 輸出 ---");
Console.WriteLine(json);

// 注意：此片段刻意最小化。如需可執行的、詳細註解的範例，
// 請查看存儲庫中 `semantic-kernel-graph-docs/examples/GraphVisualizationExample.cs`。
```

### 2. 即時執行視覺化

此片段展示使用即時突出顯示器的簡化即時視覺化流程。目的是示範該模式；可執行的、詳細註解的實現位於文件範例項目中。

```csharp
// 建立即時突出顯示器（此片段中使用 null 表示可選的傳輸/記錄器）。
var highlightOptions = new GraphRealtimeHighlightOptions
{
    EnableImmediateUpdates = false,
    UpdateInterval = TimeSpan.FromMilliseconds(500),
    EnableAnimations = true
};

using var highlighter = new GraphRealtimeHighlighter(null, highlightOptions, logger);

// 為假執行 ID 和預建的視覺化數據啟動突出顯示會話。
var executionId = Guid.NewGuid().ToString();
highlighter.StartHighlighting(executionId, visualizationData, new ExecutionHighlightStyle());

// 訂閱幾個事件以觀察進度（處理程式應輕量級）。
highlighter.NodeExecutionStarted += (_, e) => Console.WriteLine($"節點已啟動：{e.Node.NodeId}");
highlighter.NodeExecutionCompleted += (_, e) => Console.WriteLine($"節點已完成：{e.Node.NodeId}");

// 模擬進度：在實際系統中，您會調用 UpdateCurrentNode/AddNodeCompletionHighlight。
for (var i = 0; i < 3; i++)
{
    // 模擬一些工作和更新
    await Task.Delay(300);
    Console.WriteLine($"模擬迭代 {i + 1}");
}

// 生成突出顯示的匯出
var highlightedMermaid = highlighter.GenerateHighlightedVisualization(executionId, HighlightVisualizationFormat.Mermaid);
var highlightedJson = highlighter.GenerateHighlightedVisualization(executionId, HighlightVisualizationFormat.Json);

// 持久化或列印結果
Console.WriteLine("--- 突出顯示的 Mermaid ---");
Console.WriteLine(highlightedMermaid);
Console.WriteLine("--- 突出顯示的 JSON ---");
Console.WriteLine(highlightedJson);

// 完成時停止突出顯示會話
highlighter.StopHighlighting(executionId);
```

### 3. 互動式圖表檢查

此片段示範簡化的互動式檢查模式。在實踐中，檢查 API 提供更豐富的功能；有關測試的實現，請查看文件範例。

```csharp
// 建立檢查 API 實例（選項僅用於說明）。
var inspectionOptions = new GraphInspectionOptions
{
    EnableDetailedNodeInspection = true,
    EnablePerformanceMetrics = true,
    EnableRealtimeMonitoring = true
};

using var inspectionApi = new GraphInspectionApi(inspectionOptions, logger);

// 健康檢查範例
var health = inspectionApi.GetHealthCheck();
Console.WriteLine($"檢查 API 健康狀況：{(health.IsSuccess ? "正常" : "失敗")}");

// 取得主動執行（在真實 API 中返回結果包裝器）
var active = inspectionApi.GetActiveExecutions();
if (active.IsSuccess)
{
    Console.WriteLine($"已檢索主動執行：{active.Data}");
}

// 檢查給定執行 ID 的圖表結構（說明性）。
var executionId = Guid.NewGuid().ToString();
// var structureJson = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Json);
// Console.WriteLine(structureJson);

// 注意：互動式中斷點和逐步執行最好用
// 完整範例 `semantic-kernel-graph-docs/examples/GraphVisualizationExample.cs` 來演示。
```

### 4. 進階視覺化功能

演示進階視覺化功能，包括自訂樣式和匯出選項。

```csharp
// 建立進階視覺化工作流
var advancedVisualizationWorkflow = new GraphExecutor("AdvancedVisualizationWorkflow", "進階視覺化功能", logger);

// 配置進階視覺化
var advancedVisualizationOptions = new GraphVisualizationOptions
{
    EnableDOTExport = true,
    EnableJSONExport = true,
    EnableMermaidExport = true,
    EnableRealTimeHighlights = true,
    EnableExecutionOverlays = true,
    EnableCustomStyling = true,
    EnableThemeSupport = true,
    EnableExportCompression = true,
    ExportPath = "./advanced-exports",
    CustomStyles = new Dictionary<string, string>
    {
        ["node_color"] = "#4CAF50",
        ["edge_color"] = "#2196F3",
        ["highlight_color"] = "#FF9800",
        ["error_color"] = "#F44336"
    },
    ExportFormats = new[] { "dot", "json", "mermaid", "svg", "png" }
};

advancedVisualizationWorkflow.ConfigureVisualization(advancedVisualizationOptions);

// 帶有自訂樣式的進階處理節點
var advancedProcessor = new FunctionGraphNode(
    "advanced-processor",
    "具有自訂樣式的進階處理",
    async (context) =>
    {
        var inputData = context.GetValue<string>("input_data");
        var processingType = context.GetValue<string>("processing_type", "standard");
        
        // 根據處理類型應用自訂樣式
        var nodeStyle = processingType switch
        {
            "priority" => "priority_style",
            "error" => "error_style",
            "success" => "success_style",
            _ => "standard_style"
        };
        
        context.SetValue("node_style", nodeStyle);
        context.SetValue("processing_type", processingType);
        
        // 模擬處理
        await Task.Delay(Random.Shared.Next(200, 600));
        
        var processedData = $"進階處理：{inputData}（{processingType}）";
        context.SetValue("processed_data", processedData);
        context.SetValue("processing_step", "advanced_processed");
        
        return processedData;
    });

// 帶有自訂匯出的進階視覺化工具
var advancedVisualizer = new FunctionGraphNode(
    "advanced-visualizer",
    "帶有自訂匯出的進階視覺化",
    async (context) =>
    {
        var processedData = context.GetValue<string>("processed_data");
        var processingType = context.GetValue<string>("processing_type");
        var nodeStyle = context.GetValue<string>("node_style");
        
        // 生成自訂視覺化
        var customVisualization = new Dictionary<string, object>
        {
            ["node_styles"] = new Dictionary<string, object>
            {
                ["advanced-processor"] = new
                {
                    Style = nodeStyle,
                    Color = GetStyleColor(nodeStyle),
                    BorderWidth = GetStyleBorderWidth(nodeStyle),
                    Shape = GetStyleShape(nodeStyle)
                }
            },
            ["processing_metadata"] = new
            {
                Type = processingType,
                Timestamp = DateTime.UtcNow,
                Style = nodeStyle
            }
        };
        
        context.SetValue("custom_visualization", customVisualization);
        
        // 使用自訂樣式匯出
        var styledDOT = await advancedVisualizationWorkflow.ExportToDOTAsync(customVisualization);
        var styledJSON = await advancedVisualizationWorkflow.ExportToJSONAsync(customVisualization);
        var styledMermaid = await advancedVisualizationWorkflow.ExportToMermaidAsync(customVisualization);
        
        // 儲存樣式化匯出
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        File.WriteAllText($"./advanced-exports/styled_{timestamp}.dot", styledDOT);
        File.WriteAllText($"./advanced-exports/styled_{timestamp}.json", styledJSON);
        File.WriteAllText($"./advanced-exports/styled_{timestamp}.mmd", styledMermaid);
        
        return $"完成進階視覺化，使用 {processingType} 樣式";
    });

// 將節點新增到進階工作流
advancedVisualizationWorkflow.AddNode(advancedProcessor);
advancedVisualizationWorkflow.AddNode(advancedVisualizer);

// 設定開始節點
advancedVisualizationWorkflow.SetStartNode(advancedProcessor.NodeId);

// 測試進階視覺化
var advancedTestScenarios = new[]
{
    new { Data = "標準處理", Type = "standard" },
    new { Data = "優先級處理", Type = "priority" },
    new { Data = "成功處理", Type = "success" },
    new { Data = "錯誤處理", Type = "error" }
};

foreach (var scenario in advancedTestScenarios)
{
    var arguments = new KernelArguments
    {
        ["input_data"] = scenario.Data,
        ["processing_type"] = scenario.Type
    };

    Console.WriteLine($"🎨 測試進階視覺化：{scenario.Data}");
    Console.WriteLine($"   處理類型：{scenario.Type}");
    
    var result = await advancedVisualizationWorkflow.ExecuteAsync(kernel, arguments);
    
    var customVisualization = result.GetValue<Dictionary<string, object>>("custom_visualization");
    var nodeStyle = result.GetValue<string>("node_style");
    
    if (customVisualization != null)
    {
        var metadata = customVisualization["processing_metadata"] as dynamic;
        Console.WriteLine($"   節點樣式：{nodeStyle}");
        Console.WriteLine($"   樣式顏色：{GetStyleColor(nodeStyle)}");
        Console.WriteLine($"   匯出文件：styled_{DateTime.UtcNow:yyyyMMdd_HHmmss}.*");
    }
    
    Console.WriteLine();
}

// 自訂樣式的協助程式方法
string GetStyleColor(string style) => style switch
{
    "priority_style" => "#FF9800",
    "error_style" => "#F44336",
    "success_style" => "#4CAF50",
    _ => "#2196F3"
};

int GetStyleBorderWidth(string style) => style switch
{
    "priority_style" => 3,
    "error_style" => 2,
    "success_style" => 2,
    _ => 1
};

string GetStyleShape(string style) => style switch
{
    "priority_style" => "diamond",
    "error_style" => "octagon",
    "success_style" => "ellipse",
    _ => "box"
};
```

## 預期輸出

### 基本圖表視覺化範例

```
📊 以不同格式匯出圖表...
   DOT 匯出：1,234 個字符
   JSON 匯出：2,345 個字符
   Mermaid 匯出：1,567 個字符

🧪 測試視覺化工作流：範例數據 1
   處理步驟：output_generated
   最終輸出：最終輸出：轉換：處理：範例數據 1
```

### 即時執行視覺化範例

```
🎬 啟動即時視覺化...
   視覺化將每 500 毫秒更新一次
   匯出將儲存到 ./real-time-exports/
   迭代 1：數據：即時處理：即時測試數據（迭代 1），進度：10%
   迭代 2：數據：即時處理：即時測試數據（迭代 2），進度：20%
✅ 即時視覺化已完成
```

### 互動式圖表檢查範例

```
🔍 測試互動式檢查：正常處理
   檢查模式：normal
   節點狀態：completed
   中斷點命中：False

🔍 測試互動式檢查：中斷點處理
   檢查模式：breakpoint
   節點狀態：completed
   中斷點命中：True
   中斷點數據：中斷點處理
   暫停時間：2 秒
```

### 進階視覺化範例

```
🎨 測試進階視覺化：優先級處理
   處理類型：priority
   節點樣式：priority_style
   樣式顏色：#FF9800
   匯出文件：styled_20250801_143022.*
```

## 配置選項

### 視覺化配置

```csharp
var visualizationOptions = new GraphVisualizationOptions
{
    EnableDOTExport = true,                           // 啟用 DOT 格式匯出
    EnableJSONExport = true,                          // 啟用 JSON 格式匯出
    EnableMermaidExport = true,                       // 啟用 Mermaid 格式匯出
    EnableRealTimeHighlights = true,                  // 啟用即時執行突出顯示
    EnableExecutionOverlays = true,                   // 啟用執行流程疊加圖
    EnableInteractiveInspection = true,               // 啟用互動式檢查
    EnableBreakpoints = true,                         // 啟用執行中斷點
    EnableExecutionPause = true,                      // 啟用執行暫停
    EnableStepThrough = true,                         // 啟用逐步執行
    EnableStateInspection = true,                     // 啟用狀態檢查
    EnableNodeInspection = true,                      // 啟用節點級別檢查
    EnableCustomStyling = true,                       // 啟用自訂節點/邊樣式
    EnableThemeSupport = true,                        // 啟用主題支援
    EnableExportCompression = true,                   // 啟用匯出壓縮
    EnableLiveUpdates = true,                         // 啟用實況視覺化更新
    EnableExecutionTracking = true,                   // 啟用執行路徑追蹤
    EnableNodeStateHighlighting = true,               // 啟用節點狀態突出顯示
    UpdateInterval = TimeSpan.FromMilliseconds(500),  // 即時更新間隔
    ExportPath = "./graph-exports",                   // 匯出目錄路徑
    ExportFormats = new[] { "dot", "json", "mermaid", "svg", "png" }, // 支援的格式
    CustomStyles = new Dictionary<string, string>     // 自訂樣式選項
    {
        ["node_color"] = "#4CAF50",
        ["edge_color"] = "#2196F3",
        ["highlight_color"] = "#FF9800",
        ["error_color"] = "#F44336"
    }
};
```

### 即時視覺化配置

```csharp
var realTimeOptions = new RealTimeVisualizationOptions
{
    EnableLiveUpdates = true,                         // 啟用實況視覺化更新
    UpdateInterval = TimeSpan.FromMilliseconds(500),  // 更新頻率
    EnableExecutionTracking = true,                   // 追蹤執行路徑
    EnableNodeStateHighlighting = true,               // 突出顯示節點狀態
    EnableProgressIndicators = true,                  // 顯示執行進度
    EnableTimelineView = true,                        // 顯示執行時間軸
    EnablePerformanceMetrics = true,                  // 顯示性能指標
    MaxHistorySize = 1000,                            // 最大歷史記錄大小
    EnableAutoExport = true,                          // 更新時自動匯出
    ExportOnCompletion = true,                        // 執行完成時匯出
    EnableAnimation = true,                           // 啟用平滑動畫
    AnimationDuration = TimeSpan.FromMilliseconds(300) // 動畫持續時間
};
```

## 疑難排解

### 常見問題

#### 視覺化不起作用
```bash
# 問題：圖表視覺化不起作用
# 解決方案：檢查視覺化配置並啟用所需功能
EnableDOTExport = true;
EnableRealTimeHighlights = true;
ExportPath = "./valid-path";
```

#### 匯出失敗
```bash
# 問題：圖表匯出失敗
# 解決方案：檢查匯出路徑和權限
ExportPath = "./graph-exports";
Directory.CreateDirectory(ExportPath); // 確保目錄存在
```

#### 即時更新不起作用
```bash
# 問題：即時更新不起作用
# 解決方案：啟用即時功能並檢查更新間隔
EnableRealTimeHighlights = true;
EnableLiveUpdates = true;
UpdateInterval = TimeSpan.FromMilliseconds(500);
```

### 偵錯模式

啟用詳細日誌記錄以進行疑難排解：

```csharp
// 啟用偵錯日誌記錄
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<GraphVisualizationExample>();

// 使用偵錯日誌記錄配置視覺化
var debugVisualizationOptions = new GraphVisualizationOptions
{
    EnableDOTExport = true,
    EnableJSONExport = true,
    EnableRealTimeHighlights = true,
    EnableDebugLogging = true,
    LogVisualizationUpdates = true,
    LogExportOperations = true
};
```

## 進階模式

### 自訂視覺化樣式

```csharp
// 實現自訂視覺化樣式
public class CustomVisualizationStyle : IVisualizationStyle
{
    public async Task<Dictionary<string, object>> ApplyStyleAsync(GraphNode node, GraphState state)
    {
        var customStyle = new Dictionary<string, object>();
        
        // 根據節點類型應用自訂樣式
        switch (node.NodeType)
        {
            case "FunctionGraphNode":
                customStyle["shape"] = "box";
                customStyle["color"] = "#4CAF50";
                customStyle["style"] = "filled";
                break;
            case "ConditionalGraphNode":
                customStyle["shape"] = "diamond";
                customStyle["color"] = "#2196F3";
                customStyle["style"] = "filled";
                break;
            case "ReActLoopGraphNode":
                customStyle["shape"] = "ellipse";
                customStyle["color"] = "#FF9800";
                customStyle["style"] = "filled";
                break;
        }
        
        // 應用基於狀態的樣式
        if (state.GetValue<bool>("is_error", false))
        {
            customStyle["color"] = "#F44336";
            customStyle["style"] = "filled,diagonals";
        }
        
        return customStyle;
    }
}
```

### 自訂匯出格式

```csharp
// 實現自訂匯出格式
public class CustomExportFormat : IGraphExportFormat
{
    public string FormatName => "custom";
    public string FileExtension => ".custom";
    
    public async Task<string> ExportAsync(GraphExecutor executor, Dictionary<string, object> options = null)
    {
        var customExport = new StringBuilder();
        
        // 生成自訂格式
        customExport.AppendLine("自訂圖表匯出");
        customExport.AppendLine("==================");
        customExport.AppendLine();
        
        foreach (var node in executor.Nodes)
        {
            customExport.AppendLine($"節點：{node.NodeId}");
            customExport.AppendLine($"  類型：{node.NodeType}");
            customExport.AppendLine($"  描述：{node.Description}");
            customExport.AppendLine();
        }
        
        return customExport.ToString();
    }
}
```

### 互動式偵錯

```csharp
// 實現互動式偵錯
public class InteractiveDebugger : IGraphDebugger
{
    private readonly Dictionary<string, Breakpoint> _breakpoints = new();
    
    public async Task<bool> ShouldPauseAsync(GraphNode node, GraphState state)
    {
        if (_breakpoints.TryGetValue(node.NodeId, out var breakpoint))
        {
            return await breakpoint.EvaluateAsync(node, state);
        }
        return false;
    }
    
    public async Task<DebugAction> HandleBreakpointAsync(GraphNode node, GraphState state)
    {
        Console.WriteLine($"🔴 在節點命中中斷點：{node.NodeId}");
        Console.WriteLine($"   當前狀態：{string.Join(", ", state.Keys)}");
        
        Console.WriteLine("偵錯命令：[c]ontinue、[s]tep、[i]nspect、[q]uit");
        var command = Console.ReadLine()?.ToLower();
        
        return command switch
        {
            "c" => DebugAction.Continue,
            "s" => DebugAction.Step,
            "i" => await InspectStateAsync(state),
            "q" => DebugAction.Quit,
            _ => DebugAction.Continue
        };
    }
    
    private async Task<DebugAction> InspectStateAsync(GraphState state)
    {
        Console.WriteLine("📊 狀態檢查：");
        foreach (var kvp in state)
        {
            Console.WriteLine($"   {kvp.Key}：{kvp.Value}");
        }
        return DebugAction.Continue;
    }
}
```

## 相關範例

* [圖表指標](./graph-metrics.md)：指標收集和監控
* [偵錯和檢查](./debug-inspection.md)：圖表偵錯技術
* [串流執行](./streaming-execution.md)：即時執行監控
* [性能最佳化](./performance-optimization.md)：使用視覺化進行最佳化

## 另請參閱

* [圖表視覺化概念](../concepts/visualization.md)：瞭解視覺化概念
* [偵錯和檢查](../how-to/debug-and-inspection.md)：偵錯和檢查模式
* [性能監控](../how-to/performance-monitoring.md)：性能視覺化
* [API 參考](../api/)：完整 API 文件
