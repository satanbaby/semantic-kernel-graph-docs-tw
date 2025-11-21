# IGraphNode

`IGraphNode` 介面定義了 SemanticKernel.Graph 中所有 Graph 節點的基本合約。它建立了每個節點必須實現的必要結構和行為，為構建複雜工作流程提供了一致的基礎。

## 概述

`IGraphNode` 是基於 Graph 的工作流程的基礎構建塊。它定義了使節點能夠參與執行、導航和生命週期管理的合約，同時保持對副作用的認知並在共享狀態上運行。

## 核心原則

實現此介面的節點應當：

* **具備副作用意識**：在 `GraphState` 中的 `KernelArguments` 上運行
* **驗證輸入**：使用 `ValidateExecution` 進行輕量級、非變更的驗證
* **使用生命週期鉤子**：優先選擇 `OnBeforeExecuteAsync` 和 `OnAfterExecuteAsync` 而非建構函式
* **遵守取消操作**：透過 `CancellationToken` 支援合作式取消

## 屬性

### 身份和元數據

* **NodeId**：此節點實例的唯一識別碼
* **Name**：用於顯示和記錄的人類可讀名稱
* **Description**：節點用途和行為的詳細描述
* **Metadata**：自訂元數據和配置的唯讀字典
* **IsExecutable**：表示節點是否可以執行

### 輸入/輸出合約

* **InputParameters**：此節點期望的參數名稱列表（用於接線的最佳努力提示）
* **OutputParameters**：此節點產生的參數名稱列表（應在版本間保持穩定）

## 執行方法

### 核心執行

執行節點的主要邏輯：

```csharp
Task<FunctionResult> ExecuteAsync(
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`：用於函式解析和服務的 Semantic Kernel 實例
* `arguments`：包含 Graph 狀態的執行參數
* `cancellationToken`：用於合作式取消的權杖

**返回值：** 節點執行的結果

**異常：**
* `ArgumentNullException`：當 kernel 或 arguments 為 null 時
* `InvalidOperationException`：當節點無法執行時

**指導方針：**
* 避免為預期的域錯誤拋出異常；改在結果中編碼失敗
* 保留異常用於真正異常的條件
* 對所有非同步操作遵守取消權杖

### 執行驗證

驗證節點是否可以使用提供的參數執行：

```csharp
ValidationResult ValidateExecution(KernelArguments arguments)
```

**參數：**
* `arguments`：要驗證的參數

**返回值：** 指示執行可行性的驗證結果

**異常：**
* `ArgumentNullException`：當 arguments 為 null 時

**指導方針：**
* 僅執行輕量級檢查；避免昂貴的操作
* 不要在驗證期間改變狀態
* 返回可操作的驗證訊息

## 導航方法

### 下一個節點發現

在執行後判定可能的下一個節點：

```csharp
IEnumerable<IGraphNode> GetNextNodes(
    FunctionResult? executionResult,
    GraphState graphState)
```

**參數：**
* `executionResult`：執行此節點的結果（可能為 null）
* `graphState`：目前的 Graph 狀態

**返回值：** 可能的下一個節點的集合

**異常：**
* `ArgumentNullException`：當 graphState 為 null 時

**指導方針：**
* 使用 `executionResult` 和/或 `graphState` 決定轉換
* 返回空集合以在適當時終止執行
* 考慮基於執行結果的條件路由

### 執行決策

根據目前狀態判定節點是否應該執行：

```csharp
bool ShouldExecute(GraphState graphState)
```

**參數：**
* `graphState`：目前的 Graph 狀態

**返回值：** 如果節點應該執行則為 True

**異常：**
* `ArgumentNullException`：當 graphState 為 null 時

**指導方針：**
* 此方法應該具確定性且無副作用
* 根據狀態條件做決策，不是外部因素
* 考慮必需參數、業務規則或條件邏輯

## 生命週期方法

### 執行前設置

在執行節點前呼叫：

```csharp
Task OnBeforeExecuteAsync(
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`：Semantic Kernel 實例
* `arguments`：執行參數
* `cancellationToken`：取消權杖

**返回值：** 代表設置操作的任務

**指導方針：**
* 僅執行冪等的設置操作
* 避免昂貴的 I/O 操作；優先在 `ExecuteAsync` 中進行工作
* 用於初始化、驗證和資源準備

### 執行後清理

在成功執行後呼叫：

```csharp
Task OnAfterExecuteAsync(
    Kernel kernel,
    KernelArguments arguments,
    FunctionResult result,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`：Semantic Kernel 實例
* `arguments`：執行參數
* `result`：執行結果
* `cancellationToken`：取消權杖

**返回值：** 代表清理操作的任務

**指導方針：**
* 避免從此方法拋出異常
* 優先選擇記錄和補償操作而非異常
* 用於清理、結果處理和狀態更新

### 錯誤處理

當執行失敗時呼叫：

```csharp
Task OnExecutionFailedAsync(
    Kernel kernel,
    KernelArguments arguments,
    Exception exception,
    CancellationToken cancellationToken = default)
```

**參數：**
* `kernel`：Semantic Kernel 實例
* `arguments`：執行參數
* `exception`：發生的異常
* `cancellationToken`：取消權杖

**返回值：** 代表錯誤處理操作的任務

**指導方針：**
* 執行清理、發出遙測或透過共享狀態請求重試
* 不得拋出異常，除非無法繼續恢復
* 考慮實現重試邏輯或回退策略

## 實現指導方針

### 狀態管理

* **共享狀態**：在 `GraphState` 中的 `KernelArguments` 上運行
* **不可變性**：避免在驗證期間修改狀態
* **一致性**：確保狀態更新是原子的和一致的

### 錯誤處理

* **優雅降級**：在可能時優雅地處理錯誤
* **記錄**：為除錯和監控提供詳細的記錄
* **恢復**：在適當的地方實現恢復策略

### 性能考量

* **輕量級驗證**：保持驗證操作快速和高效
* **非同步操作**：對 I/O 操作使用 async/await 模式
* **資源管理**：在生命週期方法中正確處置資源

## 使用範例

### 基本節點實現

```csharp
// 在 examples 資料夾中用作 `SimpleNodeExample.cs` 的最小化、經過測試的 IGraphNode 實現範例。
// 此類演示了安全的狀態訪問、輕量級驗證和生命週期鉤子。
// 註解使用英文，適合任何經驗層級的讀者。
public class SimpleNodeExample : IGraphNode
{
    public SimpleNodeExample()
    {
        NodeId = Guid.NewGuid().ToString();
        Name = "SimpleNodeExample";
        Description = "Processes an 'input' parameter and writes 'output' to the state.";
        Metadata = new Dictionary<string, object>();
    }

    public string NodeId { get; }
    public string Name { get; }
    public string Description { get; }
    public IReadOnlyDictionary<string, object> Metadata { get; }
    public bool IsExecutable => true;

    public IReadOnlyList<string> InputParameters => new[] { "input" };
    public IReadOnlyList<string> OutputParameters => new[] { "output" };

    /// <summary>
    /// ExecuteAsync processes the required 'input' value and stores a derived
    /// 'output' value back into the provided KernelArguments. It returns a
    /// FunctionResult constructed with a small in-memory KernelFunction.
    /// </summary>
    public async Task<FunctionResult> ExecuteAsync(Kernel kernel, KernelArguments arguments, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(kernel);
        ArgumentNullException.ThrowIfNull(arguments);

        // Safely read the 'input' value from the arguments
        var input = string.Empty;
        if (arguments.ContainsName("input") && arguments.TryGetValue("input", out var v) && v != null)
        {
            input = v.ToString() ?? string.Empty;
        }

        var output = $"Processed: {input}";

        // Store the computed output in the shared arguments so downstream nodes can use it
        arguments["output"] = output;

        // Create a small KernelFunction wrapper for the produced value and return it
        var tempFunction = KernelFunctionFactory.CreateFromMethod(() => output);
        var functionResult = new FunctionResult(tempFunction, output);

        await Task.CompletedTask; // preserve async signature
        return functionResult;
    }

    /// <summary>
    /// ValidateExecution performs a lightweight check to ensure the 'input' parameter exists.
    /// </summary>
    public ValidationResult ValidateExecution(KernelArguments arguments)
    {
        ArgumentNullException.ThrowIfNull(arguments);

        var result = new ValidationResult();
        if (!arguments.ContainsName("input") || arguments["input"] == null || string.IsNullOrEmpty(arguments["input"]?.ToString()))
        {
            result.AddError("Required parameter 'input' is missing or empty");
        }

        return result;
    }

    /// <summary>
    /// GetNextNodes returns no successors for this minimal example.
    /// </summary>
    public IEnumerable<IGraphNode> GetNextNodes(FunctionResult? executionResult, GraphState graphState)
    {
        ArgumentNullException.ThrowIfNull(graphState);
        return Enumerable.Empty<IGraphNode>();
    }

    /// <summary>
    /// ShouldExecute checks whether the provided GraphState contains a non-empty 'input'.
    /// </summary>
    public bool ShouldExecute(GraphState graphState)
    {
        ArgumentNullException.ThrowIfNull(graphState);
        return graphState.KernelArguments.ContainsName("input") && !string.IsNullOrEmpty(graphState.KernelArguments["input"]?.ToString());
    }

    public Task OnBeforeExecuteAsync(Kernel kernel, KernelArguments arguments, CancellationToken cancellationToken = default)
    {
        // No-op for this example; use for idempotent setup in real nodes
        return Task.CompletedTask;
    }

    public Task OnAfterExecuteAsync(Kernel kernel, KernelArguments arguments, FunctionResult result, CancellationToken cancellationToken = default)
    {
        // No-op for this example; use for cleanup or storing extra metadata
        return Task.CompletedTask;
    }

    public Task OnExecutionFailedAsync(Kernel kernel, KernelArguments arguments, Exception exception, CancellationToken cancellationToken = default)
    {
        // No-op for this example; real implementations should log or compensate
        return Task.CompletedTask;
    }
}
```

### 具備條件邏輯的進階節點

```csharp
// 條件路由節點範例（經過測試的 `ConditionalNodeExample.cs`）。
// 此節點本身不執行函式：它對 KernelArguments 評估謂詞並在條件符合時返回已設定的後繼節點。
public class ConditionalNodeExample : IGraphNode
{
    private readonly List<IGraphNode> _nextNodes = new();
    private readonly Func<KernelArguments, bool> _condition;

    public ConditionalNodeExample(string nodeId, string name, Func<KernelArguments, bool> condition)
    {
        NodeId = nodeId ?? Guid.NewGuid().ToString();
        Name = name ?? "ConditionalNodeExample";
        Description = "Conditional routing node";
        Metadata = new Dictionary<string, object>();
        IsExecutable = false; // This node only routes
        _condition = condition ?? throw new ArgumentNullException(nameof(condition));
    }

    public string NodeId { get; }
    public string Name { get; }
    public string Description { get; }
    public IReadOnlyDictionary<string, object> Metadata { get; }
    public bool IsExecutable { get; }

    public IReadOnlyList<string> InputParameters => Array.Empty<string>();
    public IReadOnlyList<string> OutputParameters => Array.Empty<string>();

    /// <summary>
    /// ExecuteAsync returns a FunctionResult describing that no execution occurred.
    /// </summary>
    public Task<FunctionResult> ExecuteAsync(Kernel kernel, KernelArguments arguments, CancellationToken cancellationToken = default)
    {
        var result = new FunctionResult(KernelFunctionFactory.CreateFromMethod(() => "No execution"), "No execution");
        return Task.FromResult(result);
    }

    /// <summary>
    /// ValidateExecution: always valid for this routing node.
    /// </summary>
    public ValidationResult ValidateExecution(KernelArguments arguments)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        return new ValidationResult();
    }

    /// <summary>
    /// GetNextNodes returns configured successors when the condition evaluates to true.
    /// </summary>
    public IEnumerable<IGraphNode> GetNextNodes(FunctionResult? executionResult, GraphState graphState)
    {
        ArgumentNullException.ThrowIfNull(graphState);
        if (_condition(graphState.KernelArguments))
        {
            return _nextNodes;
        }

        return Enumerable.Empty<IGraphNode>();
    }

    public bool ShouldExecute(GraphState graphState)
    {
        // This node is a router and therefore does not execute payload logic itself
        return false;
    }

    /// <summary>
    /// Adds an unconditional successor for routing when the condition matches.
    /// </summary>
    public void AddNextNode(IGraphNode node)
    {
        if (node == null) throw new ArgumentNullException(nameof(node));
        _nextNodes.Add(node);
    }

    public Task OnBeforeExecuteAsync(Kernel kernel, KernelArguments arguments, CancellationToken cancellationToken = default)
        => Task.CompletedTask;

    public Task OnAfterExecuteAsync(Kernel kernel, KernelArguments arguments, FunctionResult result, CancellationToken cancellationToken = default)
        => Task.CompletedTask;

    public Task OnExecutionFailedAsync(Kernel kernel, KernelArguments arguments, Exception exception, CancellationToken cancellationToken = default)
        => Task.CompletedTask;
}
```

## 相關類型

* **FunctionGraphNode**：包裝 Semantic Kernel 函式的實現
* **ConditionalGraphNode**：用於條件路由的實現
* **GraphState**：包含執行元數據的 KernelArguments 包裝器
* **ValidationResult**：驗證操作的結果
* **FunctionResult**：節點執行的結果

## 另請參閱

* [Node Types](../concepts/node-types.md) - 可用的節點實現
* [Execution Model](../concepts/execution-model.md) - 節點如何參與執行
* [Graph Concepts](../concepts/graph-concepts.md) - 理解 Graph 結構
* [FunctionGraphNode](function-graph-node.md) - 函式包裝器實現
* [Getting Started](../getting-started.md) - 構建您的第一個 Graph
