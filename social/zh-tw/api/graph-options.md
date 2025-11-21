# Graph 選項和設定

SemanticKernel.Graph 提供了一套全面的設定系統，包含不同子系統的模組化選項。本參考涵蓋完整的選項階層，包括核心選項、特定模組設定和執行期間的不變性保證。

## GraphOptions

核心功能的主要設定類別，控制日誌、指標、驗證和執行邊界。

### Constructor

```csharp
public sealed class GraphOptions
{
    // 預設建構子，使用合理的預設值
    public GraphOptions()
}
```

### Core Properties

```csharp
public sealed class GraphOptions
{
    /// <summary>
    /// 取得或設定是否針對 Graph 執行啟用日誌。
    /// </summary>
    public bool EnableLogging { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用指標收集。
    /// </summary>
    public bool EnableMetrics { get; set; } = true;

    /// <summary>
    /// 取得或設定終止前的最大執行步驟數。
    /// </summary>
    public int MaxExecutionSteps { get; set; } = 1000;

    /// <summary>
    /// 取得或設定是否在執行前驗證 Graph 完整性。
    /// </summary>
    public bool ValidateGraphIntegrity { get; set; } = true;

    /// <summary>
    /// 取得或設定執行逾時。
    /// </summary>
    public TimeSpan ExecutionTimeout { get; set; } = TimeSpan.FromMinutes(10);

    /// <summary>
    /// 依 Graph 簽章啟用編譯和結構執行計畫的快取。
    /// </summary>
    public bool EnablePlanCompilation { get; set; } = true;

    /// <summary>
    /// 取得或設定不同類別和 Node 的日誌設定。
    /// </summary>
    public GraphLoggingOptions Logging { get; set; } = new();

    /// <summary>
    /// 取得或設定互通性相關的選項 (匯入/匯出、橋接、聯盟)。
    /// </summary>
    public GraphInteropOptions Interop { get; set; } = new();
}
```

### 使用範例

```csharp
// 建議透過 kernel 建構器註冊 GraphOptions，
// 以便讓 DI 容器將選項公開給執行內容和其他服務。
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport(opts =>
    {
        opts.EnableLogging = true;
        opts.EnableMetrics = true;
        opts.MaxExecutionSteps = 500;
        opts.ValidateGraphIntegrity = true;
        opts.ExecutionTimeout = TimeSpan.FromMinutes(5);
        opts.EnablePlanCompilation = true;

        // 設定日誌子選項
        opts.Logging.MinimumLevel = LogLevel.Debug;
        opts.Logging.EnableStructuredLogging = true;
        opts.Logging.EnableCorrelationIds = true;

        // 設定互通性
        opts.Interop.EnableImporters = true;
        opts.Interop.EnableExporters = true;
        opts.Interop.EnablePythonBridge = false;
    })
    .Build();

// 執行開始時，執行時期會透過 GraphExecutionOptions.From(graphOptions)
// 取得即時 GraphOptions 的快照，以保證執行期間的不變性。
```

## Module Activation Options

### GraphModuleActivationOptions

透過相依性注入有條件地啟用選用 Graph 模組的設定旗標。

```csharp
public sealed class GraphModuleActivationOptions
{
    /// <summary>
    /// 啟用串流元件 (事件串流連線池、重新連線管理員)。
    /// </summary>
    public bool EnableStreaming { get; set; }

    /// <summary>
    /// 啟用檢查點服務和工廠。
    /// </summary>
    public bool EnableCheckpointing { get; set; }

    /// <summary>
    /// 啟用復原整合。只有在啟用檢查點時才有效。
    /// </summary>
    public bool EnableRecovery { get; set; }

    /// <summary>
    /// 啟用人類參與迴圈 (預設註冊記憶體內存放區和 Web API 支援的通道)。
    /// </summary>
    public bool EnableHumanInTheLoop { get; set; }

    /// <summary>
    /// 啟用多代理程式基礎結構 (連線池和選項)。
    /// </summary>
    public bool EnableMultiAgent { get; set; }

    /// <summary>
    /// 套用所有旗標的環境變數覆寫。
    /// </summary>
    public void ApplyEnvironmentOverrides()
}
```

### 環境變數支援

模組啟用選項支援環境變數覆寫：

```csharp
// 環境變數可以覆寫這些設定：
// SKG_ENABLE_STREAMING=true
// SKG_ENABLE_CHECKPOINTING=true
// SKG_ENABLE_RECOVERY=true
// SKG_ENABLE_HITL=true
// SKG_ENABLE_MULTIAGENT=true

var options = new GraphModuleActivationOptions();
options.ApplyEnvironmentOverrides();

// 將模組新增至 kernel 建構器
var builder = Kernel.CreateBuilder()
    .AddGraphModules(options);
```

## 串流選項

### StreamingExecutionOptions

串流執行行為和事件處理的設定選項。

```csharp
public sealed class StreamingExecutionOptions
{
    /// <summary>
    /// 取得或設定事件串流的緩衝區大小。
    /// 預設值：100 個事件。
    /// </summary>
    public int BufferSize { get; set; } = 100;

    /// <summary>
    /// 取得或設定套用背壓前的最大緩衝區大小。
    /// 預設值：1000 個事件。
    /// </summary>
    public int MaxBufferSize { get; set; } = 1000;

    /// <summary>
    /// 取得或設定串流中斷時是否啟用自動重新連線。
    /// 預設值：true。
    /// </summary>
    public bool EnableAutoReconnect { get; set; } = true;

    /// <summary>
    /// 取得或設定重新連線嘗試的次數上限。
    /// 預設值：3 次嘗試。
    /// </summary>
    public int MaxReconnectAttempts { get; set; } = 3;

    /// <summary>
    /// 取得或設定初始重新連線延遲。
    /// 預設值：1 秒。
    /// </summary>
    public TimeSpan InitialReconnectDelay { get; set; } = TimeSpan.FromSeconds(1);

    /// <summary>
    /// 取得或設定重新連線延遲上限 (用於指數退避)。
    /// 預設值：30 秒。
    /// </summary>
    public TimeSpan MaxReconnectDelay { get; set; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// 取得或設定是否在事件中包含中繼狀態快照。
    /// 預設值：false (減少事件大小)。
    /// </summary>
    public bool IncludeStateSnapshots { get; set; } = false;

    /// <summary>
    /// 取得或設定要發出的事件類型。
    /// 預設值：所有事件類型。
    /// </summary>
    public GraphExecutionEventType[]? EventTypesToEmit { get; set; }

    /// <summary>
    /// 取得或設定要附加到串流的自訂事件處理常式。
    /// </summary>
    public List<IGraphExecutionEventHandler> CustomEventHandlers { get; set; } = new();
}
```

### 串流設定範例

```csharp
// 基本串流設定
var basicOptions = new StreamingExecutionOptions
{
    BufferSize = 50,
    MaxBufferSize = 500,
    EnableAutoReconnect = true
};

// 高效能設定
var performanceOptions = new StreamingExecutionOptions
{
    BufferSize = 1000,
    MaxBufferSize = 10000,
    IncludeStateSnapshots = false,
    EventTypesToEmit = new[] 
    { 
        GraphExecutionEventType.ExecutionStarted,
        GraphExecutionEventType.NodeCompleted,
        GraphExecutionEventType.ExecutionCompleted 
    }
};

// 監控設定
var monitoringOptions = new StreamingExecutionOptions
{
    BufferSize = 100,
    IncludeStateSnapshots = true,
    EventTypesToEmit = new[] 
    { 
        GraphExecutionEventType.NodeStarted,
        GraphExecutionEventType.NodeCompleted,
        GraphExecutionEventType.NodeFailed,
        GraphExecutionEventType.ExecutionCompleted 
    }
};
```

## 檢查點選項

### CheckpointingOptions

自動檢查點行為和狀態持久性的設定選項。

```csharp
public sealed class CheckpointingOptions
{
    /// <summary>
    /// 取得或設定建立檢查點的間隔 (已執行 Node 的數量)。
    /// </summary>
    public int CheckpointInterval { get; set; } = 10;

    /// <summary>
    /// 取得或設定建立檢查點的選用時間間隔。
    /// </summary>
    public TimeSpan? CheckpointTimeInterval { get; set; }

    /// <summary>
    /// 取得或設定執行開始前是否建立初始檢查點。
    /// </summary>
    public bool CreateInitialCheckpoint { get; set; } = true;

    /// <summary>
    /// 取得或設定執行完成後是否建立最終檢查點。
    /// </summary>
    public bool CreateFinalCheckpoint { get; set; } = true;

    /// <summary>
    /// 取得或設定發生錯誤時是否建立檢查點。
    /// </summary>
    public bool CreateErrorCheckpoints { get; set; } = true;

    /// <summary>
    /// 取得或設定應始終觸發檢查點建立的關鍵 Node ID 清單。
    /// </summary>
    public ISet<string> CriticalNodes { get; set; } = new HashSet<string>();

    /// <summary>
    /// 取得或設定是否啟用舊檢查點的自動清理。
    /// </summary>
    public bool EnableAutoCleanup { get; set; } = true;

    /// <summary>
    /// 取得或設定自動清理的保留原則。
    /// </summary>
    public CheckpointRetentionPolicy RetentionPolicy { get; set; } = new();

    /// <summary>
    /// 取得或設定是否啟用關鍵檢查點的分散式備份。
    /// </summary>
    public bool EnableDistributedBackup { get; set; } = false;

    /// <summary>
    /// 取得或設定分散式儲存的備份選項。
    /// </summary>
    public DistributedBackupOptions? DistributedBackupOptions { get; set; }
}
```

### 檢查點設定範例

```csharp
// 關鍵工作流程的頻繁檢查點
var criticalOptions = new CheckpointingOptions
{
    CheckpointInterval = 5,
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true,
    CriticalNodes = new HashSet<string> { "decision_node", "approval_node" },
    EnableAutoCleanup = true
};

// 時間為基礎的檢查點
var timeBasedOptions = new CheckpointingOptions
{
    CheckpointTimeInterval = TimeSpan.FromMinutes(5),
    CheckpointInterval = 100, // 回退到 Node 為基礎
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    EnableAutoCleanup = true
};

// 效能的最小檢查點
var minimalOptions = new CheckpointingOptions
{
    CheckpointInterval = 50,
    CreateInitialCheckpoint = false,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true,
    EnableAutoCleanup = true
};
```

## 復原選項

### RecoveryOptions

自動復原和重播功能的設定選項。

```csharp
public sealed class RecoveryOptions
{
    /// <summary>
    /// 取得或設定執行失敗時是否啟用自動復原。
    /// </summary>
    public bool EnableAutomaticRecovery { get; set; } = true;

    /// <summary>
    /// 取得或設定復原嘗試的次數上限。
    /// </summary>
    public int MaxRecoveryAttempts { get; set; } = 3;

    /// <summary>
    /// 取得或設定要使用的復原策略。
    /// </summary>
    public RecoveryStrategy Strategy { get; set; } = RecoveryStrategy.LastSuccessfulCheckpoint;

    /// <summary>
    /// 取得或設定是否啟用「如果...會怎樣」情境的條件重播。
    /// </summary>
    public bool EnableConditionalReplay { get; set; } = false;

    /// <summary>
    /// 取得或設定條件情境的最大重播深度。
    /// </summary>
    public int MaxReplayDepth { get; set; } = 10;

    /// <summary>
    /// 取得或設定復原期間是否保留執行歷史記錄。
    /// </summary>
    public bool PreserveExecutionHistory { get; set; } = true;

    /// <summary>
    /// 取得或設定復原逾時。
    /// </summary>
    public TimeSpan RecoveryTimeout { get; set; } = TimeSpan.FromMinutes(5);
}
```

### 復原設定範例

```csharp
// 生產系統的積極復原
var aggressiveRecovery = new RecoveryOptions
{
    EnableAutomaticRecovery = true,
    MaxRecoveryAttempts = 5,
    Strategy = RecoveryStrategy.LastSuccessfulCheckpoint,
    EnableConditionalReplay = false,
    PreserveExecutionHistory = true,
    RecoveryTimeout = TimeSpan.FromMinutes(10)
};

// 開發的保守復原
var conservativeRecovery = new RecoveryOptions
{
    EnableAutomaticRecovery = false,
    MaxRecoveryAttempts = 1,
    Strategy = RecoveryStrategy.Manual,
    EnableConditionalReplay = true,
    MaxReplayDepth = 5,
    PreserveExecutionHistory = false
};
```

## 人類參與迴圈 (HITL) 選項

### HumanApprovalOptions

人類核准 Node 和互動行為的設定選項。

```csharp
public sealed class HumanApprovalOptions
{
    /// <summary>
    /// 取得或設定核准要求的標題。
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// 取得或設定核准要求的說明。
    /// </summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// 取得或設定核准者的指示。
    /// </summary>
    public string Instructions { get; set; } = string.Empty;

    /// <summary>
    /// 取得或設定核准所需的欄位。
    /// </summary>
    public string[] RequiredFields { get; set; } = Array.Empty<string>();

    /// <summary>
    /// 取得或設定核准的選用欄位。
    /// </summary>
    public string[] OptionalFields { get; set; } = Array.Empty<string>();

    /// <summary>
    /// 取得或設定所需核准的數量。
    /// </summary>
    public int ApprovalThreshold { get; set; } = 1;

    /// <summary>
    /// 取得或設定拒絕數量以導致要求失敗。
    /// </summary>
    public int RejectionThreshold { get; set; } = 1;

    /// <summary>
    /// 取得或設定是否允許部分核准。
    /// </summary>
    public bool AllowPartialApproval { get; set; } = false;
}
```

### WebApiChannelOptions

Web 型人類互動通道的設定選項。

```csharp
public sealed class WebApiChannelOptions
{
    /// <summary>
    /// 取得或設定 Web API 的端點路徑。
    /// </summary>
    public string EndpointPath { get; set; } = "/api/approvals";

    /// <summary>
    /// 取得或設定 HTTP 作業的要求逾時。
    /// </summary>
    public TimeSpan RequestTimeout { get; set; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// 取得或設定失敗要求的重試原則。
    /// </summary>
    public RetryPolicy RetryPolicy { get; set; } = RetryPolicy.ExponentialBackoff(3, TimeSpan.FromSeconds(1));

    /// <summary>
    /// 取得或設定驗證設定。
    /// </summary>
    public IAuthenticationConfig? Authentication { get; set; }

    /// <summary>
    /// 取得或設定要包含在要求中的自訂標頭。
    /// </summary>
    public Dictionary<string, string> CustomHeaders { get; set; } = new();
}
```

### HITL 設定範例

```csharp
// 基本核准設定
var approvalOptions = new HumanApprovalOptions
{
    Title = "需要進行文件審查",
    Description = "請審查產生的文件的準確性",
    Instructions = "檢查文法、內容和格式",
    RequiredFields = new[] { "reviewer_name", "approval_notes" },
    ApprovalThreshold = 1,
    RejectionThreshold = 1,
    AllowPartialApproval = false
};

// Web API 通道設定
var webChannelOptions = new WebApiChannelOptions
{
    EndpointPath = "/api/approvals",
    RequestTimeout = TimeSpan.FromSeconds(30),
    RetryPolicy = RetryPolicy.ExponentialBackoff(3, TimeSpan.FromSeconds(1)),
    CustomHeaders = new Dictionary<string, string>
    {
        ["X-Client-Version"] = "1.0.0",
        ["X-Environment"] = "production"
    }
};
```

## 多代理程式選項

### MultiAgentOptions

多代理程式協調和工作流程管理的設定選項。

```csharp
public sealed class MultiAgentOptions
{
    /// <summary>
    /// 取得或設定併行代理程式的最大數量。
    /// </summary>
    public int MaxConcurrentAgents { get; set; } = 10;

    /// <summary>
    /// 取得或設定共享狀態管理選項。
    /// </summary>
    public SharedStateOptions SharedStateOptions { get; set; } = new();

    /// <summary>
    /// 取得或設定工作分配選項。
    /// </summary>
    public WorkDistributionOptions WorkDistributionOptions { get; set; } = new();

    /// <summary>
    /// 取得或設定結果彙總選項。
    /// </summary>
    public ResultAggregationOptions ResultAggregationOptions { get; set; } = new();

    /// <summary>
    /// 取得或設定健康狀況監控選項。
    /// </summary>
    public HealthMonitoringOptions HealthMonitoringOptions { get; set; } = new();

    /// <summary>
    /// 取得或設定協調逾時。
    /// </summary>
    public TimeSpan CoordinationTimeout { get; set; } = TimeSpan.FromMinutes(30);

    /// <summary>
    /// 取得或設定是否啟用已完成工作流程的自動清理。
    /// </summary>
    public bool EnableAutomaticCleanup { get; set; } = true;

    /// <summary>
    /// 取得或設定工作流程保留期間。
    /// </summary>
    public TimeSpan WorkflowRetentionPeriod { get; set; } = TimeSpan.FromHours(24);

    /// <summary>
    /// 取得或設定是否針對多代理程式工作流程啟用分散式追蹤 (ActivitySource)。
    /// </summary>
    public bool EnableDistributedTracing { get; set; } = true;
}
```

### AgentConnectionPoolOptions

用於管理代理程式連線池的設定選項。

```csharp
public sealed class AgentConnectionPoolOptions
{
    /// <summary>
    /// 取得或設定集區中的最大連線數。
    /// </summary>
    public int MaxConnections { get; set; } = 100;

    /// <summary>
    /// 取得或設定要維護的最小連線數。
    /// </summary>
    public int MinConnections { get; set; } = 10;

    /// <summary>
    /// 取得或設定連線逾時。
    /// </summary>
    public TimeSpan ConnectionTimeout { get; set; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// 取得或設定連線存留期。
    /// </summary>
    public TimeSpan ConnectionLifetime { get; set; } = TimeSpan.FromMinutes(5);

    /// <summary>
    /// 取得或設定是否啟用連線健康狀況檢查。
    /// </summary>
    public bool EnableHealthChecks { get; set; } = true;

    /// <summary>
    /// 取得或設定健康狀況檢查間隔。
    /// </summary>
    public TimeSpan HealthCheckInterval { get; set; } = TimeSpan.FromSeconds(30);
}
```

### 多代理程式設定範例

```csharp
// 高效能多代理程式設定
var highPerfOptions = new MultiAgentOptions
{
    MaxConcurrentAgents = 50,
    CoordinationTimeout = TimeSpan.FromMinutes(15),
    EnableAutomaticCleanup = true,
    WorkflowRetentionPeriod = TimeSpan.FromHours(12),
    EnableDistributedTracing = true
};

// 保守的多代理程式設定
var conservativeOptions = new MultiAgentOptions
{
    MaxConcurrentAgents = 5,
    CoordinationTimeout = TimeSpan.FromMinutes(60),
    EnableAutomaticCleanup = false,
    WorkflowRetentionPeriod = TimeSpan.FromDays(7),
    EnableDistributedTracing = false
};

// 連線池設定
var poolOptions = new AgentConnectionPoolOptions
{
    MaxConnections = 200,
    MinConnections = 20,
    ConnectionTimeout = TimeSpan.FromSeconds(15),
    ConnectionLifetime = TimeSpan.FromMinutes(10),
    EnableHealthChecks = true,
    HealthCheckInterval = TimeSpan.FromSeconds(15)
};
```

## 日誌選項

### GraphLoggingOptions

Graph 執行的進階日誌設定選項。

```csharp
public sealed class GraphLoggingOptions
{
    /// <summary>
    /// 取得或設定 Graph 執行的最小日誌層級。
    /// </summary>
    public LogLevel MinimumLevel { get; set; } = LogLevel.Information;

    /// <summary>
    /// 取得或設定是否啟用結構化日誌。
    /// </summary>
    public bool EnableStructuredLogging { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用關聯 ID。
    /// </summary>
    public bool EnableCorrelationIds { get; set; } = true;

    /// <summary>
    /// 取得或設定要記錄的狀態資料的最大大小。
    /// </summary>
    public int MaxStateDataSize { get; set; } = 2000;

    /// <summary>
    /// 取得或設定特定類別的日誌設定。
    /// 類別包括：「Graph」、「Node」、「Routing」、「Error」、「Performance」、「State」、「Validation」。
    /// </summary>
    public Dictionary<string, LogCategoryConfig> CategoryConfigs { get; set; } = new();

    /// <summary>
    /// 取得或設定 Node 特定的日誌設定。
    /// 索引鍵是 Node ID 或 Node 類型名稱。
    /// </summary>
    public Dictionary<string, NodeLoggingConfig> NodeConfigs { get; set; } = new();

    /// <summary>
    /// 取得或設定是否記錄敏感資料 (參數、狀態值)。
    /// 為 false 時，只會記錄參數名稱和計數，不會記錄值。
    /// </summary>
    public bool LogSensitiveData { get; set; } = false;

    /// <summary>
    /// 取得或設定敏感資料的清理原則。
    /// </summary>
    public SensitiveDataPolicy Sanitization { get; set; } = SensitiveDataPolicy.Default;

    /// <summary>
    /// 取得或設定此 Graph 實例的自訂關聯 ID 前置詞。
    /// </summary>
    public string? CorrelationIdPrefix { get; set; }

    /// <summary>
    /// 取得或設定日誌項目中時間戳記的格式。
    /// </summary>
    public string TimestampFormat { get; set; } = "yyyy-MM-dd HH:mm:ss.fff";
}
```

### 日誌設定範例

```csharp
// 開發的詳細日誌
var verboseLogging = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Debug,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    LogSensitiveData = true,
    MaxStateDataSize = 5000
};

// 具有清理功能的生產日誌
var productionLogging = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Information,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    LogSensitiveData = false,
    Sanitization = SensitiveDataPolicy.Strict,
    MaxStateDataSize = 1000
};

// 特定類別的日誌
var categoryLogging = new GraphLoggingOptions();
categoryLogging.CategoryConfigs["Performance"] = new LogCategoryConfig 
{ 
    Level = LogLevel.Debug, 
    Enabled = true 
};
categoryLogging.CategoryConfigs["State"] = new LogCategoryConfig 
{ 
    Level = LogLevel.Warning, 
    Enabled = false 
};
```

## 互通性選項

### GraphInteropOptions

跨生態系統整合和外部系統橋接的設定選項。

```csharp
public sealed class GraphInteropOptions
{
    /// <summary>
    /// 啟用匯入程式，將外部 Graph 定義 (例如 LangGraph/LangChain JSON) 轉換為 GraphExecutor 實例。
    /// </summary>
    public bool EnableImporters { get; set; } = true;

    /// <summary>
    /// 啟用產業格式的匯出程式 (例如 BPMN XML)。
    /// </summary>
    public bool EnableExporters { get; set; } = true;

    /// <summary>
    /// 啟用 Python 執行橋接 Node。
    /// </summary>
    public bool EnablePythonBridge { get; set; } = false;

    /// <summary>
    /// 啟用透過 HTTP 與外部 Graph 引擎的聯盟。
    /// </summary>
    public bool EnableFederation { get; set; } = true;

    /// <summary>
    /// Python 可執行檔的選用路徑 (適用於 Python 橋接)。若為 null 或空白，將使用 PATH 中的「python」。
    /// </summary>
    public string? PythonExecutablePath { get; set; }

    /// <summary>
    /// 聯合 Graph 呼叫的選用預設基底位址 (例如，上游 LangGraph 伺服器)。
    /// </summary>
    public string? FederationBaseAddress { get; set; }

    /// <summary>
    /// 重播/匯出安全性的選項，例如雜湊和加密。
    /// </summary>
    public ReplaySecurityOptions ReplaySecurity { get; set; } = new();
}
```

## 完整設定

### CompleteGraphOptions

所有 Graph 功能的便利集合設定。

```csharp
public sealed class CompleteGraphOptions
{
    /// <summary>
    /// 取得或設定是否啟用日誌。
    /// </summary>
    public bool EnableLogging { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用記憶體整合。
    /// </summary>
    public bool EnableMemory { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用範本支援。
    /// </summary>
    public bool EnableTemplates { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用向量搜尋。
    /// </summary>
    public bool EnableVectorSearch { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用語意搜尋。
    /// </summary>
    public bool EnableSemanticSearch { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用自訂範本協助程式。
    /// </summary>
    public bool EnableCustomHelpers { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用指標收集。
    /// </summary>
    public bool EnableMetrics { get; set; } = true;

    /// <summary>
    /// 取得或設定最大執行步驟。
    /// </summary>
    public int MaxExecutionSteps { get; set; } = 1000;

    /// <summary>
    /// 取得或設定互通性 (匯入/匯出) 選項。
    /// </summary>
    public GraphInteropOptions Interop { get; set; } = new();
}
```

## 不變性和執行

### 不變性保證

一旦執行開始，所有設定選項都是不變的。這可確保：

* **一致行為**：執行期間無法變更設定
* **執行緒安全性**：多個執行可使用不同的設定執行
* **可預測效能**：沒有執行時期設定額外負荷
* **偵錯清晰性**：設定狀態已凍結以供分析

### 依執行的設定

```csharp
// 建議從 kernel 建立執行程式，使其從主機的 DI 容器
// 繼承已註冊的 GraphOptions。執行程式會在內部擷取執行期間快照，
// 以便選項在執行期間是不變的。
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport(opts => { opts.MaxExecutionSteps = 100; opts.EnableLogging = true; })
    .Build();

var executor1 = new GraphExecutor(kernel); // 從 kernel 服務選擇 GraphOptions

// 建立第二個具有不同設定的 kernel，以示範獨立快照
var kernel2 = Kernel.CreateBuilder()
    .AddGraphSupport(opts => { opts.MaxExecutionSteps = 1000; opts.EnableLogging = false; })
    .Build();

var executor2 = new GraphExecutor(kernel2);

// 執行獨立執行，搭配其已擷取的設定
var result1 = await executor1.ExecuteAsync(kernel, arguments1);
var result2 = await executor2.ExecuteAsync(kernel2, arguments2);
```

### 執行時期設定驗證

```csharp
// 設定會在執行開始時進行驗證。使用 kernel 為基礎的執行程式時，
// 請確保選項已透過 AddGraphSupport 註冊，以便執行時期可以擷取快照和驗證。
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport(opts =>
    {
        opts.MaxExecutionSteps = -1; // 無效
        opts.ExecutionTimeout = TimeSpan.Zero; // 無效
    })
    .Build();

try
{
    var executor = new GraphExecutor(kernel);
    var result = await executor.ExecuteAsync(kernel, arguments);
}
catch (ArgumentException ex)
{
    // 設定驗證失敗
    Console.WriteLine($"設定錯誤：{ex.Message}");
}
```

## 使用模式

### 建構器模式設定

```csharp
var options = new GraphOptions()
    .WithLogging(LogLevel.Debug, enableStructured: true)
    .WithMetrics(enabled: true)
    .WithExecutionLimits(maxSteps: 500, timeout: TimeSpan.FromMinutes(5))
    .WithValidation(validateIntegrity: true, enablePlanCompilation: true)
    .WithInterop(enableImporters: true, enableExporters: true);
```

### 環境為基礎的設定

```csharp
// 若您的主控環境公開設定 (IConfiguration)，建議將
// 設定繫結至 GraphOptions，然後透過 AddGraphSupport 進行註冊。輕量級
// 僅限環境的覆寫也可以透過讀取環境變數並在向 DI 註冊選項前套用它們來實作。
var builder = Kernel.CreateBuilder();

// 範例：手動套用環境覆寫
var envOptions = new GraphOptions();
var envMax = Environment.GetEnvironmentVariable("SKG_MAX_EXECUTION_STEPS");
if (int.TryParse(envMax, out var maxSteps)) envOptions.MaxExecutionSteps = maxSteps;
if (bool.TryParse(Environment.GetEnvironmentVariable("SKG_ENABLE_LOGGING"), out var logEnabled)) envOptions.EnableLogging = logEnabled;
if (bool.TryParse(Environment.GetEnvironmentVariable("SKG_ENABLE_METRICS"), out var m)) envOptions.EnableMetrics = m;
// 使用 kernel 建構器註冊已解析的選項
builder.AddGraphSupport(opts =>
{
    // 將已解析的值複製到主機使用的選項實例中
    opts.EnableLogging = envOptions.EnableLogging;
    opts.EnableMetrics = envOptions.EnableMetrics;
    opts.MaxExecutionSteps = envOptions.MaxExecutionSteps;
});

var kernel = builder.Build();
```

### 設定繼承

```csharp
// 基本設定
var baseOptions = new GraphOptions
{
    EnableLogging = true,
    EnableMetrics = true,
    MaxExecutionSteps = 1000
};

// 特殊設定
var specializedOptions = new GraphOptions
{
    EnableLogging = baseOptions.EnableLogging,
    EnableMetrics = baseOptions.EnableMetrics,
    MaxExecutionSteps = 500, // 覆寫
    ExecutionTimeout = TimeSpan.FromMinutes(2) // 新增
};
```

## 效能考量

* **設定驗證**：在執行程式建立時進行一次，不在執行期間進行
* **選項存取**：直接屬性存取，無間接位址額外負荷
* **記憶體使用量**：設定物件的記憶體足跡最小
* **序列化**：選項可以序列化以保存設定
* **快取**：常用的設定可以快取並重複使用

## 安全性考量

* **敏感資料**：在生產環境中使用 `LogSensitiveData = false`
* **清理**：設定適當的清理原則
* **驗證**：在使用前一律驗證設定
* **環境變數**：保護環境變數存取安全
* **設定檔**：使用適當的權限保護設定檔

## 參考

* [Core API Reference](core.md) - Core Graph 執行 API
* [Extensions and Options](extensions-and-options.md) - 其他設定選項
* [Module Activation](../how-to/module-activation.md) - 如何啟用選用模組
* [Configuration Best Practices](../how-to/configuration-best-practices.md) - 設定指南
* [Performance Tuning](../how-to/performance-tuning.md) - 效能最佳化
