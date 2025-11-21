# GraphExecutor

`GraphExecutor` 類別是 Graph 執行的主要協調器，實作 `IGraphExecutor` 介面。它管理完整的執行流程、導航和 Graph Node 的協調，並提供全面的設定選項來控制效能、並行及資源治理。

## 概述

`GraphExecutor` 提供強大的、執行緒安全的執行引擎，具備內建防止無限迴圈的保護機制、可設定的效能監測，以及平行執行和資源治理等進階功能。它設計用於簡單工作流程和複雜的企業場景。

## 屬性

### 核心屬性

* **GraphId**: 此 Graph 實例的唯一識別碼
* **Name**: Graph 的人類可讀名稱
* **Description**: Graph 用途的詳細描述
* **CreatedAt**: Graph 建立時的時間戳記
* **StartNode**: 用於執行的已設定起始 Node（可為 null）
* **Nodes**: Graph 中所有 Node 的唯讀集合
* **Edges**: 所有條件 Edge 的唯讀集合
* **NodeCount**: Graph 中 Node 的總數
* **EdgeCount**: Graph 中 Edge 的總數

### 執行狀態

* **IsReadyForExecution**: 指示 Graph 是否已準備好執行（具有 Node 和起始 Node）

## 設定方法

### 指標設定

為 Graph 設定效能指標收集：

```csharp
GraphExecutor ConfigureMetrics(GraphMetricsOptions? options = null)
```

**參數：**
* `options`: 指標收集選項（null 表示停用指標）

**傳回值：** 此執行器用於方法鏈結

**範例：**
```csharp
var executor = new GraphExecutor("MyGraph");
executor.ConfigureMetrics(new GraphMetricsOptions
{
    EnableRealTimeMetrics = true,
    MetricsRetentionPeriod = TimeSpan.FromHours(24),
    EnablePercentileCalculations = true
});
```

### 並行設定

設定平行執行行為：

```csharp
GraphExecutor ConfigureConcurrency(GraphConcurrencyOptions? options)
```

**參數：**
* `options`: 並行選項（null 停用平行執行）

**傳回值：** 此執行器用於方法鏈結

**範例：**
```csharp
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount * 2,
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond
});
```

### 資源治理設定

設定資源限制和 QoS 行為：

```csharp
GraphExecutor ConfigureResources(GraphResourceOptions? options)
```

**參數：**
* `options`: 資源治理選項（null 停用資源治理）

**傳回值：** 此執行器用於方法鏈結

**範例：**
```csharp
executor.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 100.0,
    MaxBurstSize = 200,
    CpuHighWatermarkPercent = 85.0,
    MinAvailableMemoryMB = 1024.0
});
```

### 自我修復設定

設定 Node 故障自動復原：

```csharp
GraphExecutor ConfigureSelfHealing(SelfHealingOptions options)
```

**參數：**
* `options`: 自我修復設定選項

**傳回值：** 此執行器用於方法鏈結

## 執行方法

### 主要執行

從已設定的起始 Node 執行 Graph：

```csharp
Task<FunctionResult> ExecuteAsync(
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`: 用於函式解析的 Semantic Kernel 實例
* `arguments`: 執行狀態和輸入
* `cancellationToken`: 取消權杖

**傳回值：** 最終執行結果

**例外狀況：**
* `ArgumentNullException`: 當 kernel 或 arguments 為 null 時
* `InvalidOperationException`: 當 Graph 未準備好執行時
* `OperationCanceledException`: 當執行被取消時

### 從特定 Node 執行

從特定 Node 實例開始執行：

```csharp
Task<FunctionResult> ExecuteFromNodeAsync(
    IGraphNode startNode,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `startNode`: 要開始執行的 Node 實例
* `kernel`: Semantic Kernel 實例
* `arguments`: 執行狀態和輸入
* `cancellationToken`: 取消權杖

**傳回值：** 最終執行結果

**例外狀況：**
* `ArgumentNullException`: 當任何參數為 null 時
* `InvalidOperationException`: 當 startNode 不屬於此 Graph 時

### 從 Node ID 執行

從 ID 識別的 Node 開始執行：

```csharp
Task<FunctionResult> ExecuteFromAsync(
    Kernel kernel,
    KernelArguments arguments,
    string startNodeId,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`: Semantic Kernel 實例
* `arguments`: 執行狀態和輸入
* `startNodeId`: 要開始的 Node 的 ID
* `cancellationToken`: 取消權杖

**傳回值：** 最終執行結果

**例外狀況：**
* `ArgumentNullException`: 當 kernel 或 arguments 為 null 時
* `ArgumentException`: 當 startNodeId 無效時
* `InvalidOperationException`: 當找不到起始 Node 時

### Node 執行

獨立執行單一 Node：

```csharp
Task<FunctionResult> ExecuteNodeAsync(
    IGraphNode node,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `node`: 要執行的 Node
* `kernel`: Semantic Kernel 實例
* `arguments`: 執行狀態和輸入
* `cancellationToken`: 取消權杖

**傳回值：** Node 執行結果

### Graph 執行

執行自訂的 Node 序列：

```csharp
Task<FunctionResult> ExecuteGraphAsync(
    IEnumerable<IGraphNode> nodes,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `nodes`: 要執行的已排序 Node 序列
* `kernel`: Semantic Kernel 實例
* `arguments`: 執行狀態和輸入
* `cancellationToken`: 取消權杖

**傳回值：** 最終執行結果

## 驗證和完整性

### Graph 驗證

驗證 Graph 的結構完整性：

```csharp
ValidationResult ValidateGraphIntegrity()
```

**傳回值：** 包含錯誤和警告的驗證結果

**驗證檢查：**
* Graph 至少包含一個 Node
* 起始 Node 已設定
* 所有 Node 有效
* 所有 Edge 有效
* Edge 間的結構相容性
* 無法到達的 Node（啟用嚴格模式時）

**範例：**
```csharp
var validationResult = executor.ValidateGraphIntegrity();
if (!validationResult.IsValid)
{
    Console.WriteLine($"Graph validation failed: {validationResult.CreateSummary()}");
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"Error: {error}");
    }
}
```

## Graph 建構

### 新增 Node

將 Node 新增至 Graph：

```csharp
GraphExecutor AddNode(IGraphNode node)
```

**參數：**
* `node`: 要新增的 Node

**傳回值：** 此執行器用於方法鏈結

**範例：**
```csharp
executor.AddNode(new FunctionGraphNode(myFunction, "processData"))
       .AddNode(new ConditionalGraphNode("validate", "Validate input"))
       .AddNode(new FunctionGraphNode(outputFunction, "generateOutput"));
```

### 連接 Node

在 Node 之間建立條件 Edge：

```csharp
GraphExecutor Connect(string sourceNodeId, string targetNodeId, string? edgeName = null)
```

**參數：**
* `sourceNodeId`: 來源 Node 識別碼
* `targetNodeId`: 目標 Node 識別碼
* `edgeName`: Edge 的選擇性名稱

**傳回值：** 此執行器用於方法鏈結

**範例：**
```csharp
executor.Connect("start", "processData")
       .Connect("processData", "validate")
       .Connect("validate", "generateOutput", "success")
       .Connect("validate", "errorHandler", "failure");
```

### 設定起始 Node

設定執行起點：

```csharp
GraphExecutor SetStartNode(string nodeId)
```

**參數：**
* `nodeId`: 要開始執行的 Node 的 ID

**傳回值：** 此執行器用於方法鏈結

**例外狀況：**
* `ArgumentException`: 當 nodeId 為 null 或空白時
* `InvalidOperationException`: 當找不到該 Node 時

## 中介軟體支援

### 新增中介軟體

使用自訂中介軟體擴展執行行為：

```csharp
GraphExecutor UseMiddleware(IGraphExecutionMiddleware middleware)
```

**參數：**
* `middleware`: 要新增的中介軟體實例

**傳回值：** 此執行器用於方法鏈結

**範例：**
```csharp
executor.UseMiddleware(new LoggingMiddleware())
       .UseMiddleware(new MetricsMiddleware())
       .UseMiddleware(new CustomBusinessLogicMiddleware());
```

## 執行緒安全

`GraphExecutor` 設計為執行緒安全：

* **Node 集合**: 由 `ConcurrentDictionary<TKey, TValue>` 保護
* **Edge 變異**: 由私有鎖保護以確保一致性
* **公開方法**: 驗證輸入並拋擲適當的例外狀況
* **執行**: 尊重 `CancellationToken` 並傳播取消
* **重複使用**: 實例可安全地跨執行重複使用

## 效能和可觀測性

### 內建追蹤

* **ActivitySource**: 使用 `ActivitySource` 自動分散式追蹤
* **執行標籤**: 用於相關和偵錯的豐富中繼資料
* **效能指標**: 選擇性詳細效能追蹤

### 事件系統

Graph 變異事件用於監控和整合：

* **NodeAdded**: 成功新增 Node 後引發
* **NodeRemoved**: 成功移除 Node 後引發
* **NodeReplaced**: 當 Node 被取代時引發
* **EdgeAdded**: 成功新增 Edge 後引發
* **EdgeRemoved**: 成功移除 Edge 後引發

## 使用範例

### 基本 Graph 建構

```csharp
// Create a minimal kernel and lightweight kernel functions used by function nodes
var kernel = Kernel.CreateBuilder().Build();

var loadFn = KernelFunctionFactory.CreateFromMethod((KernelArguments a) =>
{
    // Simulate loading data
    return "loaded data";
}, "LoadData");

var processFn = KernelFunctionFactory.CreateFromMethod((KernelArguments a) =>
{
    // Simulate processing
    return "processed data";
}, "ProcessData");

var saveFn = KernelFunctionFactory.CreateFromMethod((KernelArguments a) =>
{
    // Simulate saving
    return "saved data";
}, "SaveData");

// Build executor and nodes
var executor = new GraphExecutor("DataProcessingGraph", "Process and validate data");

executor.AddNode(new FunctionGraphNode(loadFn, "loadData"))
        .AddNode(new FunctionGraphNode(processFn, "processData"))
        .AddNode(new ConditionalGraphNode("validate", "Validate processed data"))
        .AddNode(new FunctionGraphNode(saveFn, "saveData"));

// Connect nodes and set start node
executor.Connect("loadData", "processData")
        .Connect("processData", "validate")
        .Connect("validate", "saveData", "valid")
        .Connect("validate", "errorHandler", "invalid");

executor.SetStartNode("loadData");

// Prepare kernel arguments and execute
var args = new KernelArguments();
var result = await executor.ExecuteAsync(kernel, args);
```

### 進階設定

```csharp
var executor = new GraphExecutor("EnterpriseGraph", "High-performance enterprise workflow");

// Configure comprehensive metrics
executor.ConfigureMetrics(new GraphMetricsOptions
{
    EnableRealTimeMetrics = true,
    MetricsRetentionPeriod = TimeSpan.FromDays(7),
    EnablePercentileCalculations = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(5)
});

// Configure parallel execution
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount * 2,
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = true
});

// Configure resource governance
executor.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 200.0,
    MaxBurstSize = 500,
    CpuHighWatermarkPercent = 80.0,
    MinAvailableMemoryMB = 2048.0,
    EnableCooperativePreemption = true
});

// Configure self-healing
executor.ConfigureSelfHealing(new SelfHealingOptions
{
    EnableAutomaticRecovery = true,
    MaxRetryAttempts = 3,
    QuarantineFailedNodes = true
});
```

## 相關類型

* **IGraphExecutor**: 介面契約
* **GraphExecutionContext**: 執行狀態和協調
* **GraphExecutionOptions**: 不可變執行設定
* **GraphMetricsOptions**: 效能指標設定
* **GraphConcurrencyOptions**: 平行執行設定
* **GraphResourceOptions**: 資源治理設定
* **ValidationResult**: Graph 驗證結果

## 另請參閱

* [IGraphExecutor](igraph-executor.md) - 介面契約和語意
* [Execution Model](../concepts/execution-model.md) - 執行如何流過 Graph
* [Resource Governance and Concurrency](../how-to/resource-governance-and-concurrency.md) - 進階設定
* [Parallelism and Fork/Join](../how-to/parallelism-and-fork-join.md) - 平行執行模式
* [Getting Started](../getting-started.md) - 建立您的第一個 Graph
