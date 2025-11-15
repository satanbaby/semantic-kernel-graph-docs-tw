# 狀態管理

狀態管理是 SemanticKernel.Graph 中資料流的基礎。本指南說明如何使用 `GraphState`、`KernelArguments`、執行歷史、中繼資料、驗證和序列化來建置強大且易維護的工作流程。

## 您將學到什麼

* `GraphState` 如何封裝 `KernelArguments` 以提供增強功能
* 管理執行歷史和中繼資料
* 狀態驗證和版本控制
* 序列化和反序列化功能
* 狀態設計和管理的最佳實踐

## 概念和技術

**GraphState**：圍繞 `KernelArguments` 的增強封裝，提供執行追蹤、中繼資料管理、驗證和序列化功能。

**KernelArguments**：Semantic Kernel 的核心容器，用於鍵值對，代表執行狀態和上下文。

**執行歷史**：所有執行步驟的時間順序記錄，包括每個節點執行的時序、結果和中繼資料。

**狀態驗證**：內建的完整性檢查，確保狀態一致性、可序列化性和版本相容性。

**序列化**：能夠使用壓縮、版本遷移和完整性驗證來保存和還原圖形狀態。

## 前置條件

* 已完成[第一個圖表教程](../first-graph-5-minutes.md)
* 對 SemanticKernel.Graph 概念有基本理解
* 熟悉 Semantic Kernel 的 `KernelArguments`

## 核心狀態組件

### GraphState：增強狀態封裝

`GraphState` 是主要狀態容器，使用額外的圖形特定功能封裝 `KernelArguments`：

```csharp
using SemanticKernel.Graph.State;
using Microsoft.SemanticKernel;

// 使用現有的 KernelArguments 建立狀態
var arguments = new KernelArguments
{
    ["input"] = "Hello World",
    ["timestamp"] = DateTimeOffset.UtcNow
};

var graphState = new GraphState(arguments);

// 範例：序列化、保存、反序列化和驗證
var serialized = graphState.Serialize(SerializationOptions.Verbose);
// 保存至檔案（範例路徑）
var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "graphstate-example.json");
File.WriteAllText(path, serialized);

// 讀取並反序列化
var loadedJson = File.ReadAllText(path);
var deserializedResult = SerializableStateFactory.Deserialize<GraphState>(loadedJson, json => JsonSerializer.Deserialize<GraphState>(json));
if (deserializedResult.IsSuccessful)
{
    var restored = deserializedResult.State;
    Console.WriteLine($"Restored state id: {restored.StateId}");
}
else
{
    Console.WriteLine("Failed to deserialize state");
}

// 存取底層的 KernelArguments
var kernelArgs = graphState.KernelArguments;

// 存取增強的屬性
var stateId = graphState.StateId;
var version = graphState.Version;
var createdAt = graphState.CreatedAt;
var lastModified = graphState.LastModified;
```

### 狀態屬性和中繼資料

每個 `GraphState` 實例都包含內建的中繼資料：

```csharp
// 狀態識別
var stateId = graphState.StateId;           // 唯一識別符
var version = graphState.Version;           // 狀態版本（例如："1.1.0"）
var createdAt = graphState.CreatedAt;       // 建立時間戳記
var lastModified = graphState.LastModified; // 最後修改時間戳記
var isModified = graphState.IsModified;     // 狀態是否已修改

// 執行追蹤
var executionStepCount = graphState.ExecutionStepCount;
var executionHistory = graphState.ExecutionHistory;
```

## 狀態存取和操作

### 讀取狀態值

使用型別安全的方法讀取狀態中的值：

```csharp
// 帶有預設值的型別安全讀取
var name = graphState.GetValue<string>("userName");
var age = graphState.GetValue<int>("userAge");
var isActive = graphState.GetValue<bool>("isActive");

// 安全讀取並提供備用值
var department = graphState.GetValueOrDefault("department", "Unknown");
var score = graphState.GetValueOrDefault("score", 0.0);

// Try 模式用於條件讀取
if (graphState.TryGetValue<string>("email", out var email))
{
    // 處理電子郵件
}
```

### 寫入狀態

更新狀態值並追蹤修改：

```csharp
// 設定值（自動更新 LastModified）
graphState.SetValue("processed", true);
graphState.SetValue("result", "Success");
graphState.SetValue("score", 95.5);

// 移除值
var wasRemoved = graphState.RemoveValue("temporaryData");

// 檢查修改狀態
if (graphState.IsModified)
{
    Console.WriteLine($"State modified at: {graphState.LastModified}");
}
```

### 複雜物件管理

在狀態中儲存和擷取複雜物件：

```csharp
// 儲存複雜物件
var userProfile = new
{
    Name = "Alice",
    Department = "Engineering",
    Skills = new[] { "C#", ".NET", "AI" },
    Experience = 5
};

graphState.SetValue("userProfile", userProfile);

// 擷取並使用複雜物件
var profile = graphState.GetValue<object>("userProfile");
var metadata = graphState.GetValue<Dictionary<string, object>>("metadata");

// 儲存集合
var tags = new List<string> { "AI", "Machine Learning", "Graphs" };
graphState.SetValue("tags", tags);
```

## 執行歷史和追蹤

### 執行步驟

`GraphState` 透過 `ExecutionStep` 物件自動追蹤執行歷史：

```csharp
// 每個執行步驟包括：
var steps = graphState.ExecutionHistory;
foreach (var step in steps)
{
    Console.WriteLine($"Step: {step.StepId}");
    Console.WriteLine($"Node: {step.NodeId}");
    Console.WriteLine($"Function: {step.FunctionName}");
    Console.WriteLine($"Status: {step.Status}");
    Console.WriteLine($"Duration: {step.Duration}");
    Console.WriteLine($"Result: {step.Result}");
}
```

### 執行狀態型別

執行步驟可以有不同的狀態：

```csharp
public enum ExecutionStatus
{
    Running,      // 正在執行
    Completed,    // 成功完成
    Failed,       // 執行失敗
    Cancelled     // 執行已取消
}
```

### 新增執行中繼資料

節點可以將自訂中繼資料新增至執行步驟：

```csharp
// 在節點執行中
var step = new ExecutionStep("nodeId", "functionName", DateTimeOffset.UtcNow);

// 新增自訂中繼資料
step.AddMetadata("inputSize", input.Length);
step.AddMetadata("processingTime", stopwatch.ElapsedMilliseconds);
step.AddMetadata("confidence", 0.95);

// 標記完成
step.MarkCompleted(result);
```

## 狀態驗證和完整性

### 內建驗證

`GraphState` 透過 `ISerializableState` 實現全面的驗證：

```csharp
// 驗證狀態完整性
var validationResult = graphState.ValidateIntegrity();

if (validationResult.IsValid)
{
    Console.WriteLine("State is valid");
}
else
{
    Console.WriteLine($"Validation failed: {validationResult.ErrorCount} errors");
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"Error: {error.Message}");
    }
}
```

### 驗證結果詳細資訊

驗證結果提供詳細資訊：

```csharp
var result = graphState.ValidateIntegrity();

Console.WriteLine($"Valid: {result.IsValid}");
Console.WriteLine($"Errors: {result.ErrorCount}");
Console.WriteLine($"Warnings: {result.WarningCount}");
Console.WriteLine($"Total Issues: {result.TotalIssues}");

// 取得詳細摘要
var summary = result.CreateSummary(includeDetails: true);
Console.WriteLine(summary);
```

### 自訂驗證

使用自訂規則擴展驗證：

```csharp
public static ValidationResult ValidateCustomRules(GraphState state)
{
    var result = new ValidationResult();
    
    // 檢查必填欄位
    if (!state.TryGetValue<string>("userId", out _))
    {
        result.AddError("Required field 'userId' is missing");
    }
    
    // 驗證資料型別
    if (state.TryGetValue<int>("age", out var age) && age < 0)
    {
        result.AddWarning("Age should be non-negative", "data_validation");
    }
    
    // 檢查商業規則
    if (state.TryGetValue<string>("email", out var email) && !email.Contains("@"))
    {
        result.AddError("Invalid email format");
    }
    
    return result;
}
```

## 狀態版本控制和相容性

### 版本管理

`GraphState` 包含用於相容性控制的語意版本控制：

```csharp
// 目前版本資訊
var currentVersion = StateVersion.Current;           // "1.1.0"
var minSupported = StateVersion.MinimumSupported;    // "1.0.0"

// 檢查版本相容性
var stateVersion = graphState.Version;
var isCompatible = stateVersion.IsCompatible;        // 與目前版本相容
var requiresMigration = stateVersion.RequiresMigration; // 需要遷移

// 版本比較
if (stateVersion < StateVersion.Current)
{
    Console.WriteLine("State version is older than current");
}
```

### 版本解析

從字串建立版本物件：

```csharp
// 解析版本字串
var version = StateVersion.Parse("1.2.3");
Console.WriteLine($"Major: {version.Major}");    // 1
Console.WriteLine($"Minor: {version.Minor}");    // 2
Console.WriteLine($"Patch: {version.Patch}");    // 3

// Try-parse 用於安全的版本處理
if (StateVersion.TryParse("invalid", out var parsedVersion))
{
    // 使用解析的版本
}
else
{
    Console.WriteLine("Invalid version format");
}
```

## 序列化和持久化

### 基本序列化

將狀態序列化為字串表現形式：

```csharp
// 使用預設選項進行序列化
var serialized = graphState.Serialize();

// 使用自訂選項進行序列化
var options = new SerializationOptions
{
    Indented = true,
    EnableCompression = true,
    IncludeMetadata = true,
    IncludeExecutionHistory = true
};

var verboseSerialized = graphState.Serialize(options);
```

### 序列化選項

控制序列化的內容：

```csharp
var options = new SerializationOptions
{
    Indented = false,                    // 緊湊 JSON
    EnableCompression = true,            // 為大型狀態啟用壓縮
    IncludeMetadata = true,              // 包含狀態中繼資料
    IncludeExecutionHistory = false,     // 排除執行歷史
    ValidateIntegrity = true             // 序列化前驗證
};
```

### 反序列化

從序列化資料還原狀態：

```csharp
using SemanticKernel.Graph.State;

// 使用工廠方法反序列化
var deserializedResult = SerializableStateFactory.Deserialize<GraphState>(
    serializedData,
    json => JsonSerializer.Deserialize<GraphState>(json)
);

if (deserializedResult.IsSuccessful)
{
    var restoredState = deserializedResult.State;
    Console.WriteLine("State restored successfully");
    
    // 檢查是否已套用遷移
    if (deserializedResult.WasMigrated)
    {
        Console.WriteLine($"Migrated from version {deserializedResult.OriginalVersion}");
    }
}
else
{
    Console.WriteLine("Deserialization failed");
    var summary = deserializedResult.CreateSummary();
    Console.WriteLine(summary);
}
```

### 完整性檢查

驗證序列化資料完整性：

```csharp
// 建立總和檢查碼以驗證完整性
var checksum = graphState.CreateChecksum();

// 驗證完整性
var validationResult = graphState.ValidateIntegrity();
if (!validationResult.IsValid)
{
    throw new InvalidOperationException("State integrity validation failed");
}
```

## 狀態延伸和公用程式

### KernelArguments 延伸

使用延伸方法與狀態搭配：

```csharp
using SemanticKernel.Graph.Extensions;

var arguments = new KernelArguments
{
    ["input"] = "Hello World"
};

// 轉換為 GraphState
var graphState = arguments.ToGraphState();

// 檢查是否已有 GraphState
if (arguments.HasGraphState())
{
    var existingState = arguments.GetOrCreateGraphState();
}

// 明確設定 GraphState
arguments.SetGraphState(graphState);
```

### 狀態複製和合併

建立副本和合併狀態：

```csharp
using SemanticKernel.Graph.Extensions;

// 複製狀態（深層複製）
var clonedState = graphState.Clone();

// 合併狀態（其他狀態優先）
var mergedState = graphState.MergeFrom(otherState);

// 檢查狀態是否相等
var areEqual = graphState.Equals(otherState);
```

### 狀態幫助程式

使用公用程式方法進行常見操作：

```csharp
using SemanticKernel.Graph.State;

// 估計序列化大小
var estimatedSize = StateHelpers.EstimateSerializedSize(graphState);

// 驗證可序列化性
var serializationValidation = StateValidator.ValidateSerializability(graphState);

// 取得參數名稱
var parameterNames = graphState.GetParameterNames();
```

## 進階狀態模式

### 狀態組合

建置複雜的狀態結構：

```csharp
// 建立階層式狀態
var state = new GraphState(new KernelArguments
{
    ["user"] = new Dictionary<string, object>
    {
        ["profile"] = new
        {
            Name = "Alice",
            Email = "alice@example.com"
        },
        ["preferences"] = new Dictionary<string, object>
        {
            ["theme"] = "dark",
            ["language"] = "en"
        }
    },
    ["session"] = new Dictionary<string, object>
    {
        ["startTime"] = DateTimeOffset.UtcNow,
        ["activeTab"] = "dashboard"
    }
});
```

### 狀態生命週期管理

在執行過程中管理狀態：

```csharp
public class StateAwareNode : IGraphNode
{
    public async Task<FunctionResult> ExecuteAsync(GraphState state)
    {
        // 讀取輸入狀態
        var input = state.GetValue<string>("input");
        
        // 處理並更新狀態
        var result = await ProcessInput(input);
        state.SetValue("processedResult", result);
        state.SetValue("processingTimestamp", DateTimeOffset.UtcNow);
        
        // 新增執行中繼資料
        state.AddExecutionStep("StateAwareNode", "ProcessInput", DateTimeOffset.UtcNow);
        
        return new FunctionResult(result);
    }
}
```

### 狀態驗證模式

實現全面的驗證：

```csharp
public static class StateValidationRules
{
    public static ValidationResult ValidateUserProfile(GraphState state)
    {
        var result = new ValidationResult();
        
        // 必填欄位驗證
        var requiredFields = new[] { "userId", "userName", "email" };
        foreach (var field in requiredFields)
        {
            if (!state.TryGetValue<string>(field, out var value) || string.IsNullOrEmpty(value))
            {
                result.AddError($"Required field '{field}' is missing or empty");
            }
        }
        
        // 資料型別驗證
        if (state.TryGetValue<int>("age", out var age))
        {
            if (age < 0 || age > 150)
            {
                result.AddWarning("Age value seems unrealistic", "data_validation");
            }
        }
        
        // 商業規則驗證
        if (state.TryGetValue<string>("email", out var email))
        {
            if (!email.Contains("@") || !email.Contains("."))
            {
                result.AddError("Invalid email format");
            }
        }
        
        return result;
    }
}
```

## 最佳實踐

### 狀態設計原則

1. **保持狀態簡單**：使用清晰、描述性的鍵名稱
2. **型別安全**：使用 `GetValue<T>()` 進行型別安全的存取
3. **驗證**：在工作流程的關鍵點驗證狀態
4. **中繼資料**：添加有意義的中繼資料用於偵錯和監控
5. **序列化**：考慮哪些需要持久化，哪些是暫時性的

### 效能考量

1. **大型物件**：注意大型物件的序列化成本
2. **執行歷史**：限制長時間執行工作流程的歷史記錄大小
3. **壓縮**：為大型狀態啟用壓縮
4. **驗證**：選擇性地使用驗證以避免效能影響

### 錯誤處理

1. **優雅降級**：正常處理遺漏的狀態
2. **驗證**：在執行關鍵操作前驗證狀態
3. **記錄**：記錄狀態變更用於偵錯
4. **復原**：實現狀態復原機制

## 疑難排解

### 常見問題

**狀態鍵未找到**
```
System.Collections.Generic.KeyNotFoundException: The given key 'missingKey' was not present
```
**解決方案**：使用 `GetValueOrDefault()` 或在讀取前使用 `ContainsKey()` 檢查。

**序列化錯誤**
```
System.Text.Json.JsonException: The JSON value could not be converted to type
```
**解決方案**：確保狀態中的所有物件都是 JSON 可序列化的。

**版本相容性問題**
```
State version 1.0.0 is not compatible with current version 1.1.0
```
**解決方案**：使用狀態遷移或更新工作流程以處理版本差異。

**大型狀態效能問題**
```
Serialized state too large: 50,000,000 bytes
```
**解決方案**：啟用壓縮、排除不必要的資料或分割大型狀態。

## 另請參閱

* [狀態快速入門](../state-quickstart.md) - 狀態管理的快速介紹
* [狀態教程](../state-tutorial.md) - 全面的狀態管理教程
* [執行模型](execution-model.md) - 狀態如何流過執行
* [檢查點](../checkpointing-quickstart.md) - 保存和還原狀態
* [圖形概念](graph-concepts.md) - 核心圖形概念和模式
