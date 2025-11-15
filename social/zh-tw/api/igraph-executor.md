# IGraphExecutor

`IGraphExecutor` 介面定義了建立在 Semantic Kernel 之上的圖形執行的公開合約。它抽象了執行引擎，以啟用模擬、依賴反轉和跨不同實現的一致行為。

## 概述

`IGraphExecutor` 作為核心執行合約，協調圖形工作流程。它管理完整的執行生命週期，從初始化到完成，同時提供針對無限迴圈的保護措施並確保可預測的行為。

## 合約和語義

### 核心執行方法

主要方法 `ExecuteAsync` 協調圖形執行，從配置的起始節點開始直到完成或取消：

```csharp
Task<FunctionResult> ExecuteAsync(
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default);
```

**參數：**
* `kernel`：用於解析函式、提示、記憶體和其他服務的 Semantic Kernel 實例
* `arguments`：執行狀態和輸入作為 `KernelArguments`；更新的值可能在執行期間被寫入
* `cancellationToken`：用於協作取消的令牌

**傳回值：** 代表圖形執行終端結果的 `FunctionResult`

**例外：**
* `ArgumentNullException`：如果 `kernel` 或 `arguments` 為 null，則拋出
* `OperationCanceledException`：如果操作通過 `cancellationToken` 被取消，則拋出

### 節點執行方法

#### ExecuteNodeAsync
獨立執行單個圖形節點：

```csharp
Task<FunctionResult> ExecuteNodeAsync(
    IGraphNode node,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default);
```

此方法對於測試各個節點或實現自訂執行策略很有用。

#### ExecuteGraphAsync
執行由提供的節點組成的圖形：

```csharp
Task<FunctionResult> ExecuteGraphAsync(
    IEnumerable<IGraphNode> nodes,
    Kernel kernel,
    KernelArguments arguments,
    CancellationToken cancellationToken = default);
```

此方法支援條件式路由、分支或早期終止，取決於節點類型和執行時條件。

### 屬性

* `Name`：執行器實例的人類可讀邏輯名稱，適用於記錄、診斷或多執行器場景

## 執行語義

### 生命週期管理

執行器遵循結構化的執行生命週期：

1. **初始化**：使用不可變選項快照建立執行內容
2. **驗證**：在執行前可選地驗證圖形完整性
3. **計劃編譯**：可能編譯和快取結構執行計劃
4. **節點執行**：使用生命週期鉤子依序處理節點
5. **完成**：傳回最終結果或傳播例外

### 狀態管理

* **KernelArguments**：被視為權威執行狀態
* **GraphState**：圍繞 KernelArguments 的包裝器，具有額外的中繼資料
* **執行內容**：捕獲不可變選項和執行中繼資料
* **狀態傳播**：更新在節點間一致地傳播

### 安全功能

* **迴圈防止**：針對無限迴圈的內建保護措施
* **逾時支援**：可配置的執行逾時
* **取消**：通過 CancellationToken 進行協作取消
* **資源限制**：可配置的最大執行步數
* **完整性驗證**：選擇性的圖形結構驗證

### 執行緒安全

如果實例本身不保持任何可變的每次執行狀態，則通常可以跨執行安全地重複使用。該介面不保證併發執行的執行緒安全性。

## 實現要求

實現應該：

* 驗證輸入並遵守提供的 `Kernel` 配置和策略
* 將 `KernelArguments` 視為權威執行狀態
* 通過 `CancellationToken` 支援協作取消
* 根據系統中其他位置的配置發出豐富的記錄/遙測
* 適當處理例外並傳播取消

## 使用示例

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

### 單個節點執行

```csharp
var node = executor.GetNode("specificNode");
var result = await executor.ExecuteNodeAsync(node, kernel, arguments, cancellationToken);
```

### 自訂節點序列

```csharp
var customNodes = new[] { node1, node2, node3 };
var result = await executor.ExecuteGraphAsync(customNodes, kernel, arguments, cancellationToken);
```

### 可執行示例

以下是一個最小的、完全可執行的示例，演示如何建立簡單的圖形、新增兩個函式節點、連接它們、設定起始節點並使用 `GraphExecutor` 執行圖形。此示例是 `examples` 資料夾中附帶的相同代碼，已經過編譯和執行測試。

```csharp
// 最小可執行示例，演示如何建構 GraphExecutor、
// 新增函式節點、連接它們、設定起始節點並執行圖形。
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Nodes;
using SemanticKernel.Graph.State;
using System.Threading;

public static class GraphExecutorExample
{
    /// <summary>
    /// 文件示例的進入點。從示例執行程式呼叫。
    /// </summary>
    public static async Task RunAsync()
    {
        // 建立一個最小的核心以用於函式呼叫。
        var kernel = Kernel.CreateBuilder().Build();

        // 建立簡單的核心函式作為輕量級委派供節點使用。
        var fnA = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
        {
            // 簡單函式：傳回問候字串
            return "Hello from A";
        }, "FnA");

        var fnB = KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
        {
            // 回聲函式：將文本附加到先前的狀態
            var prev = args.ContainsName("message") ? args["message"]?.ToString() : string.Empty;
            return $"B received: {prev}";
        }, "FnB");

        // 將函式包裝到圖形節點中
        var nodeA = new FunctionGraphNode(fnA, "nodeA", "Start node A");
        var nodeB = new FunctionGraphNode(fnB, "nodeB", "Receiver node B");

        // 建立執行器並新增節點
        var executor = new GraphExecutor("ExampleGraph", "A tiny demo graph for docs");
        executor.AddNode(nodeA).AddNode(nodeB);

        // 連接 A -> B 並設定起始節點
        executor.Connect("nodeA", "nodeB");
        executor.SetStartNode("nodeA");

        // 準備初始核心引數 / 圖形狀態
        var args = new KernelArguments();
        args["message"] = "Initial message";

        // 執行圖形
        var result = await executor.ExecuteAsync(kernel, args, CancellationToken.None);

        // 列印最終結果
        Console.WriteLine("Graph execution completed.");
        Console.WriteLine($"Final result: {result.GetValue<string>()}");
    }
}
```

## 相關類型

* **GraphExecutor**：此介面的主要實現
* **GraphExecutionContext**：維護執行狀態和協調
* **GraphExecutionOptions**：不可變執行配置快照
* **GraphState**：圍繞 KernelArguments 的包裝器，具有執行中繼資料

## 另見

* [GraphExecutor](graph-executor.md) - 主要實現詳情
* [執行模型](../concepts/execution-model.md) - 執行如何通過圖形流動
* [圖形概念](../concepts/graph-concepts.md) - 理解圖形結構
* [開始使用](../getting-started.md) - 建立您的第一個圖形
