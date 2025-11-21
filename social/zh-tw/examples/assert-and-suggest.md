# 斷言與建議示例

此示例演示了如何對 LLM 輸出強制約束、根據業務規則驗證內容，以及提供可操作的修正建議。

## 目標

了解如何在基於 Graph 的系統中實現內容驗證和建議工作流程：
* 對 LLM 輸出強制業務約束和內容政策
* 自動驗證內容品質和合規性
* 生成內容改進的可操作建議
* 通過驗證和更正週期實現持續的內容品質改進
* 使用備用機制優雅地處理約束違反

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中已配置
* **Semantic Kernel Graph 套件**已安裝
* 對 [Graph Concepts](../concepts/graph-concepts.md) 和 [Node Types](../concepts/node-types.md) 的基本理解
* 熟悉 [State Management](../concepts/state.md)

## 關鍵元件

### 概念與技術

* **Content Validation**：根據預定義的約束自動檢查內容
* **Constraint Enforcement**：業務規則驗證，包含清晰的錯誤報告
* **Suggestion Generation**：內容改進的可操作建議
* **Feedback Loops**：通過驗證和修正週期實現持續改進
* **State Management**：在 Graph 執行過程中追蹤驗證結果和建議

### 核心類別

* `FunctionGraphNode`：用於內容生成、驗證和重寫的 Node
* `KernelFunctionFactory`：從方法建立 Kernel 函數的工廠
* `GraphExecutor`：運行驗證工作流程的執行器
* `GraphState`：驗證結果和建議的狀態管理
* `KernelArguments`：Graph 執行的輸入/輸出管理

## 運行示例

### 入門指南

此示例通過 Semantic Kernel Graph 套件演示驗證和建議模式。下面的程式碼片段向你展示如何在自己的應用程式中實現此模式。

## 分步實現

### 1. 建立驗證 Graph

此示例建立了一個具有三個主要 Node 的簡單 Graph：草稿生成、驗證和重寫。

```csharp
// 建立一個將託管驗證工作流程的 Graph 執行器。
// 這是一個用於文檔和本地測試的最小內存 Graph。
var graph = new GraphExecutor("AssertAndSuggest", "Validate output and suggest fixes");

// 1) 草稿 Node：模擬一個故意違反約束的 LLM 草稿。
// 該 Node 將其生成的草稿存儲在 Graph 狀態中的「draft_output」鍵下。
var draftNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () =>
        {
            // 故意違反的草稿：推廣詞彙和過長的摘要
            var draft = "Title: Super Gadget Pro Max\n" +
                        "Summary: This is a free, absolutely unbeatable gadget with unlimited features, " +
                        "best in class performance, and a comprehensive set of accessories included for everyone right now.";
            return draft;
        },
        functionName: "generate_draft",
        description: "Generates an initial draft (simulated LLM output)"),
    nodeId: "draft",
    description: "Draft generation")
    .StoreResultAs("draft_output");
```

### 2. 實現內容驗證

驗證 Node 檢查內容是否遵守業務約束並生成建議。

```csharp
// 2) 驗證 Node：檢查草稿、斷言約束，並將建議發送到狀態。
// 它將驗證結果標記和文字建議寫入 KernelArguments 供下游 Node 使用。
var validateNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        var text = args.TryGetValue("draft_output", out var o) ? o?.ToString() ?? string.Empty : string.Empty;
        var (valid, errors, suggestions) = ValidateConstraints(text);

        // 將布林值有效性和序列化訊息存儲在共享的引數中
        args["assert_valid"] = valid;
        args["assert_errors"] = string.Join(" | ", errors ?? Array.Empty<string>());
        args["suggestions"] = string.Join(" | ", suggestions ?? Array.Empty<string>());

        return valid ? "valid" : "invalid";
    }, functionName: "validate_output", description: "Validates output and provides suggestions"),
    nodeId: "validate", description: "Validation").StoreResultAs("validation_result");
```

### 3. 實現內容重寫

重寫 Node 應用建議來產生修正的內容。

```csharp
// 3) 重寫 Node：應用建議並將修正後的草稿寫回狀態。
// 應用修復後，它重新運行驗證來更新有效性標記。
var rewriteNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        var text = args.TryGetValue("draft_output", out var o) ? o?.ToString() ?? string.Empty : string.Empty;
        var fixedText = ApplySuggestions(text);
        args["rewritten_output"] = fixedText;

        // 重新驗證修正文本以更新 assert_valid/assert_errors
        var (valid, errors, _) = ValidateConstraints(fixedText);
        args["assert_valid"] = valid;
        args["assert_errors"] = valid ? string.Empty : string.Join(" | ", errors ?? Array.Empty<string>());
        return fixedText;
    }, functionName: "rewrite_with_suggestions", description: "Produces a corrected rewrite"),
    nodeId: "rewrite", description: "Rewrite");
```

### 4. 內容呈現與結果

呈現 Node 顯示最終結果和驗證狀態。

```csharp
// 4) 呈現 Node：打印原始草稿、任何驗證錯誤、建議和重寫文本。
var presentNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        var original = args.TryGetValue("draft_output", out var o) ? o?.ToString() ?? string.Empty : string.Empty;
        var rewritten = args.TryGetValue("rewritten_output", out var r) ? r?.ToString() ?? string.Empty : string.Empty;
        var errors = args.TryGetValue("assert_errors", out var e) ? e?.ToString() ?? string.Empty : string.Empty;
        var suggestions = args.TryGetValue("suggestions", out var s) ? s?.ToString() ?? string.Empty : string.Empty;
        var finalValid = args.TryGetValue("assert_valid", out var v) && v is bool b && b;

        Console.WriteLine("\n📋 Content Validation Results:");
        Console.WriteLine(new string('=', 60));

        Console.WriteLine("\n📝 Original Draft:");
        Console.WriteLine(original);

        if (!string.IsNullOrEmpty(errors))
        {
            Console.WriteLine("\n❌ Validation Errors:");
            Console.WriteLine(errors);
        }

        if (!string.IsNullOrEmpty(suggestions))
        {
            Console.WriteLine("\n💡 Suggestions:");
            Console.WriteLine(suggestions);
        }

        if (!string.IsNullOrWhiteSpace(rewritten))
        {
            Console.WriteLine("\n✅ Corrected Version:");
            Console.WriteLine(rewritten);
        }

        Console.WriteLine($"\n🎯 Final Validation: {(finalValid ? "PASSED" : "FAILED")}");
        return "Content validation and correction completed";
    }, functionName: "present_results", description: "Presents validation results"),
    nodeId: "present", description: "Results Presentation");
```

### 5. Graph 組裝與執行

Node 連接形成驗證工作流程。

```csharp
// 組裝 Graph 並將 Node 連接在一起。使用清晰、確定性的路由
// 以便文檔示例易於跟蹤。
graph.AddNode(draftNode);
graph.AddNode(validateNode);
graph.AddNode(rewriteNode);
graph.AddNode(presentNode);

// 路由：draft -> validate
graph.ConnectWhen(draftNode.NodeId, validateNode.NodeId, _ => true);
// 如果驗證成功，直接進行呈現
graph.ConnectWhen(validateNode.NodeId, presentNode.NodeId, ka => ka.TryGetValue("assert_valid", out var v) && v is bool vb && vb);
// 否則重寫然後呈現
graph.ConnectWhen(validateNode.NodeId, rewriteNode.NodeId, ka => !(ka.TryGetValue("assert_valid", out var v) && v is bool vb2 && vb2));
graph.ConnectWhen(rewriteNode.NodeId, presentNode.NodeId, _ => true);

// 執行驗證工作流程
var args = new KernelArguments();
var result = await graph.ExecuteAsync(kernel, args);
```

### 6. 約束驗證邏輯

此示例實現了內容驗證的特定業務約束。

```csharp
private static (bool valid, string[] errors, string[] suggestions) ValidateConstraints(string text)
{
    // 返回具有清晰訊息的集合。保持邏輯簡單且確定性，用於文檔。
    var errors = new List<string>();
    var suggestions = new List<string>();

    if (string.IsNullOrWhiteSpace(text))
    {
        errors.Add("Content is empty");
        suggestions.Add("Provide a draft containing a Title and Summary lines");
        return (false, errors.ToArray(), suggestions.ToArray());
    }

    // 推廣語言檢查
    if (text.Contains("free", StringComparison.OrdinalIgnoreCase) ||
        text.Contains("unlimited", StringComparison.OrdinalIgnoreCase) ||
        text.Contains("best in class", StringComparison.OrdinalIgnoreCase))
    {
        errors.Add("Contains promotional language");
        suggestions.Add("Remove promotional terms like 'free', 'unlimited', or 'best in class'");
    }

    // 長度限制（文檔示例使用大方的閾值）
    if (text.Length > 500)
    {
        errors.Add($"Content too long ({text.Length} characters)");
        suggestions.Add("Keep content concise, consider shortening the Summary");
    }

    // 緊急性語言
    if (text.Contains("right now", StringComparison.OrdinalIgnoreCase) ||
        text.Contains("immediately", StringComparison.OrdinalIgnoreCase))
    {
        errors.Add("Contains urgency language");
        suggestions.Add("Avoid urgency words such as 'right now' or 'immediately'");
    }

    return (errors.Count == 0, errors.ToArray(), suggestions.ToArray());
}
```

### 7. 建議應用邏輯

重寫邏輯應用建議來修正內容。

```csharp
private static string ApplySuggestions(string text)
{
    if (string.IsNullOrWhiteSpace(text)) return string.Empty;

    // 用於文檔目的的確定性、基於規則的修正。
    var corrected = text.Replace("free", "premium", StringComparison.OrdinalIgnoreCase);
    corrected = corrected.Replace("unlimited", "comprehensive", StringComparison.OrdinalIgnoreCase);
    corrected = corrected.Replace("best in class", "high-quality", StringComparison.OrdinalIgnoreCase);

    // 移除緊急性詞彙
    corrected = corrected.Replace("right now", "available", StringComparison.OrdinalIgnoreCase);
    corrected = corrected.Replace("immediately", "promptly", StringComparison.OrdinalIgnoreCase);

    // 截斷長內容以保持示例簡潔
    if (corrected.Length > 500)
    {
        corrected = corrected.Substring(0, 497) + "...";
    }

    return corrected;
}
```

## 預期輸出

此示例產生全面的輸出，顯示：

* 📝 具有約束違反的原始草稿內容
* ❌ 驗證錯誤和業務規則違反
* 💡 內容改進的可操作建議
* ✅ 應用約束的修正版本
* 🎯 最終驗證狀態（已通過/失敗）
* 📋 完整的驗證工作流程結果

## 故障排除

### 常見問題

1. **約束驗證失敗**：確保約束邏輯處理邊界情況和空值
2. **建議應用錯誤**：驗證建議邏輯不會引入新的違反
3. **狀態管理問題**：檢查驗證結果是否正確存儲和檢索
4. **內容長度問題**：監控內容長度約束和截斷邏輯

### 除錯提示

* 啟用詳細日誌記錄以追蹤驗證步驟
* 監控驗證 Node 之間的狀態轉換
* 驗證約束邏輯處理所有內容類型
* 檢查建議應用的完整性

## 另請參閱

* [Content Validation](../how-to/content-validation.md)
* [State Management](../concepts/state.md)
* [Node Types](../concepts/node-types.md)
* [Graph Concepts](../concepts/graph-concepts.md)
* [Error Handling](../how-to/error-handling-and-resilience.md)
