# 結構描述型別和驗證

SemanticKernel.Graph 提供一個完整的型別系統和驗證框架，可確保資料一致性、啟用編譯時間檢查，並透過遷移支援無縫的狀態演進。本指南涵蓋完整的結構描述型別生態系統，包括型別推斷、驗證和狀態遷移功能。

## 概述

結構描述型別和驗證系統包含幾個關鍵元件：

* **GraphTypeInferenceEngine**：自動推斷未型別化節點的輸入/輸出結構描述
* **StateValidator**：全面驗證圖表狀態的完整性和一致性
* **TypedSchema 系統**：針對具有基本和 .NET 型別支援的圖表參數的強型別
* **State Migration System**：在不同版本之間自動進行狀態演進
* **Compile-time Validation**：早期偵測結構描述不相容和錯誤

## 核心元件

### GraphTypeInferenceEngine

`GraphTypeInferenceEngine` 使用可用的型別化結構描述在圖表上執行輕量級型別推斷。它會將已知的輸出型別從來源節點傳播到未宣告型別化結構描述的目標。

```csharp
public static class GraphTypeInferenceEngine
{
    /// <summary>
    /// 推斷不實作 ITypedSchemaNode 的節點的輸入結構描述。
    /// 盡可能根據名稱從上游節點的輸出推導輸入參數名稱和型別。
    /// </summary>
    public static IReadOnlyDictionary<string, GraphIOSchema> InferInputSchemas(GraphExecutor graph);
}
```

**關鍵功能：**
* **保守推斷**：僅在確信關係時才推斷型別
* **以名稱為基礎的傳播**：在節點邊界之間按名稱對應參數
* **上游分析**：檢查前置節點以判斷輸入需求
* **後備處理**：在無法取得型別資訊時提供未型別化的後備

**使用範例：**
```csharp
var graph = new GraphExecutor("inference-example");

// 新增型別化的來源節點
var sourceNode = new TypedSourceNode();
graph.AddNode(sourceNode);

// 新增未型別化的目標節點
var targetNode = new UntypedTargetNode();
graph.AddNode(targetNode);

graph.Connect(sourceNode.NodeId, targetNode.NodeId);

// 推斷未型別化節點的結構描述
var inferredSchemas = GraphTypeInferenceEngine.InferInputSchemas(graph);

// 目標節點現在具有根據來源輸出推斷的輸入結構描述
var targetSchema = inferredSchemas[targetNode.NodeId];
```

### StateValidator

`StateValidator` 提供圖表狀態的全面完整性檢查，確保資料一致性並及早識別潛在問題。

```csharp
public static class StateValidator
{
    /// <summary>
    /// 驗證 GraphState 的完整完整性。
    /// </summary>
    public static ValidationResult ValidateState(GraphState state);
    
    /// <summary>
    /// 僅驗證狀態的重要屬性。
    /// </summary>
    public static bool ValidateCriticalProperties(GraphState state);
}
```

**驗證類別：**

1. **基本屬性**：狀態 ID、名稱和中繼資料驗證
2. **資料驗證**：參數名稱、值和型別一致性
3. **執行歷程記錄**：歷程記錄大小限制和完整性檢查
4. **版本驗證**：相容性和遷移需求
5. **大小驗證**：記憶體使用量和序列化大小限制

**使用範例：**
```csharp
var state = new GraphState("validation-test");

// 新增一些資料
state.SetValue("user_id", 123);
state.SetValue("user_name", "John Doe");

// 驗證狀態
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

## 型別化結構描述系統

### GraphType

`GraphType` 類別使用基本分類或 .NET 執行階段型別表示參數型別，以進行更嚴格的驗證。

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
* **Any**：接受任何值（預設值）
* **String**：僅限字串值
* **Integer**：整數值 (int, long 等)
* **Number**：數值 (int, double, decimal 等)
* **Boolean**：僅限布林值
* **Object**：物件執行個體
* **Array**：陣列或集合值
* **Json**：JSON 格式的字串

**使用範例：**
```csharp
// 建立基本型別
var stringType = GraphType.FromPrimitive(GraphPrimitiveType.String);
var intType = GraphType.FromPrimitive(GraphPrimitiveType.Integer);
var numberType = GraphType.FromPrimitive(GraphPrimitiveType.Number);

// 建立 .NET 型別為基礎的型別
var userType = GraphType.FromDotNetType(typeof(User));
var listType = GraphType.FromDotNetType(typeof(List<string>));

// 檢查相容性
Console.WriteLine(stringType.IsValueCompatible("hello")); // True
Console.WriteLine(stringType.IsValueCompatible(123));     // False
Console.WriteLine(intType.IsValueCompatible(42));         // True
Console.WriteLine(intType.IsValueCompatible(3.14));       // False
Console.WriteLine(numberType.IsValueCompatible(3.14));    // True

// 檢查型別可指派性
Console.WriteLine(intType.IsAssignableTo(numberType));    // True (int → number)
Console.WriteLine(numberType.IsAssignableTo(intType));    // False (number ↛ int)
```

### GraphParameterSchema

為個別圖表參數定義結構和條件約束。

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

為節點定義完整的輸入/輸出結構描述，並按方向組織參數。

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

### ITypedSchemaNode 介面

節點可實作此介面以公開其輸入/輸出結構描述以進行驗證和型別推斷。

```csharp
public interface ITypedSchemaNode
{
    /// <summary>
    /// 傳回描述必要/選用輸入的輸入結構描述。
    /// </summary>
    GraphIOSchema GetInputSchema();
    
    /// <summary>
    /// 傳回描述節點產生之值的輸出結構描述。
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

## 狀態遷移系統

### StateVersion

代表圖表狀態的版本，用於相容性控制和遷移。

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
* **主要版本**：不相容的變更需要遷移
* **次要版本**：回溯相容的新增
* **修補程式版本**：錯誤修正和小幅改進
* **相容性**：相同主要版本且 >= 最小支援版本

### IStateMigration 介面

定義不同版本之間狀態遷移的合約。

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

狀態遷移的中央登錄和管理器。

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

## 編譯時間驗證

### 結構描述相容性驗證

`GraphExecutor` 在型別化結構描述可用時自動驗證邊界之間的結構描述相容性。

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
* **必要參數驗證**：警告有關遺漏的必要輸入
* **結構描述傳播**：使用型別推斷填補未型別化節點的空白
* **邊界驗證**：檢查所有圖表連線之間的相容性

### ValidationResult

包含錯誤、警告和成功狀態的全面驗證結果。

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

型別推斷引擎使用保守策略以避免誤報：

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

## 最佳實務

### 結構描述設計

1. **使用特定型別**：盡可能使用精確型別而非 `Any`
2. **記錄參數**：一律為複雜參數提供描述
3. **版本化結構描述**：針對狀態遷移使用語義版本設定
4. **測試相容性**：使用現有資料驗證結構描述變更

### 遷移策略

1. **回溯相容性**：在主要版本內維護相容性
2. **累進遷移**：將大型變更分解為較小的可管理步驟
3. **復原支援**：確保遷移可在需要時反向
4. **測試**：在生產前使用真實資料測試遷移

### 效能考量

1. **延遲驗證**：僅在需要時驗證結構描述
2. **快取結果**：快取重複檢查的驗證結果
3. **批次操作**：將相關驗證分組在一起
4. **非同步驗證**：針對大型資料集使用非同步驗證

## 疑難排解

### 常見問題

**型別推斷無法運作**
* 確保來源節點實作 `ITypedSchemaNode`
* 檢查參數名稱是否完全相符（不區分大小寫）
* 確認節點在圖表中正確連線

**遷移失敗**
* 遷移前檢查版本相容性
* 確保所有必要的遷移已登錄
* 遷移前驗證序列化狀態格式

**驗證錯誤**
* 檢查必要欄位的結構描述定義
* 檢查節點邊界之間的型別相容性
* 確認所有必要輸入都已提供

### 除錯提示

1. **啟用詳細記錄**：將記錄層級設定為 Debug 以取得驗證詳細資訊
2. **使用圖表視覺化**：檢查節點連線和資料流
3. **檢查遷移路徑**：使用 `GetMigrationPath` 瞭解遷移步驟
4. **累進驗證**：在進行完整圖表驗證前測試個別元件

## 概念和技術

**型別推斷**：根據連線節點中的可用結構描述資訊自動判斷參數型別的程序。

**結構描述驗證**：驗證資料結構是否符合定義的結構描述，確保型別安全和資料完整性。

**狀態遷移**：在不同版本之間轉換序列化狀態資料以維護相容性的程序。

**編譯時間驗證**：在圖表建構期間早期偵測潛在問題，執行開始前。

## 另請參閱

* [建立圖表](build-a-graph.md) - 瞭解如何建立具有型別化結構描述的圖表
* [狀態管理](state.md) - 瞭解圖表狀態和序列化
* [錯誤處理和復原力](error-handling-and-resilience.md) - 妥適處理驗證失敗
* [圖表檢查和偵錯](debug-and-inspection.md) - 偵錯結構描述和驗證問題
