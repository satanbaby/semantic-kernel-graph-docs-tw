# 常見問題（FAQ）

關於 SemanticKernel.Graph 的常見問題與解答。

## 基本概念

### 什麼是 SemanticKernel.Graph？
**SemanticKernel.Graph** 是 Semantic Kernel 的擴充套件，增加了計算圖執行功能，允許你使用節點、條件邊和受控執行來建立複雜的工作流程。

### 它與 Semantic Kernel 的關係如何？
這是一個擴充套件，與現有 Semantic Kernel 保持完全相容，增加了圖形編排功能，但不改變基礎功能。

### 與 LangGraph 的差異是什麼？
它提供與 LangGraph 類似的功能，但更著重於與 .NET 生態系統和 Semantic Kernel 的原生整合，針對企業應用進行最佳化。

## 需求與相容性

### 支援哪些 .NET 版本？
**.NET 8+** 是建議的最低版本，完全支援所有現代功能。

### 是否能與現有的 SK 程式碼搭配使用？
**可以**，只需進行最少的變更。它利用現有的外掛程式、服務和連接器，只是增加了圖形功能。

### 如何遷移現有的 Semantic Kernel 專案？
**遷移步驟：**
1. **新增套件參考** - 安裝 `SemanticKernel.Graph` NuGet 套件
2. **更新核心建構器** - 在 `Build()` 之前新增 `AddGraphSupport()` 呼叫
3. **註冊圖形服務** - 使用現有的 DI 容器進行服務註冊
4. **測試整合** - 驗證外掛程式和服務能作為圖形節點運作
5. **漸進式採用** - 從簡單的圖形開始，然後增加複雜性

### 是否需要外部服務？
**不一定**。它可以以最少的組態運作，但在可用時可以整合遙測、記憶體和監控服務。

### 需要哪些組態檔？
**不需要任何**。它開箱即用，但你可以選擇使用：
- `appsettings.json` 用於環境特定設定
- 環境變數用於敏感組態
- 自訂組態提供者用於企業部署

## 功能

### 是否支援串流？
**支援**，具有自動重新連線、智慧緩衝和背壓控制。

### 檢查點在生產環境中是否有效？
**有效**，支援持久化、壓縮、版本控制和強大的恢復。

### 是否支援平行執行？
**支援**，具有確定性排程器、並行控制和狀態合併。

### 視覺化是否互動式？
**是的**，可以匯出至 DOT、Mermaid、JSON 和即時執行覆蓋。

## 整合與開發

### 如何與現有應用程式整合？
```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Integration;

// 新增基本組態的圖形支援
builder.AddGraphSupport();

// 建構核心
var kernel = builder.Build();

// 取得圖形執行器工廠
var executor = kernel.GetRequiredService<IGraphExecutorFactory>();

// 對於進階組態，你也可以使用：
// builder.AddGraphSupport(options =>
// {
//     options.EnableLogging = true;
//     options.EnableMetrics = true;
//     options.MaxExecutionSteps = 100;
//     options.ExecutionTimeout = TimeSpan.FromMinutes(5);
// });
```

### 是否支援自訂外掛程式？
**支援**，所有現有的 SK 外掛程式都可作為圖形節點。

### 如何除錯複雜的圖形？
* **互動式除錯工作階段** - 逐步執行並檢查狀態
* **特定節點的中斷點** - 條件中斷點和執行暫停
* **即時視覺化** - 具有節點突出顯示的即時圖形執行
* **每個節點的詳細指標** - 效能分析和瓶頸識別
* **狀態檢查** - 執行期間檢視和修改圖形狀態
* **執行歷史記錄** - 所有執行步驟的完整稽核日誌
* **錯誤上下文** - 附帶堆疊追蹤的詳細錯誤資訊

### 是否有測試支援？
**有**，整合了測試架構和開發用的模擬程式。

### 常見的整合問題有哪些？
**常見問題與解決方案：**
- **找不到服務**：確保在 `Build()` 之前呼叫了 `AddGraphSupport()`
- **組態錯誤**：檢查所有必要的服務是否已註冊
- **記憶體問題**：如果使用記憶體功能，驗證是否呼叫了 `AddGraphMemory()`
- **檢查點失敗**：確保持久化有適當的檔案權限

## 效能與可擴充性

### 效能開銷是多少？
**最少** - 只有編排所需的開銷，對節點執行沒有影響。

### 如何最佳化圖形效能？
**效能最佳化策略：**
- **平行執行** - 在可能的地方啟用並行節點執行
- **快取** - 針對重複操作使用檢查點和狀態快取
- **資源池** - 設定連線池和資源限制
- **非同步操作** - 確保所有節點都使用非同步/等待模式
- **記憶體管理** - 設定適當的記憶體限制和清理間隔
- **監控** - 使用內建指標識別瓶頸

### 是否支援分散式執行？
**支援**，支援多個處理序和機器。

### 如何處理失敗？
* 可設定的重試原則
* 斷路器
* 自動回退
* 檢查點恢復

## 組態與部署

### 是否需要特殊組態？
**不需要**，它可以零組態運作，但在需要時提供進階選項。

### 是否支援 Docker 容器？
**支援**，完全支援容器化環境。

### 安全考量如何？
**安全功能包括：**
- **密鑰管理** - 與 Azure Key Vault 和環境變數整合
- **驗證** - 支援 Azure AD、OAuth 和自訂驗證提供者
- **資料加密** - 靜態和傳輸中的敏感資料加密
- **存取控制** - 圖形執行的角色型權限
- **稽核日誌記錄** - 全面的執行稽核日誌

### 如何在生產環境中監控？
* **原生指標**（.NET Metrics）- 內建效能計數器
* **結構化日誌記錄** - 帶有關聯 ID 的 JSON 格式日誌
* **Application Insights 整合** - 帶有自訂事件的 Azure 監控
* **匯出至 Prometheus/Grafana** - 開源監控堆疊支援
* **即時執行追蹤** - 即時圖形執行視覺化
* **自訂遙測** - 可擴充的指標收集架構

## 支援與社群

### 如何尋求協助？
* [文件](../index.md)
* [範例](../examples/index.md)
* [GitHub Issues](https://github.com/your-org/semantic-kernel-graph/issues)
* [Discussions](https://github.com/your-org/semantic-kernel-graph/discussions)

### 如何貢獻？
* 報告錯誤
* 提出改進建議
* 貢獻範例
* 改進文件

### 是否有公開的路線圖？
**有**，可在 [路線圖](../architecture/implementation-roadmap.md) 取得。

## 使用案例

### 它最適合哪些類型的應用程式？
* **複雜的 AI 工作流程** - 多步驟推理、思維鏈和代理系統
* **資料處理管道** - ETL 工作流程、資料驗證和轉換鏈
* **自動化決策系統** - 商務規則引擎、核准工作流程和決策樹
* **微服務編排** - 服務協調、斷路器和回退策略
* **進階聊天機器人應用程式** - 多回合對話、上下文管理和意圖路由
* **內容生成** - 檔案建立、程式碼生成和創意寫作工作流程
* **品質保證** - 測試自動化、驗證管道和品質閘道

### 生產使用的範例？
* 自動化文件分析
* 大規模內容分類
* 推薦系統
* 核准工作流程
* 表單處理

---

## 另見

* [快速入門](../getting-started.md)
* [安裝](../installation.md)
* [範例](../examples/index.md)
* [架構](../architecture/index.md)
* [疑難排解](../troubleshooting.md)

## 參考資料

* [Semantic Kernel 文件](https://learn.microsoft.com/en-us/semantic-kernel/)
* [LangGraph Python](https://langchain-ai.github.io/langgraph/)
* [.NET 文件](https://docs.microsoft.com/en-us/dotnet/)

## 完整整合範例

以下是展示本常見問題所述整合模式的完整工作範例：

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Integration;

// 建立核心建構器
var kernelBuilder = Kernel.CreateBuilder();

// 新增基本圖形支援
kernelBuilder.AddGraphSupport();

// 新增記憶體支援
kernelBuilder.AddGraphMemory();

// 新增具有自訂選項的檢查點支援
kernelBuilder.AddCheckpointSupport(options =>
{
    options.EnableCompression = true;
    options.MaxCacheSize = 1000;
    options.EnableAutoCleanup = true;
    options.AutoCleanupInterval = TimeSpan.FromHours(1);
});

// 建構核心
var kernel = kernelBuilder.Build();

// 取得圖形執行器工廠
var executor = kernel.GetRequiredService<IGraphExecutorFactory>();

Console.WriteLine("✅ 已成功新增圖形支援！");
Console.WriteLine($"✅ 圖形執行器工廠：{executor.GetType().Name}");
```

此範例展示：
- **基本圖形整合**使用 `AddGraphSupport()`
- **記憶體整合**使用 `AddGraphMemory()`
- **檢查點支援**使用 `AddCheckpointSupport()`
- **從建構的核心中擷取服務**
- **適當的錯誤處理和驗證**

## 後續步驟

閱讀完此常見問題後，你可以：

1. **開始建置** - 使用上面的整合範例將圖形支援新增至你的專案
2. **探索範例** - 查看 [範例](../examples/index.md) 區段中的完整工作範例
3. **學習概念** - 閱讀 [圖形概念](../concepts/graph-concepts.md) 和 [節點類型](../concepts/node-types.md)
4. **進階功能** - 探索 [進階模式](../examples/advanced-patterns.md) 和 [動態路由](../examples/dynamic-routing.md)
5. **尋求協助** - 加入社群討論並在 GitHub 上報告問題

## 其他資源

- **API 參考** - 完整的 [API 文件](../api/core.md)
- **架構指南** - 深入 [系統架構](../architecture/index.md)
- **最佳做法** - 從 [實世界範例](../examples/index.md) 學習
- **效能指南** - 使用 [效能秘訣](../how-to/metrics-and-observability.md) 最佳化你的圖形
