# Semantic Kernel Graph

歡迎來到 SemanticKernel.Graph 文件。本網站參照 LangGraph 文件結構，專注於一個精實且務實的 .NET 實現，完全與 Semantic Kernel 整合。

## 概念和技術

**SemanticKernel.Graph**：Semantic Kernel 的擴展，添加計算圖執行功能，允許您創建具有智慧協調的複雜工作流程。

**計算圖**：通過節點連接邊的結構，代表工作流程，具有受控執行和條件路由。

**原生整合**：作為現有 Semantic Kernel 的擴展工作，保持完全相容性並利用現有插件和服務。

## SemanticKernel.Graph 解決的問題

### 協調問題
* **複雜工作流程**：創建具有多個步驟的 AI 管線
* **智慧路由**：基於狀態和上下文的決策
* **流程控制**：迴圈、條件和受控迭代
* **組合**：重用元件和子圖

### 生產挑戰
* **可擴展性**：並行和分散式執行
* **韌性**：檢查點、重試和熔斷器
* **可觀測性**：指標、日誌和即時可視化
* **可維護性**：調試、檢查和自動文件

## 核心功能

### **圖執行**
* 函數、條件、推理和迴圈節點
* 邊緣條件和動態路由
* 順序、並行和分散式執行
* 確定性排程器，確保可重複性

### **流式傳輸和事件**
* 具有即時事件的流式執行
* 自動重新連接和背壓控制
* 非同步消費執行事件
* 與消息傳遞系統整合

### **狀態和持久化**
* 類型化和驗證的狀態系統
* 自動和手動檢查點
* 狀態序列化和壓縮
* 執行恢復和重放

### **智慧路由**
* 基於狀態的條件路由
* 動態和自適應策略
* 決策的語義相似性
* 從反饋中學習

### **人在迴圈中**
* 人工批准節點
* 多個通道（控制台、網絡、電子郵件）
* 逾時和 SLA 政策
* 稽核和決策追蹤

### **整合和擴展性**
* 整合 REST 工具
* 可擴展的插件系統
* 與外部服務整合
* 常見工作流程的範本

## 在幾分鐘內開始

### 1. **快速安裝**
```bash
dotnet add package SemanticKernel.Graph
```

### 2. **第一個圖**
```csharp
builder.AddGraphSupport();
var kernel = builder.Build();

// 創建圖執行器（不是 Graph 類別）
var executor = new GraphExecutor("MyGraph", "My first graph");

// 添加節點和邊
executor.AddNode(startNode);
executor.AddNode(processNode);
executor.AddNode(endNode);

executor.SetStartNode(startNode.NodeId);
executor.AddEdge(ConditionalEdge.CreateUnconditional(startNode, processNode));
executor.AddEdge(ConditionalEdge.CreateUnconditional(processNode, endNode));

// 執行圖
var result = await executor.ExecuteAsync(kernel, arguments);
```

> **重要注意**：SemanticKernel.Graph 函式庫使用 `GraphExecutor` 類別，而不是 `Graph` 類別。這與某些其他圖形函式庫不同。`GraphExecutor` 既作為圖定義又作為執行引擎。

## 文件結構

### **開始使用**
* [安裝](./installation.md) - 設置和要求
* [第一個圖](./first-graph-5-minutes.md) - 5 分鐘 Hello World
* [快速指南](./index.md#quickstarts) - 按功能的快速指南

### **概念**
* [圖](./concepts/graphs.md) - 結構和元件
* [節點](./concepts/nodes.md) - 類型和生命週期
* [執行](./concepts/execution.md) - 模式和控制
* [路由](./concepts/routing.md) - 策略和條件
* [狀態](./concepts/state.md) - 管理和持久化

### **操作指南**
* [構建圖](./how-to/build-a-graph.md) - 創建和驗證
* [條件節點](./how-to/conditional-nodes.md) - 動態路由
* [檢查點](./how-to/checkpointing.md) - 持久化和恢復
* [流式傳輸](./how-to/streaming.md) - 即時執行
* [指標](./how-to/metrics-and-observability.md) - 監控

### **參考**
* [API](./api/index.md) - 完整 API 文件
* [配置](./api/configuration.md) - 選項和參數
* [類型](./api/types.md) - 資料結構
* [延伸](./api/extensions.md) - 延伸方法

### **示例**
* [索引](./examples/index.md) - 所有可用示例
* [聊天機器人](./examples/chatbot.md) - 具有記憶的交談
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
* 結構化資訊提取
* 驗證和批准管線
* 具有檢查點的批量處理

### **推薦系統**
* 基於相似性的路由
* 從使用者反饋中學習
* 條件篩選器和個人化
* 持續結果優化

### **微服務協調**
* API 呼叫協調
* 熔斷器和重試政策
* 智慧負載平衡
* 監控和可觀測性

## 與替代方案的比較

| 功能 | SemanticKernel.Graph | LangGraph | Temporal | Durable Functions |
|---------|----------------------|-----------|----------|-------------------|
| **SK 整合** | ✅ 原生 | ❌ Python | ❌ Java/Go | ❌ Azure |
| **效能** | ✅ 原生 .NET | ⚠️ Python | ✅ JVM | ✅ Azure 執行時 |
| **檢查點** | ✅ 高級 | ✅ 基本 | ✅ 穩健 | ✅ 原生 |
| **流式傳輸** | ✅ 事件 | ✅ 流式傳輸 | ❌ | ⚠️ 有限 |
| **可視化** | ✅ 即時 | ✅ 靜態 | ❌ | ❌ |
| **HITL** | ✅ 多個通道 | ⚠️ 基本 | ❌ | ❌ |

## 社群和支持

### **貢獻**
* [GitHub 儲存庫](https://github.com/kallebelins/semantic-kernel-graph-docs)
* [問題](https://github.com/kallebelins/semantic-kernel-graph-docs/issues)
* [討論](https://github.com/kallebelins/semantic-kernel-graph-docs/discussions)
* [貢獻指南](https://github.com/kallebelins/semantic-kernel-graph-docs/CONTRIBUTING.md)

### **其他資源**
* [LinkedIn](https://www.linkedin.com/company/skgraph-dev)

### **需要幫助？**
* [常見問題](./faq.md) - 常見問題
* [疑難排解](./troubleshooting.md) - 問題解決
* [示例](./examples/index.md) - 實際示例
* [API 參考](./api/index.md) - 技術文件

## 快速指南

### **5 分鐘**
* [第一個圖](./first-graph-5-minutes.md) - 基本 Hello World
* [狀態](./state-quickstart.md) - 變數管理
* [條件](./conditional-nodes-quickstart.md) - 簡單路由
* [流式傳輸](./streaming-quickstart.md) - 即時事件

### **15 分鐘**
* [檢查點](./checkpointing-quickstart.md) - 狀態持久化
* [指標](./metrics-logging-quickstart.md) - 基本監控
* [ReAct/CoT](./react-cot-quickstart.md) - 推理模式

### **30 分鐘**
* [條件教學](./conditional-nodes-tutorial.md) - 進階路由
* [狀態教學](./state-tutorial.md) - 複雜管理
* [多代理](./examples/multi-agent.md) - 代理協調

---

> **提示**：本文件使用 Material for MkDocs。使用左側導航和搜尋欄快速查找主題。

> **準備好開始了嗎？** 進入[安裝](./installation.md)或[第一個圖](./first-graph-5-minutes.md)在幾分鐘內開始！
