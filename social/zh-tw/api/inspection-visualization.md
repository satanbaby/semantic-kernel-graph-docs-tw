# 檢查和可視化 API 參考

本參考文檔說明了 SemanticKernel.Graph 中的檢查和可視化 API，這些 API 可實現圖形執行的實時監控、除錯和視覺表示。

## GraphInspectionApi

用於檢查圖形結構、執行狀態和性能指標的執行時 API。提供用於實時監控、除錯和分析圖形執行的端點。

### 功能

* 實時圖形結構檢查
* 執行狀態監控
* 性能指標存取
* 節點和邊緣詳細資訊檢索
* 執行路徑追蹤
* 健康檢查和狀態監控
* 自定義查詢功能

### 建構函式

```csharp
public GraphInspectionApi(GraphInspectionOptions? options = null, IGraphLogger? logger = null)
```

### 方法

#### 執行環境管理

```csharp
public void RegisterExecution(GraphExecutionContext executionContext, GraphPerformanceMetrics? performanceMetrics = null)
public void UnregisterExecution(string executionId)
public void RegisterDebugSession(IDebugSession debugSession)
```

#### 結構檢查端點

```csharp
public GraphInspectionResponse GetGraphStructure(string executionId, InspectionFormat format = InspectionFormat.Json)
public GraphInspectionResponse GetNodeDetails(string executionId, string nodeId)
public GraphInspectionResponse GetActiveExecutions()
```

#### 性能指標端點

```csharp
public GraphInspectionResponse GetPerformanceMetrics(string executionId, TimeSpan? timeWindow = null, MetricsExportFormat format = MetricsExportFormat.Json)
public GraphInspectionResponse GetPerformanceHeatmap(string executionId)
```

#### 實時監控端點

```csharp
public GraphInspectionResponse GetExecutionStatus(string executionId)
public GraphInspectionResponse GetHealthCheck()
```

#### 除錯和分析

```csharp
// 使用 GetGraphStructure、GetNodeDetails 和 GetActiveExecutions 檢索
// 詳細的結構、節點級別的資訊和活動執行摘要
// 以透過檢查 API 進行除錯和分析工作流。
```

### 屬性

* `IsDisposed`：取得 API 是否已處理
* `ActiveExecutionCount`：取得監控中的活動執行數量

## GraphVisualizationEngine

用於序列化和匯出至多種格式的綜合圖形可視化引擎。提供生成 DOT、JSON、Mermaid 和其他可視化格式的方法。

### 支援的格式

* **DOT (GraphViz)**：用於專業圖形可視化
* **JSON**：用於 API 使用和資料交換
* **Mermaid**：用於文檔和基於網絡的圖表
* **SVG**：用於靜態圖像匯出

### 功能

* 實時執行路徑高亮
* 性能指標整合
* 可自定義的樣式和主題
* 多格式匯出功能

### 建構函式

```csharp
public GraphVisualizationEngine(GraphVisualizationOptions? options = null, IGraphLogger? logger = null)
```

### 方法

#### 圖形結構序列化

```csharp
public string SerializeToDot(GraphVisualizationData visualizationData, DotSerializationOptions? options = null)
public string SerializeToSvg(GraphVisualizationData visualizationData, SvgSerializationOptions? options = null)
public string SerializeToJson(GraphVisualizationData visualizationData, JsonSerializationOptions? options = null)
public string GenerateEnhancedMermaidDiagram(GraphVisualizationData visualizationData, MermaidGenerationOptions? options = null)
```

#### 指標整合

```csharp
public string ExportMetricsForVisualization(GraphPerformanceMetrics performanceMetrics, MetricsExportFormat format = MetricsExportFormat.Json)
public string GeneratePerformanceHeatmap(GraphPerformanceMetrics performanceMetrics, GraphVisualizationData visualizationData)
```

#### 實時高亮

```csharp
public GraphVisualizationData UpdateRealtimeHighlights(GraphVisualizationData visualizationData, GraphExecutionContext currentExecutionContext)
```

## GraphInspectionOptions

圖形檢查 API 的配置選項。

### 屬性

```csharp
public int MaxActiveExecutions { get; set; } = 100;           // 要監控的最大活動執行數
public bool EnableDetailedNodeInspection { get; set; } = true; // 啟用詳細節點檢查
public bool EnablePerformanceMetrics { get; set; } = true;     // 啟用性能指標收集
public bool EnableRealtimeMonitoring { get; set; } = true;     // 啟用實時監控
public bool EnableDebugSessions { get; set; } = true;          // 啟用除錯工作階段支援
public TimeSpan MetricsRetentionPeriod { get; set; } = TimeSpan.FromHours(24); // 指標保留期限
public DateTimeOffset StartTime { get; set; } = DateTimeOffset.UtcNow; // API 啟動時間
public bool IncludeDebugInfo { get; set; } = true;             // 在回應中包含除錯資訊
public bool IncludePerformanceHeatmaps { get; set; } = true;   // 包含性能熱圖
```

## GraphVisualizationOptions

圖形可視化引擎的配置選項。

### 屬性

```csharp
public VisualizationTheme Theme { get; set; } = VisualizationTheme.Default;  // 預設可視化主題
public bool EnableRealtimeUpdates { get; set; } = true;                       // 啟用實時更新
public bool EnableCaching { get; set; } = true;                               // 啟用快取
public int MaxCacheSize { get; set; } = 100;                                  // 最大快取大小
public int CacheExpirationMinutes { get; set; } = 30;                         // 快取過期時間
public bool IncludePerformanceMetrics { get; set; } = true;                   // 包含性能指標
public int MaxNodesPerVisualization { get; set; } = 1000;                     // 每個可視化的最大節點數
public bool EnableAdvancedStyling { get; set; } = true;                       // 啟用進階樣式設定
```

## 序列化選項

### DotSerializationOptions

DOT 格式序列化特定的選項。

```csharp
public string GraphName { get; set; } = "SemanticKernelGraph";  // DOT 輸出中的圖形名稱
public bool EnableClustering { get; set; } = false;             // 啟用節點聚類
public bool HighlightExecutionPath { get; set; } = true;        // 高亮執行路徑
public bool HighlightCurrentNode { get; set; } = true;          // 高亮目前節點
public DotLayoutDirection LayoutDirection { get; set; } = DotLayoutDirection.TopToBottom; // 佈局方向
public bool IncludeNodeTypeInfo { get; set; } = true;           // 包含節點類型資訊
public Dictionary<string, string> CustomNodeStyles { get; set; } = new(); // 自定義節點樣式
public Dictionary<string, string> CustomEdgeStyles { get; set; } = new(); // 自定義邊緣樣式
```

### SvgSerializationOptions

SVG 序列化特定的選項。

```csharp
public int Width { get; set; } = 960;                          // 畫布寬度（像素）
public int Height { get; set; } = 540;                          // 畫布高度（像素）
public int HorizontalSpacing { get; set; } = 180;               // 節點之間的水平間距
public int VerticalSpacing { get; set; } = 120;                 // 節點之間的垂直間距
public bool IncludeMetricsOverlay { get; set; } = true;         // 包含指標覆蓋層
public bool HighlightExecutionPath { get; set; } = true;        // 高亮執行路徑
public bool HighlightCurrentNode { get; set; } = true;          // 高亮目前節點
```

### JsonSerializationOptions

JSON 序列化特定的選項。

```csharp
public bool Indented { get; set; } = true;                      // 用縮進格式化 JSON
public bool UseCamelCase { get; set; } = true;                  // 使用 camelCase 屬性命名
public bool IncludeNodeProperties { get; set; } = true;          // 包含詳細的節點屬性
public bool IncludeLayoutInfo { get; set; } = true;             // 包含佈局資訊
public bool IncludeExecutionMetrics { get; set; } = false;      // 包含執行指標
public bool IncludeTimestamps { get; set; } = true;             // 包含時間戳資訊
public int MaxSerializationDepth { get; set; } = 10;            // 最大序列化深度
```

### MermaidGenerationOptions

Mermaid 圖表生成特定的選項。

```csharp
public string Direction { get; set; } = "TD";                   // 圖表方向（TD、LR、BT、RL）
public bool IncludeTitle { get; set; } = true;                  // 在圖表中包含標題
public bool EnableStyling { get; set; } = true;                 // 啟用樣式類別
public bool HighlightExecutionPath { get; set; } = true;        // 高亮執行路徑
public bool HighlightCurrentNode { get; set; } = true;          // 高亮目前節點
public bool StyleByNodeType { get; set; } = true;               // 按節點類型進行樣式設定
public bool IncludePerformanceIndicators { get; set; } = false; // 包含性能指標
public MermaidTheme Theme { get; set; } = MermaidTheme.Default; // 圖表主題
public Dictionary<string, string> CustomStyles { get; set; } = new(); // 自定義 CSS 樣式
```

## InspectionFormat 列舉

支援的檢查回應格式的列舉。

```csharp
public enum InspectionFormat
{
    Json,      // API 回應的 JSON 格式
    Dot,       // GraphViz 可視化的 DOT 格式
    Mermaid,   // 基於網絡圖表的 Mermaid 格式
    Xml        // 用於結構化資料交換的 XML 格式
}
```

## MetricsExportFormat 列舉

支援的指標匯出格式的列舉。

```csharp
public enum MetricsExportFormat
{
    Json,        // JSON 格式
    Csv,         // CSV 格式
    Prometheus   // Prometheus 指標格式
}
```

## DotLayoutDirection 列舉

DOT 佈局方向的列舉。

```csharp
public enum DotLayoutDirection
{
    TopToBottom,    // 由上至下的佈局
    LeftToRight,    // 由左至右的佈局
    BottomToTop,    // 由下至上的佈局
    RightToLeft     // 由右至左的佈局
}
```

## VisualizationTheme 列舉

支援的可視化主題的列舉。

```csharp
public enum VisualizationTheme
{
    Default,    // 具有標準顏色和樣式的預設主題
    Dark,       // 針對深色背景最佳化的深色主題
    Light,      // 針對淺色背景最佳化的淺色主題
    HighContrast // 用於無障礙的高對比度主題
}
```

## MermaidTheme 列舉

Mermaid 圖表主題的列舉。

```csharp
public enum MermaidTheme
{
    Default,    // 預設 Mermaid 主題
    Forest,     // 綠色調的森林主題
    Dark,       // 深色主題
    Neutral     // 中性主題
}
```

## GraphInspectionResponse

表示來自圖形檢查 API 的回應。

### 屬性

```csharp
public bool IsSuccess { get; private set; }                     // 請求是否成功
public string Data { get; private set; } = string.Empty;        // 回應資料
public string? ErrorMessage { get; private set; }               // 失敗時的錯誤訊息
public object? Metadata { get; private set; }                   // 其他中繼資料
public DateTimeOffset Timestamp { get; private set; } = DateTimeOffset.UtcNow; // 回應時間戳
```

### 靜態工廠方法

```csharp
public static GraphInspectionResponse Success(string data, object? metadata = null)
public static GraphInspectionResponse NotFound(string message)
public static GraphInspectionResponse Error(string message)
```

## GraphVisualizationData

用於圖形可視化資訊的資料結構。

### 屬性

```csharp
public IReadOnlyList<IGraphNode> Nodes { get; }                 // 圖形節點
public IReadOnlyList<GraphEdgeInfo> Edges { get; }              // 圖形邊緣
public IGraphNode? CurrentNode { get; }                          // 目前執行中的節點
public IReadOnlyList<IGraphNode> ExecutionPath { get; }         // 執行路徑
public DateTimeOffset GeneratedAt { get; } = DateTimeOffset.UtcNow; // 生成時間戳
```

### 建構函式

```csharp
public GraphVisualizationData(IReadOnlyList<IGraphNode> nodes, IReadOnlyList<GraphEdgeInfo> edges, IGraphNode? currentNode = null, IReadOnlyList<IGraphNode>? executionPath = null)
```

## GraphEdgeInfo

用於可視化的圖形邊緣資訊。

### 屬性

```csharp
public string FromNodeId { get; }                                // 源節點 ID
public string ToNodeId { get; }                                  // 目標節點 ID
public string? Label { get; }                                    // 邊緣標籤
public string? Condition { get; }                                // 條件運算式
public bool IsHighlighted { get; set; }                          // 邊緣是否已高亮
```

### 建構函式

```csharp
public GraphEdgeInfo(string fromNodeId, string toNodeId, string? label = null, string? condition = null)
```

## 使用示例

### 基本檢查設定

```csharp
// 建立包含選項的檢查 API
var inspectionOptions = new GraphInspectionOptions
{
    MaxActiveExecutions = 50,
    EnableDetailedNodeInspection = true,
    EnablePerformanceMetrics = true,
    EnableRealtimeMonitoring = true
};

var inspectionApi = new GraphInspectionApi(inspectionOptions, logger);

// 註冊執行以進行監控
inspectionApi.RegisterExecution(executionContext, performanceMetrics);
```

### 圖形結構檢查

```csharp
// 獲取不同格式的圖形結構
var jsonStructure = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Json);
var dotStructure = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Dot);
var mermaidStructure = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Mermaid);

if (jsonStructure.IsSuccess)
{
    var graphData = jsonStructure.Data;
    // 處理圖形結構資料
}
```

### 可視化匯出

```csharp
// 建立可視化引擎
var visualizationEngine = new GraphVisualizationEngine(logger: logger);

// 匯出至 DOT 格式
var dotOptions = new DotSerializationOptions
{
    GraphName = "MyGraph",
    HighlightExecutionPath = true,
    HighlightCurrentNode = true,
    LayoutDirection = DotLayoutDirection.TopToBottom
};

var dotOutput = visualizationEngine.SerializeToDot(visualizationData, dotOptions);

// 匯出至 Mermaid
var mermaidOptions = new MermaidGenerationOptions
{
    Direction = "TD",
    EnableStyling = true,
    HighlightExecutionPath = true,
    StyleByNodeType = true
};

var mermaidOutput = visualizationEngine.GenerateEnhancedMermaidDiagram(visualizationData, mermaidOptions);
```

### 性能指標匯出

```csharp
// 獲取性能指標
var metricsResponse = inspectionApi.GetPerformanceMetrics(executionId, TimeSpan.FromHours(1), MetricsExportFormat.Json);

if (metricsResponse.IsSuccess)
{
    var metricsData = metricsResponse.Data;
    // 處理性能指標
}

// 生成性能熱圖
var heatmapResponse = inspectionApi.GetPerformanceHeatmap(executionId);
if (heatmapResponse.IsSuccess)
{
    var heatmapData = heatmapResponse.Data;
    // 處理熱圖資料
}
```

### 實時監控

```csharp
// 獲取目前執行狀態
var statusResponse = inspectionApi.GetExecutionStatus(executionId);
if (statusResponse.IsSuccess)
{
    var statusData = statusResponse.Data;
    // 處理實時狀態
}

// 獲取執行健康狀況
var healthResponse = inspectionApi.GetExecutionHealth(executionId);
if (healthResponse.IsSuccess)
{
    var healthData = healthResponse.Data;
    // 處理健康資訊
}
```

## 另請參閱

* [除錯和檢查指南](../how-to/debug-and-inspection.md) - 如何使用檢查和除錯功能
* [指標和可觀測性指南](../how-to/metrics-and-observability.md) - 性能監控和指標
* [實時可視化指南](../how-to/real-time-visualization-and-highlights.md) - 即時可視化功能
* [GraphVisualizationExample](../examples/graph-visualization.md) - 實用的可視化示例
* [Streaming APIs 參考](./streaming.md) - 實時執行監控
* [指標和日誌參考](./metrics-logging.md) - 性能指標和日誌
