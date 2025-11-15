# 斷言與建議範例

此範例示範如何對大型語言模型輸出強制實施約束、驗證內容是否符合業務規則，以及提供可行動的修正建議。

## 目標

學習如何在基於圖形的系統中實現內容驗證和建議工作流程，以便：
* 對大型語言模型輸出強制實施業務約束和內容政策
* 自動驗證內容品質和合規性
* 生成可行動的內容改進建議
* 透過驗證和修正循環實現持續的內容品質改進
* 使用備用機制優雅地處理約束違規

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 基本瞭解 [圖形概念](../concepts/graph-concepts.md)和 [節點類型](../concepts/node-types.md)
* 熟悉 [狀態管理](../concepts/state.md)

## 關鍵元件

### 概念和技術

* **內容驗證**：對預定義約束進行自動內容檢查
* **約束強制實施**：具有清晰錯誤報告的業務規則驗證
* **建議生成**：針對內容改進的可行動建議
* **反饋循環**：透過驗證和修正循環進行持續改進
* **狀態管理**：在圖形執行期間追蹤驗證結果和建議

### 核心類別

* `FunctionGraphNode`：用於內容生成、驗證和重寫的節點
* `KernelFunctionFactory`：從方法建立核心函數的工廠
* `GraphExecutor`：用於執行驗證工作流程的執行器
* `GraphState`：驗證結果和建議的狀態管理
* `KernelArguments`：圖形執行的輸入/輸出管理

## 執行範例

### 入門

此範例使用 Semantic Kernel Graph 套件展示驗證和建議模式。下面的程式碼片段向您展示如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. 建立驗證圖形

此範例建立一個具有三個主要節點的簡單圖形：草稿生成、驗證和重寫。

```csharp
// 建立圖形執行器以託管驗證工作流程。
// 這是用於文件和本地測試的最小化記憶體中圖形。
var graph = new GraphExecutor("AssertAndSuggest", "Validate output and suggest fixes");

// 1) 草稿節點：模擬故意違反約束的大型語言模型草稿。
// 該節點將其產生的草稿儲存到圖形狀態中，其關鍵字為 "draft_output"。
var draftNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod(
        () =>
        {
            // 故意違反的草稿：宣傳用語和過長的摘要
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

驗證節點根據業務約束檢查內容並生成建議。

```csharp
// 2) 驗證節點：檢查草稿、斷言約束，並向狀態發出建議。
// 它將驗證結果標誌和文本建議寫入 KernelArguments 以供下游節點使用。
var validateNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        var text = args.TryGetValue("draft_output", out var o) ? o?.ToString() ?? string.Empty : string.Empty;
        var (valid, errors, suggestions) = ValidateConstraints(text);

        // 在共享引數中儲存布林值有效性和序列化訊息
        args["assert_valid"] = valid;
        args["assert_errors"] = string.Join(" | ", errors ?? Array.Empty<string>());
        args["suggestions"] = string.Join(" | ", suggestions ?? Array.Empty<string>());

        return valid ? "valid" : "invalid";
    }, functionName: "validate_output", description: "Validates output and provides suggestions"),
    nodeId: "validate", description: "Validation").StoreResultAs("validation_result");
```

### 3. 實現內容重寫

重寫節點應用建議以產生修正內容。

```csharp
// 3) 重寫節點：應用建議並將修正的草稿寫回狀態。
// 應用修復後，它重新執行驗證以更新有效性標誌。
var rewriteNode = new FunctionGraphNode(
    KernelFunctionFactory.CreateFromMethod((KernelArguments args) =>
    {
        var text = args.TryGetValue("draft_output", out var o) ? o?.ToString() ?? string.Empty : string.Empty;
        var fixedText = ApplySuggestions(text);
        args["rewritten_output"] = fixedText;

        // 重新驗證修正的文本以更新 assert_valid/assert_errors
        var (valid, errors, _) = ValidateConstraints(fixedText);
        args["assert_valid"] = valid;
        args["assert_errors"] = valid ? string.Empty : string.Join(" | ", errors ?? Array.Empty<string>());
        return fixedText;
    }, functionName: "rewrite_with_suggestions", description: "Produces a corrected rewrite"),
    nodeId: "rewrite", description: "Rewrite");
```

### 4. 內容呈現和結果

呈現節點顯示最終結果和驗證狀態。

```csharp
// 4) 呈現節點：列印原始草稿、任何驗證錯誤、建議和重寫文本。
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

### 5. 圖形組件和執行

節點被連接以形成驗證工作流程。

```csharp
// 組件圖形並將節點連接在一起。使用清晰、確定性的路由
// 以便文件範例保持易於遵循。
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

此範例為內容驗證實現特定的業務約束。

```csharp
private static (bool valid, string[] errors, string[] suggestions) ValidateConstraints(string text)
{
    // 返回具有清晰訊息的集合。保持邏輯簡單且確定性以供文件使用。
    var errors = new List<string>();
    var suggestions = new List<string>();

    if (string.IsNullOrWhiteSpace(text))
    {
        errors.Add("Content is empty");
        suggestions.Add("Provide a draft containing a Title and Summary lines");
        return (false, errors.ToArray(), suggestions.ToArray());
    }

    // 宣傳語言檢查
    if (text.Contains("free", StringComparison.OrdinalIgnoreCase) ||
        text.Contains("unlimited", StringComparison.OrdinalIgnoreCase) ||
        text.Contains("best in class", StringComparison.OrdinalIgnoreCase))
    {
        errors.Add("Contains promotional language");
        suggestions.Add("Remove promotional terms like 'free', 'unlimited', or 'best in class'");
    }

    // 長度限制（文件範例使用寬鬆的閾值）
    if (text.Length > 500)
    {
        errors.Add($"Content too long ({text.Length} characters)");
        suggestions.Add("Keep content concise, consider shortening the Summary");
    }

    // 緊急語言
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

重寫邏輯應用建議以修正內容。

```csharp
private static string ApplySuggestions(string text)
{
    if (string.IsNullOrWhiteSpace(text)) return string.Empty;

    // 用於文件目的的確定性、基於規則的修正。
    var corrected = text.Replace("free", "premium", StringComparison.OrdinalIgnoreCase);
    corrected = corrected.Replace("unlimited", "comprehensive", StringComparison.OrdinalIgnoreCase);
    corrected = corrected.Replace("best in class", "high-quality", StringComparison.OrdinalIgnoreCase);

    // 移除緊急術語
    corrected = corrected.Replace("right now", "available", StringComparison.OrdinalIgnoreCase);
    corrected = corrected.Replace("immediately", "promptly", StringComparison.OrdinalIgnoreCase);

    // 截斷長內容以保持範例簡潔
    if (corrected.Length > 500)
    {
        corrected = corrected.Substring(0, 497) + "...";
    }

    return corrected;
}
```

## 預期輸出

此範例產生全面的輸出，顯示：

* 📝 具有約束違規的原始草稿內容
* ❌ 驗證錯誤和業務規則違規
* 💡 內容改進的可行動建議
* ✅ 應用約束的修正版本
* 🎯 最終驗證狀態（PASSED/FAILED）
* 📋 完整的驗證工作流程結果

## 故障排除

### 常見問題

1. **約束驗證失敗**：確保約束邏輯處理邊界情況和空值
2. **建議應用錯誤**：驗證建議邏輯不會引入新的違規
3. **狀態管理問題**：檢查驗證結果是否正確儲存和檢索
4. **內容長度問題**：監視內容長度約束和截斷邏輯

### 除錯提示

* 啟用詳細記錄以追蹤驗證步驟
* 監視驗證節點之間的狀態轉換
* 驗證約束邏輯是否處理所有內容類型
* 檢查建議應用的完整性

## 參見

* [內容驗證](../how-to/content-validation.md)
* [狀態管理](../concepts/state.md)
* [節點類型](../concepts/node-types.md)
* [圖形概念](../concepts/graph-concepts.md)
* [錯誤處理](../how-to/error-handling-and-resilience.md)
