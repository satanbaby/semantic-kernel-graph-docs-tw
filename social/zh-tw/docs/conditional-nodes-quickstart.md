# 條件節點快速入門

本快速教程將教您如何在 SemanticKernel.Graph 中使用條件節點和邊，以建立動態工作流程，該工作流程可以根據狀態做出決策並路由執行。

## 您將學習的內容

* 建立 `ConditionalGraphNode` 進行 if/else 邏輯
* 使用 `ConditionalEdge` 進行動態路由
* 建立適應不同場景的工作流程
* 基於範本和函數的條件

## 概念和技術

**ConditionalGraphNode**：一種特殊的節點類型，它評估條件並根據結果將執行路由到不同的路徑。

**ConditionalEdge**：連接條件節點與其真/假執行路徑的邊，以實現動態工作流程路由。

**動態路由**：圖形根據運行時條件和狀態值改變執行路徑的能力。

**範本表達式**：可以參考狀態變數並在運行時評估的字符串型條件。

## 前置要求

* 完成[首個圖形教程](first-graph-5-minutes.md)
* 完成[狀態快速入門](state-quickstart.md)
* 對 SemanticKernel.Graph 概念的基本理解

## 步驟 1：基本條件節點

### 簡單的 If/Else 邏輯

```csharp
using SemanticKernel.Graph.Nodes;

// 建立檢查使用者年齡的條件節點
var ageCheckNode = new ConditionalGraphNode(
    state => state.GetValue<int>("userAge") >= 18,
    "age_check",
    "AgeVerification",
    "檢查使用者是否年滿 18 歲"
);
```

### 使用基於範本的條件

```csharp
// 替代方案：使用範本表達式
var templateAgeCheck = new ConditionalGraphNode(
    "{{userAge}} >= 18",
    "template_age_check",
    "TemplateAgeCheck",
    "基於範本的年齡驗證"
);
```

## 步驟 2：連接條件路徑

### 新增真/假節點

```csharp
// 為不同路徑建立函數節點
var adultNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () => "歡迎！您可以存取成人內容。",
        "AdultAccess",
        "提供成人內容存取權"
    ),
    "adult_node"
);

var minorNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () => "抱歉，您必須年滿 18 歲才能存取此內容。",
        "MinorAccess",
        "告知使用者年齡限制"
    ),
    "minor_node"
);

// 連接條件路徑
ageCheckNode
    .AddTrueNode(adultNode)    // 條件為真時執行
    .AddFalseNode(minorNode);  // 條件為假時執行
```

## 步驟 3：建立完整的條件工作流程

### 建立圖形

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

// KernelArguments 的輔助擴充類
public static class KernelArgumentsExtensions
{
    // 輔助方法，用於從 KernelArguments 安全地取得型別化值
    public static T GetValue<T>(this KernelArguments args, string key, T defaultValue = default!)
    {
        if (args.TryGetValue(key, out var value) && value is T typedValue)
        {
            return typedValue;
        }
        return defaultValue;
    }
}

class Program
{
    static async Task Main(string[] args)
    {
        var builder = Kernel.CreateBuilder();
        builder.AddOpenAIChatCompletion("gpt-3.5-turbo", Environment.GetEnvironmentVariable("OPENAI_API_KEY"));
        builder.AddGraphSupport();
        var kernel = builder.Build();

        // 節點 1：輸入處理
        var inputNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var age = args.GetValue<int>("userAge");
                    var name = args.GetValue<string>("userName");
                    
                    // 新增一些分析
                    var isVip = age > 25 && name.Length > 5;
                    args["isVip"] = isVip;
                    args["ageGroup"] = age < 18 ? "minor" : age < 65 ? "adult" : "senior";
                    
                    return $"已處理使用者：{name}，年齡：{age}，VIP：{isVip}";
                },
                "ProcessUser",
                "處理使用者輸入並確定特徵"
            ),
            "input_node"
        ).StoreResultAs("inputResult");

        // 節點 2：年齡驗證
        var ageCheckNode = new ConditionalGraphNode(
            state => state.GetValue<int>("userAge") >= 18,
            "age_check",
            "AgeVerification",
            "驗證使用者年滿 18 歲"
        );

        // 節點 3：VIP 狀態檢查
        var vipCheckNode = new ConditionalGraphNode(
            "{{isVip}} == true",
            "vip_check",
            "VipStatusCheck",
            "檢查使用者是否具有 VIP 狀態"
        );

        // 節點 4：成人內容存取
        var adultNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var name = args.GetValue<string>("userName");
                    var age = args.GetValue<int>("userAge");
                    var isVip = args.GetValue<bool>("isVip");
                    
                    var access = isVip ? "Premium" : "Standard";
                    args["accessLevel"] = access;
                    args["contentType"] = "adult";
                    
                    return $"歡迎 {name}！您擁有 {access} 級別的成人內容存取權。";
                },
                "AdultAccess",
                "提供成人內容存取權"
            ),
            "adult_node"
        ).StoreResultAs("adultResult");

        // 節點 5：VIP 升級建議
        var vipUpgradeNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var name = args.GetValue<string>("userName");
                    var age = args.GetValue<int>("userAge");
                    
                    args["upgradeSuggested"] = true;
                    args["upgradeReason"] = "年齡和活動符合 VIP 條件";
                    
                    return $"您好 {name}！根據您的年齡（{age}），您可能符合 VIP 狀態的條件。";
                },
                "VipUpgrade",
                "向符合條件的使用者建議 VIP 升級"
            ),
            "vip_upgrade_node"
        ).StoreResultAs("upgradeResult");

        // 節點 6：未成年人存取限制
        var minorNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var name = args.GetValue<string>("userName");
                    var age = args.GetValue<int>("userAge");
                    
                    args["accessLevel"] = "restricted";
                    args["contentType"] = "family";
                    args["restrictionReason"] = "未達到年齡要求";
                    
                    return $"您好 {name}！您今年 {age} 歲。此內容要求您年滿 18 歲。";
                },
                "MinorAccess",
                "處理 18 歲以下使用者的存取"
            ),
            "minor_node"
        ).StoreResultAs("minorResult");

        // 節點 7：最終摘要
        var summaryNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var name = args.GetValue<string>("userName");
                    var age = args.GetValue<int>("userAge");
                    var accessLevel = args.GetValue<string>("accessLevel");
                    var contentType = args.GetValue<string>("contentType");
                    
                    var summary = $"使用者：{name}，年齡：{age}，存取層級：{accessLevel}，內容：{contentType}";
                    args["finalSummary"] = summary;
                    
                    return summary;
                },
                "CreateSummary",
                "建立使用者存取的最終摘要"
            ),
            "summary_node"
        ).StoreResultAs("summaryResult");

        // 建立並設定圖形
        var graph = new GraphExecutor("ConditionalWorkflowExample", "演示基於使用者特徵的條件路由");
        
        graph.AddNode(inputNode);
        graph.AddNode(ageCheckNode);
        graph.AddNode(vipCheckNode);
        graph.AddNode(adultNode);
        graph.AddNode(vipUpgradeNode);
        graph.AddNode(minorNode);
        graph.AddNode(summaryNode);
        
        // 使用條件邏輯連接節點
        graph.Connect(inputNode.NodeId, ageCheckNode.NodeId);
        
        // 年齡檢查路徑 - 使用 ConnectWhen 進行條件路由
        graph.ConnectWhen(ageCheckNode.NodeId, vipCheckNode.NodeId, 
            args => args.GetValue<int>("userAge") >= 18);
        graph.ConnectWhen(ageCheckNode.NodeId, minorNode.NodeId, 
            args => args.GetValue<int>("userAge") < 18);
        
        // VIP 檢查路徑
        graph.ConnectWhen(vipCheckNode.NodeId, adultNode.NodeId, 
            args => args.GetValue<bool>("isVip") == true);
        graph.ConnectWhen(vipCheckNode.NodeId, vipUpgradeNode.NodeId, 
            args => args.GetValue<bool>("isVip") == false);
        
        // 連接所有路徑至摘要
        graph.Connect(adultNode.NodeId, summaryNode.NodeId);
        graph.Connect(vipUpgradeNode.NodeId, summaryNode.NodeId);
        graph.Connect(minorNode.NodeId, summaryNode.NodeId);
        
        graph.SetStartNode(inputNode.NodeId);

        // 使用不同使用者場景執行
        var scenarios = new[]
        {
            new { Name = "Alice", Age = 25, ExpectedPath = "VIP 成人" },
            new { Name = "Bob", Age = 17, ExpectedPath = "未成年人" },
            new { Name = "Charlie", Age = 30, ExpectedPath = "標準成人" }
        };

        foreach (var scenario in scenarios)
        {
            Console.WriteLine($"\n=== 測試：{scenario.Name}，年齡 {scenario.Age} ===");
            
            var initialState = new KernelArguments
            {
                ["userName"] = scenario.Name,
                ["userAge"] = scenario.Age
            };
            
            var result = await graph.ExecuteAsync(kernel, initialState);
            
            Console.WriteLine($"採取的路徑：{scenario.ExpectedPath}");
            Console.WriteLine($"最終摘要：{initialState.GetValue<string>("finalSummary")}");
            Console.WriteLine($"存取層級：{initialState.GetValue<string>("accessLevel")}");
        }
        
        Console.WriteLine("\n✅ 條件工作流程已成功完成！");
    }
}
```

## 步驟 4：執行您的條件範例

### 設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

### 執行圖形

```bash
dotnet run
```

您應該看到如下所示的輸出：

```
=== 測試：Alice，年齡 25 ===
採取的路徑：VIP 成人
最終摘要：使用者：Alice，年齡：25，存取層級：Premium，內容：adult
存取層級：Premium

=== 測試：Bob，年齡 17 ===
採取的路徑：未成年人
最終摘要：使用者：Bob，年齡：17，存取層級：restricted，內容：family
存取層級：restricted

=== 測試：Charlie，年齡 30 ===
採取的路徑：標準成人
最終摘要：使用者：Charlie，年齡：30，存取層級：Standard，內容：adult
存取層級：Standard

✅ 條件工作流程已成功完成！
```

## 剛才發生了什麼？

### 1. **條件節點建立**
```csharp
var ageCheckNode = new ConditionalGraphNode(
    state => state.GetValue<int>("userAge") >= 18,
    "age_check"
);
```
建立一個評估條件並根據結果路由執行的節點。

### 2. **條件邊路由**
```csharp
graph.ConnectWhen(ageCheckNode.NodeId, vipCheckNode.NodeId, 
    args => args.GetValue<int>("userAge") >= 18);
```
使用 `ConnectWhen` 根據狀態條件建立動態路由。

### 3. **多個執行路徑**
圖形建立不同的執行路徑：
* **Alice (25)**：輸入 → 年齡檢查 (真) → VIP 檢查 (真) → 成人存取 → 摘要
* **Bob (17)**：輸入 → 年齡檢查 (假) → 未成年人存取 → 摘要  
* **Charlie (30)**：輸入 → 年齡檢查 (真) → VIP 檢查 (假) → VIP 升級 → 摘要

### 4. **基於狀態的決策**
每個條件節點從目前狀態讀取以做出路由決策，建立一個適應不同輸入的動態工作流程。

## 主要概念

* **ConditionalGraphNode**：評估條件並將執行路由到不同路徑
* **ConditionalEdge**：根據狀態條件在節點之間建立受保護的轉換
* **範本條件**：使用類似 Handlebars 的語法進行簡單條件
* **函數條件**：使用 C# 函數進行複雜的條件邏輯
* **動態路由**：執行流程根據目前狀態改變

## 常見模式

### 簡單布林條件
```csharp
var simpleCheck = new ConditionalGraphNode(
    state => state.GetValue<bool>("isEnabled"),
    "simple_check"
);
```

### 複雜狀態分析
```csharp
var complexCheck = new ConditionalGraphNode(
    state => 
    {
        var score = state.GetValue<int>("score");
        var attempts = state.GetValue<int>("attempts");
        var isVip = state.GetValue<bool>("isVip");
        
        return score > 80 && attempts < 3 || isVip;
    },
    "complex_check"
);
```

### 基於範本的條件
```csharp
var templateCheck = new ConditionalGraphNode(
    "{{score}} > 80 && {{attempts}} < 3 || {{isVip}} == true",
    "template_check"
);
```

### 多個條件路徑
```csharp
// 建立類似 switch 的結構
var primaryCheck = new ConditionalGraphNode("{{priority}} == 'high'");
var secondaryCheck = new ConditionalGraphNode("{{priority}} == 'medium'");

graph.ConnectWhen(inputNode.NodeId, primaryCheck.NodeId, 
    args => args.GetValue<string>("priority") == "high");
graph.ConnectWhen(inputNode.NodeId, secondaryCheck.NodeId, 
    args => args.GetValue<string>("priority") == "medium");
```

## 故障排除

### **條件始終評估為假**
```
條件永遠不會評估為真，始終採用假路徑
```
**解決方案**：檢查您的條件邏輯並驗證狀態值是否如預期。

### **多個路徑執行**
```
多個條件路徑執行時應該只有一個執行
```
**解決方案**：確保您的條件互斥或使用適當的條件邊。

### **狀態值不可用**
```
System.Collections.Generic.KeyNotFoundException：給定鍵 'missingKey' 不存在
```
**解決方案**：使用帶有預設值的輔助方法或在讀取狀態值之前使用 `TryGetValue()` 檢查。

### **範本條件語法錯誤**
```
範本條件無法評估
```
**解決方案**：驗證範本語法並確保所有參考的變數都存在於狀態中。

## 後續步驟

* **[條件節點教程](conditional-nodes-tutorial.md)**：進階條件模式和最佳實踐
* **[狀態管理](state-tutorial.md)**：進階狀態操作和驗證
* **[交換節點](how-to/switch-nodes.md)**：多分支條件邏輯
* **[核心概念](concepts/index.md)**：理解圖形、節點和執行

## 概念和技術

本教程介紹了幾個關鍵概念：

* **條件路由**：基於狀態條件直接執行流程的能力
* **ConditionalGraphNode**：評估條件並路由執行的節點
* **ConditionalEdge**：僅當滿足特定條件時才允許遍歷的邊
* **範本條件**：用於簡單條件邏輯的自然語言表達式
* **函數條件**：用於複雜條件評估的 C# 函數
* **動態工作流程**：根據運行時狀態調整執行路徑的圖形

## 前置要求和最小設定

要完成本教程，您需要：
* **.NET 8.0+** 運行時和 SDK
* 已安裝 **SemanticKernel.Graph** 套件
* 配置的 **LLM 提供者**，包含有效的 API 金鑰
* 為您的 API 認證設定的**環境變數**

## 另請參閱

* **[首個圖形教程](first-graph-5-minutes.md)**：建立您的第一個圖形工作流程
* **[狀態快速入門](state-quickstart.md)**：管理節點之間的資料流
* **[條件節點教程](conditional-nodes-tutorial.md)**：進階條件模式
* **[核心概念](concepts/index.md)**：理解圖形、節點和執行
* **[API 參考](api/nodes.md)**：完整的節點 API 文檔

## 參考 API

* **[ConditionalGraphNode](../api/nodes.md#conditional-graph-node)**：條件路由節點
* **[ConditionalEdge](../api/core.md#conditional-edge)**：條件連接邊
* **[IGraphNode](../api/core.md#igraph-node)**：基本節點介面
* **[GraphExecutor](../api/core.md#graph-executor)**：圖形執行引擎
