# GraphExecutor

`GraphExecutor` 類別是圖形執行的主要編排器，實現 `IGraphExecutor` 介面。它管理完整的執行流程、導航和圖形節點的協調，具有針對效能、並行性和資源治理的全面配置選項。

## 概述

`GraphExecutor` 提供了一個強大的、執行緒安全的執行引擎，具有針對無限迴圈的內建保障、可設定的效能監視和進階功能，例如平行執行和資源治理。它適用於簡單工作流程和複雜的企業場景。

## 屬性

### 核心屬性

* **GraphId**：此圖形執行個體的唯一識別碼
* **Name**：圖形的人類可讀名稱
* **Description**：圖形功能的詳細說明
* **CreatedAt**：建立圖形時的時間戳
* **StartNode**：為執行配置的起始節點（可為 null）
* **Nodes**：圖形中所有節點的唯讀集合
* **Edges**：所有條件邊的唯讀集合
* **NodeCount**：圖形中的節點總數
* **EdgeCount**：圖形中的邊總數

### 執行狀態

* **IsReadyForExecution**：指示圖形是否準備好執行（具有節點和起始節點）

## 設定方法

### 指標設定

配置圖形的效能指標集合：

```csharp
GraphExecutor ConfigureMetrics(GraphMetricsOptions? options = null)
```

**參數：**
* `options`：指標集合選項（null 以停用指標）

**返回：** 用於方法鏈結的此執行器

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

### 並行性設定

配置平行執行行為：

```csharp
GraphExecutor ConfigureConcurrency(GraphConcurrencyOptions? options)
```

**參數：**
* `options`：並行性選項（null 停用平行執行）

**返回：** 用於方法鏈結的此執行器

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

配置資源限制和 QoS 行為：

```csharp
GraphExecutor ConfigureResources(GraphResourceOptions? options)
```

**參數：**
* `options`：資源治理選項（null 停用資源治理）

**返回：** 用於方法鏈結的此執行器

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

配置從節點故障自動復原：

```csharp
GraphExecutor ConfigureSelfHealing(SelfHealingOptions options)
```

**參數：**
* `options`：自我修復組態選項

**返回：** 用於方法鏈結的此執行器

## 執行方法

### 主要執行

從配置的起始節點執行圖形：

```csharp
Task<FunctionResult> ExecuteAsync(
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`：用於函式解析的 Semantic Kernel 執行個體
* `arguments`：執行狀態和輸入
* `cancellationToken`：取消權杖

**返回：** 最終執行結果

**例外：**
* `ArgumentNullException`：當核心或引數為 null 時
* `InvalidOperationException`：當圖形未準備好執行時
* `OperationCanceledException`：當執行被取消時

### 從特定節點執行

從特定節點執行個體開始執行：

```csharp
Task<FunctionResult> ExecuteFromNodeAsync(
    IGraphNode startNode,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `startNode`：開始執行的節點執行個體
* `kernel`：Semantic Kernel 執行個體
* `arguments`：執行狀態和輸入
* `cancellationToken`：取消權杖

**返回：** 最終執行結果

**例外：**
* `ArgumentNullException`：當任何參數為 null 時
* `InvalidOperationException`：當 startNode 不是圖形的一部分時

### 從節點 ID 執行

從節點 ID 識別的節點開始執行：

```csharp
Task<FunctionResult> ExecuteFromAsync(
    Kernel kernel,
    KernelArguments arguments,
    string startNodeId,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`：Semantic Kernel 執行個體
* `arguments`：執行狀態和輸入
* `startNodeId`：要開始的節點 ID
* `cancellationToken`：取消權杖

**返回：** 最終執行結果

**例外：**
* `ArgumentNullException`：當核心或引數為 null 時
* `ArgumentException`：當 startNodeId 無效時
* `InvalidOperationException`：當找不到起始節點時

### 節點執行

單獨執行單一節點：

```csharp
Task<FunctionResult> ExecuteNodeAsync(
    IGraphNode node,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `node`：要執行的節點
* `kernel`：Semantic Kernel 執行個體
* `arguments`：執行狀態和輸入
* `cancellationToken`：取消權杖

**返回：** 節點執行結果

### 圖形執行

執行自訂節點序列：

```csharp
Task<FunctionResult> ExecuteGraphAsync(
    IEnumerable<IGraphNode> nodes,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `nodes`：要執行的節點有序序列
* `kernel`：Semantic Kernel 執行個體
* `arguments`：執行狀態和輸入
* `cancellationToken`：取消權杖

**返回：** 最終執行結果

## 驗證和完整性

### 圖形驗證

驗證圖形的結構完整性：

```csharp
ValidationResult ValidateGraphIntegrity()
```

**返回：** 具有錯誤和警告的驗證結果

**驗證檢查：**
* 圖形至少包含一個節點
* 起始節點已配置
* 所有節點都有效
* 所有邊都有效
* 各邊間的結構描述相容性
* 無法到達的節點（啟用嚴格模式時）

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

## 圖形構建

### 新增節點

將節點新增至圖形：

```csharp
GraphExecutor AddNode(IGraphNode node)
```

**參數：**
* `node`：要新增的節點

**返回：** 用於方法鏈結的此執行器

**範例：**
```csharp
executor.AddNode(new FunctionGraphNode(myFunction, "processData"))
       .AddNode(new ConditionalGraphNode("validate", "Validate input"))
       .AddNode(new FunctionGraphNode(outputFunction, "generateOutput"));
```

### 連接節點

建立節點之間的條件邊：

```csharp
GraphExecutor Connect(string sourceNodeId, string targetNodeId, string? edgeName = null)
```

**參數：**
* `sourceNodeId`：來源節點識別碼
* `targetNodeId`：目標節點識別碼
* `edgeName`：邊的選擇性名稱

**返回：** 用於方法鏈結的此執行器

**範例：**
```csharp
executor.Connect("start", "processData")
       .Connect("processData", "validate")
       .Connect("validate", "generateOutput", "success")
       .Connect("validate", "errorHandler", "failure");
```

### 設定起始節點

配置執行起始點：

```csharp
GraphExecutor SetStartNode(string nodeId)
```

**參數：**
* `nodeId`：開始執行的節點 ID

**返回：** 用於方法鏈結的此執行器

**例外：**
* `ArgumentException`：當 nodeId 為 null 或空白時
* `InvalidOperationException`：當找不到節點時

## 中介軟體支援

### 新增中介軟體

使用自訂中介軟體擴充執行行為：

```csharp
GraphExecutor UseMiddleware(IGraphExecutionMiddleware middleware)
```

**參數：**
* `middleware`：要新增的中介軟體執行個體

**返回：** 用於方法鏈結的此執行器

**範例：**
```csharp
executor.UseMiddleware(new LoggingMiddleware())
       .UseMiddleware(new MetricsMiddleware())
       .UseMiddleware(new CustomBusinessLogicMiddleware());
```

## 執行緒安全

`GraphExecutor` 設計用於執行緒安全：

* **節點集合**：由 `ConcurrentDictionary<TKey, TValue>` 保護
* **邊變動**：由私人鎖保護以確保一致性
* **公用方法**：驗證輸入並擲回適當的例外
* **執行**：榮幸 `CancellationToken` 並傳播取消
* **重用**：執行個體在多次執行中安全重用

## 效能和可觀測性

### 內建追蹤

* **ActivitySource**：使用 `ActivitySource` 自動分散式追蹤
* **執行標記**：用於關聯和偵錯的豐富中繼資料
* **效能指標**：選擇性詳細效能追蹤

### 事件系統

圖形變動事件以進行監視和整合：

* **NodeAdded**：在成功新增節點後引發
* **NodeRemoved**：在成功移除節點後引發
* **NodeReplaced**：在取代節點時引發
* **EdgeAdded**：在成功新增邊後引發
* **EdgeRemoved**：在成功移除邊後引發

## 使用範例

### 基本圖形構建

```csharp
// 建立最小核心和函式節點使用的輕量級核心函式
var kernel = Kernel.CreateBuilder().Build();

var loadFn = KernelFunctionFactory.CreateFromMethod((KernelArguments a) =>
{
    // 模擬載入資料
    return "loaded data";
}, "LoadData");

var processFn = KernelFunctionFactory.CreateFromMethod((KernelArguments a) =>
{
    // 模擬處理
    return "processed data";
}, "ProcessData");

var saveFn = KernelFunctionFactory.CreateFromMethod((KernelArguments a) =>
{
    // 模擬儲存
    return "saved data";
}, "SaveData");

// 構建執行器和節點
var executor = new GraphExecutor("DataProcessingGraph", "Process and validate data");

executor.AddNode(new FunctionGraphNode(loadFn, "loadData"))
        .AddNode(new FunctionGraphNode(processFn, "processData"))
        .AddNode(new ConditionalGraphNode("validate", "Validate processed data"))
        .AddNode(new FunctionGraphNode(saveFn, "saveData"));

// 連接節點並設定起始節點
executor.Connect("loadData", "processData")
        .Connect("processData", "validate")
        .Connect("validate", "saveData", "valid")
        .Connect("validate", "errorHandler", "invalid");

executor.SetStartNode("loadData");

// 準備核心引數並執行
var args = new KernelArguments();
var result = await executor.ExecuteAsync(kernel, args);
```

### 進階組態

```csharp
var executor = new GraphExecutor("EnterpriseGraph", "High-performance enterprise workflow");

// 配置全面指標
executor.ConfigureMetrics(new GraphMetricsOptions
{
    EnableRealTimeMetrics = true,
    MetricsRetentionPeriod = TimeSpan.FromDays(7),
    EnablePercentileCalculations = true,
    ResourceSamplingInterval = TimeSpan.FromSeconds(5)
});

// 配置平行執行
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount * 2,
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = true
});

// 配置資源治理
executor.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 200.0,
    MaxBurstSize = 500,
    CpuHighWatermarkPercent = 80.0,
    MinAvailableMemoryMB = 2048.0,
    EnableCooperativePreemption = true
});

// 配置自我修復
executor.ConfigureSelfHealing(new SelfHealingOptions
{
    EnableAutomaticRecovery = true,
    MaxRetryAttempts = 3,
    QuarantineFailedNodes = true
});
```

## 相關類型

* **IGraphExecutor**：介面契約
* **GraphExecutionContext**：執行狀態和協調
* **GraphExecutionOptions**：不可變執行組態
* **GraphMetricsOptions**：效能指標組態
* **GraphConcurrencyOptions**：平行執行組態
* **GraphResourceOptions**：資源治理組態
* **ValidationResult**：圖形驗證結果

## 另請參閱

* [IGraphExecutor](igraph-executor.md) - 介面契約和語意
* [執行模型](../concepts/execution-model.md) - 執行如何流經圖形
* [資源治理和並行性](../how-to/resource-governance-and-concurrency.md) - 進階組態
* [平行性和分叉/聯接](../how-to/parallelism-and-fork-join.md) - 平行執行模式
* [開始使用](../getting-started.md) - 構建您的第一個圖形
