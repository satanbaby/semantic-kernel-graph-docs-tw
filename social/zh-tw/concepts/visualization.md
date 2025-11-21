# 可視化

可視化允許您生成圖表並導出 Graph 結構，用於文檔和外部工具。

## 概念和技術

**Graph Visualization**：計算 Graph 的結構和執行流程的圖形表示。

**Visualization Engine**：負責將內部 Graph 結構轉換為視覺格式的系統。

**Execution Overlay**：顯示當前狀態和實時執行歷史的視覺層。

## 導出格式

### DOT (Graphviz)
* **格式**：Graphviz 的 Graph 描述語言
* **用法**：生成靜態和互動圖表
* **優勢**：業界標準、自動佈局支持
* **範例**：`digraph { A -> B [label="condition"]; }`

### Mermaid
* **格式**：基於文本的圖表語言
* **用法**：與 GitHub、GitLab、Notion 等工具集成
* **優勢**：簡單語法、自動渲染
* **範例**：`graph TD; A-->B; B-->C;`

### JSON
* **格式**：Graph 數據的結構化表示
* **用法**：與外部工具和 API 集成
* **優勢**：層級結構、易於解析
* **範例**：`{"nodes": [...], "edges": [...], "metadata": {...}}`

## 主要組件

### GraphVisualizationEngine
```csharp
// Create a visualization engine instance. The library also exposes overloads
// that accept options, but the parameterless constructor is sufficient for
// most doc examples and mirrors `examples/GraphVisualizationExample.cs`.
using var engine = new GraphVisualizationEngine();
```

### GraphVisualizationData (從運行時 Graph 映射)
```csharp
// Build a lightweight visualization payload from the runtime graph and nodes
var nodes = new List<IGraphNode> { node1, node2 };
var edges = new List<GraphEdgeInfo> { new GraphEdgeInfo("node1", "node2", "to-node2") };

// GraphVisualizationData is the structure consumed by the engine in examples
var visualizationData = new GraphVisualizationData(nodes, edges, currentNode: node2, executionPath: nodes);
```

## 可視化功能

### 靜態可視化
* **Graph 結構**：Node、Edge 和層級
* **元數據**：有關類型、配置和文檔的信息
* **自動佈局**：元素的自動組織

### 實時可視化
* **執行狀態**：當前 Node、執行歷史
* **指標**：執行時間、使用計數器
* **突出顯示**：活躍 Node 和已遍歷路徑的視覺強調

### 互動檢查
* **縮放和導航**：詳細探索特定部分
* **篩選器**：按 Node 類型或狀態進行選擇性可視化
* **提示文字**：懸停時的詳細信息

## 配置和選項

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

### 可視化主題
* **Light**：用於印刷文檔的淺色主題
* **Dark**：用於演示和演示的深色主題
* **Custom**：具有特定顏色的自定義主題

## 使用示例

### 基本導出
```csharp
// Using the engine as shown in `examples/GraphVisualizationExample.cs`
var dot = engine.SerializeToDot(visualizationData, new DotSerializationOptions { GraphName = "VizExample" });
Console.WriteLine(dot);

var mermaid = engine.GenerateEnhancedMermaidDiagram(visualizationData, new MermaidGenerationOptions { Direction = "TD" });
Console.WriteLine(mermaid);

var json = engine.SerializeToJson(visualizationData, new JsonSerializationOptions { Indented = true });
Console.WriteLine(json);
```

### 狀態可視化
```csharp
// Visualize graph with execution state
var executionState = await executor.GetExecutionStateAsync();
var visualGraph = await visualizer.CreateExecutionVisualizationAsync(graph, executionState);

// Export complete visualization
var visualization = await visualizer.ExportAsync(visualGraph, VisualizationFormat.Mermaid);
```

### 執行覆蓋
```csharp
// Create real-time overlay
var realtimeVisualizer = new GraphRealtimeHighlighter(graph);
realtimeVisualizer.StartHighlighting();

// Update visual state
await realtimeVisualizer.UpdateExecutionStateAsync(executionState);
```

## 工具集成

### GitHub/GitLab
* **Mermaid**：Markdown 中的自動渲染
* **PlantUML**：通過擴展集成
* **Graphviz**：通過 GitHub Actions 渲染

### 文檔工具
* **DocFX**：與 API 文檔集成
* **MkDocs**：原生 Mermaid 支持
* **Sphinx**：圖表擴展

### IDE 和編輯器
* **VS Code**：Graph 可視化擴展
* **JetBrains**：圖表繪製插件
* **Vim/Emacs**：Graph 編輯模式

## 監控和調試

### 可視化指標
* **渲染時間**：生成可視化的延遲
* **導出大小**：生成文件的大小
* **佈局質量**：視覺組織指標

### 可視化調試
```csharp
var debugOptions = new GraphVisualizationOptions
{
    EnableDebugMode = true,
    LogVisualizationSteps = true,
    ValidateVisualizationOutput = true
};
```

## 參考資料

* [實時可視化](../how-to/real-time-visualization-and-highlights.md)
* [可視化範例](../examples/graph-visualization.md)
* [調試和檢查](../how-to/debug-and-inspection.md)
* [Graph](../concepts/graph-concepts.md)
* [執行](../concepts/execution-model.md)

## 參考資料

* `GraphVisualizationEngine`：主要可視化引擎
* `VisualGraphDefinition`：可視化的數據結構
* `GraphVisualizationOptions`：可視化配置
* `GraphRealtimeHighlighter`：實時突出顯示
* `VisualizationFormat`：支持的導出格式
