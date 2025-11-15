# 進階模式示例

本示例演示了語意核心圖中進階架構模式的全面整合，包括學術模式、機器學習最佳化和企業整合功能。

## 目標

學習如何在基於圖形的工作流中實現和協調進階模式，以便：
* 配置和使用學術模式（斷路器、艙壁、旁路快取）
* 啟用基於機器學習的效能預測和異常偵測
* 實現分散式系統的企業整合模式
* 在真實世界場景中協調多個模式
* 全面監控和診斷模式效能

## 先決條件

* **.NET 8.0** 或更高版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中設定
* **語意核心圖套件**已安裝
* 對[圖形概念](../concepts/graph-concepts.md)和[執行模型](../concepts/execution-model.md)的基本理解
* 熟悉[錯誤處理和復原能力](../how-to/error-handling-and-resilience.md)

## 主要元件

### 概念和技術

* **學術模式**：企業級復原能力模式，包括斷路器、艙壁和旁路快取
* **機器學習最佳化**：使用歷史執行資料進行效能預測和異常偵測
* **企業整合**：訊息路由、內容型路由、發布-訂閱和聚合模式
* **模式協調**：協調執行多個模式並進行全面診斷

### 核心類別

* `GraphExecutor`：透過 `WithAllAdvancedPatterns` 支援進階模式的增強執行器
* `AcademicPatterns`：斷路器、艙壁和旁路快取實現
* `MachineLearningOptimizer`：效能預測和異常偵測引擎
* `EnterpriseIntegrationPatterns`：訊息路由和處理模式
* `GraphPerformanceMetrics`：全面效能追蹤和分析

## 執行示例

### 入門

本示例演示了語意核心圖套件的進階模式和最佳化。下面的程式碼片段向您展示如何在自己的應用程式中實現這些模式。

## 逐步實現

### 1. 建立進階圖執行器

該示例首先建立啟用了所有進階模式的圖執行器。

```csharp
// 使用提供的核心和圖記錄器建立 GraphExecutor。
// 此片段為演示配置了一組最小、安全的進階模式。
var executor = new GraphExecutor(kernel, graphLogger);

// 使用保守預設值啟用主要學術復原能力模式。
executor.WithAllAdvancedPatterns(config =>
{
    // 啟用學術復原能力模式（斷路器、艙壁、旁路快取）。
    config.EnableAcademicPatterns = true;
    config.Academic.EnableCircuitBreaker = true;
    config.Academic.EnableBulkhead = true;
    config.Academic.EnableCacheAside = true;

    // 斷路器：3 次失敗後跳閘，保持短時間開啟。
    config.Academic.CircuitBreakerOptions.FailureThreshold = 3;
    config.Academic.CircuitBreakerOptions.OpenTimeout = TimeSpan.FromSeconds(10);

    // 艙壁：限制並行性以避免演示中的資源耗盡。
    config.Academic.BulkheadOptions.MaxConcurrency = 5;
    config.Academic.BulkheadOptions.AcquisitionTimeout = TimeSpan.FromSeconds(15);

    // 旁路快取：用於演示的小型記憶體內快取。
    config.Academic.CacheAsideOptions.MaxCacheSize = 1000;
    config.Academic.CacheAsideOptions.DefaultTtl = TimeSpan.FromMinutes(10);
});
```

### 2. 學術模式演示

#### 斷路器模式

```csharp
// 透過執行器的斷路器幫助器執行受保護的操作。
// 操作應為非同步委派；當斷路器開啟或發生失敗時執行備用方案。
var circuitBreakerTest = await executor.ExecuteWithCircuitBreakerAsync(
    operation: async () =>
    {
        // 模擬一些工作
        await Task.Delay(100);
        Console.WriteLine("Operation executed successfully");
        return "Success";
    },
    fallback: async () =>
    {
        // 用於演示的最小備用實現
        Console.WriteLine("Fallback operation executed");
        return "Fallback";
    });
```

#### 艙壁模式

```csharp
// 使用艙壁並行執行多個操作以保護資源。
var bulkheadTasks = Enumerable.Range(1, 3).Select(async i =>
{
    return await executor.ExecuteWithBulkheadAsync(async (cancellationToken) =>
    {
        await Task.Delay(200, cancellationToken);
        Console.WriteLine($"Bulkhead operation {i} completed");
        return $"Result-{i}";
    });
});

var bulkheadResults = await Task.WhenAll(bulkheadTasks);
```

#### 旁路快取模式

```csharp
// 旁路快取模式：快取未命中時呼叫載入器以填充快取。
var cacheResult1 = await executor.GetOrSetCacheAsync(
    key: "user_profile_123",
    loader: async () =>
    {
        // 模擬緩慢的資料來源（資料庫）
        await Task.Delay(500);
        Console.WriteLine("Loading from database (cache miss)");
        return new { UserId = 123, Name = "John Doe", Email = "john@example.com" };
    });

// 第二次呼叫應為快取命中，不會呼叫載入器委派。
var cacheResult2 = await executor.GetOrSetCacheAsync(
    key: "user_profile_123",
    loader: async () =>
    {
        // 如果在您的環境中執行，則快取未正常運作。
        Console.WriteLine("Loader unexpectedly invoked on supposed cache hit");
        return new { UserId = 123, Name = "John Doe", Email = "john@example.com" };
    });
```

### 3. 進階最佳化

該示例演示了基於歷史指標的效能最佳化。

```csharp
// 建立小型指標物件並模擬執行以產生範例資料。
var metrics = new GraphPerformanceMetrics(new GraphMetricsOptions(), graphLogger);

for (int i = 0; i < 5; i++)
{
    var tracker = metrics.StartNodeTracking($"node_{i % 2}", $"TestNode{i % 2}", $"exec_{i}");
    await Task.Delay(Random.Shared.Next(50, 150));
    metrics.CompleteNodeTracking(tracker, success: true);
}

// 使用模擬指標執行輕量級最佳化分析。
var optimizationResult = await executor.OptimizeAsync(metrics);
Console.WriteLine($"Analysis completed in {optimizationResult.AnalysisTime.TotalMilliseconds:F2}ms");
Console.WriteLine($"Total optimizations identified: {optimizationResult.TotalOptimizations}");
```

### 4. 機器學習最佳化

#### 效能預測

```csharp
// 準備用於預測演示的小型圖形組態。
var graphConfig = new GraphConfiguration
{
    NodeCount = 8,
    AveragePathLength = 3.5,
    ConditionalNodeCount = 2,
    LoopNodeCount = 1,
    ParallelNodeCount = 2
};

// 向執行器要求效能預測（需要啟用機器學習）。
var prediction = await executor.PredictPerformanceAsync(graphConfig);
Console.WriteLine($"Predicted latency: {prediction.PredictedLatency.TotalMilliseconds:F2}ms");
Console.WriteLine($"Confidence: {prediction.Confidence:P2}");
Console.WriteLine($"Recommended optimizations: {prediction.RecommendedOptimizations.Count}");
```

#### 異常偵測

```csharp
// 異常偵測輸入示例（模擬指標）。
var executionMetrics = new GraphExecutionMetrics
{
    TotalExecutionTime = TimeSpan.FromMilliseconds(5000),
    CpuUsage = 85.0,
    MemoryUsage = 75.0,
    ErrorRate = 2.0,
    ThroughputPerSecond = 10.0
};

var anomalyResult = await executor.DetectAnomaliesAsync(executionMetrics);
Console.WriteLine($"Is anomaly: {anomalyResult.IsAnomaly}");
Console.WriteLine($"Anomaly score: {anomalyResult.AnomalyScore:F2}");
Console.WriteLine($"Confidence: {anomalyResult.Confidence:P2}");
```

### 5. 企業整合模式

#### 訊息路由

```csharp
// 定義一個簡單的訊息路由規則，轉發「OrderCreated」訊息。
var messageRoute = new IntegrationRoute
{
    Type = IntegrationRouteType.Message,
    Source = "orders",
    Destination = "fulfillment",
    Conditions = new Dictionary<string, object>
    {
        ["MessageType"] = "OrderCreated",
        ["Priority"] = MessagePriority.High
    }
};

var routeId = await executor.ConfigureIntegrationRouteAsync(messageRoute);
Console.WriteLine($"Route configured with id: {routeId}");
```

#### 處理不同模式

```csharp
// 準備幾個用於路由演示的範例企業訊息。
var testMessages = new[]
{
    new EnterpriseMessage
    {
        MessageType = "OrderCreated",
        Priority = MessagePriority.High,
        Payload = new { OrderId = "ORD-001", CustomerId = "CUST-123", Amount = 299.99 },
        Routing = new RoutingProperties { RoutingKey = "orders", Topic = "order-events" }
    },
    new EnterpriseMessage
    {
        MessageType = "PaymentProcessed",
        Priority = MessagePriority.Normal,
        Payload = new { PaymentId = "PAY-001", OrderId = "ORD-001", Status = "Completed" },
        Routing = new RoutingProperties { RoutingKey = "payments", Topic = "payment-events" }
    }
};

foreach (var message in testMessages)
{
    Console.WriteLine($"Processing message: {message.MessageType}");

    // 訊息路由器
    var routerContext = new ProcessingContext
    {
        ProcessingPattern = IntegrationPattern.MessageRouter,
        RoutingKey = message.Routing.RoutingKey,
        ProcessingTimeout = TimeSpan.FromSeconds(30)
    };

    var routerResult = await executor.ProcessEnterpriseMessageAsync(message, routerContext);
    Console.WriteLine($"Message Router: {(routerResult.Success ? "OK" : "FAIL")} ({routerResult.ProcessingTime.TotalMilliseconds:F2}ms)");

    // 內容型路由器
    var contentContext = new ProcessingContext
    {
        ProcessingPattern = IntegrationPattern.ContentBasedRouter,
        ProcessingTimeout = TimeSpan.FromSeconds(30)
    };

    var contentResult = await executor.ProcessEnterpriseMessageAsync(message, contentContext);
    Console.WriteLine($"Content Router: {(contentResult.Success ? "OK" : "FAIL")} ({contentResult.ProcessingTime.TotalMilliseconds:F2}ms)");

    // 發布-訂閱
    var pubSubContext = new ProcessingContext
    {
        ProcessingPattern = IntegrationPattern.PublishSubscribe,
        Topic = message.Routing.Topic,
        ProcessingTimeout = TimeSpan.FromSeconds(30)
    };

    var pubSubResult = await executor.ProcessEnterpriseMessageAsync(message, pubSubContext);
    Console.WriteLine($"Pub-Sub: {(pubSubResult.Success ? "OK" : "FAIL")} ({pubSubResult.ProcessingTime.TotalMilliseconds:F2}ms)");
}
```

### 6. 全面診斷

該示例以所有模式的全面診斷結束。

```csharp
// 執行全面診斷例行程序並列印精簡報告。
var diagnosticReport = await executor.RunComprehensiveDiagnosticsAsync(metrics);

Console.WriteLine($"\nDiagnostic Report (Generated at {diagnosticReport.Timestamp:HH:mm:ss})");
Console.WriteLine(new string('=', 60));

Console.WriteLine($"Success: {diagnosticReport.Success}");
Console.WriteLine($"Executor ID: {diagnosticReport.GraphExecutorId}");

if (diagnosticReport.AcademicPatternsStatus != null)
{
    var status = diagnosticReport.AcademicPatternsStatus;
    Console.WriteLine($"Circuit Breaker configured: {status.CircuitBreakerConfigured}");
    Console.WriteLine($"Bulkhead configured: {status.BulkheadConfigured}");
    Console.WriteLine($"Cache-Aside configured: {status.CacheAsideConfigured}");
}

if (diagnosticReport.OptimizationAnalysis != null)
{
    var opt = diagnosticReport.OptimizationAnalysis;
    Console.WriteLine($"Optimization analysis time: {opt.AnalysisTime.TotalMilliseconds:F2}ms");
    Console.WriteLine($"Total optimizations: {opt.TotalOptimizations}");
}
```

## 預期輸出

該示例產生全面的輸出，顯示：

* ✅ 建立啟用所有模式的進階圖執行器
* 🎓 學術模式演示（斷路器、艙壁、旁路快取）
* ⚡ 具有效能建議的進階最佳化分析
* 🤖 機器學習訓練和效能預測
* 🏢 企業整合模式（訊息路由器、內容路由器、發布-訂閱）
* 🔍 所有模式的全面診斷報告

## 疑難排解

### 常見問題

1. **模式組態錯誤**：確保所有模式選項在呼叫 `WithAllAdvancedPatterns` 之前都已正確配置
2. **機器學習訓練失敗**：檢查是否有足夠的歷史資料可用於訓練
3. **整合路由錯誤**：驗證訊息路由條件和目標組態
4. **效能問題**：監控最佳化分析計時並根據需要調整閾值

### 除錯提示

* 啟用詳細記錄以追蹤模式執行
* 使用全面診斷來識別組態問題
* 監控斷路器狀態和艙壁並行限制
* 檢查快取命中率和機器學習模型訓練狀態

## 另請參閱

* [錯誤處理和復原能力](../how-to/error-handling-and-resilience.md)
* [資源治理和並行](../how-to/resource-governance-and-concurrency.md)
* [指標和可觀測性](../how-to/metrics-and-observability.md)
* [整合和擴充](../how-to/integration-and-extensions.md)
* [進階路由](../how-to/advanced-routing.md)
