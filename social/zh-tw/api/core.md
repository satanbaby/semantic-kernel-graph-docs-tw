# 核心 API

Core API 提供了 SemanticKernel.Graph 的基礎構件，包括主執行引擎、狀態管理以及能夠實現基於 Graph 工作流程的核心類型。

## 關鍵類型

### 核心執行
* **`GraphExecutor`** - Graph 執行的主編導者，管理執行流程和協調
* **`GraphExecutionContext`** - 單次 Graph 執行的執行上下文，追蹤進度並管理資源
* **`IGraphNode`** - 所有 Graph Node 的基礎契約，定義必要的結構和行為

### 狀態管理
* **`GraphState`** - KernelArguments 的型別化包裝器，作為 Graph 狀態基礎
* **`ConditionalEdge`** - Graph Node 之間有方向性的、可選受保護的轉移
* **`StateMergeConflictPolicy`** - 平行執行期間狀態合併的衝突解決策略

### 錯誤處理和復原力
* **`ErrorPolicyRegistry`** - 錯誤處理策略和策略的登錄表
* **`RetryPolicyGraphNode`** - 具有自動重試功能和可配置策略的 Node 包裝器
* **`ErrorHandlerGraphNode`** - 用於處理和從錯誤復原的專門 Node
* **`ErrorMetricsCollector`** - 收集和追蹤錯誤指標以進行監控和分析

### 多代理協調
* **`MultiAgentCoordinator`** - 協調多個 Graph executor 實例以進行多代理執行
* **`ResultAggregator`** - 使用可配置策略聚合來自多個代理的結果
* **`AgentConnectionPool`** - 管理遠端代理通訊的連線和重用
* **`WorkDistributor`** - 使用各種策略跨多個代理分配工作

### 驗證和編譯
* **`WorkflowValidator`** - 驗證工作流程完整性和結構正確性
* **`GraphTypeInferenceEngine`** - 推斷型別並驗證 Edge 間的架構相容性
* **`StateValidator`** - 驗證狀態完整性並解決衝突
* **`StateMergeConflictPolicy`** - 定義合併期間如何解決衝突的狀態值

## 效能和指標

* **`GraphPerformanceMetrics`** - 全面的效能指標收集器
* **`NodeExecutionMetrics`** - Node 層級的執行統計資訊
* **`GraphMetricsOptions`** - 指標配置選項
* **`GraphMetricsExporter`** - 指標匯出和視覺化

請參考[指標 API 參考](./metrics.md)以取得詳細的指標文件。

## 使用範例

以下是展示 Core API 類型的全面範例：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;
using SemanticKernel.Graph.Execution;
using SemanticKernel.Graph.Integration.Policies;
using SemanticKernel.Graph.Integration;

// 建立和設定具有 Graph 支援的 kernel
var kernel = Kernel.CreateBuilder()
    .AddOpenAIChatCompletion("gpt-4", "your-api-key")
    .AddGraphSupport()
    .Build();

// 建立具有配置的 Graph executor
var executor = new GraphExecutor("MyWorkflow", "Sample workflow demonstration");

// 配置效能監控
executor.ConfigureMetrics(new GraphMetricsOptions
{
    EnableRealTimeMetrics = true,
    MetricsRetentionPeriod = TimeSpan.FromHours(1),
    EnablePercentileCalculations = true
});

// 配置並行選項
executor.ConfigureConcurrency(new GraphConcurrencyOptions
{
    MaxDegreeOfParallelism = 4,
    EnableParallelExecution = true
});

// 建立和管理 Graph 狀態
var graphState = new GraphState();
graphState.KernelArguments["userName"] = "John Doe";
graphState.KernelArguments["currentStep"] = 1;

// 建立函式 Node
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

// 建立條件 Edge
var edge = new ConditionalEdge(
    startNode,
    processNode,
    (args) => args.GetValue<string>("input")?.Length > 0,
    "StartToProcess"
);

// 使用重試策略包裝 Node
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

// 將 Node 新增至 executor 並執行
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

### Graph 執行流程
1. **初始化**：建立 `GraphExecutor` 並配置選項
2. **Node 建立**：建立 `FunctionGraphNode`、`ConditionalGraphNode` 或自訂 Node
3. **Edge 定義**：為導覽邏輯定義 `ConditionalEdge` 實例
4. **狀態管理**：使用 `GraphState` 進行持久性執行狀態
5. **執行**：呼叫 `ExecuteAsync()` 執行完整工作流程

### 狀態管理
- `GraphState` 包裝 `KernelArguments` 以進行 Graph 特定功能
- 執行期間狀態在所有 Node 間共享
- 使用 `SetValue()` 和 `GetValue<T>()` 進行型別安全狀態存取
- 狀態合併衝突使用 `StateMergeConflictPolicy` 解決

### 錯誤處理
- 使用 `RetryPolicyGraphNode` 包裝 Node 以進行自動重試
- 配置重試策略：固定延遲、指數退避、自訂邏輯
- 使用 `ErrorHandlerGraphNode` 進行專門的錯誤復原
- 使用 `ErrorMetricsCollector` 監控錯誤

### 多代理協調
- `MultiAgentCoordinator` 管理多個 executor 實例
- 配置工作分配策略：角色型、負載型、優先權型
- 使用可配置的解決策略處理狀態衝突
- 使用共識、合併或自訂策略聚合結果

## 另請參閱

* [Graph 概念](../concepts/graph-concepts.md) - 核心 Graph 概念和術語
* [執行模型](../concepts/execution-model.md) - Graph 執行的原理
* [Node 類型](../concepts/node-types.md) - 可用的 Node 類型和其功能
* [建立 Graph](../how-to/build-a-graph.md) - 建立 Graph 的逐步指南
* [錯誤處理和復原力](../how-to/error-handling-and-resilience.md) - 錯誤策略和復原
* [多代理和共享狀態](../how-to/multi-agent-and-shared-state.md) - 多代理協調
* [整合和擴充](../how-to/integration-and-extensions.md) - 擴充框架
* [指標和可觀測性](../how-to/metrics-and-observability.md) - 效能監控

請參考源代碼中的 XML 文件以取得完整簽名和其他範例。
