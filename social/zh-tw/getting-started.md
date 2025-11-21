# 開始使用 SemanticKernel.Graph

歡迎來到 SemanticKernel.Graph，這是一個強大的 .NET 函式庫，為 Microsoft 的 Semantic Kernel 生態系帶來了基於圖形的工作流程的靈活性和功能。本指南將幫助您了解什麼是 SemanticKernel.Graph、它解決的問題，以及它與 Semantic Kernel 和 LangGraph 的關係。

## 什麼是 SemanticKernel.Graph？

SemanticKernel.Graph 是一個生產級的 .NET 函式庫，可讓您使用有向圖建構複雜的、有狀態的 AI 工作流程。它擴展了 Microsoft 的 Semantic Kernel，提供高級的編排功能，讓您能建立精緻的 AI 代理、多步驟推理工作流程和智慧自動化系統。

### 主要功能

* **Graph-Based Workflows**：使用 Node 和條件 Edge 設計複雜的 AI 工作流程
* **Native Semantic Kernel Integration**：無縫使用現有的 SK 外掛程式、記憶體和連接器
* **State Management**：在工作流程執行過程中保持上下文和狀態
* **Conditional Logic**：基於 AI 回應和狀態實現動態路由
* **Streaming Execution**：即時監控和事件串流
* **Checkpointing & Recovery**：從任何一點恢復工作流程並保持狀態持久化
* **Visualization & Debugging**：內建工具以理解和排除工作流程故障
* **Multi-Agent Coordination**：在複雜場景中協調多個 AI 代理

## SemanticKernel.Graph 解決的問題

### 1. **複雜的 AI 工作流程編排**
傳統的 AI 應用程式通常以順序方式執行函式，無法做出決定或處理複雜的分支邏輯。SemanticKernel.Graph 讓您能建立智慧工作流程，可以：
* 根據 AI 回應做出決策
* 處理多個執行路徑
* 實現重試邏輯和錯誤恢復
* 協調多個 AI 代理

### 2. **跨 AI 互動的狀態管理**
在多個 AI 函式呼叫中保持上下文具有挑戰性。SemanticKernel.Graph 提供：
* 具有版本控制的永久狀態管理
* 自動狀態序列化和檢查點
* 狀態驗證和完整性檢查
* 工作流程步驟之間的高效狀態共享

### 3. **動態 AI 代理行為**
建立能根據上下文調整行為的 AI 代理需要複雜的編排。使用 SemanticKernel.Graph，您可以：
* 實現 ReAct（推理 + 行動）模式
* 建立推理鏈工作流程
* 構建從先前互動中學習的代理
* 處理人類參與的場景

### 4. **生產級的 AI 工作流程**
構建企業級的 AI 應用程式需要健壯的錯誤處理、監控和可擴展性。SemanticKernel.Graph 提供：
* 全面的錯誤處理和恢復
* 效能指標和可觀測性
* 資源治理和速率限制
* 分散式執行功能

## 與 Semantic Kernel 的關係

SemanticKernel.Graph 是建立在 Semantic Kernel 之上，而不是作為替代品。它使用圖形編排功能擴展現有的 SK 生態系，同時保持與以下元件的完全相容性：

### **現有 SK 元件**
* **Plugins**：所有現有的 SK 外掛程式都可作為圖形節點使用
* **Memory**：向量和語義記憶系統無縫整合
* **Connectors**：OpenAI、Azure OpenAI 和其他 LLM 提供者保持不變
* **Templates**：Handlebars 和其他範本系統保持完全功能
* **Logging**：SK 的日誌記錄基礎結構透過圖形特定上下文得到增強

### **零設定設置**
```csharp
var builder = Kernel.CreateBuilder();
// 您現有的 SK 設定
builder.AddOpenAIChatCompletion("gpt-4", "your-api-key");

// 只需一行程式碼就能新增圖形支援
builder.AddGraphSupport();

var kernel = builder.Build();
```

### **增強的功能**
SemanticKernel.Graph 新增圖形特定功能，同時保持 SK 的簡潔性：
* **Graph State**：帶有版本控制和驗證的增強 `KernelArguments`
* **Node Types**：條件邏輯、迴圈和錯誤處理的專用節點
* **Execution Engine**：帶有檢查點和恢復的高級編排
* **Observability**：圖形執行的增強日誌記錄和指標

## 與 LangGraph 的同等性

SemanticKernel.Graph 提供與 LangGraph 功能同等的功能，同時保持 .NET 原生設計模式和與 Microsoft 生態系的整合。

### **核心概念對齊**
| LangGraph 概念 | SemanticKernel.Graph 等效項 | 狀態 |
|------------------|----------------------------------|---------|
| State Management | `GraphState` + `KernelArguments` | ✅ 完整 |
| Conditional Edges | `ConditionalEdge` + `ConditionalGraphNode` | ✅ 完整 |
| Function Nodes | `FunctionGraphNode` | ✅ 完整 |
| Loops | `LoopGraphNode` + `ReActLoopGraphNode` | ✅ 完整 |
| Human-in-the-Loop | `HumanApprovalGraphNode` | ✅ 完整 |
| Streaming | `IStreamingGraphExecutor` | ✅ 完整 |
| Checkpointing | `CheckpointManager` + `StateHelpers` | ✅ 完整 |
| Multi-Agent | `MultiAgentCoordinator` | ✅ 完整 |

### **進階功能**
* **ReAct Pattern**：完整實現推理和行動循環
* **Chain-of-Thought**：具有驗證的結構化推理工作流程
* **Dynamic Routing**：內容感知的節點選擇
* **Error Recovery**：全面的錯誤處理和重試機制
* **Performance Optimization**：內建分析和最佳化工具

### **.NET 特定優勢**
* **Native Performance**：針對 .NET 執行時和記憶體管理進行最佳化
* **Enterprise Integration**：內建 Azure 服務和企業模式支援
* **Type Safety**：整個圖形執行管線的強類型
* **Async/Await**：非同步作業和串流的原生支援
* **Dependency Injection**：與 .NET DI 容器的無縫整合

## 何時使用 SemanticKernel.Graph

### **最適合**
* **AI Agents**：構建可以推理和行動的智慧代理
* **Workflow Automation**：複雜的多步驟 AI 流程
* **Decision Systems**：AI 驅動的決策樹和路由邏輯
* **Multi-Agent Coordination**：協調多個 AI 代理
* **Human-AI Collaboration**：需要人類批准或輸入的工作流程
* **Production AI Applications**：具有監控和恢復的企業級 AI 系統

### **考慮替代方案時機**
* **Simple Function Calls**：基本的 SK 函式執行就足夠了
* **Static Workflows**：不需要條件邏輯或動態行為
* **Minimal State Management**：簡單的無狀態 AI 互動
* **Resource Constraints**：記憶體或處理資源非常有限

## 快速入門

準備好開始了嗎？以下是如何在不到 5 分鐘內建立您的第一個圖形的方法：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

// 1. 建立和設定您的核心
var builder = Kernel.CreateBuilder();
builder.AddOpenAIChatCompletion("gpt-4", "your-api-key");
builder.AddGraphSupport(); // 啟用圖形功能
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

// 3. 建立並執行圖形
var graph = new GraphExecutor("MyFirstGraph");
graph.AddNode(echoNode);
graph.SetStartNode(echoNode);

var state = new KernelArguments { ["input"] = "Hello, World!" };
var result = await graph.ExecuteAsync(kernel, state);

Console.WriteLine(state["output"]); // 輸出：Echo: Hello, World!
```

## 後續步驟

現在您已了解什麼是 SemanticKernel.Graph，以及它如何融入您的 AI 開發工作流程，請探索這些資源：

* **[Installation Guide](installation.md)**：在您的專案中設定 SemanticKernel.Graph
* **[First Graph Tutorial](first-graph.md)**：構建您的第一個完整圖形工作流程
* **[Core Concepts](concepts/index.md)**：了解 Graph、Node、State 和執行
* **[Examples](examples/index.md)**：查看真實世界的使用案例和實現
* **[API Reference](api/core.md)**：探索完整的 API 介面

## 概念和技術

本概述介紹了您在整個 SemanticKernel.Graph 中將使用的幾個關鍵概念：

* **Graph**：由 Node 和 Edge 組成的有向圖結構，定義執行流程
* **Node**：可以執行 AI 函式、做出決策或執行其他操作的個別工作單位
* **Edge**：Node 之間的連線，可以包含條件邏輯以進行動態路由
* **State**：流經圖形的永久資料，在執行步驟間保持上下文
* **Execution**：遍歷圖形、執行節點和管理狀態轉換的流程

## 先決條件和最少設定

若要使用 SemanticKernel.Graph，您需要：
* **.NET 8.0** 或更新版本
* **Semantic Kernel** 套件（最新穩定版本）
* **LLM Provider**（OpenAI、Azure OpenAI 或其他支援的提供者）
* **API Keys**：針對您選擇的 LLM 提供者

## 疑難排解快速參考

**常見問題：**
* **Package not found**：確保您使用的是正確的 NuGet 套件名稱
* **Kernel configuration errors**：驗證您的 LLM 提供者是否已正確設定
* **Graph execution failures**：檢查所有節點是否已正確連接和設定

如需更詳細的疑難排解，請查看 [Troubleshooting Guide](troubleshooting.md)。
