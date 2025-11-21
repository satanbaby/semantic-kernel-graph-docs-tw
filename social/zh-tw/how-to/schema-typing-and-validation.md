# 模式型別與驗證

SemanticKernel.Graph 提供了一個綜合型別系統和驗證框架，確保資料一致性、啟用編譯時檢查，並透過遷移支援無縫的狀態演進。本指南涵蓋完整的模式型別生態系統，包括型別推斷、驗證和狀態遷移功能。

## 概述

模式型別和驗證系統由幾個關鍵元件組成：

* **GraphTypeInferenceEngine**：自動為無型別節點推斷輸入/輸出模式
* **StateValidator**：對 Graph 狀態完整性和一致性進行全面驗證
* **TypedSchema 系統**：針對 Graph 參數的強型別，支援基本型別和 .NET 型別
* **State Migration System**：在不同版本之間自動進行狀態演進
* **Compile-time Validation**：提早偵測模式不相容和錯誤

## 核心元件

### GraphTypeInferenceEngine

`GraphTypeInferenceEngine` 使用可用的型別化模式對 Graph 執行輕量級型別推斷。它會將已知的輸出型別從來源節點傳播到未宣告型別化模式的目標節點。

```csharp
public static class GraphTypeInferenceEngine
{
    /// <summary>
    /// Infers input schemas for nodes that do not implement ITypedSchemaNode.
    /// When possible, derives input parameter names and types from upstream nodes' outputs by name.
    /// </summary>
    public static IReadOnlyDictionary<string, GraphIOSchema> InferInputSchemas(GraphExecutor graph);
}
```

**關鍵功能：**
* **保守推斷**：僅在對關係有把握時才推斷型別
* **基於名稱的傳播**：透過名稱在節點邊界之間對應參數
* **上游分析**：檢查前置節點以確定輸入要求
* **後備處理**：在型別資訊不可用時提供無型別後備選項

**使用範例：**
```csharp
var graph = new GraphExecutor("inference-example");

// Add typed source node
var sourceNode = new TypedSourceNode();
graph.AddNode(sourceNode);

// Add untyped target node
var targetNode = new UntypedTargetNode();
graph.AddNode(targetNode);

graph.Connect(sourceNode.NodeId, targetNode.NodeId);

// Infer schemas for untyped nodes
var inferredSchemas = GraphTypeInferenceEngine.InferInputSchemas(graph);

// The target node now has inferred input schemas based on source outputs
var targetSchema = inferredSchemas[targetNode.NodeId];
```

### StateValidator

`StateValidator` 為 Graph 狀態提供全面的完整性檢查，確保資料一致性並及早發現潛在問題。

```csharp
public static class StateValidator
{
    /// <summary>
    /// Validates the complete integrity of a GraphState.
    /// </summary>
    public static ValidationResult ValidateState(GraphState state);
    
    /// <summary>
    /// Validates only the critical properties of the state.
    /// </summary>
    public static bool ValidateCriticalProperties(GraphState state);
}
```

**驗證類別：**

1. **基本屬性**：State ID、名稱和中繼資料驗證
2. **資料驗證**：參數名稱、值和型別一致性
3. **執行歷史記錄**：歷史記錄大小限制和完整性檢查
4. **版本驗證**：相容性和遷移需求
5. **大小驗證**：記憶體使用和序列化大小限制

**使用範例：**
```csharp
var state = new GraphState("validation-test");

// Add some data
state.SetValue("user_id", 123);
state.SetValue("user_name", "John Doe");

// Validate the state
var validationResult = StateValidator.ValidateState(state);

if (validationResult.IsValid)
{
    Console.WriteLine("State is valid");
}
else
{
    foreach (var error in validationResult.Errors)
    {
        Console.WriteLine($"Validation error: {error.Message}");
    }
    
    foreach (var warning in validationResult.Warnings)
    {
        Console.WriteLine($"Validation warning: {warning.Message}");
    }
}
```

## 型別化模式系統

### GraphType

`GraphType` 類別使用基本分類或 .NET 執行時型別代表參數型別，以進行更嚴格的驗證。

```csharp
public sealed class GraphType
{
    public static GraphType FromPrimitive(GraphPrimitiveType primitive);
    public static GraphType FromDotNetType(Type type);
    
    public GraphPrimitiveType Primitive { get; }
    public Type? DotNetType { get; }
    
    public bool IsValueCompatible(object? value);
    public bool IsAssignableTo(GraphType target);
}
```

**基本型別：**
* **Any**：接受任何值（預設）
* **String**：僅字串值
* **Integer**：整數值（int、long 等）
* **Number**：數值（int、double、decimal 等）
* **Boolean**：僅布林值
* **Object**：物件例項
* **Array**：陣列或集合值
* **Json**：JSON 格式的字串

**使用範例：**
```csharp
// Create primitive types
var stringType = GraphType.FromPrimitive(GraphPrimitiveType.String);
var intType = GraphType.FromPrimitive(GraphPrimitiveType.Integer);
var numberType = GraphType.FromPrimitive(GraphPrimitiveType.Number);

// Create .NET type-based types
var userType = GraphType.FromDotNetType(typeof(User));
var listType = GraphType.FromDotNetType(typeof(List<string>));

// Check compatibility
Console.WriteLine(stringType.IsValueCompatible("hello")); // True
Console.WriteLine(stringType.IsValueCompatible(123));     // False
Console.WriteLine(intType.IsValueCompatible(42));         // True
Console.WriteLine(intType.IsValueCompatible(3.14));       // False
Console.WriteLine(numberType.IsValueCompatible(3.14));    // True

// Check type assignability
Console.WriteLine(intType.IsAssignableTo(numberType));    // True (int → number)
Console.WriteLine(numberType.IsAssignableTo(intType));    // False (number ↛ int)
```

### GraphParameterSchema

定義個別 Graph 參數的結構和約束。

```csharp
public sealed class GraphParameterSchema
{
    public required string Name { get; init; }
    public string? Description { get; init; }
    public bool Required { get; init; }
    public GraphType Type { get; init; } = GraphType.FromPrimitive(GraphPrimitiveType.Any);
}
```

**使用範例：**
```csharp
var parameterSchema = new GraphParameterSchema
{
    Name = "user_id",
    Description = "Unique identifier for the user",
    Required = true,
    Type = GraphType.FromPrimitive(GraphPrimitiveType.Integer)
};

var userSchema = new GraphParameterSchema
{
    Name = "user_data",
    Description = "Complete user information",
    Required = false,
    Type = GraphType.FromDotNetType(typeof(User))
};
```

### GraphIOSchema

定義節點的完整輸入/輸出模式，按方向組織參數。

```csharp
public sealed class GraphIOSchema
{
    public IReadOnlyDictionary<string, GraphParameterSchema> Inputs { get; init; }
    public IReadOnlyDictionary<string, GraphParameterSchema> Outputs { get; init; }
    
    public bool TryGetInput(string name, out GraphParameterSchema? schema);
    public bool TryGetOutput(string name, out GraphParameterSchema? schema);
}
```

**使用範例：**
```csharp
var inputSchema = new Dictionary<string, GraphParameterSchema>
{
    ["query"] = new GraphParameterSchema
    {
        Name = "query",
        Description = "Search query string",
        Required = true,
        Type = GraphType.FromPrimitive(GraphPrimitiveType.String)
    },
    ["limit"] = new GraphParameterSchema
    {
        Name = "limit",
        Description = "Maximum number of results",
        Required = false,
        Type = GraphType.FromPrimitive(GraphPrimitiveType.Integer)
    }
};

var outputSchema = new Dictionary<string, GraphParameterSchema>
{
    ["results"] = new GraphParameterSchema
    {
        Name = "results",
        Description = "Search results array",
        Required = true,
        Type = GraphType.FromPrimitive(GraphPrimitiveType.Array)
    },
    ["total_count"] = new GraphParameterSchema
    {
        Name = "total_count",
        Description = "Total number of matching results",
        Required = true,
        Type = GraphType.FromPrimitive(GraphPrimitiveType.Integer)
    }
};

var nodeSchema = new GraphIOSchema
{
    Inputs = inputSchema,
    Outputs = outputSchema
};
```

### ITypedSchemaNode Interface

節點可以實作此介面來公開其輸入/輸出模式，以供驗證和型別推斷使用。

```csharp
public interface ITypedSchemaNode
{
    /// <summary>
    /// Returns the input schema describing required/optional inputs.
    /// </summary>
    GraphIOSchema GetInputSchema();
    
    /// <summary>
    /// Returns the output schema describing values produced by the node.
    /// </summary>
    GraphIOSchema GetOutputSchema();
}
```

**實作範例：**
```csharp
public class SearchNode : IGraphNode, ITypedSchemaNode
{
    public GraphIOSchema GetInputSchema()
    {
        return new GraphIOSchema
        {
            Inputs = new Dictionary<string, GraphParameterSchema>
            {
                ["query"] = new GraphParameterSchema
                {
                    Name = "query",
                    Required = true,
                    Type = GraphType.FromPrimitive(GraphPrimitiveType.String)
                }
            },
            Outputs = new Dictionary<string, GraphParameterSchema>
            {
                ["results"] = new GraphParameterSchema
                {
                    Name = "results",
                    Required = true,
                    Type = GraphType.FromPrimitive(GraphPrimitiveType.Array)
                }
            }
        };
    }
    
    public GraphIOSchema GetOutputSchema() => GetInputSchema();
    
    // ... other IGraphNode implementation
}
```

## State 遷移系統

### StateVersion

表示 Graph 狀態的版本，用於相容性控制和遷移。

```csharp
public readonly struct StateVersion : IEquatable<StateVersion>, IComparable<StateVersion>
{
    public static readonly StateVersion Current = new(1, 1, 0);
    public static readonly StateVersion MinimumSupported = new(1, 0, 0);
    
    public int Major { get; }
    public int Minor { get; }
    public int Patch { get; }
    
    public bool IsCompatible => this >= MinimumSupported && Major == Current.Major;
    public bool RequiresMigration => this < Current;
}
```

**版本相容性：**
* **Major 版本**：不相容的變更需要遷移
* **Minor 版本**：向後相容的新增項目
* **Patch 版本**：錯誤修復和輕微改善
* **相容性**：相同的 Major 版本且 >= 最低支援版本

### IStateMigration Interface

定義不同版本之間 State 遷移的協議。

```csharp
public interface IStateMigration
{
    StateVersion FromVersion { get; }
    StateVersion ToVersion { get; }
    string Description { get; }
    
    bool CanMigrate(StateVersion version);
    string Migrate(string serializedState);
}
```

**實作範例：**
```csharp
public class UserProfileMigration_1_0_0_to_1_1_0 : IStateMigration
{
    public StateVersion FromVersion => new(1, 0, 0);
    public StateVersion ToVersion => new(1, 1, 0);
    public string Description => "Adds user_preferences field to user profiles";
    
    public bool CanMigrate(StateVersion version) => version == FromVersion;
    
    public string Migrate(string serializedState)
    {
        try
        {
            // Parse the old state
            var oldState = JsonSerializer.Deserialize<Dictionary<string, object>>(serializedState);
            
            // Add new field with default value
            if (oldState.ContainsKey("user_profile"))
            {
                var profile = oldState["user_profile"] as Dictionary<string, object>;
                if (profile != null && !profile.ContainsKey("user_preferences"))
                {
                    profile["user_preferences"] = new Dictionary<string, object>();
                }
            }
            
            // Return migrated state
            return JsonSerializer.Serialize(oldState);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Migration failed: {ex.Message}", ex);
        }
    }
}
```

### StateMigrationManager

State 遷移的中央註冊表和管理器。

```csharp
public static class StateMigrationManager
{
    // Registration
    public static void RegisterMigration(IStateMigration migration);
    public static void RegisterMigrations(IEnumerable<IStateMigration> migrations);
    public static void ClearMigrations();
    
    // Migration operations
    public static bool IsMigrationNeeded(StateVersion version);
    public static string MigrateToCurrentVersion(string serializedState, StateVersion fromVersion);
    public static IList<IStateMigration> GetMigrationPath(StateVersion fromVersion, StateVersion toVersion);
    
    // Query operations
    public static IReadOnlyList<IStateMigration> GetAllMigrations();
    public static IList<IStateMigration> GetMigrationsForVersion(StateVersion version);
    public static MigrationStats GetMigrationStats();
}
```

**使用範例：**
```csharp
// Example: register a migration and migrate an old serialized state
StateMigrationManager.ClearMigrations();
StateMigrationManager.RegisterMigration(new UserProfileMigration_1_0_0_to_1_1_0());

var oldVersion = new StateVersion(1, 0, 0);
var oldSerializedState = state.Serialize();

if (StateMigrationManager.IsMigrationNeeded(oldVersion))
{
    Console.WriteLine("Migration required");
    var migrationPath = StateMigrationManager.GetMigrationPath(oldVersion, StateVersion.Current);
    Console.WriteLine($"Migration path: {string.Join(" → ", migrationPath.Select(m => m.ToVersion))}");

    try
    {
        var migratedState = StateMigrationManager.MigrateToCurrentVersion(oldSerializedState, oldVersion);
        Console.WriteLine($"Migration completed. Migrated size: {migratedState.Length}");
    }
    catch (InvalidOperationException ex)
    {
        Console.WriteLine($"Migration failed: {ex.Message}");
    }
}
else
{
    Console.WriteLine("No migration needed for current example state.");
}
```

## 編譯時驗證

### 模式相容性驗證

當型別化模式可用時，`GraphExecutor` 會自動驗證邊上的模式相容性。

```csharp
// This validation happens automatically during graph integrity checks
var result = graph.ValidateGraphIntegrity();

// Schema compatibility warnings are included in the result
foreach (var warning in result.Warnings)
{
    if (warning.Message.Contains("may not be assignable"))
    {
        Console.WriteLine($"Schema compatibility warning: {warning.Message}");
    }
}
```

**驗證功能：**
* **型別檢查**：確保輸出型別與輸入型別相容
* **必要參數驗證**：警告缺少的必要輸入
* **模式傳播**：使用型別推斷填補無型別節點中的空隙
* **Edge 驗證**：檢查所有 Graph 連線的相容性

### ValidationResult

包括錯誤、警告和成功狀態的全面驗證結果。

```csharp
public class ValidationResult
{
    public bool IsValid => !Errors.Any();
    public IReadOnlyList<ValidationIssue> Errors { get; }
    public IReadOnlyList<ValidationIssue> Warnings { get; }
    
    public void AddError(string message, string? code = null);
    public void AddWarning(string message, string? code = null);
    public void Merge(ValidationResult other);
}
```

**使用範例：**
```csharp
var result = new ValidationResult();

// Add validation issues
if (string.IsNullOrEmpty(userName))
{
    result.AddError("User name is required", "USER_NAME_REQUIRED");
}

if (userAge < 13)
{
    result.AddWarning("User may be too young for this service", "AGE_WARNING");
}

// Check results
if (result.IsValid)
{
    Console.WriteLine("Validation passed");
}
else
{
    Console.WriteLine($"Validation failed with {result.Errors.Count} errors");
    foreach (var error in result.Errors)
    {
        Console.WriteLine($"Error: {error.Message} (Code: {error.Code})");
    }
}

if (result.Warnings.Any())
{
    Console.WriteLine($"Validation completed with {result.Warnings.Count} warnings");
    foreach (var warning in result.Warnings)
    {
        Console.WriteLine($"Warning: {warning.Message} (Code: {warning.Code})");
    }
}
```

## 進階型別推斷模式

### 保守型別傳播

型別推斷引擎使用保守策略來避免誤判：

```csharp
// Example: Inferring types across a chain of nodes
var graph = new GraphExecutor("type-inference-chain");

// Node A: Produces typed output
var nodeA = new TypedSourceNode();
nodeA.SetOutputSchema(new GraphIOSchema
{
    Outputs = new Dictionary<string, GraphParameterSchema>
    {
        ["data"] = new GraphParameterSchema
        {
            Name = "data",
            Type = GraphType.FromPrimitive(GraphPrimitiveType.String),
            Required = true
        }
    }
});

// Node B: Untyped, will receive inferred schema
var nodeB = new UntypedNode();

// Node C: Typed input requirements
var nodeC = new TypedTargetNode();
nodeC.SetInputSchema(new GraphIOSchema
{
    Inputs = new Dictionary<string, GraphParameterSchema>
    {
        ["data"] = new GraphParameterSchema
        {
            Name = "data",
            Type = GraphType.FromPrimitive(GraphPrimitiveType.String),
            Required = true
        }
    }
});

graph.AddNode(nodeA).AddNode(nodeB).AddNode(nodeC);
graph.Connect(nodeA.NodeId, nodeB.NodeId);
graph.Connect(nodeB.NodeId, nodeC.NodeId);

// Infer schemas for untyped nodes
var inferredSchemas = GraphTypeInferenceEngine.InferInputSchemas(graph);

// Node B now has inferred input schema based on Node A's output
var nodeBSchema = inferredSchemas[nodeB.NodeId];
Console.WriteLine($"Node B inferred inputs: {nodeBSchema.Inputs.Count}");
```

### 型別相容性矩陣

系統提供保守的型別相容性矩陣：

```csharp
// Primitive type compatibility
var intType = GraphType.FromPrimitive(GraphPrimitiveType.Integer);
var numberType = GraphType.FromPrimitive(GraphPrimitiveType.Number);
var anyType = GraphType.FromPrimitive(GraphPrimitiveType.Any);

// Integer is assignable to Number
Console.WriteLine(intType.IsAssignableTo(numberType)); // True

// Number is not assignable to Integer (loss of precision)
Console.WriteLine(numberType.IsAssignableTo(intType)); // False

// Any type is compatible with everything
Console.WriteLine(anyType.IsAssignableTo(intType)); // True
Console.WriteLine(intType.IsAssignableTo(anyType)); // True

// .NET type compatibility
var baseType = GraphType.FromDotNetType(typeof(Animal));
var derivedType = GraphType.FromDotNetType(typeof(Dog));

// Derived types are assignable to base types
Console.WriteLine(derivedType.IsAssignableTo(baseType)); // True
Console.WriteLine(baseType.IsAssignableTo(derivedType)); // False
```

## 最佳做法

### 模式設計

1. **使用特定型別**：盡可能使用精確的型別而非 `Any`
2. **記錄參數**：始終為複雜參數提供說明
3. **版本化模式**：為 State 遷移使用語義化版本控制
4. **測試相容性**：使用現有資料驗證模式變更

### 遷移策略

1. **向後相容性**：在 Major 版本內保持相容性
2. **增量遷移**：將大型變更分解為較小、可管理的步驟
3. **回滾支援**：確保遷移可在需要時反轉
4. **測試**：在生產環境前使用實際資料測試遷移

### 效能考量

1. **延遲驗證**：僅在需要時驗證模式
2. **快取結果**：為重複檢查快取驗證結果
3. **批次操作**：將相關驗證分組在一起
4. **非同步驗證**：對大型資料集使用非同步驗證

## 故障排除

### 常見問題

**型別推斷無法運作**
* 確保來源節點實作 `ITypedSchemaNode`
* 檢查參數名稱是否完全相符（不分大小寫）
* 驗證節點在 Graph 中是否正確連線

**遷移失敗**
* 在遷移前檢查版本相容性
* 確保註冊所有必要的遷移
* 遷移前驗證序列化 State 格式

**驗證錯誤**
* 檢查模式定義中是否有必要欄位
* 檢查節點邊界之間的型別相容性
* 驗證是否提供所有必要的輸入

### 偵錯提示

1. **啟用詳細記錄**：將記錄層級設定為 Debug 以取得驗證詳細資訊
2. **使用 Graph 視覺化**：檢查節點連線和資料流
3. **檢查遷移路徑**：使用 `GetMigrationPath` 瞭解遷移步驟
4. **增量驗證**：在完整 Graph 驗證前測試個別元件

## 概念和技術

**型別推斷**：根據來自連線節點的可用模式資訊自動確定參數型別的程序。

**模式驗證**：驗證資料結構符合已定義模式，確保型別安全和資料完整性。

**State 遷移**：在不同版本之間轉換序列化 State 資料以維持相容性的程序。

**編譯時驗證**：在 Graph 構造期間提早偵測潛在問題，在執行開始前進行。

## 另請參閱

* [建構 Graph](build-a-graph.md) - 了解如何使用型別化模式建立 Graph
* [State 管理](state.md) - 了解 Graph State 和序列化
* [錯誤處理和復原力](error-handling-and-resilience.md) - 妥善處理驗證失敗
* [Graph 檢查和偵錯](debug-and-inspection.md) - 偵錯模式和驗證問題
