# 指標和可觀測性

SemanticKernel.Graph 中的指標和可觀測性提供了對圖表執行效能、資源使用情況和操作健康狀況的全面見解。本指南涵蓋效能指標收集、匯出功能、執行追蹤和監控儀表板。

## 你將學到什麼

* 如何配置和啟用全面的指標收集
* 理解 Node 級別和路徑級別的效能指標
* 將指標匯出到各種監控系統和儀表板
* 設置執行追蹤和關聯
* 監控系統資源和效能指標
* 生產可觀測性的最佳實踐

## 概念和技術

**GraphPerformanceMetrics**：全面的指標收集器，追蹤 Node 執行時間、成功率、執行路徑和系統資源使用。

**NodeExecutionMetrics**：單個 Node 效能追蹤，包括執行次數、計時百分位數（p50、p95、p99）以及成功/失敗率。

**ExecutionPathMetrics**：分析整個執行路由通過 Graph，包括路徑頻率和效能特徵。

**Metrics Exporters**：針對各種監控系統（包括 Prometheus、Grafana 和自訂儀表板）的特殊匯出功能。

**Execution Tracing**：基於 OpenTelemetry 的追蹤，具有執行 span 和流式事件之間的關聯。

**Resource Monitoring**：CPU 和記憶體使用情況追蹤，可設定採樣間隔。

## 先決條件

* [First Graph Tutorial](../first-graph-5-minutes.md) 已完成
* 對圖表執行概念的基本理解
* 熟悉指標和監控概念
* Microsoft.Extensions.Logging 已配置（可選但建議）

## 啟用指標收集

### 基本指標配置

在 Kernel 級別啟用指標收集：

```csharp
// Create and configure a Kernel with graph support and metrics enabled.
// Note: when calling network or long-running operations use async methods on the kernel.
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

### 圖表級別的指標配置

為特定圖表配置詳細的指標收集：

```csharp
// Create a GraphExecutor and configure metrics collection. Use development metrics
// for detailed sampling during debugging; use production options to reduce overhead.
using SemanticKernel.Graph.Core;

// Create graph with metrics enabled
var graph = new GraphExecutor("PerformanceGraph", "High-performance workflow");

// Enable development metrics (detailed tracking, frequent sampling)
graph.EnableDevelopmentMetrics();

// Or use production metrics (optimized for performance)
// graph.EnableProductionMetrics();

// Or customize metrics options
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

### 預設配置

使用預定義的配置來實現常見場景：

```csharp
// Development environment (detailed tracking)
var devOptions = GraphMetricsOptions.CreateDevelopmentOptions();
graph.ConfigureMetrics(devOptions);

// Production environment (performance optimized)
var prodOptions = GraphMetricsOptions.CreateProductionOptions();
graph.ConfigureMetrics(prodOptions);

// High-performance scenario (minimal overhead)
var perfOptions = GraphMetricsOptions.CreatePerformanceOptions();
graph.ConfigureMetrics(perfOptions);
```

## 效能指標收集

### Node 級別指標

追蹤單個 Node 的效能特徵：

```csharp
// Get metrics for a specific node
var nodeMetrics = graph.GetNodeMetrics("processing_node");
if (nodeMetrics != null)
{
    Console.WriteLine($"Node: {nodeMetrics.NodeName}");
    Console.WriteLine($"Total Executions: {nodeMetrics.TotalExecutions}");
    Console.WriteLine($"Success Rate: {nodeMetrics.SuccessRate:F1}%");
    Console.WriteLine($"Average Time: {nodeMetrics.AverageExecutionTime.TotalMilliseconds:F2}ms");
    
    // Get percentile performance
    var p50 = nodeMetrics.GetPercentile(50);
    var p95 = nodeMetrics.GetPercentile(95);
    var p99 = nodeMetrics.GetPercentile(99);
    
    Console.WriteLine($"P50: {p50.TotalMilliseconds:F2}ms");
    Console.WriteLine($"P95: {p95.TotalMilliseconds:F2}ms");
    Console.WriteLine($"P99: {p99.TotalMilliseconds:F2}ms");
    
    // Performance classification
    var rating = nodeMetrics.GetPerformanceClassification();
    Console.WriteLine($"Performance Rating: {rating}");
}
```

### 執行路徑指標

分析通過 Graph 的完整執行路由：

```csharp
// Get all execution path metrics
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
    
    // Get path-specific percentiles
    var p95 = metrics.GetPercentile(95);
    Console.WriteLine($"  P95: {p95.TotalMilliseconds:F2}ms");
}
```

### 整體效能摘要

取得全面的效能概觀：

```csharp
// Retrieve a performance summary (synchronous accessor). This call is typically
// fast because it reads in-memory collected metrics; guard against null when
// metrics are not yet available (e.g., immediately after startup).
// Get performance summary for the last hour
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
    
    // System health assessment
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

在圖表執行期間監控 CPU 和記憶體使用：

```csharp
// Enable resource monitoring
var resourceOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(5)
};

graph.ConfigureMetrics(resourceOptions);

// Access current resource metrics
var metrics = graph.GetPerformanceMetrics();
if (metrics != null)
{
    Console.WriteLine($"Current CPU Usage: {metrics.CurrentCpuUsage:F1}%");
    Console.WriteLine($"Available Memory: {metrics.CurrentAvailableMemoryMB:F0} MB");
    Console.WriteLine($"Overall Throughput: {metrics.OverallThroughput:F2} executions/sec");
    Console.WriteLine($"Average Latency: {metrics.AverageExecutionLatency.TotalMilliseconds:F2}ms");
}
```

### 資源採樣配置

配置資源監控行為：

```csharp
var resourceOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(10), // Sample every 10 seconds
    MaxSampleHistory = 10000,                           // Keep 10K samples
    MetricsRetentionPeriod = TimeSpan.FromDays(7)       // Retain for 7 days
};

graph.ConfigureMetrics(resourceOptions);
```

## 指標匯出和整合

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

// Export in different formats
var metrics = graph.GetPerformanceMetrics();
if (metrics != null)
{
    // JSON format for web dashboards
    var jsonMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Json);
    
    // Prometheus format for monitoring systems
    var prometheusMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus);
    
    // CSV format for spreadsheet analysis
    var csvMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Csv);
    
    // XML format for legacy systems
    var xmlMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Xml);
}
```

### 儀表板整合

匯出針對常見儀表板格式化的指標：

```csharp
// Export for Grafana
var grafanaMetrics = exporter.ExportForDashboard(metrics, DashboardType.Grafana);

// Export for Chart.js
var chartJsMetrics = exporter.ExportForDashboard(metrics, DashboardType.ChartJs);

// Export for custom dashboards
var customMetrics = exporter.ExportForDashboard(metrics, DashboardType.Custom);
```

### Prometheus 整合

以 Prometheus 格式匯出指標用於監控系統：

```csharp
// Export Prometheus metrics
var prometheusMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus);

// Example output:
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

## 執行追蹤和關聯

### OpenTelemetry 整合

啟用具有關聯的分佈式追蹤：

```csharp
using System.Diagnostics;

// Configure ActivitySource for tracing
var activitySource = new ActivitySource("SemanticKernel.Graph");

// Enable tracing in graph options
var graphOptions = new GraphOptions
{
    EnableMetrics = true,
    EnableLogging = true
};

// GraphExecutor automatically creates tracing spans
var graph = new GraphExecutor("TracedGraph", "Graph with tracing enabled");

// Execute with automatic tracing
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

### Span 關聯

將執行 span 與流式事件相關聯：

```csharp
// Execute with streaming and tracing
var stream = streamingExecutor.ExecuteStreamAsync(kernel, arguments);

await foreach (var evt in stream)
{
    // Each event includes correlation information
    Console.WriteLine($"Event: {evt.EventType}");
    Console.WriteLine($"Execution ID: {evt.ExecutionId}");
    Console.WriteLine($"Node ID: {evt.NodeId}");
    Console.WriteLine($"Correlation ID: {evt.CorrelationId}");
    
    // Use correlation ID to link with tracing spans
    if (Activity.Current != null)
    {
        Activity.Current.SetTag("event.correlation_id", evt.CorrelationId);
        Activity.Current.SetTag("event.node_id", evt.NodeId);
    }
}
```

### 自訂追蹤

為你的圖表 Node 新增自訂追蹤：

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
            // Node execution logic
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

### 識別效能瓶頸

分析 Node 效能以找到瓶頸：

```csharp
// Get all node metrics and identify slow nodes
var allNodeMetrics = graph.GetAllNodeMetrics();
var slowNodes = allNodeMetrics
    .Where(n => n.Value.AverageExecutionTime.TotalMilliseconds > 1000) // > 1 second
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
// Find the most frequently executed paths
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
    
    // Check if path has performance issues
    if (metrics.SuccessRate < 90 || metrics.AverageExecutionTime.TotalMilliseconds > 5000)
    {
        Console.WriteLine("  ⚠️  Performance issues detected!");
    }
}
```

### 趨勢分析

監控一段時間內的效能趨勢：

```csharp
// Get performance summary for different time windows
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

實現自動化健康監控：

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
        
        // Check success rate
        if (summary.SuccessRate < 95)
        {
            issues.Add($"Low success rate: {summary.SuccessRate:F1}%");
        }
        
        // Check response time
        if (summary.AverageExecutionTime.TotalMilliseconds > 5000)
        {
            issues.Add($"High response time: {summary.AverageExecutionTime.TotalMilliseconds:F0}ms");
        }
        
        // Check throughput
        if (summary.Throughput < 1.0)
        {
            issues.Add($"Low throughput: {summary.Throughput:F2}/sec");
        }
        
        // Check system resources
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

// Usage
var healthMonitor = new GraphHealthMonitor();
var health = await healthMonitor.CheckHealthAsync(graph);

if (health.Status == HealthStatus.Unhealthy)
{
    Console.WriteLine($"🔴 Health Check Failed: {health.Description}");
    // Send alert, log error, etc.
}
else
{
    Console.WriteLine("🟢 Health Check Passed");
}
```

### 效能警示

設置自動化效能監控：

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
            // Send notification, log alert, etc.
        }
    }
}

// Usage
var alerting = new PerformanceAlerting(graph);
```

## 最佳實踐

### 指標配置

* **Development**：使用 `CreateDevelopmentOptions()` 進行詳細的偵錯
* **Production**：使用 `CreateProductionOptions()` 進行效能最佳化
* **High-Throughput**：使用 `CreatePerformanceOptions()` 以最小化開銷
* **Resource Monitoring**：僅在需要時啟用，以避免效能影響

### 效能監控

* **Sampling Intervals**：平衡準確性和效能（資源的 5-30 秒）
* **Retention Periods**：保留指標足夠長以進行趨勢分析（7-30 天）
* **Percentile Tracking**：專注於 p95 和 p99 以進行延遲監控
* **Path Analysis**：監控執行路徑以尋找最佳化機會

### 匯出和整合

* **Prometheus**：用於 Kubernetes 和雲原生監控
* **Grafana**：匯出儀表板就緒的指標以進行視覺化
* **Custom Dashboards**：使用 JSON 匯出進行網頁型監控
* **Alerting**：為關鍵效能問題設置自動化警示

### 追蹤和關聯

* **Correlation IDs**：使用穩定的 ID 來連結 span 和事件
* **Span Naming**：使用描述性名稱以提高可觀測性
* **Tag Strategy**：為追蹤 span 新增業務情境
* **Sampling**：為生產環境配置適當的採樣率

## 疑難排解

### 常見問題

**未收集指標**：確保圖表選項中的 `EnableMetrics` 為 true，且指標已正確配置。

**高記憶體使用量**：在指標選項中減少 `MaxSampleHistory` 和 `MaxPathHistoryPerPath`。

**效能影響**：使用生產最佳化的指標選項，如果不需要，請停用資源監控。

**匯出失敗**：檢查匯出格式相容性，並確保指標資料可用。

### 效能最佳化

```csharp
// Optimize metrics collection for high-throughput scenarios
var optimizedOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = false,        // Disable if not needed
    ResourceSamplingInterval = TimeSpan.FromMinutes(5),
    MaxSampleHistory = 1000,                // Reduce sample history
    EnableDetailedPathTracking = false,     // Disable if not needed
    MaxPathHistoryPerPath = 100,            // Reduce path history
    EnablePercentileCalculations = true,    // Keep percentiles
    MetricsRetentionPeriod = TimeSpan.FromHours(2), // Shorter retention
    EnableRealTimeMetrics = false,          // Disable for performance
    AggregationInterval = TimeSpan.FromMinutes(5)   // Less frequent aggregation
};

graph.ConfigureMetrics(optimizedOptions);
```

## 另請參閱

* [Debug and Inspection](debug-and-inspection.md) - 使用指標進行偵錯和分析
* [State Management](../concepts/state.md) - 理解執行狀態和情境
* [Graph Execution](../concepts/execution.md) - 執行生命週期和效能
* [Examples](../../examples/) - 指標和監控的實際範例
