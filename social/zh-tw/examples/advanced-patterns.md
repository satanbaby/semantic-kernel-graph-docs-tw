# 進階模式示例

本範例展示了 Semantic Kernel Graph 中進階架構模式的全面整合，包括學術模式、機器學習優化和企業整合功能。

## 目標

了解如何在基於圖形的工作流中實現和協調進階模式，以：
* 配置並使用學術模式（Circuit Breaker、Bulkhead、Cache-Aside）
* 啟用基於機器學習的性能預測和異常檢測
* 為分佈式系統實現企業整合模式
* 在現實場景中協調多個模式
* 全面監視和診斷模式性能

## 必備條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 已在 `appsettings.json` 中配置
* 已安裝 **Semantic Kernel Graph 套件**
* 對 [Graph 概念](../concepts/graph-concepts.md) 和 [執行模型](../concepts/execution-model.md) 有基本瞭解
* 熟悉 [錯誤處理和恢復力](../how-to/error-handling-and-resilience.md)

## 主要組件

### 概念和技術

* **Academic Patterns**：包括 Circuit Breaker、Bulkhead 和 Cache-Aside 的企業級恢復力模式
* **Machine Learning Optimization**：使用歷史執行資料進行性能預測和異常檢測
* **Enterprise Integration**：訊息路由、基於內容的路由、發佈-訂閱和聚合模式
* **Pattern Orchestration**：多個模式的協調執行，並提供全面的診斷功能

### 核心類別

* `GraphExecutor`：透過 `WithAllAdvancedPatterns` 支持進階模式的增強執行器
* `AcademicPatterns`：Circuit breaker、bulkhead 和 cache-aside 實現
* `MachineLearningOptimizer`：性能預測和異常檢測引擎
* `EnterpriseIntegrationPatterns`：訊息路由和處理模式
* `GraphPerformanceMetrics`：全面的性能追蹤和分析

## 執行範例

### 快速開始

此範例使用 Semantic Kernel Graph 套件展示進階模式和優化。下面的程式碼片段展示了如何在您自己的應用程式中實現這些模式。

## 逐步實現

### 1. 建立進階圖形執行器

該範例首先建立一個啟用了所有進階模式的圖形執行器。

```csharp
// Create a GraphExecutor using the provided Kernel and a graph logger.
// This snippet configures a minimal, safe set of advanced patterns for demos.
var executor = new GraphExecutor(kernel, graphLogger);

// Enable the main academic resilience patterns with conservative defaults.
executor.WithAllAdvancedPatterns(config =>
{
    // Enable academic resilience patterns (circuit breaker, bulkhead, cache-aside).
    config.EnableAcademicPatterns = true;
    config.Academic.EnableCircuitBreaker = true;
    config.Academic.EnableBulkhead = true;
    config.Academic.EnableCacheAside = true;

    // Circuit breaker: trip after 3 failures and keep open briefly.
    config.Academic.CircuitBreakerOptions.FailureThreshold = 3;
    config.Academic.CircuitBreakerOptions.OpenTimeout = TimeSpan.FromSeconds(10);

    // Bulkhead: limit concurrency to avoid resource exhaustion in demos.
    config.Academic.BulkheadOptions.MaxConcurrency = 5;
    config.Academic.BulkheadOptions.AcquisitionTimeout = TimeSpan.FromSeconds(15);

    // Cache-aside: small in-memory cache for demo purposes.
    config.Academic.CacheAsideOptions.MaxCacheSize = 1000;
    config.Academic.CacheAsideOptions.DefaultTtl = TimeSpan.FromMinutes(10);
});
```

### 2. 學術模式展示

#### Circuit Breaker 模式

```csharp
// Execute a protected operation via the executor's circuit breaker helper.
// The operation should be an async delegate; a fallback is executed when the
// circuit is open or failures occur.
var circuitBreakerTest = await executor.ExecuteWithCircuitBreakerAsync(
    operation: async () =>
    {
        // Simulate some work
        await Task.Delay(100);
        Console.WriteLine("Operation executed successfully");
        return "Success";
    },
    fallback: async () =>
    {
        // Minimal fallback implementation for demos
        Console.WriteLine("Fallback operation executed");
        return "Fallback";
    });
```

#### Bulkhead 模式

```csharp
// Run several operations in parallel using the bulkhead to protect resources.
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

#### Cache-Aside 模式

```csharp
// Cache-aside pattern: loader is called on cache miss to populate the cache.
var cacheResult1 = await executor.GetOrSetCacheAsync(
    key: "user_profile_123",
    loader: async () =>
    {
        // Simulate slow data source (database)
        await Task.Delay(500);
        Console.WriteLine("Loading from database (cache miss)");
        return new { UserId = 123, Name = "John Doe", Email = "john@example.com" };
    });

// Second call should be a cache hit and not invoke the loader delegate.
var cacheResult2 = await executor.GetOrSetCacheAsync(
    key: "user_profile_123",
    loader: async () =>
    {
        // If this runs in your environment the cache did not work as expected.
        Console.WriteLine("Loader unexpectedly invoked on supposed cache hit");
        return new { UserId = 123, Name = "John Doe", Email = "john@example.com" };
    });
```

### 3. 進階優化

該範例展示了基於歷史指標的性能優化。

```csharp
// Create a small metrics object and simulate executions to produce sample data.
var metrics = new GraphPerformanceMetrics(new GraphMetricsOptions(), graphLogger);

for (int i = 0; i < 5; i++)
{
    var tracker = metrics.StartNodeTracking($"node_{i % 2}", $"TestNode{i % 2}", $"exec_{i}");
    await Task.Delay(Random.Shared.Next(50, 150));
    metrics.CompleteNodeTracking(tracker, success: true);
}

// Run a lightweight optimization analysis using the simulated metrics.
var optimizationResult = await executor.OptimizeAsync(metrics);
Console.WriteLine($"Analysis completed in {optimizationResult.AnalysisTime.TotalMilliseconds:F2}ms");
Console.WriteLine($"Total optimizations identified: {optimizationResult.TotalOptimizations}");
```

### 4. 機器學習優化

#### 性能預測

```csharp
// Prepare a small graph configuration for a prediction demo.
var graphConfig = new GraphConfiguration
{
    NodeCount = 8,
    AveragePathLength = 3.5,
    ConditionalNodeCount = 2,
    LoopNodeCount = 1,
    ParallelNodeCount = 2
};

// Request a performance prediction from the executor (requires ML enabled).
var prediction = await executor.PredictPerformanceAsync(graphConfig);
Console.WriteLine($"Predicted latency: {prediction.PredictedLatency.TotalMilliseconds:F2}ms");
Console.WriteLine($"Confidence: {prediction.Confidence:P2}");
Console.WriteLine($"Recommended optimizations: {prediction.RecommendedOptimizations.Count}");
```

#### 異常檢測

```csharp
// Example anomaly detection input (simulated metrics).
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
// Define a simple message routing rule that forwards 'OrderCreated' messages.
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

#### 處理不同的模式

```csharp
// Prepare a few sample enterprise messages for routing demonstration.
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

    // Message Router
    var routerContext = new ProcessingContext
    {
        ProcessingPattern = IntegrationPattern.MessageRouter,
        RoutingKey = message.Routing.RoutingKey,
        ProcessingTimeout = TimeSpan.FromSeconds(30)
    };

    var routerResult = await executor.ProcessEnterpriseMessageAsync(message, routerContext);
    Console.WriteLine($"Message Router: {(routerResult.Success ? "OK" : "FAIL")} ({routerResult.ProcessingTime.TotalMilliseconds:F2}ms)");

    // Content-Based Router
    var contentContext = new ProcessingContext
    {
        ProcessingPattern = IntegrationPattern.ContentBasedRouter,
        ProcessingTimeout = TimeSpan.FromSeconds(30)
    };

    var contentResult = await executor.ProcessEnterpriseMessageAsync(message, contentContext);
    Console.WriteLine($"Content Router: {(contentResult.Success ? "OK" : "FAIL")} ({contentResult.ProcessingTime.TotalMilliseconds:F2}ms)");

    // Publish-Subscribe
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

該範例以全面診斷所有模式來結束。

```csharp
// Run the comprehensive diagnostics routine and print a compact report.
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

該範例產生全面的輸出，顯示：

* ✅ 啟用了所有模式的進階圖形執行器建立
* 🎓 學術模式展示（Circuit Breaker、Bulkhead、Cache-Aside）
* ⚡ 進階優化分析，包含性能建議
* 🤖 機器學習訓練和性能預測
* 🏢 企業整合模式（訊息路由器、內容路由器、發佈-訂閱）
* 🔍 所有模式的全面診斷報告

## 疑難排解

### 常見問題

1. **Pattern Configuration Errors**：在呼叫 `WithAllAdvancedPatterns` 之前，請確保所有模式選項都已正確配置
2. **ML Training Failures**：檢查是否有足夠的歷史資料可用於訓練
3. **Integration Route Errors**：驗證訊息路由條件和目的地配置
4. **Performance Issues**：監視優化分析計時並根據需要調整閾值

### 偵錯提示

* 啟用詳細記錄以追蹤模式執行
* 使用全面診斷來識別配置問題
* 監視 circuit breaker 狀態和 bulkhead 併發限制
* 檢查快取命中率和 ML 模型訓練狀態

## 另請參閱

* [錯誤處理和恢復力](../how-to/error-handling-and-resilience.md)
* [資源治理和並行處理](../how-to/resource-governance-and-concurrency.md)
* [指標和可觀測性](../how-to/metrics-and-observability.md)
* [整合和擴充](../how-to/integration-and-extensions.md)
* [進階路由](../how-to/advanced-routing.md)
