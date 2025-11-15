# 人工參與式工作流程（Human-in-the-Loop）

本指南說明如何在 SemanticKernel.Graph 中實作人工參與式工作流程（HITL）。您將學習如何暫停執行以等待人工審核、實作信心度閘門，以及整合多個互動頻道以實現無縫的人工監督。

## 概述

人工參與式工作流程可讓您：
* **暫停執行**並等待人工核准或輸入
* **實作信心度閘門**以進行品質控制
* **支援多個頻道**，包括 CLI、Web 和 API 介面
* **批量核准**多個待審決議
* **設定逾時和 SLA**以應對人工回應需求

## 核心 HITL 元件

### 人工核准節點

使用 `HumanApprovalGraphNode` 暫停執行以等待人工決策。該節點需要一個 `IHumanInteractionChannel` 實例（例如 `ConsoleHumanInteractionChannel`）。

```csharp
// 建立一個控制台頻道，將在終端中提示核准者。
var consoleChannel = new ConsoleHumanInteractionChannel();

// 建立一個 HumanApprovalGraphNode，暫停圖表執行並請求人工核准。
// 提供簡短清晰的標題和訊息，以便核准者理解請求的操作。
var approvalNode = new HumanApprovalGraphNode(
    approvalTitle: "Document Approval",
    approvalMessage: "Please review and approve the generated document (type 'approve' or 'reject')",
    interactionChannel: consoleChannel,
    nodeId: "approve_step"
)
    // 配置合理的逾時設置和預設動作以避免
    // 無限期阻擋自動化執行。TimeoutAction.Reject 將
    // 在核准者未回應時選擇拒絕路徑。
    .WithTimeout(TimeSpan.FromMinutes(10), TimeoutAction.Reject);

// 在 GraphExecutor 中註冊該節點並連接兩個可能的結果。
executor.AddNode(approvalNode);
executor.Connect(approvalNode.NodeId, "approved_path");
executor.Connect(approvalNode.NodeId, "rejected_path");
```

### 信心度閘門節點

實作基於信心度的決策閘門。如果您想要用於人工覆蓋的互動頻道，請使用接受頻道的工廠方法。

```csharp
// 建立一個信心度閘門節點，可以根據
// 數值分數進行自動路由。可選地附加一個互動頻道，以便
// 人工可以覆蓋或檢查低信心度情況。
var consoleChannel = new ConsoleHumanInteractionChannel();
var confidenceNode = ConfidenceGateGraphNode.CreateWithInteraction(
    confidenceThreshold: 0.8f,
    interactionChannel: consoleChannel,
    nodeId: "confidence_check"
);

// 新增該節點並使用 ConnectWhen 搭配檢查圖表狀態的
// 謂詞來路由結果。使用 GetOrCreateGraphState() 讀取
// 圖表稍早產生的值。
executor.AddNode(confidenceNode);
executor.ConnectWhen("confidence_check", "high_confidence", args =>
    args.GetOrCreateGraphState().GetFloat("confidence_score", 0f) >= 0.8f);
executor.ConnectWhen("confidence_check", "human_review", args =>
    args.GetOrCreateGraphState().GetFloat("confidence_score", 0f) < 0.8f);
```

## 多個互動頻道

### 控制台頻道

使用基於控制台的人工互動。使用簡單的配置字典初始化頻道（該頻道公開 `InitializeAsync` 用於配置）。

```csharp
// 配置並初始化一個基於控制台的互動頻道。
var consoleChannel = new ConsoleHumanInteractionChannel();
await consoleChannel.InitializeAsync(new Dictionary<string, object>
{
    // 選擇適合核准場景的提示樣式。
    ["prompt_style"] = "detailed",
    // 在支援彩色的終端中啟用顏色以提高可讀性。
    ["enable_colors"] = true,
    // 可選地顯示時間戳以幫助核准者追蹤請求。
    ["show_timestamps"] = true
});

// 使用已初始化的控制台頻道建立一個核准節點，
// 並使用逾時設置防護長時間等待。
var approvalNode = new HumanApprovalGraphNode(
    approvalTitle: "Console Approval",
    approvalMessage: "Enter 'approve' or 'reject'",
    interactionChannel: consoleChannel,
    nodeId: "console_approval"
).WithTimeout(TimeSpan.FromMinutes(10));
```

### Web API 頻道

實作基於 Web 的核准介面。該程式庫提供了由 `IHumanInteractionStore` 支持的 Web API 頻道。使用提供的核心建造器擴展進行註冊，或使用存儲區手動建構頻道。

```csharp
// 透過核心建造器註冊 Web API 人工互動支持
// 以便範例連接由 DI 和框架處理。
kernelBuilder.AddWebApiHumanInteraction();

// 或者，使用備份存儲區手動建構頻道。
var store = new InMemoryHumanInteractionStore();
var webApiChannel = new WebApiHumanInteractionChannel(store);

// 建立一個路由到 Web 頻道的核准節點。Web 互動
// 通常需要較長的逾時以允許外部核准者回應。
var webApprovalNode = new HumanApprovalGraphNode(
    approvalTitle: "Web Approval",
    approvalMessage: "Approve via the web UI",
    interactionChannel: webApiChannel,
    nodeId: "web_approval"
).WithTimeout(TimeSpan.FromMinutes(30));
```

### CLI 頻道

CLI 互動可由控制台頻道提供。此程式碼庫中沒有單獨的 `CliHumanInteractionChannel` 類型 — 重複使用 `ConsoleHumanInteractionChannel`。

```csharp
// CLI 互動重複使用控制台頻道。當核准者期望簡短命令和
// 有限輸出時，使用簡潔的提示樣式。
var cliChannel = new ConsoleHumanInteractionChannel();
await cliChannel.InitializeAsync(new Dictionary<string, object>
{
    ["prompt_style"] = "compact",
    ["enable_colors"] = false
});

var cliApprovalNode = new HumanApprovalGraphNode(
    approvalTitle: "CLI Approval",
    approvalMessage: "Respond via terminal",
    interactionChannel: cliChannel,
    nodeId: "cli_approval"
).WithTimeout(TimeSpan.FromMinutes(15));
```

## 進階 HITL 模式

### 批量核准管理

使用 `HumanApprovalBatchManager` 有效地處理多個待審核准。

```csharp
// 使用預設頻道和批次選項建立管理器。
// 批次管理器將多個請求分組以減少通知噪音。
var defaultChannel = new ConsoleHumanInteractionChannel();
var batchOptions = new BatchApprovalOptions
{
    MaxBatchSize = 20,
    BatchFormationTimeout = TimeSpan.FromHours(1),
    AllowPartialApproval = false
};

var batchManager = new HumanApprovalBatchManager(defaultChannel, batchOptions);

// 建立一個核准節點，可能由管理器路由到批次中。
var batchApprovalNode = new HumanApprovalGraphNode(
    approvalTitle: "Batch Approval",
    approvalMessage: "This request may be processed in a batch",
    interactionChannel: defaultChannel,
    nodeId: "batch_approval"
).WithTimeout(TimeSpan.FromHours(2));
```

### 條件式人工審核

使用條件節點和核准節點實作智能人工審核路由。

```csharp
// 建立一個條件節點，評估圖表狀態以決定
// 是否需要人工審核。謂詞讀取稍早在
// 圖表狀態中儲存的值，例如信心度、風險等級和交易金額。
var conditionalReview = new ConditionalGraphNode(
    condition: state =>
    {
        var confidence = state.GetFloat("confidence_score", 0f);
        var riskLevel = state.GetString("risk_level", "low");
        var amount = state.GetDecimal("transaction_amount", 0m);

        // 當信心度低、風險高或
        // 交易金額超過業務定義的閾值時，請求人工審核。
        return confidence < 0.7f ||
               riskLevel == "high" ||
               amount > 10000m;
    },
    nodeId: "review_decision"
);

// 建立當條件節點評估為 true 時將執行的人工核准節點。
var humanReviewNode = new HumanApprovalGraphNode(
    approvalTitle: "Human Review",
    approvalMessage: "Please review this transaction",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "human_review"
);

// 將節點連接到執行器中，並將 true 分支路由到人工節點。
executor.AddNode(conditionalReview);
executor.AddNode(humanReviewNode);
conditionalReview.AddTrueNode(humanReviewNode);
// 在 false 分支上根據需要新增自動處理節點。
```

### 多階段核准

實作複雜的核准工作流程：

```csharp
// 範例多階段核准流程。每個階段由一個
// HumanApprovalGraphNode 表示。核准是鏈式的，以便
// 一個階段的輸出觸發下一個階段。
var firstApproval = new HumanApprovalGraphNode(
    approvalTitle: "First Approval",
    approvalMessage: "Stage 1 approval",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "first_approval"
);

var secondApproval = new HumanApprovalGraphNode(
    approvalTitle: "Second Approval",
    approvalMessage: "Stage 2 approval",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "second_approval"
);

var finalApproval = new HumanApprovalGraphNode(
    approvalTitle: "Final Approval",
    approvalMessage: "Final stage approval",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "final_approval"
);

// 將多階段流程連接到執行器中。
executor.AddNode(firstApproval);
executor.AddNode(secondApproval);
executor.AddNode(finalApproval);
executor.Connect(firstApproval.NodeId, secondApproval.NodeId);
executor.Connect(secondApproval.NodeId, finalApproval.NodeId);
executor.Connect(finalApproval.NodeId, "approved");
```

## 配置和選項

### 核准節點配置

配置核准行為和外觀：

```csharp
// 使用明確的核准選項和逾時配置核准節點。
var configuredApproval = new HumanApprovalGraphNode(
    approvalTitle: "Document Review Required",
    approvalMessage: "Please review the generated document for accuracy",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "configured_approval"
);

// 新增核准者可以選擇的具名核准選項。該 API
// 將選擇的值儲存在結果中，以便圖表路由可以使用它。
configuredApproval.AddApprovalOption("approve", "Approve", value: true, isDefault: true)
                  .AddApprovalOption("reject", "Reject", value: false);

// 應用合理的逾時以避免無限期阻擋。
configuredApproval.WithTimeout(TimeSpan.FromMinutes(15), TimeoutAction.Reject);
```

### 頻道配置

配置互動頻道以獲得最佳使用者體驗：

```csharp
// Web API 頻道透過核心建造器進行註冊或使用存儲區建構。
kernelBuilder.AddWebApiHumanInteraction();

// 或者手動使用備份存儲區建構並初始化它。
var store = new InMemoryHumanInteractionStore();
var webChannel = new WebApiHumanInteractionChannel(store);
await webChannel.InitializeAsync();
```

## 與外部系統整合

### 電子郵件通知

整合核准的電子郵件通知：

```csharp
// 電子郵件頻道預設不包含在程式碼庫中；實作一個
// 實作 IHumanInteractionChannel 的頻道並插入核准節點。
```

## 監控和稽核

### 核准追蹤

追蹤核准狀態和時序：

```csharp
// 建立一個核准節點並附加掛鈎以記錄時序和結果
// 中繼資料以進行監控和稽核。
var trackedApproval = new HumanApprovalGraphNode(
    approvalTitle: "Tracked Approval",
    approvalMessage: "Please review and track timing",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "tracked_approval"
);

// 記錄何時請求核准。
trackedApproval.OnBeforeExecuteAsync = async (kernel, args, ct) =>
{
    var state = args.GetOrCreateGraphState();
    state["approval_requested_at"] = DateTimeOffset.UtcNow;
    return Task.CompletedTask;
};

// 記錄核准何時完成並儲存結果以進行稽核。
trackedApproval.OnAfterExecuteAsync = async (kernel, args, result, ct) =>
{
    var state = args.GetOrCreateGraphState();
    var requestedAt = state.GetValue<DateTimeOffset>("approval_requested_at");
    state["approval_completed_at"] = DateTimeOffset.UtcNow;
    state["approval_result"] = result.IsSuccess ? "approved" : "rejected";
    return Task.CompletedTask;
};
```

## 最佳實踐

### 核准設計

1. **清晰的說明** - 為核准者提供清晰、可行的說明
2. **合理的逾時** - 根據核准複雜度設定適當的逾時
3. **升級路徑** - 定義逾期核准的升級程序
4. **批次處理** - 將相關核准分組以提高效率

### 頻道選擇

1. **使用者偏好** - 根據使用者偏好和可用性選擇頻道
2. **回應緊迫性** - 針對緊急核准使用更快的頻道
3. **整合功能** - 利用現有通訊基礎設施
4. **無障礙** - 確保所有核准者都可以存取頻道

### 安全和合規

1. **驗證** - 為所有頻道實作適當的身份驗證
2. **稽核線跡** - 為合規維護全面的稽核日誌
3. **資料隱私** - 保護核准請求中的敏感資訊
4. **存取控制** - 限制核准存取權限給授權使用者

## 故障排除

### 常見問題

**核准逾時**：檢查逾時設置和核准者可用性

**頻道故障**：驗證頻道配置和網路連線

**批次處理問題**：檢查批次大小限制和分組邏輯

**稽核日誌差距**：驗證稽核記錄器配置和權限

### 除錯提示

1. **啟用詳細的記錄**以追蹤核准流程
2. **檢查頻道狀態**以瞭解連線問題
3. **監控核准指標**以瞭解效能問題
4. **獨立測試頻道**以隔離問題

## 概念和技巧

**HumanApprovalGraphNode**：一種特殊的圖表節點，暫停執行以等待人工輸入或核准。它支援多個互動頻道和可配置的逾時。

**ConfidenceGateGraphNode**：一種根據信心度分數自動路由執行的節點，僅當信心度低於閾值時才需要人工干預。

**HumanInteractionChannel**：定義如何處理人工互動的介面，支援多種通訊方法，如控制台、Web API、電子郵件和 Slack。

**HumanApprovalBatchManager**：一項服務，將多個核准請求分組為批次以進行有效處理，減少通知開銷並改善核准工作流程管理。

**核准工作流程**：一種模式，其中圖表執行在特定點暫停以允許人工決策，在自動化過程中啟用監督和品質控制。

## 另請參閱

* [人工參與式工作流程](human-in-the-loop.md) - HITL 工作流程的綜合指南
* [建立圖表](build-a-graph.md) - 瞭解如何使用核准節點建構圖表
* [錯誤處理和復原能力](error-handling-and-resilience.md) - 妥善處理核准失敗
* [安全和資料](security-and-data.md) - 安全 HITL 實作實踐
* [範例：HITL 工作流程](../examples/hitl-example.md) - 人工參與式工作流程的完整工作範例
