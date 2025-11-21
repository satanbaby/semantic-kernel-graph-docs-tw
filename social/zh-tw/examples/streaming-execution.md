# Streaming Execution 示例

此示例展示 Semantic Kernel Graph 系統的串流執行功能，包括即時事件串流、緩衝和重新連接功能。

## 目標

學習如何在基於 Graph 的工作流程中實現串流執行，以便：
* 在 Graph 執行期間啟用即時事件串流
* 實現事件篩選和緩衝策略
* 支援長時間運行操作的 Web API 串流
* 處理連接管理和重新連接情況
* 即時監控執行進度

## 前置條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 對 [Graph 概念](../concepts/graph-concepts.md) 和 [Streaming 執行](../concepts/streaming.md) 的基本認識
* 熟悉 [事件串流](../concepts/events.md)

## 關鍵元件

### 概念和技術

* **Streaming 執行**：Graph 執行期間的即時事件串流
* **事件篩選**：基於類型和內容的選擇性事件處理
* **緩衝串流**：用於批次處理的事件緩衝
* **Web API 串流**：用於 Web 應用程式的 HTTP 串流
* **連接管理**：處理斷開連接和重新連接

### 核心類別

* `StreamingGraphExecutor`：具有串流功能的執行器
* `GraphExecutionEventStream`：執行事件的串流
* `StreamingExtensions`：串流配置實用程式
* `GraphExecutionEvent`：個別執行事件
* `FunctionGraphNode`：用於工作流程執行的 Graph 節點

## 執行示例

### 快速開始

此示例展示使用 Semantic Kernel Graph 套件進行串流執行和即時監控。下面的程式碼片段顯示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本串流執行

該示例從基本串流執行開始，展示即時事件。

```csharp
private static async Task RunBasicStreamingExample(Kernel kernel)
{
    // Use the runnable example in the examples folder to ensure code compiles and runs
    await StreamingQuickstartExample.RunAsync(kernel);
}
```

### 2. 事件篩選

該示例展示根據類型和內容篩選事件。

```csharp
// The full, runnable filtering example is available in:
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// Run the complete scenario via the examples runner:
await StreamingQuickstartExample.RunAsync(kernel);
```

### 3. 緩衝串流

該示例展示用於批次事件處理的緩衝串流。

```csharp
// The buffered streaming scenario is implemented and tested in:
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// Execute the scenario using the examples runner:
await StreamingQuickstartExample.RunAsync(kernel);
```

### 4. Web API 串流

該示例展示 Web API 情況下的串流。

```csharp
// Web API streaming example (SSE) is provided and validated in:
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// Use the examples runner to execute the scenario:
await StreamingQuickstartExample.RunAsync(kernel);
```

### 5. 重新連接示例

該示例展示處理斷開連接和重新連接。

```csharp
// Reconnection handling demo is implemented and tested here:
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
// Execute it via the examples runner:
await StreamingQuickstartExample.RunAsync(kernel);
```

### 6. 進階串流配置

該示例展示串流的進階配置選項。

```csharp
// Advanced configuration options are demonstrated in the runnable example:
// `semantic-kernel-graph-docs/examples/StreamingQuickstartExample.cs`
await StreamingQuickstartExample.RunAsync(kernel);
```

### 7. 事件處理和管理

該示例展示全面的事件處理。

```csharp
// Example event processing and handling is available in the runnable example.
// Run the sample to see complete event handling logic and outputs:
await StreamingQuickstartExample.RunAsync(kernel);
```

## 預期輸出

該示例產生全面的輸出，顯示：

* 📡 具有即時事件的基本串流執行
* 🔍 按類型和內容進行事件篩選
* 📦 用於批次處理的緩衝串流
* 🌐 具有 SSE 格式的 Web API 串流
* 🔌 重新連接處理和復原
* ⚡ 即時執行監控
* ✅ 完整的串流工作流程執行

## 故障排查

### 常見問題

1. **串流連接失敗**：檢查網路連接和串流配置
2. **事件處理錯誤**：驗證事件類型處理和錯誤管理
3. **緩衝問題**：調整緩衝區大小和超時設定
4. **重新連接失敗**：配置重新連接選項和重試邏輯

### 調試技巧

* 為串流操作啟用詳細日誌記錄
* 監控事件串流健康狀況和連接狀態
* 驗證事件篩選和緩衝配置
* 檢查重新連接設定和錯誤處理

## 另請參閱

* [Streaming 執行](../concepts/streaming.md)
* [事件串流](../concepts/events.md)
* [Web API 整合](../how-to/exposing-rest-apis.md)
* [即時監控](../how-to/metrics-and-observability.md)
* [連接管理](../how-to/connection-management.md)
