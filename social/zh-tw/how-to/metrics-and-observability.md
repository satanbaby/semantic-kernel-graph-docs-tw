# 指標與可觀測性

SemanticKernel.Graph 中的指標與可觀測性提供對圖形執行效能、資源使用情況和操作健康狀況的全面洞察。本指南涵蓋效能指標收集、匯出功能、執行追蹤和監控儀表板。

## 您將學到

* 如何設定和啟用全面的指標收集
* 瞭解節點級別和路徑級別的效能指標
* 將指標匯出到各種監控系統和儀表板
* 設定執行追蹤和相關聯
* 監控系統資源和效能指標
* 生產環境可觀測性的最佳實踐

## 概念與技術

**GraphPerformanceMetrics**：全面的指標收集器，追蹤節點執行時間、成功率、執行路徑和系統資源使用情況。

**NodeExecutionMetrics**：個別節點效能追蹤，包括執行次數、計時百分位數（p50、p95、p99）和成功/失敗率。

**ExecutionPathMetrics**：完整執行路由的分析，包括路徑頻率和效能特性。

**指標匯出器**：為各種監控系統（包括 Prometheus、Grafana 和自訂儀表板）提供專門的匯出功能。

**執行追蹤**：基於 OpenTelemetry 的追蹤，執行跨度與串流事件之間具有相關聯。

**資源監控**：CPU 和記憶體使用情況追蹤，具有可配置的取樣間隔。

## 前提條件

* [首個圖形教學課程](../first-graph-5-minutes.md) 已完成
* 對圖形執行概念的基本理解
* 對指標和監控概念的熟悉
* 已配置 Microsoft.Extensions.Logging（可選但建議）

## 啟用指標收集

### 基本指標設定

在核心級別啟用指標收集：

```csharp
// 建立並設定具有圖形支援和啟用指標的 Kernel。
// 注意：呼叫網路或長時間執行的作業時，使用核心上的非同步方法。
using SemanticKernel.Graph.Extensions;

var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey)
    .AddGraphSupport(options =>
    {
        options.EnableMetrics = true;
        options.EnableLogging = true;
    })
    .Build();
```

### 圖形級指標設定

為特定圖形設定詳細的指標收集：

```csharp
// 建立 GraphExecutor 並設定指標收集。使用開發指標
// 以在偵錯期間進行詳細取樣；使用生產選項以降低額外費用。
using SemanticKernel.Graph.Core;

// 建立啟用指標的圖形
var graph = new GraphExecutor("PerformanceGraph", "High-performance workflow");

// 啟用開發指標（詳細追蹤，頻繁取樣）
graph.EnableDevelopmentMetrics();

// 或使用生產指標（針對效能最佳化）
// graph.EnableProductionMetrics();

// 或自訂指標選項
var customMetricsOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(10),
    MaxSampleHistory = 5000,
    EnableDetailedPathTracking = true,
    EnablePercentileCalculations = true,
    MetricsRetentionPeriod = TimeSpan.FromDays(7)
};

graph.ConfigureMetrics(customMetricsOptions);
```

### 預設設定

使用預先定義的設定來因應常見情境：

```csharp
// 開發環境（詳細追蹤）
var devOptions = GraphMetricsOptions.CreateDevelopmentOptions();
graph.ConfigureMetrics(devOptions);

// 生產環境（效能最佳化）
var prodOptions = GraphMetricsOptions.CreateProductionOptions();
graph.ConfigureMetrics(prodOptions);

// 高效能情境（最少額外費用）
var perfOptions = GraphMetricsOptions.CreatePerformanceOptions();
graph.ConfigureMetrics(perfOptions);
```

## 效能指標收集

### 節點級指標

追蹤個別節點的效能特性：

```csharp
// 取得特定節點的指標
var nodeMetrics = graph.GetNodeMetrics("processing_node");
if (nodeMetrics != null)
{
    Console.WriteLine($"Node: {nodeMetrics.NodeName}");
    Console.WriteLine($"Total Executions: {nodeMetrics.TotalExecutions}");
    Console.WriteLine($"Success Rate: {nodeMetrics.SuccessRate:F1}%");
    Console.WriteLine($"Average Time: {nodeMetrics.AverageExecutionTime.TotalMilliseconds:F2}ms");
    
    // 取得百分位效能
    var p50 = nodeMetrics.GetPercentile(50);
    var p95 = nodeMetrics.GetPercentile(95);
    var p99 = nodeMetrics.GetPercentile(99);
    
    Console.WriteLine($"P50: {p50.TotalMilliseconds:F2}ms");
    Console.WriteLine($"P95: {p95.TotalMilliseconds:F2}ms");
    Console.WriteLine($"P99: {p99.TotalMilliseconds:F2}ms");
    
    // 效能分類
    var rating = nodeMetrics.GetPerformanceClassification();
    Console.WriteLine($"Performance Rating: {rating}");
}
```

### 執行路徑指標

分析透過圖形的完整執行路由：

```csharp
// 取得所有執行路徑指標
var pathMetrics = graph.GetAllPathMetrics();
foreach (var path in pathMetrics.OrderByDescending(p => p.Value.ExecutionCount))
{
    var metrics = path.Value;
    Console.WriteLine($"Path: {metrics.PathKey}");
    Console.WriteLine($"  Executions: {metrics.ExecutionCount}");
    Console.WriteLine($"  Success Rate: {metrics.SuccessRate:F1}%");
    Console.WriteLine($"  Average Time: {metrics.AverageExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"  Path Length: {metrics.PathLength} nodes");
    Console.WriteLine($"  Frequency: {metrics.ExecutionsPerHour:F2}/hour");
    
    // 取得路徑特定的百分位數
    var p95 = metrics.GetPercentile(95);
    Console.WriteLine($"  P95: {p95.TotalMilliseconds:F2}ms");
}
```

### 整體效能摘要

取得全面的效能概觀：

```csharp
// 檢索效能摘要（同步存取器）。此呼叫通常
// 速度快，因為它讀取記憶體中收集的指標；在啟動後
// 指標尚未可用時（例如啟動後立即）防範 null。
// 取得過去一小時的效能摘要
var summary = graph.GetPerformanceSummary(TimeSpan.FromHours(1));
if (summary != null)
{
    Console.WriteLine("📊 PERFORMANCE SUMMARY");
    Console.WriteLine("".PadRight(50, '-'));
    Console.WriteLine($"Total Executions: {summary.TotalExecutions}");
    Console.WriteLine($"Success Rate: {summary.SuccessRate:F1}%");
    Console.WriteLine($"Average Execution Time: {summary.AverageExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"Min/Max Time: {summary.MinExecutionTime.TotalMilliseconds:F2}ms / {summary.MaxExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"Throughput: {summary.Throughput:F2} executions/second");
    Console.WriteLine($"Current CPU Usage: {summary.CurrentCpuUsage:F1}%");
    Console.WriteLine($"Available Memory: {summary.CurrentAvailableMemoryMB:F0} MB");
    
    // 系統健康狀況評估
    var isHealthy = summary.IsHealthy();
    Console.WriteLine($"System Health: {(isHealthy ? "🟢 HEALTHY" : "🔴 NEEDS ATTENTION")}");
    
    if (!isHealthy)
    {
        var alerts = summary.GetPerformanceAlerts();
        Console.WriteLine("Performance Alerts:");
        foreach (var alert in alerts)
        {
            Console.WriteLine($"  - {alert}");
        }
    }
}
```

## 資源監控

### 系統資源追蹤

在圖形執行期間監控 CPU 和記憶體使用情況：

```csharp
// 啟用資源監控
var resourceOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(5)
};

graph.ConfigureMetrics(resourceOptions);

// 存取目前的資源指標
var metrics = graph.GetPerformanceMetrics();
if (metrics != null)
{
    Console.WriteLine($"Current CPU Usage: {metrics.CurrentCpuUsage:F1}%");
    Console.WriteLine($"Available Memory: {metrics.CurrentAvailableMemoryMB:F0} MB");
    Console.WriteLine($"Overall Throughput: {metrics.OverallThroughput:F2} executions/sec");
    Console.WriteLine($"Average Latency: {metrics.AverageExecutionLatency.TotalMilliseconds:F2}ms");
}
```

### 資源取樣設定

設定資源監控行為：

```csharp
var resourceOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(10), // 每 10 秒取樣一次
    MaxSampleHistory = 10000,                           // 保留 10K 個樣本
    MetricsRetentionPeriod = TimeSpan.FromDays(7)       // 保留 7 天
};

graph.ConfigureMetrics(resourceOptions);
```

## 指標匯出與整合

### GraphMetricsExporter

將指標匯出到各種監控系統：

```csharp
using SemanticKernel.Graph.Core;

var exporter = new GraphMetricsExporter(
    new GraphMetricsExportOptions
    {
        IndentedOutput = true,
        UseCamelCase = true,
        IncludePercentileData = true,
        IncludeTrendAnalysis = true,
        IncludeRecommendations = true
    }
);

// 以不同格式匯出
var metrics = graph.GetPerformanceMetrics();
if (metrics != null)
{
    // 用於網頁儀表板的 JSON 格式
    var jsonMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Json);
    
    // 用於監控系統的 Prometheus 格式
    var prometheusMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus);
    
    // 用於試算表分析的 CSV 格式
    var csvMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Csv);
    
    // 用於舊版系統的 XML 格式
    var xmlMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Xml);
}
```

### 儀表板整合

匯出為熱門儀表板格式化的指標：

```csharp
// 匯出至 Grafana
var grafanaMetrics = exporter.ExportForDashboard(metrics, DashboardType.Grafana);

// 匯出至 Chart.js
var chartJsMetrics = exporter.ExportForDashboard(metrics, DashboardType.ChartJs);

// 匯出至自訂儀表板
var customMetrics = exporter.ExportForDashboard(metrics, DashboardType.Custom);
```

### Prometheus 整合

以 Prometheus 格式匯出指標以用於監控系統：

```csharp
// 匯出 Prometheus 指標
var prometheusMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus);

// 範例輸出：
// # HELP graph_node_execution_total Total number of node executions
// # TYPE graph_node_execution_total counter
// graph_node_execution_total{node_id="processing_node",node_name="Processing"} 150
// graph_node_execution_total{node_id="decision_node",node_name="Decision"} 75
// 
// # HELP graph_node_execution_duration_seconds Node execution duration in seconds
// # TYPE graph_node_execution_duration_seconds histogram
// graph_node_execution_duration_seconds_bucket{node_id="processing_node",le="0.1"} 45
// graph_node_execution_duration_seconds_bucket{node_id="processing_node",le="0.5"} 120
// graph_node_execution_duration_seconds_bucket{node_id="processing_node",le="1.0"} 150
```

## 執行追蹤與相關聯

### OpenTelemetry 整合

使用相關聯啟用分散式追蹤：

```csharp
using System.Diagnostics;

// 設定 ActivitySource 進行追蹤
var activitySource = new ActivitySource("SemanticKernel.Graph");

// 在圖形選項中啟用追蹤
var graphOptions = new GraphOptions
{
    EnableMetrics = true,
    EnableLogging = true
};

// GraphExecutor 自動建立追蹤跨度
var graph = new GraphExecutor("TracedGraph", "Graph with tracing enabled");

// 使用自動追蹤執行
using var activity = activitySource.StartActivity("Graph.Execute");
if (activity != null)
{
    activity.SetTag("graph.id", graph.GraphId);
    activity.SetTag("graph.name", graph.Name);
    
    var result = await graph.ExecuteAsync(kernel, arguments);
    
    activity.SetTag("execution.success", true);
    activity.SetTag("execution.result", result.GetValue<string>());
}
```

### 跨度相關聯

將執行跨度與串流事件相關聯：

```csharp
// 使用串流和追蹤執行
var stream = streamingExecutor.ExecuteStreamAsync(kernel, arguments);

await foreach (var evt in stream)
{
    // 每個事件包含相關聯資訊
    Console.WriteLine($"Event: {evt.EventType}");
    Console.WriteLine($"Execution ID: {evt.ExecutionId}");
    Console.WriteLine($"Node ID: {evt.NodeId}");
    Console.WriteLine($"Correlation ID: {evt.CorrelationId}");
    
    // 使用相關聯 ID 與追蹤跨度連結
    if (Activity.Current != null)
    {
        Activity.Current.SetTag("event.correlation_id", evt.CorrelationId);
        Activity.Current.SetTag("event.node_id", evt.NodeId);
    }
}
```

### 自訂追蹤

將自訂追蹤新增到您的圖形節點：

```csharp
public class CustomTracingNode : IGraphNode
{
    public async Task<FunctionResult> ExecuteAsync(Kernel kernel, KernelArguments arguments)
    {
        using var activity = ActivitySource.StartActivity("CustomNode.Execute");
        if (activity != null)
        {
            activity.SetTag("node.type", "CustomTracing");
            activity.SetTag("node.custom_data", "example");
        }
        
        try
        {
            // 節點執行邏輯
            var result = await ProcessDataAsync(arguments);
            
            activity?.SetTag("execution.success", true);
            return result;
        }
        catch (Exception ex)
        {
            activity?.SetTag("execution.success", false);
            activity?.SetTag("exception.type", ex.GetType().Name);
            activity?.SetTag("exception.message", ex.Message);
            throw;
        }
    }
}
```

## 效能分析和最佳化

### 辨識效能瓶頸

分析節點效能以找出瓶頸：

```csharp
// 取得所有節點指標並辨識緩慢的節點
var allNodeMetrics = graph.GetAllNodeMetrics();
var slowNodes = allNodeMetrics
    .Where(n => n.Value.AverageExecutionTime.TotalMilliseconds > 1000) // > 1 秒
    .OrderByDescending(n => n.Value.AverageExecutionTime.TotalMilliseconds);

Console.WriteLine("🐌 SLOW NODES (>1s average)");
foreach (var node in slowNodes)
{
    var metrics = node.Value;
    Console.WriteLine($"Node: {metrics.NodeName}");
    Console.WriteLine($"  Average Time: {metrics.AverageExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"  P95 Time: {metrics.GetPercentile(95).TotalMilliseconds:F2}ms");
    Console.WriteLine($"  Success Rate: {metrics.SuccessRate:F1}%");
    Console.WriteLine($"  Total Executions: {metrics.TotalExecutions}");
}
```

### 路徑效能分析

分析執行路徑效能：

```csharp
// 尋找最常執行的路徑
var frequentPaths = graph.GetAllPathMetrics()
    .OrderByDescending(p => p.Value.ExecutionCount)
    .Take(5);

Console.WriteLine("🛤️ MOST FREQUENT EXECUTION PATHS");
foreach (var path in frequentPaths)
{
    var metrics = path.Value;
    Console.WriteLine($"Path: {metrics.PathKey}");
    Console.WriteLine($"  Frequency: {metrics.ExecutionsPerHour:F2}/hour");
    Console.WriteLine($"  Success Rate: {metrics.SuccessRate:F1}%");
    Console.WriteLine($"  Average Time: {metrics.AverageExecutionTime.TotalMilliseconds:F2}ms");
    
    // 檢查路徑是否存在效能問題
    if (metrics.SuccessRate < 90 || metrics.AverageExecutionTime.TotalMilliseconds > 5000)
    {
        Console.WriteLine("  ⚠️  Performance issues detected!");
    }
}
```

### 趨勢分析

監控一段時間內的效能趨勢：

```csharp
// 取得不同時間視窗的效能摘要
var timeWindows = new[]
{
    TimeSpan.FromMinutes(5),
    TimeSpan.FromMinutes(15),
    TimeSpan.FromHours(1),
    TimeSpan.FromHours(6)
};

Console.WriteLine("📈 PERFORMANCE TRENDS");
foreach (var window in timeWindows)
{
    var summary = graph.GetPerformanceSummary(window);
    if (summary != null)
    {
        Console.WriteLine($"\n{window} Window:");
        Console.WriteLine($"  Executions: {summary.TotalExecutions}");
        Console.WriteLine($"  Success Rate: {summary.SuccessRate:F1}%");
        Console.WriteLine($"  Average Time: {summary.AverageExecutionTime.TotalMilliseconds:F2}ms");
        Console.WriteLine($"  Throughput: {summary.Throughput:F2}/sec");
    }
}
```

## 監控和警示

### 健康檢查

實施自動化的健康監控：

```csharp
public class GraphHealthMonitor
{
    public async Task<HealthReport> CheckHealthAsync(GraphExecutor graph)
    {
        var summary = graph.GetPerformanceSummary(TimeSpan.FromMinutes(5));
        if (summary == null)
        {
            return new HealthReport(HealthStatus.Unhealthy, "No metrics available");
        }
        
        var issues = new List<string>();
        
        // 檢查成功率
        if (summary.SuccessRate < 95)
        {
            issues.Add($"Low success rate: {summary.SuccessRate:F1}%");
        }
        
        // 檢查回應時間
        if (summary.AverageExecutionTime.TotalMilliseconds > 5000)
        {
            issues.Add($"High response time: {summary.AverageExecutionTime.TotalMilliseconds:F0}ms");
        }
        
        // 檢查輸送量
        if (summary.Throughput < 1.0)
        {
            issues.Add($"Low throughput: {summary.Throughput:F2}/sec");
        }
        
        // 檢查系統資源
        if (summary.CurrentCpuUsage > 80)
        {
            issues.Add($"High CPU usage: {summary.CurrentCpuUsage:F1}%");
        }
        
        if (summary.CurrentAvailableMemoryMB < 1000)
        {
            issues.Add($"Low memory: {summary.CurrentAvailableMemoryMB:F0} MB available");
        }
        
        var status = issues.Count == 0 ? HealthStatus.Healthy : HealthStatus.Unhealthy;
        return new HealthReport(status, string.Join("; ", issues));
    }
}

// 使用
var healthMonitor = new GraphHealthMonitor();
var health = await healthMonitor.CheckHealthAsync(graph);

if (health.Status == HealthStatus.Unhealthy)
{
    Console.WriteLine($"🔴 Health Check Failed: {health.Description}");
    // 傳送警示、記錄錯誤等
}
else
{
    Console.WriteLine("🟢 Health Check Passed");
}
```

### 效能警示

設定自動化效能監控：

```csharp
public class PerformanceAlerting
{
    private readonly GraphExecutor _graph;
    private readonly Timer _alertingTimer;
    
    public PerformanceAlerting(GraphExecutor graph)
    {
        _graph = graph;
        _alertingTimer = new Timer(CheckPerformance, null, TimeSpan.Zero, TimeSpan.FromMinutes(1));
    }
    
    private void CheckPerformance(object? state)
    {
        var summary = _graph.GetPerformanceSummary(TimeSpan.FromMinutes(5));
        if (summary == null) return;
        
        var alerts = summary.GetPerformanceAlerts();
        foreach (var alert in alerts)
        {
            Console.WriteLine($"🚨 PERFORMANCE ALERT: {alert}");
            // 傳送通知、記錄警示等
        }
    }
}

// 使用
var alerting = new PerformanceAlerting(graph);
```

## 最佳實踐

### 指標設定

* **開發**：使用 `CreateDevelopmentOptions()` 以進行詳細偵錯
* **生產**：使用 `CreateProductionOptions()` 以進行效能最佳化
* **高輸送量**：使用 `CreatePerformanceOptions()` 以降低額外費用
* **資源監控**：僅在需要時啟用，以避免效能影響

### 效能監控

* **取樣間隔**：平衡準確性與效能（資源 5-30 秒）
* **保留期間**：保留指標足夠長的時間以進行趨勢分析（7-30 天）
* **百分位追蹤**：專注於 p95 和 p99 進行延遲監控
* **路徑分析**：監控執行路徑以尋求最佳化機會

### 匯出和整合

* **Prometheus**：用於 Kubernetes 和雲原生監控
* **Grafana**：匯出儀表板就緒的指標以進行視覺化
* **自訂儀表板**：使用 JSON 匯出進行網頁式監控
* **警示**：為關鍵效能問題設定自動化警示

### 追蹤和相關聯

* **相關聯 ID**：使用穩定的 ID 以連結跨度和事件
* **跨度命名**：使用描述性名稱以改善可觀測性
* **標籤策略**：將商務內容新增到追蹤跨度
* **取樣**：為生產環境設定適當的取樣率

## 疑難排解

### 常見問題

**指標未收集**：確保圖形選項中的 `EnableMetrics` 為 true，且指標已正確設定。

**高記憶體使用量**：減少指標選項中的 `MaxSampleHistory` 和 `MaxPathHistoryPerPath`。

**效能影響**：使用生產最佳化的指標選項，若不需要請停用資源監控。

**匯出失敗**：檢查匯出格式相容性，並確保指標資料可用。

### 效能最佳化

```csharp
// 針對高輸送量情境最佳化指標收集
var optimizedOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = false,        // 不需要時停用
    ResourceSamplingInterval = TimeSpan.FromMinutes(5),
    MaxSampleHistory = 1000,                // 減少樣本歷程
    EnableDetailedPathTracking = false,     // 不需要時停用
    MaxPathHistoryPerPath = 100,            // 減少路徑歷程
    EnablePercentileCalculations = true,    // 保留百分位數
    MetricsRetentionPeriod = TimeSpan.FromHours(2), // 較短的保留
    EnableRealTimeMetrics = false,          // 為了效能停用
    AggregationInterval = TimeSpan.FromMinutes(5)   // 較少頻繁的彙總
};

graph.ConfigureMetrics(optimizedOptions);
```

## 另請參閱

* [偵錯和檢查](debug-and-inspection.md) - 使用指標進行偵錯和分析
* [狀態管理](../concepts/state.md) - 瞭解執行狀態和內容
* [圖形執行](../concepts/execution.md) - 執行生命週期和效能
* [範例](../../examples/) - 指標和監控的實際範例
