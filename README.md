# Semantic Kernel Graph 套件

一個功能強大且可擴展的圖形式執行框架，建立在微軟的 Semantic Kernel 之上，專為構建複雜的 AI 工作流程、多代理系統和智能應用程式而設計。

在網站上瀏覽文件：[skgraph.dev](https://skgraph.dev/)

## 🚀 功能特性

### 核心功能
- **圖形式執行**：將複雜的 AI 工作流程定義為具有節點和邊的有向圖
- **有狀態編排**：跨節點共享的類型化狀態，包含驗證和序列化
- **動態路由**：由數據和模型輸出驅動的條件邊和智能路由
- **檢查點和恢復**：從任何位置恢復執行，並完全保留狀態
- **流式執行**：實時事件和監控，適用於交互式應用
- **人工在迴圈中**：內置的批准、干預和反饋工作流程

### 進階模式
- **思維鏈**和 **ReAct**：結構化推理和工具使用工作流程
- **多跳 RAG**，包含重試和護欄
- **條件執行**和**並行分支合併**模式

### 企業功能
- **可觀測性**：指標、日誌和實時可視化
- **錯誤策略**：重試、退避和補償
- **資源治理**：並發限制、速率限制和成本控制
- **安全性**：數據和密鑰處理、身份驗證和策略集成

## 🧭 文件

線上文件：[skgraph.dev](https://skgraph.dev/)

### 開始使用
- [概述](docs/getting-started.md)
- [安裝](docs/installation.md)
- [第一個圖形](docs/first-graph.md)
- 快速入門：
  - [5 分鐘內建立第一個圖形](docs/first-graph-5-minutes.md)
  - [狀態管理](docs/state-quickstart.md)
  - [條件節點](docs/conditional-nodes-quickstart.md)
  - [檢查點](docs/checkpointing-quickstart.md)
  - [流式處理](docs/streaming-quickstart.md)
  - [指標和日誌](docs/metrics-logging-quickstart.md)
  - [ReAct 和思維鏈](docs/react-cot-quickstart.md)
- 教程：
  - [狀態管理](docs/state-tutorial.md)
  - [條件節點](docs/conditional-nodes-tutorial.md)

### 核心概念
- [概述](docs/concepts/index.md)
- [圖形概念](docs/concepts/graph-concepts.md)
- [圖形](docs/concepts/graphs.md)
- [節點](docs/concepts/nodes.md)
- [節點類型](docs/concepts/node-types.md)
- [狀態](docs/concepts/state.md)
- [邊和路由](docs/concepts/routing.md)
- [執行](docs/concepts/execution.md)
- [執行模型](docs/concepts/execution-model.md)
- [檢查點](docs/concepts/checkpointing.md)
- [流式處理](docs/concepts/streaming.md)
- [可視化](docs/concepts/visualization.md)

### 操作指南
- 核心：
  - [構建圖形](docs/how-to/build-a-graph.md)
  - [條件節點](docs/how-to/conditional-nodes.md)
  - [迴圈](docs/how-to/loops.md)
- 進階：
  - [進階路由](docs/how-to/advanced-routing.md)
  - [並行處理（分支合併）](docs/how-to/parallelism-and-fork-join.md)
  - [錯誤處理和復原能力](docs/how-to/error-handling-and-resilience.md)
- 整合：
  - [工具](docs/how-to/tools.md)
  - [REST 工具整合](docs/how-to/rest-tools-integration.md)
  - [多代理和共享狀態](docs/how-to/multi-agent-and-shared-state.md)
  - [整合和擴展](docs/how-to/integration-and-extensions.md)
- 可觀測性：
  - [指標](docs/how-to/metrics-and-observability.md)
  - [調試和檢查](docs/how-to/debug-and-inspection.md)
  - [實時可視化](docs/how-to/real-time-visualization-and-highlights.md)
- 安全和治理：
  - [安全和數據](docs/how-to/security-and-data.md)
  - [資源治理和並發](docs/how-to/resource-governance-and-concurrency.md)
  - [人工在迴圈中](docs/how-to/human-in-the-loop.md)
- 伺服器和 API：
  - [伺服器和 API](docs/how-to/server-and-apis.md)
  - [公開 REST API](docs/how-to/exposing-rest-apis.md)
- 模板和類型：
  - [模板和記憶體](docs/how-to/templates-and-memory.md)
  - [架構類型和驗證](docs/how-to/schema-typing-and-validation.md)

## 🛠️ 安裝

### 必要條件
* .NET 8.0 或更新版本
* Semantic Kernel SDK
* 選項：Azure OpenAI、OpenAI 或其他 AI 服務認證

## 🔧 使用方式

### 基本圖形定義
```csharp
var graph = new GraphBuilder()
    .AddNode("start", new ActionNode("Initialize workflow"))
    .AddNode("process", new ActionNode("Process data"))
    .AddNode("decision", new ConditionalNode("Make decision"))
    .AddNode("complete", new ActionNode("Complete workflow"))
    
    .AddEdge("start", "process")
    .AddEdge("process", "decision")
    .AddEdge("decision", "complete", "success")
    
    .Build();

var executor = new GraphExecutor();
var result = await executor.ExecuteAsync(graph, context);
```

### 進階多代理工作流程
```csharp
var workflow = new MultiAgentWorkflowBuilder()
    .AddAgent("researcher", new ResearchAgent())
    .AddAgent("analyst", new AnalysisAgent())
    .AddAgent("writer", new WritingAgent())
    
    .DefineWorkflow(workflow => workflow
        .StartWith("researcher")
        .Then("analyst")
        .Then("writer")
        .WithHumanApproval("final_review")
    )
    
    .Build();
```

## 📊 範例

`examples/` 目錄中有一個完整的 .NET 範例專案，對應於文件範例。

執行先決條件：
- .NET 8.0 SDK 或更新版本
- 選項：設定 `OPENAI_API_KEY`（或提供商環境變數）以執行 LLM 支援的演示

從儲存庫根目錄執行範例：

```powershell
cd examples
dotnet run            # 執行所有範例
dotnet run -- first-graph
dotnet run -- conditional-nodes-quickstart
dotnet run -- streaming-quickstart
dotnet run -- multi-agent
```

常見的範例名稱（完整清單請參見 `examples/Program.cs`）：
`first-graph`, `first-graph-5-minutes`, `getting-started`, `state-quickstart`, `state-tutorial`, `conditional-nodes-quickstart`, `conditional-nodes-tutorial`, `checkpointing-quickstart`, `streaming-quickstart`, `metrics-logging-quickstart`, `dynamic-routing`, `advanced-routing`, `graph-executor`, `graph-options`, `executors-and-middlewares`, `inspection-visualization`, `debug-inspection`, `logging`, `graph-metrics`, `graph-visualization`, `multi-agent`, `chain-of-thought`, `react-cot-quickstart`, `react-agent`, `rest-api`, `rest-tools`, `plugin-system`, `document-analysis-pipeline`, `memory-agent`, `retrieval-agent`, `multi-hop-rag-retry`, `optimizers-and-few-shot`, `validation-compilation`, `error-policies`, `schema-typing-and-validation`, `resource-governance`, `parallelism-and-fork-join`.

範例文件：`docs/examples/`
- 核心模式：[條件節點](docs/examples/conditional-nodes.md)、[迴圈](docs/examples/loop-nodes.md)、[檢查點](docs/examples/checkpointing.md)
- AI 模式：[思維鏈](docs/examples/chain-of-thought.md)、[ReAct](docs/examples/react-agent.md)、[多代理](docs/examples/multi-agent.md)
- 進階功能：[進階模式](docs/examples/advanced-patterns.md)、[進階路由](docs/examples/advanced-routing.md)、[動態路由](docs/examples/dynamic-routing.md)
- 整合：[REST API](docs/examples/rest-api.md)、[外掛系統](docs/examples/plugin-system.md)、[工具](docs/examples/tools.md)
- 可觀測性：[指標](docs/examples/graph-metrics.md)、[可視化](docs/examples/graph-visualization.md)、[日誌](docs/examples/logging.md)
- 工作流程：[聊天機器人](docs/examples/chatbot.md)、[文件分析](docs/examples/document-analysis-pipeline.md)、[檢索代理](docs/examples/retrieval-agent.md)
- 特殊：[記憶體代理](docs/examples/memory-agent.md)、[多跳 RAG 重試](docs/examples/multi-hop-rag-retry.md)、[最佳化器和少量示例](docs/examples/optimizers-and-few-shot.md)、[斷言和建議](docs/examples/assert-and-suggest.md)、[子圖形](docs/examples/subgraph-examples.md)、[流式執行](docs/examples/streaming-execution.md)
- 模板：[模板標準部分](docs/examples/template-standard-sections.md)、[執行指南](docs/examples/execution-guide.md)

## 📖 API 參考

主要參考頁面（完整清單請參見 `docs/api/`）：
- 核心：[core.md](docs/api/core.md)、[nodes.md](docs/api/nodes.md)、[extensions.md](docs/api/extensions.md)、[extensions-and-options.md](docs/api/extensions-and-options.md)
- 整合：[integration.md](docs/api/integration.md)、[rest-tools.md](docs/api/rest-tools.md)、[server-apis.md](docs/api/server-apis.md)
- 執行和工具：[graph-executor.md](docs/api/graph-executor.md)、[executors-and-middlewares.md](docs/api/executors-and-middlewares.md)、[execution-context.md](docs/api/execution-context.md)
- 選項和策略：[graph-options.md](docs/api/graph-options.md)、[error-policies.md](docs/api/error-policies.md)
- 功能：[human-in-the-loop.md](docs/api/human-in-the-loop.md)、[visualization-realtime.md](docs/api/visualization-realtime.md)、[inspection-visualization.md](docs/api/inspection-visualization.md)
- 模式：[dynamic-routing.md](docs/api/dynamic-routing.md)、[conditional-edge.md](docs/api/conditional-edge.md)
- 類型和狀態：[state-and-serialization.md](docs/api/state-and-serialization.md)、[streaming.md](docs/api/streaming.md)
- 代理和驗證：[multi-agent.md](docs/api/multi-agent.md)、[validation-compilation.md](docs/api/validation-compilation.md)
- 其他：[additional-utilities.md](docs/api/additional-utilities.md)、[main-node-types.md](docs/api/main-node-types.md)、[igraph-executor.md](docs/api/igraph-executor.md)、[igraph-node.md](docs/api/igraph-node.md)、[metrics.md](docs/api/metrics.md)

## 📦 在應用程式中安裝（NuGet）

在 .NET 應用程式中安裝套件：

```powershell
dotnet add package SemanticKernel.Graph
dotnet add package Microsoft.SemanticKernel
```

然後按照上述指南建立並執行圖形。

## 🔍 故障排除和資源
- [詞彙表](docs/glossary.md)
- [遷移](docs/migrations/index.md)
- [故障排除](docs/troubleshooting.md)
- [常見問題](docs/faq.md)
- [變更日誌](docs/changelog.md)

## 🤝 貢獻

歡迎對文件和範例進行貢獻。請在儲存庫上開啟議題或提交拉取請求。
- 儲存庫：`https://github.com/kallebelins/semantic-kernel-graph-docs`
- 議題：`https://github.com/kallebelins/semantic-kernel-graph-docs/issues`

## 📄 授權

根據 MIT 授權授權。

## 🙏 致謝

* 建立在 [Microsoft Semantic Kernel](https://github.com/microsoft/semantic-kernel) 之上
* 受現代工作流程編排模式啟發
* 社群貢獻和反饋

## 📞 支援和社群

- 網站：[skgraph.dev](https://skgraph.dev/)
- 文件：`docs/`
- 範例：`examples/`
- LinkedIn：`https://www.linkedin.com/company/skgraph-dev/`

---

**準備好建立智能工作流程了嗎？** 從[5 分鐘內建立第一個圖形](docs/first-graph-5-minutes.md)開始，探索 Semantic Kernel Graph！
