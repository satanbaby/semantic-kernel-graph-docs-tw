# Semantic Kernel Graph

歡迎來到 SemanticKernel.Graph 文件。本網站參考 LangGraph 文件結構，專注於精簡且實用的 .NET 實作，並完全整合於 Semantic Kernel。

## 概念與技術

**SemanticKernel.Graph**：Semantic Kernel 的擴充功能，新增了計算圖執行能力，讓您能夠建立具有智慧編排功能的複雜工作流程。

**計算圖**：透過由邊連接的節點來表示工作流程的結構，具有受控的執行和條件式路由。

**原生整合**：作為現有 Semantic Kernel 的擴充功能運作，保持完全相容性並利用現有的外掛程式和服務。

## SemanticKernel.Graph 解決的問題

### 編排問題
* **複雜工作流程**：建立具有多個步驟的 AI 管線
* **智慧路由**：基於狀態和上下文的決策
* **流程控制**：迴圈、條件式和受控迭代
* **組合**：重複使用元件和子圖

### 生產挑戰
* **可擴展性**：平行和分散式執行
* **韌性**：檢查點、重試和斷路器
* **可觀察性**：指標、記錄和即時視覺化
* **可維護性**：除錯、檢查和自動文件

## 核心功能

### **圖執行**
* 函式、條件式、推理和迴圈節點
* 具有條件和動態路由的邊
* 循序、平行和分散式執行
* 用於可重現性的確定性排程器

### **串流和事件**
* 具有即時事件的串流執行
* 自動重新連接和背壓控制
* 非同步消費執行事件
* 與訊息系統整合

### **狀態和持久性**
* 具有型別和驗證的狀態系統
* 自動和手動檢查點
* 狀態序列化和壓縮
* 執行恢復和重播

### **智慧路由**
* 基於狀態的條件式路由
* 動態和自適應策略
* 用於決策的語義相似性
* 從回饋中學習

### **人工介入**
* 人工核准節點
* 多個通道（主控台、網頁、電子郵件）
* 逾時和 SLA 政策
* 稽核和決策追蹤

### **整合和擴充性**
* 整合的 REST 工具
* 可擴充的外掛程式系統
* 與外部服務整合
* 常見工作流程的範本

## 幾分鐘內開始使用

### 1. **快速安裝**
```bash
dotnet add package SemanticKernel.Graph
```

### 2. **第一個圖**
```csharp
builder.AddGraphSupport();
var kernel = builder.Build();

// 建立圖執行器（不是 Graph 類別）
var executor = new GraphExecutor("MyGraph", "My first graph");

// 新增節點和邊
executor.AddNode(startNode);
executor.AddNode(processNode);
executor.AddNode(endNode);

executor.SetStartNode(startNode.NodeId);
executor.AddEdge(ConditionalEdge.CreateUnconditional(startNode, processNode));
executor.AddEdge(ConditionalEdge.CreateUnconditional(processNode, endNode));

// 執行圖
var result = await executor.ExecuteAsync(kernel, arguments);
```

> **重要注意事項**：SemanticKernel.Graph 函式庫使用 `GraphExecutor` 類別，而不是 `Graph` 類別。這與其他一些圖函式庫不同。`GraphExecutor` 同時作為圖定義和執行引擎。

## 文件結構

### **開始使用**
* [安裝](./installation.md) - 設定和需求
* [第一個圖](./first-graph-5-minutes.md) - 5 分鐘的 Hello World
* [快速入門](./index.md#quickstarts) - 依功能分類的快速指南

### **概念**
* [圖](./concepts/graphs.md) - 結構和元件
* [節點](./concepts/nodes.md) - 類型和生命週期
* [執行](./concepts/execution.md) - 模式和控制
* [路由](./concepts/routing.md) - 策略和條件
* [狀態](./concepts/state.md) - 管理和持久性

### **操作指南**
* [建立圖](./how-to/build-a-graph.md) - 建立和驗證
* [條件節點](./how-to/conditional-nodes.md) - 動態路由
* [檢查點](./how-to/checkpointing.md) - 持久性和恢復
* [串流](./how-to/streaming.md) - 即時執行
* [指標](./how-to/metrics-and-observability.md) - 監控

### **參考**
* [API](./api/index.md) - 完整的 API 文件
* [設定](./api/configuration.md) - 選項和參數
* [類型](./api/types.md) - 資料結構
* [擴充功能](./api/extensions.md) - 擴充方法

### **範例**
* [索引](./examples/index.md) - 所有可用的範例
* [聊天機器人](./examples/chatbot.md) - 具有記憶的對話
* [ReAct](./examples/react-agent.md) - 推理和行動
* [多代理](./examples/multi-agent.md) - 代理協調
* [文件](./examples/document-analysis-pipeline.md) - 文件分析

## 使用案例

### **AI 代理**
* 具有記憶和上下文的聊天機器人
* 推理代理（ReAct、思考鏈）
* 多個代理的協調
* 自動決策工作流程

### **文件處理**
* 自動分析和分類
* 結構化資訊擷取
* 驗證和核准管線
* 具有檢查點的批次處理

### **推薦系統**
* 基於相似性的路由
* 從使用者回饋中學習
* 條件式篩選和個人化
* 持續結果最佳化

### **微服務編排**
* API 呼叫協調
* 斷路器和重試政策
* 智慧負載平衡
* 監控和可觀察性

## 與替代方案的比較

| 功能 | SemanticKernel.Graph | LangGraph | Temporal | Durable Functions |
|---------|----------------------|-----------|----------|-------------------|
| **SK 整合** | ✅ 原生 | ❌ Python | ❌ Java/Go | ❌ Azure |
| **效能** | ✅ 原生 .NET | ⚠️ Python | ✅ JVM | ✅ Azure Runtime |
| **檢查點** | ✅ 進階 | ✅ 基本 | ✅ 強固 | ✅ 原生 |
| **串流** | ✅ 事件 | ✅ 串流 | ❌ | ⚠️ 受限 |
| **視覺化** | ✅ 即時 | ✅ 靜態 | ❌ | ❌ |
| **人工介入** | ✅ 多通道 | ⚠️ 基本 | ❌ | ❌ |

## 社群和支援

### **貢獻**
* [GitHub 儲存庫](https://github.com/kallebelins/semantic-kernel-graph-docs)
* [議題](https://github.com/kallebelins/semantic-kernel-graph-docs/issues)
* [討論](https://github.com/kallebelins/semantic-kernel-graph-docs/discussions)
* [貢獻指南](https://github.com/kallebelins/semantic-kernel-graph-docs/CONTRIBUTING.md)

### **其他資源**
* [LinkedIn](https://www.linkedin.com/company/skgraph-dev)

### **需要協助？**
* [常見問題](./faq.md) - 常見問題解答
* [疑難排解](./troubleshooting.md) - 問題解決
* [範例](./examples/index.md) - 實用範例
* [API 參考](./api/index.md) - 技術文件

## 快速入門

### **5 分鐘**
* [第一個圖](./first-graph-5-minutes.md) - 基本 Hello World
* [狀態](./state-quickstart.md) - 變數管理
* [條件式](./conditional-nodes-quickstart.md) - 簡單路由
* [串流](./streaming-quickstart.md) - 即時事件

### **15 分鐘**
* [檢查點](./checkpointing-quickstart.md) - 狀態持久性
* [指標](./metrics-logging-quickstart.md) - 基本監控
* [ReAct/CoT](./react-cot-quickstart.md) - 推理模式

### **30 分鐘**
* [條件式教學](./conditional-nodes-tutorial.md) - 進階路由
* [狀態教學](./state-tutorial.md) - 複雜管理
* [多代理](./examples/multi-agent.md) - 代理協調

---

> **提示**：本文件使用 Material for MkDocs。使用左側導覽和搜尋列快速尋找主題。

> **準備開始了嗎？** 前往[安裝](./installation.md)或[第一個圖](./first-graph-5-minutes.md)即可在幾分鐘內開始！
