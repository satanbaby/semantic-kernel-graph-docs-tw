# 可視化

可視化讓你能夠生成圖表並匯出圖形結構，供文件和外部工具使用。

## 概念與技術

**圖形可視化**：計算圖結構和執行流程的圖形表示。

**可視化引擎**：負責將內部圖形結構轉換為視覺格式的系統。

**執行疊層**：實時顯示當前狀態和執行歷史的視覺層。

## 匯出格式

### DOT (Graphviz)
* **格式**：用於 Graphviz 的圖形描述語言
* **用途**：生成靜態和互動式圖表
* **優勢**：業界標準、自動版面配置支援
* **範例**：`digraph { A -> B [label="condition"]; }`

### Mermaid
* **格式**：基於文本的圖表語言
* **用途**：與 GitHub、GitLab、Notion 等工具整合
* **優勢**：簡單語法、自動渲染
* **範例**：`graph TD; A-->B; B-->C;`

### JSON
* **格式**：圖形資料的結構化表示
* **用途**：與外部工具和 API 整合
* **優勢**：階層式結構、易於解析
* **範例**：`{"nodes": [...], "edges": [...], "metadata": {...}}`

## 主要元件

### GraphVisualizationEngine
```csharp
// 建立可視化引擎實例。程式庫也提供接受選項的多載，
// 但無參數建構函式足以應付大多數文件範例
// 並鏡像 `examples/GraphVisualizationExample.cs`。
using var engine = new GraphVisualizationEngine();
```

### GraphVisualizationData (從執行時圖形映射)
```csharp
// 從執行時圖形和節點建立輕量級可視化有效負荷
var nodes = new List<IGraphNode> { node1, node2 };
var edges = new List<GraphEdgeInfo> { new GraphEdgeInfo("node1", "node2", "to-node2") };

// GraphVisualizationData 是引擎在範例中使用的結構
var visualizationData = new GraphVisualizationData(nodes, edges, currentNode: node2, executionPath: nodes);
```

## 可視化功能

### 靜態可視化
* **圖形結構**：節點、邊和階層
* **中繼資料**：類型、設定和文件的相關資訊
* **自動版面配置**：元素的自動組織

### 即時可視化
* **執行狀態**：當前節點、執行歷史
* **指標**：執行時間、使用計數器
* **醒目提示**：作用中節點和已遍歷路徑的視覺強調

### 互動式檢查
* **縮放和導覽**：詳細探索特定部分
* **篩選**：按節點類型或狀態的選擇性可視化
* **工具提示**：懸停時的詳細資訊

## 設定和選項

### GraphVisualizationOptions
```csharp
var options = new GraphVisualizationOptions
{
    IncludeMetadata = true,
    ShowExecutionState = true,
    ShowPerformanceMetrics = true,
    ExportFormat = VisualizationFormat.Mermaid,
    Theme = VisualizationTheme.Dark,
    NodeSpacing = 100,
    EdgeRouting = EdgeRoutingType.Orthogonal
};
```

### 可視化佈景主題
* **淺色**：用於列印文件的淺色佈景主題
* **深色**：用於演示和示範的深色佈景主題
* **自訂**：具有特定顏色的自訂佈景主題

## 使用範例

### 基本匯出
```csharp
// 使用引擎，如 `examples/GraphVisualizationExample.cs` 所示
var dot = engine.SerializeToDot(visualizationData, new DotSerializationOptions { GraphName = "VizExample" });
Console.WriteLine(dot);

var mermaid = engine.GenerateEnhancedMermaidDiagram(visualizationData, new MermaidGenerationOptions { Direction = "TD" });
Console.WriteLine(mermaid);

var json = engine.SerializeToJson(visualizationData, new JsonSerializationOptions { Indented = true });
Console.WriteLine(json);
```

### 狀態可視化
```csharp
// 使用執行狀態可視化圖形
var executionState = await executor.GetExecutionStateAsync();
var visualGraph = await visualizer.CreateExecutionVisualizationAsync(graph, executionState);

// 匯出完整可視化
var visualization = await visualizer.ExportAsync(visualGraph, VisualizationFormat.Mermaid);
```

### 執行疊層
```csharp
// 建立即時疊層
var realtimeVisualizer = new GraphRealtimeHighlighter(graph);
realtimeVisualizer.StartHighlighting();

// 更新視覺狀態
await realtimeVisualizer.UpdateExecutionStateAsync(executionState);
```

## 工具整合

### GitHub/GitLab
* **Mermaid**：在 markdown 中自動渲染
* **PlantUML**：透過擴充功能整合
* **Graphviz**：透過 GitHub Actions 渲染

### 文件工具
* **DocFX**：與 API 文件整合
* **MkDocs**：原生 Mermaid 支援
* **Sphinx**：圖表擴充功能

### IDE 和編輯器
* **VS Code**：圖形可視化擴充功能
* **JetBrains**：圖表編製外掛
* **Vim/Emacs**：圖形編輯模式

## 監控和除錯

### 可視化指標
* **渲染時間**：生成可視化的延遲
* **匯出大小**：生成檔案的大小
* **版面配置品質**：視覺組織指標

### 可視化除錯
```csharp
var debugOptions = new GraphVisualizationOptions
{
    EnableDebugMode = true,
    LogVisualizationSteps = true,
    ValidateVisualizationOutput = true
};
```

## 另請參閱

* [即時可視化](../how-to/real-time-visualization-and-highlights.md)
* [可視化範例](../examples/graph-visualization.md)
* [除錯和檢查](../how-to/debug-and-inspection.md)
* [圖形](../concepts/graph-concepts.md)
* [執行](../concepts/execution-model.md)

## 參考資源

* `GraphVisualizationEngine`：主要可視化引擎
* `VisualGraphDefinition`：可視化資料結構
* `GraphVisualizationOptions`：可視化設定
* `GraphRealtimeHighlighter`：即時醒目提示
* `VisualizationFormat`：支援的匯出格式
