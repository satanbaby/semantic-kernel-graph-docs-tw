# 圖形指標範例

本範例展示如何在語義核心圖形工作流中收集、監控和分析效能指標。它說明如何為圖形執行實施全面的可觀測性，包括節點級指標、執行路徑和效能分析。

## 目標

學習如何在基於圖形的工作流中實施全面的指標和監控，以便：
* 在圖形執行期間收集即時效能指標
* 監控節點執行時間、成功率和資源使用
* 分析執行路徑並識別效能瓶頸
* 將指標匯出到各種監控系統和儀表板
* 為生產工作流實施自訂指標和告警

## 先決條件

* **.NET 8.0** 或更高版本
* **OpenAI API 密鑰**配置在 `appsettings.json`
* **語義核心圖形套件**已安裝
* 基本了解[圖形概念](../concepts/graph-concepts.md)和[指標概念](../concepts/metrics.md)

## 主要元件

### 概念和技術

* **效能指標**：執行效能資料的收集和分析
* **節點監控**：個別節點執行的即時監控
* **執行路徑分析**：追蹤和分析透過圖形的執行流程
* **資源監控**：監控 CPU、記憶體和其他資源使用
* **指標匯出**：將指標匯出到監控系統和儀表板

### 核心類別

* `GraphPerformanceMetrics`：核心指標收集和管理
* `NodeExecutionMetrics`：個別節點效能追蹤
* `MetricsDashboard`：即時指標視覺化和分析
* `GraphMetricsExporter`：將指標匯出到外部系統

## 執行範例

### 開始使用

此範例展示使用語義核心圖形套件的指標收集和效能監控。下面的程式碼片段說明如何在自己的應用程式中實施此模式。

## 逐步實施

### 1. 基本指標收集

此範例展示圖形執行期間的基本指標收集。

```csharp
// 建立開發友善的指標選項（示範用短間隔）
var options = GraphMetricsOptions.CreateDevelopmentOptions();
options.EnableResourceMonitoring = false; // 保持示範確定性

// 使用選項建立指標收集器
using var metrics = new GraphPerformanceMetrics(options);

// 模擬幾個節點執行並為每個記錄指標
for (int i = 0; i < 5; i++)
{
    var execId = $"exec-{i}";

    // 開始追蹤節點執行
    var tracker = metrics.StartNodeTracking($"node-{i}", $"node-name-{i}", execId);

    // 模擬工作
    await Task.Delay(10 + i * 5);

    // 標記完成並記錄執行路徑以供分析
    metrics.CompleteNodeTracking(tracker, success: true, result: null);
    metrics.RecordExecutionPath(execId, new[] { tracker.NodeId }, TimeSpan.FromMilliseconds(10 + i * 5), success: true);
}

// 使用指標匯出器匯出預覽
using var exporter = new GraphMetricsExporter();
var json = exporter.ExportMetrics(metrics, MetricsExportFormat.Json, TimeSpan.FromMinutes(10));
Console.WriteLine("\n--- JSON 匯出預覽 ---\n");
Console.WriteLine(json.Substring(0, Math.Min(800, json.Length)));

var prometheus = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus, TimeSpan.FromMinutes(10));
Console.WriteLine("\n--- Prometheus 匯出預覽 ---\n");
Console.WriteLine(prometheus.Substring(0, Math.Min(800, prometheus.Length)));
```

### 2. 進階效能監控

展示具有詳細指標收集的全面效能監控。

```csharp
// 建立開發選項和適合進行分析示範的指標收集器
var options = GraphMetricsOptions.CreateDevelopmentOptions();
using var metrics = new GraphPerformanceMetrics(options);

// 模擬昂貴的操作並記錄詳細的計時資訊
var execId = "advanced-exec-1";
var tracker = metrics.StartNodeTracking("performance-node", "performance-node", execId);
var stopwatch = System.Diagnostics.Stopwatch.StartNew();

// 模擬 CPU 繁重的工作，偶爾等待以避免封鎖執行緒池
int iterations = 10_000;
long result = 0;
for (int i = 0; i < iterations; i++)
{
    result += i * i;
    if (i % 1000 == 0) await Task.Delay(1); // 協作暫停以保持回應性
}

stopwatch.Stop();
metrics.CompleteNodeTracking(tracker, success: true, result: result);

// 使用匯出器在模擬工作負載後檢查指標
using var exporter = new GraphMetricsExporter();
Console.WriteLine(exporter.ExportMetrics(metrics, MetricsExportFormat.Json, TimeSpan.FromMinutes(10)));
```

### 3. 即時指標儀表板

展示如何實施即時指標視覺化和監控。

```csharp
// 使用指標收集器的資源採樣展示基本的即時採樣
var options = GraphMetricsOptions.CreateDevelopmentOptions();
options.EnableResourceMonitoring = true;
using var metrics = new GraphPerformanceMetrics(options);

// 模擬一連串的短執行並顯示採樣的 CPU/記憶體
for (int i = 0; i < 10; i++)
{
    var execId = $"rt-{i}";
    var tracker = metrics.StartNodeTracking("data-generator", "data-generator", execId);

    // 模擬一些處理延遲
    await Task.Delay(Random.Shared.Next(50, 200));

    metrics.CompleteNodeTracking(tracker, success: true);

    // 讀取目前採樣的系統指標（收集器定期更新它們）
    Console.WriteLine($"迭代 {i + 1}：CPU={metrics.CurrentCpuUsage:F1}% 記憶體={metrics.CurrentAvailableMemoryMB:F0} MB");

    await Task.Delay(500); // 節流更新以進行示範
}

Console.WriteLine("✅ 即時採樣示範完成");
```

### 4. 指標匯出和整合

展示將指標匯出到外部監控系統和儀表板。

```csharp
// 使用指標匯出器直接匯出範例
using var exporter = new GraphMetricsExporter(new GraphMetricsExportOptions { IndentedOutput = true });

// 匯出 JSON
var jsonExport = exporter.ExportMetrics(metrics, MetricsExportFormat.Json, TimeSpan.FromMinutes(10));
Console.WriteLine("--- JSON 匯出 ---");
Console.WriteLine(jsonExport);

// 匯出 CSV
var csvExport = exporter.ExportMetrics(metrics, MetricsExportFormat.Csv, TimeSpan.FromMinutes(10));
Console.WriteLine("--- CSV 匯出 ---");
Console.WriteLine(csvExport.Split('\n').Take(20)); // 預覽前幾行

// 匯出 Prometheus
var promExport = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus, TimeSpan.FromMinutes(10));
Console.WriteLine("--- Prometheus 匯出 ---");
Console.WriteLine(promExport);
```

## 預期輸出

### 基本指標收集範例

```
📊 測試指標收集：範例資料 1
   處理時間：234.56 毫秒
   輸入大小：12 個字元
   收集的指標：5 個指標

📊 測試指標收集：範例資料 2
   處理時間：187.23 毫秒
   輸入大小：12 個字元
   收集的指標：5 個指標
```

### 進階效能監控範例

```
🚀 測試效能監控：低複雜度任務
   複雜度級別：1
   處理時間：156.78 毫秒
   迭代次數：1,000
   吞吐量：6,374 次/秒
   效能分數：85.67
   瓶頸：CPU 繁重

🚀 測試效能監控：高複雜度任務
   複雜度級別：10
   處理時間：1,234.56 毫秒
   迭代次數：10,000
   吞吐量：8,101 次/秒
   效能分數：92.34
   瓶頸：記憶體繁重
```

### 即時指標儀表板範例

```
📊 開始即時指標收集...
   儀表板每 500 毫秒更新一次
   按任意鍵停止...
   迭代 1：目前：87.45、平均：87.45、趨勢：穩定
   迭代 2：目前：112.34、平均：99.90、趨勢：上升
   迭代 3：目前：95.67、平均：98.49、趨勢：下降
✅ 即時指標收集完成
```

### 指標匯出範例

```
📤 測試指標匯出：10 個執行
   成功率：90.0%
   平均時間：150.00 毫秒
   匯出格式：json、csv、prometheus、monitoring

📤 測試指標匯出：50 個執行
   成功率：96.0%
   平均時間：150.00 毫秒
   匯出格式：json、csv、prometheus、monitoring
```

## 組態選項

### 指標組態

```csharp
var metricsOptions = new GraphMetricsOptions
{
    EnableNodeMetrics = true,                        // 啟用節點級指標
    EnableExecutionMetrics = true,                   // 啟用執行級指標
    EnableResourceMetrics = true,                    // 啟用資源使用指標
    EnableCustomMetrics = true,                      // 啟用自訂指標
    EnablePerformanceProfiling = true,               // 啟用效能分析
    EnableRealTimeMetrics = true,                    // 啟用即時指標
    EnableMetricsStreaming = true,                   // 啟用指標串流
    EnableMetricsDashboard = true,                   // 啟用指標儀表板
    EnableMetricsExport = true,                      // 啟用指標匯出
    EnableMetricsPersistence = true,                 // 啟用指標持久化
    MetricsCollectionInterval = TimeSpan.FromMilliseconds(100), // 收集間隔
    DashboardUpdateInterval = TimeSpan.FromMilliseconds(500),   // 儀表板更新間隔
    ExportInterval = TimeSpan.FromSeconds(5),        // 匯出間隔
    MetricsStoragePath = "./metrics-data",           // 指標儲存路徑
    ExportFormats = new[] { "json", "csv", "prometheus" },     // 匯出格式
    EnableMetricsCompression = true,                 // 啟用指標壓縮
    MaxMetricsHistory = 10000,                       // 最大指標歷史記錄
    EnableMetricsAggregation = true,                 // 啟用指標聚合
    AggregationInterval = TimeSpan.FromMinutes(1)    // 聚合間隔
};
```

### 效能分析組態

```csharp
var profilingOptions = new PerformanceProfilingOptions
{
    EnableDetailedProfiling = true,                  // 啟用詳細分析
    EnableMemoryProfiling = true,                    // 啟用記憶體分析
    EnableCpuProfiling = true,                       // 啟用 CPU 分析
    EnableNetworkProfiling = true,                   // 啟用網路分析
    ProfilingSamplingRate = 0.1,                     // 分析採樣率 (10%)
    EnableHotPathAnalysis = true,                    // 啟用熱路徑分析
    EnableBottleneckDetection = true,                // 啟用瓶頸偵測
    ProfilingOutputPath = "./profiling-data",         // 分析輸出路徑
    EnableProfilingVisualization = true,             // 啟用分析視覺化
    MaxProfilingDataSize = 100 * 1024 * 1024        // 最大分析資料大小 (100MB)
};
```

## 疑難排解

### 常見問題

#### 未收集指標
```bash
# 問題：未收集指標
# 解決方案：啟用指標收集並檢查組態
EnableNodeMetrics = true;
EnableExecutionMetrics = true;
MetricsCollectionInterval = TimeSpan.FromMilliseconds(100);
```

#### 效能影響
```bash
# 問題：指標收集影響效能
# 解決方案：調整收集間隔並啟用採樣
MetricsCollectionInterval = TimeSpan.FromSeconds(1);
EnableMetricsSampling = true;
SamplingRate = 0.1; // 10% 採樣
```

#### 記憶體問題
```bash
# 問題：指標消耗過多記憶體
# 解決方案：啟用壓縮並限制歷史記錄
EnableMetricsCompression = true;
MaxMetricsHistory = 1000;
EnableMetricsAggregation = true;
```

### 除錯模式

啟用詳細記錄以進行疑難排解：

```csharp
// 啟用除錯記錄
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<GraphMetricsExample>();

// 以除錯記錄組態指標
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
// 實施自訂指標收集
public class CustomMetricsCollector : IMetricsCollector
{
    public async Task<Dictionary<string, object>> CollectMetricsAsync(MetricsContext context)
    {
        var customMetrics = new Dictionary<string, object>();
        
        // 收集自訂業務指標
        customMetrics["business_value"] = await CalculateBusinessValue(context);
        customMetrics["user_satisfaction"] = await MeasureUserSatisfaction(context);
        customMetrics["cost_per_execution"] = await CalculateCostPerExecution(context);
        
        // 收集領域特定指標
        customMetrics["domain_accuracy"] = await MeasureDomainAccuracy(context);
        customMetrics["processing_efficiency"] = await MeasureProcessingEfficiency(context);
        
        return customMetrics;
    }
}
```

### 指標聚合和分析

```csharp
// 實施自訂指標聚合
public class MetricsAggregator : IMetricsAggregator
{
    public async Task<AggregatedMetrics> AggregateMetricsAsync(IEnumerable<MetricsSnapshot> snapshots)
    {
        var aggregated = new AggregatedMetrics();
        
        foreach (var snapshot in snapshots)
        {
            // 聚合效能指標
            aggregated.TotalExecutions += snapshot.ExecutionCount;
            aggregated.TotalProcessingTime += snapshot.TotalProcessingTime;
            aggregated.SuccessCount += snapshot.SuccessCount;
            aggregated.ErrorCount += snapshot.ErrorCount;
            
            // 追蹤趨勢
            aggregated.ExecutionTrends.Add(snapshot.Timestamp, snapshot.ExecutionCount);
            aggregated.PerformanceTrends.Add(snapshot.Timestamp, snapshot.AverageProcessingTime);
        }
        
        // 計算衍生指標
        aggregated.SuccessRate = (double)aggregated.SuccessCount / aggregated.TotalExecutions;
        aggregated.AverageProcessingTime = aggregated.TotalProcessingTime / aggregated.TotalExecutions;
        aggregated.ErrorRate = (double)aggregated.ErrorCount / aggregated.TotalExecutions;
        
        return aggregated;
    }
}
```

### 即時告警

```csharp
// 實施即時指標告警
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

// 告警規則範例
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
            Condition = async (metrics) => metrics.ErrorRate > 0.1 // 10% 錯誤率
        };
    }
}
```

## 相關範例

* [圖形視覺化](./graph-visualization.md)：指標的視覺表示
* [效能最佳化](./performance-optimization.md)：使用指標進行最佳化
* [串流執行](./streaming-execution.md)：即時指標串流
* [除錯和檢查](./debug-inspection.md)：用於除錯的指標

## 另請參閱

* [指標和可觀測性](../concepts/metrics.md)：理解指標概念
* [效能監控](../how-to/performance-monitoring.md)：效能監控模式
* [除錯和檢查](../how-to/debug-and-inspection.md)：使用指標進行除錯
* [API 參考](../api/)：完整 API 文件
