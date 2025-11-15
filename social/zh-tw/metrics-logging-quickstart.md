# 指標和日誌快速入門

瞭解如何在 SemanticKernel.Graph 應用程式中啟用全面的指標蒐集和結構化日誌。本指南將向您展示如何監控效能、追蹤執行路徑，以及獲得對圖形操作的深入見解。

## 概念和技術

**指標蒐集**：`GraphPerformanceMetrics` 類別追蹤節點執行時間、成功率和資源使用情況，幫助您識別效能瓶頸並優化您的圖形。

**結構化日誌**：`SemanticKernelGraphLogger` 提供與 Microsoft.Extensions.Logging 整合的相關性感知日誌，使您能輕鬆追蹤執行流程並除錯問題。

**效能分析**：內建儀表板和報告幫助您瞭解執行模式、識別緩慢節點，並即時監控系統健康狀況。

## 先決條件和最小設定

* .NET 8.0 或更新版本
* 已安裝 SemanticKernel.Graph 套件
* 應用程式中已設定 Microsoft.Extensions.Logging

## 快速設定

### 1. 啟用指標和日誌

新增圖形支援至您的核心，並啟用指標和日誌：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;

// 建立啟用圖形支援的核心
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-3.5-turbo", apiKey) // 替換為您的 API 金鑰
    .AddGraphSupport(options =>
    {
        options.EnableLogging = true;   // 啟用結構化日誌
        options.EnableMetrics = true;   // 啟用效能指標蒐集
    })
    .Build();
```

### 2. 建立含有指標的圖形

建立圖形執行器並啟用開發指標以進行詳細追蹤：

```csharp
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;

// 建立具有描述性名稱和描述的圖形執行器
var graph = new GraphExecutor("MyGraph", "Example graph with metrics");

// 啟用開發指標（詳細追蹤、頻繁取樣）
// 用於開發和測試環境
graph.EnableDevelopmentMetrics();

// 或使用生產指標（針對效能最佳化）
// 用於生產環境以降低負荷
// graph.EnableProductionMetrics();
```

### 3. 新增節點並執行

建置圖形並執行它以蒐集指標：

```csharp
// 建立具有描述性名稱和簡單函式的函式節點
var node1 = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "Hello!", "greeting"),
    "greeting",
    "Greeting Node");

var node2 = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(() => "Processing...", "processing"),
    "processing",
    "Processing Node");

// 透過新增節點和連接它們來建置圖形
graph.AddNode(node1)
     .AddNode(node2)
     .Connect(node1.NodeId, node2.NodeId)  // 連接 greeting -> processing
     .SetStartNode(node1.NodeId);          // 設定 greeting 作為起始節點

// 多次執行以產生有意義的指標資料
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
        Console.Write("X");  // 顯示失敗的執行
        // 在生產環境中，記錄異常詳細資訊
    }
}
Console.WriteLine(" Done!");
```

## 檢視效能資料

### 基本效能摘要

取得圖形效能的概覽：

```csharp
// 取得過去 5 分鐘的效能摘要
var summary = graph.GetPerformanceSummary(TimeSpan.FromMinutes(5));
if (summary != null)
{
    Console.WriteLine("📊 效能摘要");
    Console.WriteLine("".PadRight(50, '-'));
    Console.WriteLine($"總執行次數：{summary.TotalExecutions}");
    Console.WriteLine($"成功率：{summary.SuccessRate:F1}%");
    Console.WriteLine($"平均執行時間：{summary.AverageExecutionTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"輸送量：{summary.Throughput:F2} 次執行/秒");
    
    // 根據效能閾值檢查系統健康狀況
    var isHealthy = summary.IsHealthy();
    Console.WriteLine($"系統健康狀況：{(isHealthy ? "🟢 正常" : "🔴 需要注意")}");
    
    // 如果系統需要注意，顯示效能警示
    if (!isHealthy)
    {
        var alerts = summary.GetPerformanceAlerts();
        Console.WriteLine("警示：");
        foreach (var alert in alerts)
        {
            Console.WriteLine($"  - {alert}");
        }
    }
}
else
{
    Console.WriteLine("尚無效能資料。請先執行圖形。");
}
```

### 節點級指標

分析個別節點的效能：

```csharp
// 取得圖形中所有節點的指標
var nodeMetrics = graph.GetAllNodeMetrics();
if (nodeMetrics.Count > 0)
{
    Console.WriteLine("🔧 節點效能");
    Console.WriteLine("".PadRight(50, '-'));
    Console.WriteLine($"{"節點",-15} {"執行次數",-12} {"平均時間",-12} {"成功 %",-10} {"評級",-12}");
    Console.WriteLine("".PadRight(70, '-'));

    // 按總執行時間排序節點（最慢優先）
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
    Console.WriteLine("尚無節點指標。請先執行圖形。");
}
```

### 執行路徑分析

瞭解圖形如何流動並識別瓶頸：

```csharp
// 分析執行路徑以瞭解圖形流程模式
var pathMetrics = graph.GetPathMetrics();
if (pathMetrics.Count > 0)
{
    Console.WriteLine("🛣️ 執行路徑");
    Console.WriteLine("".PadRight(50, '-'));
    
    // 按執行計數排序路徑（最頻繁優先）
    foreach (var kvp in pathMetrics.OrderByDescending(x => x.Value.ExecutionCount))
    {
        var path = kvp.Value;
        Console.WriteLine($"路徑：{path.PathKey}");
        Console.WriteLine($"  執行次數：{path.ExecutionCount} | " +
                         $"平均時間：{path.AverageExecutionTime.TotalMilliseconds:F2}ms | " +
                         $"成功率：{path.SuccessRate:F1}%");
        
        // 識別潛在瓶頸
        if (path.AverageExecutionTime.TotalMilliseconds > 1000)
        {
            Console.WriteLine($"  ⚠️  偵測到緩慢路徑 - 考慮最佳化");
        }
        if (path.SuccessRate < 95.0)
        {
            Console.WriteLine($"  ❌ 成功率低 - 調查失敗原因");
        }
    }
}
else
{
    Console.WriteLine("尚無路徑指標。請先執行圖形。");
}
```

## 進階指標設定

### 自訂指標選項

使用自訂選項設定詳細的指標蒐集：

```csharp
// 建立生產最佳化的指標選項
var metricsOptions = GraphMetricsOptions.CreateProductionOptions();

// 設定資源監控（CPU 和記憶體使用情況）
metricsOptions.EnableResourceMonitoring = true;  // 監控系統資源
metricsOptions.ResourceSamplingInterval = TimeSpan.FromSeconds(10); // 每 10 秒取樣一次

// 設定資料保留和追蹤
metricsOptions.MaxSampleHistory = 10000; // 保留最後 10,000 個樣本
metricsOptions.EnableDetailedPathTracking = true; // 詳細追蹤執行路徑

// 將設定應用到圖形
graph.ConfigureMetrics(metricsOptions);

Console.WriteLine("進階指標設定已成功套用！");
```

### 即時監控

為即時指標監控建立儀表板：

```csharp
// 為即時監控建立指標儀表板
var dashboard = new MetricsDashboard(graph.PerformanceMetrics!);

// 產生即時指標快照
var realtimeMetrics = dashboard.GenerateRealTimeMetrics();
Console.WriteLine("📈 即時指標");
Console.WriteLine("".PadRight(50, '='));
Console.WriteLine(realtimeMetrics);

// 產生全面的儀表板報告
var dashboardReport = dashboard.GenerateDashboard(
    timeWindow: TimeSpan.FromMinutes(10),    // 過去 10 分鐘的資料
    includeNodeDetails: true,                // 包含每個節點的分析
    includePathAnalysis: true);              // 包含執行路徑分析

Console.WriteLine("\n📊 全面儀表板");
Console.WriteLine("".PadRight(50, '='));
Console.WriteLine(dashboardReport);

// 產生快速狀態概覽
var statusOverview = dashboard.GenerateStatusOverview();
Console.WriteLine("\n⚡ 快速狀態");
Console.WriteLine("".PadRight(50, '='));
Console.WriteLine(statusOverview);
```

## 日誌設定

### 結構化日誌設定

使用相關性 ID 設定詳細日誌：

```csharp
using Microsoft.Extensions.Logging;
using SemanticKernel.Graph.Integration;

// 使用主控台輸出設定結構化日誌
var loggerFactory = LoggerFactory.Create(builder =>
    builder
        .AddConsole()                           // 新增主控台日誌提供程式
        .SetMinimumLevel(LogLevel.Information)  // 設定最低日誌層級
        .AddFilter("SemanticKernel.Graph", LogLevel.Debug)); // 為圖形操作啟用偵錯

// 建立支援相關性的圖形記錄器
var graphLogger = new SemanticKernelGraphLogger(
    loggerFactory.CreateLogger("MyGraph"),      // 具有類別的記錄器執行個體
    new GraphOptions { EnableLogging = true }); // 啟用日誌的圖形選項

// 記錄器會自動追蹤執行內容和相關性 ID
Console.WriteLine("✅ 結構化日誌設定成功！");
```

### 日誌擴充

針對常見情況使用便利的日誌擴充：

```csharp
using SemanticKernel.Graph.Extensions;

// 產生唯一執行識別碼以進行相關性
var executionId = Guid.NewGuid().ToString();
var nodeId = "greeting-node";

// 使用相關性記錄圖形級資訊
graphLogger.LogGraphInfo(executionId, "Graph execution started", 
    new Dictionary<string, object> 
    { 
        ["GraphName"] = "MyGraph",
        ["StartTime"] = DateTime.UtcNow 
    });

// 使用內容記錄節點級詳細資訊
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

## 疑難排解

### 常見問題

**未顯示指標**：確認在新增圖形支援時已設定 `options.EnableMetrics = true`。

**效能計數器失敗**：在某些系統上，資源監控需要提高的權限。如果遇到問題，請使用 `EnableResourceMonitoring = false`。

**記憶體使用量高**：在生產環境中減少 `MaxSampleHistory` 和 `MaxPathHistoryPerPath`。

**日誌過於詳細**：適當設定日誌層級 - 生產環境使用 `LogLevel.Information`，開發環境使用 `LogLevel.Debug`。

### 效能建議

* 在生產環境中使用 `CreateProductionOptions()`
* 只在需要時啟用資源監控
* 根據您的分析需求設定適當的保留期
* 蒐集詳細指標時監控記憶體使用情況

## 另請參閱

* **參考**：[GraphPerformanceMetrics](../api/GraphPerformanceMetrics.md)、[GraphMetricsOptions](../api/GraphMetricsOptions.md)、[SemanticKernelGraphLogger](../api/SemanticKernelGraphLogger.md)
* **指南**：[效能監控](../guides/performance-monitoring.md)、[除錯和檢查](../guides/debugging-inspection.md)
* **範例**：[GraphMetricsExample](../examples/graph-metrics.md)、[AdvancedPatternsExample](../examples/advanced-patterns.md)

## 參考 API

* **[GraphPerformanceMetrics](../api/metrics.md#graph-performance-metrics)**：效能指標蒐集
* **[GraphMetricsOptions](../api/metrics.md#graph-metrics-options)**：指標設定選項
* **[SemanticKernelGraphLogger](../api/logging.md#semantic-kernel-graph-logger)**：結構化日誌系統
* **[MetricsDashboard](../api/metrics.md#metrics-dashboard)**：即時指標視覺化
