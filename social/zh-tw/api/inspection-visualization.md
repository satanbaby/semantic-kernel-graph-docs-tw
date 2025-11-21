# 檢查與視覺化 API 參考

本參考文檔記錄了 SemanticKernel.Graph 中的檢查與視覺化 API，這些 API 能夠進行即時監控、除錯，以及圖表執行的視覺化表示。

## GraphInspectionApi

用於檢查圖表結構、執行狀態和性能指標的執行時 API。提供用於即時監控、除錯和分析圖表執行的端點。

### 功能

* 即時圖表結構檢查
* 執行狀態監控
* 性能指標存取
* Node 和 Edge 詳細資訊檢索
* 執行路徑追蹤
* 健康檢查與狀態監控
* 自訂查詢功能

### 建構函式

```csharp
public GraphInspectionApi(GraphInspectionOptions? options = null, IGraphLogger? logger = null)
```

### 方法

#### 執行上下文管理

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

#### 即時監控端點

```csharp
public GraphInspectionResponse GetExecutionStatus(string executionId)
public GraphInspectionResponse GetHealthCheck()
```

#### 除錯與分析

```csharp
// Use GetGraphStructure, GetNodeDetails and GetActiveExecutions to retrieve
// detailed structure, node-level information and active execution summaries
// for debugging and analysis workflows via the inspection API.
```

### 屬性

* `IsDisposed`: 取得 API 是否已被釋放
* `ActiveExecutionCount`: 取得目前被監控的主動執行數量

## GraphVisualizationEngine

用於序列化和匯出至多種格式的綜合圖表視覺化引擎。提供用於產生 DOT、JSON、Mermaid 和其他視覺化格式的方法。

### 支援的格式

* **DOT (GraphViz)**: 用於專業圖表視覺化
* **JSON**: 用於 API 使用和資料交換
* **Mermaid**: 用於文檔和網頁型圖表
* **SVG**: 用於靜態影像匯出

### 功能

* 即時執行路徑高亮顯示
* 性能指標整合
* 可自訂的樣式和主題
* 多格式匯出功能

### 建構函式

```csharp
public GraphVisualizationEngine(GraphVisualizationOptions? options = null, IGraphLogger? logger = null)
```

### 方法

#### 圖表結構序列化

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

#### 即時高亮顯示

```csharp
public GraphVisualizationData UpdateRealtimeHighlights(GraphVisualizationData visualizationData, GraphExecutionContext currentExecutionContext)
```

## GraphInspectionOptions

圖表檢查 API 的設定選項。

### 屬性

```csharp
public int MaxActiveExecutions { get; set; } = 100;           // Maximum active executions to monitor
public bool EnableDetailedNodeInspection { get; set; } = true; // Enable detailed node inspection
public bool EnablePerformanceMetrics { get; set; } = true;     // Enable performance metrics collection
public bool EnableRealtimeMonitoring { get; set; } = true;     // Enable real-time monitoring
public bool EnableDebugSessions { get; set; } = true;          // Enable debug session support
public TimeSpan MetricsRetentionPeriod { get; set; } = TimeSpan.FromHours(24); // Metrics retention period
public DateTimeOffset StartTime { get; set; } = DateTimeOffset.UtcNow; // API start time
public bool IncludeDebugInfo { get; set; } = true;             // Include debug information in responses
public bool IncludePerformanceHeatmaps { get; set; } = true;   // Include performance heatmaps
```

## GraphVisualizationOptions

圖表視覺化引擎的設定選項。

### 屬性

```csharp
public VisualizationTheme Theme { get; set; } = VisualizationTheme.Default;  // Default visualization theme
public bool EnableRealtimeUpdates { get; set; } = true;                       // Enable real-time updates
public bool EnableCaching { get; set; } = true;                               // Enable caching
public int MaxCacheSize { get; set; } = 100;                                  // Maximum cache size
public int CacheExpirationMinutes { get; set; } = 30;                         // Cache expiration time
public bool IncludePerformanceMetrics { get; set; } = true;                   // Include performance metrics
public int MaxNodesPerVisualization { get; set; } = 1000;                     // Maximum nodes per visualization
public bool EnableAdvancedStyling { get; set; } = true;                       // Enable advanced styling
```

## 序列化選項

### DotSerializationOptions

特定於 DOT 格式序列化的選項。

```csharp
public string GraphName { get; set; } = "SemanticKernelGraph";  // Graph name in DOT output
public bool EnableClustering { get; set; } = false;             // Enable node clustering
public bool HighlightExecutionPath { get; set; } = true;        // Highlight execution path
public bool HighlightCurrentNode { get; set; } = true;          // Highlight current node
public DotLayoutDirection LayoutDirection { get; set; } = DotLayoutDirection.TopToBottom; // Layout direction
public bool IncludeNodeTypeInfo { get; set; } = true;           // Include node type information
public Dictionary<string, string> CustomNodeStyles { get; set; } = new(); // Custom node styles
public Dictionary<string, string> CustomEdgeStyles { get; set; } = new(); // Custom edge styles
```

### SvgSerializationOptions

特定於 SVG 序列化的選項。

```csharp
public int Width { get; set; } = 960;                          // Canvas width in pixels
public int Height { get; set; } = 540;                          // Canvas height in pixels
public int HorizontalSpacing { get; set; } = 180;               // Horizontal spacing between nodes
public int VerticalSpacing { get; set; } = 120;                 // Vertical spacing between nodes
public bool IncludeMetricsOverlay { get; set; } = true;         // Include metrics overlay
public bool HighlightExecutionPath { get; set; } = true;        // Highlight execution path
public bool HighlightCurrentNode { get; set; } = true;          // Highlight current node
```

### JsonSerializationOptions

特定於 JSON 序列化的選項。

```csharp
public bool Indented { get; set; } = true;                      // Format JSON with indentation
public bool UseCamelCase { get; set; } = true;                  // Use camelCase property naming
public bool IncludeNodeProperties { get; set; } = true;          // Include detailed node properties
public bool IncludeLayoutInfo { get; set; } = true;             // Include layout information
public bool IncludeExecutionMetrics { get; set; } = false;      // Include execution metrics
public bool IncludeTimestamps { get; set; } = true;             // Include timestamp information
public int MaxSerializationDepth { get; set; } = 10;            // Maximum serialization depth
```

### MermaidGenerationOptions

特定於 Mermaid 圖表產生的選項。

```csharp
public string Direction { get; set; } = "TD";                   // Diagram direction (TD, LR, BT, RL)
public bool IncludeTitle { get; set; } = true;                  // Include title in diagram
public bool EnableStyling { get; set; } = true;                 // Enable styling classes
public bool HighlightExecutionPath { get; set; } = true;        // Highlight execution path
public bool HighlightCurrentNode { get; set; } = true;          // Highlight current node
public bool StyleByNodeType { get; set; } = true;               // Style nodes by type
public bool IncludePerformanceIndicators { get; set; } = false; // Include performance indicators
public MermaidTheme Theme { get; set; } = MermaidTheme.Default; // Diagram theme
public Dictionary<string, string> CustomStyles { get; set; } = new(); // Custom CSS styles
```

## InspectionFormat 列舉

支援的檢查回應格式的列舉。

```csharp
public enum InspectionFormat
{
    Json,      // JSON format for API responses
    Dot,       // DOT format for GraphViz visualization
    Mermaid,   // Mermaid format for web-based diagrams
    Xml        // XML format for structured data exchange
}
```

## MetricsExportFormat 列舉

支援的指標匯出格式的列舉。

```csharp
public enum MetricsExportFormat
{
    Json,        // JSON format
    Csv,         // CSV format
    Prometheus   // Prometheus metrics format
}
```

## DotLayoutDirection 列舉

DOT 配置方向的列舉。

```csharp
public enum DotLayoutDirection
{
    TopToBottom,    // Top to bottom layout
    LeftToRight,    // Left to right layout
    BottomToTop,    // Bottom to top layout
    RightToLeft     // Right to left layout
}
```

## VisualizationTheme 列舉

支援的視覺化主題的列舉。

```csharp
public enum VisualizationTheme
{
    Default,    // Default theme with standard colors and styling
    Dark,       // Dark theme optimized for dark backgrounds
    Light,      // Light theme optimized for light backgrounds
    HighContrast // High contrast theme for accessibility
}
```

## MermaidTheme 列舉

Mermaid 圖表主題的列舉。

```csharp
public enum MermaidTheme
{
    Default,    // Default Mermaid theme
    Forest,     // Forest theme with green tones
    Dark,       // Dark theme
    Neutral     // Neutral theme
}
```

## GraphInspectionResponse

代表來自圖表檢查 API 的回應。

### 屬性

```csharp
public bool IsSuccess { get; private set; }                     // Whether the request was successful
public string Data { get; private set; } = string.Empty;        // Response data
public string? ErrorMessage { get; private set; }               // Error message if failed
public object? Metadata { get; private set; }                   // Additional metadata
public DateTimeOffset Timestamp { get; private set; } = DateTimeOffset.UtcNow; // Response timestamp
```

### 靜態工廠方法

```csharp
public static GraphInspectionResponse Success(string data, object? metadata = null)
public static GraphInspectionResponse NotFound(string message)
public static GraphInspectionResponse Error(string message)
```

## GraphVisualizationData

圖表視覺化資訊的資料結構。

### 屬性

```csharp
public IReadOnlyList<IGraphNode> Nodes { get; }                 // Graph nodes
public IReadOnlyList<GraphEdgeInfo> Edges { get; }              // Graph edges
public IGraphNode? CurrentNode { get; }                          // Currently executing node
public IReadOnlyList<IGraphNode> ExecutionPath { get; }         // Execution path
public DateTimeOffset GeneratedAt { get; } = DateTimeOffset.UtcNow; // Generation timestamp
```

### 建構函式

```csharp
public GraphVisualizationData(IReadOnlyList<IGraphNode> nodes, IReadOnlyList<GraphEdgeInfo> edges, IGraphNode? currentNode = null, IReadOnlyList<IGraphNode>? executionPath = null)
```

## GraphEdgeInfo

用於視覺化的圖表 Edge 資訊。

### 屬性

```csharp
public string FromNodeId { get; }                                // Source node ID
public string ToNodeId { get; }                                  // Target node ID
public string? Label { get; }                                    // Edge label
public string? Condition { get; }                                // Conditional expression
public bool IsHighlighted { get; set; }                          // Whether edge is highlighted
```

### 建構函式

```csharp
public GraphEdgeInfo(string fromNodeId, string toNodeId, string? label = null, string? condition = null)
```

## 使用範例

### 基本檢查設定

```csharp
// Create inspection API with options
var inspectionOptions = new GraphInspectionOptions
{
    MaxActiveExecutions = 50,
    EnableDetailedNodeInspection = true,
    EnablePerformanceMetrics = true,
    EnableRealtimeMonitoring = true
};

var inspectionApi = new GraphInspectionApi(inspectionOptions, logger);

// Register an execution for monitoring
inspectionApi.RegisterExecution(executionContext, performanceMetrics);
```

### 圖表結構檢查

```csharp
// Get graph structure in different formats
var jsonStructure = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Json);
var dotStructure = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Dot);
var mermaidStructure = inspectionApi.GetGraphStructure(executionId, InspectionFormat.Mermaid);

if (jsonStructure.IsSuccess)
{
    var graphData = jsonStructure.Data;
    // Process graph structure data
}
```

### 視覺化匯出

```csharp
// Create visualization engine
var visualizationEngine = new GraphVisualizationEngine(logger: logger);

// Export to DOT format
var dotOptions = new DotSerializationOptions
{
    GraphName = "MyGraph",
    HighlightExecutionPath = true,
    HighlightCurrentNode = true,
    LayoutDirection = DotLayoutDirection.TopToBottom
};

var dotOutput = visualizationEngine.SerializeToDot(visualizationData, dotOptions);

// Export to Mermaid
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
// Get performance metrics
var metricsResponse = inspectionApi.GetPerformanceMetrics(executionId, TimeSpan.FromHours(1), MetricsExportFormat.Json);

if (metricsResponse.IsSuccess)
{
    var metricsData = metricsResponse.Data;
    // Process performance metrics
}

// Generate performance heatmap
var heatmapResponse = inspectionApi.GetPerformanceHeatmap(executionId);
if (heatmapResponse.IsSuccess)
{
    var heatmapData = heatmapResponse.Data;
    // Process heatmap data
}
```

### 即時監控

```csharp
// Get current execution status
var statusResponse = inspectionApi.GetExecutionStatus(executionId);
if (statusResponse.IsSuccess)
{
    var statusData = statusResponse.Data;
    // Process real-time status
}

// Get execution health
var healthResponse = inspectionApi.GetExecutionHealth(executionId);
if (healthResponse.IsSuccess)
{
    var healthData = healthResponse.Data;
    // Process health information
}
```

## 另請參閱

* [除錯與檢查指南](../how-to/debug-and-inspection.md) - 如何使用檢查和除錯功能
* [指標與可觀測性指南](../how-to/metrics-and-observability.md) - 性能監控和指標
* [即時視覺化指南](../how-to/real-time-visualization-and-highlights.md) - 即時視覺化功能
* [GraphVisualizationExample](../examples/graph-visualization.md) - 實用視覺化範例
* [Streaming APIs 參考](./streaming.md) - 即時執行監控
* [指標與日誌參考](./metrics-logging.md) - 性能指標和日誌
