# 擴充與選項

SemanticKernel.Graph 函式庫提供了一套全面的擴充方法和設定選項，能夠與現有的 Semantic Kernel 實例無縫整合。本參考涵蓋了核心擴充類別、設定選項，以及用於設定圖形功能的建構器模式。

## 概述

擴充與選項提供了一種流暢的、以設定為驅動的方式來在 Semantic Kernel 應用程式中啟用圖形功能。該系統提供了多個層級的設定粒度，從簡單的一行設定到用於生產環境的高級、細調設定。

## 核心概念

**KernelArgumentsExtensions**：擴充方法，將圖形特定的功能新增至 `KernelArguments`，包括狀態管理、執行追蹤和偵錯功能。

**GraphOptions**：核心圖形功能的設定選項，包括日誌記錄、指標、驗證和執行邊界。

**KernelBuilderExtensions**：`IKernelBuilder` 的擴充方法，能夠透過流暢設定 API 進行零設定的圖形設定。

## 核心擴充類別

### KernelArgumentsExtensions

擴充方法，透過圖形特定的功能（狀態管理、執行追蹤和偵錯）增強 `KernelArguments`。

#### 圖形狀態方法

```csharp
// 將 KernelArguments 轉換為 GraphState 實例（快取在引數上）
public static GraphState ToGraphState(this KernelArguments arguments)

// 從 KernelArguments 取得或建立 GraphState
public static GraphState GetOrCreateGraphState(this KernelArguments arguments)

// 檢查 KernelArguments 是否已包含 GraphState
public static bool HasGraphState(this KernelArguments arguments)

// 在 KernelArguments 上設定特定的 GraphState 實例
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

// 將 KernelArguments 轉換為 GraphState 實例（快取在引數上）
var graphState = arguments.ToGraphState();

// 安全地檢查並讀取 GraphState
if (arguments.HasGraphState())
{
    var existingState = arguments.GetOrCreateGraphState();
    Console.WriteLine($"狀態包含參數：{string.Join(", ", existingState.GetParameterNames())}");
}
```

#### 執行追蹤方法

```csharp
// 啟動新的執行步驟並傳回建立的 ExecutionStep
public static ExecutionStep StartExecutionStep(this KernelArguments arguments, string nodeId, string functionName)

// 完成目前的執行步驟（可選結果）
public static void CompleteExecutionStep(this KernelArguments arguments, object? result = null)

// 設定執行內容（任何物件；使用 GetExecutionContext<T> 以型別化的方式讀取）
public static void SetExecutionContext(this KernelArguments arguments, object context)

// 取得特定型別 T 的執行內容
public static T? GetExecutionContext<T>(this KernelArguments arguments)

// 設定資源治理使用的執行優先順序提示
public static void SetExecutionPriority(this KernelArguments arguments, ExecutionPriority priority)

// 取得執行優先順序提示（如果已設定）
public static ExecutionPriority? GetExecutionPriority(this KernelArguments arguments)
```

**範例：**
```csharp
// 開始追蹤特定節點/函式的執行步驟
var step = arguments.StartExecutionStep("process_input", "ProcessUserInput");

// ... 在此處執行工作（同步或非同步）...

// 將步驟標記為已完成並包含可選結果
arguments.CompleteExecutionStep(result: new { status = "processed" });

// 設定資源治理的優先順序提示
arguments.SetExecutionPriority(ExecutionPriority.High);

// 如果先前已設定，則檢索執行內容
var context = arguments.GetExecutionContext<GraphExecutionContext>();
if (context is not null)
{
    Console.WriteLine($"執行 ID：{context.ExecutionId}");
}
```

#### 執行 ID 管理

```csharp
// 設定要由執行內容和裝飾器使用的明確執行識別碼
public static void SetExecutionId(this KernelArguments arguments, string executionId)

// 取得先前在引數上設定的明確執行識別碼（未設定時為 null）
public static string? GetExplicitExecutionId(this KernelArguments arguments)

// 確保存在穩定的執行識別碼；提供種子時從種子建立決定性 ID
public static string EnsureStableExecutionId(this KernelArguments arguments, int? seed = null)
```

**範例：**
```csharp
// 確保存在穩定的執行識別碼以用於關聯日誌/追蹤
var executionId = arguments.EnsureStableExecutionId();
Console.WriteLine($"執行 ID：{executionId}");

// 用於測試的決定性 ID
var seededId = arguments.EnsureStableExecutionId(seed: 42);
Console.WriteLine($"決定性執行 ID：{seededId}");

// 如果需要，用自訂 ID 覆寫
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

// 檢查是否已啟用偵錯
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
    Console.WriteLine("已啟用偵錯模式");
    
    // 設定偵錯工作階段
    var debugSession = new DebugSession("debug-123");
    arguments.SetDebugSession(debugSession);
}

// 清除偵錯資訊
arguments.ClearDebugInfo();
```

#### 公用程式方法

```csharp
// 建立 KernelArguments 的深層複本，同時保留存在的 GraphState
public static KernelArguments Clone(this KernelArguments arguments)

// 設定預估節點成本權重（>= 1.0），用作資源治理的提示
public static void SetEstimatedNodeCostWeight(this KernelArguments arguments, double costWeight)

// 取得預估節點成本權重，或在未設定時傳回 null
public static double? GetEstimatedNodeCostWeight(this KernelArguments arguments)
```

**範例：**
```csharp
// 複製引數以在執行平行分支時避免共享變異
var clonedArgs = arguments.Clone();

// 對執行器設定成本權重提示以影響資源治理
arguments.SetEstimatedNodeCostWeight(2.5);

// 安全地擷取成本權重
var weight = arguments.GetEstimatedNodeCostWeight();
Console.WriteLine($"節點成本權重：{weight}");
```

### GraphOptions

控制日誌記錄、指標、驗證和執行邊界的核心圖形功能的設定選項。

#### 核心屬性

```csharp
public sealed class GraphOptions
{
    // 啟用/停用日誌記錄
    public bool EnableLogging { get; set; } = true;
    
    // 啟用/停用指標收集
    public bool EnableMetrics { get; set; } = true;
    
    // 最大執行步驟
    public int MaxExecutionSteps { get; set; } = 1000;
    
    // 驗證圖形完整性
    public bool ValidateGraphIntegrity { get; set; } = true;
    
    // 執行逾時
    public TimeSpan ExecutionTimeout { get; set; } = TimeSpan.FromMinutes(10);
    
    // 啟用計劃編譯
    public bool EnablePlanCompilation { get; set; } = true;
    
    // 日誌記錄設定
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

// 設定日誌記錄選項
options.Logging.MinimumLevel = LogLevel.Debug;
options.Logging.EnableStructuredLogging = true;
options.Logging.EnableCorrelationIds = true;

// 設定互通性選項
options.Interop.EnableImporters = true;
options.Interop.EnableExporters = true;
options.Interop.EnablePythonBridge = false;
```

#### GraphLoggingOptions

圖形執行的進階日誌記錄設定，具有對行為和結構化資料的細粒度控制。

```csharp
public sealed class GraphLoggingOptions
{
    // 最小日誌層級
    public LogLevel MinimumLevel { get; set; } = LogLevel.Information;
    
    // 啟用結構化日誌記錄
    public bool EnableStructuredLogging { get; set; } = true;
    
    // 啟用關聯 ID
    public bool EnableCorrelationIds { get; set; } = true;
    
    // 包含執行計時
    public bool IncludeTimings { get; set; } = true;
    
    // 包含節點中繼資料
    public bool IncludeNodeMetadata { get; set; } = true;
    
    // 在偵錯日誌中包含狀態快照
    public bool IncludeStateSnapshots { get; set; } = false;
    
    // 日誌中的最大狀態資料大小
    public int MaxStateDataSize { get; set; } = 2000;
    
    // 分類特定設定
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

// 設定特定節點分類
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

用於跨生態系統整合和外部工具支援的互通性選項。

```csharp
public sealed class GraphInteropOptions
{
    // 啟用外部格式的匯入器
    public bool EnableImporters { get; set; } = true;
    
    // 啟用行業格式的匯出器
    public bool EnableExporters { get; set; } = true;
    
    // 啟用 Python 執行橋接
    public bool EnablePythonBridge { get; set; } = false;
    
    // 啟用與外部引擎的聯合
    public bool EnableFederation { get; set; } = true;
    
    // Python 可執行檔路徑
    public string? PythonExecutablePath { get; set; }
    
    // 聯合基本位址
    public string? FederationBaseAddress { get; set; }
    
    // 重放/匯出的安全性選項
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

`IKernelBuilder` 的擴充方法，能夠透過流暢設定 API 進行零設定的圖形設定。

#### 基本圖形支援

```csharp
// 使用預設設定新增圖形支援
public static IKernelBuilder AddGraphSupport(this IKernelBuilder builder)

// 使用自訂設定新增圖形支援
public static IKernelBuilder AddGraphSupport(this IKernelBuilder builder, 
    Action<GraphOptions> configure)

// 使用日誌記錄設定新增圖形支援
public static IKernelBuilder AddGraphSupportWithLogging(this IKernelBuilder builder, 
    Action<GraphLoggingOptions> configure)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 基本設定
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

// 使用日誌記錄設定
builder.AddGraphSupportWithLogging(logging =>
{
    logging.MinimumLevel = LogLevel.Information;
    logging.EnableCorrelationIds = true;
    logging.IncludeTimings = true;
});
```

#### 環境特定設定

```csharp
// 偵錯設定
public static IKernelBuilder AddGraphSupportForDebugging(this IKernelBuilder builder)

// 生產環境設定
public static IKernelBuilder AddGraphSupportForProduction(this IKernelBuilder builder)

// 高效能設定
public static IKernelBuilder AddGraphSupportForPerformance(this IKernelBuilder builder)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 環境特定設定
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

#### 完整圖形支援

```csharp
// 使用所有整合新增完整的圖形支援
public static IKernelBuilder AddCompleteGraphSupport(this IKernelBuilder builder, 
    Action<CompleteGraphOptions>? configure = null)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 具有所有功能的完整設定
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

#### 模組特定擴充

```csharp
// 新增檢查點支援
public static IKernelBuilder AddCheckpointSupport(this IKernelBuilder builder, 
    Action<CheckpointOptions> configure)

// 新增串流支援
public static IKernelBuilder AddGraphStreamingPool(this IKernelBuilder builder, 
    Action<StreamingOptions>? configure = null)

// 新增記憶體整合
public static IKernelBuilder AddGraphMemory(this IKernelBuilder builder, 
    Action<GraphMemoryOptions>? configure = null)

// 新增範本支援
public static IKernelBuilder AddGraphTemplates(this IKernelBuilder builder, 
    Action<GraphTemplateOptions>? configure = null)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 新增核心圖形支援
builder.AddGraphSupport();

// 新增檢查點
builder.AddCheckpointSupport(options =>
{
    options.EnableCompression = true;
    options.MaxCacheSize = 500;
    options.EnableAutoCleanup = true;
    options.AutoCleanupInterval = TimeSpan.FromHours(2);
});

// 新增串流
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

// 新增範本
builder.AddGraphTemplates(options =>
{
    options.EnableHandlebars = true;
    options.EnableCustomHelpers = true;
    options.TemplateCacheSize = 200;
});
```

#### 簡單圖形建立

```csharp
// 建立簡單順序圖形
public static IKernelBuilder AddSimpleSequentialGraph(this IKernelBuilder builder, 
    string graphName, params string[] functionNames)

// 從範本建立圖形
public static IKernelBuilder AddGraphFromTemplate(this IKernelBuilder builder, 
    string graphName, string templatePath, object? templateData = null)
```

**範例：**
```csharp
var builder = Kernel.CreateBuilder();

// 建立簡單順序圖形
builder.AddSimpleSequentialGraph("workflow", 
    "validate_input", 
    "process_data", 
    "generate_output");

// 從範本建立圖形
builder.AddGraphFromTemplate("chatbot", "templates/chatbot.json", new
{
    welcomeMessage = "Hello! How can I help you?",
    maxTurns = 10
});
```

## 子選項類別

### CheckpointOptions

檢查點行為和持久化的設定。

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
    
    // 包含狀態快照
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

### 基本設定模式

```csharp
var builder = Kernel.CreateBuilder();

// 新增基本圖形支援
builder.AddGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMetrics = true;
    options.MaxExecutionSteps = 1000;
    options.ExecutionTimeout = TimeSpan.FromMinutes(10);
});

var kernel = builder.Build();
```

### 生產環境設定模式

```csharp
var builder = Kernel.CreateBuilder();

// 生產環境優化設定
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

### 偵錯設定模式

```csharp
var builder = Kernel.CreateBuilder();

// 偵錯優化設定
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

// 具有所有功能的完整設定
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

* **日誌記錄**：在生產環境中停用詳細日誌記錄以提高效能
* **指標**：對高頻率操作使用採樣
* **檢查點**：在檢查點頻率與儲存成本之間取得平衡
* **串流**：根據記憶體限制設定緩衝區大小
* **範本**：對頻繁存取的範本使用快取

## 執行緒安全性

* **GraphOptions**：設定時執行緒安全；執行期間不可變
* **KernelArgumentsExtensions**：並行存取時執行緒安全
* **KernelBuilderExtensions**：建構器設定期間執行緒安全

## 錯誤處理

* **設定驗證**：選項在建構器設定期間進行驗證
* **正常降級**：如果遺失相依性，可選功能會正常失敗
* **環境偵測**：根據環境變數進行自動設定

## 另請參閱

* [圖形執行器](graph-executor.md)
* [圖形狀態](state-and-serialization.md)
* [串流執行](../concepts/streaming.md)
* [檢查點](../concepts/checkpointing.md)
* [記憶體整合](../concepts/memory.md)
* [範本引擎](../concepts/templates.md)
* [整合指南](../how-to/integration-and-extensions.md)
