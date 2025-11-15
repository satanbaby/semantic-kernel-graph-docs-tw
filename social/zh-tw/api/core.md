# 核心 API

核心 API 提供了 SemanticKernel.Graph 的基礎構建塊，包括主要的執行引擎、狀態管理和支援基於圖形工作流程的核心類型。

## 關鍵類型

### 核心執行
* **`GraphExecutor`** - 圖形執行的主要協調器，管理執行流程和協調
* **`GraphExecutionContext`** - 單個圖形運行的執行上下文，跟蹤進度和管理資源
* **`IGraphNode`** - 所有圖形節點的基本合約，定義基本結構和行為

### 狀態管理
* **`GraphState`** - KernelArguments 的型別化包裝器，作為圖形狀態基礎
* **`ConditionalEdge`** - 圖形節點之間的定向、可選保護的轉換
* **`StateMergeConflictPolicy`** - 平行執行期間狀態合併的衝突解決策略

### 錯誤處理和復原能力
* **`ErrorPolicyRegistry`** - 錯誤處理政策和策略的登錄表
* **`RetryPolicyGraphNode`** - 具有自動重試功能和可配置政策的節點包裝器
* **`ErrorHandlerGraphNode`** - 用於處理和恢復錯誤的專用節點
* **`ErrorMetricsCollector`** - 收集和跟蹤錯誤指標以進行監控和分析

### 多代理協調
* **`MultiAgentCoordinator`** - 為多代理執行協調多個圖形執行器實例
* **`ResultAggregator`** - 使用可配置策略聚合來自多個代理的結果
* **`AgentConnectionPool`** - 管理遠程代理通訊的連接和重用
* **`WorkDistributor`** - 使用各種策略在多個代理之間分配工作

### 驗證和編譯
* **`WorkflowValidator`** - 驗證工作流程完整性和結構正確性
* **`GraphTypeInferenceEngine`** - 推斷類型並驗證邊之間的架構相容性
* **`StateValidator`** - 驗證狀態完整性並解決衝突
* **`StateMergeConflictPolicy`** - 定義在合併期間如何解決衝突的狀態值

## 效能和指標

* **`GraphPerformanceMetrics`** - 綜合效能指標收集器
* **`NodeExecutionMetrics`** - 節點級執行統計
* **`GraphMetricsOptions`** - 指標配置選項
* **`GraphMetricsExporter`** - 指標導出和視覺化

有關詳細的指標文檔，請參閱 [指標 API 參考](./metrics.md)。

## 使用示例

以下是演示核心 API 類型的綜合示例：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;
using SemanticKernel.Graph.Execution;
using SemanticKernel.Graph.Integration.Policies;
using SemanticKernel.Graph.Integration;

// 建立並配置支援圖形的核心
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-4", "your-api-key")
    .AddGraphSupport()
    .Build();

// 使用配置建立圖形執行器
var executor = new GraphExecutor("MyWorkflow", "Sample workflow demonstration");

// 配置效能監控
executor.ConfigureMetrics(new GraphMetricsOptions
{
    EnableRealTimeMetrics = true,
    MetricsRetentionPeriod = TimeSpan.FromHours(1),
    EnablePercentileCalculations = true
});

// 配置並發選項
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    MaxDegreeOfParallelism = 4,
    EnableParallelExecution = true
});

// 建立並管理圖形狀態
var graphState = new GraphState();
graphState.KernelArguments["userName"] = "John Doe";
graphState.KernelArguments["currentStep"] = 1;

// 建立函數節點
var startNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string input) => $"Started: {input}",
        functionName: "StartProcess",
        description: "Starts the workflow"
    ),
    "startNode",
    "Workflow start point"
);

var processNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string input) => $"Processed: {input}",
        functionName: "ProcessData",
        description: "Processes the input data"
    ),
    "processNode",
    "Data processing node"
);

// 建立條件邊
var edge = new ConditionalEdge(
    startNode,
    processNode,
    (args) => args.GetValue<string>("input")?.Length > 0,
    "StartToProcess"
);

// 使用重試政策包裝節點
var retryConfig = new RetryPolicyConfig
{
    MaxRetries = 3,
    BaseDelay = TimeSpan.FromSeconds(1),
    Strategy = RetryStrategy.ExponentialBackoff,
    UseJitter = true
};

var retryNode = new RetryPolicyGraphNode(processNode, retryConfig);

// 建立多代理協調器
var multiAgentOptions = new MultiAgentOptions
{
    MaxConcurrentAgents = 5,
    CoordinationTimeout = TimeSpan.FromMinutes(10),
    SharedStateOptions = new SharedStateOptions
    {
        ConflictResolutionStrategy = ConflictResolutionStrategy.Merge,
        AllowOverwrite = true
    }
};

var coordinator = new MultiAgentCoordinator(multiAgentOptions);

// 新增節點到執行器並執行
executor.AddNode(startNode)
        .AddNode(retryNode)
        .SetStartNode("startNode");

var arguments = new KernelArguments();
arguments.SetGraphState(graphState);
arguments["input"] = "Hello World";

var result = await executor.ExecuteAsync(kernel, arguments);
Console.WriteLine($"Execution result: {result.GetValue<string>()}");
```

## 核心概念

### 圖形執行流程
1. **初始化**：建立 `GraphExecutor` 並配置選項
2. **節點建立**：建立 `FunctionGraphNode`、`ConditionalGraphNode` 或自訂節點
3. **邊定義**：為導航邏輯定義 `ConditionalEdge` 實例
4. **狀態管理**：使用 `GraphState` 進行持久執行狀態
5. **執行**：呼叫 `ExecuteAsync()` 運行完整工作流程

### 狀態管理
- `GraphState` 包裝 `KernelArguments` 以提供圖形特定的功能
- 執行期間狀態在所有節點之間共用
- 使用 `SetValue()` 和 `GetValue<T>()` 進行型別安全的狀態存取
- 狀態合併衝突使用 `StateMergeConflictPolicy` 解決

### 錯誤處理
- 使用 `RetryPolicyGraphNode` 包裝節點以進行自動重試
- 配置重試策略：固定延遲、指數退避、自訂邏輯
- 使用 `ErrorHandlerGraphNode` 進行專門的錯誤恢復
- 使用 `ErrorMetricsCollector` 監控錯誤

### 多代理協調
- `MultiAgentCoordinator` 管理多個執行器實例
- 配置工作分配策略：基於角色、基於負載、基於優先級
- 使用可配置的解決策略處理狀態衝突
- 使用共識、合併或自訂策略聚合結果

## 另請參閱

* [圖形概念](../concepts/graph-concepts.md) - 核心圖形概念和術語
* [執行模型](../concepts/execution-model.md) - 圖形執行的運作方式
* [節點類型](../concepts/node-types.md) - 可用的節點類型及其功能
* [建立圖形](../how-to/build-a-graph.md) - 建立圖形的逐步指南
* [錯誤處理和復原能力](../how-to/error-handling-and-resilience.md) - 錯誤政策和恢復
* [多代理和共用狀態](../how-to/multi-agent-and-shared-state.md) - 多代理協調
* [整合和擴展](../how-to/integration-and-extensions.md) - 擴展框架
* [指標和可觀測性](../how-to/metrics-and-observability.md) - 效能監控

請參閱源中的 XML 文件以獲得完整簽名和其他示例。
