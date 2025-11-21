# 指標與日誌快速入門

學習如何在您的 SemanticKernel.Graph 應用程式中啟用全面的指標收集和結構化日誌。本指南向您展示如何監控效能、追蹤執行路徑，以及深入了解您的 Graph 操作。

## 概念與技術

**指標收集**：`GraphPerformanceMetrics` 類別追蹤 Node 執行時間、成功率和資源使用情況，幫助識別效能瓶頸並最佳化您的 Graph。

**結構化日誌**：`SemanticKernelGraphLogger` 提供相關性感知的日誌記錄，與 Microsoft.Extensions.Logging 整合，讓您輕鬆追蹤執行流程並偵錯問題。

**效能分析**：內建的儀表板和報告幫助您瞭解執行模式、識別緩慢的 Node，以及即時監控系統健康狀態。

## 先決條件與最低配置

* .NET 8.0 或更新版本
* SemanticKernel.Graph 套件已安裝
* 您的應用程式中已配置 Microsoft.Extensions.Logging

## 快速設定

### 1. 啟用指標與日誌

新增啟用指標和日誌的 Graph 支援到您的核心：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;

// 建立啟用 Graph 支援的核心
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey) // 替換為您的 API 金鑰
    .AddGraphSupport(options =>
    {
        options.EnableLogging = true;   // 啟用結構化日誌
        options.EnableMetrics = true;   // 啟用效能指標收集
    })
    .Build();
```

### 2. 建立含指標的 Graph

建立 Graph 執行器並啟用開發指標以進行詳細追蹤：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;

// 建立具有描述性名稱和描述的 Graph 執行器
var graph = new GraphExecutor("MyGraph", "Example graph with metrics");

// 啟用開發指標（詳細追蹤、頻繁取樣）
// 用於開發和測試環境
graph.EnableDevelopmentMetrics();

// 或使用生產指標（針對效能優化）
// 用於生產環境以減少開銷
// graph.EnableProductionMetrics();
```

### 3. 新增 Node 並執行

建立您的 Graph 並執行它以收集指標：

```csharp
// 建立具有描述性名稱和簡單函數的函數 Node
var node1 = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "Hello!", "greeting"),
    "greeting",
    "Greeting Node");

var node2 = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "Processing...", "processing"),
    "processing",
    "Processing Node");

// 透過新增 Node 並連接它們來建立 Graph
graph.AddNode(node1)
     .AddNode(node2)
     .Connect(node1.NodeId, node2.NodeId)  // 連接 greeting -> processing
     .SetStartNode(node1.NodeId);          // 設定 greeting 為起始 Node

// 執行多次以產生有意義的指標資料
Console.WriteLine("Executing graph to collect metrics...");
for (int i = 0; i < 10; i++)
{
    try
    {
        var result = await graph.ExecuteAsync(kernel, new KernelArguments());
        Console.Write(".");  // 顯示進度
    }
    catch (Exception ex)
    {
        Console.Write("X");  // 顯示失敗執行
        // 在生產環境中，記錄異常詳細資訊
    }
}
Console.WriteLine(" Done!");
```

## 檢視效能資料

### 基本效能摘要

取得您的 Graph 效能概覽：

```csharp
// 取得過去 5 分鐘的效能摘要
var summary = graph.GetPerformanceSummary(TimeSpan.FromMinutes(5));
if (summary != null)
{
    Console.WriteLine("📊 PERFORMANCE SUMMARY");
    Console.WriteLine("".PadRight(50, '-'));
    Console.WriteLine($"Total Executions: {summary.TotalExecutions}");
    Console.WriteLine($"Success Rate: {summary.SuccessRate:F1}%");
    Console.WriteLine($"Average Execution Time: {summary.AverageExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"Throughput: {summary.Throughput:F2} executions/second");
    
    // 根據效能閾值檢查系統健康狀態
    var isHealthy = summary.IsHealthy();
    Console.WriteLine($"System Health: {(isHealthy ? "🟢 HEALTHY" : "🔴 NEEDS ATTENTION")}");
    
    // 如果系統需要關注，顯示效能警告
    if (!isHealthy)
    {
        var alerts = summary.GetPerformanceAlerts();
        Console.WriteLine("Alerts:");
        foreach (var alert in alerts)
        {
            Console.WriteLine($"  - {alert}");
        }
    }
}
else
{
    Console.WriteLine("No performance data available yet. Execute the graph first.");
}
```

### Node 層級指標

分析個別 Node 的效能：

```csharp
// 取得 Graph 中所有 Node 的指標
var nodeMetrics = graph.GetAllNodeMetrics();
if (nodeMetrics.Count > 0)
{
    Console.WriteLine("🔧 NODE PERFORMANCE");
    Console.WriteLine("".PadRight(50, '-'));
    Console.WriteLine($"{"Node",-15} {"Executions",-12} {"Avg Time",-12} {"Success %",-10} {"Rating",-12}");
    Console.WriteLine("".PadRight(70, '-'));

    // 按總執行時間排序 Node（最慢優先）
    foreach (var kvp in nodeMetrics.OrderByDescending(x => x.Value.TotalExecutionTime))
    {
        var node = kvp.Value;
        var rating = node.GetPerformanceClassification(); // Excellent, Good, Fair, Poor
        
        Console.WriteLine($"{node.NodeName.Substring(0, Math.Min(14, node.NodeName.Length)),-15} " +
                         $"{node.TotalExecutions,-12} " +
                         $"{node.AverageExecutionTime.TotalMilliseconds,-12:F2}ms " +
                         $"{node.SuccessRate,-10:F1}% " +
                         $"{rating,-12}");
    }
}
else
{
    Console.WriteLine("No node metrics available yet. Execute the graph first.");
}
```

### 執行路徑分析

瞭解您的 Graph 如何流動並識別瓶頸：

```csharp
// 分析執行路徑以瞭解 Graph 流程模式
var pathMetrics = graph.GetPathMetrics();
if (pathMetrics.Count > 0)
{
    Console.WriteLine("🛣️ EXECUTION PATHS");
    Console.WriteLine("".PadRight(50, '-'));
    
    // 按執行次數排序路徑（最頻繁優先）
    foreach (var kvp in pathMetrics.OrderByDescending(x => x.Value.ExecutionCount))
    {
        var path = kvp.Value;
        Console.WriteLine($"Path: {path.PathKey}");
        Console.WriteLine($"  Executions: {path.ExecutionCount} | " +
                         $"Avg Time: {path.AverageExecutionTime.TotalMilliseconds:F2}ms | " +
                         $"Success: {path.SuccessRate:F1}%");
        
        // 識別潛在瓶頸
        if (path.AverageExecutionTime.TotalMilliseconds > 1000)
        {
            Console.WriteLine($"  ⚠️  Slow path detected - consider optimization");
        }
        if (path.SuccessRate < 95.0)
        {
            Console.WriteLine($"  ❌ Low success rate - investigate failures");
        }
    }
}
else
{
    Console.WriteLine("No path metrics available yet. Execute the graph first.");
}
```

## 進階指標配置

### 自訂指標選項

使用自訂選項配置詳細的指標收集：

```csharp
// 建立生產優化的指標選項
var metricsOptions = GraphMetricsOptions.CreateProductionOptions();

// 配置資源監控（CPU 和記憶體使用情況）
metricsOptions.EnableResourceMonitoring = true;  // 監控系統資源
metricsOptions.ResourceSamplingInterval = TimeSpan.FromSeconds(10); // 每 10 秒取樣一次

// 配置資料保留和追蹤
metricsOptions.MaxSampleHistory = 10000; // 保留最後 10,000 個樣本
metricsOptions.EnableDetailedPathTracking = true; // 詳細追蹤執行路徑

// 將配置應用到 Graph
graph.ConfigureMetrics(metricsOptions);

Console.WriteLine("Advanced metrics configuration applied successfully!");
```

### 即時監控

建立儀表板以進行即時指標監控：

```csharp
// 建立用於即時監控的指標儀表板
var dashboard = new MetricsDashboard(graph.PerformanceMetrics!);

// 產生即時指標快照
var realtimeMetrics = dashboard.GenerateRealTimeMetrics();
Console.WriteLine("📈 REAL-TIME METRICS");
Console.WriteLine("".PadRight(50, '='));
Console.WriteLine(realtimeMetrics);

// 產生全面的儀表板報告
var dashboardReport = dashboard.GenerateDashboard(
    timeWindow: TimeSpan.FromMinutes(10),    // 過去 10 分鐘的資料
    includeNodeDetails: true,                // 包括每個 Node 的分析
    includePathAnalysis: true);              // 包括執行路徑分析

Console.WriteLine("\n📊 COMPREHENSIVE DASHBOARD");
Console.WriteLine("".PadRight(50, '='));
Console.WriteLine(dashboardReport);

// 產生快速狀態概覽
var statusOverview = dashboard.GenerateStatusOverview();
Console.WriteLine("\n⚡ QUICK STATUS");
Console.WriteLine("".PadRight(50, '='));
Console.WriteLine(statusOverview);
```

## 日誌配置

### 結構化日誌設定

使用相關性 ID 配置詳細的日誌記錄：

```csharp
using Microsoft.Extensions.Logging;
using SemanticKernel.Graph.Integration;

// 使用主控台輸出配置結構化日誌
var loggerFactory = LoggerFactory.Create(builder =>
    builder
        .AddConsole()                           // 新增主控台日誌提供者
        .SetMinimumLevel(LogLevel.Information)  // 設定最低日誌層級
        .AddFilter("SemanticKernel.Graph", LogLevel.Debug)); // 為 Graph 操作啟用偵錯

// 建立具有相關性支援的 Graph 記錄器
var graphLogger = new SemanticKernelGraphLogger(
    loggerFactory.CreateLogger("MyGraph"),      // 具有分類的記錄器執行個體
    new GraphOptions { EnableLogging = true }); // 啟用日誌的 Graph 選項

// 記錄器自動追蹤執行內容和相關性 ID
Console.WriteLine("✅ Structured logging configured successfully!");
```

### 日誌擴充功能

針對常見情況使用方便的日誌擴充功能：

```csharp
using SemanticKernel.Graph.Extensions;

// 產生相關性的唯一執行 ID
var executionId = Guid.NewGuid().ToString();
var nodeId = "greeting-node";

// 使用相關性記錄 Graph 層級的資訊
graphLogger.LogGraphInfo(executionId, "Graph execution started", 
    new Dictionary<string, object> 
    { 
        ["GraphName"] = "MyGraph",
        ["StartTime"] = DateTime.UtcNow 
    });

// 使用內容記錄 Node 層級的詳細資訊
graphLogger.LogNodeInfo(executionId, nodeId, "Node processing started",
    new Dictionary<string, object>
    {
        ["NodeType"] = "FunctionGraphNode",
        ["InputParameters"] = "none"
    });

// 使用標籤記錄效能指標以進行篩選
graphLogger.LogPerformance(executionId, "execution_time", 150.5, "ms", 
    new Dictionary<string, string> 
    { 
        ["node_type"] = "function",
        ["operation"] = "greeting",
        ["environment"] = "development"
    });

// 記錄完成
graphLogger.LogGraphInfo(executionId, "Graph execution completed successfully");
```

## 疑難排除

### 常見問題

**指標未顯示**：確保在新增 Graph 支援時設定 `options.EnableMetrics = true`。

**效能計數器失敗**：在某些系統上，資源監控需要提高的權限。如果遇到問題，請使用 `EnableResourceMonitoring = false`。

**高記憶體使用量**：在生產環境中減少 `MaxSampleHistory` 和 `MaxPathHistoryPerPath`。

**日誌過於冗長**：適當配置日誌層級 - 在生產環境中使用 `LogLevel.Information`，在開發環境中使用 `LogLevel.Debug`。

### 效能建議

* 在生產環境中使用 `CreateProductionOptions()`
* 僅在需要時啟用資源監控
* 根據您的分析要求設定適當的保留期限
* 在收集詳細指標時監控記憶體使用量

## 另請參閱

* **參考資料**：[GraphPerformanceMetrics](../api/GraphPerformanceMetrics.md)、[GraphMetricsOptions](../api/GraphMetricsOptions.md)、[SemanticKernelGraphLogger](../api/SemanticKernelGraphLogger.md)
* **指南**：[效能監控](../guides/performance-monitoring.md)、[偵錯與檢查](../guides/debugging-inspection.md)
* **範例**：[GraphMetricsExample](../examples/graph-metrics.md)、[AdvancedPatternsExample](../examples/advanced-patterns.md)

## 參考 API

* **[GraphPerformanceMetrics](../api/metrics.md#graph-performance-metrics)**：效能指標收集
* **[GraphMetricsOptions](../api/metrics.md#graph-metrics-options)**：指標配置選項
* **[SemanticKernelGraphLogger](../api/logging.md#semantic-kernel-graph-logger)**：結構化日誌系統
* **[MetricsDashboard](../api/metrics.md#metrics-dashboard)**：即時指標視覺化
