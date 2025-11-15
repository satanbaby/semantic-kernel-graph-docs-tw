# 開始使用 SemanticKernel.Graph

歡迎使用 SemanticKernel.Graph，這是一個強大的 .NET 函式庫，為 Microsoft 的 Semantic Kernel 生態系統帶來基於圖的工作流程的靈活性和強大功能。本指南將協助您了解什麼是 SemanticKernel.Graph、它解決的問題，以及它與 Semantic Kernel 和 LangGraph 的關係。

## 什麼是 SemanticKernel.Graph？

SemanticKernel.Graph 是一個可用於生產環境的 .NET 函式庫，讓您能夠使用有向圖建立複雜的、具狀態的 AI 工作流程。它擴充了 Microsoft 的 Semantic Kernel，提供進階的編排能力，讓您能夠建立精密的 AI 代理、多步驟推理工作流程和智慧自動化系統。

### 主要功能

* **圖基礎工作流程**：使用節點和條件式邊來設計複雜的 AI 工作流程
* **原生 Semantic Kernel 整合**：無縫使用現有的 SK 外掛程式、記憶體和連接器
* **狀態管理**：在工作流程執行過程中維護上下文和狀態
* **條件式邏輯**：基於 AI 回應和狀態實作動態路由
* **串流執行**：即時監控和事件串流
* **檢查點與恢復**：從任何點恢復工作流程並持久化狀態
* **視覺化與除錯**：內建工具用於理解和疑難排解工作流程
* **多代理協調**：在複雜情境中編排多個 AI 代理

## SemanticKernel.Graph 解決的問題

### 1. **複雜的 AI 工作流程編排**
傳統的 AI 應用程式通常循序執行函式，無法做出決策或處理複雜的分支邏輯。SemanticKernel.Graph 讓您能夠建立智慧工作流程，可以：
* 基於 AI 回應做出決策
* 處理多個執行路徑
* 實作重試邏輯和錯誤恢復
* 協調多個 AI 代理

### 2. **跨 AI 互動的狀態管理**
在多個 AI 函式呼叫之間維護上下文具有挑戰性。SemanticKernel.Graph 提供：
* 具有版本控制的持久性狀態管理
* 自動狀態序列化和檢查點
* 狀態驗證和完整性檢查
* 工作流程步驟之間的高效狀態共享

### 3. **動態 AI 代理行為**
建立能夠根據上下文調整其行為的 AI 代理需要精密的編排。使用 SemanticKernel.Graph，您可以：
* 實作 ReAct（推理 + 行動）模式
* 建立思考鏈推理工作流程
* 建構從先前互動中學習的代理
* 處理人工介入情境

### 4. **生產就緒的 AI 工作流程**
建立企業級 AI 應用程式需要強固的錯誤處理、監控和可擴展性。SemanticKernel.Graph 提供：
* 全面的錯誤處理和恢復
* 效能指標和可觀察性
* 資源治理和速率限制
* 分散式執行能力

## 與 Semantic Kernel 的關係

SemanticKernel.Graph 是**建構於** Semantic Kernel 之上，而非取代它。它擴充了現有的 SK 生態系統，提供圖編排能力，同時保持與以下元件的完全相容性：

### **現有的 SK 元件**
* **外掛程式**：所有現有的 SK 外掛程式都可以作為圖節點運作
* **記憶體**：向量和語義記憶體系統無縫整合
* **連接器**：OpenAI、Azure OpenAI 和其他 LLM 提供者保持不變
* **範本**：Handlebars 和其他範本系統保持完全功能
* **記錄**：SK 的記錄基礎設施增強了圖特定的上下文

### **零設定設置**
```csharp
var builder = Kernel.CreateBuilder();
// 您現有的 SK 設定
builder.AddOpenAIChatCompletion("gpt-4", "your-api-key");

// 只需一行即可新增圖支援
builder.AddGraphSupport();

var kernel = builder.Build();
```

### **增強功能**
SemanticKernel.Graph 在保留 SK 簡單性的同時新增了圖特定功能：
* **圖狀態**：具有版本控制和驗證的增強型 `KernelArguments`
* **節點類型**：用於條件式邏輯、迴圈和錯誤處理的專用節點
* **執行引擎**：具有檢查點和恢復功能的進階編排
* **可觀察性**：增強的圖執行記錄和指標

## 與 LangGraph 的對等性

SemanticKernel.Graph 提供與 LangGraph 的功能對等性，同時保持 .NET 原生設計模式和與 Microsoft 生態系統的整合。

### **核心概念對齊**
| LangGraph 概念 | SemanticKernel.Graph 對應 | 狀態 |
|------------------|----------------------------------|---------|
| 狀態管理 | `GraphState` + `KernelArguments` | ✅ 完整 |
| 條件式邊 | `ConditionalEdge` + `ConditionalGraphNode` | ✅ 完整 |
| 函式節點 | `FunctionGraphNode` | ✅ 完整 |
| 迴圈 | `LoopGraphNode` + `ReActLoopGraphNode` | ✅ 完整 |
| 人工介入 | `HumanApprovalGraphNode` | ✅ 完整 |
| 串流 | `IStreamingGraphExecutor` | ✅ 完整 |
| 檢查點 | `CheckpointManager` + `StateHelpers` | ✅ 完整 |
| 多代理 | `MultiAgentCoordinator` | ✅ 完整 |

### **進階功能**
* **ReAct 模式**：具有推理和行動週期的完整實作
* **思考鏈**：具有驗證的結構化推理工作流程
* **動態路由**：上下文感知的節點選擇
* **錯誤恢復**：全面的錯誤處理和重試機制
* **效能最佳化**：內建的分析和最佳化工具

### **.NET 特定優勢**
* **原生效能**：針對 .NET 執行階段和記憶體管理最佳化
* **企業整合**：內建對 Azure 服務和企業模式的支援
* **型別安全**：整個圖執行管線的強型別
* **Async/Await**：原生支援非同步操作和串流
* **相依性注入**：與 .NET DI 容器無縫整合

## 何時使用 SemanticKernel.Graph

### **最適合用於**
* **AI 代理**：建立能夠推理和行動的智慧代理
* **工作流程自動化**：複雜的多步驟 AI 流程
* **決策系統**：AI 驅動的決策樹和路由邏輯
* **多代理協調**：編排多個 AI 代理
* **人機協作**：需要人工核准或輸入的工作流程
* **生產環境 AI 應用程式**：具有監控和恢復功能的企業級 AI 系統

### **考慮替代方案的情況**
* **簡單函式呼叫**：基本的 SK 函式執行就足夠
* **靜態工作流程**：不需要條件式邏輯或動態行為
* **最小狀態管理**：簡單的無狀態 AI 互動
* **資源限制**：記憶體或處理資源非常有限

## 快速開始

準備好開始了嗎？以下是如何在 5 分鐘內建立您的第一個圖：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

// 1. 建立並設定您的核心
var builder = Kernel.CreateBuilder();
builder.AddOpenAIChatCompletion("gpt-4", "your-api-key");
builder.AddGraphSupport(); // 啟用圖功能
var kernel = builder.Build();

// 2. 建立一個簡單的函式節點
var echoNode = new FunctionGraphNode(
    kernel.CreateFunctionFromMethod(
        (string input) => $"Echo: {input}",
        functionName: "EchoFunction",
        description: "Echoes the input with a prefix"
    ),
    "echo_node"
).StoreResultAs("output");

// 3. 建立並執行圖
var graph = new GraphExecutor("MyFirstGraph");
graph.AddNode(echoNode);
graph.SetStartNode(echoNode);

var state = new KernelArguments { ["input"] = "Hello, World!" };
var result = await graph.ExecuteAsync(kernel, state);

Console.WriteLine(state["output"]); // 輸出: Echo: Hello, World!
```

## 下一步

現在您已經了解什麼是 SemanticKernel.Graph 以及它如何融入您的 AI 開發工作流程，請探索這些資源：

* **[安裝指南](installation.md)**：在您的專案中設定 SemanticKernel.Graph
* **[第一個圖教學](first-graph.md)**：建立您的第一個完整圖工作流程
* **[核心概念](concepts/index.md)**：了解圖、節點、狀態和執行
* **[範例](examples/index.md)**：查看實際使用模式和實作
* **[API 參考](api/core.md)**：探索完整的 API 介面

## 概念與技術

本概述介紹了在 SemanticKernel.Graph 中將使用的幾個關鍵概念：

* **圖**：由節點和邊組成的有向圖結構，定義了執行流程
* **節點**：可以執行 AI 函式、做出決策或執行其他操作的個別工作單元
* **邊**：節點之間的連接，可包含用於動態路由的條件式邏輯
* **狀態**：流經圖的持久性資料，在執行步驟之間維護上下文
* **執行**：遍歷圖、執行節點和管理狀態轉換的過程

## 先決條件和最低設定

要使用 SemanticKernel.Graph，您需要：
* **.NET 8.0** 或更新版本
* **Semantic Kernel** 套件（最新穩定版本）
* **LLM 提供者**（OpenAI、Azure OpenAI 或其他支援的提供者）
* 您所選 LLM 提供者的 **API 金鑰**

## 快速疑難排解

**常見問題：**
* **找不到套件**：確保您使用正確的 NuGet 套件名稱
* **核心設定錯誤**：驗證您的 LLM 提供者已正確設定
* **圖執行失敗**：檢查所有節點是否正確連接和設定

如需更詳細的疑難排解，請參閱[疑難排解指南](troubleshooting.md)。
