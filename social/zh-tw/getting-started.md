# 開始使用 SemanticKernel.Graph

歡迎使用 SemanticKernel.Graph，一個強大的 .NET 程式庫，為 Microsoft 的 Semantic Kernel 生態系統帶來基於圖形的工作流程的靈活性和能力。本指南將幫助你理解 SemanticKernel.Graph 是什麼、它解決的問題，以及它與 Semantic Kernel 和 LangGraph 的關係。

## 什麼是 SemanticKernel.Graph？

SemanticKernel.Graph 是一個可用於生產環境的 .NET 程式庫，能讓你使用有向圖建置複雜、具狀態的 AI 工作流程。它延伸了 Microsoft 的 Semantic Kernel，提供進階的編排能力，讓你可以建立精密的 AI 代理、多步驟推理工作流程和智能自動化系統。

### 主要功能

* **基於圖形的工作流程**：使用節點和條件邊建設複雜的 AI 工作流程
* **原生 Semantic Kernel 整合**：無縫使用現有的 SK 外掛程式、記憶體和連接器
* **狀態管理**：在工作流程執行過程中維持上下文和狀態
* **條件邏輯**：根據 AI 回應和狀態實現動態路由
* **串流執行**：即時監控和事件串流
* **檢查點和復原**：從任何點恢復工作流程，支持狀態持久化
* **視覺化和除錯**：內建工具用於理解和故障排除工作流程
* **多代理協調**：在複雜場景中編排多個 AI 代理

## SemanticKernel.Graph 解決的問題

### 1. **複雜的 AI 工作流程編排**
傳統 AI 應用程式通常按順序執行函式，無法根據情況做出決策或處理複雜的分支邏輯。SemanticKernel.Graph 讓你可以建立智能工作流程，能夠：
* 根據 AI 回應做出決策
* 處理多個執行路徑
* 實現重試邏輯和錯誤恢復
* 協調多個 AI 代理

### 2. **跨 AI 互動的狀態管理**
在多個 AI 函式呼叫中維持上下文是個挑戰。SemanticKernel.Graph 提供：
* 具備版本控制的持久狀態管理
* 自動狀態序列化和檢查點
* 狀態驗證和完整性檢查
* 工作流程步驟之間的高效狀態共享

### 3. **動態 AI 代理行為**
建立可以根據上下文調整行為的 AI 代理需要複雜的編排。使用 SemanticKernel.Graph，你可以：
* 實現 ReAct（推理 + 行動）模式
* 建立思路鏈推理工作流程
* 建置可從先前互動中學習的代理
* 處理人工迴圈場景

### 4. **可用於生產環境的 AI 工作流程**
建立企業級 AI 應用程式需要強大的錯誤處理、監控和可擴展性。SemanticKernel.Graph 提供：
* 全面的錯誤處理和恢復
* 效能指標和可觀察性
* 資源管理和速率限制
* 分散式執行功能

## 與 Semantic Kernel 的關係

SemanticKernel.Graph 是建立在 Semantic Kernel **之上的**，而不是替代品。它延伸現有的 SK 生態系統，加入圖形編排功能，同時維持完全相容性：

### **現有 SK 元件**
* **外掛程式**：所有現有的 SK 外掛程式可作為圖形節點運作
* **記憶體**：向量和語意記憶系統無縫整合
* **連接器**：OpenAI、Azure OpenAI 和其他 LLM 提供商保持不變
* **範本**：Handlebars 和其他範本系統完全保持功能
* **記錄**：SK 的記錄基礎設施以圖形特定的上下文增強

### **零設定安裝**
```csharp
var builder = Kernel.CreateBuilder();
// 你現有的 SK 設定
builder.AddOpenAIChatCompletion("gpt-4", "your-api-key");

// 用一行程式碼新增圖形支援
builder.AddGraphSupport();

var kernel = builder.Build();
```

### **增強的功能**
SemanticKernel.Graph 新增圖形特定功能，同時保留 SK 的簡潔性：
* **圖形狀態**：使用版本控制和驗證的增強 `KernelArguments`
* **節點類型**：用於條件邏輯、迴圈和錯誤處理的專用節點
* **執行引擎**：具有檢查點和恢復功能的進階編排
* **可觀察性**：增強的圖形執行記錄和指標

## 與 LangGraph 的奇偶校驗

SemanticKernel.Graph 提供與 LangGraph 的功能奇偶校驗，同時保持 .NET 原生設計模式和與 Microsoft 生態系統的整合。

### **核心概念對齐**
| LangGraph 概念 | SemanticKernel.Graph 對應項 | 狀態 |
|------------------|----------------------------------|---------|
| 狀態管理 | `GraphState` + `KernelArguments` | ✅ 完整 |
| 條件邊 | `ConditionalEdge` + `ConditionalGraphNode` | ✅ 完整 |
| 函式節點 | `FunctionGraphNode` | ✅ 完整 |
| 迴圈 | `LoopGraphNode` + `ReActLoopGraphNode` | ✅ 完整 |
| 人工迴圈 | `HumanApprovalGraphNode` | ✅ 完整 |
| 串流 | `IStreamingGraphExecutor` | ✅ 完整 |
| 檢查點 | `CheckpointManager` + `StateHelpers` | ✅ 完整 |
| 多代理 | `MultiAgentCoordinator` | ✅ 完整 |

### **進階功能**
* **ReAct 模式**：具有推理和行動循環的完整實現
* **思路鏈**：具有驗證的結構化推理工作流程
* **動態路由**：情境感知節點選擇
* **錯誤恢復**：全面的錯誤處理和重試機制
* **效能最佳化**：內建分析和最佳化工具

### **.NET 特定優勢**
* **原生效能**：針對 .NET 執行時間和記憶體管理進行最佳化
* **企業整合**：內建對 Azure 服務和企業模式的支援
* **型別安全**：整個圖形執行管道的強式型別
* **非同步/等待**：原生支援非同步作業和串流
* **依賴注入**：與 .NET DI 容器的無縫整合

## 何時使用 SemanticKernel.Graph

### **完美應用於**
* **AI 代理**：建立可以推理和行動的智能代理
* **工作流程自動化**：複雜的多步驟 AI 流程
* **決策系統**：AI 驅動的決策樹和路由邏輯
* **多代理協調**：編排多個 AI 代理
* **人工-AI 協作**：需要人工核准或輸入的工作流程
* **生產 AI 應用程式**：具有監控和恢復的企業級 AI 系統

### **考慮替代方案時**
* **簡單函式呼叫**：基本 SK 函式執行已足夠
* **靜態工作流程**：無需條件邏輯或動態行為
* **最小狀態管理**：簡單的無狀態 AI 互動
* **資源限制**：非常有限的記憶體或處理資源

## 快速開始

準備好開始了嗎？以下是如何在 5 分鐘內建立你的第一個圖形的方法：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph.Core;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

// 1. 建立並設定你的核心
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

Console.WriteLine(state["output"]); // 輸出: Echo: Hello, World!
```

## 後續步驟

現在你已經理解了 SemanticKernel.Graph 是什麼，以及它如何適應你的 AI 開發工作流程，請探索這些資源：

* **[安裝指南](installation.md)**：在你的專案中設定 SemanticKernel.Graph
* **[第一個圖形教程](first-graph.md)**：建立你的第一個完整的圖形工作流程
* **[核心概念](concepts/index.md)**：理解圖形、節點、狀態和執行
* **[範例](examples/index.md)**：查看真實世界的用法模式和實現
* **[API 參考](api/core.md)**：探索完整的 API 介面

## 概念和技術

此概述介紹了你在使用 SemanticKernel.Graph 時會用到的幾個關鍵概念：

* **圖形**：由節點和邊組成的有向圖結構，定義執行流程
* **節點**：可以執行 AI 函式、做出決策或執行其他操作的獨立工作單位
* **邊**：節點之間的連接，可以包含用於動態路由的條件邏輯
* **狀態**：流經圖形的持久資料，維持執行步驟之間的上下文
* **執行**：遍歷圖形、執行節點和管理狀態轉換的過程

## 先決條件和最小設定

要使用 SemanticKernel.Graph，你需要：
* **.NET 8.0** 或更新版本
* **Semantic Kernel** 套件（最新穩定版本）
* **LLM 提供商**（OpenAI、Azure OpenAI 或其他支援的提供商）
* 你選擇的 LLM 提供商的 **API 金鑰**

## 故障排除快速指南

**常見問題：**
* **找不到套件**：確保你使用的是正確的 NuGet 套件名稱
* **核心設定錯誤**：驗證你的 LLM 提供商已正確設定
* **圖形執行失敗**：檢查所有節點是否已正確連接和設定

如需更詳細的故障排除，請參閱 [故障排除指南](troubleshooting.md)。
