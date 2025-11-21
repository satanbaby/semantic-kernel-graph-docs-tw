# Subgraph 範例

此範例示範 Semantic Kernel Graph 中的 Subgraph 組合功能，展示不同的隔離模式和輸入/輸出映射。

## 目標

學習如何在基於 Graph 的工作流程中實現 Subgraph 組合，以便：
* 建立具有隔離執行上下文的可重用 Subgraph
* 實現父圖形和子圖形之間的輸入/輸出映射
* 使用不同的隔離模式（IsolatedClone、ScopedPrefix）
* 處理狀態合併和衝突解決
* 建立模組化和可組合的 Graph 架構

## 先決條件

* **.NET 8.0** 或更高版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* 已安裝 **Semantic Kernel Graph** 套件
* 對 [Graph 概念](../concepts/graph-concepts.md) 和 [Subgraph 組合](../concepts/subgraphs.md) 的基本了解
* 熟悉 [狀態管理](../concepts/state.md)

## 關鍵組件

### 概念和技術

* **Subgraph 組合**：從更簡單、可重用的組件建立複雜的 Graph
* **隔離模式**：用於隔離 Subgraph 執行上下文的不同策略
* **輸入/輸出映射**：在父圖形和子圖形上下文之間轉換資料
* **狀態合併**：將來自 Subgraph 的執行結果與父狀態結合
* **衝突解決**：在 Subgraph 執行期間處理狀態衝突

### 核心類別

* `GraphExecutor`：父圖形和子圖形的基本執行器
* `SubgraphGraphNode`：執行具有配置的 Subgraph 的節點
* `SubgraphConfiguration`：Subgraph 行為和映射的配置
* `FunctionGraphNode`：Subgraph 內用於特定功能的節點
* `SubgraphIsolationMode`：隔離策略的列舉

## 執行範例

### 入門

此範例使用 Semantic Kernel Graph 套件演示 Subgraph 組合和隔離。下面的程式碼片段顯示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. IsolatedClone Subgraph 範例

第一個範例演示具有完全隔離和明確映射的 Subgraph 執行。

```csharp
public static async Task RunIsolatedCloneAsync(Kernel kernel)
{
    ArgumentNullException.ThrowIfNull(kernel);

    // 1) 定義一個計算 x 和 y 之和的子 Subgraph
    var child = new GraphExecutor("Subgraph_Sum", "計算 x 和 y 的總和");

    var sumFunction = KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            // 安全地將輸入轉換為 double
            var x = args.TryGetValue("x", out var xv) && xv is IConvertible ? Convert.ToDouble(xv) : 0.0;
            var y = args.TryGetValue("y", out var yv) && yv is IConvertible ? Convert.ToDouble(yv) : 0.0;
            var sum = x + y;
            // 將結果儲存在子狀態中
            args["sum"] = sum;
            return sum.ToString("F2");
        },
        functionName: "compute_sum",
        description: "將 x 和 y 相加並存放在 'sum' 中"
    );

    var sumNode = new FunctionGraphNode(sumFunction, nodeId: "sum_node", description: "計算總和");
    sumNode.SetMetadata("StoreResultAs", "sum");

    child.AddNode(sumNode).SetStartNode(sumNode.NodeId);

    // 2) 在父圖形中配置 Subgraph 節點，包括映射和隔離
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

    var parent = new GraphExecutor("Parent_IsolatedClone", "使用 Subgraph 進行求和");
    var subgraphNode = new SubgraphGraphNode(child, name: "Subgraph(Sum)", description: "執行求和 Subgraph", config: config);

    // 在 Subgraph 執行後繼續的最終節點
    var finalizeFunction = KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var total = args.TryGetValue("total", out var tv) ? tv : 0;
            return $"總計（從 Subgraph 映射）：{total}";
        },
        functionName: "finalize",
        description: "返回總計"
    );
    var finalizeNode = new FunctionGraphNode(finalizeFunction, nodeId: "finalize_node", description: "顯示總計");

    parent.AddNode(subgraphNode)
          .AddNode(finalizeNode)
          .SetStartNode(subgraphNode.NodeId)
          .Connect(subgraphNode.NodeId, finalizeNode.NodeId);

    // 3) 使用初始狀態（a,b）執行
    var args = new KernelArguments
    {
        ["a"] = 3,
        ["b"] = 7
    };

    var result = await parent.ExecuteAsync(kernel, args, CancellationToken.None);

    Console.WriteLine("[IsolatedClone] 預期總計 = 10");
    var totalOk = args.TryGetValue("total", out var totalVal);
    Console.WriteLine($"[IsolatedClone] 獲得的總計 = {(totalOk ? totalVal : "（未映射）")}");
    Console.WriteLine($"[IsolatedClone] 最終訊息 = {result.GetValue<object>()}");
}
```

### 2. ScopedPrefix Subgraph 範例

第二個範例演示具有作用域前綴隔離的 Subgraph 執行。

```csharp
public static async Task RunScopedPrefixAsync(Kernel kernel)
{
    ArgumentNullException.ThrowIfNull(kernel);

    // 1) 定義一個在前綴下向總計應用折扣的子 Subgraph
    var child = new GraphExecutor("Subgraph_Discount", "在前綴下將折扣應用於總計");

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
        description: "應用折扣並存放在 'final' 中"
    );

    var discountNode = new FunctionGraphNode(applyDiscountFunction, nodeId: "discount_node", description: "應用折扣");
    discountNode.SetMetadata("StoreResultAs", "final");
    child.AddNode(discountNode).SetStartNode(discountNode.NodeId);

    // 2) 使用作用域前綴隔離的 Subgraph 節點
    var config = new SubgraphConfiguration
    {
        IsolationMode = SubgraphIsolationMode.ScopedPrefix,
        ScopedPrefix = "invoice."
    };

    var parent = new GraphExecutor("Parent_ScopedPrefix", "使用帶有作用域前綴的 Subgraph");
    var subgraphNode = new SubgraphGraphNode(child, name: "Subgraph(Discount)", description: "執行折扣 Subgraph", config: config);

    var echoFunction = KernelFunctionFactory.CreateFromMethod(
        (KernelArguments args) =>
        {
            var total = args.TryGetValue("invoice.total", out var t) ? t : 0;
            var discount = args.TryGetValue("invoice.discount", out var d) ? d : 0;
            var final = args.TryGetValue("invoice.final", out var f) ? f : 0;
            return $"總計：{total} | 折扣：{discount} | 最終：{final}";
        },
        functionName: "echo_invoice",
        description: "回應發票值"
    );
    var echoNode = new FunctionGraphNode(echoFunction, nodeId: "echo_node", description: "回應節點");

    parent.AddNode(subgraphNode)
          .AddNode(echoNode)
          .SetStartNode(subgraphNode.NodeId)
          .Connect(subgraphNode.NodeId, echoNode.NodeId);

    // 3) 使用初始的有前綴狀態執行
    var args = new KernelArguments
    {
        ["invoice.total"] = 125.0,
        ["invoice.discount"] = 20.0
    };

    var result = await parent.ExecuteAsync(kernel, args, CancellationToken.None);

    Console.WriteLine("[ScopedPrefix] 最終預期 = 105.00");
    var finalOk = args.TryGetValue("invoice.final", out var finalVal);
    Console.WriteLine($"[ScopedPrefix] invoice.final = {(finalOk ? finalVal : "（未映射）")}");
    Console.WriteLine($"[ScopedPrefix] 最終訊息 = {result.GetValue<object>()}");
}
```

### 3. Subgraph 配置選項

範例演示 Subgraph 行為的各種配置選項。

```csharp
// 全面的 Subgraph 配置
var advancedConfig = new SubgraphConfiguration
{
    // 隔離模式決定 Subgraph 上下文的管理方式
    IsolationMode = SubgraphIsolationMode.IsolatedClone, // 或 ScopedPrefix

    // 作用域前綴隔離（僅用於 ScopedPrefix 模式）
    ScopedPrefix = "my_subgraph_",

    // 如何在合併期間處理狀態衝突
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond, // 或 PreferFirst、Merge

    // 輸入映射：父狀態 -> Subgraph 狀態
    InputMappings = new Dictionary<string, string>
    {
        ["parent_input"] = "subgraph_input",
        ["parent_config"] = "subgraph_config"
    },

    // 輸出映射：Subgraph 狀態 -> 父狀態
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

範例展示了不同隔離模式之間的狀態管理方式。

```csharp
// IsolatedClone 模式中的狀態管理
// - 父狀態：{ "a": 3, "b": 7 }
// - 映射到 Subgraph：{ "x": 3, "y": 7 }
// - Subgraph 執行：{ "x": 3, "y": 7, "sum": 10 }
// - 映射回父：{ "a": 3, "b": 7, "total": 10 }

// ScopedPrefix 模式中的狀態管理
// - 父狀態：{ "data": "Hello World" }
// - 映射到 Subgraph：{ "input": "Hello World" }
// - Subgraph 執行：{ "input": "Hello World", "internal_result": "Processed: HELLO WORLD", "internal_count": 11 }
// - 使用前綴合併：{ "data": "Hello World", "subgraph_internal_result": "Processed: HELLO WORLD", "subgraph_internal_count": 11 }
// - 映射輸出：{ "data": "Hello World", "result": "Processed: HELLO WORLD", "count": 11 }
```

### 5. 錯誤處理和驗證

範例包括 Subgraph 執行的錯誤處理。

```csharp
// Subgraph 執行中的錯誤處理
try
{
    var result = await parent.ExecuteAsync(kernel, args, CancellationToken.None);
    
    if (result.Success)
    {
        Console.WriteLine("✅ Subgraph 執行成功完成");
        Console.WriteLine($"結果：{result.GetValue<object>()}");
    }
    else
    {
        Console.WriteLine("❌ Subgraph 執行失敗");
        Console.WriteLine($"錯誤：{result.ErrorMessage}");
    }
}
catch (SubgraphExecutionException ex)
{
    Console.WriteLine($"🚨 Subgraph 執行錯誤：{ex.Message}");
    Console.WriteLine($"Subgraph：{ex.SubgraphName}");
    Console.WriteLine($"節點：{ex.NodeId}");
}
catch (StateMappingException ex)
{
    Console.WriteLine($"🔀 狀態映射錯誤：{ex.Message}");
    Console.WriteLine($"映射：{ex.MappingName}");
}
```

### 6. 進階 Subgraph 模式

範例演示 Subgraph 組合的進階模式。

```csharp
// 巢狀 Subgraph
var nestedChild = new GraphExecutor("Nested_Child", "巢狀 Subgraph 範例");
// ... 配置巢狀子 Graph

var middleChild = new GraphExecutor("Middle_Child", "中級別 Subgraph");
var nestedNode = new SubgraphGraphNode(nestedChild, "Nested", "巢狀 Subgraph");
middleChild.AddNode(nestedNode);

var parent = new GraphExecutor("Parent", "具有巢狀 Subgraph 的父 Graph");
var middleNode = new SubgraphGraphNode(middleChild, "Middle", "中 Subgraph");
parent.AddNode(middleNode);

// 條件式 Subgraph 執行
var conditionalConfig = new SubgraphConfiguration
{
    IsolationMode = SubgraphIsolationMode.IsolatedClone,
    ExecutionCondition = (state) => 
        state.TryGetValue("enable_subgraph", out var enable) && 
        enable is bool b && b
};

// 動態 Subgraph 選擇
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
        "根據條件選擇適當的 Subgraph"
    ),
    "selector",
    "Subgraph 選擇器"
);
```

## 預期輸出

範例產生全面的輸出，顯示：

* 🔢 使用明確映射的 IsolatedClone Subgraph 執行
* 🔀 使用自動前綴的 ScopedPrefix Subgraph 執行
* 📊 狀態轉換和映射結果
* 🔄 狀態合併和衝突解決
* ✅ 完整的 Subgraph 工作流程執行
* 📈 模組化 Graph 組合功能

## 疑難排解

### 常見問題

1. **狀態映射失敗**：驗證輸入/輸出映射配置
2. **隔離模式錯誤**：檢查隔離模式是否與使用情況相容
3. **狀態合併衝突**：配置適當的衝突解決原則
4. **Subgraph 執行失敗**：監視 Subgraph 執行和錯誤處理

### 偵錯提示

* 為 Subgraph 執行啟用詳細記錄
* 驗證狀態映射配置和轉換
* 監視狀態隔離和合併行為
* 檢查 Subgraph 配置和隔離模式設定

## 另請參閱

* [Subgraph 組合](../concepts/subgraphs.md)
* [狀態管理](../concepts/state.md)
* [Graph 組合](../how-to/graph-composition.md)
* [狀態映射](../concepts/state-mapping.md)
* [模組化架構](../patterns/modular-architecture.md)
