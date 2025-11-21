# 擴展與選項

SemanticKernel.Graph 函式庫提供了一套完整的擴展方法和設定選項，能夠與現有的 Semantic Kernel 執行個體無縫整合。本參考文檔涵蓋了核心擴展類別、設定選項和用於設置 Graph 功能的構建程式模式。

## 概述

擴展與選項提供了一個流暢的、設定驅動的方法來啟用 Semantic Kernel 應用程式中的 Graph 功能。系統提供多個層級的設定粒度，從簡單的單行設置到用於生產環境的進階、細微調整的設定。

## 主要概念

**KernelArgumentsExtensions**: 擴展方法，將 Graph 特定功能新增至 `KernelArguments`，包括狀態管理、執行追蹤和偵錯功能。

**GraphOptions**: 核心 Graph 功能的設定選項，包括記錄、指標、驗證和執行邊界。

**KernelBuilderExtensions**: `IKernelBuilder` 的擴展方法，能夠使用流暢的設定 API 進行零設定 Graph 設置。

## 核心擴展類別

### KernelArgumentsExtensions

擴展方法，用狀態管理、執行追蹤和偵錯功能來增強 `KernelArguments` 的 Graph 特定功能。

#### Graph 狀態方法

```csharp
// 將 KernelArguments 轉換為 GraphState 執行個體（在引數上快取）
public static GraphState ToGraphState(this KernelArguments arguments)

// 從 KernelArguments 取得或建立 GraphState
public static GraphState GetOrCreateGraphState(this KernelArguments arguments)

// 檢查 KernelArguments 是否已包含 GraphState
public static bool HasGraphState(this KernelArguments arguments)

// 在 KernelArguments 上設定特定的 GraphState 執行個體
public static void SetGraphState(this KernelArguments arguments, GraphState graphState)
```

**範例：**
```csharp
// 準備包含範例資料的核心引數
var arguments = new KernelArguments
{
    ["input"] = "Hello World",
    ["user"] = "Alice"
};

// 將 KernelArguments 轉換為 GraphState 執行個體（在引數上快取）
var graphState = arguments.ToGraphState();

// 安全地檢查並讀取 GraphState
if (arguments.HasGraphState())
{
    var existingState = arguments.GetOrCreateGraphState();
    Console.WriteLine($"State contains parameters: {string.Join(", ", existingState.GetParameterNames())}");
}
```

#### 執行追蹤方法

```csharp
// 啟動新的執行步驟並傳回建立的 ExecutionStep
public static ExecutionStep StartExecutionStep(this KernelArguments arguments, string nodeId, string functionName)

// 完成目前的執行步驟（選用結果）
public static void CompleteExecutionStep(this KernelArguments arguments, object? result = null)

// 設定執行內容（任何物件；使用 GetExecutionContext<T> 來讀取型別）
public static void SetExecutionContext(this KernelArguments arguments, object context)

// 以特定型別 T 取得執行內容
public static T? GetExecutionContext<T>(this KernelArguments arguments)

// 設定執行優先順序提示，由資源管理使用
public static void SetExecutionPriority(this KernelArguments arguments, ExecutionPriority priority)

// 取得執行優先順序提示（如果已設定）
public static ExecutionPriority? GetExecutionPriority(this KernelArguments arguments)
```

**範例：**
```csharp
// 開始追蹤特定節點/函數的執行步驟
var step = arguments.StartExecutionStep("process_input", "ProcessUserInput");

// ... 在這裡執行工作（同步或非同步）...

// 將步驟標記為完成，並附帶選用的結果
arguments.CompleteExecutionStep(result: new { status = "processed" });

// 設定由執行程式用於資源管理的優先順序提示
arguments.SetExecutionPriority(ExecutionPriority.High);

// 擷取執行內容（如果之前已設定）
var context = arguments.GetExecutionContext<GraphExecutionContext>();
if (context is not null)
{
    Console.WriteLine($"Execution ID: {context.ExecutionId}");
}
```

#### 執行 ID 管理

```csharp
// 設定由執行內容和裝飾器使用的明確執行識別碼
public static void SetExecutionId(this KernelArguments arguments, string executionId)

// 取得先前在引數上設定的明確執行識別碼（未設定時為 null）
public static string? GetExplicitExecutionId(this KernelArguments arguments)

// 確保存在穩定的執行識別碼；提供種子時從種子建立決定性 ID
public static string EnsureStableExecutionId(this KernelArguments arguments, int? seed = null)
```

**範例：**
```csharp
// 確保存在穩定的執行識別碼以關聯日誌/追蹤
var executionId = arguments.EnsureStableExecutionId();
Console.WriteLine($"Execution ID: {executionId}");

// 用於測試的決定性 ID
var seededId = arguments.EnsureStableExecutionId(seed: 42);
Console.WriteLine($"Deterministic execution ID: {seededId}");

// 在必要時使用自訂 ID 覆寫
arguments.SetExecutionId("custom-execution-123");
```

#### 偵錯與檢查方法

```csharp
// 設定偵錯工作階段
public static void SetDebugSession(this KernelArguments arguments, IDebugSession debugSession)

// 取得偵錯工作階段
public static IDebugSession? GetDebugSession(this KernelArguments arguments)

// 設定偵錯模式
public static void SetDebugMode(this KernelArguments arguments, DebugExecutionMode mode)

// 取得偵錯模式
public static DebugExecutionMode GetDebugMode(this KernelArguments arguments)

// 檢查是否啟用偵錯
public static bool IsDebugEnabled(this KernelArguments arguments)

// 清除偵錯資訊
public static void ClearDebugInfo(this KernelArguments arguments)
```

**範例：**
```csharp
// 啟用偵錯模式
arguments.SetDebugMode(DebugExecutionMode.Verbose);

// 檢查偵錯狀態
if (arguments.IsDebugEnabled())
{
    Console.WriteLine("Debug mode is enabled");
    
    // 設定偵錯工作階段
    var debugSession = new DebugSession("debug-123");
    arguments.SetDebugSession(debugSession);
}

// 清除偵錯資訊
arguments.ClearDebugInfo();
```

#### 公用程式方法

```csharp
// 建立 KernelArguments 的深層副本，同時保留存在的 GraphState
public static KernelArguments Clone(this KernelArguments arguments)

// 設定估計的節點成本權重 (>= 1.0)，作為資源管理的提示
public static void SetEstimatedNodeCostWeight(this KernelArguments arguments, double costWeight)

// 取得估計的節點成本權重，未設定時為 null
public static double? GetEstimatedNodeCostWeight(this KernelArguments arguments)
```

**範例：**
```csharp
// 在執行平行分支時複製引數，以避免共用的變異
var clonedArgs = arguments.Clone();

// 設定成本權重提示給執行程式，以影響資源管理
arguments.SetEstimatedNodeCostWeight(2.5);

// 安全地擷取成本權重
var weight = arguments.GetEstimatedNodeCostWeight();
Console.WriteLine($"Node cost weight: {weight}");
```

### GraphOptions

控制記錄、指標、驗證和執行邊界的核心 Graph 功能的設定選項。

#### 核心屬性

```csharp
public sealed class GraphOptions
{
    // 啟用/停用記錄
    public bool EnableLogging { get; set; } = true;
    
    // 啟用/停用指標收集
    public bool EnableMetrics { get; set; } = true;
    
    // 最大執行步數
    public int MaxExecutionSteps { get; set; } = 1000;
    
    // 驗證 Graph 完整性
    public bool ValidateGraphIntegrity { get; set; } = true;
    
    // 執行逾時
    public TimeSpan ExecutionTimeout { get; set; } = TimeSpan.FromMinutes(10);
    
    // 啟用計畫編譯
    public bool EnablePlanCompilation { get; set; } = true;
    
    // 記錄設定
    public GraphLoggingOptions Logging { get; set; } = new();
    
    // 互通性選項
    public GraphInteropOptions Interop { get; set; } = new();
}
```

**範例：**
```csharp
var options = new GraphOptions
{
    EnableLogging = true,
    EnableMetrics = true,
    MaxExecutionSteps = 500,
    ValidateGraphIntegrity = true,
    ExecutionTimeout = TimeSpan.FromMinutes(5),
    EnablePlanCompilation = true
};

// 設定記錄選項
options.Logging.MinimumLevel = LogLevel.Debug;
options.Logging.EnableStructuredLogging = true;
options.Logging.EnableCorrelationIds = true;

// 設定互通性選項
options.Interop.EnableImporters = true;
options.Interop.EnableExporters = true;
options.Interop.EnablePythonBridge = false;
```

#### GraphLoggingOptions

對 Graph 執行進行進階記錄設定，並對行為和結構化資料進行細緻控制。

```csharp
public sealed class GraphLoggingOptions
{
    // 最小記錄層級
    public LogLevel MinimumLevel { get; set; } = LogLevel.Information;
    
    // 啟用結構化記錄
    public bool EnableStructuredLogging { get; set; } = true;
    
    // 啟用相互關聯 ID
    public bool EnableCorrelationIds { get; set; } = true;
    
    // 包括執行計時
    public bool IncludeTimings { get; set; } = true;
    
    // 包括節點中繼資料
    public bool IncludeNodeMetadata { get; set; } = true;
    
    // 在偵錯日誌中包括狀態快照
    public bool IncludeStateSnapshots { get; set; } = false;
    
    // 日誌中的最大狀態資料大小
    public int MaxStateDataSize { get; set; } = 2000;
    
    // 類別特定的設定
    public Dictionary<string, NodeLoggingOptions> CategoryConfigurations { get; set; } = new();
}
```

**範例：**
```csharp
var loggingOptions = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Debug,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    IncludeTimings = true,
    IncludeNodeMetadata = true,
    MaxStateDataSize = 1000
};

// 設定特定的節點類別
loggingOptions.CategoryConfigurations["ai_nodes"] = new NodeLoggingOptions
{
    LogInputs = true,
    LogOutputs = true,
    LogTiming = true,
    LogStateChanges = true,
    MaxDataSize = 500
};

loggingOptions.CategoryConfigurations["utility_nodes"] = new NodeLoggingOptions
{
    LogInputs = false,
    LogOutputs = false,
    LogTiming = true,
    LogStateChanges = false,
    MaxDataSize = 100
};
```

#### GraphInteropOptions

用於跨生態系統整合和外部工具支持的互通性選項。

```csharp
public sealed class GraphInteropOptions
{
    // 啟用外部格式的匯入器
    public bool EnableImporters { get; set; } = true;
    
    // 啟用業界格式的匯出器
    public bool EnableExporters { get; set; } = true;
    
    // 啟用 Python 執行橋接
    public bool EnablePythonBridge { get; set; } = false;
    
    // 啟用與外部引擎的聯合
    public bool EnableFederation { get; set; } = true;
    
    // Python 可執行檔路徑
    public string? PythonExecutablePath { get; set; }
    
    // 聯合基位址
    public string? FederationBaseAddress { get; set; }
    
    // 重新執行/匯出的安全性選項
    public GraphSecurityOptions Security { get; set; } = new();
}
```

**範例：**
```csharp
var interopOptions = new GraphInteropOptions
{
    EnableImporters = true,
    EnableExporters = true,
    EnablePythonBridge = true,
    EnableFederation = false,
    PythonExecutablePath = "/usr/bin/python3"
};

// 設定安全性選項
interopOptions.Security.EnableHashing = true;
interopOptions.Security.EnableEncryption = false;
interopOptions.Security.HashAlgorithm = "SHA256";
```

### KernelBuilderExtensions

`IKernelBuilder` 的擴展方法，能夠使用流暢的設定 API 進行零設定 Graph 設置。

#### 基本 Graph 支持

```csharp
// 使用預設設定新增 Graph 支持
public static IKernelBuilder AddGraphSupport(this IKernelBuilder builder)

// 使用自訂設定新增 Graph 支持
public static IKernelBuilder AddGraphSupport(this IKernelBuilder builder, 
    Action<GraphOptions> configure)

// 使用記錄設定新增 Graph 支持
public static IKernelBuilder AddGraphSupportWithLogging(this IKernelBuilder builder, 
    Action<GraphLoggingOptions> configure)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 基本設置
builder.AddGraphSupport();

// 自訂設定
builder.AddGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMetrics = true;
    options.MaxExecutionSteps = 500;
    options.ExecutionTimeout = TimeSpan.FromMinutes(5);
    
    options.Logging.MinimumLevel = LogLevel.Debug;
    options.Logging.EnableStructuredLogging = true;
    
    options.Interop.EnableImporters = true;
    options.Interop.EnableExporters = true;
});

// 使用記錄設定
builder.AddGraphSupportWithLogging(logging =>
{
    logging.MinimumLevel = LogLevel.Information;
    logging.EnableCorrelationIds = true;
    logging.IncludeTimings = true;
});
```

#### 環境特定的設定

```csharp
// 偵錯設定
public static IKernelBuilder AddGraphSupportForDebugging(this IKernelBuilder builder)

// 生產設定
public static IKernelBuilder AddGraphSupportForProduction(this IKernelBuilder builder)

// 高效能設定
public static IKernelBuilder AddGraphSupportForPerformance(this IKernelBuilder builder)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 環境特定的設置
if (environment.IsDevelopment())
{
    builder.AddGraphSupportForDebugging();
}
else if (environment.IsProduction())
{
    builder.AddGraphSupportForProduction();
}
else
{
    builder.AddGraphSupportForPerformance();
}
```

#### 完整 Graph 支持

```csharp
// 新增完整的 Graph 支持，包括所有整合
public static IKernelBuilder AddCompleteGraphSupport(this IKernelBuilder builder, 
    Action<CompleteGraphOptions>? configure = null)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 使用所有功能的完整設置
builder.AddCompleteGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMemory = true;
    options.EnableTemplates = true;
    options.EnableVectorSearch = true;
    options.EnableSemanticSearch = true;
    options.EnableCustomHelpers = true;
    options.EnableMetrics = true;
    options.MaxExecutionSteps = 1000;
});
```

#### 模組特定的擴展

```csharp
// 新增檢查點支持
public static IKernelBuilder AddCheckpointSupport(this IKernelBuilder builder, 
    Action<CheckpointOptions> configure)

// 新增串流支持
public static IKernelBuilder AddGraphStreamingPool(this IKernelBuilder builder, 
    Action<StreamingOptions>? configure = null)

// 新增記憶體整合
public static IKernelBuilder AddGraphMemory(this IKernelBuilder builder, 
    Action<GraphMemoryOptions>? configure = null)

// 新增範本支持
public static IKernelBuilder AddGraphTemplates(this IKernelBuilder builder, 
    Action<GraphTemplateOptions>? configure = null)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 新增核心 Graph 支持
builder.AddGraphSupport();

// 新增檢查點支持
builder.AddCheckpointSupport(options =>
{
    options.EnableCompression = true;
    options.MaxCacheSize = 500;
    options.EnableAutoCleanup = true;
    options.AutoCleanupInterval = TimeSpan.FromHours(2);
});

// 新增串流支持
builder.AddGraphStreamingPool(options =>
{
    options.BufferSize = 100;
    options.MaxBufferSize = 1000;
    options.EnableAutoReconnect = true;
    options.MaxReconnectAttempts = 3;
});

// 新增記憶體整合
builder.AddGraphMemory(options =>
{
    options.EnableVectorSearch = true;
    options.EnableSemanticSearch = true;
    options.DefaultCollectionName = "my-graph-memory";
    options.SimilarityThreshold = 0.8;
});

// 新增範本支持
builder.AddGraphTemplates(options =>
{
    options.EnableHandlebars = true;
    options.EnableCustomHelpers = true;
    options.TemplateCacheSize = 200;
});
```

#### 簡單 Graph 建立

```csharp
// 建立簡單的循序 Graph
public static IKernelBuilder AddSimpleSequentialGraph(this IKernelBuilder builder, 
    string graphName, params string[] functionNames)

// 從範本建立 Graph
public static IKernelBuilder AddGraphFromTemplate(this IKernelBuilder builder, 
    string graphName, string templatePath, object? templateData = null)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 建立簡單的循序 Graph
builder.AddSimpleSequentialGraph("workflow", 
    "validate_input", 
    "process_data", 
    "generate_output");

// 從範本建立 Graph
builder.AddGraphFromTemplate("chatbot", "templates/chatbot.json", new
{
    welcomeMessage = "Hello! How can I help you?",
    maxTurns = 10
});
```

## 子選項類別

### CheckpointOptions

檢查點行為和持續性的設定。

```csharp
public sealed class CheckpointOptions
{
    // 啟用壓縮
    public bool EnableCompression { get; set; } = true;
    
    // 最大快取大小
    public int MaxCacheSize { get; set; } = 1000;
    
    // 預設保留原則
    public CheckpointRetentionPolicy DefaultRetentionPolicy { get; set; } = new();
    
    // 啟用自動清理
    public bool EnableAutoCleanup { get; set; } = true;
    
    // 自動清理間隔
    public TimeSpan AutoCleanupInterval { get; set; } = TimeSpan.FromHours(1);
    
    // 啟用分散式備份
    public bool EnableDistributedBackup { get; set; } = false;
    
    // 預設備份選項
    public CheckpointBackupOptions DefaultBackupOptions { get; set; } = new();
}
```

### StreamingOptions

串流執行和事件處理的設定。

```csharp
public sealed class StreamingOptions
{
    // 緩衝區大小
    public int BufferSize { get; set; } = 100;
    
    // 最大緩衝區大小
    public int MaxBufferSize { get; set; } = 1000;
    
    // 啟用自動重新連線
    public bool EnableAutoReconnect { get; set; } = true;
    
    // 最大重新連線嘗試次數
    public int MaxReconnectAttempts { get; set; } = 3;
    
    // 初始重新連線延遲
    public TimeSpan InitialReconnectDelay { get; set; } = TimeSpan.FromSeconds(1);
    
    // 最大重新連線延遲
    public TimeSpan MaxReconnectDelay { get; set; } = TimeSpan.FromSeconds(30);
    
    // 包括狀態快照
    public bool IncludeStateSnapshots { get; set; } = false;
    
    // 要發出的事件類型
    public GraphExecutionEventType[]? EventTypesToEmit { get; set; }
}
```

### GraphMemoryOptions

記憶體整合和向量搜尋的設定。

```csharp
public sealed class GraphMemoryOptions
{
    // 啟用向量搜尋
    public bool EnableVectorSearch { get; set; } = true;
    
    // 啟用語義搜尋
    public bool EnableSemanticSearch { get; set; } = true;
    
    // 預設集合名稱
    public string DefaultCollectionName { get; set; } = "graph-memory";
    
    // 相似度閾值
    public double SimilarityThreshold { get; set; } = 0.7;
}
```

### GraphTemplateOptions

範本引擎和自訂協助程式的設定。

```csharp
public sealed class GraphTemplateOptions
{
    // 啟用 Handlebars 範本
    public bool EnableHandlebars { get; set; } = true;
    
    // 啟用自訂範本協助程式
    public bool EnableCustomHelpers { get; set; } = true;
    
    // 範本快取大小
    public int TemplateCacheSize { get; set; } = 100;
}
```

## 使用模式

### 基本設置模式

```csharp
var builder = Kernel.CreateBuilder();

// 新增基本 Graph 支持
builder.AddGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMetrics = true;
    options.MaxExecutionSteps = 1000;
    options.ExecutionTimeout = TimeSpan.FromMinutes(10);
});

var kernel = builder.Build();
```

### 生產設置模式

```csharp
var builder = Kernel.CreateBuilder();

// 生產最佳化設定
builder.AddGraphSupportForProduction()
    .AddCheckpointSupport(options =>
    {
        options.EnableCompression = true;
        options.MaxCacheSize = 2000;
        options.EnableAutoCleanup = true;
    })
    .AddGraphStreamingPool(options =>
    {
        options.BufferSize = 500;
        options.MaxBufferSize = 5000;
        options.EnableAutoReconnect = true;
    });

var kernel = builder.Build();
```

### 偵錯設置模式

```csharp
var builder = Kernel.CreateBuilder();

// 偵錯最佳化設定
builder.AddGraphSupportForDebugging()
    .AddGraphStreamingPool(options =>
    {
        options.IncludeStateSnapshots = true;
        options.EventTypesToEmit = new[]
        {
            GraphExecutionEventType.ExecutionStarted,
            GraphExecutionEventType.NodeStarted,
            GraphExecutionEventType.NodeCompleted,
            GraphExecutionEventType.ExecutionCompleted
        };
    });

var kernel = builder.Build();
```

### 完整整合模式

```csharp
var builder = Kernel.CreateBuilder();

// 使用所有功能的完整設置
builder.AddCompleteGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMemory = true;
    options.EnableTemplates = true;
    options.EnableVectorSearch = true;
    options.EnableSemanticSearch = true;
    options.EnableCustomHelpers = true;
    options.EnableMetrics = true;
    options.MaxExecutionSteps = 2000;
});

var kernel = builder.Build();
```

## 效能考量

* **記錄**: 在生產環境中停用詳細記錄以改善效能
* **指標**: 針對高頻率操作使用取樣
* **檢查點**: 在檢查點頻率與儲存成本之間取得平衡
* **串流**: 根據記憶體限制設定緩衝區大小
* **範本**: 針對經常存取的範本使用快取

## 執行緒安全

* **GraphOptions**: 設定時執行緒安全；執行期間不可變
* **KernelArgumentsExtensions**: 並行存取時執行緒安全
* **KernelBuilderExtensions**: 構建器設定期間執行緒安全

## 錯誤處理

* **設定驗證**: 在構建器設定期間驗證選項
* **順利降級**: 如果遺漏相依性，選用功能會順利失敗
* **環境偵測**: 根據環境變數自動設定

## 另請參閱

* [Graph Executor](graph-executor.md)
* [Graph State](state-and-serialization.md)
* [Streaming Execution](../concepts/streaming.md)
* [Checkpointing](../concepts/checkpointing.md)
* [Memory Integration](../concepts/memory.md)
* [Template Engine](../concepts/templates.md)
* [Integration Guide](../how-to/integration-and-extensions.md)
