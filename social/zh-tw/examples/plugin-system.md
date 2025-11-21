# 插件系統範例

本範例展示了 Semantic Kernel Graph 中的進階插件系統功能，包括插件註冊表、自訂節點、偵錯工具和市場功能。

## 目標

了解如何在基於圖的工作流中實現和管理進階插件系統：
* 建立和管理綜合插件註冊表
* 開發具有進階功能的自訂插件
* 實現插件轉換和整合系統
* 啟用插件偵錯和分析工具
* 建立具有分析和發現功能的插件市場
* 支援熱重新載入和範本系統

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**在 `appsettings.json` 中設定
* **Semantic Kernel Graph 套件**已安裝
* 對 [Graph Concepts](../concepts/graph-concepts.md) 和 [Plugin Integration](../how-to/integration-and-extensions.md) 的基本了解
* 熟悉 [Custom Nodes](../concepts/node-types.md)

## 關鍵元件

### 概念和技術

* **Plugin Registry**：插件的集中管理，包含中繼資料和生命週期
* **Custom Plugin Creation**：開發具有自訂功能的特殊插件
* **Plugin Conversion**：自動將 Semantic Kernel 插件轉換為圖節點
* **Debugging and Profiling**：用於插件開發和效能分析的工具
* **Marketplace Analytics**：插件的發現、評級和使用分析
* **Hot-Reloading**：無需系統重新啟動即可動態更新插件

### 核心類別

* `PluginRegistry`：用於管理插件和中繼資料的中央註冊表
* `PluginMetadata`：用於插件識別和分類的全面中繼資料
* `CustomPluginNode`：建立自訂插件節點的基類
* `PluginConverter`：將 Semantic Kernel 插件轉換為圖相容節點
* `PluginDebugger`：用於插件開發的偵錯和分析工具
* `PluginMarketplace`：具有發現和分析功能的市場功能

## 執行範例

### 開始使用

此範例演示了 Semantic Kernel Graph 套件的插件系統和動態載入。下面的程式碼片段展示了如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. 插件註冊表設定

此最小片段展示了可執行範例 `PluginSystemExample` 使用的註冊表建立。

```csharp
// Create a logger factory for examples
using var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole().SetMinimumLevel(LogLevel.Information));

// Create plugin registry with conservative limits and a typed logger
var registry = new PluginRegistry(new PluginRegistryOptions
{
    MaxPlugins = 100,
    AllowPluginOverwrite = true,
    EnablePeriodicCleanup = true
}, loggerFactory.CreateLogger<PluginRegistry>());

// Basic marketplace analytics snapshot (async call)
var analytics = await registry.GetMarketplaceAnalyticsAsync();
Console.WriteLine($"Marketplace total plugins: {analytics.TotalPlugins}");
```

### 2. 插件註冊

使用最少的中繼資料和一個在請求時產生執行時節點的工廠來註冊插件。

```csharp
// Minimal plugin metadata
var metadata = new PluginMetadata
{
    Id = "test-plugin",
    Name = "Test Plugin",
    Description = "A simple test plugin used by examples",
    Version = new PluginVersion(1, 0, 0),
    Category = PluginCategory.General
};

// Register with a factory that creates the graph node instance when requested
var result = await registry.RegisterPluginAsync(metadata, serviceProvider => new TestPluginNode());
if (!result.IsSuccess)
{
    Console.WriteLine($"Failed to register plugin: {result.ErrorMessage}");
}
```

### 3. 插件搜尋和發現

使用註冊表搜尋 API 尋找符合簡單條件的插件。

```csharp
// Find plugins in a specific category
var found = await registry.SearchPluginsAsync(new PluginSearchCriteria
{
    Category = PluginCategory.General
});

Console.WriteLine($"Found plugins: {found.Count}");
foreach (var p in found.Take(10))
{
    Console.WriteLine($" - {p.Name} ({p.Id}) v{p.Version}");
}
```

### 4. 自訂插件建立

建立一個實現 `IGraphNode` 的小型自訂插件節點。範例專案包含由 `PluginSystemExample` 使用的 `TestPluginNode`。

可執行範例演示了使用工廠註冊插件並透過註冊表建立執行個體。建議在函式庫程式碼中建立可重複使用的節點類別，並將範例保持簡小且自含。

```csharp
// Example node factory used above: serviceProvider => new TestPluginNode()
// TestPluginNode implements IGraphNode and returns a simple FunctionResult.
```

### 5. 進階插件轉換

程式碼庫可能包括 `PluginConverter` 實現；如果沒有，請透過建立中繼資料（使用 `PluginMetadata.FromKernelPlugin`）和實現節點包裝器將核心插件轉換為圖節點。範例專案側重於註冊表和執行；轉換工具程式是可選的，應在需要時在函式庫程式碼中實現。

```csharp
// Example: Create metadata from a kernel plugin
var kernel = Kernel.CreateBuilder().Build();
// var kernelPlugin = kernel.ImportPluginFromObject(new SomeKernelPlugin());
// var metadata = PluginMetadata.FromKernelPlugin(kernelPlugin);
// registry.RegisterPluginAsync(metadata, sp => new ConvertedKernelNode(kernelPlugin));
```

### 6. 插件偵錯和分析

此函式庫提供了一個 `PluginDebugger`，它與 `IPluginRegistry` 整合以收集執行追蹤、產生報告並執行輕量級分析。下面的範例使用程式碼庫中可用的公用 API（`PluginDebugger`、`IPluginDebugSession`）並保持流程最小化和可重現。

```csharp
// Create debugger and registry (use existing loggerFactory from examples)
var registry = new PluginRegistry(new PluginRegistryOptions(), loggerFactory.CreateLogger<PluginRegistry>());
var debugger = new PluginDebugger(registry, null, loggerFactory.CreateLogger<PluginDebugger>());

// Register or ensure a plugin with id 'test-plugin' exists in the registry before debugging
// registry.RegisterPluginAsync(metadata, sp => new TestPluginNode());

// Start a debug session for the plugin
var session = await debugger.StartDebugSessionAsync("test-plugin", new PluginDebugConfiguration
{
    EnableTracing = true,
    EnableProfiling = false,
    LogExecutionSteps = true
});

// Capture a lightweight execution trace using the session
var trace = await session.TraceExecutionAsync(new KernelArguments { ["input"] = "debug test input" });
Console.WriteLine($"Trace captured: {trace.Steps.Count} steps for plugin {trace.PluginId}");

// Generate a debug report (includes session summaries and optional execution history)
var report = await debugger.GenerateDebugReportAsync("test-plugin");
Console.WriteLine($"Debug report generated for {report.PluginName} at {report.GeneratedAt}");

// Optionally profile resource usage for the plugin (simulated profile duration)
var profile = await debugger.ProfilePluginResourceUsageAsync("test-plugin", new PluginProfilingOptions { Duration = TimeSpan.FromSeconds(1) });
Console.WriteLine($"Profile: peak memory {profile.PeakMemoryUsage} MB, peak CPU {profile.PeakCpuUsage}%");

// Dispose session when finished
session.Dispose();
```

### 7. 插件市場分析

`PluginRegistry` 提供了一個適合於文件範例的簡單分析快照。如需更豐富的市場功能，請實現一個獨立的服務，該服務聚合註冊表統計資料和市場中繼資料。

```csharp
// Use the registry analytics helper to get a quick overview
var analytics = await registry.GetMarketplaceAnalyticsAsync();
Console.WriteLine($"Total plugins: {analytics.TotalPlugins}");
foreach (var kv in analytics.PluginsByCategory)
{
    Console.WriteLine($"  {kv.Key}: {kv.Value}");
}
```

### 8. 熱重新載入和範本系統

此系統支援動態插件更新和基於範本的開發。

```csharp
private static async Task DemonstrateHotReloadingAsync(ILogger logger, ILoggerFactory loggerFactory)
{
    Console.WriteLine("\n🔥 6. Hot-Reloading and Template System");
    Console.WriteLine("----------------------------------------");

    var hotReloader = new PluginHotReloader(loggerFactory.CreateLogger<PluginHotReloader>());
    var templateEngine = new PluginTemplateEngine(loggerFactory.CreateLogger<PluginTemplateEngine>());

    // Create a plugin from template
    var template = await templateEngine.GetTemplateAsync("basic-analytics");
    var pluginCode = await template.GenerateCodeAsync(new Dictionary<string, object>
    {
        ["pluginName"] = "Generated Analytics",
        ["description"] = "Auto-generated analytics plugin",
        ["category"] = "Analytics"
    });

    Console.WriteLine($"  Generated plugin code: {pluginCode.Length} characters");

    // Compile and load the plugin
    var compiledPlugin = await hotReloader.CompileAndLoadAsync(pluginCode);
    Console.WriteLine($"  Plugin compiled and loaded: {compiledPlugin.GetType().Name}");

    // Test the hot-reloaded plugin
    var result = await compiledPlugin.ExecuteAsync(new KernelArguments
    {
        ["data"] = "test data for hot-reloaded plugin"
    });

    Console.WriteLine($"  Hot-reload test result: {result}");

    // Demonstrate template system
    var availableTemplates = await templateEngine.GetAvailableTemplatesAsync();
    Console.WriteLine($"\n📋 Available Templates:");
    foreach (var templateInfo in availableTemplates)
    {
        Console.WriteLine($"   - {templateInfo.Name}: {templateInfo.Description}");
    }
}
```

## 預期輸出

此範例會產生全面的輸出，顯示：

* 📚 插件註冊表設定和管理
* 🔧 自訂插件建立和註冊
* 🔄 來自 Semantic Kernel 的進階插件轉換
* 🐛 插件偵錯和分析功能
* 🏪 插件市場分析和發現
* 🔥 熱重新載入和範本系統功能
* ✅ 完整插件系統工作流執行

## 疑難排解

### 常見問題

1. **插件註冊失敗**：確保插件中繼資料完整且有效
2. **轉換錯誤**：檢查 Semantic Kernel 插件相容性和依賴項
3. **偵錯失敗**：驗證是否啟用了插件偵錯以及是否配置了記錄
4. **熱重新載入問題**：確保插件程式碼編譯和載入權限

### 偵錯提示

* 為插件註冊表操作啟用詳細記錄
* 使用插件偵錯工具追蹤執行流程
* 監視插件效能指標和資源使用情況
* 驗證範本生成和編譯過程

## 另請參閱

* [Plugin Integration](../how-to/integration-and-extensions.md)
* [Custom Nodes](../concepts/node-types.md)
* [Plugin Development](../how-to/plugin-development.md)
* [Debugging and Inspection](../how-to/debug-and-inspection.md)
* [Template System](../concepts/templates.md)
