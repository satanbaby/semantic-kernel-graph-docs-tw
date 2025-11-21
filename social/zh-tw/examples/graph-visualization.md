# Graph 可視化範例

此範例演示如何使用 Semantic Kernel Graph 的可視化功能來可視化和檢查 Graph 結構。它展示了如何以各種格式匯出 Graph、建立即時可視化，以及實現互動式 Graph 檢查。

## 目標

了解如何在基於 Graph 的工作流程中實現 Graph 可視化和檢查，以便：
* 以多種格式匯出 Graph（DOT、JSON、Mermaid）
* 使用執行亮點建立即時可視化
* 實現互動式 Graph 檢查和偵錯
* 為文件和分析生成視覺呈現
* 使用視覺回饋監視 Graph 執行

## 必要條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中設定
* **Semantic Kernel Graph 套件**已安裝
* 對 [Graph 概念](../concepts/graph-concepts.md) 和 [可視化概念](../concepts/visualization.md) 的基本理解

## 關鍵元件

### 概念和技術

* **Graph Visualization**：將 Graph 結構轉換為視覺呈現
* **Export Formats**：支援多種可視化格式（DOT、JSON、Mermaid）
* **Real-Time Highlights**：在 Graph 執行期間提供視覺回饋
* **Interactive Inspection**：偵錯和分析 Graph 結構
* **Execution Overlays**：執行流程的視覺呈現

### 核心類別

* `GraphVisualizationEngine`：核心可視化引擎
* `GraphRealtimeHighlighter`：即時執行亮點突出
* `GraphInspectionApi`：互動式 Graph 檢查
* `GraphVisualizationOptions`：可視化配置

## 執行範例

### 開始使用

此範例演示了 Semantic Kernel Graph 套件的 Graph 可視化和匯出功能。下面的程式碼片段展示了如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本 Graph 可視化

此範例演示了基本的 Graph 匯出和可視化功能。下面的程式碼片段是一個最小的、自足的範例，與 `semantic-kernel-graph-docs/examples/GraphVisualizationExample.cs` 中的測試範例相同。

```csharp
// 為需要它的 API 建立最小的 kernel 實例。
var kernel = Kernel.CreateBuilder().Build();

// 使用工廠輔助函數建立兩個簡單的函數 Node。
// 這些函數是瑣碎的，並為演示返回靜態字符串。
var fn1 = KernelFunctionFactory.CreateFromMethod(() => "node1-output", "Fn1");
var fn2 = KernelFunctionFactory.CreateFromMethod(() => "node2-output", "Fn2");

var node1 = new FunctionGraphNode(fn1, "node1", "Node 1");
var node2 = new FunctionGraphNode(fn2, "node2", "Node 2");

// 出於演示目的，手動建立可視化資料。
var nodes = new List<IGraphNode> { node1, node2 };
var edges = new List<GraphEdgeInfo> { new GraphEdgeInfo("node1", "node2", "to-node2") };
var visualizationData = new GraphVisualizationData(nodes, edges, currentNode: node2, executionPath: nodes);

// 建立引擎並以多種格式產生輸出。
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

// 注意：此程式碼片段刻意簡化。有關可執行的、完整註解的範例，
// 請參閱儲存庫中的 `semantic-kernel-graph-docs/examples/GraphVisualizationExample.cs`。
```

### 2. 即時執行可視化

此程式碼片段顯示了使用即時亮點突出器的簡化即時可視化流程。目的是演示該模式；可執行的、完整註解的實現可在文件範例專案中取得。

```csharp
// 建立即時亮點突出器（此程式碼片段中對傳輸/記錄器使用 null）。
var highlightOptions = new GraphRealtimeHighlightOptions
{
    EnableImmediateUpdates = false,
    UpdateInterval = TimeSpan.FromMilliseconds(500),
    EnableAnimations = true
};

using var highlighter = new GraphRealtimeHighlighter(null, highlightOptions, logger);

// 為虛假執行 ID 和預先建立的可視化資料啟動亮點突出工作階段。
var executionId = Guid.NewGuid().ToString();
highlighter.StartHighlighting(executionId, visualizationData, new ExecutionHighlightStyle());

// 訂閱幾個事件以觀察進度（處理程式應該是輕量級的）。
highlighter.NodeExecutionStarted += (_, e) => Console.WriteLine($"Node 已啟動：{e.Node.NodeId}");
highlighter.NodeExecutionCompleted += (_, e) => Console.WriteLine($"Node 已完成：{e.Node.NodeId}");

// 模擬進度：在實際系統中，您將呼叫 UpdateCurrentNode/AddNodeCompletionHighlight。
for (var i = 0; i < 3; i++)
{
    // 模擬一些工作和更新
    await Task.Delay(300);
    Console.WriteLine($"模擬迭代 {i + 1}");
}

// 產生亮點突出的匯出
var highlightedMermaid = highlighter.GenerateHighlightedVisualization(executionId, HighlightVisualizationFormat.Mermaid);
var highlightedJson = highlighter.GenerateHighlightedVisualization(executionId, HighlightVisualizationFormat.Json);

// 保存或列印結果
Console.WriteLine("--- 亮點突出的 Mermaid ---");
Console.WriteLine(highlightedMermaid);
Console.WriteLine("--- 亮點突出的 JSON ---");
Console.WriteLine(highlightedJson);

// 完成時停止亮點突出工作階段
highlighter.StopHighlighting(executionId);
```

### 3. 互動式 Graph 檢查

此程式碼片段演示了簡化的互動式檢查模式。在實務中，檢查 API 提供了更豐富的功能；請參閱文件範例以獲得測試實現。

```csharp
// 建立檢查 API 實例（選項是說明性的）。
var inspectionOptions = new GraphInspectionOptions
{
    EnableDetailedNodeInspection = true,
    EnablePerformanceMetrics = true,
    EnableRealtimeMonitoring = true
};

using var inspectionApi = new GraphInspectionApi(inspectionOptions, logger);

// 健康檢查範例
var health = inspectionApi.GetHealthCheck();
Console.WriteLine($"檢查 API 健康狀態：{(health.IsSuccess ? "確定" : "失敗")}");

// 取得作用中的執行（在實際 API 中傳回結果包裝程式）
var active = inspectionApi.GetActiveExecutions();
if (active.IsSuccess)
{
    Console.WriteLine($"取得的作用中執行：{active.Data}");
}

// 檢查給定執行 ID 的 Graph 結構（說明性的）。
var executionId = Guid.NewGuid().ToString();
// var structureJson = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Json);
// Console.WriteLine(structureJson);

// 注意：互動式中斷點和逐步執行最好用
// `semantic-kernel-graph-docs/examples/GraphVisualizationExample.cs` 中的完整範例演示。
```

### 4. 高級可視化功能

演示高級可視化功能，包括自訂樣式和匯出選項。

```csharp
// 建立高級可視化工作流程
var advancedVisualizationWorkflow = new GraphExecutor("AdvancedVisualizationWorkflow", "高級可視化功能", logger);

// 配置高級可視化
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

// 具有自訂樣式的高級處理 Node
var advancedProcessor = new FunctionGraphNode(
    "advanced-processor",
    "具有自訂樣式的高級處理",
    async (context) =>
    {
        var inputData = context.GetValue<string>("input_data");
        var processingType = context.GetValue<string>("processing_type", "standard");
        
        // 根據處理類型套用自訂樣式
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
        
        var processedData = $"高級處理：{inputData}（{processingType}）";
        context.SetValue("processed_data", processedData);
        context.SetValue("processing_step", "advanced_processed");
        
        return processedData;
    });

// 具有自訂匯出的高級可視化工具
var advancedVisualizer = new FunctionGraphNode(
    "advanced-visualizer",
    "具有自訂匯出的高級可視化",
    async (context) =>
    {
        var processedData = context.GetValue<string>("processed_data");
        var processingType = context.GetValue<string>("processing_type");
        var nodeStyle = context.GetValue<string>("node_style");
        
        // 生成自訂可視化
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
        
        // 保存樣式化的匯出
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        File.WriteAllText($"./advanced-exports/styled_{timestamp}.dot", styledDOT);
        File.WriteAllText($"./advanced-exports/styled_{timestamp}.json", styledJSON);
        File.WriteAllText($"./advanced-exports/styled_{timestamp}.mmd", styledMermaid);
        
        return $"高級可視化已完成，具有 {processingType} 樣式";
    });

// 將 Node 新增至高級工作流程
advancedVisualizationWorkflow.AddNode(advancedProcessor);
advancedVisualizationWorkflow.AddNode(advancedVisualizer);

// 設定起始 Node
advancedVisualizationWorkflow.SetStartNode(advancedProcessor.NodeId);

// 測試高級可視化
var advancedTestScenarios = new[]
{
    new { Data = "標準處理", Type = "standard" },
    new { Data = "優先處理", Type = "priority" },
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

    Console.WriteLine($"🎨 測試高級可視化：{scenario.Data}");
    Console.WriteLine($"   處理類型：{scenario.Type}");
    
    var result = await advancedVisualizationWorkflow.ExecuteAsync(kernel, arguments);
    
    var customVisualization = result.GetValue<Dictionary<string, object>>("custom_visualization");
    var nodeStyle = result.GetValue<string>("node_style");
    
    if (customVisualization != null)
    {
        var metadata = customVisualization["processing_metadata"] as dynamic;
        Console.WriteLine($"   Node 樣式：{nodeStyle}");
        Console.WriteLine($"   樣式顏色：{GetStyleColor(nodeStyle)}");
        Console.WriteLine($"   匯出檔案：styled_{DateTime.UtcNow:yyyyMMdd_HHmmss}.*");
    }
    
    Console.WriteLine();
}

// 自訂樣式的輔助方法
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

### 基本 Graph 可視化範例

```
📊 以不同格式匯出 Graph...
   DOT 匯出：1,234 個字元
   JSON 匯出：2,345 個字元
   Mermaid 匯出：1,567 個字元

🧪 測試可視化工作流程：範例資料 1
   處理步驟：output_generated
   最終輸出：最終輸出：轉換：已處理：範例資料 1
```

### 即時執行可視化範例

```
🎬 開始即時可視化...
   可視化將每 500 毫秒更新一次
   匯出將保存到 ./real-time-exports/
   迭代 1：資料：即時處理：即時測試資料（迭代 1），進度：10%
   迭代 2：資料：即時處理：即時測試資料（迭代 2），進度：20%
✅ 即時可視化已完成
```

### 互動式 Graph 檢查範例

```
🔍 測試互動式檢查：正常處理
   檢查模式：normal
   Node 狀態：completed
   斷點命中：False

🔍 測試互動式檢查：斷點處理
   檢查模式：breakpoint
   Node 狀態：completed
   斷點命中：True
   斷點資料：斷點處理
   暫停持續時間：2 秒
```

### 高級可視化範例

```
🎨 測試高級可視化：優先處理
   處理類型：priority
   Node 樣式：priority_style
   樣式顏色：#FF9800
   匯出檔案：styled_20250801_143022.*
```

## 設定選項

### 可視化設定

```csharp
var visualizationOptions = new GraphVisualizationOptions
{
    EnableDOTExport = true,                           // 啟用 DOT 格式匯出
    EnableJSONExport = true,                          // 啟用 JSON 格式匯出
    EnableMermaidExport = true,                       // 啟用 Mermaid 格式匯出
    EnableRealTimeHighlights = true,                  // 啟用即時執行亮點突出
    EnableExecutionOverlays = true,                   // 啟用執行流程覆蓋圖
    EnableInteractiveInspection = true,               // 啟用互動式檢查
    EnableBreakpoints = true,                         // 啟用執行中斷點
    EnableExecutionPause = true,                      // 啟用執行暫停
    EnableStepThrough = true,                         // 啟用逐步執行
    EnableStateInspection = true,                     // 啟用狀態檢查
    EnableNodeInspection = true,                      // 啟用 Node 級別檢查
    EnableCustomStyling = true,                       // 啟用自訂 Node/Edge 樣式
    EnableThemeSupport = true,                        // 啟用佈景主題支援
    EnableExportCompression = true,                   // 啟用匯出壓縮
    EnableLiveUpdates = true,                         // 啟用即時可視化更新
    EnableExecutionTracking = true,                   // 啟用執行路徑追蹤
    EnableNodeStateHighlighting = true,               // 啟用 Node 狀態亮點突出
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

### 即時可視化設定

```csharp
var realTimeOptions = new RealTimeVisualizationOptions
{
    EnableLiveUpdates = true,                         // 啟用即時可視化更新
    UpdateInterval = TimeSpan.FromMilliseconds(500),  // 更新頻率
    EnableExecutionTracking = true,                   // 追蹤執行路徑
    EnableNodeStateHighlighting = true,               // 亮點突出 Node 狀態
    EnableProgressIndicators = true,                  // 顯示執行進度
    EnableTimelineView = true,                        // 顯示執行時間軸
    EnablePerformanceMetrics = true,                  // 顯示效能計量
    MaxHistorySize = 1000,                            // 最大歷史記錄大小
    EnableAutoExport = true,                          // 更新時自動匯出
    ExportOnCompletion = true,                        // 執行完成時匯出
    EnableAnimation = true,                           // 啟用平滑動畫
    AnimationDuration = TimeSpan.FromMilliseconds(300) // 動畫持續時間
};
```

## 疑難排解

### 常見問題

#### 可視化無法運作
```bash
# 問題：Graph 可視化無法運作
# 解決方案：檢查可視化配置並啟用必要的功能
EnableDOTExport = true;
EnableRealTimeHighlights = true;
ExportPath = "./valid-path";
```

#### 匯出失敗
```bash
# 問題：Graph 匯出失敗
# 解決方案：檢查匯出路徑和權限
ExportPath = "./graph-exports";
Directory.CreateDirectory(ExportPath); // 確保目錄存在
```

#### 即時更新無法運作
```bash
# 問題：即時更新無法運作
# 解決方案：啟用即時功能並檢查更新間隔
EnableRealTimeHighlights = true;
EnableLiveUpdates = true;
UpdateInterval = TimeSpan.FromMilliseconds(500);
```

### 偵錯模式

啟用詳細記錄以進行疑難排解：

```csharp
// 啟用偵錯記錄
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<GraphVisualizationExample>();

// 配置具有偵錯記錄的可視化
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

## 高級模式

### 自訂可視化樣式

```csharp
// 實現自訂可視化樣式
public class CustomVisualizationStyle : IVisualizationStyle
{
    public async Task<Dictionary<string, object>> ApplyStyleAsync(GraphNode node, GraphState state)
    {
        var customStyle = new Dictionary<string, object>();
        
        // 根據 Node 類型套用自訂樣式
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
        
        // 套用基於狀態的樣式
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
        customExport.AppendLine("CUSTOM GRAPH EXPORT");
        customExport.AppendLine("==================");
        customExport.AppendLine();
        
        foreach (var node in executor.Nodes)
        {
            customExport.AppendLine($"Node：{node.NodeId}");
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
        Console.WriteLine($"🔴 在 Node 處觸發斷點：{node.NodeId}");
        Console.WriteLine($"   目前狀態：{string.Join(", ", state.Keys)}");
        
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

* [Graph 計量](./graph-metrics.md)：計量收集和監視
* [偵錯和檢查](./debug-inspection.md)：Graph 偵錯技術
* [串流執行](./streaming-execution.md)：即時執行監視
* [效能最佳化](./performance-optimization.md)：使用可視化進行最佳化

## 另請參閱

* [Graph 可視化概念](../concepts/visualization.md)：了解可視化概念
* [偵錯和檢查](../how-to/debug-and-inspection.md)：偵錯和檢查模式
* [效能監視](../how-to/performance-monitoring.md)：效能可視化
* [API 參考](../api/)：完整的 API 文件
