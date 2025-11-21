# 人工介入迴圈

本指南說明如何在 SemanticKernel.Graph 中實現人工介入迴圈 (HITL) 工作流程。您將了解如何暫停執行以取得人工核准、實現信心閘門，以及整合多個互動通道以實現無縫的人工監督。

## 概述

人工介入迴圈工作流程可讓您：
* **暫停執行**並等待人工核准或輸入
* **實現信心閘門**以進行品質控制
* **支援多個通道**，包括 CLI、Web 和 API 介面
* **批量核准**多個待決事項
* **設定逾時和 SLA** 以滿足人工回應要求

## 核心 HITL 元件

### 人工核准節點

使用 `HumanApprovalGraphNode` 暫停執行以進行人工決定。該節點需要 `IHumanInteractionChannel` 執行個體（例如 `ConsoleHumanInteractionChannel`）。

```csharp
// 建立一個主控台通道，將透過終端提示核准者。
var consoleChannel = new ConsoleHumanInteractionChannel();

// 建置一個 HumanApprovalGraphNode，暫停 Graph 執行並要求
// 人工核准。提供簡短、清晰的標題和訊息，以便核准者
// 了解請求的動作。
var approvalNode = new HumanApprovalGraphNode(
    approvalTitle: "Document Approval",
    approvalMessage: "Please review and approve the generated document (type 'approve' or 'reject')",
    interactionChannel: consoleChannel,
    nodeId: "approve_step"
)
    // 設定合理的逾時和預設動作以避免
    // 無限期地封鎖自動化執行。TimeoutAction.Reject 將
    // 在核准者未回應時選擇拒絕路徑。
    .WithTimeout(TimeSpan.FromMinutes(10), TimeoutAction.Reject);

// 在 GraphExecutor 中註冊節點並連接兩個可能的結果。
executor.AddNode(approvalNode);
executor.Connect(approvalNode.NodeId, "approved_path");
executor.Connect(approvalNode.NodeId, "rejected_path");
```

### 信心閘門節點

實現基於信心的決定閘門。如果您想要一個互動通道以進行人工覆蓋，請使用接受通道的工廠方法。

```csharp
// 建立一個信心閘門節點，可根據
// 數值分數自動路由。選擇性地附加互動通道，以便人類
// 可以覆蓋或檢查低信心個案。
var consoleChannel = new ConsoleHumanInteractionChannel();
var confidenceNode = ConfidenceGateGraphNode.CreateWithInteraction(
    confidenceThreshold: 0.8f,
    interactionChannel: consoleChannel,
    nodeId: "confidence_check"
);

// 新增節點並使用 ConnectWhen 搭配檢查 Graph 狀態的述詞來路由結果。
// 使用 GetOrCreateGraphState() 讀取
// Graph 中先前產生的值。
executor.AddNode(confidenceNode);
executor.ConnectWhen("confidence_check", "high_confidence", args =>
    args.GetOrCreateGraphState().GetFloat("confidence_score", 0f) >= 0.8f);
executor.ConnectWhen("confidence_check", "human_review", args =>
    args.GetOrCreateGraphState().GetFloat("confidence_score", 0f) < 0.8f);
```

## 多個互動通道

### 主控台通道

使用主控台型人工互動。使用簡單的設定字典初始化通道（通道公開 `InitializeAsync` 以供設定）。

```csharp
// 設定並初始化主控台型互動通道。
var consoleChannel = new ConsoleHumanInteractionChannel();
await consoleChannel.InitializeAsync(new Dictionary<string, object>
{
    // 選擇適合核准情節的提示樣式。
    ["prompt_style"] = "detailed",
    // 啟用顏色以改善在支援終端時的可讀性。
    ["enable_colors"] = true,
    // 選擇性地顯示時間戳記以幫助核准者追蹤要求。
    ["show_timestamps"] = true
});

// 使用初始化的主控台通道建立核准節點，並
// 使用逾時保護長執行等待。
var approvalNode = new HumanApprovalGraphNode(
    approvalTitle: "Console Approval",
    approvalMessage: "Enter 'approve' or 'reject'",
    interactionChannel: consoleChannel,
    nodeId: "console_approval"
).WithTimeout(TimeSpan.FromMinutes(10));
```

### Web API 通道

實現 Web 型核准介面。該程式庫提供 Web API 支援的通道，可搭配 `IHumanInteractionStore` 運作。使用提供的核心建置器擴充功能來註冊它，或使用存放區建構通道。

```csharp
// 透過核心建置器註冊 Web API 人工互動支援
// 以便範例連接由 DI 和框架處理。
kernelBuilder.AddWebApiHumanInteraction();

// 或者，使用支援存放區手動建構通道。
var store = new InMemoryHumanInteractionStore();
var webApiChannel = new WebApiHumanInteractionChannel(store);

// 建立路由至 Web 通道的核准節點。Web 互動
// 通常需要更長的逾時以允許外部核准者回應。
var webApprovalNode = new HumanApprovalGraphNode(
    approvalTitle: "Web Approval",
    approvalMessage: "Approve via the web UI",
    interactionChannel: webApiChannel,
    nodeId: "web_approval"
).WithTimeout(TimeSpan.FromMinutes(30));
```

### CLI 通道

CLI 互動可由主控台通道提供。此程式碼基底中沒有單獨的 `CliHumanInteractionChannel` 型別 — 重複使用 `ConsoleHumanInteractionChannel`。

```csharp
// CLI 互動重複使用主控台通道。當核准者
// 預期簡短命令和有限輸出時，使用精簡提示
// 樣式。
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

使用 `HumanApprovalBatchManager` 有效率地處理多個待決核准。

```csharp
// 使用預設通道和批次選項建立管理員。
// 批次管理員將多個要求分組以減少通知噪音。
var defaultChannel = new ConsoleHumanInteractionChannel();
var batchOptions = new BatchApprovalOptions
{
    MaxBatchSize = 20,
    BatchFormationTimeout = TimeSpan.FromHours(1),
    AllowPartialApproval = false
};

var batchManager = new HumanApprovalBatchManager(defaultChannel, batchOptions);

// 建立可能由管理員路由至批次的核准節點。
var batchApprovalNode = new HumanApprovalGraphNode(
    approvalTitle: "Batch Approval",
    approvalMessage: "This request may be processed in a batch",
    interactionChannel: defaultChannel,
    nodeId: "batch_approval"
).WithTimeout(TimeSpan.FromHours(2));
```

### 條件式人工檢查

使用條件式節點和核准節點實現智能人工檢查路由。

```csharp
// 建立一個條件式節點，評估 Graph 狀態以決定是否
// 需要人工檢查。述詞讀取先前儲存在
// Graph 狀態中的值，例如信心度、風險等級和交易金額。
var conditionalReview = new ConditionalGraphNode(
    condition: state =>
    {
        var confidence = state.GetFloat("confidence_score", 0f);
        var riskLevel = state.GetString("risk_level", "low");
        var amount = state.GetDecimal("transaction_amount", 0m);

        // 當信心度低、風險高或
        // 交易金額超過業務定義的閾值時，要求人工檢查。
        return confidence < 0.7f ||
               riskLevel == "high" ||
               amount > 10000m;
    },
    nodeId: "review_decision"
);

// 建立一個人工核准節點，當條件式
// 節點評估為真時，該節點將被執行。
var humanReviewNode = new HumanApprovalGraphNode(
    approvalTitle: "Human Review",
    approvalMessage: "Please review this transaction",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "human_review"
);

// 將節點連接至執行程式，並將真分支路由至人工節點。
executor.AddNode(conditionalReview);
executor.AddNode(humanReviewNode);
conditionalReview.AddTrueNode(humanReviewNode);
// 視情況在假分支上新增自動處理節點。
```

### 多階段核准

實現複雜的核准工作流程：

```csharp
// 多階段核准流的範例。每個階段由
// HumanApprovalGraphNode 表示。核准被連接起來，
// 以便一個階段的輸出觸發下一個階段。
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

// 將多階段流連接至執行程式。
executor.AddNode(firstApproval);
executor.AddNode(secondApproval);
executor.AddNode(finalApproval);
executor.Connect(firstApproval.NodeId, secondApproval.NodeId);
executor.Connect(secondApproval.NodeId, finalApproval.NodeId);
executor.Connect(finalApproval.NodeId, "approved");
```

## 設定和選項

### 核准節點設定

設定核准行為和外觀：

```csharp
// 使用明確的核准選項和逾時設定核准節點。
var configuredApproval = new HumanApprovalGraphNode(
    approvalTitle: "Document Review Required",
    approvalMessage: "Please review the generated document for accuracy",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "configured_approval"
);

// 新增核准者可選擇的具名核准選項。
// API 會將選擇的值儲存在結果中，以便 Graph 路由可以使用它。
configuredApproval.AddApprovalOption("approve", "Approve", value: true, isDefault: true)
                  .AddApprovalOption("reject", "Reject", value: false);

// 套用合理的逾時以避免無限期封鎖。
configuredApproval.WithTimeout(TimeSpan.FromMinutes(15), TimeoutAction.Reject);
```

### 通道設定

設定互動通道以最佳化使用者體驗：

```csharp
// Web API 通道透過核心建置器註冊或使用存放區建構。
kernelBuilder.AddWebApiHumanInteraction();

// 或者手動建構具有支援存放區的通道，並初始化它。
var store = new InMemoryHumanInteractionStore();
var webChannel = new WebApiHumanInteractionChannel(store);
await webChannel.InitializeAsync();
```

## 與外部系統的整合

### 電子郵件通知

整合電子郵件通知以進行核准：

```csharp
// 電子郵件通道預設不包括在程式碼基底中；實現一個通道
// 實現 IHumanInteractionChannel 並插入核准節點中。
```

## 監控和稽核

### 核准追蹤

追蹤核准狀態和時間：

```csharp
// 建立核准節點並附加掛鉤以記錄時間和結果
// 中繼資料以進行監控和稽核。
var trackedApproval = new HumanApprovalGraphNode(
    approvalTitle: "Tracked Approval",
    approvalMessage: "Please review and track timing",
    interactionChannel: new ConsoleHumanInteractionChannel(),
    nodeId: "tracked_approval"
);

// 記錄核准何時被要求。
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

## 最佳做法

### 核准設計

1. **清晰的指示** - 為核准者提供清晰、可行的指示
2. **合理的逾時** - 根據核准複雜性設定適當的逾時
3. **升級路徑** - 定義逾期核准的升級程序
4. **批量處理** - 分組相關核准以提高效率

### 通道選擇

1. **使用者偏好** - 根據使用者偏好和可用性選擇通道
2. **回應緊急性** - 對於緊急核准使用更快的通道
3. **整合能力** - 利用現有的通訊基礎架構
4. **可存取性** - 確保所有核准者都可存取通道

### 安全性和合規性

1. **身份驗證** - 為所有通道實現適當的身份驗證
2. **稽核軌跡** - 為合規性維護全面的稽核日誌
3. **資料隱私** - 保護核准要求中的機密資訊
4. **存取控制** - 限制核准存取僅限授權使用者

## 疑難排解

### 常見問題

**核准逾時**：檢查逾時設定和核准者可用性

**通道故障**：驗證通道設定和網路連線

**批量處理問題**：檢查批量大小限制和分組邏輯

**稽核日誌差距**：驗證稽核記錄器設定和權限

### 偵錯提示

1. **啟用詳細日誌**以追蹤核准流
2. **檢查通道狀態**以發現連線問題
3. **監控核准計量**以發現效能問題
4. **獨立測試通道**以隔離問題

## 概念和技術

**HumanApprovalGraphNode**：一個專門的 Graph 節點，暫停執行以等待人工輸入或核准。它支援多個互動通道和可設定的逾時。

**ConfidenceGateGraphNode**：一個根據信心分數自動路由執行的節點，只在信心低於閾值時需要人工介入。

**HumanInteractionChannel**：定義如何處理人工互動的介面，支援各種通訊方法，如主控台、Web API、電子郵件和 Slack。

**HumanApprovalBatchManager**：將多個核准要求分組為批次以進行有效率處理的服務，減少通知成本並改善核准工作流程管理。

**核准工作流程**：一種模式，其中 Graph 執行在特定點暫停，允許人工決定制定，在自動化程序中啟用監督和品質控制。

## 另請參閱

* [Human-in-the-Loop](human-in-the-loop.md) - HITL 工作流程的完整指南
* [Build a Graph](build-a-graph.md) - 了解如何使用核准節點建構 Graph
* [Error Handling and Resilience](error-handling-and-resilience.md) - 妥善處理核准失敗
* [Security and Data](security-and-data.md) - 安全的 HITL 實現做法
* [Examples: HITL Workflows](../examples/hitl-example.md) - 人工介入迴圈工作流程的完整工作範例
