# 指標 API 參考

本參考文件詳細記錄了 SemanticKernel.Graph 中的綜合指標和效能監控 API，這些 API 提供了關於圖形執行效能、資源使用和操作狀態的詳細見解。

## GraphPerformanceMetrics

圖形執行的綜合效能指標收集器。追蹤節點級別的指標、執行路徑、資源使用和效能指標。

### 屬性

* `TotalExecutions`：追蹤的圖形執行總數
* `Uptime`：指標收集啟動後經過的時間
* `NodeMetrics`：每個節點指標的字典
* `PathMetrics`：每個執行路徑指標的字典
* `CircuitBreakerMetrics`：每個節點的斷路器指標字典
* `ResourceUsage`：當前系統資源使用情況（CPU、記憶體）
* `LastSampleTime`：最後一次資源取樣的時間戳

### 方法

#### StartNodeTracking

```csharp
public NodeExecutionTracker StartNodeTracking(string nodeId, string nodeName, string executionId)
```

開始追蹤節點執行並返回完成追蹤器。

**參數：**
* `nodeId`：節點識別碼
* `nodeName`：節點名稱
* `executionId`：執行識別碼

**返回：** 完成追蹤的追蹤令牌

#### CompleteNodeTracking

```csharp
public void CompleteNodeTracking(NodeExecutionTracker tracker, bool success, object? result = null, Exception? exception = null)
```

完成節點執行追蹤並記錄指標。

**參數：**
* `tracker`：節點執行追蹤器
* `success`：執行是否成功
* `result`：執行結果（可選）
* `exception`：失敗時的異常（可選）

#### GetNodeMetrics

```csharp
// 指標收集器公開 NodeMetrics 字典。使用範例：
if (metrics.NodeMetrics.TryGetValue(nodeId, out var nodeMetrics))
{
    // nodeMetrics 是 NodeExecutionMetrics 實例
}
else
{
    // 未找到
}
```

從 `NodeMetrics` 屬性檢索特定節點的指標。

#### GetPerformanceSummary

```csharp
public GraphPerformanceSummary GetPerformanceSummary(TimeSpan timeWindow)
```

為指定的 `timeWindow` 生成具有聚合統計資料的綜合效能摘要。

**參數：**
- `timeWindow`：要分析的時間窗口（例如 `TimeSpan.FromMinutes(5)`）

**返回：** 包含關鍵指標的效能摘要

### 配置

```csharp
var options = new GraphMetricsOptions
{
    EnableResourceMonitoring = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(5),
    MaxSampleHistory = 10000,
    EnableDetailedPathTracking = true,
    EnablePercentileCalculations = true,
    MetricsRetentionPeriod = TimeSpan.FromHours(24)
};

var metrics = new GraphPerformanceMetrics(options);
```

## NodeExecutionMetrics

追蹤特定圖形節點的執行指標。提供關於節點效能和行為的詳細統計資料。

### 屬性

* `NodeId`：節點識別碼
* `NodeName`：節點名稱
* `TotalExecutions`：執行總次數
* `SuccessfulExecutions`：成功執行次數
* `FailedExecutions`：失敗執行次數
* `SuccessRate`：成功率百分比（0-100）
* `AverageExecutionTime`：平均執行時間
* `MinExecutionTime`：最小執行時間
* `MaxExecutionTime`：最大執行時間
* `FirstExecution`：第一次執行的時間戳
* `LastExecution`：最後一次執行的時間戳

### 方法

#### RecordExecution

```csharp
public void RecordExecution(TimeSpan duration, bool success, object? result = null, Exception? exception = null)
```

記錄單個執行及其結果和計時。

**參數：**
* `duration`：執行時間
* `success`：執行是否成功
* `result`：執行結果（可選）
* `exception`：失敗時的異常（可選）

#### GetPercentiles

```csharp
// NodeExecutionMetrics 提供單一百分位數的 GetPercentile 方法。
// 範例：獲取節點的 P95 執行時間
var p95 = nodeMetrics.GetPercentile(95);
```

計算節點的單個執行時間百分位數（例如 P50、P95、P99）。

**參數：**
- `percentile`：百分位值（0-100）

**返回：** 在要求的百分位處的執行時間（TimeSpan）

## OpenTelemetry 計量整合

SemanticKernel.Graph 與 OpenTelemetry 的 `Meter` 整合，以進行標準化的指標收集和匯出。

### 計量配置

```csharp
// 框架使用的預設計量名稱
var streamingMeter = new Meter("SemanticKernel.Graph.Streaming", "1.0.0");
var distributionMeter = new Meter("SemanticKernel.Graph.Distribution", "1.0.0");
var agentPoolMeter = new Meter("skg.agent_pool", "1.0.0");
```

### 指標工具

#### 計數器

```csharp
// 帶標籤的事件計數器
var eventsCounter = meter.CreateCounter<long>("skg.stream.events", unit: "count", 
    description: "Total events emitted by the stream");

// 使用方式
eventsCounter.Add(1, new KeyValuePair<string, object?>("event_type", "NodeStarted"),
    new KeyValuePair<string, object?>("executionId", executionId),
    new KeyValuePair<string, object?>("graph", graphId),
    new KeyValuePair<string, object?>("node", nodeId));
```

#### 直方圖

```csharp
// 延遲直方圖
var eventLatencyMs = meter.CreateHistogram<double>("skg.stream.event.latency_ms", 
    unit: "ms", description: "Latency per event");

// 負載大小直方圖
var serializedPayloadBytes = meter.CreateHistogram<long>("skg.stream.event.payload_bytes", 
    unit: "bytes", description: "Serialized payload size per event");

// 使用方式
eventLatencyMs.Record(elapsedMs, new KeyValuePair<string, object?>("event_type", "NodeCompleted"),
    new KeyValuePair<string, object?>("executionId", executionId),
    new KeyValuePair<string, object?>("graph", graphId),
    new KeyValuePair<string, object?>("node", nodeId));
```

### 標準指標標籤

SemanticKernel.Graph 中的所有指標都使用一致的標籤進行關聯和篩選：

#### 核心標籤

* **`executionId`**：每次圖形執行的唯一識別碼
* **`graph`**：圖形定義的穩定識別碼
* **`node`**：特定節點的穩定識別碼
* **`event_type`**：正在測量的事件或操作的類型

#### 額外的上下文標籤

* **`workflow.id`**：多代理工作流程識別碼
* **`workflow.name`**：人類可讀的工作流程名稱
* **`agent.id`**：多代理場景中的代理識別碼
* **`operation.type`**：正在執行的操作類型
* **`compressed`**：是否應用了資料壓縮
* **`memory_mapped`**：是否使用了記憶體對應緩衝區

### 指標命名慣例

指標遵循分層命名模式：

```
skg.{component}.{metric_name}
```

範例：
* `skg.stream.events` - 串流事件計數器
* `skg.stream.event.latency_ms` - 事件延遲直方圖
* `skg.stream.event.payload_bytes` - 事件負載大小直方圖
* `skg.stream.producer.flush_ms` - 製作者緩衝區排清延遲
* `skg.agent_pool.connections` - 代理池連線計數器
* `skg.work_distributor.tasks` - 工作分發工作計數器

## 串流指標

### 事件串流指標

```csharp
var options = new StreamingExecutionOptions
{
    EnableMetrics = true,
    MetricsMeterName = "MyApp.GraphExecution"
};

// executor 可能是 IStreamingGraphExecutor（例如 StreamingGraphExecutor）
var stream = executor.ExecuteStreamAsync(kernel, args, options);
```

**可用指標：**
* `skg.stream.events` - 發出的事件總數（計數器）
* `skg.stream.event.latency_ms` - 事件處理延遲（直方圖）
* `skg.stream.event.payload_bytes` - 序列化負載大小（直方圖）
* `skg.stream.producer.flush_ms` - 製作者緩衝區排清延遲（直方圖）

### 連線池指標

```csharp
var poolOptions = new StreamingPoolOptions
{
    EnableMetrics = true,
    MetricsMeterName = "MyApp.StreamingPool"
};
```

**可用指標：**
* `skg.stream.pool.connections` - 活躍連線（計數器）
* `skg.stream.pool.requests` - 要求計數（計數器）
* `skg.stream.pool.latency_ms` - 要求延遲（直方圖）

## 多代理指標

### 代理池指標

```csharp
var agentOptions = new AgentConnectionPoolOptions
{
    EnableMetrics = true,
    MetricsMeterName = "skg.agent_pool"
};
```

**可用指標：**
* `skg.agent_pool.connections` - 活躍代理連線（計數器）
* `skg.agent_pool.requests` - 要求計數（計數器）
* `skg.agent_pool.latency_ms` - 要求延遲（直方圖）

### 工作分發指標

```csharp
var distributorOptions = new WorkDistributorOptions
{
    EnableMetrics = true,
    MetricsMeterName = "skg.work_distributor"
};
```

**可用指標：**
* `skg.work_distributor.tasks` - 工作計數（計數器）
* `skg.work_distributor.latency_ms` - 工作分發延遲（直方圖）
* `skg.work_distributor.queue_size` - 佇列大小（量測）

## 效能監控

### 資源監控

```csharp
var metricsOptions = new GraphMetricsOptions
{
    EnableResourceMonitoring = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(5)
};

var metrics = new GraphPerformanceMetrics(metricsOptions);
```

**監控的資源：**
* CPU 使用百分比
* 可用記憶體（MB）
* 處理程序處理器時間
* 系統負載指標

### 執行路徑分析

```csharp
// GraphPerformanceMetrics 公開 PathMetrics 字典。範例查詢：
if (metrics.PathMetrics.TryGetValue("path_signature", out var pathMetrics))
{
    var avgTime = pathMetrics.AverageExecutionTime;
    var successRate = pathMetrics.SuccessRate;
    var executionCount = pathMetrics.ExecutionCount;
}
```

**路徑指標：**
* 每個路徑的執行計數
* 成功/失敗率
* 平均執行時間
* 特定路徑的效能趨勢

## 指標匯出和視覺化

### 匯出格式

```csharp
var exporter = new GraphMetricsExporter();
var jsonMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Json, TimeSpan.FromHours(1));
var prometheusMetrics = exporter.ExportMetrics(metrics, MetricsExportFormat.Prometheus, TimeSpan.FromHours(1));
```

### 儀表板整合

```csharp
var dashboard = new MetricsDashboard();
dashboard.RegisterExecution(executionContext, metrics);

var heatmap = dashboard.GeneratePerformanceHeatmap(metrics, visualizationData);
var summary = dashboard.ExportMetricsForVisualization(metrics, MetricsExportFormat.Json);
```

## 配置範例

### 開發環境

```csharp
var devOptions = GraphMetricsOptions.CreateDevelopmentOptions();
// 高頻率取樣、詳細追蹤、短期保留
```

### 生產環境

```csharp
var prodOptions = GraphMetricsOptions.CreateProductionOptions();
// 平衡的取樣、全面的追蹤、延長的保留
```

### 效能臨界情況

```csharp
var minimalOptions = GraphMetricsOptions.CreateMinimalOptions();
// 最小開銷、基本指標、短期保留
```

## 最佳實踐

### 指標標籤

1. **一致的標籤**：始終使用標準標籤集（`executionId`、`graph`、`node`）
2. **基數管理**：避免可能導致指標系列爆炸的高基數標籤
3. **語義命名**：使用有助於除錯和分析的描述性標籤值

### 效能考量

1. **取樣**：為資源監控使用適當的取樣間隔
2. **保留**：平衡歷史資料需求和記憶體使用
3. **匯出頻率**：根據監控要求設定匯出間隔

### 整合

1. **OpenTelemetry**：利用內建的 OpenTelemetry 整合進行標準可觀測性
2. **自訂指標**：使用相同的標籤模式擴展應用程式特定的指標
3. **告警**：使用指標閾值進行主動監控和告警

## 另請參閱

* [指標和可觀測性指南](../how-to/metrics-and-observability.md) - 綜合可觀測性指南
* [指標快速入門](../metrics-logging-quickstart.md) - 開始使用指標和日誌
* [串流 API 參考](./streaming.md) - 具有指標的串流執行
* [多代理參考](./multi-agent.md) - 多代理指標和監控
* [圖形選項參考](./graph-options.md) - 指標配置選項
