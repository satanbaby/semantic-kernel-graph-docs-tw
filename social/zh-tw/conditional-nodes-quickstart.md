# 條件Node快速入門

本快速教學將教導您如何在 SemanticKernel.Graph 中使用條件Node和Edge，以建立可以根據狀態進行決策和路由執行的動態工作流程。

## 您將學習的內容

* 建立 `ConditionalGraphNode` 用於 if/else 邏輯
* 使用 `ConditionalEdge` 進行動態路由
* 建構適應不同場景的工作流程
* 基於範本和函數的條件

## 概念和技術

**ConditionalGraphNode**: 一種專用的Node類型，可評估條件並根據結果將執行路由到不同路徑。

**ConditionalEdge**: 連接條件Node到其真/假執行路徑的Edge，可啟用動態工作流程路由。

**動態路由**: Graph根據執行時間條件和狀態值改變執行路徑的能力。

**範本運算式**: 可參考狀態變數並在執行時評估的基於字串的條件。

## 先決條件

* [First Graph 教學](first-graph-5-minutes.md) 已完成
* [State 快速入門](state-quickstart.md) 已完成
* 對 SemanticKernel.Graph 概念的基本了解

## 步驟 1: 基本條件Node

### 簡單的 If/Else 邏輯

```csharp
using SemanticKernel.Graph.Nodes;

// 建立條件Node檢查使用者年齡
var ageCheckNode = new ConditionalGraphNode(
    state => state.GetValue<int>("userAge") >= 18,
    "age_check",
    "AgeVerification",
    "Checks if user is 18 or older"
);
```

### 使用基於範本的條件

```csharp
// 替代方案: 使用範本運算式
var templateAgeCheck = new ConditionalGraphNode(
    "{{userAge}} >= 18",
    "template_age_check",
    "TemplateAgeCheck",
    "Template-based age verification"
);
```

## 步驟 2: 連接條件路徑

### 新增真/假Node

```csharp
// 為不同路徑建立函數Node
var adultNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () => "Welcome! You have access to adult content.",
        "AdultAccess",
        "Provides adult content access"
    ),
    "adult_node"
);

var minorNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () => "Sorry, you must be 18 or older to access this content.",
        "MinorAccess",
        "Informs user about age restriction"
    ),
    "minor_node"
);

// 連接條件路徑
ageCheckNode
    .AddTrueNode(adultNode)    // 如果條件為真則執行
    .AddFalseNode(minorNode);  // 如果條件為假則執行
```

## 步驟 3: 建構完整的條件工作流程

### 建立 Graph

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

// KernelArguments 的幫助程式擴充類別
public static class KernelArgumentsExtensions
{
    // 幫助程式方法以安全地從 KernelArguments 取得具型別值
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

        // Node 1: 輸入處理
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
                    
                    return $"Processed user: {name}, Age: {age}, VIP: {isVip}";
                },
                "ProcessUser",
                "Processes user input and determines characteristics"
            ),
            "input_node"
        ).StoreResultAs("inputResult");

        // Node 2: 年齡驗證
        var ageCheckNode = new ConditionalGraphNode(
            state => state.GetValue<int>("userAge") >= 18,
            "age_check",
            "AgeVerification",
            "Verifies user is 18 or older"
        );

        // Node 3: VIP 狀態檢查
        var vipCheckNode = new ConditionalGraphNode(
            "{{isVip}} == true",
            "vip_check",
            "VipStatusCheck",
            "Checks if user has VIP status"
        );

        // Node 4: 成人內容存取
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
                    
                    return $"Welcome {name}! You have {access} access to adult content.";
                },
                "AdultAccess",
                "Provides adult content access"
            ),
            "adult_node"
        ).StoreResultAs("adultResult");

        // Node 5: VIP 升級建議
        var vipUpgradeNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var name = args.GetValue<string>("userName");
                    var age = args.GetValue<int>("userAge");
                    
                    args["upgradeSuggested"] = true;
                    args["upgradeReason"] = "Age and activity qualify for VIP";
                    
                    return $"Hello {name}! Based on your age ({age}), you might qualify for VIP status.";
                },
                "VipUpgrade",
                "Suggests VIP upgrade for eligible users"
            ),
            "vip_upgrade_node"
        ).StoreResultAs("upgradeResult");

        // Node 6: 未成年人存取限制
        var minorNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var name = args.GetValue<string>("userName");
                    var age = args.GetValue<int>("userAge");
                    
                    args["accessLevel"] = "restricted";
                    args["contentType"] = "family";
                    args["restrictionReason"] = "Age requirement not met";
                    
                    return $"Hello {name}! You're {age} years old. This content requires you to be 18 or older.";
                },
                "MinorAccess",
                "Handles access for users under 18"
            ),
            "minor_node"
        ).StoreResultAs("minorResult");

        // Node 7: 最終摘要
        var summaryNode = new FunctionGraphNode(
            KernelFunctionFactory.CreateFromMethod(
                (KernelArguments args) =>
                {
                    var name = args.GetValue<string>("userName");
                    var age = args.GetValue<int>("userAge");
                    var accessLevel = args.GetValue<string>("accessLevel");
                    var contentType = args.GetValue<string>("contentType");
                    
                    var summary = $"User: {name}, Age: {age}, Access: {accessLevel}, Content: {contentType}";
                    args["finalSummary"] = summary;
                    
                    return summary;
                },
                "CreateSummary",
                "Creates final summary of user access"
            ),
            "summary_node"
        ).StoreResultAs("summaryResult");

        // 建構並配置 Graph
        var graph = new GraphExecutor("ConditionalWorkflowExample", "Demonstrates conditional routing based on user characteristics");
        
        graph.AddNode(inputNode);
        graph.AddNode(ageCheckNode);
        graph.AddNode(vipCheckNode);
        graph.AddNode(adultNode);
        graph.AddNode(vipUpgradeNode);
        graph.AddNode(minorNode);
        graph.AddNode(summaryNode);
        
        // 使用條件邏輯連接Node
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
        
        // 將所有路徑連接到摘要
        graph.Connect(adultNode.NodeId, summaryNode.NodeId);
        graph.Connect(vipUpgradeNode.NodeId, summaryNode.NodeId);
        graph.Connect(minorNode.NodeId, summaryNode.NodeId);
        
        graph.SetStartNode(inputNode.NodeId);

        // 使用不同的使用者情境執行
        var scenarios = new[]
        {
            new { Name = "Alice", Age = 25, ExpectedPath = "VIP Adult" },
            new { Name = "Bob", Age = 17, ExpectedPath = "Minor" },
            new { Name = "Charlie", Age = 30, ExpectedPath = "Standard Adult" }
        };

        foreach (var scenario in scenarios)
        {
            Console.WriteLine($"\n=== Testing: {scenario.Name}, Age {scenario.Age} ===");
            
            var initialState = new KernelArguments
            {
                ["userName"] = scenario.Name,
                ["userAge"] = scenario.Age
            };
            
            var result = await graph.ExecuteAsync(kernel, initialState);
            
            Console.WriteLine($"Path taken: {scenario.ExpectedPath}");
            Console.WriteLine($"Final summary: {initialState.GetValue<string>("finalSummary")}");
            Console.WriteLine($"Access level: {initialState.GetValue<string>("accessLevel")}");
        }
        
        Console.WriteLine("\n✅ Conditional workflow completed successfully!");
    }
}
```

## 步驟 4: 執行您的條件範例

### 設定環境變數

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
```

### 執行 Graph

```bash
dotnet run
```

您應該看到如下輸出:

```
=== Testing: Alice, Age 25 ===
Path taken: VIP Adult
Final summary: User: Alice, Age: 25, Access: Premium, Content: adult
Access level: Premium

=== Testing: Bob, Age 17 ===
Path taken: Minor
Final summary: User: Bob, Age: 17, Access: restricted, Content: family
Access level: restricted

=== Testing: Charlie, Age 30 ===
Path taken: Standard Adult
Final summary: User: Charlie, Age: 30, Access: Standard, Content: adult
Access level: Standard

✅ Conditional workflow completed successfully!
```

## 發生了什麼?

### 1. **條件Node建立**
```csharp
var ageCheckNode = new ConditionalGraphNode(
    state => state.GetValue<int>("userAge") >= 18,
    "age_check"
);
```
建立一個Node，可評估條件並根據結果路由執行。

### 2. **條件Edge路由**
```csharp
graph.ConnectWhen(ageCheckNode.NodeId, vipCheckNode.NodeId, 
    args => args.GetValue<int>("userAge") >= 18);
```
使用 `ConnectWhen` 根據狀態條件建立動態路由。

### 3. **多個執行路徑**
Graph 建立不同的執行路徑:
* **Alice (25)**: 輸入 → 年齡檢查 (真) → VIP 檢查 (真) → 成人存取 → 摘要
* **Bob (17)**: 輸入 → 年齡檢查 (假) → 未成年人存取 → 摘要  
* **Charlie (30)**: 輸入 → 年齡檢查 (真) → VIP 檢查 (假) → VIP 升級 → 摘要

### 4. **基於狀態的決策**
每個條件Node從目前狀態讀取以進行路由決策，建立一個適應不同輸入的動態工作流程。

## 關鍵概念

* **ConditionalGraphNode**: 評估條件並將執行路由到不同路徑
* **ConditionalEdge**: 基於狀態條件在Node之間建立受保護的轉換
* **範本條件**: 使用 Handlebars 類語法進行簡單條件
* **函數條件**: 使用 C# 函數進行複雜的條件邏輯
* **動態路由**: 執行流程根據目前狀態改變

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
// 建立 switch 類結構
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
條件永遠不會評估為真，總是採用假路徑
```
**解決方案**: 檢查您的條件邏輯並驗證狀態值是否符合預期。

### **多個路徑執行**
```
多個條件路徑在執行時只有一個應該執行
```
**解決方案**: 確保您的條件互斥或使用適當的條件Edge。

### **狀態值不可用**
```
System.Collections.Generic.KeyNotFoundException: The given key 'missingKey' was not present
```
**解決方案**: 使用具有預設值的幫助程式方法，或在讀取狀態值之前使用 `TryGetValue()` 檢查。

### **範本條件語法錯誤**
```
範本條件無法評估
```
**解決方案**: 驗證範本語法並確保所有參考的變數存在於狀態中。

## 後續步驟

* **[條件Node教學](conditional-nodes-tutorial.md)**: 進階條件模式和最佳實務
* **[狀態管理](state-tutorial.md)**: 進階狀態操作和驗證
* **[Switch Node](how-to/switch-nodes.md)**: 多分支條件邏輯
* **[核心概念](concepts/index.md)**: 理解Graph、Node和執行

## 概念和技術

本教學介紹了幾個關鍵概念:

* **條件路由**: 根據狀態條件指導執行流程的能力
* **ConditionalGraphNode**: 評估條件並路由執行的Node
* **ConditionalEdge**: 僅在滿足特定條件時允許轉換的Edge
* **範本條件**: 用於簡單條件邏輯的自然語言運算式
* **函數條件**: 用於複雜條件評估的 C# 函數
* **動態工作流程**: 根據執行時間狀態調整執行路徑的Graph

## 先決條件和最小配置

要完成本教學，您需要:
* **.NET 8.0+** 執行時間和 SDK
* **SemanticKernel.Graph** 套件已安裝
* **LLM 提供程式**配置有效的 API 金鑰
* **環境變數**已設定用於您的 API 認證

## 另請參閱

* **[First Graph 教學](first-graph-5-minutes.md)**: 建立您的第一個Graph工作流程
* **[State 快速入門](state-quickstart.md)**: 在Node之間管理資料流
* **[條件Node教學](conditional-nodes-tutorial.md)**: 進階條件模式
* **[核心概念](concepts/index.md)**: 理解Graph、Node和執行
* **[API 參考](api/nodes.md)**: 完整的Node API 文件

## 參考 API

* **[ConditionalGraphNode](../api/nodes.md#conditional-graph-node)**: 條件路由Node
* **[ConditionalEdge](../api/core.md#conditional-edge)**: 條件連線Edge
* **[IGraphNode](../api/core.md#igraph-node)**: 基本Node介面
* **[GraphExecutor](../api/core.md#graph-executor)**: Graph執行引擎
