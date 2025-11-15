# 外掛系統範例

此範例展示 Semantic Kernel Graph 中的進階外掛系統功能，包括外掛登錄表、自訂節點、除錯工具和市集功能。

## 目標

瞭解如何在基於圖形的工作流程中實現和管理進階外掛系統，以：
* 建立和管理全面的外掛登錄表
* 開發具有進階功能的自訂外掛
* 實現外掛轉換和整合系統
* 啟用外掛除錯和分析工具
* 建立具有分析和探索功能的外掛市集
* 支援熱重新載入和範本系統

## 先決條件

* **.NET 8.0** 或更新版本
* 在 `appsettings.json` 中設定的 **OpenAI API 金鑰**
* 已安裝 **Semantic Kernel Graph 套件**
* 基本瞭解 [圖形概念](../concepts/graph-concepts.md) 和 [外掛整合](../how-to/integration-and-extensions.md)
* 熟悉 [自訂節點](../concepts/node-types.md)

## 主要元件

### 概念和技術

* **外掛登錄表**：具有中繼資料和生命週期的外掛集中管理
* **自訂外掛建立**：開發具有自訂功能的特化外掛
* **外掛轉換**：自動將 Semantic Kernel 外掛轉換為圖形節點
* **除錯和分析**：用於外掛開發和效能分析的工具
* **市集分析**：外掛的探索、評分和使用分析
* **熱重新載入**：無需系統重新啟動的動態外掛更新

### 核心類別

* `PluginRegistry`：管理外掛和中繼資料的中央登錄表
* `PluginMetadata`：外掛識別和分類的綜合中繼資料
* `CustomPluginNode`：用於建立自訂外掛節點的基類
* `PluginConverter`：將 Semantic Kernel 外掛轉換為圖形相容的節點
* `PluginDebugger`：用於外掛開發的除錯和分析工具
* `PluginMarketplace`：具有探索和分析功能的市集功能

## 執行範例

### 開始使用

此範例展示 Semantic Kernel Graph 套件的外掛系統和動態載入。下面的程式碼片段說明如何在您自己的應用程式中實現此模式。

## 分步驟實作

### 1. 外掛登錄表設定

此最小片段顯示了可執行範例 `PluginSystemExample` 使用的登錄表建立。

```csharp
// 為範例建立記錄器工廠
using var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole().SetMinimumLevel(LogLevel.Information));

// 使用保守限制和輸入的記錄器建立外掛登錄表
var registry = new PluginRegistry(new PluginRegistryOptions
{
    MaxPlugins = 100,
    AllowPluginOverwrite = true,
    EnablePeriodicCleanup = true
}, loggerFactory.CreateLogger<PluginRegistry>());

// 基本市集分析快照 (非同步呼叫)
var analytics = await registry.GetMarketplaceAnalyticsAsync();
Console.WriteLine($"市集總外掛數：{analytics.TotalPlugins}");
```

### 2. 外掛登錄

使用最少的中繼資料和產生執行時期節點的工廠登錄外掛。

```csharp
// 最少的外掛中繼資料
var metadata = new PluginMetadata
{
    Id = "test-plugin",
    Name = "Test Plugin",
    Description = "A simple test plugin used by examples",
    Version = new PluginVersion(1, 0, 0),
    Category = PluginCategory.General
};

// 使用工廠登錄，該工廠在要求時建立圖形節點執行個體
var result = await registry.RegisterPluginAsync(metadata, serviceProvider => new TestPluginNode());
if (!result.IsSuccess)
{
    Console.WriteLine($"無法登錄外掛：{result.ErrorMessage}");
}
```

### 3. 外掛搜尋和探索

使用登錄表搜尋 API 尋找符合簡單條件的外掛。

```csharp
// 尋找特定類別中的外掛
var found = await registry.SearchPluginsAsync(new PluginSearchCriteria
{
    Category = PluginCategory.General
});

Console.WriteLine($"找到的外掛：{found.Count}");
foreach (var p in found.Take(10))
{
    Console.WriteLine($" - {p.Name} ({p.Id}) v{p.Version}");
}
```

### 4. 自訂外掛建立

建立實現 `IGraphNode` 的小型自訂外掛節點。範例專案包含 `PluginSystemExample` 使用的 `TestPluginNode`。

可執行範例展示使用工廠登錄外掛並透過登錄表建立執行個體。偏好在程式庫程式碼中建立可重複使用的節點類別，並保持範例小巧且自我包含。

```csharp
// 上面使用的範例節點工廠：serviceProvider => new TestPluginNode()
// TestPluginNode 實作 IGraphNode 並傳回簡單的 FunctionResult。
```

### 5. 進階外掛轉換

程式碼庫可能包含 `PluginConverter` 實作；如果沒有，透過使用 `PluginMetadata.FromKernelPlugin` 建立中繼資料並實現節點包裝器，將核心外掛轉換為圖形節點。範例專案著重於登錄表和執行；轉換公用程式是選擇性的，應在需要時在程式庫程式碼中實作。

```csharp
// 範例：從核心外掛建立中繼資料
var kernel = Kernel.CreateBuilder().Build();
// var kernelPlugin = kernel.ImportPluginFromObject(new SomeKernelPlugin());
// var metadata = PluginMetadata.FromKernelPlugin(kernelPlugin);
// registry.RegisterPluginAsync(metadata, sp => new ConvertedKernelNode(kernelPlugin));
```

### 6. 外掛除錯和分析

程式庫提供與 `IPluginRegistry` 整合的 `PluginDebugger`，以收集執行追蹤、產生報告和執行輕量級分析。下面的範例使用程式碼庫中可用的公開 API (`PluginDebugger`、`IPluginDebugSession`)，並保持流程最小且可重現。

```csharp
// 建立除錯工具和登錄表 (使用範例中的現有 loggerFactory)
var registry = new PluginRegistry(new PluginRegistryOptions(), loggerFactory.CreateLogger<PluginRegistry>());
var debugger = new PluginDebugger(registry, null, loggerFactory.CreateLogger<PluginDebugger>());

// 在除錯前在登錄表中登錄或確保存在具有 id 'test-plugin' 的外掛
// registry.RegisterPluginAsync(metadata, sp => new TestPluginNode());

// 為外掛啟動除錯工作階段
var session = await debugger.StartDebugSessionAsync("test-plugin", new PluginDebugConfiguration
{
    EnableTracing = true,
    EnableProfiling = false,
    LogExecutionSteps = true
});

// 使用工作階段擷取輕量級執行追蹤
var trace = await session.TraceExecutionAsync(new KernelArguments { ["input"] = "debug test input" });
Console.WriteLine($"擷取追蹤：外掛 {trace.PluginId} 的 {trace.Steps.Count} 個步驟");

// 產生除錯報告 (包括工作階段摘要和選擇性執行歷程記錄)
var report = await debugger.GenerateDebugReportAsync("test-plugin");
Console.WriteLine($"為 {report.PluginName} 在 {report.GeneratedAt} 產生除錯報告");

// 選擇性地分析外掛的資源使用情況 (模擬的分析持續時間)
var profile = await debugger.ProfilePluginResourceUsageAsync("test-plugin", new PluginProfilingOptions { Duration = TimeSpan.FromSeconds(1) });
Console.WriteLine($"分析：尖峰記憶體 {profile.PeakMemoryUsage} MB、尖峰 CPU {profile.PeakCpuUsage}%");

// 完成時處置工作階段
session.Dispose();
```

### 7. 外掛市集分析

`PluginRegistry` 提供適合用於文件範例的簡單分析快照。若要使用更豐富的市集功能，請實作單獨的服務，以聚合登錄表統計資料和市集中�繼資料。

```csharp
// 使用登錄表分析協助程式取得快速概覽
var analytics = await registry.GetMarketplaceAnalyticsAsync();
Console.WriteLine($"總外掛數：{analytics.TotalPlugins}");
foreach (var kv in analytics.PluginsByCategory)
{
    Console.WriteLine($"  {kv.Key}：{kv.Value}");
}
```

### 8. 熱重新載入和範本系統

系統支援動態外掛更新和基於範本的開發。

```csharp
private static async Task DemonstrateHotReloadingAsync(ILogger logger, ILoggerFactory loggerFactory)
{
    Console.WriteLine("\n🔥 6. 熱重新載入和範本系統");
    Console.WriteLine("----------------------------------------");

    var hotReloader = new PluginHotReloader(loggerFactory.CreateLogger<PluginHotReloader>());
    var templateEngine = new PluginTemplateEngine(loggerFactory.CreateLogger<PluginTemplateEngine>());

    // 從範本建立外掛
    var template = await templateEngine.GetTemplateAsync("basic-analytics");
    var pluginCode = await template.GenerateCodeAsync(new Dictionary<string, object>
    {
        ["pluginName"] = "Generated Analytics",
        ["description"] = "Auto-generated analytics plugin",
        ["category"] = "Analytics"
    });

    Console.WriteLine($"  產生的外掛程式碼：{pluginCode.Length} 個字元");

    // 編譯並載入外掛
    var compiledPlugin = await hotReloader.CompileAndLoadAsync(pluginCode);
    Console.WriteLine($"  外掛已編譯並載入：{compiledPlugin.GetType().Name}");

    // 測試熱重新載入的外掛
    var result = await compiledPlugin.ExecuteAsync(new KernelArguments
    {
        ["data"] = "test data for hot-reloaded plugin"
    });

    Console.WriteLine($"  熱重新載入測試結果：{result}");

    // 展示範本系統
    var availableTemplates = await templateEngine.GetAvailableTemplatesAsync();
    Console.WriteLine($"\n📋 可用的範本：");
    foreach (var templateInfo in availableTemplates)
    {
        Console.WriteLine($"   - {templateInfo.Name}：{templateInfo.Description}");
    }
}
```

## 預期輸出

範例會產生顯示以下內容的綜合輸出：

* 📚 外掛登錄表設定和管理
* 🔧 自訂外掛建立和登錄
* 🔄 來自 Semantic Kernel 的進階外掛轉換
* 🐛 外掛除錯和分析功能
* 🏪 外掛市集分析和探索
* 🔥 熱重新載入和範本系統功能
* ✅ 完整的外掛系統工作流程執行

## 疑難排解

### 常見問題

1. **外掛登錄失敗**：確保外掛中繼資料完整且有效
2. **轉換錯誤**：檢查 Semantic Kernel 外掛相容性和相依性
3. **除錯失敗**：驗證外掛除錯已啟用且記錄已設定
4. **熱重新載入問題**：確保外掛程式碼編譯和載入權限

### 除錯提示

* 為外掛登錄表作業啟用詳細記錄
* 使用外掛除錯工具追蹤執行流程
* 監視外掛效能指標和資源使用情況
* 驗證範本產生和編譯程序

## 另請參閱

* [外掛整合](../how-to/integration-and-extensions.md)
* [自訂節點](../concepts/node-types.md)
* [外掛開發](../how-to/plugin-development.md)
* [除錯和檢查](../how-to/debug-and-inspection.md)
* [範本系統](../concepts/templates.md)
