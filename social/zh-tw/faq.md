# 常見問題集 - FAQ

關於 SemanticKernel.Graph 的常見問題與解答。

## 基本概念

### 什麼是 SemanticKernel.Graph？
**SemanticKernel.Graph** 是 Semantic Kernel 的擴展，增加了計算圖執行功能，讓你能建立具有節點、條件邊和受控執行的複雜工作流。

### 它與 Semantic Kernel 的關係是什麼？
它是一個擴展，與現有的 Semantic Kernel 保持完全相容性，增加了圖協調功能，而不改變基本功能。

### 與 LangGraph 的差異是什麼？
它提供類似於 LangGraph 的功能，但專注於與 .NET 生態系統和 Semantic Kernel 的原生整合，針對企業應用進行最佳化。

## 需求與相容性

### 支援哪些 .NET 版本？
**.NET 8+** 是建議的最低版本，完全支援所有現代功能。

### 它是否與現有的 SK 程式碼相容？
**是的**，只需最少的修改。它利用現有的外掛、服務和連接器，只添加圖功能。

### 如何遷移現有的 Semantic Kernel 專案？
**遷移步驟：**
1. **添加套件參考** - 安裝 `SemanticKernel.Graph` NuGet 套件
2. **更新內核建構器** - 在 `Build()` 前添加 `AddGraphSupport()` 呼叫
3. **註冊圖服務** - 為服務註冊使用現有的 DI 容器
4. **測試整合** - 驗證外掛和服務作為圖節點的工作情況
5. **逐步採用** - 從簡單圖開始，然後增加複雜性

### 它是否需要外部服務？
**不一定**。它可以以最少配置運行，但在有遙測、記憶體和監控服務時可進行整合。

### 需要哪些配置檔案？
**無需任何**。它開箱即用，但你可以選擇使用：
- `appsettings.json` 用於環境特定的設定
- 環境變數用於敏感配置
- 自訂配置提供者用於企業部署

## 功能

### 是否支援串流？
**是的**，具有自動重新連接、智能緩衝和反壓力控制。

### 檢查點在生產環境中是否有效？
**是的**，支援持久化、壓縮、版本控制和強大的恢復。

### 是否支援平行執行？
**是的**，具有確定性排程器、併發控制和狀態合併。

### 視覺化是否支援互動？
**是的**，支援匯出到 DOT、Mermaid、JSON 和即時執行覆蓋。

## 整合與開發

### 如何與現有應用程式進行整合？
```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Integration;

// 使用基本配置添加圖支援
builder.AddGraphSupport();

// 建構內核
var kernel = builder.Build();

// 取得圖執行器工廠
var executor = kernel.GetRequiredService<IGraphExecutorFactory>();

// 針對高級配置，你也可以使用：
// builder.AddGraphSupport(options =>
// {
//     options.EnableLogging = true;
//     options.EnableMetrics = true;
//     options.MaxExecutionSteps = 100;
//     options.ExecutionTimeout = TimeSpan.FromMinutes(5);
// });
```

### 是否支援自訂外掛？
**是的**，所有現有的 SK 外掛都可作為圖節點。

### 如何除錯複雜的圖？
* **互動式除錯工作階段** - 逐步執行並檢查狀態
* **在特定節點上設置中斷點** - 條件式中斷點和執行暫停
* **即時視覺化** - 實時圖執行，節點醒目提示
* **每個節點的詳細指標** - 效能分析和瓶頸識別
* **狀態檢查** - 在執行過程中檢視和修改圖狀態
* **執行歷史** - 所有執行步驟的完整稽核軌跡
* **錯誤內容** - 詳細的錯誤資訊，包括堆疊追蹤

### 是否有測試支援？
**是的**，具有整合測試框架和用於開發的模擬。

### 常見的整合問題有哪些？
**常見問題及解決方案：**
- **找不到服務**：確保 `AddGraphSupport()` 在 `Build()` 之前被呼叫
- **配置錯誤**：檢查是否所有必需的服務都已註冊
- **記憶體問題**：如果使用記憶體功能，驗證是否呼叫了 `AddGraphMemory()`
- **檢查點失敗**：確保持久化具有適當的檔案權限

## 效能與可擴充性

### 效能開銷是多少？
**最少** - 僅限於協調所需的內容，對節點執行沒有影響。

### 如何最佳化圖效能？
**效能最佳化策略：**
- **平行執行** - 盡可能啟用併發節點執行
- **快取** - 針對重複操作使用檢查點和狀態快取
- **資源池** - 配置連接池和資源限制
- **非同步操作** - 確保所有節點都使用 async/await 模式
- **記憶體管理** - 配置適當的記憶體限制和清理間隔
- **監控** - 使用內建指標識別瓶頸

### 是否支援分散式執行？
**是的**，支援多個處理序和機器。

### 如何處理失敗？
* 可配置的重試原則
* 斷路器
* 自動回退
* 檢查點恢復

## 配置與部署

### 它是否需要特殊配置？
**否**，它可以零配置運行，但在需要時提供進階選項。

### 是否支援 Docker 容器？
**是的**，完全支援容器化環境。

### 安全考量是什麼？
**安全功能包括：**
- **密碼管理** - 與 Azure Key Vault 和環境變數的整合
- **驗證** - 支援 Azure AD、OAuth 和自訂驗證提供者
- **資料加密** - 靜態和傳輸中的敏感資料加密
- **存取控制** - 圖執行的角色型權限
- **稽核記錄** - 完整的執行稽核軌跡

### 如何在生產環境中監控？
* **原生指標**（.NET Metrics）- 內建效能計數器
* **結構化記錄** - JSON 格式化的記錄，包含相關識別碼
* **Application Insights 整合** - 具有自訂事件的 Azure 監控
* **匯出到 Prometheus/Grafana** - 開源監控堆疊支援
* **即時執行追蹤** - 實時圖執行視覺化
* **自訂遙測** - 可擴充的指標收集架構

## 支援與社群

### 在哪裡可以找到協助？
* [文件](../index.md)
* [範例](../examples/index.md)
* [GitHub Issues](https://github.com/your-org/semantic-kernel-graph/issues)
* [Discussions](https://github.com/your-org/semantic-kernel-graph/discussions)

### 如何貢獻？
* 回報錯誤
* 建議改進
* 貢獻範例
* 改進文件

### 是否有公開的路線圖？
**是的**，位於 [Roadmap](../architecture/implementation-roadmap.md)。

## 使用案例

### 它最適合哪些應用程式類型？
* **複雜的 AI 工作流** - 多步驟推理、思考鏈和代理系統
* **資料處理管道** - ETL 工作流、資料驗證和轉換鏈
* **自動化決策系統** - 業務規則引擎、核准工作流和決策樹
* **微服務協調** - 服務協調、斷路器和回退策略
* **進階聊天機器人應用** - 多輪對話、背景管理和意圖路由
* **內容生成** - 文件建立、程式碼生成和創意寫作工作流
* **品質保證** - 測試自動化、驗證管道和品質閘道

### 生產使用範例？
* 自動化文件分析
* 大規模內容分類
* 推薦系統
* 核准工作流
* 表單處理

---

## 另請參閱

* [開始使用](../getting-started.md)
* [安裝](../installation.md)
* [範例](../examples/index.md)
* [架構](../architecture/index.md)
* [故障排除](../troubleshooting.md)

## 參考資料

* [Semantic Kernel 文件](https://learn.microsoft.com/en-us/semantic-kernel/)
* [LangGraph Python](https://langchain-ai.github.io/langgraph/)
* [.NET 文件](https://docs.microsoft.com/en-us/dotnet/)

## 完整整合範例

以下是一個完整的工作範例，展示本常見問題集中描述的整合模式：

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Integration;

// 建立內核建構器
var kernelBuilder = Kernel.CreateBuilder();

// 添加基本圖支援
kernelBuilder.AddGraphSupport();

// 添加記憶體支援
kernelBuilder.AddGraphMemory();

// 使用自訂選項添加檢查點支援
kernelBuilder.AddCheckpointSupport(options =>
{
    options.EnableCompression = true;
    options.MaxCacheSize = 1000;
    options.EnableAutoCleanup = true;
    options.AutoCleanupInterval = TimeSpan.FromHours(1);
});

// 建構內核
var kernel = kernelBuilder.Build();

// 取得圖執行器工廠
var executor = kernel.GetRequiredService<IGraphExecutorFactory>();

Console.WriteLine("✅ Graph support added successfully!");
Console.WriteLine($"✅ Graph executor factory: {executor.GetType().Name}");
```

此範例展示：
- **基本圖整合**，使用 `AddGraphSupport()`
- **記憶體整合**，使用 `AddGraphMemory()`
- **檢查點支援**，使用 `AddCheckpointSupport()`
- **從建置的內核進行服務檢索**
- **適當的錯誤處理**和驗證

## 後續步驟

閱讀完本常見問題集後，你可以：

1. **開始建構** - 使用上方的整合範例將圖支援添加到你的專案
2. **探索範例** - 查看 [範例](../examples/index.md) 部分的完整工作範例
3. **學習概念** - 閱讀 [Graph 概念](../concepts/graph-concepts.md) 和 [Node 類型](../concepts/node-types.md)
4. **進階功能** - 探索 [進階模式](../examples/advanced-patterns.md) 和 [動態路由](../examples/dynamic-routing.md)
5. **取得協助** - 加入社群討論並在 GitHub 上報告問題

## 額外資源

- **API 參考** - 完整的 [API 文件](../api/core.md)
- **架構指南** - 深入了解 [系統架構](../architecture/index.md)
- **最佳實踐** - 從 [真實範例](../examples/index.md) 學習
- **效能指南** - 使用 [效能提示](../how-to/metrics-and-observability.md) 最佳化你的圖
