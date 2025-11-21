# IGraphExecutor

`IGraphExecutor` 介面定義了在語義核心之上構建的圖形執行的公開契約。它抽象了執行引擎，以啟用模擬、依賴反轉和跨不同實現的一致行為。

## 概述

`IGraphExecutor` 作為編排 Graph 工作流的核心執行契約。它管理從初始化到完成的完整執行生命週期，同時提供防止無限迴圈的保護措施並確保可預測的行為。

## 契約和語義

### 核心執行方法

主要方法 `ExecuteAsync` 從配置的起始 Node 編排 Graph 執行，直到完成或取消：

```csharp
Task<FunctionResult> ExecuteAsync(
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default);
```

**參數：**
* `kernel`：用於解析函式、提示、記憶體和其他服務的語義核心實例
* `arguments`：執行狀態和輸入，為 `KernelArguments`；更新的值可能在執行期間寫入
* `cancellationToken`：用於協作取消的令牌

**返回：** 代表 Graph 執行終端結果的 `FunctionResult`

**例外：**
* `ArgumentNullException`：如果 `kernel` 或 `arguments` 為 null，則拋出
* `OperationCanceledException`：如果操作通過 `cancellationToken` 被取消，則拋出

### Node 執行方法

#### ExecuteNodeAsync
在隔離狀態下執行單個 Graph Node：

```csharp
Task<FunctionResult> ExecuteNodeAsync(
    IGraphNode node,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default);
```

此方法對於測試個別 Node 或實現自訂執行策略很有用。

#### ExecuteGraphAsync
執行由提供的 Node 組成的 Graph：

```csharp
Task<FunctionResult> ExecuteGraphAsync(
    IEnumerable<IGraphNode> nodes,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default);
```

此方法支援條件路由、分支或根據 Node 類型和執行時條件的早期終止。

### 屬性

* `Name`：執行器實例的人類可讀的邏輯名稱，對於日誌記錄、診斷或多執行器情景很有用

## 執行語義

### 生命週期管理

執行器遵循結構化的執行生命週期：

1. **初始化**：使用不可變選項快照建立執行上下文
2. **驗證**：可選地在執行前驗證 Graph 完整性
3. **計畫編譯**：可能編譯和緩存結構執行計畫
4. **Node 執行**：使用生命週期掛鉤依序處理 Node
5. **完成**：返回最終結果或傳播例外

### 狀態管理

* **KernelArguments**：作為權威執行狀態處理
* **GraphState**：環繞 KernelArguments 的包裝器，附加元資料
* **執行上下文**：捕獲不可變選項和執行元資料
* **狀態傳播**：更新在 Node 間一致傳播

### 安全功能

* **迴圈防止**：防止無限迴圈的內置防護措施
* **逾時支援**：可配置的執行逾時
* **取消**：通過 CancellationToken 的協作取消
* **資源限制**：可配置的最大執行步驟
* **完整性驗證**：可選的 Graph 結構驗證

### 執行緒安全

如果在實例上不保留可變的每次執行狀態，實例通常可安全地在執行間重複使用。該介面不保證併發執行的執行緒安全。

## 實現要求

實現應該：

* 驗證輸入並遵守提供的 `Kernel` 配置和原則
* 將 `KernelArguments` 作為權威執行狀態處理
* 支援通過 `CancellationToken` 的協作取消
* 按照系統其他位置的配置發出豐富的日誌記錄/遙測
* 適當處理例外並傳播取消

## 使用範例

### 基本執行

```csharp
Kernel kernel = BuildKernel();
KernelArguments args = new() { ["input"] = "Hello" };
IGraphExecutor executor = GetExecutor();
FunctionResult result = await executor.ExecuteAsync(kernel, args, CancellationToken.None);
```

### 使用取消

```csharp
using var cts = new CancellationTokenSource(TimeSpan.FromMinutes(5));
var result = await executor.ExecuteAsync(kernel, arguments, cts.Token);
```

### 單個 Node 執行

```csharp
var node = executor.GetNode("specificNode");
var result = await executor.ExecuteNodeAsync(node, kernel, arguments, cancellationToken);
```

### 自訂 Node 序列

```csharp
var customNodes = new[] { node1, node2, node3 };
var result = await executor.ExecuteGraphAsync(customNodes, kernel, arguments, cancellationToken);
```

### 可執行範例

以下是一個最小的完全可執行的範例，演示如何構造簡單的 Graph、添加兩個函式 Node、連接它們、設定起始 Node 並使用 `GraphExecutor` 執行 Graph。此範例是 `examples` 資料夾中提供的相同程式碼，已測試可編譯和執行。

```csharp
// 最小可執行範例，演示如何構造 GraphExecutor、
// 添加函式 Node、連接它們、設定起始 Node 並執行 Graph。
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;
using System.Threading;

public static class GraphExecutorExample
{
    /// <summary>
    /// 文件範例的進入點。從範例執行器呼叫。
    /// </summary>
    public static async Task RunAsync()
    {
        // 建立最小核心用於函式調用。
        var kernel = Kernel.CreateBuilder().Build();

        // 建立簡單的核心函式作為輕量級委派供 Node 使用。
        var fnA = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
        {
            // 簡單函式：返回問候字串
            return "Hello from A";
        }, "FnA");

        var fnB = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
        {
            // 迴聲函式：將文字附加到先前狀態
            var prev = args.ContainsName("message") ? args["message"]?.ToString() : string.Empty;
            return $"B received: {prev}";
        }, "FnB");

        // 將函式包裝到 Graph Node 中
        var nodeA = new FunctionGraphNode(fnA, "nodeA", "Start node A");
        var nodeB = new FunctionGraphNode(fnB, "nodeB", "Receiver node B");

        // 建立執行器並添加 Node
        var executor = new GraphExecutor("ExampleGraph", "A tiny demo graph for docs");
        executor.AddNode(nodeA).AddNode(nodeB);

        // 連接 A -> B 並設定起始 Node
        executor.Connect("nodeA", "nodeB");
        executor.SetStartNode("nodeA");

        // 準備初始核心參數 / Graph 狀態
        var args = new KernelArguments();
        args["message"] = "Initial message";

        // 執行 Graph
        var result = await executor.ExecuteAsync(kernel, args, CancellationToken.None);

        // 列印最終結果
        Console.WriteLine("Graph execution completed.");
        Console.WriteLine($"Final result: {result.GetValue<string>()}");
    }
}
```

## 相關型別

* **GraphExecutor**：此介面的主要實現
* **GraphExecutionContext**：維護執行狀態和協調
* **GraphExecutionOptions**：不可變執行配置快照
* **GraphState**：環繞 KernelArguments 的包裝器，附加執行元資料

## 另請參閱

* [GraphExecutor](graph-executor.md) - 主要實現詳情
* [執行模型](../concepts/execution-model.md) - 執行如何流動通過 Graph
* [Graph 概念](../concepts/graph-concepts.md) - 理解 Graph 結構
* [開始使用](../getting-started.md) - 構造您的第一個 Graph
