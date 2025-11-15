# 驗證與編譯

本文件涵蓋了 SemanticKernel.Graph 中的完整驗證和編譯系統，包括工作流程驗證、型別推論、狀態驗證和合併衝突解決。該系統在多個層級提供了強大的驗證，從編譯時的架構檢查到執行時的狀態完整性驗證，確保了可靠的圖形執行和資料一致性。

## WorkflowValidator

`WorkflowValidator` 在執行前驗證多代理工作流程的結構完整性、能力相容性和資源組態健全性，提供詳細的錯誤報告的全面驗證。

### 概述

此驗證器執行非拋出例外的檢查，並將問題彙總到 `ValidationResult` 中，以便早期發現問題，例如無效的依賴項、缺少的能力和組態問題。它支援工作流程結構、代理能力、容量約束和資源治理設定的驗證。

### 主要特性

* **結構驗證**：ID 唯一性、依賴項完整性和循環檢測
* **代理能力驗證**：確保所需的能力可用
* **容量驗證**：驗證代理容量組態
* **資源治理驗證**：檢查資源組態健全性
* **全面報告**：彙總錯誤、警告和建議
* **非拋出設計**：安全的驗證，無例外

### 組態

```csharp
var validator = new WorkflowValidator(logger);

// 使用完整上下文驗證工作流程
var result = validator.Validate(
    workflow: workflow,
    agentRoles: agentRoles,
    agentCapacities: agentCapacities,
    resourceOptions: resourceOptions
);
```

### 工作流程驗證

```csharp
// 建立要驗證的工作流程
var workflow = new MultiAgentWorkflow
{
    Id = "document-analysis-001",
    Name = "Document Analysis Pipeline",
    RequiredAgents = new List<string> { "analysis-agent", "processing-agent" },
    Tasks = new List<WorkflowTask>
    {
        new WorkflowTask
        {
            Id = "extract-text",
            Name = "Text Extraction",
            RequiredCapabilities = new HashSet<string> { "text_extraction", "ocr" },
            DependsOn = new List<string>()
        },
        new WorkflowTask
        {
            Id = "process-content",
            Name = "Content Processing",
            RequiredCapabilities = new HashSet<string> { "text_processing", "nlp" },
            DependsOn = new List<string> { "extract-text" }
        }
    }
};

// 驗證工作流程
var validationResult = validator.Validate(workflow);

if (validationResult.IsValid)
{
    Console.WriteLine("Workflow validation passed");
}
else
{
    Console.WriteLine($"Validation failed with {validationResult.ErrorCount} errors:");
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"  Error: {error.Message} (Property: {error.PropertyName})");
    }
    
    if (validationResult.HasWarnings)
    {
        Console.WriteLine($"Warnings: {validationResult.WarningCount}");
        foreach (var warning in validationResult.Warnings)
        {
            Console.WriteLine($"  Warning: {warning.Message}");
        }
    }
}
```

### 代理能力驗證

```csharp
// 定義具有能力的代理角色
var agentRoles = new Dictionary<string, AgentRole>
{
    ["analysis-agent"] = new AgentRole
    {
        Name = "Document Analyst",
        Capabilities = { "text_extraction", "ocr", "image_analysis" }
    },
    ["processing-agent"] = new AgentRole
    {
        Name = "Content Processor",
        Capabilities = { "text_processing", "nlp", "classification" }
    }
};

// 使用代理角色驗證
var result = validator.Validate(workflow, agentRoles: agentRoles);

// 檢查能力相容性
if (!result.IsValid)
{
    var capabilityErrors = result.Errors
        .Where(e => e.Message.Contains("capabilities"))
        .ToList();
    
    foreach (var error in capabilityErrors)
    {
        Console.WriteLine($"Capability error: {error.Message}");
    }
}
```

### 容量和資源驗證

```csharp
// 定義代理容量
var agentCapacities = new Dictionary<string, AgentCapacity>
{
    ["analysis-agent"] = new AgentCapacity
    {
        AgentId = "analysis-agent",
        MaxCapacity = 5,
        CurrentLoad = 2
    },
    ["processing-agent"] = new AgentCapacity
    {
        AgentId = "processing-agent",
        MaxCapacity = 3,
        CurrentLoad = 1
    }
};

// 定義資源治理選項
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    CpuHighWatermarkPercent = 80,
    CpuSoftLimitPercent = 70,
    MinAvailableMemoryMB = 512,
    BasePermitsPerSecond = 10,
    MaxBurstSize = 20
};

// 使用完整上下文驗證
var result = validator.Validate(
    workflow, 
    agentRoles, 
    agentCapacities, 
    resourceOptions
);
```

## GraphTypeInferenceEngine

`GraphTypeInferenceEngine` 使用可用的型別化架構對圖形執行輕量級型別推論，將已知的輸出型別從來源節點傳播到沒有宣告型別化架構的目標節點。

### 概述

此靜態引擎提供保守的、基於名稱的型別推論，檢查上游節點以確定無型別目標節點的輸入需求。它支援基本型別和 .NET 執行時型別，使型別化架構能夠在圖形元件中逐步採用。

### 主要特性

* **保守推論**：僅在對關係有信心時才推論型別
* **基於名稱的傳播**：跨節點邊界按名稱對應參數
* **上游分析**：檢查前驅節點以獲取型別資訊
* **後退處理**：當無法獲得型別資訊時提供無型別後退
* **靜態分析**：編譯時型別推論，無執行時開銷

### 型別推論

```csharp
var graph = new GraphExecutor("type-inference-example");

// 添加具有已知輸出架構的型別化來源節點
var sourceNode = new TypedSourceNode();
graph.AddNode(sourceNode);

// 添加無型別的目標節點
var targetNode = new UntypedTargetNode();
graph.AddNode(targetNode);

// 連接節點
graph.Connect(sourceNode.NodeId, targetNode.NodeId);

// 為無型別節點推論輸入架構
var inferredSchemas = GraphTypeInferenceEngine.InferInputSchemas(graph);

// 檢查目標節點的推論架構
if (inferredSchemas.TryGetValue(targetNode.NodeId, out var targetSchema))
{
    Console.WriteLine($"Target node input schema:");
    foreach (var input in targetSchema.Inputs)
    {
        Console.WriteLine($"  {input.Key}: {input.Value.Type} (Required: {input.Value.Required})");
        Console.WriteLine($"    Description: {input.Value.Description}");
    }
}
```

### 架構傳播

```csharp
// 建立包含多個型別化節點的圖形
var graph = new GraphExecutor("schema-propagation");

// 具有型別化輸出的來源節點
var dataSource = new DataSourceNode();
graph.AddNode(dataSource);

// 中間處理節點
var processor = new DataProcessorNode();
graph.AddNode(processor);

// 最終輸出節點
var output = new OutputNode();
graph.AddNode(output);

// 連接管道
graph.Connect(dataSource.NodeId, processor.NodeId);
graph.Connect(processor.NodeId, output.NodeId);

// 推論整個管道的架構
var inferredSchemas = GraphTypeInferenceEngine.InferInputSchemas(graph);

// 檢查架構傳播
foreach (var kvp in inferredSchemas)
{
    Console.WriteLine($"Node {kvp.Key} inferred schema:");
    foreach (var input in kvp.Value.Inputs)
    {
        Console.WriteLine($"  Input: {input.Key} -> {input.Value.Type}");
    }
}
```

## StateValidator

`StateValidator` 為圖形狀態提供全面的完整性檢查，確保資料一致性並在執行生命週期早期識別潛在問題。

### 概述

此靜態驗證器執行多個驗證類別，包括基本屬性、資料驗證、執行歷史、版本相容性和大小約束。它為效能敏感的案例提供全面驗證和關鍵屬性驗證。

### 主要特性

* **全面驗證**：完整的狀態完整性檢查
* **關鍵屬性驗證**：快速驗證基本屬性
* **大小和記憶體驗證**：防止過度的資源使用
* **歷史驗證**：確保執行歷史完整性
* **版本相容性**：檢查狀態版本需求

### 狀態驗證

```csharp
var state = new GraphState();

// 添加資料到狀態
state.SetValue("user_id", 123);
state.SetValue("user_name", "John Doe");
state.SetValue("settings", new Dictionary<string, object>
{
    ["theme"] = "dark",
    ["language"] = "en"
});

// 全面驗證
var validationResult = StateValidator.ValidateState(state);

if (validationResult.IsValid)
{
    Console.WriteLine("State validation passed");
}
else
{
    Console.WriteLine($"State validation failed with {validationResult.ErrorCount} errors:");
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"  Error: {error.Message}");
    }
    
    if (validationResult.HasWarnings)
    {
        Console.WriteLine($"Warnings: {validationResult.WarningCount}");
        foreach (var warning in validationResult.Warnings)
        {
            Console.WriteLine($"  Warning: {warning.Message}");
        }
    }
}
```

### 關鍵屬性驗證

```csharp
// 僅進行關鍵屬性的快速驗證
var isCriticalValid = StateValidator.ValidateCriticalProperties(state);

if (isCriticalValid)
{
    Console.WriteLine("Critical state properties are valid");
}
else
{
    Console.WriteLine("Critical state properties validation failed");
}
```

### 驗證類別

```csharp
// 驗證狀態的特定方面
var state = new GraphState();

// 基本屬性驗證
if (string.IsNullOrWhiteSpace(state.StateId))
{
    Console.WriteLine("State ID is missing");
}

// 資料驗證
foreach (var kvp in state.Parameters)
{
    var key = kvp.Key;
    var value = kvp.Value;
    
    // 檢查參數名稱長度
    if (key.Length > 256)
    {
        Console.WriteLine($"Parameter name too long: {key}");
    }
    
    // 檢查字串值長度
    if (value is string strValue && strValue.Length > 1024 * 1024)
    {
        Console.WriteLine($"String value too long for parameter: {key}");
    }
}

// 大小驗證
var stateSize = state.EstimateSize();
if (stateSize > 10 * 1024 * 1024) // 10MB limit
{
    Console.WriteLine($"State size exceeds limit: {stateSize} bytes");
}

// 歷史驗證
if (state.ExecutionHistory.Count > 10000)
{
    Console.WriteLine("Execution history too large");
}
```

## StateMergeConflictPolicy

`StateMergeConflictPolicy` 定義了平行分支聯接期間狀態合併的衝突解決策略，提供靈活和可配置的合併行為。

### 概述

此列舉和組態系統支援從簡單的優先規則到複雜的類似 CRDT 的語義的多個合併策略。它在圖形執行期間實現了對衝突狀態值如何解決的細粒度控制，特別是在平行執行場景中。

### 合併策略

```csharp
// 可用的合併衝突策略
public enum StateMergeConflictPolicy
{
    PreferFirst = 0,        // 使用基本狀態中的值
    PreferSecond = 1,       // 使用疊加狀態中的值
    ThrowOnConflict = 2,    // 衝突時拋出例外
    LastWriteWins = 3,      // 使用基於時間戳的解決
    FirstWriteWins = 4,     // 使用第一次寫入時間戳
    Reduce = 5,             // 應用 reduce 函式
    CrdtLike = 6,           // 類似 CRDT 的合併語義
    Custom = 7              // 自訂合併函式
}
```

### 基本狀態合併

```csharp
var baseState = new GraphState();
baseState.SetValue("count", 5);
baseState.SetValue("settings", new Dictionary<string, object>
{
    ["theme"] = "light",
    ["language"] = "en"
});

var overlayState = new GraphState();
overlayState.SetValue("count", 10);
overlayState.SetValue("settings", new Dictionary<string, object>
{
    ["theme"] = "dark",
    ["language"] = "pt"
});

// 使用原則進行簡單合併
var mergedState = StateHelpers.MergeStates(
    baseState, 
    overlayState, 
    StateMergeConflictPolicy.PreferSecond
);

Console.WriteLine($"Count: {mergedState.GetValue<int>("count")}"); // 10 (overlay)
Console.WriteLine($"Theme: {mergedState.GetValue<Dictionary<string, object>>("settings")["theme"]}"); // "dark"
```

### 進階合併組態

```csharp
// 使用特定原則建立合併組態
var config = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.PreferSecond
};

// 按鍵配置特定原則
config.SetKeyPolicy("count", StateMergeConflictPolicy.Reduce);
config.SetKeyPolicy("settings", StateMergeConflictPolicy.Reduce);

// 按型別配置原則
config.SetTypePolicy(typeof(Dictionary<string, object>), StateMergeConflictPolicy.Reduce);
config.SetTypePolicy(typeof(int), StateMergeConflictPolicy.Reduce);

// 自訂合併函式
config.SetCustomKeyMerger("count", (baseVal, overlayVal) =>
{
    if (baseVal is int baseInt && overlayVal is int overlayInt)
    {
        return baseInt + overlayInt; // 相加值
    }
    return overlayVal;
});

config.SetCustomKeyMerger("settings", (baseVal, overlayVal) =>
{
    if (baseVal is Dictionary<string, object> baseDict && 
        overlayVal is Dictionary<string, object> overlayDict)
    {
        var merged = new Dictionary<string, object>(baseDict);
        foreach (var kvp in overlayDict)
        {
            merged[kvp.Key] = kvp.Value;
        }
        return merged;
    }
    return overlayVal;
});

// 執行進階合併
var advancedMergedState = StateHelpers.MergeStates(baseState, overlayState, config);

Console.WriteLine($"Count: {advancedMergedState.GetValue<int>("count")}"); // 15 (5 + 10)
var settings = advancedMergedState.GetValue<Dictionary<string, object>>("settings");
Console.WriteLine($"Theme: {settings["theme"]}"); // "dark"
Console.WriteLine($"Language: {settings["language"]}"); // "pt"
```

### Reduce 函式

```csharp
// 為數值型別配置 reduce 函式
config.SetReduceFunction(typeof(int), (baseVal, overlayVal) =>
{
    if (baseVal is int baseInt && overlayVal is int overlayInt)
    {
        return Math.Max(baseInt, overlayVal); // 取最大值
    }
    return overlayVal;
});

config.SetReduceFunction(typeof(double), (baseVal, overlayVal) =>
{
    if (baseVal is double baseDouble && overlayVal is double overlayDouble)
    {
        return (baseDouble + overlayDouble) / 2; // 平均值
    }
    return overlayVal;
});

// 為集合配置 reduce 函式
config.SetReduceFunction(typeof(List<string>), (baseVal, overlayVal) =>
{
    if (baseVal is List<string> baseList && overlayVal is List<string> overlayList)
    {
        var merged = new List<string>(baseList);
        foreach (var item in overlayList)
        {
            if (!merged.Contains(item))
            {
                merged.Add(item);
            }
        }
        return merged;
    }
    return overlayVal;
});
```

### 衝突檢測和解決

```csharp
// 執行具有衝突檢測的合併
var mergeResult = StateHelpers.MergeStatesWithConflicts(baseState, overlayState, config);

if (mergeResult.HasConflicts)
{
    Console.WriteLine($"Merge completed with {mergeResult.Conflicts.Count} conflicts:");
    
    foreach (var conflict in mergeResult.Conflicts)
    {
        Console.WriteLine($"  Conflict on '{conflict.Key}':");
        Console.WriteLine($"    Base value: {conflict.BaseValue}");
        Console.WriteLine($"    Overlay value: {conflict.OverlayValue}");
        Console.WriteLine($"    Policy: {conflict.Policy}");
        Console.WriteLine($"    Resolved: {conflict.WasResolved}");
        
        if (conflict.ResolvedValue != null)
        {
            Console.WriteLine($"    Final value: {conflict.ResolvedValue}");
        }
    }
}
else
{
    Console.WriteLine("Merge completed without conflicts");
}

// 存取合併的狀態
var finalState = mergeResult.MergedState;
```

## ValidationResult 和 ValidationIssue

驗證系統提供了全面的結果物件，這些物件會彙總驗證問題並提供有關錯誤、警告和建議的詳細資訊。

### ValidationResult 結構

```csharp
public sealed class ValidationResult
{
    public DateTimeOffset Timestamp { get; }
    public bool IsValid { get; }
    public bool HasErrors { get; }
    public bool HasWarnings { get; }
    public IReadOnlyList<ValidationIssue> Issues { get; }
    public IReadOnlyList<ValidationIssue> Errors { get; }
    public IReadOnlyList<ValidationIssue> Warnings { get; }
    public int TotalIssues { get; }
    public int ErrorCount { get; }
    public int WarningCount { get; }
    
    public void AddError(string message, string? propertyName = null);
    public void AddWarning(string message, string? propertyName = null);
    public void Merge(ValidationResult other);
    public string CreateSummary(bool includeWarnings = true);
    public void ThrowIfInvalid();
}
```

### ValidationIssue 結構

```csharp
public sealed class ValidationIssue
{
    public ValidationSeverity Severity { get; }
    public string Message { get; }
    public string? PropertyName { get; }
    public string? Code { get; }
    public Dictionary<string, object> Metadata { get; }
    
    public ValidationIssue(ValidationSeverity severity, string message, 
        string? propertyName = null, string? code = null);
}

public enum ValidationSeverity
{
    Info = 0,
    Warning = 1,
    Error = 2,
    Critical = 3
}
```

### 使用驗證結果

```csharp
// 建立驗證結果
var result = new ValidationResult();

// 添加驗證問題
result.AddError("Required field 'name' is missing", "name");
result.AddWarning("Field 'age' should be positive", "age");
result.AddError("Invalid email format", "email");

// 檢查驗證狀態
if (result.IsValid)
{
    Console.WriteLine("Validation passed");
}
else
{
    Console.WriteLine($"Validation failed: {result.ErrorCount} errors, {result.WarningCount} warnings");
    
    // 處理錯誤
    foreach (var error in result.Errors)
    {
        Console.WriteLine($"Error: {error.Message}");
        if (!string.IsNullOrEmpty(error.PropertyName))
        {
            Console.WriteLine($"  Property: {error.PropertyName}");
        }
    }
    
    // 處理警告
    foreach (var warning in result.Warnings)
    {
        Console.WriteLine($"Warning: {warning.Message}");
    }
}

// 建立摘要
var summary = result.CreateSummary(includeWarnings: true);
Console.WriteLine(summary);

// 與另一個結果合併
var otherResult = new ValidationResult();
otherResult.AddError("Additional error");
result.Merge(otherResult);

// 如果無效則拋出（對驗證鏈很有用）
try
{
    result.ThrowIfInvalid();
}
catch (ValidationException ex)
{
    Console.WriteLine($"Validation failed: {ex.Message}");
}
```

## 另請參閱

* [架構型別化和驗證指南](../how-to/schema-typing-and-validation.md) - 實施架構驗證的全面指南
* [狀態和序列化參考](state-and-serialization.md) - 狀態管理和合併操作
* [多代理參考](multi-agent.md) - 多代理系統中的工作流程驗證
* [圖形執行器參考](graph-executor.md) - 圖形完整性驗證
* [整合參考](integration.md) - 外部系統驗證
* [驗證範例](../examples/validation-examples.md) - 驗證實作的實際範例
