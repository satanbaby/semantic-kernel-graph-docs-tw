# 安全性和資料處理

本指南說明如何在 SemanticKernel.Graph 中實作全面的安全措施和資料處理政策，包括資料清理、敏感金鑰管理、保留政策和加密功能。

## 概述

SemanticKernel.Graph 提供企業級安全功能，確保敏感資料保護、安全執行和資料治理要求合規。該系統包括：

* **資料清理**：自動編輯日誌、事件和匯出中的敏感資訊
* **身份驗證與授權**：Bearer 令牌驗證和基於範圍的存取控制
* **加密**：支援加密檢查點和安全資料傳輸
* **保留政策**：可設定的資料生命週期管理和自動清理
* **多租戶隔離**：不同租戶環境之間的安全邊界

## 資料清理

### 核心清理元件

清理系統由多個關鍵元件組成：

* **`SensitiveDataSanitizer`**：清理物件和字典的主要公用程式
* **`SensitiveDataPolicy`**：定義清理行為的組態政策
* **`SanitizationLevel`**：控制清理強度的列舉

### 清理等級

```csharp
public enum SanitizationLevel
{
    None = 0,      // 不套用任何清理
    Basic = 1,     // 僅在金鑰提示敏感性時編輯
    Strict = 2     // 編輯所有字串值，不論金鑰為何
}
```

### 基本清理組態

使用預設敏感金鑰模式設定清理：

```csharp
using SemanticKernel.Graph.Integration;

var policy = new SensitiveDataPolicy
{
    Enabled = true,
    Level = SanitizationLevel.Basic,
    RedactionText = "***REDACTED***",
    MaskAuthorizationBearerToken = true
};

var sanitizer = new SensitiveDataSanitizer(policy);
```

### 自訂敏感金鑰模式

定義您特定領域敏感資料的自訂模式：

```csharp
var customPolicy = new SensitiveDataPolicy
{
    Enabled = true,
    Level = SanitizationLevel.Basic,
    RedactionText = "[SENSITIVE]",
    SensitiveKeySubstrings = new[]
    {
        // 標準模式
        "password", "secret", "token", "key", "auth",
        
        // 特定領域模式
        "ssn", "credit_card", "bank_account", "social_security",
        "medical_record", "patient_id", "diagnosis",
        
        // 自訂業務模式
        "internal_note", "confidential", "restricted"
    },
    MaskAuthorizationBearerToken = true
};

var sanitizer = new SensitiveDataSanitizer(customPolicy);
```

### 清理不同資料類型

清理器自動處理各種資料結構：

```csharp
// 建立包含潛在敏感項目的字典。將變數宣告為
// IDictionary<string, object?> 以確保選擇清理器的
// IDictionary 多載（解決多載歧義）。
IDictionary<string, object?> sensitiveData = new Dictionary<string, object?>
{
    ["username"] = "john_doe",
    ["password"] = "secret123",
    ["api_key"] = "sk-1234567890abcdef",
    ["authorization"] = "Bearer sk-1234567890abcdef",
    ["connection_string"] = "Server=localhost;Database=test;Password=secret;",
    ["normal_data"] = "This is not sensitive"
};

// 呼叫 IDictionary 多載來清理原位語意。
var sanitizedData = sanitizer.Sanitize(sensitiveData);

// 範例輸出：敏感值根據政策進行編輯
foreach (var kvp in sanitizedData)
{
    Console.WriteLine($"{kvp.Key}: {kvp.Value}");
}

// JSON 範例：清理 JsonDocument 承載（對 HTTP 主體很有用）
using var doc = System.Text.Json.JsonDocument.Parse(
    "{\"api_key\":\"sk-abcdef\",\"nested\":{\"password\":\"p@ss\"}}"
);

var sanitizedJson = sanitizer.Sanitize(doc.RootElement);

// 如果 sanitizedJson 是字典，迭代並顯示值
if (sanitizedJson is IDictionary<string, object?> dict)
{
    foreach (var kv in dict)
    {
        Console.WriteLine($"JSON - {kv.Key}: {kv.Value}");
    }
}

```

### 與日誌整合

將清理套用至日誌輸出以防止敏感資料洩露：

```csharp
// 使用清理設定日誌記錄
var loggingOptions = new GraphLoggingOptions
{
    LogSensitiveData = false,
    Sanitization = new SensitiveDataPolicy
    {
        Enabled = true,
        Level = SanitizationLevel.Basic,
        RedactionText = "[REDACTED]"
    }
};

// 套用至核心產生器
builder.AddGraphSupport(opts =>
{
    opts.EnableLogging = true;
    opts.Logging = loggingOptions;
});
```

## 身份驗證和授權

### Bearer 令牌驗證

SemanticKernel.Graph 透過 `IBearerTokenValidator` 介面提供靈活的 Bearer 令牌驗證：

```csharp
using SemanticKernel.Graph.Integration;

// Azure AD JWT 驗證
var validator = new AzureAdBearerTokenValidator();

// 使用必需的範圍驗證令牌
var isValid = await validator.ValidateAsync(
    bearerToken: "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1Ni...",
    requiredScopes: new[] { "graph.read", "graph.write" },
    requiredAppRoles: new[] { "GraphUser", "GraphAdmin" }
);
```

### 自訂令牌驗證程式

為您的身份驗證系統實作自訂驗證邏輯：

```csharp
public sealed class CustomBearerTokenValidator : IBearerTokenValidator
{
    public async Task<bool> ValidateAsync(string bearerToken, 
        IEnumerable<string>? requiredScopes = null, 
        IEnumerable<string>? requiredAppRoles = null, 
        CancellationToken cancellationToken = default)
    {
        // 實作您的自訂驗證邏輯
        // 例如，針對您的身份提供者進行驗證
        
        if (string.IsNullOrWhiteSpace(bearerToken))
            return false;
            
        try
        {
            // 解析並驗證令牌
            // 檢查範圍和角色
            // 驗證過期和其他聲明
            
            return true; // 根據驗證傳回 true 或 false
        }
        catch
        {
            return false;
        }
    }
}
```

### REST API 安全性

設定圖形 REST API 的安全性：

```csharp
var restApiOptions = new GraphRestApiOptions
{
    RequireAuthentication = true,
    EnableBearerTokenAuth = true,
    RequiredScopes = new[] { "graph.execute", "graph.read" },
    RequiredAppRoles = new[] { "GraphUser" },
    ApiKey = null, // 改用 Bearer 令牌
    RateLimitRequestsPerMinute = 100
};

// 在相依性注入容器中登錄
builder.Services.AddSingleton(restApiOptions);
builder.Services.AddSingleton<IBearerTokenValidator, AzureAdBearerTokenValidator>();
```

## 加密和安全儲存

### 檢查點加密

啟用敏感檢查點資料的加密：

```csharp
var checkpointOptions = new CheckpointOptions
{
    EnableCompression = true,
    EnableEncryption = true,
    EncryptionKey = "your-encryption-key", // 使用安全金鑰管理
    MaxCacheSize = 1000,
    EnableAutoCleanup = true
};

// 使用備份加密進行設定
var backupOptions = new CheckpointBackupOptions
{
    CompressBackup = true,
    EncryptBackup = true,
    ReplicationFactor = 3,
    VerifyAfterBackup = true
};

checkpointOptions.DefaultBackupOptions = backupOptions;
```

### 安全金鑰管理

透過 `ISecretResolver` 介面實作安全金鑰解析：

```csharp
public sealed class AzureKeyVaultSecretResolver : ISecretResolver
{
    private readonly SecretClient _secretClient;
    
    public AzureKeyVaultSecretResolver(SecretClient secretClient)
    {
        _secretClient = secretClient;
    }
    
    public async Task<string?> ResolveAsync(string secretName, CancellationToken cancellationToken = default)
    {
        try
        {
            var secret = await _secretClient.GetSecretAsync(secretName, cancellationToken: cancellationToken);
            return secret.Value.Value;
        }
        catch
        {
            return null;
        }
    }
}

// 在相依性注入容器中登錄
builder.Services.AddSingleton<ISecretResolver, AzureKeyVaultSecretResolver>();
```

### 記憶體加密

在需要時加密記憶體中的敏感資料：

```csharp
var memoryOptions = new GraphMemoryOptions
{
    EnableVectorSearch = true,
    EnableSemanticSearch = true,
    EnableEncryption = true,
    EncryptionKey = "memory-encryption-key",
    DefaultCollectionName = "encrypted-graph-memory"
};
```

## 資料保留和生命週期管理

### 檢查點保留政策

設定自動清理和保留政策：

```csharp
var retentionPolicy = new CheckpointRetentionPolicy
{
    MaxAge = TimeSpan.FromDays(30),           // 保留 30 天
    MaxCheckpointsPerExecution = 100,         // 每次執行最多 100 個
    MaxTotalStorageBytes = 5L * 1024 * 1024 * 1024,  // 總儲存空間 5GB
    KeepCriticalCheckpoints = true,           // 一律保留關鍵檢查點
    CriticalCheckpointInterval = 10           // 每 10 個常規檢查點後進行關鍵檢查點
};

var checkpointOptions = new CheckpointOptions
{
    DefaultRetentionPolicy = retentionPolicy,
    EnableAutoCleanup = true,
    AutoCleanupInterval = TimeSpan.FromHours(6)
};
```

### 日誌保留和清理

設定日誌保留和自動清理：

```csharp
var loggingOptions = new GraphLoggingOptions
{
    LogRetentionPeriod = TimeSpan.FromDays(90),
    EnableLogRotation = true,
    MaxLogFileSize = 100 * 1024 * 1024, // 100MB
    MaxLogFiles = 10,
    EnableCompression = true,
    EnableEncryption = false // 啟用敏感日誌的加密
};
```

### 記憶體清理政策

設定記憶體清理和保留：

```csharp
var memoryCleanupOptions = new MemoryCleanupOptions
{
    CleanupInterval = TimeSpan.FromHours(12),
    MaxMemoryAge = TimeSpan.FromDays(7),
    MaxMemoryEntries = 10000,
    EnableCompression = true,
    EnableEncryption = false
};
```

## 多租戶隔離

### 租戶內容管理

為多租戶應用程式實作租戶隔離：

```csharp
public sealed class TenantContext
{
    public string TenantId { get; init; } = string.Empty;
    public string UserId { get; init; } = string.Empty;
    public IReadOnlyDictionary<string, string> Claims { get; init; } = new Dictionary<string, string>();
    public TimeSpan SessionTimeout { get; init; } = TimeSpan.FromHours(8);
}

// 租戶感知圖形執行
public sealed class TenantAwareGraphExecutor
{
    private readonly GraphExecutor _baseExecutor;
    private readonly TenantContext _tenantContext;
    
    public async Task<GraphExecutionResult> ExecuteAsync(
        KernelArguments arguments, 
        CancellationToken cancellationToken = default)
    {
        // 將租戶內容注入至引數
        arguments["tenant_id"] = _tenantContext.TenantId;
        arguments["user_id"] = _tenantContext.UserId;
        
        // 以租戶隔離的方式執行
        return await _baseExecutor.ExecuteAsync(arguments, cancellationToken);
    }
}
```

### 子圖隔離

使用子圖隔離模式進行安全執行邊界：

```csharp
var subgraphConfig = new SubgraphConfiguration
{
    IsolationMode = SubgraphIsolationMode.IsolatedClone,
    ScopedPrefix = "tenant_data",
    InputMappings = new Dictionary<string, string>
    {
        ["user_input"] = "input",
        ["tenant_context"] = "context"
    },
    OutputMappings = new Dictionary<string, string>
    {
        ["result"] = "tenant_result",
        ["metadata"] = "tenant_metadata"
    }
};

var subgraphNode = new SubgraphGraphNode(subgraphExecutor, subgraphConfig);
```

### API 層級租戶隔離

在 REST API 層級實作租戶隔離：

```csharp
var restApiOptions = new GraphRestApiOptions
{
    RequireAuthentication = true,
    EnableTenantIsolation = true,
    TenantHeaderName = "X-Tenant-ID",
    TenantValidationRequired = true,
    MaxTenantsPerRequest = 1
};

// 自訂租戶驗證程式
public sealed class TenantValidator : ITenantValidator
{
    public async Task<bool> ValidateTenantAsync(string tenantId, string userId, CancellationToken cancellationToken = default)
    {
        // 實作租戶驗證邏輯
        // 檢查使用者是否有權存取指定租戶
        return await ValidateUserTenantAccessAsync(tenantId, userId, cancellationToken);
    }
}
```

## 審核和合規性

### 執行審核

啟用全面的執行審核：

```csharp
var auditOptions = new AuditOptions
{
    EnableExecutionAudit = true,
    EnableDataAccessAudit = true,
    EnableSecurityAudit = true,
    AuditRetentionPeriod = TimeSpan.FromDays(365),
    EnableAuditCompression = true,
    EnableAuditEncryption = true
};

// 設定審核日誌記錄
var auditLogger = new AuditLogger(auditOptions);
builder.Services.AddSingleton<IAuditLogger>(auditLogger);
```

### 合規性報告

產生法規要求的合規性報告：

```csharp
public sealed class ComplianceReporter
{
    public async Task<ComplianceReport> GenerateReportAsync(
        DateTimeOffset startDate, 
        DateTimeOffset endDate, 
        string tenantId, 
        CancellationToken cancellationToken = default)
    {
        var report = new ComplianceReport
        {
            Period = new DateRange(startDate, endDate),
            TenantId = tenantId,
            DataAccessLogs = await GetDataAccessLogsAsync(startDate, endDate, tenantId, cancellationToken),
            SecurityEvents = await GetSecurityEventsAsync(startDate, endDate, tenantId, cancellationToken),
            DataRetentionCompliance = await ValidateDataRetentionAsync(tenantId, cancellationToken)
        };
        
        return report;
    }
}
```

## 安全最佳實踐

### 組態安全

1. **環境式組態**：使用環境變數進行敏感組態
2. **秘密輪換**：實作長期認證的自動秘密輪換
3. **最小權限**：為每個元件授予最小必需權限
4. **網路安全**：針對所有外部通訊使用 HTTPS/TLS

### 資料保護

1. **靜態加密**：加密持久儲存區中的敏感資料
2. **傳輸中加密**：對所有資料傳輸使用 TLS
3. **金鑰管理**：使用安全金鑰管理服務（Azure 金鑰保存庫、AWS KMS）
4. **資料分類**：按敏感性分類資料，並套用適當的保護

### 存取控制

1. **多重要素驗證**：要求對管理存取進行 MFA
2. **角色型存取控制**：為細粒度權限實作 RBAC
3. **工作階段管理**：實作適當的工作階段逾時和管理
4. **審核日誌記錄**：記錄所有與安全相關的事件以供合規之用

### 監控和警示

1. **安全監控**：監控可疑活動和安全事件
2. **警示**：針對安全違規和異常設定警示
3. **事件回應**：有程序來應對安全事件
4. **定期審查**：進行定期安全審查和滲透測試

## 疑難排解

### 常見安全問題

**身份驗證失敗**
* 驗證 Bearer 令牌格式和過期時間
* 檢查必需的範圍和應用程式角色
* 驗證令牌簽發者和對象

**資料清理問題**
* 確保敏感金鑰模式正確設定
* 檢查清理等級設定
* 驗證自訂協助函數不會略過清理

**加密問題**
* 驗證加密金鑰格式和長度
* 檢查金鑰輪換排程
* 驗證加密演算法相容性

**租戶隔離問題**
* 確認租戶內容是否已正確注入
* 檢查子圖隔離模式組態
* 驗證租戶驗證邏輯

### 安全偵錯

1. **啟用安全日誌記錄**：使用詳細的安全日誌記錄進行疑難排解
2. **令牌檢查**：使用 JWT 偵錯程式檢查令牌內容
3. **政策驗證**：使用範例資料測試清理政策
4. **隔離測試**：使用多租戶測試案例驗證租戶隔離

## 另請參閱

* [整合和延伸](../how-to/integration-and-extensions.md) - 核心整合模式和延伸
* [檢查點和復原](../concepts/checkpointing.md) - 狀態持久化和復原
* [多代理程式工作流程](../how-to/multi-agent-and-shared-state.md) - 安全多代理程式協調
* [REST API 整合](../how-to/exposing-rest-apis.md) - 安全 API 端點
* [API 參考](../api/) - 安全類型的完整 API 文件
