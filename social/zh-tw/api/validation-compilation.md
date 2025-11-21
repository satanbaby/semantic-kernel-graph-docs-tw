# 驗證和編譯

本文檔涵蓋 SemanticKernel.Graph 中的全面驗證和編譯系統，包括工作流驗證、型別推論、狀態驗證和合併衝突解決。該系統在多個層級提供強大的驗證，從編譯時期架構檢查到執行時期狀態完整性驗證，確保可靠的 Graph 執行和資料一致性。

## WorkflowValidator

`WorkflowValidator` 驗證多代理工作流的結構完整性、能力兼容性和資源配置健全性，並在執行前提供全面驗證和詳細錯誤報告。

### Overview

此驗證程式執行非拋出檢查並將問題聚合到 `ValidationResult`，啟用早期檢測問題，例如無效依賴、缺失能力和配置問題。它支援工作流結構、代理能力、容量限制和資源治理設定的驗證。

### 主要功能

* **結構驗證**：ID 唯一性、依賴完整性和循環檢測
* **代理能力驗證**：確保所需能力可用
* **容量驗證**：驗證代理容量配置
* **資源治理驗證**：檢查資源配置健全性
* **全面報告**：聚合錯誤、警告和建議
* **非拋出設計**：安全驗證，無例外狀況

### Configuration

```csharp
var validator = new WorkflowValidator(logger);

// Validate workflow with full context
var result = validator.Validate(
    workflow: workflow,
    agentRoles: agentRoles,
    agentCapacities: agentCapacities,
    resourceOptions: resourceOptions
);
```

### 工作流驗證

```csharp
// Create a workflow to validate
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

// Validate the workflow
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
// Define agent roles with capabilities
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

// Validate with agent roles
var result = validator.Validate(workflow, agentRoles: agentRoles);

// Check capability compatibility
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
// Define agent capacities
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

// Define resource governance options
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    CpuHighWatermarkPercent = 80,
    CpuSoftLimitPercent = 70,
    MinAvailableMemoryMB = 512,
    BasePermitsPerSecond = 10,
    MaxBurstSize = 20
};

// Validate with full context
var result = validator.Validate(
    workflow, 
    agentRoles, 
    agentCapacities, 
    resourceOptions
);
```

## GraphTypeInferenceEngine

`GraphTypeInferenceEngine` 使用可用的型別架構對 Graph 執行輕量級型別推論，從來源 Node 傳播已知的輸出型別到未宣告型別架構的目標。

### Overview

此靜態引擎提供保守的、以名稱為基礎的型別推論，檢查上游 Node 以確定未型別化目標 Node 的輸入需求。它支援原始型別和 .NET 執行時期型別，啟用漸進式在 Graph 元件中採用型別架構。

### 主要功能

* **保守推論**：僅在關係確信時推論型別
* **以名稱為基礎的傳播**：跨 Node 邊界按名稱對應參數
* **上游分析**：檢查前驅 Node 以取得型別資訊
* **後備處理**：無型別資訊時提供未型別化後備
* **靜態分析**：編譯時期型別推論，無執行時期額外負荷

### 型別推論

```csharp
var graph = new GraphExecutor("type-inference-example");

// Add typed source node with known output schema
var sourceNode = new TypedSourceNode();
graph.AddNode(sourceNode);

// Add untyped target node
var targetNode = new UntypedTargetNode();
graph.AddNode(targetNode);

// Connect nodes
graph.Connect(sourceNode.NodeId, targetNode.NodeId);

// Infer input schemas for untyped nodes
var inferredSchemas = GraphTypeInferenceEngine.InferInputSchemas(graph);

// Check inferred schema for target node
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
// Create a graph with multiple typed nodes
var graph = new GraphExecutor("schema-propagation");

// Source node with typed outputs
var dataSource = new DataSourceNode();
graph.AddNode(dataSource);

// Intermediate processing node
var processor = new DataProcessorNode();
graph.AddNode(processor);

// Final output node
var output = new OutputNode();
graph.AddNode(output);

// Connect the pipeline
graph.Connect(dataSource.NodeId, processor.NodeId);
graph.Connect(processor.NodeId, output.NodeId);

// Infer schemas throughout the pipeline
var inferredSchemas = GraphTypeInferenceEngine.InferInputSchemas(graph);

// Check schema propagation
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

`StateValidator` 為 Graph 狀態提供全面的完整性檢查，確保資料一致性並在執行生命週期早期識別潛在問題。

### Overview

此靜態驗證程式執行多個驗證類別，包括基本內容、資料驗證、執行歷程、版本相容性和大小限制。它為效能敏感的情況提供全面驗證和關鍵內容驗證。

### 主要功能

* **全面驗證**：完整狀態完整性檢查
* **關鍵內容驗證**：快速驗證基本內容
* **大小和記憶體驗證**：防止過度資源使用
* **歷程驗證**：確保執行歷程完整性
* **版本相容性**：檢查狀態版本需求

### 狀態驗證

```csharp
var state = new GraphState();

// Add data to the state
state.SetValue("user_id", 123);
state.SetValue("user_name", "John Doe");
state.SetValue("settings", new Dictionary<string, object>
{
    ["theme"] = "dark",
    ["language"] = "en"
});

// Comprehensive validation
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

### 關鍵內容驗證

```csharp
// Fast validation of critical properties only
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
// Validate specific aspects of the state
var state = new GraphState();

// Basic properties validation
if (string.IsNullOrWhiteSpace(state.StateId))
{
    Console.WriteLine("State ID is missing");
}

// Data validation
foreach (var kvp in state.Parameters)
{
    var key = kvp.Key;
    var value = kvp.Value;
    
    // Check parameter name length
    if (key.Length > 256)
    {
        Console.WriteLine($"Parameter name too long: {key}");
    }
    
    // Check string value length
    if (value is string strValue && strValue.Length > 1024 * 1024)
    {
        Console.WriteLine($"String value too long for parameter: {key}");
    }
}

// Size validation
var stateSize = state.EstimateSize();
if (stateSize > 10 * 1024 * 1024) // 10MB limit
{
    Console.WriteLine($"State size exceeds limit: {stateSize} bytes");
}

// History validation
if (state.ExecutionHistory.Count > 10000)
{
    Console.WriteLine("Execution history too large");
}
```

## StateMergeConflictPolicy

`StateMergeConflictPolicy` 定義狀態合併期間平行分支連接的衝突解決策略，提供靈活和可配置的合併行為。

### Overview

此列舉和配置系統支援多種合併策略，從簡單的優先順序規則到複雜的 CRDT 類型語義。它在 Graph 執行期間啟用對衝突狀態值解決方式的細粒度控制，特別是在平行執行案例中。

### 合併策略

```csharp
// Available merge conflict policies
public enum StateMergeConflictPolicy
{
    PreferFirst = 0,        // Use value from base state
    PreferSecond = 1,       // Use value from overlay state
    ThrowOnConflict = 2,    // Throw exception on conflict
    LastWriteWins = 3,      // Use timestamp-based resolution
    FirstWriteWins = 4,     // Use first write timestamp
    Reduce = 5,             // Apply reduce function
    CrdtLike = 6,           // CRDT-like merge semantics
    Custom = 7              // Custom merge function
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

// Simple merge with policy
var mergedState = StateHelpers.MergeStates(
    baseState, 
    overlayState, 
    StateMergeConflictPolicy.PreferSecond
);

Console.WriteLine($"Count: {mergedState.GetValue<int>("count")}"); // 10 (overlay)
Console.WriteLine($"Theme: {mergedState.GetValue<Dictionary<string, object>>("settings")["theme"]}"); // "dark"
```

### 進階合併配置

```csharp
// Create merge configuration with specific policies
var config = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.PreferSecond
};

// Configure specific policies per key
config.SetKeyPolicy("count", StateMergeConflictPolicy.Reduce);
config.SetKeyPolicy("settings", StateMergeConflictPolicy.Reduce);

// Configure policies per type
config.SetTypePolicy(typeof(Dictionary<string, object>), StateMergeConflictPolicy.Reduce);
config.SetTypePolicy(typeof(int), StateMergeConflictPolicy.Reduce);

// Custom merge functions
config.SetCustomKeyMerger("count", (baseVal, overlayVal) =>
{
    if (baseVal is int baseInt && overlayVal is int overlayInt)
    {
        return baseInt + overlayInt; // Sum the values
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

// Perform advanced merge
var advancedMergedState = StateHelpers.MergeStates(baseState, overlayState, config);

Console.WriteLine($"Count: {advancedMergedState.GetValue<int>("count")}"); // 15 (5 + 10)
var settings = advancedMergedState.GetValue<Dictionary<string, object>>("settings");
Console.WriteLine($"Theme: {settings["theme"]}"); // "dark"
Console.WriteLine($"Language: {settings["language"]}"); // "pt"
```

### Reduce Functions

```csharp
// Configure reduce functions for numeric types
config.SetReduceFunction(typeof(int), (baseVal, overlayVal) =>
{
    if (baseVal is int baseInt && overlayVal is int overlayInt)
    {
        return Math.Max(baseInt, overlayVal); // Take maximum
    }
    return overlayVal;
});

config.SetReduceFunction(typeof(double), (baseVal, overlayVal) =>
{
    if (baseVal is double baseDouble && overlayVal is double overlayDouble)
    {
        return (baseDouble + overlayDouble) / 2; // Average
    }
    return overlayVal;
});

// Configure reduce functions for collections
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

### 衝突偵測和解決

```csharp
// Perform merge with conflict detection
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

// Access the merged state
var finalState = mergeResult.MergedState;
```

## ValidationResult and ValidationIssue

驗證系統提供全面的結果物件，聚合驗證問題並提供有關錯誤、警告和建議的詳細資訊。

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
// Create validation result
var result = new ValidationResult();

// Add validation issues
result.AddError("Required field 'name' is missing", "name");
result.AddWarning("Field 'age' should be positive", "age");
result.AddError("Invalid email format", "email");

// Check validation status
if (result.IsValid)
{
    Console.WriteLine("Validation passed");
}
else
{
    Console.WriteLine($"Validation failed: {result.ErrorCount} errors, {result.WarningCount} warnings");
    
    // Process errors
    foreach (var error in result.Errors)
    {
        Console.WriteLine($"Error: {error.Message}");
        if (!string.IsNullOrEmpty(error.PropertyName))
        {
            Console.WriteLine($"  Property: {error.PropertyName}");
        }
    }
    
    // Process warnings
    foreach (var warning in result.Warnings)
    {
        Console.WriteLine($"Warning: {warning.Message}");
    }
}

// Create summary
var summary = result.CreateSummary(includeWarnings: true);
Console.WriteLine(summary);

// Merge with another result
var otherResult = new ValidationResult();
otherResult.AddError("Additional error");
result.Merge(otherResult);

// Throw if invalid (useful for validation chains)
try
{
    result.ThrowIfInvalid();
}
catch (ValidationException ex)
{
    Console.WriteLine($"Validation failed: {ex.Message}");
}
```

## 另見

* [Schema Typing and Validation Guide](../how-to/schema-typing-and-validation.md) - 實施架構驗證的全面指南
* [State and Serialization Reference](state-and-serialization.md) - 狀態管理和合併操作
* [Multi-Agent Reference](multi-agent.md) - 多代理系統中的工作流驗證
* [Graph Executor Reference](graph-executor.md) - Graph 完整性驗證
* [Integration Reference](integration.md) - 外部系統驗證
* [Validation Examples](../examples/validation-examples.md) - 驗證實作的實用示例
