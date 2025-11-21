# 範例索引

本章節提供 Semantic Kernel Graph 套件中所有可用範例的全面概述。每個範例都展示特定的功能和模式，您可以將其用作參考來構建自己的 Graph 工作流。

## 快速開始

本文件中的範例提供了 Semantic Kernel Graph 套件功能的全面示範。每個範例都包括：

* **完整的程式碼片段**，您可以複製並改編
* **逐步説明**，解釋程式碼的工作原理
* **各種場景的配置範例**
* **最佳實踐**和使用模式

瀏覽下方按類別組織的範例，為您的使用案例找到合適的起點。

## 範例類別

### 🔧 核心 Graph 模式

展示基礎 Graph 概念和執行模式的範例。

| 範例 | 說明 | 主要功能 |
|---------|-------------|--------------|
| [Chain of Thought](./chain-of-thought.md) | 具有驗證和回溯的逐步推理 | `ChainOfThoughtGraphNode`、推理類型、信心評分 |
| [Conditional Nodes](./conditional-nodes.md) | 基於條件和狀態的動態路由 | `ConditionalGraphNode`、`ConditionalEdge`、基於樣板的路由 |
| [Loop Nodes](./loop-nodes.md) | 具有退出條件的受控反覆運算 | 迴圈控制、狀態管理、反覆運算限制 |
| [Subgraphs](./subgraphs.md) | 模組化 Graph 組合和隔離 | 隔離執行、作用域狀態、Graph 組合 |

### 🤖 Agent 模式

展示不同 Agent 架構和協調策略的範例。

| 範例 | 說明 | 主要功能 |
|---------|-------------|--------------|
| [ReAct Agent](./react-agent.md) | 具有工具選擇的推理和行動迴圈 | `ReActLoopGraphNode`、工具整合、行動驗證 |
| [ReAct Problem Solving](./react-problem-solving.md) | 複雜問題分解和解決方案 | 多步驟推理、工具協調、解決方案驗證 |
| [Memory Agent](./memory-agent.md) | 跨對話的持久記憶 | 記憶整合、上下文持久性、對話歷史 |
| [Retrieval Agent](./retrieval-agent.md) | 資訊檢索和合成 | RAG 模式、文件處理、知識合成 |
| [Multi-Agent](./multi-agent.md) | 協調的多 Agent 工作流 | `MultiAgentCoordinator`、並列執行、結果彙總 |

### 🔄 高階工作流

展示複雜工作流模式和整合的範例。

| 範例 | 說明 | 主要功能 |
|---------|-------------|--------------|
| [Advanced Patterns](./advanced-patterns.md) | 複雜工作流組合 | 模式組合、進階路由、工作流協調 |
| [Advanced Routing](./advanced-routing.md) | 具有語義相似性的動態路由 | 基於嵌入的路由、機率決策、內容感知路由 |
| [Dynamic Routing](./dynamic-routing.md) | 執行時期路由決策 | 自適應路由、基於效能的決策、後備策略 |
| [Document Analysis Pipeline](./document-analysis-pipeline.md) | 多階段文件處理 | 管道協調、內容擷取、分析工作流 |
| [Multi-Hop RAG with Retry](./multi-hop-rag-retry.md) | 復原力資訊檢索 | 重試原則、斷路器、檢查點復原 |

### 💾 狀態和持久性

關注狀態管理、檢查點和資料持久性的範例。

| 範例 | 說明 | 主要功能 |
|---------|-------------|--------------|
| [State Management](./state-management.md) | Graph 狀態和引數處理 | `GraphState`、`KernelArguments`、狀態驗證 |
| [Checkpointing](./checkpointing.md) | 執行狀態持久性和復原 | `CheckpointManager`、狀態序列化、復原工作流 |
| [Streaming Execution](./streaming-execution.md) | 實時執行監視 | `StreamingGraphExecutor`、事件串流、實時更新 |

### 📊 可觀測性和偵錯

展示監視、計量和偵錯功能的範例。

| 範例 | 說明 | 主要功能 |
|---------|-------------|--------------|
| [Graph Metrics](./graph-metrics.md) | 效能監視和計量收集 | `GraphPerformanceMetrics`、執行計時、效能分析 |
| [Graph Visualization](./graph-visualization.md) | Graph 結構視覺化和匯出 | DOT/JSON/Mermaid 匯出、實時醒目提示、Graph 檢查 |
| [Logging](./logging-example.md) | 全面的記錄和追蹤 | 結構化記錄、執行追蹤、偵錯資訊 |

### 🔌 整合和擴充

展示與外部系統整合和擴充模式的範例。

| 範例 | 說明 | 主要功能 |
|---------|-------------|--------------|
| [Plugin System](./plugin-system.md) | 動態外掛程式載入和執行 | 外掛程式探索、動態載入、外掛程式協調 |
| [REST API Integration](./rest-api.md) | 透過 REST 工具進行外部 API 整合 | `RestToolGraphNode`、API 協調、外部服務整合 |
| [Assert and Suggest](./assert-suggest.md) | 驗證和建議模式 | 輸入驗證、建議生成、品質閘道 |

### 🧠 AI 和最佳化

展示 AI 特定模式和最佳化策略的範例。

| 範例 | 說明 | 主要功能 |
|---------|-------------|--------------|
| [Optimizers and Few-Shot](./optimizers-fewshot.md) | 提示詞最佳化和少次學習 | 提示詞最佳化、少次範例、效能調校 |
| [Chatbot with Memory](./chatbot.md) | 具有持久上下文的對話式 AI | 對話管理、記憶整合、上下文感知 |

## 範例複雜度等級

### 🟢 初級
* **Chain of Thought**：基本推理模式
* **Conditional Nodes**：簡單路由邏輯
* **State Management**：基本狀態處理
* **Logging**：基本可觀測性

### 🟡 中級
* **ReAct Agent**：工具整合和推理
* **Checkpointing**：狀態持久性
* **Graph Metrics**：效能監視
* **Plugin System**：動態載入

### 🔴 高級
* **Multi-Agent**：分散式協調
* **Advanced Patterns**：複雜工作流組合
* **Document Analysis**：多階段管道
* **Dynamic Routing**：自適應執行

## 執行範例

### 必要條件

1. **.NET 8.0** 或更新版本
2. **OpenAI API 金鑰**（在 `appsettings.json` 中配置）
3. **Semantic Kernel Graph 套件**已安裝

### 組態

在範例專案中建立或更新 `appsettings.json`：

```json
{
  "OpenAI": {
    "ApiKey": "your-api-key-here",
    "Model": "gpt-3.5-turbo",
    "MaxTokens": 4000,
    "Temperature": 0.7
  }
}
```

### 範例執行流程

1. **設定**：含 Graph 支援的核心組態
2. **Graph 建立**：使用 Node 和 Edge 構建 Graph 結構
3. **執行**：使用輸入引數執行 Graph
4. **監視**：觀察執行流程並收集計量
5. **結果**：處理並顯示執行結果

## 學習路徑

### 從這裡開始
1. **Chain of Thought**：理解基本推理模式
2. **Conditional Nodes**：學習動態路由
3. **State Management**：掌握狀態處理

### 構建複雜性
1. **ReAct Agent**：新增工具整合
2. **Checkpointing**：實現持久性
3. **Multi-Agent**：探索分散式工作流

### 高階模式
1. **Advanced Patterns**：複雜組合
2. **Document Analysis**：多階段管道
3. **Dynamic Routing**：自適應執行

## 貢獻範例

在貢獻新範例時：

1. **遵循模式**：使用現有範例作為樣板
2. **包含文件**：新增全面的註解和 README
3. **新增至 Program.cs**：在範例字典中註冊
4. **徹底測試**：確保範例無誤執行
5. **更新此索引**：將新範例新增至適當的類別

## 故障排除

### 常見問題

* **API 金鑰遺失**：檢查 `appsettings.json` 組態
* **套件相依性**：確保已安裝所有必需的套件
* **記憶體問題**：大型 Graph 可能需要增加記憶體限制
* **逾時錯誤**：為複雜工作流調整執行逾時

### 取得協助

* 查閱[故障排除指南](../troubleshooting.md)
* 檢閱[API 參考](../api/)以取得詳細的類別文件
* 針對特定問題在專案存放庫中開啟問題

## 相關文件

* [快速開始](../getting-started.md)：快速入門指南
* [概念](../concepts/)：核心概念和術語
* [操作指南](../how-to/)：逐步教學
* [API 參考](../api/)：完整 API 文件
* [架構](../architecture/)：系統設計和決策
