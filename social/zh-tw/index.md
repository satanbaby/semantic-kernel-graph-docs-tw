# Semantic Kernel Graph

歡迎來到 SemanticKernel.Graph 文件。本網站鏡像 LangGraph 的文件結構，重點關注精實且務實的 .NET 實現，完全整合於 Semantic Kernel。

## 概念與技術

**SemanticKernel.Graph**：Semantic Kernel 的擴展，增加了計算圖執行功能，讓你能夠建立具有智慧編排的複雜工作流程。

**Computational Graphs**：代表工作流程的結構，通過由 Edge 連接的 Node 組成，具有受控執行和條件路由。

**Native Integration**：作為現有 Semantic Kernel 的擴展運作，保持完全相容性並發揮現有外掛程式和服務的優勢。

## SemanticKernel.Graph 解決的問題

### 編排問題
* **複雜工作流程**：建立具有多個步驟的 AI 管道
* **智慧路由**：基於狀態和上下文的決策
* **流程控制**：迴圈、條件和受控迭代
* **組合**：元件和子圖的重複使用

### 生產挑戰
* **可擴展性**：平行和分散式執行
* **恢復力**：檢查點、重試和斷路器
* **可觀測性**：指標、日誌和即時可視化
* **可維護性**：除錯、檢查和自動文件

## 核心功能

### **Graph 執行**
* Function、條件、推理和迴圈 Node
* 具有條件和動態路由的 Edge
* 循序、平行和分散式執行
* 用於可重現性的確定性調度器

### **Streaming 和事件**
* 具有即時事件的 Streaming 執行
* 自動重新連接和背壓控制
* 執行事件的非同步消費
* 與訊息系統的整合

### **狀態和持久性**
* 型別化和驗證的狀態系統
* 自動和手動檢查點
* 狀態序列化和壓縮
* 執行恢復和重放

### **智慧路由**
* 基於狀態的條件路由
* 動態和自適應策略
* 語義相似度用於決策
* 從回饋中學習

### **人在迴圈中**
* 人工核准 Node
* 多個頻道（主控台、網路、電子郵件）
* 逾時和 SLA 原則
* 稽核和決策追蹤

### **整合和擴展性**
* 整合 REST 工具
* 可擴展的外掛程式系統
* 與外部服務的整合
* 常見工作流程的範本

## 幾分鐘內開始

### 1. **快速安裝**
```bash
dotnet add package SemanticKernel.Graph
```

### 2. **第一個 Graph**
```csharp
builder.AddGraphSupport();
var kernel = builder.Build();

// Create graph executor (not a Graph class)
var executor = new GraphExecutor("MyGraph", "My first graph");

// Add nodes and edges
executor.AddNode(startNode);
executor.AddNode(processNode);
executor.AddNode(endNode);

executor.SetStartNode(startNode.NodeId);
executor.AddEdge(ConditionalEdge.CreateUnconditional(startNode, processNode));
executor.AddEdge(ConditionalEdge.CreateUnconditional(processNode, endNode));

// Execute the graph
var result = await executor.ExecuteAsync(kernel, arguments);
```

> **重要提示**：SemanticKernel.Graph 程式庫使用 `GraphExecutor` 類別，而不是 `Graph` 類別。這與某些其他圖形程式庫不同。`GraphExecutor` 同時作為圖形定義和執行引擎。

## 文件結構

### **開始使用**
* [安裝](./installation.md) - 設定和需求
* [第一個 Graph](./first-graph-5-minutes.md) - 5 分鐘內的 Hello World
* [快速入門](./index.md#quickstarts) - 按功能快速指南

### **概念**
* [Graphs](./concepts/graphs.md) - 結構和元件
* [Nodes](./concepts/nodes.md) - 型別和生命週期
* [執行](./concepts/execution.md) - 模式和控制
* [路由](./concepts/routing.md) - 策略和條件
* [狀態](./concepts/state.md) - 管理和持久性

### **如何指南**
* [建立 Graphs](./how-to/build-a-graph.md) - 建立和驗證
* [條件 Nodes](./how-to/conditional-nodes.md) - 動態路由
* [檢查點](./how-to/checkpointing.md) - 持久性和恢復
* [Streaming](./how-to/streaming.md) - 即時執行
* [指標](./how-to/metrics-and-observability.md) - 監控

### **參考**
* [APIs](./api/index.md) - 完整 API 文件
* [設定](./api/configuration.md) - 選項和參數
* [型別](./api/types.md) - 資料結構
* [擴展](./api/extensions.md) - 擴展方法

### **範例**
* [索引](./examples/index.md) - 所有可用的範例
* [聊天機器人](./examples/chatbot.md) - 具有記憶的對話
* [ReAct](./examples/react-agent.md) - 推理和動作
* [多代理](./examples/multi-agent.md) - 代理協調
* [文件](./examples/document-analysis-pipeline.md) - 文件分析

## 使用案例

### **AI 代理**
* 具有記憶和上下文的聊天機器人
* 推理代理（ReAct、思維鏈）
* 多個代理的協調
* 自動化決策工作流程

### **文件處理**
* 自動分析和分類
* 結構化資訊提取
* 驗證和核准管道
* 具有檢查點的批次處理

### **推薦系統**
* 基於相似度的路由
* 從使用者回饋中學習
* 條件篩選和個人化
* 連續結果最佳化

### **微服務編排**
* API 呼叫協調
* 斷路器和重試原則
* 智慧負載平衡
* 監控和可觀測性

## 與替代方案的比較

| 功能 | SemanticKernel.Graph | LangGraph | Temporal | Durable Functions |
|---------|----------------------|-----------|----------|-------------------|
| **SK 整合** | ✅ 本機 | ❌ Python | ❌ Java/Go | ❌ Azure |
| **效能** | ✅ 本機 .NET | ⚠️ Python | ✅ JVM | ✅ Azure Runtime |
| **檢查點** | ✅ 進階 | ✅ 基本 | ✅ 穩健 | ✅ 本機 |
| **Streaming** | ✅ 事件 | ✅ Streaming | ❌ | ⚠️ 受限 |
| **可視化** | ✅ 即時 | ✅ 靜態 | ❌ | ❌ |
| **HITL** | ✅ 多頻道 | ⚠️ 基本 | ❌ | ❌ |

## 社群和支援

### **貢獻**
* [GitHub 存放庫](https://github.com/kallebelins/semantic-kernel-graph-docs)
* [議題](https://github.com/kallebelins/semantic-kernel-graph-docs/issues)
* [討論](https://github.com/kallebelins/semantic-kernel-graph-docs/discussions)
* [貢獻指南](https://github.com/kallebelins/semantic-kernel-graph-docs/CONTRIBUTING.md)

### **其他資源**
* [LinkedIn](https://www.linkedin.com/company/skgraph-dev)

### **需要幫助？**
* [FAQ](./faq.md) - 常見問題
* [疑難排解](./troubleshooting.md) - 問題解決
* [範例](./examples/index.md) - 實際範例
* [API 參考](./api/index.md) - 技術文件

## 快速入門

### **5 分鐘**
* [第一個 Graph](./first-graph-5-minutes.md) - 基本 Hello World
* [狀態](./state-quickstart.md) - 變數管理
* [條件](./conditional-nodes-quickstart.md) - 簡單路由
* [Streaming](./streaming-quickstart.md) - 即時事件

### **15 分鐘**
* [檢查點](./checkpointing-quickstart.md) - 狀態持久性
* [指標](./metrics-logging-quickstart.md) - 基本監控
* [ReAct/CoT](./react-cot-quickstart.md) - 推理模式

### **30 分鐘**
* [條件教學](./conditional-nodes-tutorial.md) - 進階路由
* [狀態教學](./state-tutorial.md) - 複雜管理
* [多代理](./examples/multi-agent.md) - 代理協調

---

> **提示**：本文件使用 Material for MkDocs。使用左側導覽和搜尋欄快速找到主題。

> **準備好開始了嗎？** 前往[安裝](./installation.md)或[第一個 Graph](./first-graph-5-minutes.md)在幾分鐘內開始！
