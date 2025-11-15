# 串流執行範例

本範例展示了 Semantic Kernel 圖表系統的串流執行功能，包括即時事件串流、緩衝和重新連接功能。

## 目標

學習如何在基於圖表的工作流中實現串流執行，以達到：
* 在圖表執行期間啟用即時事件串流
* 實現事件篩選和緩衝策略
* 支援長時間運行操作的網頁 API 串流
* 處理連接管理和重新連接場景
* 即時監控執行進度

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中設定
* **Semantic Kernel 圖表套件**已安裝
* 基本瞭解 [圖表概念](../concepts/graph-concepts.md) 和 [串流執行](../concepts/streaming.md)
* 熟悉 [事件串流](../concepts/events.md)

## 主要元件

### 概念和技術

* **串流執行**：圖表執行期間的即時事件串流
* **事件篩選**：根據類型和內容進行選擇性事件處理
* **緩衝串流**：事件緩衝以進行批次處理
* **網頁 API 串流**：適用於網頁應用的 HTTP 串流
* **連接管理**：處理斷線和重新連接

### 核心類別

* `StreamingGraphExecutor`：具有串流功能的執行器
* `GraphExecutionEventStream`：執行事件流
* `StreamingExtensions`：串流配置公用程式
* `GraphExecutionEvent`：個別執行事件
* `FunctionGraphNode`：工作流執行的圖表節點

## 執行範例

### 快速開始

本範例展示了 Semantic Kernel 圖表套件的串流執行和即時監控。下面的代碼片段展示了如何在您自己的應用中實現此模式。

## 分步實現

### 1. 基礎串流執行

範例以基礎串流執行開始，顯示即時事件。

```csharp
private static async Task RunBasicStreamingExample(Kernel kernel)
{
    // 使用 examples 資料夾中的可執行範例，確保代碼可以編譯和執行
    await StreamingQuickstartExample.RunAsync(kernel);
}
```

### 2. 事件篩選

範例展示了基於類型和內容篩選事件。

```csharp
// 完整、可執行的篩選範例位於：
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// 通過範例執行器運行完整情景：
await StreamingQuickstartExample.RunAsync(kernel);
```

### 3. 緩衝串流

範例展示了用於批次事件處理的緩衝串流。

```csharp
// 緩衝串流情景在以下位置實現和測試：
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// 使用範例執行器執行情景：
await StreamingQuickstartExample.RunAsync(kernel);
```

### 4. 網頁 API 串流

範例展示了網頁 API 場景的串流。

```csharp
// 網頁 API 串流範例 (SSE) 在以下位置提供和驗證：
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// 使用範例執行器執行情景：
await StreamingQuickstartExample.RunAsync(kernel);
```

### 5. 重新連接範例

範例展示了處理斷線和重新連接。

```csharp
// 重新連接處理演示在此處實現和測試：
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// 通過範例執行器執行：
await StreamingQuickstartExample.RunAsync(kernel);
```

### 6. 進階串流配置

範例展示了串流的進階配置選項。

```csharp
// 進階配置選項在可執行範例中演示：
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
await StreamingQuickstartExample.RunAsync(kernel);
```

### 7. 事件處理和管理

範例展示了全面的事件處理。

```csharp
// 完整的事件處理和管理在可執行範例中提供。
// 執行此範例以查看完整的事件處理邏輯和輸出：
await StreamingQuickstartExample.RunAsync(kernel);
```

## 預期輸出

該範例產生全面的輸出，顯示：

* 📡 具有即時事件的基礎串流執行
* 🔍 按類型和內容進行事件篩選
* 📦 用於批次處理的緩衝串流
* 🌐 採用 SSE 格式的網頁 API 串流
* 🔌 重新連接處理和恢復
* ⚡ 即時執行監控
* ✅ 完整的串流工作流執行

## 疑難排解

### 常見問題

1. **串流連接失敗**：檢查網路連接和串流配置
2. **事件處理錯誤**：驗證事件類型處理和錯誤管理
3. **緩衝問題**：調整緩衝區大小和超時設定
4. **重新連接失敗**：配置重新連接選項和重試邏輯

### 偵錯提示

* 為串流操作啟用詳細日誌記錄
* 監控事件流健康狀況和連接狀態
* 驗證事件篩選和緩衝配置
* 檢查重新連接設定和錯誤處理

## 另請參閱

* [串流執行](../concepts/streaming.md)
* [事件串流](../concepts/events.md)
* [網頁 API 整合](../how-to/exposing-rest-apis.md)
* [即時監控](../how-to/metrics-and-observability.md)
* [連接管理](../how-to/connection-management.md)
