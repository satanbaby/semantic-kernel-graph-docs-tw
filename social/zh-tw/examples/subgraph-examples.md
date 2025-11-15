# 子圖示例

此範例展示了 Semantic Kernel Graph 中的子圖組合功能，包含不同的隔離模式和輸入/輸出對應。

## 目標

學習如何在基於圖的工作流中實現子圖組合：
* 使用隔離的執行上下文建立可重複使用的子圖
* 實現父圖與子圖之間的輸入/輸出對應
* 使用不同的隔離模式（IsolatedClone、ScopedPrefix）
* 處理狀態合併和衝突解決
* 構建模組化和可組合的圖架構

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 對[圖概念](../concepts/graph-concepts.md)和[子圖組合](../concepts/subgraphs.md)的基本理解
* 熟悉[狀態管理](../concepts/state.md)

## 關鍵元件

### 概念和技術

* **子圖組合**：從更簡單的、可重複使用的元件構建複雜的圖
* **隔離模式**：隔離子圖執行上下文的不同策略
* **輸入/輸出對應**：在父圖和子圖上下文之間轉換資料
* **狀態合併**：將子圖的執行結果與父狀態結合
* **衝突解決**：在子圖執行期間處理狀態衝突

### 核心類別

* `GraphExecutor`：父圖和子圖的基礎執行器
* `SubgraphGraphNode`：執行具有配置的子圖的節點
* `SubgraphConfiguration`：子圖行為和對應的配置
* `FunctionGraphNode`：子圖內用於特定功能的節點
* `SubgraphIsolationMode`：隔離策略的列舉

## 運行示例

### 快速開始

此範例展示了 Semantic Kernel Graph 套件中的子圖組合和隔離。下面的程式碼片段展示了如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. IsolatedClone 子圖示例

第一個範例展示了完全隔離和明確對應的子圖執行。

```csharp
public static async Task RunIsolatedCloneAsync(Kernel kernel)
{
    ArgumentNullException.ThrowIfNull(kernel);

    // 1) 定義一個計算 x 和 y 之和的子子圖
    var child = new GraphExecutor("Subgraph_Sum", "Calculates sum of x and y");

    var sumFunction = KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            // 安全地將輸入轉換為 double
            var x = args.TryGetValue("x", out var xv) && xv is IConvertible ? Convert.ToDouble(xv) : 0.0;
            var y = args.TryGetValue("y", out var yv) && yv is IConvertible ? Convert.ToDouble(yv) : 0.0;
            var sum = x + y;
            // 將結果存儲在子狀態中
            args["sum"] = sum;
            return sum.ToString("F2");
        },
        functionName: "compute_sum",
        description: "Sums x and y and stores in 'sum'"
    );

    var sumNode = new FunctionGraphNode(sumFunction, nodeId: "sum_node", description: "Calculates sum");
    sumNode.SetMetadata("StoreResultAs", "sum");

    child.AddNode(sumNode).SetStartNode(sumNode.NodeId);

    // 2) 在父圖中配置子圖節點，包括對應和隔離
    var config = new SubgraphConfiguration
    {
        IsolationMode = SubgraphIsolationMode.IsolatedClone,
        MergeConflictPolicy = SemanticKernel.Graph.State.StateMergeConflictPolicy.PreferSecond,
        InputMappings =
        {
            ["a"] = "x",
            ["b"] = "y"
        },
        OutputMappings =
        {
            ["sum"] = "total"
        }
    };

    var parent = new GraphExecutor("Parent_IsolatedClone", "Uses subgraph for summation");
    var subgraphNode = new SubgraphGraphNode(child, name: "Subgraph(Sum)", description: "Executes sum subgraph", config: config);

    // 最終節點以在子圖執行後繼續
    var finalizeFunction = KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var total = args.TryGetValue("total", out var tv) ? tv : 0;
            return $"Total (mapped from subgraph): {total}";
        },
        functionName: "finalize",
        description: "Returns total"
    );
    var finalizeNode = new FunctionGraphNode(finalizeFunction, nodeId: "finalize_node", description: "Displays total");

    parent.AddNode(subgraphNode)
          .AddNode(finalizeNode)
          .SetStartNode(subgraphNode.NodeId)
          .Connect(subgraphNode.NodeId, finalizeNode.NodeId);

    // 3) 使用初始狀態 (a,b) 執行
    var args = new KernelArguments
    {
        ["a"] = 3,
        ["b"] = 7
    };

    var result = await parent.ExecuteAsync(kernel, args, CancellationToken.None);

    Console.WriteLine("[IsolatedClone] expected total = 10");
    var totalOk = args.TryGetValue("total", out var totalVal);
    Console.WriteLine($"[IsolatedClone] obtained total = {(totalOk ? totalVal : "(not mapped)")}");
    Console.WriteLine($"[IsolatedClone] final message = {result.GetValue<object>()}");
}
```

### 2. ScopedPrefix 子圖示例

第二個範例展示了使用作用域前綴隔離的子圖執行。

```csharp
public static async Task RunScopedPrefixAsync(Kernel kernel)
{
    ArgumentNullException.ThrowIfNull(kernel);

    // 1) 定義一個在前綴下對總值應用折扣的子子圖
    var child = new GraphExecutor("Subgraph_Discount", "Applies a discount to a total under a prefix");

    var applyDiscountFunction = KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var total = args.TryGetValue("total", out var tv) && tv is IConvertible ? Convert.ToDouble(tv) : 0.0;
            var discount = args.TryGetValue("discount", out var dv) && dv is IConvertible ? Convert.ToDouble(dv) : 0.0;
            var final = Math.Max(0.0, total - discount);
            args["final"] = final;
            return final.ToString("F2");
        },
        functionName: "apply_discount",
        description: "Applies discount and stores in 'final'"
    );

    var discountNode = new FunctionGraphNode(applyDiscountFunction, nodeId: "discount_node", description: "Apply discount");
    discountNode.SetMetadata("StoreResultAs", "final");
    child.AddNode(discountNode).SetStartNode(discountNode.NodeId);

    // 2) 具有作用域前綴隔離的子圖節點
    var config = new SubgraphConfiguration
    {
        IsolationMode = SubgraphIsolationMode.ScopedPrefix,
        ScopedPrefix = "invoice."
    };

    var parent = new GraphExecutor("Parent_ScopedPrefix", "Uses subgraph with scoped prefix");
    var subgraphNode = new SubgraphGraphNode(child, name: "Subgraph(Discount)", description: "Executes discount subgraph", config: config);

    var echoFunction = KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var total = args.TryGetValue("invoice.total", out var t) ? t : 0;
            var discount = args.TryGetValue("invoice.discount", out var d) ? d : 0;
            var final = args.TryGetValue("invoice.final", out var f) ? f : 0;
            return $"Total: {total} | Discount: {discount} | Final: {final}";
        },
        functionName: "echo_invoice",
        description: "Echoes invoice values"
    );
    var echoNode = new FunctionGraphNode(echoFunction, nodeId: "echo_node", description: "Echo node");

    parent.AddNode(subgraphNode)
          .AddNode(echoNode)
          .SetStartNode(subgraphNode.NodeId)
          .Connect(subgraphNode.NodeId, echoNode.NodeId);

    // 3) 使用初始前綴狀態執行
    var args = new KernelArguments
    {
        ["invoice.total"] = 125.0,
        ["invoice.discount"] = 20.0
    };

    var result = await parent.ExecuteAsync(kernel, args, CancellationToken.None);

    Console.WriteLine("[ScopedPrefix] final expected = 105.00");
    var finalOk = args.TryGetValue("invoice.final", out var finalVal);
    Console.WriteLine($"[ScopedPrefix] invoice.final = {(finalOk ? finalVal : "(not mapped)")}");
    Console.WriteLine($"[ScopedPrefix] final message = {result.GetValue<object>()}");
}
```

### 3. 子圖配置選項

這些範例展示了子圖行為的各種配置選項。

```csharp
// 全面的子圖配置
var advancedConfig = new SubgraphConfiguration
{
    // 隔離模式決定了子圖上下文的管理方式
    IsolationMode = SubgraphIsolationMode.IsolatedClone, // 或 ScopedPrefix

    // 用於作用域隔離的 ScopedPrefix（僅與 ScopedPrefix 模式一起使用）
    ScopedPrefix = "my_subgraph_",

    // 如何處理合併期間的狀態衝突
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond, // 或 PreferFirst、Merge

    // 輸入對應：父狀態 -> 子圖狀態
    InputMappings = new Dictionary<string, string>
    {
        ["parent_input"] = "subgraph_input",
        ["parent_config"] = "subgraph_config"
    },

    // 輸出對應：子圖狀態 -> 父狀態
    OutputMappings = new Dictionary<string, string>
    {
        ["subgraph_result"] = "parent_result",
        ["subgraph_metadata"] = "parent_metadata"
    },

    // 其他配置選項
    EnableStateValidation = true,
    MaxExecutionTime = TimeSpan.FromMinutes(5),
    EnableCheckpointing = false
};
```

### 4. 狀態管理和隔離

這些範例展示了在不同隔離模式中狀態如何被管理。

```csharp
// IsolatedClone 模式中的狀態管理
// - 父狀態：{ "a": 3, "b": 7 }
// - 對應到子圖：{ "x": 3, "y": 7 }
// - 子圖執行：{ "x": 3, "y": 7, "sum": 10 }
// - 對應回父圖：{ "a": 3, "b": 7, "total": 10 }

// ScopedPrefix 模式中的狀態管理
// - 父狀態：{ "data": "Hello World" }
// - 對應到子圖：{ "input": "Hello World" }
// - 子圖執行：{ "input": "Hello World", "internal_result": "Processed: HELLO WORLD", "internal_count": 11 }
// - 使用前綴合併：{ "data": "Hello World", "subgraph_internal_result": "Processed: HELLO WORLD", "subgraph_internal_count": 11 }
// - 對應輸出：{ "data": "Hello World", "result": "Processed: HELLO WORLD", "count": 11 }
```

### 5. 錯誤處理和驗證

這些範例包括子圖執行的錯誤處理。

```csharp
// 子圖執行中的錯誤處理
try
{
    var result = await parent.ExecuteAsync(kernel, args, CancellationToken.None);
    
    if (result.Success)
    {
        Console.WriteLine("✅ 子圖執行完成成功");
        Console.WriteLine($"結果：{result.GetValue<object>()}");
    }
    else
    {
        Console.WriteLine("❌ 子圖執行失敗");
        Console.WriteLine($"錯誤：{result.ErrorMessage}");
    }
}
catch (SubgraphExecutionException ex)
{
    Console.WriteLine($"🚨 子圖執行錯誤：{ex.Message}");
    Console.WriteLine($"子圖：{ex.SubgraphName}");
    Console.WriteLine($"節點：{ex.NodeId}");
}
catch (StateMappingException ex)
{
    Console.WriteLine($"🔀 狀態對應錯誤：{ex.Message}");
    Console.WriteLine($"對應：{ex.MappingName}");
}
```

### 6. 進階子圖模式

這些範例展示了子圖組合的進階模式。

```csharp
// 嵌套子圖
var nestedChild = new GraphExecutor("Nested_Child", "Nested subgraph example");
// ... 配置嵌套子圖

var middleChild = new GraphExecutor("Middle_Child", "Middle level subgraph");
var nestedNode = new SubgraphGraphNode(nestedChild, "Nested", "Nested subgraph");
middleChild.AddNode(nestedNode);

var parent = new GraphExecutor("Parent", "Parent with nested subgraphs");
var middleNode = new SubgraphGraphNode(middleChild, "Middle", "Middle subgraph");
parent.AddNode(middleNode);

// 條件子圖執行
var conditionalConfig = new SubgraphConfiguration
{
    IsolationMode = SubgraphIsolationMode.IsolatedClone,
    ExecutionCondition = (state) => 
        state.TryGetValue("enable_subgraph", out var enable) && 
        enable is bool b && b
};

// 動態子圖選擇
var subgraphSelector = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var condition = args.TryGetValue("condition", out var c) ? c?.ToString() ?? string.Empty : string.Empty;
            return condition switch
            {
                "sum" => "Subgraph_Sum",
                "process" => "Subgraph_Processor",
                _ => "Subgraph_Default"
            };
        },
        "select_subgraph",
        "Selects appropriate subgraph based on condition"
    ),
    "selector",
    "Subgraph Selector"
);
```

## 預期輸出

這些範例產生全面的輸出，展示：

* 🔢 具有明確對應的 IsolatedClone 子圖執行
* 🔀 具有自動前綴的 ScopedPrefix 子圖執行
* 📊 狀態轉換和對應結果
* 🔄 狀態合併和衝突解決
* ✅ 完整的子圖工作流執行
* 📈 模組化圖組合功能

## 故障排除

### 常見問題

1. **狀態對應失敗**：驗證輸入/輸出對應配置
2. **隔離模式錯誤**：檢查隔離模式是否與使用情況相容
3. **狀態合併衝突**：配置適當的衝突解決策略
4. **子圖執行失敗**：監視子圖執行和錯誤處理

### 調試提示

* 為子圖執行啟用詳細日誌
* 驗證狀態對應配置和轉換
* 監視狀態隔離和合併行為
* 檢查子圖配置和隔離模式設定

## 另請參閱

* [子圖組合](../concepts/subgraphs.md)
* [狀態管理](../concepts/state.md)
* [圖組合](../how-to/graph-composition.md)
* [狀態對應](../concepts/state-mapping.md)
* [模組化架構](../patterns/modular-architecture.md)
