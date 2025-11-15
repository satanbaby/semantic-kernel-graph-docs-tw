# 狀態與序列化

SemanticKernel.Graph 中的狀態管理系統為數據流、執行跟蹤和持久化提供了堅實的基礎。本參考涵蓋核心狀態類別、序列化功能以及用於處理圖形狀態的實用程式方法。

## 概述

狀態系統圍繞 `GraphState` 構建，該系統使用增強功能包裹 `KernelArguments`，包括執行跟蹤、元資料管理、驗證和序列化。該系統支援版本控制、完整性檢查、壓縮以及用於並行執行場景的高級合併操作。

## 主要概念

**GraphState**：增強的 `KernelArguments` 包裝器，提供執行跟蹤、元資料、驗證和序列化功能。

**ISerializableState**：定義標準序列化方法的介面，具有版本控制和完整性檢查。

**StateVersion**：用於狀態相容性控制和遷移支援的語義版本控制系統。

**SerializationOptions**：可配置的選項，用於控制序列化行為、壓縮和元資料包含。

**StateHelpers**：常見狀態操作的實用程式方法，包括序列化、合併、驗證和檢查點。

## 核心類別

### GraphState

主要狀態容器，使用額外的圖形特定功能包裝 `KernelArguments`。

#### 屬性

* **`KernelArguments`**：底層 `KernelArguments` 執行個體
* **`StateId`**：此狀態執行個體的唯一識別符
* **`Version`**：當前狀態版本，用於相容性控制
* **`CreatedAt`**：狀態建立時的時間戳記
* **`LastModified`**：上次狀態修改的時間戳記
* **`ExecutionHistory`**：執行步驟的唯讀集合
* **`ExecutionStepCount`**：記錄的執行步驟總數
* **`IsModified`**：指示狀態自建立後是否已修改

#### 建構函式

```csharp
// GraphState 為建立狀態執行個體提供了便利的建構函式。
public class GraphState
{
    // 使用預設 KernelArguments 建立空狀態
    public GraphState() { /* implementation omitted */ }

    // 從現有 KernelArguments 初始化建立狀態
    public GraphState(KernelArguments kernelArguments) { /* implementation omitted */ }
}
```

**範例：**
```csharp
// 使用現有引數建立狀態並讀取值。
var arguments = new KernelArguments
{
    ["input"] = "Hello World",
    ["timestamp"] = DateTimeOffset.UtcNow
};

// 使用 KernelArguments 初始化 GraphState
var graphState = new GraphState(arguments);

// 安全地存取底層 KernelArguments
var kernelArgs = graphState.KernelArguments;
var input = kernelArgs.GetValue<string>("input");
```

#### 狀態存取方法

```csharp
// GraphState 中用於存取值的範例方法簽章。
public class GraphState
{
    public T? GetValue<T>(string name) { /* returns typed value or default */ throw null!; }
    public bool TryGetValue<T>(string name, out T? value) { value = default; return false; }
    public void SetValue(string name, object? value) { }
    public bool RemoveValue(string name) { return false; }
    public bool ContainsValue(string name) { return false; }
    public IEnumerable<string> GetParameterNames() { yield break; }
}
```

**範例：**
```csharp
// 使用 GraphState API 設定和擷取值。
graphState.SetValue("userName", "Alice");
graphState.SetValue("age", 30);

// 型別安全的擷取
var userName = graphState.GetValue<string>("userName"); // 傳回 "Alice"
var age = graphState.GetValue<int>("age"); // 傳回 30

// 使用 TryGetValue 安全擷取
if (graphState.TryGetValue<string>("email", out var email) && email is not null)
{
    Console.WriteLine($"Email: {email}");
}

// 檢查是否存在
if (graphState.ContainsValue("userName"))
{
    Console.WriteLine("Username is set");
}
```

#### 元資料方法

```csharp
// GraphState 上的元資料協助程式。
public class GraphState
{
    public T? GetMetadata<T>(string key) { /* returns typed metadata */ throw null!; }
    public void SetMetadata(string key, object value) { }
    public bool RemoveMetadata(string key) { return false; }
}
```

**範例：**
```csharp
// 在狀態上儲存和擷取元資料。
graphState.SetMetadata("source", "user_input");
graphState.SetMetadata("priority", "high");

var source = graphState.GetMetadata<string>("source");
var priority = graphState.GetMetadata<string>("priority");
Console.WriteLine($"source={source}, priority={priority}");
```

#### ISerializableState 實作

```csharp
// 典型的 ISerializableState 實作表面。
public interface ISerializableState
{
    StateVersion Version { get; }
    string StateId { get; }
    DateTimeOffset CreatedAt { get; }
    DateTimeOffset LastModified { get; }
    string Serialize(SerializationOptions? options = null);
    ValidationResult ValidateIntegrity();
    string CreateChecksum();
}
```

**範例：**
```csharp
// 序列化和驗證狀態完整性。
var serialized = graphState.Serialize();

var options = new SerializationOptions
{
    Indented = true,
    EnableCompression = true,
    IncludeMetadata = true
};

var verboseSerialized = graphState.Serialize(options);

// 驗證完整性並報告任何錯誤
var validation = graphState.ValidateIntegrity();
if (!validation.IsValid)
{
    foreach (var error in validation.Errors)
    {
        Console.WriteLine($"Validation error: {error}");
    }
}

// 計算檢查和以供日後驗證
var checksum = graphState.CreateChecksum();
```

### ISerializableState

定義標準序列化方法的介面，具有版本控制和完整性檢查。

#### 介面方法

```csharp
// 可序列化狀態的範例介面成員。
public interface ISerializableState
{
    StateVersion Version { get; }
    string StateId { get; }
    DateTimeOffset CreatedAt { get; }
    DateTimeOffset LastModified { get; }
    string Serialize(SerializationOptions? options = null);
    ValidationResult ValidateIntegrity();
    string CreateChecksum();
}
```

### SerializationOptions

用於控制序列化行為的可配置選項。

#### 屬性

* **`Indented`**：是否使用縮排格式化
* **`EnableCompression`**：是否為大型狀態啟用壓縮
* **`IncludeMetadata`**：是否在序列化中包含元資料
* **`IncludeExecutionHistory`**：是否包含執行歷史記錄
* **`CompressionLevel`**：要使用的壓縮等級
* **`JsonOptions`**：自訂 JSON 序列化程式選項
* **`ValidateIntegrity`**：是否在序列化後驗證完整性

#### 工廠方法

```csharp
// SerializationOptions 的常見工廠預設值。
public class SerializationOptions
{
    public bool Indented { get; set; }
    public bool EnableCompression { get; set; }
    public bool IncludeMetadata { get; set; }
    public bool IncludeExecutionHistory { get; set; }
    public System.IO.Compression.CompressionLevel? CompressionLevel { get; set; }
    public bool ValidateIntegrity { get; set; }

    public static SerializationOptions Default => new SerializationOptions();

    public static SerializationOptions Compact => new SerializationOptions
    {
        Indented = false,
        EnableCompression = true,
        IncludeMetadata = false,
        IncludeExecutionHistory = false
    };

    public static SerializationOptions Verbose => new SerializationOptions
    {
        Indented = true,
        EnableCompression = false,
        IncludeMetadata = true,
        IncludeExecutionHistory = true,
        ValidateIntegrity = true
    };
}
```

**範例：**
```csharp
// 選擇預定義的選項預設值或建立自訂預設值。
var compactOptions = SerializationOptions.Compact;
var verboseOptions = SerializationOptions.Verbose;

var customOptions = new SerializationOptions
{
    Indented = true,
    EnableCompression = true,
    IncludeMetadata = true,
    IncludeExecutionHistory = false,
    CompressionLevel = System.IO.Compression.CompressionLevel.Fastest
};
```

### StateVersion

代表用於相容性控制和遷移的狀態版本。

#### 屬性

* **`Major`**：主要版本號碼
* **`Minor`**：次要版本號碼
* **`Patch`**：修補程式版本號碼
* **`IsCompatible`**：指示此版本是否與當前版本相容
* **`RequiresMigration`**：指示此版本是否需要遷移

#### 常數

```csharp
// 狀態系統使用的範例版本常數。
public static class StateVersionConstants
{
    public static readonly StateVersion Current = new StateVersion(1, 1, 0);
    public static readonly StateVersion MinimumSupported = new StateVersion(1, 0, 0);
}
```

#### 建構函式

```csharp
// 構造狀態版本執行個體。
public record StateVersion(int Major, int Minor, int Patch)
{
    public StateVersion(int major, int minor, int patch) : this(major, minor, patch) { }
    public bool IsCompatible => Major == StateVersionConstants.Current.Major;
    public bool RequiresMigration => this < StateVersionConstants.Current;
}
```

**範例：**
```csharp
// 建立版本
var version = new StateVersion(1, 2, 3);

// 檢查相容性
var isCompatible = version.IsCompatible; // 如果相容則為 true
var needsMigration = version.RequiresMigration; // 如果需要遷移則為 true

// 比較版本
if (version < StateVersion.Current)
{
    Console.WriteLine("State version is older than current");
}
```

#### 靜態方法

```csharp
// StateVersion 的剖析協助程式。
public static class StateVersionParser
{
    public static StateVersion Parse(string version) =>
        TryParse(version, out var v) ? v : throw new FormatException("Invalid version format");

    public static bool TryParse(string? version, out StateVersion result)
    {
        result = default!;
        if (string.IsNullOrWhiteSpace(version)) return false;
        var parts = version.Split('.');
        if (parts.Length != 3) return false;
        if (int.TryParse(parts[0], out var major) && int.TryParse(parts[1], out var minor) && int.TryParse(parts[2], out var patch))
        {
            result = new StateVersion(major, minor, patch);
            return true;
        }
        return false;
    }
}
```

**範例：**
```csharp
// 剖析版本字串
var version = StateVersion.Parse("1.2.3");
Console.WriteLine($"Major: {version.Major}");    // 1
Console.WriteLine($"Minor: {version.Minor}");    // 2
Console.WriteLine($"Patch: {version.Patch}");    // 3

// 安全的剖析
if (StateVersion.TryParse("invalid", out var parsedVersion))
{
    // 使用剖析的版本
}
else
{
    Console.WriteLine("Invalid version format");
}
```

### StateHelpers

常見狀態操作的實用程式方法，包括序列化、合併、驗證和檢查點。

#### 序列化方法

```csharp
// GraphState 執行個體的序列化和反序列化協助程式。
public static class StateHelpers
{
    public static string SerializeState(GraphState state, bool indented = false, bool enableCompression = true, bool useCache = true)
    {
        // 實作委派至 GraphState.Serialize，並帶有 SerializationOptions 執行個體。
        var options = new SerializationOptions { Indented = indented, EnableCompression = enableCompression };
        return state.Serialize(options);
    }

    public static string SerializeState(GraphState state, bool indented, bool enableCompression, bool useCache, out SerializationMetrics metrics)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var result = SerializeState(state, indented, enableCompression, useCache);
        sw.Stop();
        metrics = new SerializationMetrics { Duration = sw.Elapsed };
        return result;
    }

    public static GraphState DeserializeState(string serializedData)
    {
        // 委派至 GraphState 反序列化邏輯 (為簡潔起見省略實作)。
        throw new NotImplementedException();
    }
}
```

**範例：**
```csharp
// 使用協助程式和選擇性計量進行基本序列化。
var serialized = StateHelpers.SerializeState(graphState);

var serializedWithMetrics = StateHelpers.SerializeState(graphState, indented: true, enableCompression: true, useCache: true, out var metrics);
Console.WriteLine($"Serialization took: {metrics.Duration}");

// 反序列化 (若在文件中未實作可能擲回)
// var restoredState = StateHelpers.DeserializeState(serialized);
```

#### 狀態管理方法

```csharp
// 高階狀態管理協助程式。實作應在適當的地方保留不可變性。
public static class StateHelpers
{
    public static GraphState CloneState(GraphState state) => new GraphState(state.KernelArguments);

    public static GraphState MergeStates(GraphState baseState, GraphState overlayState, StateMergeConflictPolicy policy)
    {
        // 簡化的合併：預設情況下覆蓋優先。
        var merged = CloneState(baseState);
        foreach (var name in overlayState.GetParameterNames())
        {
            if (overlayState.TryGetValue<object>(name, out var v)) merged.SetValue(name, v);
        }
        return merged;
    }

    public static GraphState MergeStates(GraphState baseState, GraphState overlayState, StateMergeConfiguration configuration) =>
        MergeStates(baseState, overlayState, configuration.DefaultPolicy);

    public static StateMergeResult MergeStatesWithConflictDetection(GraphState baseState, GraphState overlayState, StateMergeConfiguration configuration, bool detectConflicts = true)
    {
        // 在此範例中傳回表示沒有衝突的簡單結果。
        return new StateMergeResult { HasConflicts = false };
    }
}
```

**範例：**
```csharp
// 使用協助程式複製和合併狀態。
var clonedState = StateHelpers.CloneState(graphState);
var mergedState = StateHelpers.MergeStates(baseState, overlayState, StateMergeConflictPolicy.PreferSecond);

// 使用組態型合併
var config = new StateMergeConfiguration { DefaultPolicy = StateMergeConflictPolicy.Reduce };
config.SetKeyPolicy("counters", StateMergeConflictPolicy.Reduce);
var advancedMergedState = StateHelpers.MergeStates(baseState, overlayState, config);

// 使用衝突偵測進行合併
var mergeResult = StateHelpers.MergeStatesWithConflictDetection(baseState, overlayState, config, detectConflicts: true);
if (mergeResult.HasConflicts)
{
    foreach (var conflict in mergeResult.Conflicts)
    {
        Console.WriteLine($"Conflict on '{conflict.Key}': {conflict.BaseValue} vs {conflict.OverlayValue}");
    }
}
```

#### 驗證方法

```csharp
// 驗證協助程式以檢查必需參數並強制執行型別條件約束。
public static class StateHelpers
{
    public static IList<string> ValidateRequiredParameters(GraphState state, IEnumerable<string> requiredParameters)
    {
        var missing = new List<string>();
        foreach (var p in requiredParameters)
        {
            if (!state.ContainsValue(p)) missing.Add(p);
        }
        return missing;
    }

    public static IList<string> ValidateParameterTypes(GraphState state, IDictionary<string, Type> typeConstraints)
    {
        var violations = new List<string>();
        foreach (var kvp in typeConstraints)
        {
            if (state.TryGetValue<object>(kvp.Key, out var val) && val != null && !kvp.Value.IsInstanceOfType(val))
            {
                violations.Add($"{kvp.Key} expected {kvp.Value.Name} but got {val.GetType().Name}");
            }
        }
        return violations;
    }
}
```

**範例：**
```csharp
var required = new[] { "userName", "email", "age" };
var missing = StateHelpers.ValidateRequiredParameters(graphState, required);
if (missing.Count > 0)
{
    Console.WriteLine($"Missing required parameters: {string.Join(", ", missing)}");
}

var typeConstraints = new Dictionary<string, Type>
{
    ["userName"] = typeof(string),
    ["age"] = typeof(int),
    ["isActive"] = typeof(bool)
};

var violations = StateHelpers.ValidateParameterTypes(graphState, typeConstraints);
if (violations.Count > 0)
{
    foreach (var v in violations) Console.WriteLine($"Type violation: {v}");
}
```

#### 交易方法

```csharp
// 交易協助程式：開始、提交和復原。
public static class StateHelpers
{
    public static string BeginTransaction(GraphState state) => Guid.NewGuid().ToString();
    public static GraphState RollbackTransaction(GraphState state, string transactionId) => CloneState(state);
    public static void CommitTransaction(GraphState state, string transactionId) { /* commit changes */ }
}
```

**範例：**
```csharp
var transactionId = StateHelpers.BeginTransaction(graphState);
try
{
    // 執行暫時性變更
    graphState.SetValue("tempValue", "will be rolled back");

    // 域驗證預留位置
    var valid = true; // 以真實驗證取代
    if (valid)
    {
        StateHelpers.CommitTransaction(graphState, transactionId);
    }
    else
    {
        graphState = StateHelpers.RollbackTransaction(graphState, transactionId);
    }
}
catch (Exception)
{
    graphState = StateHelpers.RollbackTransaction(graphState, transactionId);
}
```

#### 檢查點方法

```csharp
// 檢查點協助程式建立和還原輕量級狀態快照。
public static class StateHelpers
{
    public static string CreateCheckpoint(GraphState state, string checkpointName) => Guid.NewGuid().ToString();
    public static GraphState RestoreCheckpoint(GraphState state, string checkpointId) => CloneState(state);
}
```

**範例：**
```csharp
var checkpointId = StateHelpers.CreateCheckpoint(graphState, "before_processing");
graphState.SetValue("processed", true);
// 如果需要復原：
// graphState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);
```

#### 壓縮方法

```csharp
// 壓縮相關協助程式，用於測量和管理自適應壓縮。
public static class StateHelpers
{
    public static CompressionStats GetCompressionStats(string data) => new CompressionStats { OriginalSizeBytes = data.Length, CompressedSizeBytes = data.Length };
    public static int GetAdaptiveCompressionThreshold() => 1024;
    public static void ResetAdaptiveCompression() { }
    public static AdaptiveCompressionState GetAdaptiveCompressionState() => new AdaptiveCompressionState();
}
```

**範例：**
```csharp
var stats = StateHelpers.GetCompressionStats(serializedData);
Console.WriteLine($"Original size: {stats.OriginalSizeBytes} bytes");
Console.WriteLine($"Compressed size: {stats.CompressedSizeBytes} bytes");
// 自適應壓縮資訊
var threshold = StateHelpers.GetAdaptiveCompressionThreshold();
var adaptiveState = StateHelpers.GetAdaptiveCompressionState();
```

## 使用模式

### 基本狀態建立和管理

```csharp
// 範例：建立和檢查 GraphState 執行個體。
var arguments = new KernelArguments
{
    ["input"] = "Hello World",
    ["timestamp"] = DateTimeOffset.UtcNow,
    ["user"] = "Alice"
};

var graphState = new GraphState(arguments);
graphState.SetMetadata("source", "user_input");

Console.WriteLine($"State ID: {graphState.StateId}");
Console.WriteLine($"Version: {graphState.Version}");
```

### 狀態序列化和持久化

```csharp
// 使用內建預設值或自訂選項執行個體進行序列化。
var compactSerialized = graphState.Serialize(SerializationOptions.Compact);
var verboseSerialized = graphState.Serialize(SerializationOptions.Verbose);

var customOptions = new SerializationOptions
{
    Indented = true,
    EnableCompression = true,
    IncludeMetadata = true,
    IncludeExecutionHistory = false,
    CompressionLevel = System.IO.Compression.CompressionLevel.Fastest
};

var customSerialized = graphState.Serialize(customOptions);

// 儲存和載入範例 (需要非同步內容)
// await File.WriteAllTextAsync("state.json", customSerialized);
// var loadedData = await File.ReadAllTextAsync("state.json");
// var restoredState = StateHelpers.DeserializeState(loadedData);
```

### 狀態合併和衝突解決

```csharp
// 建立要合併的狀態
var baseState = new GraphState(new KernelArguments
{
    ["user"] = "Alice",
    ["count"] = 5,
    ["settings"] = new Dictionary<string, object> { ["theme"] = "dark" }
});

var overlayState = new GraphState(new KernelArguments
{
    ["count"] = 10,
    ["settings"] = new Dictionary<string, object> { ["language"] = "en" }
});

// 簡單合併 (覆蓋優先)
var mergedState = StateHelpers.MergeStates(baseState, overlayState, 
    StateMergeConflictPolicy.PreferSecond);

// 進階合併含組態
var config = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.PreferSecond
};

// 設定特定原則
config.SetKeyPolicy("count", StateMergeConflictPolicy.Reduce);
config.SetTypePolicy(typeof(Dictionary<string, object>), StateMergeConflictPolicy.Reduce);

// 字典的自訂合併器
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

var advancedMergedState = StateHelpers.MergeStates(baseState, overlayState, config);
```

### 狀態驗證和完整性

```csharp
// 驗證狀態完整性
var validation = graphState.ValidateIntegrity();
if (!validation.IsValid)
{
    Console.WriteLine("State validation failed:");
    foreach (var error in validation.Errors)
    {
        Console.WriteLine($"  Error: {error}");
    }
    foreach (var warning in validation.Warnings)
    {
        Console.WriteLine($"  Warning: {warning}");
    }
}

// 建立和驗證檢查和
var originalChecksum = graphState.CreateChecksum();

// 進行變更
graphState.SetValue("modified", true);

// 驗證完整性
var newChecksum = graphState.CreateChecksum();
if (originalChecksum != newChecksum)
{
    Console.WriteLine("State has been modified");
}

// 驗證必需參數
var required = new[] { "user", "email", "age" };
var missing = StateHelpers.ValidateRequiredParameters(graphState, required);

if (missing.Count > 0)
{
    throw new InvalidOperationException(
        $"Missing required parameters: {string.Join(", ", missing)}");
}

// 驗證參數型別
var typeConstraints = new Dictionary<string, Type>
{
    ["user"] = typeof(string),
    ["age"] = typeof(int),
    ["isActive"] = typeof(bool)
};

var violations = StateHelpers.ValidateParameterTypes(graphState, typeConstraints);
if (violations.Count > 0)
{
    throw new InvalidOperationException(
        $"Type violations: {string.Join("; ", violations)}");
}
```

### 狀態交易和檢查點

```csharp
// 建立檢查點
var checkpointId = StateHelpers.CreateCheckpoint(graphState, "initial_state");

// 開始交易
var transactionId = StateHelpers.BeginTransaction(graphState);

try
{
    // 在交易中進行變更
    graphState.SetValue("temp1", "value1");
    graphState.SetValue("temp2", "value2");
    
    // 驗證變更
    if (ValidateChanges(graphState))
    {
        // 提交交易
        StateHelpers.CommitTransaction(graphState, transactionId);
        Console.WriteLine("Transaction committed successfully");
    }
    else
    {
        // 復原交易
        var rolledBackState = StateHelpers.RollbackTransaction(graphState, transactionId);
        graphState = rolledBackState;
        Console.WriteLine("Transaction rolled back due to validation failure");
    }
}
catch (Exception ex)
{
    // 因錯誤復原
    var rolledBackState = StateHelpers.RollbackTransaction(graphState, transactionId);
    graphState = rolledBackState;
    Console.WriteLine($"Transaction rolled back due to error: {ex.Message}");
}

// 必要時還原檢查點
if (needToRestore)
{
    var restoredState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);
    graphState = restoredState;
    Console.WriteLine("State restored from checkpoint");
}
```

## 效能考量

* **序列化快取**：對同一狀態的重複序列化使用 `useCache: true`
* **壓縮**：為大型狀態啟用壓縮以降低儲存和傳輸成本
* **自適應壓縮**：系統根據觀察到的優勢自動調整壓縮閾值
* **驗證**：在生產環境中謹慎使用驗證；考慮快取驗證結果
* **元資料**：保持元資料輕量級以避免序列化開銷

## 執行緒安全性

* **GraphState**：執行緒安全用於並行讀取；並行寫入需要外部同步
* **StateHelpers**：靜態方法為執行緒安全；為共用狀態使用適當的鎖定
* **序列化**：快取序列化為執行緒安全，具有內部鎖定

## 錯誤處理

* **驗證**：反序列化後務必驗證狀態完整性
* **檢查和**：使用檢查和偵測狀態損毀
* **交易**：實作適當的錯誤處理和復原邏輯
* **遷移**：使用遷移邏輯優雅地處理版本不相容

## 另請參閱

* [狀態管理指南](../concepts/state.md)
* [檢查點指南](../how-to/checkpointing.md)
* [狀態快速入門](../state-quickstart.md)
* [狀態教程](../state-tutorial.md)
* [ConditionalEdge](conditional-edge.md)
* [StateMergeConfiguration](state-merge-configuration.md)
* [StateMergeConflictPolicy](state-merge-conflict-policy.md)
