# 安全性與資料處理

本指南說明如何在 SemanticKernel.Graph 中實現全面的安全措施和資料處理政策，包括資料清潔、敏感金鑰管理、保留政策和加密功能。

## 概述

SemanticKernel.Graph 提供企業級安全功能，確保敏感資料保護、安全執行和合規資料治理要求。該系統包括：

* **資料清潔**：自動刪除日誌、事件和匯出中的敏感資訊
* **身份驗證與授權**：Bearer Token 驗證和基於範圍的存取控制
* **加密**：支援加密檢查點和安全資料傳輸
* **保留政策**：可配置的資料生命週期管理和自動清理
* **多租戶隔離**：不同租戶上下文之間的安全邊界

## 資料清潔

### 核心清潔元件

清潔系統包含幾個關鍵元件：

* **`SensitiveDataSanitizer`**：用於清潔物件和字典的主要工具
* **`SensitiveDataPolicy`**：定義清潔行為的配置政策
* **`SanitizationLevel`**：控制清潔強度的列舉

### 清潔級別

```csharp
public enum SanitizationLevel
{
    None = 0,      // 不應用清潔
    Basic = 1,     // 僅在金鑰提示敏感性時刪除
    Strict = 2     // 無論金鑰如何，刪除所有字串值
}
```

### 基本清潔配置

使用預設敏感金鑰模式配置清潔：

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

定義特定於您的領域的敏感資料自訂模式：

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
        
        // 自訂商業模式
        "internal_note", "confidential", "restricted"
    },
    MaskAuthorizationBearerToken = true
};

var sanitizer = new SensitiveDataSanitizer(customPolicy);
```

### 清潔不同的資料類型

清潔工具自動處理各種資料結構：

```csharp
// 建立包含可能敏感項目的字典。將變數宣告為
// IDictionary<string, object?> 以確保選擇清潔工具的 IDictionary 重載
//（解決重載歧義）。
IDictionary<string, object?> sensitiveData = new Dictionary<string, object?>
{
    ["username"] = "john_doe",
    ["password"] = "secret123",
    ["api_key"] = "sk-1234567890abcdef",
    ["authorization"] = "Bearer sk-1234567890abcdef",
    ["connection_string"] = "Server=localhost;Database=test;Password=secret;",
    ["normal_data"] = "This is not sensitive"
};

// 通過調用 IDictionary 重載來原地清潔。
var sanitizedData = sanitizer.Sanitize(sensitiveData);

// 範例輸出：根據政策刪除敏感值
foreach (var kvp in sanitizedData)
{
    Console.WriteLine($"{kvp.Key}: {kvp.Value}");
}

// JSON 範例：清潔 JsonDocument 有效負載（適用於 HTTP 主體）
using var doc = System.Text.Json.JsonDocument.Parse(
    "{\"api_key\":\"sk-abcdef\",\"nested\":{\"password\":\"p@ss\"}}"
);

var sanitizedJson = sanitizer.Sanitize(doc.RootElement);

// 如果 sanitizedJson 是字典，反覆檢視並顯示值
if (sanitizedJson is IDictionary<string, object?> dict)
{
    foreach (var kv in dict)
    {
        Console.WriteLine($"JSON - {kv.Key}: {kv.Value}");
    }
}

```

### 與日誌記錄整合

將清潔應用於日誌記錄輸出以防止敏感資料洩露：

```csharp
// 配置帶清潔的日誌記錄
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

// 應用於 Kernel Builder
builder.AddGraphSupport(opts =>
{
    opts.EnableLogging = true;
    opts.Logging = loggingOptions;
});
```

## 身份驗證與授權

### Bearer Token 驗證

SemanticKernel.Graph 透過 `IBearerTokenValidator` 介面提供靈活的 Bearer Token 驗證：

```csharp
using SemanticKernel.Graph.Integration;

// Azure AD JWT 驗證
var validator = new AzureAdBearerTokenValidator();

// 使用必需的範圍驗證 Token
var isValid = await validator.ValidateAsync(
    bearerToken: "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1Ni...",
    requiredScopes: new[] { "graph.read", "graph.write" },
    requiredAppRoles: new[] { "GraphUser", "GraphAdmin" }
);
```

### 自訂 Token 驗證器

為您的驗證系統實現自訂驗證邏輯：

```csharp
public sealed class CustomBearerTokenValidator : IBearerTokenValidator
{
    public async Task<bool> ValidateAsync(string bearerToken, 
        IEnumerable<string>? requiredScopes = null, 
        IEnumerable<string>? requiredAppRoles = null, 
        CancellationToken cancellationToken = default)
    {
        // 實現您的自訂驗證邏輯
        // 例如，根據您的身份提供者進行驗證
        
        if (string.IsNullOrWhiteSpace(bearerToken))
            return false;
            
        try
        {
            // 解析並驗證 Token
            // 檢查範圍和角色
            // 驗證過期和其他聲稱
            
            return true; // 或根據驗證返回 false
        }
        catch
        {
            return false;
        }
    }
}
```

### REST API 安全性

為 Graph REST API 配置安全性：

```csharp
var restApiOptions = new GraphRestApiOptions
{
    RequireAuthentication = true,
    EnableBearerTokenAuth = true,
    RequiredScopes = new[] { "graph.execute", "graph.read" },
    RequiredAppRoles = new[] { "GraphUser" },
    ApiKey = null, // 改用 Bearer Token
    RateLimitRequestsPerMinute = 100
};

// 在 DI 容器中註冊
builder.Services.AddSingleton(restApiOptions);
builder.Services.AddSingleton<IBearerTokenValidator, AzureAdBearerTokenValidator>();
```

## 加密和安全儲存

### 檢查點加密

為敏感的檢查點資料啟用加密：

```csharp
var checkpointOptions = new CheckpointOptions
{
    EnableCompression = true,
    EnableEncryption = true,
    EncryptionKey = "your-encryption-key", // 使用安全的金鑰管理
    MaxCacheSize = 1000,
    EnableAutoCleanup = true
};

// 使用備份加密配置
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

透過 `ISecretResolver` 介面實現安全金鑰解析：

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

// 在 DI 容器中註冊
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

配置自動清理和保留政策：

```csharp
var retentionPolicy = new CheckpointRetentionPolicy
{
    MaxAge = TimeSpan.FromDays(30),           // 保留 30 天
    MaxCheckpointsPerExecution = 100,         // 每次執行最多 100 個
    MaxTotalStorageBytes = 5L * 1024 * 1024 * 1024,  // 總共 5GB 儲存空間
    KeepCriticalCheckpoints = true,           // 始終保留關鍵檢查點
    CriticalCheckpointInterval = 10           // 每 10 個常規檢查點一個關鍵檢查點
};

var checkpointOptions = new CheckpointOptions
{
    DefaultRetentionPolicy = retentionPolicy,
    EnableAutoCleanup = true,
    AutoCleanupInterval = TimeSpan.FromHours(6)
};
```

### 日誌保留和清理

配置日誌保留和自動清理：

```csharp
var loggingOptions = new GraphLoggingOptions
{
    LogRetentionPeriod = TimeSpan.FromDays(90),
    EnableLogRotation = true,
    MaxLogFileSize = 100 * 1024 * 1024, // 100MB
    MaxLogFiles = 10,
    EnableCompression = true,
    EnableEncryption = false // 為敏感日誌啟用
};
```

### 記憶體清理政策

配置記憶體清理和保留：

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

### 租戶上下文管理

為多租戶應用程式實現租戶隔離：

```csharp
public sealed class TenantContext
{
    public string TenantId { get; init; } = string.Empty;
    public string UserId { get; init; } = string.Empty;
    public IReadOnlyDictionary<string, string> Claims { get; init; } = new Dictionary<string, string>();
    public TimeSpan SessionTimeout { get; init; } = TimeSpan.FromHours(8);
}

// 租戶感知的 Graph 執行
public sealed class TenantAwareGraphExecutor
{
    private readonly GraphExecutor _baseExecutor;
    private readonly TenantContext _tenantContext;
    
    public async Task<GraphExecutionResult> ExecuteAsync(
        KernelArguments arguments, 
        CancellationToken cancellationToken = default)
    {
        // 將租戶上下文注入參數
        arguments["tenant_id"] = _tenantContext.TenantId;
        arguments["user_id"] = _tenantContext.UserId;
        
        // 以租戶隔離的方式執行
        return await _baseExecutor.ExecuteAsync(arguments, cancellationToken);
    }
}
```

### 子 Graph 隔離

使用子 Graph 隔離模式進行安全執行邊界：

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

### API 級租戶隔離

在 REST API 級別實現租戶隔離：

```csharp
var restApiOptions = new GraphRestApiOptions
{
    RequireAuthentication = true,
    EnableTenantIsolation = true,
    TenantHeaderName = "X-Tenant-ID",
    TenantValidationRequired = true,
    MaxTenantsPerRequest = 1
};

// 自訂租戶驗證器
public sealed class TenantValidator : ITenantValidator
{
    public async Task<bool> ValidateTenantAsync(string tenantId, string userId, CancellationToken cancellationToken = default)
    {
        // 實現租戶驗證邏輯
        // 檢查使用者是否有權存取指定的租戶
        return await ValidateUserTenantAccessAsync(tenantId, userId, cancellationToken);
    }
}
```

## 審計和合規

### 執行審計

啟用全面的執行審計：

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

// 配置審計日誌記錄
var auditLogger = new AuditLogger(auditOptions);
builder.Services.AddSingleton<IAuditLogger>(auditLogger);
```

### 合規報告

為法規要求生成合規報告：

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

### 配置安全性

1. **環境型配置**：針對敏感配置使用環境變數
2. **密鑰輪替**：為長期認證實現自動密鑰輪替
3. **最小權限**：向每個元件授予最小必要權限
4. **網路安全性**：為所有外部通訊使用 HTTPS/TLS

### 資料保護

1. **靜態加密**：加密持久儲存中的敏感資料
2. **傳輸中加密**：為所有資料傳輸使用 TLS
3. **金鑰管理**：使用安全的金鑰管理服務（Azure Key Vault、AWS KMS）
4. **資料分類**：按敏感性分類資料並應用適當的保護

### 存取控制

1. **多因素驗證**：需要 MFA 進行管理存取
2. **角色型存取控制**：實現 RBAC 以進行細粒度權限
3. **工作階段管理**：實現適當的工作階段逾時和管理
4. **審計日誌記錄**：記錄所有安全相關事件以進行合規

### 監控和警示

1. **安全監控**：監控可疑活動和安全事件
2. **警示**：設定安全違規和異常的警示
3. **事件響應**：具有響應安全事件的程序
4. **定期檢查**：進行定期安全檢查和滲透測試

## 故障排除

### 常見安全問題

**驗證失敗**
* 驗證 Bearer Token 格式和過期時間
* 檢查必需的範圍和應用程式角色
* 驗證 Token 簽發者和對象

**資料清潔問題**
* 確保敏感金鑰模式配置正確
* 檢查清潔級別設定
* 驗證自訂協助程式函數不會繞過清潔

**加密問題**
* 驗證加密金鑰格式和長度
* 檢查金鑰輪替計畫
* 驗證加密演算法相容性

**租戶隔離問題**
* 確認租戶上下文已正確注入
* 檢查子 Graph 隔離模式配置
* 驗證租戶驗證邏輯

### 偵錯安全性

1. **啟用安全日誌記錄**：使用詳細的安全日誌記錄進行故障排除
2. **Token 檢查**：使用 JWT 偵錯工具檢查 Token 內容
3. **政策驗證**：使用樣本資料測試清潔政策
4. **隔離測試**：使用多租戶測試案例驗證租戶隔離

## 相關資訊

* [整合和擴充](../how-to/integration-and-extensions.md) - 核心整合模式和擴充
* [檢查點和恢復](../concepts/checkpointing.md) - 狀態持久化和恢復
* [多代理工作流程](../how-to/multi-agent-and-shared-state.md) - 安全多代理協調
* [REST API 整合](../how-to/exposing-rest-apis.md) - 安全 API 端點
* [API 參考](../api/) - 安全類型的完整 API 文件
