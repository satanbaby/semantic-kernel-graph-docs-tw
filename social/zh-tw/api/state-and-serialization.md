# State 與 Serialization

SemanticKernel.Graph 中的 state 管理系統提供了強大的基礎，用於數據流、執行追蹤和持久化。本參考涵蓋核心 state 類別、serialization 功能和處理 graph state 的實用方法。

## 概觀

state 系統以 `GraphState` 為中心，它以增強的功能包裝 `KernelArguments`，用於執行追蹤、metadata 管理、驗證和 serialization。該系統支持版本控制、完整性檢查、compression 和用於平行執行場景的高級合併操作。

## 關鍵概念

**GraphState**：`KernelArguments` 的增強包裝器，提供執行追蹤、metadata、驗證和 serialization 功能。

**ISerializableState**：定義標準 state serialization 方法的介面，包括版本控制和完整性檢查。

**StateVersion**：語義版本控制系統，用於 state 相容性控制和遷移支持。

**SerializationOptions**：可配置的選項，用於控制 serialization 行為、compression 和 metadata 包含。

**StateHelpers**：常見 state 操作的實用方法，包括 serialization、合併、驗證和 checkpointing。

## 核心類別

### GraphState

主要 state 容器，以額外的 graph 特定功能包裝 `KernelArguments`。

#### 屬性

* **`KernelArguments`**：底層 `KernelArguments` 實例
* **`StateId`**：此 state 實例的唯一識別碼
* **`Version`**：目前 state 版本，用於相容性控制
* **`CreatedAt`**：state 建立時的時間戳
* **`LastModified`**：上次 state 修改的時間戳
* **`ExecutionHistory`**：執行步驟的唯讀集合
* **`ExecutionStepCount`**：已記錄的執行步驟總數
* **`IsModified`**：指示 state 自建立後是否已被修改

#### 建構函數

```csharp
// GraphState 提供便利的建構函數來建立 state 實例。
public class GraphState
{
    // 使用預設 KernelArguments 建立空 state
    public GraphState() { /* implementation omitted */ }

    // 從現有 KernelArguments 初始化 state
    public GraphState(KernelArguments kernelArguments) { /* implementation omitted */ }
}
```

**範例：**
```csharp
// 使用現有引數建立 state 並讀取值。
var arguments = new KernelArguments
{
    ["input"] = "Hello World",
    ["timestamp"] = DateTimeOffset.UtcNow
};

// 以 KernelArguments 初始化 GraphState
var graphState = new GraphState(arguments);

// 安全地存取底層 KernelArguments
var kernelArgs = graphState.KernelArguments;
var input = kernelArgs.GetValue<string>("input");
```

#### State 存取方法

```csharp
// GraphState 中存取值的範例方法簽名。
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
// 使用 GraphState API 設定和取得值。
graphState.SetValue("userName", "Alice");
graphState.SetValue("age", 30);

// 類型安全的取值
var userName = graphState.GetValue<string>("userName"); // returns "Alice"
var age = graphState.GetValue<int>("age"); // returns 30

// 使用 TryGetValue 安全取值
if (graphState.TryGetValue<string>("email", out var email) && email is not null)
{
    Console.WriteLine($"Email: {email}");
}

// 檢查存在性
if (graphState.ContainsValue("userName"))
{
    Console.WriteLine("Username is set");
}
```

#### Metadata 方法

```csharp
// GraphState 上的 metadata 協助程式。
public class GraphState
{
    public T? GetMetadata<T>(string key) { /* returns typed metadata */ throw null!; }
    public void SetMetadata(string key, object value) { }
    public bool RemoveMetadata(string key) { return false; }
}
```

**範例：**
```csharp
// 在 state 上存儲和檢索 metadata。
graphState.SetMetadata("source", "user_input");
graphState.SetMetadata("priority", "high");

var source = graphState.GetMetadata<string>("source");
var priority = graphState.GetMetadata<string>("priority");
Console.WriteLine($"source={source}, priority={priority}");
```

#### ISerializableState 實作

```csharp
// 典型的 ISerializableState 實作面。
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
// Serialize 和驗證 state 完整性。
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

// 計算 checksum 以供稍後驗證
var checksum = graphState.CreateChecksum();
```

### ISerializableState

定義標準 state serialization 方法的介面，包括版本控制和完整性檢查。

#### 介面方法

```csharp
// serializable state 的範例介面成員。
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

用於控制 serialization 行為的可配置選項。

#### 屬性

* **`Indented`**：是否使用縮排格式
* **`EnableCompression`**：是否為大型 state 啟用 compression
* **`IncludeMetadata`**：是否在 serialization 中包含 metadata
* **`IncludeExecutionHistory`**：是否包含執行歷史記錄
* **`CompressionLevel`**：要使用的 compression 級別
* **`JsonOptions`**：自訂 JSON serializer 選項
* **`ValidateIntegrity`**：是否在 serialization 後驗證完整性

#### 工廠方法

```csharp
// SerializationOptions 的常見工廠預設。
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
// 選擇預定義的選項預設或建立自訂選項。
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

表示 state 版本，用於相容性控制和遷移。

#### 屬性

* **`Major`**：主版本號
* **`Minor`**：次版本號
* **`Patch`**：修補程式版本號
* **`IsCompatible`**：指示此版本是否與目前版本相容
* **`RequiresMigration`**：指示此版本是否需要遷移

#### 常數

```csharp
// state 系統使用的範例版本常數。
public static class StateVersionConstants
{
    public static readonly StateVersion Current = new StateVersion(1, 1, 0);
    public static readonly StateVersion MinimumSupported = new StateVersion(1, 0, 0);
}
```

#### 建構函數

```csharp
// 建構一個 state 版本實例。
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
var isCompatible = version.IsCompatible; // true if compatible
var needsMigration = version.RequiresMigration; // true if needs migration

// 比較版本
if (version < StateVersion.Current)
{
    Console.WriteLine("State version is older than current");
}
```

#### 靜態方法

```csharp
// StateVersion 的 Parsing 協助程式。
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
// Parse 版本字串
var version = StateVersion.Parse("1.2.3");
Console.WriteLine($"Major: {version.Major}");    // 1
Console.WriteLine($"Minor: {version.Minor}");    // 2
Console.WriteLine($"Patch: {version.Patch}");    // 3

// 安全 parsing
if (StateVersion.TryParse("invalid", out var parsedVersion))
{
    // Use parsed version
}
else
{
    Console.WriteLine("Invalid version format");
}
```

### StateHelpers

常見 state 操作的實用方法，包括 serialization、合併、驗證和 checkpointing。

#### Serialization 方法

```csharp
// GraphState 實例的 serialization 和 deserialization 協助程式。
public static class StateHelpers
{
    public static string SerializeState(GraphState state, bool indented = false, bool enableCompression = true, bool useCache = true)
    {
        // Implementation delegates to GraphState.Serialize with a SerializationOptions instance.
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
        // Delegates to GraphState deserialization logic (implementation omitted for brevity).
        throw new NotImplementedException();
    }
}
```

**範例：**
```csharp
// 使用協助程式和選擇性 metrics 進行基本 serialization。
var serialized = StateHelpers.SerializeState(graphState);

var serializedWithMetrics = StateHelpers.SerializeState(graphState, indented: true, enableCompression: true, useCache: true, out var metrics);
Console.WriteLine($"Serialization took: {metrics.Duration}");

// Deserialization (might throw if unimplemented in docs)
// var restoredState = StateHelpers.DeserializeState(serialized);
```

#### State 管理方法

```csharp
// 高階 state 管理協助程式。實作應在適當的情況下保持不變性。
public static class StateHelpers
{
    public static GraphState CloneState(GraphState state) => new GraphState(state.KernelArguments);

    public static GraphState MergeStates(GraphState baseState, GraphState overlayState, StateMergeConflictPolicy policy)
    {
        // Simplified merge: overlay takes precedence by default.
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
        // Returns a simple result indicating no conflicts in this example.
        return new StateMergeResult { HasConflicts = false };
    }
}
```

**範例：**
```csharp
// 使用協助程式複製和合併 state。
var clonedState = StateHelpers.CloneState(graphState);
var mergedState = StateHelpers.MergeStates(baseState, overlayState, StateMergeConflictPolicy.PreferSecond);

// 使用基於組態的合併
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
// 驗證協助程式以檢查必要的參數和強制執行類型約束。
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

#### Transaction 方法

```csharp
// Transaction 協助程式：開始、提交和回滾。
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
    // 執行暫時變更
    graphState.SetValue("tempValue", "will be rolled back");

    // 佔位符用於域驗證
    var valid = true; // replace with real validation
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

#### Checkpoint 方法

```csharp
// Checkpoint 協助程式建立和還原 state 的輕量級快照。
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
// If rollback needed:
// graphState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);
```

#### Compression 方法

```csharp
// Compression 相關協助程式，用於測量和管理自適應 compression。
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
// 自適應 compression 資訊
var threshold = StateHelpers.GetAdaptiveCompressionThreshold();
var adaptiveState = StateHelpers.GetAdaptiveCompressionState();
```

## 使用模式

### 基本 State 建立和管理

```csharp
// 範例：建立和檢視 GraphState 實例。
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

### State Serialization 和持久化

```csharp
// 使用內建預設或自訂選項實例進行 serialization。
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

// 保存和加載範例（需要 async 上下文）
// await File.WriteAllTextAsync("state.json", customSerialized);
// var loadedData = await File.ReadAllTextAsync("state.json");
// var restoredState = StateHelpers.DeserializeState(loadedData);
```

### State 合併和衝突解決

```csharp
// 建立要合併的 state
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

// 簡單合併（overlay 具有優先權）
var mergedState = StateHelpers.MergeStates(baseState, overlayState, 
    StateMergeConflictPolicy.PreferSecond);

// 使用組態的高級合併
var config = new StateMergeConfiguration
{
    DefaultPolicy = StateMergeConflictPolicy.PreferSecond
};

// 組態特定原則
config.SetKeyPolicy("count", StateMergeConflictPolicy.Reduce);
config.SetTypePolicy(typeof(Dictionary<string, object>), StateMergeConflictPolicy.Reduce);

// 字典的自訂合併程式
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

### State 驗證和完整性

```csharp
// 驗證 state 完整性
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

// 建立和驗證 checksum
var originalChecksum = graphState.CreateChecksum();

// 進行變更
graphState.SetValue("modified", true);

// 驗證完整性
var newChecksum = graphState.CreateChecksum();
if (originalChecksum != newChecksum)
{
    Console.WriteLine("State has been modified");
}

// 驗證必要參數
var required = new[] { "user", "email", "age" };
var missing = StateHelpers.ValidateRequiredParameters(graphState, required);

if (missing.Count > 0)
{
    throw new InvalidOperationException(
        $"Missing required parameters: {string.Join(", ", missing)}");
}

// 驗證參數類型
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

### State Transaction 和 Checkpointing

```csharp
// 建立 checkpoint
var checkpointId = StateHelpers.CreateCheckpoint(graphState, "initial_state");

// 開始 transaction
var transactionId = StateHelpers.BeginTransaction(graphState);

try
{
    // 在 transaction 中進行變更
    graphState.SetValue("temp1", "value1");
    graphState.SetValue("temp2", "value2");
    
    // 驗證變更
    if (ValidateChanges(graphState))
    {
        // 提交 transaction
        StateHelpers.CommitTransaction(graphState, transactionId);
        Console.WriteLine("Transaction committed successfully");
    }
    else
    {
        // 回滾 transaction
        var rolledBackState = StateHelpers.RollbackTransaction(graphState, transactionId);
        graphState = rolledBackState;
        Console.WriteLine("Transaction rolled back due to validation failure");
    }
}
catch (Exception ex)
{
    // 在錯誤時回滾
    var rolledBackState = StateHelpers.RollbackTransaction(graphState, transactionId);
    graphState = rolledBackState;
    Console.WriteLine($"Transaction rolled back due to error: {ex.Message}");
}

// 如果需要，從 checkpoint 還原
if (needToRestore)
{
    var restoredState = StateHelpers.RestoreCheckpoint(graphState, checkpointId);
    graphState = restoredState;
    Console.WriteLine("State restored from checkpoint");
}
```

## 效能考量

* **Serialization Caching**：對相同 state 的重複 serialization 使用 `useCache: true`
* **Compression**：為大型 state 啟用 compression 以減少儲存和轉移成本
* **自適應 Compression**：系統會根據觀察到的優勢自動調整 compression 閾值
* **驗證**：在生產環境中謹慎使用驗證；考慮快取驗證結果
* **Metadata**：保持 metadata 輕量級以避免 serialization 開銷

## 執行緒安全性

* **GraphState**：執行緒安全的並行讀取；並行寫入需要外部同步
* **StateHelpers**：靜態方法是執行緒安全的；對共用 state 使用適當的鎖定
* **Serialization**：快取的 serialization 是執行緒安全的，具有內部鎖定

## 錯誤處理

* **驗證**：在 deserialization 後始終驗證 state 完整性
* **Checksums**：使用 checksums 偵測 state 損壞
* **Transactions**：實作適當的錯誤處理和回滾邏輯
* **遷移**：使用遷移邏輯優雅地處理版本不相容性

## 另請參閱

* [State Management Guide](../concepts/state.md)
* [Checkpointing Guide](../how-to/checkpointing.md)
* [State Quickstart](../state-quickstart.md)
* [State Tutorial](../state-tutorial.md)
* [ConditionalEdge](conditional-edge.md)
* [StateMergeConfiguration](state-merge-configuration.md)
* [StateMergeConflictPolicy](state-merge-conflict-policy.md)
