# 圖形選項和配置

SemanticKernel.Graph 提供了一個全面的配置系統，包含不同子系統的模組化選項。本參考涵蓋了完整的選項層次結構，包括核心選項、模組特定配置和執行期間的不可變性保證。

## GraphOptions

用於控制日誌記錄、指標、驗證和執行邊界的圖形功能的主要配置類別。

### 建構函式

```csharp
public sealed class GraphOptions
{
    // 預設建構函式，提供合理的預設值
    public GraphOptions()
}
```

### 核心屬性

```csharp
public sealed class GraphOptions
{
    /// <summary>
    /// 取得或設定是否啟用圖形執行的日誌記錄。
    /// </summary>
    public bool EnableLogging { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用指標收集。
    /// </summary>
    public bool EnableMetrics { get; set; } = true;

    /// <summary>
    /// 取得或設定終止前的最大執行步數。
    /// </summary>
    public int MaxExecutionSteps { get; set; } = 1000;

    /// <summary>
    /// 取得或設定是否在執行前驗證圖形完整性。
    /// </summary>
    public bool ValidateGraphIntegrity { get; set; } = true;

    /// <summary>
    /// 取得或設定執行逾時。
    /// </summary>
    public TimeSpan ExecutionTimeout { get; set; } = TimeSpan.FromMinutes(10);

    /// <summary>
    /// 啟用圖形簽名的結構化執行計畫編譯和快取。
    /// </summary>
    public bool EnablePlanCompilation { get; set; } = true;

    /// <summary>
    /// 取得或設定不同類別和節點的日誌記錄配置。
    /// </summary>
    public GraphLoggingOptions Logging { get; set; } = new();

    /// <summary>
    /// 取得或設定互操作性相關選項（匯入/匯出、橋接、聯盟）。
    /// </summary>
    public GraphInteropOptions Interop { get; set; } = new();
}
```

### 使用範例

```csharp
// 建議透過核心建設器註冊 GraphOptions，使 DI 容器
// 將選項暴露給執行上下文和其他服務。
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport(opts =>
    {
        opts.EnableLogging = true;
        opts.EnableMetrics = true;
        opts.MaxExecutionSteps = 500;
        opts.ValidateGraphIntegrity = true;
        opts.ExecutionTimeout = TimeSpan.FromMinutes(5);
        opts.EnablePlanCompilation = true;

        // 配置日誌記錄子選項
        opts.Logging.MinimumLevel = LogLevel.Debug;
        opts.Logging.EnableStructuredLogging = true;
        opts.Logging.EnableCorrelationIds = true;

        // 配置互操作性
        opts.Interop.EnableImporters = true;
        opts.Interop.EnableExporters = true;
        opts.Interop.EnablePythonBridge = false;
    })
    .Build();

// 當執行開始時，執行時會透過 GraphExecutionOptions.From(graphOptions) 
// 拍攝即時 GraphOptions 的快照，保證按執行的不可變性。
```

## 模組啟用選項

### GraphModuleActivationOptions

用於有條件地透過依賴注入啟用可選圖形模組的配置旗標。

```csharp
public sealed class GraphModuleActivationOptions
{
    /// <summary>
    /// 啟用串流元件（事件串流連線池、重新連線管理器）。
    /// </summary>
    public bool EnableStreaming { get; set; }

    /// <summary>
    /// 啟用檢查點服務和工廠。
    /// </summary>
    public bool EnableCheckpointing { get; set; }

    /// <summary>
    /// 啟用復原整合。僅在啟用檢查點時有效。
    /// </summary>
    public bool EnableRecovery { get; set; }

    /// <summary>
    /// 啟用人類在迴圈中（預設註冊記憶體中存放區和 Web API 支援的通道）。
    /// </summary>
    public bool EnableHumanInTheLoop { get; set; }

    /// <summary>
    /// 啟用多代理程式基礎結構（連線池和選項）。
    /// </summary>
    public bool EnableMultiAgent { get; set; }

    /// <summary>
    /// 應用所有旗標的環境變數覆寫。
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

// 將模組新增至核心建設器
var builder = Kernel.CreateBuilder()
    .AddGraphModules(options);
```

## 串流選項

### StreamingExecutionOptions

用於串流執行行為和事件處理的配置選項。

```csharp
public sealed class StreamingExecutionOptions
{
    /// <summary>
    /// 取得或設定事件串流的緩衝區大小。
    /// 預設值：100 個事件。
    /// </summary>
    public int BufferSize { get; set; } = 100;

    /// <summary>
    /// 取得或設定應用背壓前的最大緩衝區大小。
    /// 預設值：1000 個事件。
    /// </summary>
    public int MaxBufferSize { get; set; } = 1000;

    /// <summary>
    /// 取得或設定串流中斷時是否啟用自動重新連線。
    /// 預設值：true。
    /// </summary>
    public bool EnableAutoReconnect { get; set; } = true;

    /// <summary>
    /// 取得或設定重新連線嘗試的最大次數。
    /// 預設值：3 次嘗試。
    /// </summary>
    public int MaxReconnectAttempts { get; set; } = 3;

    /// <summary>
    /// 取得或設定初始重新連線延遲。
    /// 預設值：1 秒。
    /// </summary>
    public TimeSpan InitialReconnectDelay { get; set; } = TimeSpan.FromSeconds(1);

    /// <summary>
    /// 取得或設定最大重新連線延遲（用於指數退避）。
    /// 預設值：30 秒。
    /// </summary>
    public TimeSpan MaxReconnectDelay { get; set; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// 取得或設定是否在事件中包含中間狀態快照。
    /// 預設值：false（以減少事件大小）。
    /// </summary>
    public bool IncludeStateSnapshots { get; set; } = false;

    /// <summary>
    /// 取得或設定要發出的事件類型。
    /// 預設值：所有事件類型。
    /// </summary>
    public GraphExecutionEventType[]? EventTypesToEmit { get; set; }

    /// <summary>
    /// 取得或設定要附加到串流的自訂事件處理器。
    /// </summary>
    public List<IGraphExecutionEventHandler> CustomEventHandlers { get; set; } = new();
}
```

### 串流配置範例

```csharp
// 基本串流配置
var basicOptions = new StreamingExecutionOptions
{
    BufferSize = 50,
    MaxBufferSize = 500,
    EnableAutoReconnect = true
};

// 高效能配置
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

// 監控配置
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

用於自動檢查點行為和狀態持續性的配置選項。

```csharp
public sealed class CheckpointingOptions
{
    /// <summary>
    /// 取得或設定建立檢查點的間隔（已執行的節點數）。
    /// </summary>
    public int CheckpointInterval { get; set; } = 10;

    /// <summary>
    /// 取得或設定用於建立檢查點的可選時間間隔。
    /// </summary>
    public TimeSpan? CheckpointTimeInterval { get; set; }

    /// <summary>
    /// 取得或設定是否在執行開始前建立初始檢查點。
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
    /// 取得或設定應始終觸發檢查點建立的重要節點 ID 清單。
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
    /// 取得或設定是否啟用重要檢查點的分散式備份。
    /// </summary>
    public bool EnableDistributedBackup { get; set; } = false;

    /// <summary>
    /// 取得或設定用於分散式存放的備份選項。
    /// </summary>
    public DistributedBackupOptions? DistributedBackupOptions { get; set; }
}
```

### 檢查點配置範例

```csharp
// 針對關鍵工作流的頻繁檢查點
var criticalOptions = new CheckpointingOptions
{
    CheckpointInterval = 5,
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    CreateErrorCheckpoints = true,
    CriticalNodes = new HashSet<string> { "decision_node", "approval_node" },
    EnableAutoCleanup = true
};

// 基於時間的檢查點
var timeBasedOptions = new CheckpointingOptions
{
    CheckpointTimeInterval = TimeSpan.FromMinutes(5),
    CheckpointInterval = 100, // 回退到基於節點
    CreateInitialCheckpoint = true,
    CreateFinalCheckpoint = true,
    EnableAutoCleanup = true
};

// 最小檢查點以提高效能
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

用於自動復原和重播功能的配置選項。

```csharp
public sealed class RecoveryOptions
{
    /// <summary>
    /// 取得或設定執行失敗時是否啟用自動復原。
    /// </summary>
    public bool EnableAutomaticRecovery { get; set; } = true;

    /// <summary>
    /// 取得或設定復原嘗試的最大次數。
    /// </summary>
    public int MaxRecoveryAttempts { get; set; } = 3;

    /// <summary>
    /// 取得或設定要使用的復原策略。
    /// </summary>
    public RecoveryStrategy Strategy { get; set; } = RecoveryStrategy.LastSuccessfulCheckpoint;

    /// <summary>
    /// 取得或設定是否啟用條件式重播以執行「如果情況如何」案例。
    /// </summary>
    public bool EnableConditionalReplay { get; set; } = false;

    /// <summary>
    /// 取得或設定條件式案例的最大重播深度。
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

### 復原配置範例

```csharp
// 針對生產系統的積極復原
var aggressiveRecovery = new RecoveryOptions
{
    EnableAutomaticRecovery = true,
    MaxRecoveryAttempts = 5,
    Strategy = RecoveryStrategy.LastSuccessfulCheckpoint,
    EnableConditionalReplay = false,
    PreserveExecutionHistory = true,
    RecoveryTimeout = TimeSpan.FromMinutes(10)
};

// 針對開發的保守復原
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

## 人類在迴圈中 (HITL) 選項

### HumanApprovalOptions

用於人類核准節點和互動行為的配置選項。

```csharp
public sealed class HumanApprovalOptions
{
    /// <summary>
    /// 取得或設定核准請求的標題。
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// 取得或設定核准請求的描述。
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
    /// 取得或設定所需的核准次數。
    /// </summary>
    public int ApprovalThreshold { get; set; } = 1;

    /// <summary>
    /// 取得或設定失敗請求的拒絕次數。
    /// </summary>
    public int RejectionThreshold { get; set; } = 1;

    /// <summary>
    /// 取得或設定是否允許部分核准。
    /// </summary>
    public bool AllowPartialApproval { get; set; } = false;
}
```

### WebApiChannelOptions

用於基於網路的人類互動通道的配置選項。

```csharp
public sealed class WebApiChannelOptions
{
    /// <summary>
    /// 取得或設定 Web API 的端點路徑。
    /// </summary>
    public string EndpointPath { get; set; } = "/api/approvals";

    /// <summary>
    /// 取得或設定 HTTP 操作的請求逾時。
    /// </summary>
    public TimeSpan RequestTimeout { get; set; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// 取得或設定失敗請求的重試原則。
    /// </summary>
    public RetryPolicy RetryPolicy { get; set; } = RetryPolicy.ExponentialBackoff(3, TimeSpan.FromSeconds(1));

    /// <summary>
    /// 取得或設定驗證配置。
    /// </summary>
    public IAuthenticationConfig? Authentication { get; set; }

    /// <summary>
    /// 取得或設定要包含在請求中的自訂標頭。
    /// </summary>
    public Dictionary<string, string> CustomHeaders { get; set; } = new();
}
```

### HITL 配置範例

```csharp
// 基本核准配置
var approvalOptions = new HumanApprovalOptions
{
    Title = "Document Review Required",
    Description = "Please review the generated document for accuracy",
    Instructions = "Check grammar, content, and formatting",
    RequiredFields = new[] { "reviewer_name", "approval_notes" },
    ApprovalThreshold = 1,
    RejectionThreshold = 1,
    AllowPartialApproval = false
};

// Web API 通道配置
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

用於多代理程式協調和工作流程管理的配置選項。

```csharp
public sealed class MultiAgentOptions
{
    /// <summary>
    /// 取得或設定並行代理程式的最大數目。
    /// </summary>
    public int MaxConcurrentAgents { get; set; } = 10;

    /// <summary>
    /// 取得或設定共用狀態管理選項。
    /// </summary>
    public SharedStateOptions SharedStateOptions { get; set; } = new();

    /// <summary>
    /// 取得或設定工作分配選項。
    /// </summary>
    public WorkDistributionOptions WorkDistributionOptions { get; set; } = new();

    /// <summary>
    /// 取得或設定結果匯總選項。
    /// </summary>
    public ResultAggregationOptions ResultAggregationOptions { get; set; } = new();

    /// <summary>
    /// 取得或設定健康狀態監控選項。
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
    /// 取得或設定是否啟用多代理程式工作流程的分散式追蹤 (ActivitySource)。
    /// </summary>
    public bool EnableDistributedTracing { get; set; } = true;
}
```

### AgentConnectionPoolOptions

用於管理代理程式連線池的配置選項。

```csharp
public sealed class AgentConnectionPoolOptions
{
    /// <summary>
    /// 取得或設定集區中的最大連線數目。
    /// </summary>
    public int MaxConnections { get; set; } = 100;

    /// <summary>
    /// 取得或設定要維護的最小連線數目。
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
    /// 取得或設定是否啟用連線健康檢查。
    /// </summary>
    public bool EnableHealthChecks { get; set; } = true;

    /// <summary>
    /// 取得或設定健康檢查間隔。
    /// </summary>
    public TimeSpan HealthCheckInterval { get; set; } = TimeSpan.FromSeconds(30);
}
```

### 多代理程式配置範例

```csharp
// 高效能多代理程式配置
var highPerfOptions = new MultiAgentOptions
{
    MaxConcurrentAgents = 50,
    CoordinationTimeout = TimeSpan.FromMinutes(15),
    EnableAutomaticCleanup = true,
    WorkflowRetentionPeriod = TimeSpan.FromHours(12),
    EnableDistributedTracing = true
};

// 保守多代理程式配置
var conservativeOptions = new MultiAgentOptions
{
    MaxConcurrentAgents = 5,
    CoordinationTimeout = TimeSpan.FromMinutes(60),
    EnableAutomaticCleanup = false,
    WorkflowRetentionPeriod = TimeSpan.FromDays(7),
    EnableDistributedTracing = false
};

// 連線池配置
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

## 日誌記錄選項

### GraphLoggingOptions

用於圖形執行的進階日誌記錄配置選項。

```csharp
public sealed class GraphLoggingOptions
{
    /// <summary>
    /// 取得或設定圖形執行的最小日誌層級。
    /// </summary>
    public LogLevel MinimumLevel { get; set; } = LogLevel.Information;

    /// <summary>
    /// 取得或設定是否啟用結構化日誌記錄。
    /// </summary>
    public bool EnableStructuredLogging { get; set; } = true;

    /// <summary>
    /// 取得或設定是否啟用相關識別碼。
    /// </summary>
    public bool EnableCorrelationIds { get; set; } = true;

    /// <summary>
    /// 取得或設定要記錄的狀態資料的最大大小。
    /// </summary>
    public int MaxStateDataSize { get; set; } = 2000;

    /// <summary>
    /// 取得或設定類別特定的日誌記錄配置。
    /// 類別包括：「Graph」、「Node」、「Routing」、「Error」、「Performance」、「State」、「Validation」。
    /// </summary>
    public Dictionary<string, LogCategoryConfig> CategoryConfigs { get; set; } = new();

    /// <summary>
    /// 取得或設定節點特定的日誌記錄配置。
    /// 鍵是節點 ID 或節點類型名稱。
    /// </summary>
    public Dictionary<string, NodeLoggingConfig> NodeConfigs { get; set; } = new();

    /// <summary>
    /// 取得或設定是否記錄敏感資料（參數、狀態值）。
    /// 當為 false 時，僅記錄參數名稱和計數，不記錄值。
    /// </summary>
    public bool LogSensitiveData { get; set; } = false;

    /// <summary>
    /// 取得或設定敏感資料的清理原則。
    /// </summary>
    public SensitiveDataPolicy Sanitization { get; set; } = SensitiveDataPolicy.Default;

    /// <summary>
    /// 取得或設定此圖形實例的自訂相關識別碼前置詞。
    /// </summary>
    public string? CorrelationIdPrefix { get; set; }

    /// <summary>
    /// 取得或設定日誌項目中時間戳記的格式。
    /// </summary>
    public string TimestampFormat { get; set; } = "yyyy-MM-dd HH:mm:ss.fff";
}
```

### 日誌記錄配置範例

```csharp
// 開發用詳細日誌記錄
var verboseLogging = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Debug,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    LogSensitiveData = true,
    MaxStateDataSize = 5000
};

// 含清理的生產日誌記錄
var productionLogging = new GraphLoggingOptions
{
    MinimumLevel = LogLevel.Information,
    EnableStructuredLogging = true,
    EnableCorrelationIds = true,
    LogSensitiveData = false,
    Sanitization = SensitiveDataPolicy.Strict,
    MaxStateDataSize = 1000
};

// 類別特定的日誌記錄
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

## 互操作性選項

### GraphInteropOptions

用於跨生態系統整合和外部系統橋接的配置選項。

```csharp
public sealed class GraphInteropOptions
{
    /// <summary>
    /// 啟用將外部圖形定義（例如 LangGraph/LangChain JSON）轉換為 GraphExecutor 實例的匯入器。
    /// </summary>
    public bool EnableImporters { get; set; } = true;

    /// <summary>
    /// 啟用用於業界格式的匯出器（例如 BPMN XML）。
    /// </summary>
    public bool EnableExporters { get; set; } = true;

    /// <summary>
    /// 啟用 Python 執行橋接節點。
    /// </summary>
    public bool EnablePythonBridge { get; set; } = false;

    /// <summary>
    /// 啟用透過 HTTP 與外部圖形引擎的聯盟。
    /// </summary>
    public bool EnableFederation { get; set; } = true;

    /// <summary>
    /// 用於 Python 橋接的 Python 可執行檔的可選路徑。如果為 null 或空字串，將使用 PATH 中的「python」。
    /// </summary>
    public string? PythonExecutablePath { get; set; }

    /// <summary>
    /// 聯盟圖形呼叫的可選預設基址（例如上游 LangGraph 伺服器）。
    /// </summary>
    public string? FederationBaseAddress { get; set; }

    /// <summary>
    /// 重播/匯出安全性的選項，例如雜湊和加密。
    /// </summary>
    public ReplaySecurityOptions ReplaySecurity { get; set; } = new();
}
```

## 完整配置

### CompleteGraphOptions

所有圖形功能的便利聚合配置。

```csharp
public sealed class CompleteGraphOptions
{
    /// <summary>
    /// 取得或設定是否啟用日誌記錄。
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
    /// 取得或設定是否啟用語義搜尋。
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
    /// 取得或設定最大執行步數。
    /// </summary>
    public int MaxExecutionSteps { get; set; } = 1000;

    /// <summary>
    /// 取得或設定互操作性（匯入/匯出）選項。
    /// </summary>
    public GraphInteropOptions Interop { get; set; } = new();
}
```

## 不可變性和執行

### 不可變性保證

所有配置選項在執行開始後都是不可變的。這可以確保：

* **一致的行為**：執行期間配置無法變更
* **執行緒安全**：多個執行可以使用不同的配置執行
* **可預測的效能**：沒有執行時配置負擔
* **除錯清晰度**：配置狀態被凍結以供分析

### 按執行的配置

```csharp
// 建議從核心建立執行程式，以便繼承主機 DI 容器中註冊的 GraphOptions。
// 執行程式會在內部捕捉按執行快照，所以選項在執行期間是不可變的。
var kernel = Kernel.CreateBuilder()
    .AddGraphSupport(opts => { opts.MaxExecutionSteps = 100; opts.EnableLogging = true; })
    .Build();

var executor1 = new GraphExecutor(kernel); // 從核心服務中拾取 GraphOptions

// 建立第二個核心具有不同的設定以演示獨立快照
var kernel2 = Kernel.CreateBuilder()
    .AddGraphSupport(opts => { opts.MaxExecutionSteps = 1000; opts.EnableLogging = false; })
    .Build();

var executor2 = new GraphExecutor(kernel2);

// 執行使用其捕捉的配置獨立執行
var result1 = await executor1.ExecuteAsync(kernel, arguments1);
var result2 = await executor2.ExecuteAsync(kernel2, arguments2);
```

### 執行時配置驗證

```csharp
// 在執行開始時驗證配置。使用基於核心的執行程式時，
// 確保選項透過 AddGraphSupport 註冊，以便執行時可以快照和驗證。
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
    // 配置驗證失敗
    Console.WriteLine($"Configuration error: {ex.Message}");
}
```

## 使用模式

### 建設器模式配置

```csharp
var options = new GraphOptions()
    .WithLogging(LogLevel.Debug, enableStructured: true)
    .WithMetrics(enabled: true)
    .WithExecutionLimits(maxSteps: 500, timeout: TimeSpan.FromMinutes(5))
    .WithValidation(validateIntegrity: true, enablePlanCompilation: true)
    .WithInterop(enableImporters: true, enableExporters: true);
```

### 環境型配置

```csharp
// 如果您的主機環境暴露配置 (IConfiguration)，建議將
// 設定繫結到 GraphOptions 中，然後透過 AddGraphSupport 註冊。也可以實作輕量級
// 環境唯讀覆寫，方法是在註冊選項到 DI 前讀取環境變數並應用。
var builder = Kernel.CreateBuilder();

// 範例：手動應用環境覆寫
var envOptions = new GraphOptions();
var envMax = Environment.GetEnvironmentVariable("SKG_MAX_EXECUTION_STEPS");
if (int.TryParse(envMax, out var maxSteps)) envOptions.MaxExecutionSteps = maxSteps;
if (bool.TryParse(Environment.GetEnvironmentVariable("SKG_ENABLE_LOGGING"), out var logEnabled)) envOptions.EnableLogging = logEnabled;
if (bool.TryParse(Environment.GetEnvironmentVariable("SKG_ENABLE_METRICS"), out var m)) envOptions.EnableMetrics = m;
// 向核心建設器註冊解析的選項
builder.AddGraphSupport(opts =>
{
    // 將解析的值複製到主機使用的選項實例中
    opts.EnableLogging = envOptions.EnableLogging;
    opts.EnableMetrics = envOptions.EnableMetrics;
    opts.MaxExecutionSteps = envOptions.MaxExecutionSteps;
});

var kernel = builder.Build();
```

### 配置繼承

```csharp
// 基本配置
var baseOptions = new GraphOptions
{
    EnableLogging = true,
    EnableMetrics = true,
    MaxExecutionSteps = 1000
};

// 特殊配置
var specializedOptions = new GraphOptions
{
    EnableLogging = baseOptions.EnableLogging,
    EnableMetrics = baseOptions.EnableMetrics,
    MaxExecutionSteps = 500, // 覆寫
    ExecutionTimeout = TimeSpan.FromMinutes(2) // 新增
};
```

## 效能考量

* **配置驗證**：在執行程式建立時進行，不在執行期間進行
* **選項存取**：直接屬性存取，無間接存取負擔
* **記憶體使用**：配置物件的最小記憶體足跡
* **序列化**：選項可序列化以保存配置
* **快取**：常用的配置可以快取和重複使用

## 安全考量

* **敏感資料**：在生產環境中使用 `LogSensitiveData = false`
* **清理**：配置適當的清理原則
* **驗證**：在使用前一律驗證配置
* **環境變數**：安全的環境變數存取
* **配置檔案**：使用適當權限保護配置檔案

## 另請參閱

* [核心 API 參考](core.md) - 核心圖形執行 API
* [擴充和選項](extensions-and-options.md) - 其他配置選項
* [模組啟用](../how-to/module-activation.md) - 如何啟用可選模組
* [配置最佳實踐](../how-to/configuration-best-practices.md) - 配置指南
* [效能調整](../how-to/performance-tuning.md) - 效能最佳化
