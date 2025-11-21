# Graph Metrics 範例

此範例演示了如何在 Semantic Kernel Graph 工作流程中收集、監控和分析效能指標。它展示了如何為 Graph 執行實施全面的可觀測性，包括節點層級的指標、執行路徑和效能分析。

## 目標

學習如何在基於 Graph 的工作流程中實施全面的指標和監控，以便：
* 在 Graph 執行期間收集即時效能指標
* 監控節點執行時間、成功率和資源使用狀況
* 分析執行路徑並識別效能瓶頸
* 將指標匯出到各種監控系統和儀表板
* 為生產工作流程實施自訂指標和警示

## 前置條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已配置在 `appsettings.json` 中
* 已安裝 **Semantic Kernel Graph 套件**
* 對 [Graph Concepts](../concepts/graph-concepts.md) 和 [Metrics Concepts](../concepts/metrics.md) 的基本理解

## 主要元件

### 概念和技術

* **Performance Metrics**：執行效能資料的收集和分析
* **Node Monitoring**：個別節點執行的即時監控
* **Execution Path Analysis**：透過 Graph 追蹤和分析執行流
* **Resource Monitoring**：監控 CPU、記憶體和其他資源使用
* **Metrics Export**：將指標匯出到監控系統和儀表板

### 核心類別

* `GraphPerformanceMetrics`：核心指標收集和管理
* `NodeExecutionMetrics`：個別節點效能追蹤
* `MetricsDashboard`：即時指標視覺化和分析
* `GraphMetricsExporter`：將指標匯出到外部系統

## 執行範例

### 入門指南

此範例使用 Semantic Kernel Graph 套件演示了指標收集和效能監控。下列程式碼片段展示了如何在自己的應用程式中實施此模式。

## 逐步實施

### 1. 基本指標收集

此範例演示了在 Graph 執行期間進行基本指標收集。

```csharp
// Create development-friendly metrics options (short intervals for demos)
var options = GraphMetricsOptions.CreateDevelopmentOptions();
options.EnableResourceMonitoring = false; // keep the demo deterministic

// Create the metrics collector using the options
using var metrics = new GraphPerformanceMetrics(options);

// Simulate a few node executions and record metrics for each
for (int i = 0; i < 5; i++)
{
    var execId = $"exec-{i}";

    // Start tracking a node execution
    var tracker = metrics.StartNodeTracking($"node-{i}", $"node-name-{i}", execId);

    // Simulate work
    await Task.Delay(10 + i * 5);

    // Mark completion and record an execution path for analysis
    metrics.CompleteNodeTracking(tracker, success: true, result: null);
    metrics.RecordExecutionPath(execId, new[] { tracker.NodeId }, TimeSpan.FromMilliseconds(10 + i * 5), success: true);
}

// Export a preview using the metrics exporter
using var exporter = new GraphMetricsExporter();
var json = exporter.ExportMetrics(metrics, MetricsExportFormat.Json, TimeSpan.FromMinutes(10));
Console.WriteLine("\n--- JSON Export Preview ---\n");
Console.WriteLine(json.Substring(0, Math.Min(800, json.Length)));

var prometheus = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus, TimeSpan.FromMinutes(10));
Console.WriteLine("\n--- Prometheus Export Preview ---\n");
Console.WriteLine(prometheus.Substring(0, Math.Min(800, prometheus.Length)));
```

### 2. 進階效能監控

演示具有詳細指標收集的全面效能監控。

```csharp
// Create development options and a metrics collector suitable for profiling demos
var options = GraphMetricsOptions.CreateDevelopmentOptions();
using var metrics = new GraphPerformanceMetrics(options);

// Simulate an expensive operation and record detailed timing information
var execId = "advanced-exec-1";
var tracker = metrics.StartNodeTracking("performance-node", "performance-node", execId);
var stopwatch = System.Diagnostics.Stopwatch.StartNew();

// Simulate CPU-bound work with occasional awaits to avoid blocking the thread pool
int iterations = 10_000;
long result = 0;
for (int i = 0; i < iterations; i++)
{
    result += i * i;
    if (i % 1000 == 0) await Task.Delay(1); // cooperative pause to keep responsiveness
}

stopwatch.Stop();
metrics.CompleteNodeTracking(tracker, success: true, result: result);

// Use exporter to inspect metrics after the simulated workload
using var exporter = new GraphMetricsExporter();
Console.WriteLine(exporter.ExportMetrics(metrics, MetricsExportFormat.Json, TimeSpan.FromMinutes(10)));
```

### 3. 即時指標儀表板

展示如何實施即時指標視覺化和監控。

```csharp
// Demonstrate basic real-time sampling using the metrics collector's resource sampling
var options = GraphMetricsOptions.CreateDevelopmentOptions();
options.EnableResourceMonitoring = true;
using var metrics = new GraphPerformanceMetrics(options);

// Simulate a stream of short executions and display sampled CPU/memory
for (int i = 0; i < 10; i++)
{
    var execId = $"rt-{i}";
    var tracker = metrics.StartNodeTracking("data-generator", "data-generator", execId);

    // Simulate some processing latency
    await Task.Delay(Random.Shared.Next(50, 200));

    metrics.CompleteNodeTracking(tracker, success: true);

    // Read current sampled system metrics (collector updates them periodically)
    Console.WriteLine($"Iteration {i + 1}: CPU={metrics.CurrentCpuUsage:F1}% Memory={metrics.CurrentAvailableMemoryMB:F0} MB");

    await Task.Delay(500); // throttle updates for the demo
}

Console.WriteLine("✅ Real-time sampling demo completed");
```

### 4. 指標匯出和整合

演示將指標匯出到外部監控系統和儀表板。

```csharp
// Export example using the metrics exporter directly
using var exporter = new GraphMetricsExporter(new GraphMetricsExportOptions { IndentedOutput = true });

// Export JSON
var jsonExport = exporter.ExportMetrics(metrics, MetricsExportFormat.Json, TimeSpan.FromMinutes(10));
Console.WriteLine("--- JSON Export ---");
Console.WriteLine(jsonExport);

// Export CSV
var csvExport = exporter.ExportMetrics(metrics, MetricsExportFormat.Csv, TimeSpan.FromMinutes(10));
Console.WriteLine("--- CSV Export ---");
Console.WriteLine(csvExport.Split('\n').Take(20)); // preview first lines

// Export Prometheus
var promExport = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus, TimeSpan.FromMinutes(10));
Console.WriteLine("--- Prometheus Export ---");
Console.WriteLine(promExport);
```

## 預期輸出

### 基本指標收集範例

```
📊 Testing metrics collection: Sample data 1
   Processing Time: 234.56 ms
   Input Size: 12 characters
   Metrics Collected: 5 metrics

📊 Testing metrics collection: Sample data 2
   Processing Time: 187.23 ms
   Input Size: 12 characters
   Metrics Collected: 5 metrics
```

### 進階效能監控範例

```
🚀 Testing performance monitoring: Low complexity task
   Complexity Level: 1
   Processing Time: 156.78 ms
   Iterations: 1,000
   Throughput: 6,374 ops/sec
   Performance Score: 85.67
   Bottleneck: CPU-bound

🚀 Testing performance monitoring: High complexity task
   Complexity Level: 10
   Processing Time: 1,234.56 ms
   Iterations: 10,000
   Throughput: 8,101 ops/sec
   Performance Score: 92.34
   Bottleneck: Memory-bound
```

### 即時指標儀表板範例

```
📊 Starting real-time metrics collection...
   Dashboard will update every 500ms
   Press any key to stop...
   Iteration 1: Current: 87.45, Avg: 87.45, Trend: stable
   Iteration 2: Current: 112.34, Avg: 99.90, Trend: increasing
   Iteration 3: Current: 95.67, Avg: 98.49, Trend: decreasing
✅ Real-time metrics collection completed
```

### 指標匯出範例

```
📤 Testing metrics export: 10 executions
   Success Rate: 90.0%
   Average Time: 150.00 ms
   Export Formats: json, csv, prometheus, monitoring

📤 Testing metrics export: 50 executions
   Success Rate: 96.0%
   Average Time: 150.00 ms
   Export Formats: json, csv, prometheus, monitoring
```

## 設定選項

### 指標設定

```csharp
var metricsOptions = new GraphMetricsOptions
{
    EnableNodeMetrics = true,                        // Enable node-level metrics
    EnableExecutionMetrics = true,                   // Enable execution-level metrics
    EnableResourceMetrics = true,                    // Enable resource usage metrics
    EnableCustomMetrics = true,                      // Enable custom metrics
    EnablePerformanceProfiling = true,               // Enable performance profiling
    EnableRealTimeMetrics = true,                    // Enable real-time metrics
    EnableMetricsStreaming = true,                   // Enable metrics streaming
    EnableMetricsDashboard = true,                   // Enable metrics dashboard
    EnableMetricsExport = true,                      // Enable metrics export
    EnableMetricsPersistence = true,                 // Enable metrics persistence
    MetricsCollectionInterval = TimeSpan.FromMilliseconds(100), // Collection interval
    DashboardUpdateInterval = TimeSpan.FromMilliseconds(500),   // Dashboard update interval
    ExportInterval = TimeSpan.FromSeconds(5),        // Export interval
    MetricsStoragePath = "./metrics-data",           // Metrics storage path
    ExportFormats = new[] { "json", "csv", "prometheus" },     // Export formats
    EnableMetricsCompression = true,                 // Enable metrics compression
    MaxMetricsHistory = 10000,                       // Maximum metrics history
    EnableMetricsAggregation = true,                 // Enable metrics aggregation
    AggregationInterval = TimeSpan.FromMinutes(1)    // Aggregation interval
};
```

### 效能分析設定

```csharp
var profilingOptions = new PerformanceProfilingOptions
{
    EnableDetailedProfiling = true,                  // Enable detailed profiling
    EnableMemoryProfiling = true,                    // Enable memory profiling
    EnableCpuProfiling = true,                       // Enable CPU profiling
    EnableNetworkProfiling = true,                   // Enable network profiling
    ProfilingSamplingRate = 0.1,                     // Profiling sampling rate (10%)
    EnableHotPathAnalysis = true,                    // Enable hot path analysis
    EnableBottleneckDetection = true,                // Enable bottleneck detection
    ProfilingOutputPath = "./profiling-data",         // Profiling output path
    EnableProfilingVisualization = true,             // Enable profiling visualization
    MaxProfilingDataSize = 100 * 1024 * 1024        // Max profiling data size (100MB)
};
```

## 疑難排解

### 常見問題

#### 未收集指標
```bash
# Problem: Metrics are not being collected
# Solution: Enable metrics collection and check configuration
EnableNodeMetrics = true;
EnableExecutionMetrics = true;
MetricsCollectionInterval = TimeSpan.FromMilliseconds(100);
```

#### 效能影響
```bash
# Problem: Metrics collection impacts performance
# Solution: Adjust collection interval and enable sampling
MetricsCollectionInterval = TimeSpan.FromSeconds(1);
EnableMetricsSampling = true;
SamplingRate = 0.1; // 10% sampling
```

#### 記憶體問題
```bash
# Problem: Metrics consume too much memory
# Solution: Enable compression and limit history
EnableMetricsCompression = true;
MaxMetricsHistory = 1000;
EnableMetricsAggregation = true;
```

### 除錯模式

啟用詳細日誌以進行疑難排解：

```csharp
// Enable debug logging
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<GraphMetricsExample>();

// Configure metrics with debug logging
var debugMetricsOptions = new GraphMetricsOptions
{
    EnableNodeMetrics = true,
    EnableExecutionMetrics = true,
    EnableResourceMetrics = true,
    EnableDebugLogging = true,
    LogMetricsCollection = true,
    LogMetricsExport = true
};
```

## 進階模式

### 自訂指標收集

```csharp
// Implement custom metrics collection
public class CustomMetricsCollector : IMetricsCollector
{
    public async Task<Dictionary<string, object>> CollectMetricsAsync(MetricsContext context)
    {
        var customMetrics = new Dictionary<string, object>();
        
        // Collect custom business metrics
        customMetrics["business_value"] = await CalculateBusinessValue(context);
        customMetrics["user_satisfaction"] = await MeasureUserSatisfaction(context);
        customMetrics["cost_per_execution"] = await CalculateCostPerExecution(context);
        
        // Collect domain-specific metrics
        customMetrics["domain_accuracy"] = await MeasureDomainAccuracy(context);
        customMetrics["processing_efficiency"] = await MeasureProcessingEfficiency(context);
        
        return customMetrics;
    }
}
```

### 指標彙總和分析

```csharp
// Implement custom metrics aggregation
public class MetricsAggregator : IMetricsAggregator
{
    public async Task<AggregatedMetrics> AggregateMetricsAsync(IEnumerable<MetricsSnapshot> snapshots)
    {
        var aggregated = new AggregatedMetrics();
        
        foreach (var snapshot in snapshots)
        {
            // Aggregate performance metrics
            aggregated.TotalExecutions += snapshot.ExecutionCount;
            aggregated.TotalProcessingTime += snapshot.TotalProcessingTime;
            aggregated.SuccessCount += snapshot.SuccessCount;
            aggregated.ErrorCount += snapshot.ErrorCount;
            
            // Track trends
            aggregated.ExecutionTrends.Add(snapshot.Timestamp, snapshot.ExecutionCount);
            aggregated.PerformanceTrends.Add(snapshot.Timestamp, snapshot.AverageProcessingTime);
        }
        
        // Calculate derived metrics
        aggregated.SuccessRate = (double)aggregated.SuccessCount / aggregated.TotalExecutions;
        aggregated.AverageProcessingTime = aggregated.TotalProcessingTime / aggregated.TotalExecutions;
        aggregated.ErrorRate = (double)aggregated.ErrorCount / aggregated.TotalExecutions;
        
        return aggregated;
    }
}
```

### 即時警示

```csharp
// Implement real-time metrics alerting
public class MetricsAlerting : IMetricsAlerting
{
    private readonly List<AlertRule> _alertRules;
    
    public async Task<List<Alert>> CheckAlertsAsync(MetricsSnapshot metrics)
    {
        var alerts = new List<Alert>();
        
        foreach (var rule in _alertRules)
        {
            if (await rule.EvaluateAsync(metrics))
            {
                alerts.Add(new Alert
                {
                    RuleId = rule.RuleId,
                    Severity = rule.Severity,
                    Message = rule.GenerateMessage(metrics),
                    Timestamp = DateTime.UtcNow,
                    Metrics = metrics
                });
            }
        }
        
        return alerts;
    }
}

// Example alert rules
public class AlertRule
{
    public string RuleId { get; set; }
    public AlertSeverity Severity { get; set; }
    public Func<MetricsSnapshot, Task<bool>> Condition { get; set; }
    
    public static AlertRule CreateHighErrorRateRule()
    {
        return new AlertRule
        {
            RuleId = "high_error_rate",
            Severity = AlertSeverity.Critical,
            Condition = async (metrics) => metrics.ErrorRate > 0.1 // 10% error rate
        };
    }
}
```

## 相關範例

* [Graph Visualization](./graph-visualization.md)：視覺化指標表示
* [Performance Optimization](./performance-optimization.md)：使用指標進行最佳化
* [Streaming Execution](./streaming-execution.md)：即時指標串流
* [Debug and Inspection](./debug-inspection.md)：用於除錯的指標

## 另請參閱

* [Metrics and Observability](../concepts/metrics.md)：瞭解指標概念
* [Performance Monitoring](../how-to/performance-monitoring.md)：效能監控模式
* [Debug and Inspection](../how-to/debug-and-inspection.md)：使用指標進行除錯
* [API Reference](../api/)：完整 API 文件
