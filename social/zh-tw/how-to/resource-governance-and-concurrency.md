# 資源治理和並行處理

SemanticKernel.Graph 中的資源治理和並行處理管理提供了對資源分配、執行優先級和並行處理能力的細粒度控制。本指南涵蓋優先級排程、節點成本管理、資源限制和並行執行策略。

## 學習內容

* 如何使用 CPU 和記憶體限制配置資源治理
* 設定執行優先級和管理節點成本
* 使用 fork/join 模式配置並行執行
* 實現自適應速率限制和背壓
* 管理資源預算並防止消耗
* 生產環境資源管理的最佳實踐

## 概念和技術

**ResourceGovernor**：輕量級的進程內資源管理器，基於 CPU/記憶體和執行優先級提供自適應速率限制和協作排程。

**ExecutionPriority**：優先級別（Critical、High、Normal、Low）影響資源分配和排程決策。

**Node Cost Weight**：每個節點的相對成本係數，決定資源消耗和排程優先級。

**Parallel Execution**：Fork/join 執行模型，允許多個節點並行執行，同時保持確定性行為。

**Resource Leases**：臨時資源許可證，必須在節點執行前獲得並在執行後釋放。

**Adaptive Rate Limiting**：根據系統負載（CPU、記憶體）和資源可用性動態調整執行速率。

## 前提條件

* 完成 [First Graph 教程](../first-graph-5-minutes.md)
* 對圖執行概念的基本理解
* 熟悉並行程式設計概念
* 理解資源管理原則

## 資源治理配置

### 基本資源治理設置

在圖層級啟用資源治理：

```csharp
// 範例：建立 GraphExecutor 並啟用基本的進程內資源治理。
// 註解描述每個選項的用途，方便理解。
using SemanticKernel.Graph.Core;

// 建立圖執行器實例（名稱和描述是可選的元資料）。
var graph = new GraphExecutor("ResourceControlledGraph", "Graph with resource governance");

// 以開發合理預設值配置資源治理。
graph.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,            // 開啟管理器以強制許可證
    BasePermitsPerSecond = 50.0,                // 每秒授予的基礎許可證速率
    MaxBurstSize = 100,                         // 突發中允許的最大令牌數
    CpuHighWatermarkPercent = 85.0,             // 如果 CPU > 此值，應用強背壓
    CpuSoftLimitPercent = 70.0,                 // 如果 CPU > 此值，逐漸減少許可證
    MinAvailableMemoryMB = 512.0,               // 進行激進節流前的最小可用記憶體
    DefaultPriority = ExecutionPriority.Normal  // 未提供時的預設執行優先級
});
```

### 進階資源配置

配置完整的資源管理：

```csharp
// 進階配置範例：為混合工作負載調整管理器。
var advancedOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,

    // 速率限制：更高的基礎許可證和更大的突發以增加吞吐量。
    BasePermitsPerSecond = 100.0,
    MaxBurstSize = 200,

    // CPU 閾值：背壓行為的細粒度控制。
    CpuHighWatermarkPercent = 90.0,    // 在 90% 以上進行激進背壓
    CpuSoftLimitPercent = 75.0,        // 在 75% 以上開始節流

    // 記憶體閾值以 MB 表示。
    MinAvailableMemoryMB = 1024.0,     // 進行重量級工作負載前需要至少 1GB 可用

    // 預設執行優先級以優先處理更高重要性的工作。
    DefaultPriority = ExecutionPriority.High,

    // 節點特定成本權重：將節點標識符對應至相對成本。
    NodeCostWeights = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase)
    {
        ["heavy_processing"] = 3.0,     // 標記重型節點為 3 倍成本
        ["light_validation"] = 0.5,     // 輕型驗證器更便宜
        ["api_call"] = 2.0              // 外部呼叫消耗更多預算
    },

    // 允許協作搶佔，使更高優先級任務可以搶佔更低優先級任務。
    EnableCooperativePreemption = true,

    // 當存在時偏好外部指標收集器，以做出更好的決策。
    PreferMetricsCollector = true
};

graph.ConfigureResources(advancedOptions);
```

### 預設配置

為常見場景使用預定義配置：

```csharp
// 常見部署場景的預設配置。
// 開發：寬鬆配額使迭代更容易。
var devOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 200.0,
    MaxBurstSize = 500,
    CpuHighWatermarkPercent = 95.0,
    MinAvailableMemoryMB = 256.0
};

// 生產：在負載下保持穩定的保守預設值。
var prodOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 50.0,
    MaxBurstSize = 100,
    CpuHighWatermarkPercent = 80.0,
    CpuSoftLimitPercent = 65.0,
    MinAvailableMemoryMB = 2048.0,
    DefaultPriority = ExecutionPriority.Normal
};

// 高效能：對延遲敏感的工作負載瘦而寬鬆。
var perfOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 1000.0,
    MaxBurstSize = 2000,
    CpuHighWatermarkPercent = 98.0,
    MinAvailableMemoryMB = 128.0,
    EnableCooperativePreemption = false
};

// 應用最符合您環境的預設。
graph.ConfigureResources(devOptions);
```

## 執行優先級

### 優先級別和效果

配置執行優先級以控制資源分配：

```csharp
// 範例：在啟動圖前在 KernelArguments 上設定執行優先級。
// 這在許可證稀缺時為關鍵工作提供偏好。
var arguments = new KernelArguments();
arguments.SetExecutionPriority(ExecutionPriority.Critical); // 將此執行標記為關鍵

// 使用核心和優先級化的引數執行圖。
var result = await graph.ExecuteAsync(kernel, arguments);
```

### 優先級為基礎的成本調整

優先級影響資源消耗：

```csharp
// 優先級係數（較低係數 = 較低資源成本）
// Critical: 0.5x 成本（最高優先級，最低資源消耗）
// High: 0.6x 成本
// Normal: 1.0x 成本（預設）
// Low: 1.5x 成本（最低優先級，最高資源消耗）

// 範例：關鍵優先級工作獲得資源偏好
var criticalArgs = new KernelArguments();
criticalArgs.SetExecutionPriority(ExecutionPriority.Critical);

var normalArgs = new KernelArguments();
normalArgs.SetExecutionPriority(ExecutionPriority.Normal);

// 關鍵工作將消耗更少許可證並更快執行
var criticalResult = await graph.ExecuteAsync(kernel, criticalArgs);
var normalResult = await graph.ExecuteAsync(kernel, normalArgs);
```

### 自訂優先級政策

實現自訂優先級邏輯：

```csharp
// 自訂政策範例：從執行時引數衍生節點成本和優先級。
public class BusinessPriorityPolicy : ICostPolicy
{
    // 決定節點的相對成本權重（更高 => 消耗更多許可證）。
    public double? GetNodeCostWeight(IGraphNode node, GraphState state)
    {
        if (state.KernelArguments.TryGetValue("business_value", out var value))
        {
            var businessValue = Convert.ToDouble(value);
            // 將業務價值縮放為成本權重，最小合理值為 1.0。
            return Math.Max(1.0, businessValue / 100.0);
        }

        // 返回 null 表示「使用預設成本」
        return null;
    }

    // 可選地將業務等級對應至執行優先級。
    public ExecutionPriority? GetNodePriority(IGraphNode node, GraphState state)
    {
        if (state.KernelArguments.TryGetValue("customer_tier", out var tier))
        {
            return tier.ToString() switch
            {
                "premium" => ExecutionPriority.Critical,
                "gold" => ExecutionPriority.High,
                "silver" => ExecutionPriority.Normal,
                _ => ExecutionPriority.Low
            };
        }

        return null; // 未提供等級時使用預設優先級
    }
}

// 註冊政策，使執行器可在執行時參考。
graph.AddMetadata(nameof(ICostPolicy), new BusinessPriorityPolicy());
```

## 節點成本管理

### 設定節點成本

為不同類型的節點配置成本：

```csharp
// 範例：為常見節點標識符聲明靜態節點成本覆蓋。
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 100.0,
    NodeCostWeights = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase)
    {
        // 重型計算：消耗相當更多的許可證。
        ["image_processing"] = 5.0,
        ["ml_inference"] = 3.0,
        ["data_aggregation"] = 2.5,

        // 輕量級檢查：運行成本低。
        ["input_validation"] = 0.3,
        ["format_check"] = 0.2,

        // 外部呼叫和資料庫查詢比記憶體內操作成本更高。
        ["openai_api"] = 2.0,
        ["database_query"] = 1.5,

        // 未指定節點的後備預設權重。
        ["*"] = 1.0
    }
};

graph.ConfigureResources(resourceOptions);
```

### 動態成本計算

基於執行時狀態計算成本：

```csharp
// 自適應成本政策：從執行時引數計算成本（資料大小、複雜度）。
public class AdaptiveCostPolicy : ICostPolicy
{
    public double? GetNodeCostWeight(IGraphNode node, GraphState state)
    {
        // 如果存在資料大小提示，將其對應至成本權重。
        if (state.KernelArguments.TryGetValue("data_size_mb", out var sizeObj))
        {
            var sizeMB = Convert.ToDouble(sizeObj);
            if (sizeMB > 100) return 5.0;  // 非常大的負載很昂貴
            if (sizeMB > 10) return 2.0;   // 中等負載具有中等成本
            return 0.5;                     // 小負載很便宜
        }

        // 如果提供，使用單獨的複雜度提示。
        if (state.KernelArguments.TryGetValue("complexity_level", out var complexityObj))
        {
            var complexity = Convert.ToInt32(complexityObj);
            return Math.Max(0.5, complexity * 0.5);
        }

        // 返回 null 使用預設成本對應。
        return null;
    }
}

// 註冊自適應政策，以在執行期間被參考。
graph.AddMetadata(nameof(ICostPolicy), new AdaptiveCostPolicy());
```

### 通過引數覆蓋成本

在執行時覆蓋成本：

```csharp
// 在引數中覆蓋節點成本
var arguments = new KernelArguments();
arguments.SetEstimatedNodeCostWeight(2.5); // 此執行的 2.5 倍成本

// 使用自訂成本執行
var result = await graph.ExecuteAsync(kernel, arguments);
```

## 並行執行配置

### 基本並行執行

為獨立分支啟用並行執行：

```csharp
// 配置並行性選項以安全地並行運行獨立分支。
graph.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,                         // 允許並行 fork/join 執行
    MaxDegreeOfParallelism = 4,                             // 要執行的最大並行分支數
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond, // 狀態結合時的合併策略
    FallbackToSequentialOnCycles = true                     // 檢測到週期時保守使用
});
```

### 進階並行配置

配置精進的並行執行：

```csharp
var concurrencyOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    
    // 並行性限制
    MaxDegreeOfParallelism = Environment.ProcessorCount * 2, // 2 倍 CPU 核心數
    
    // 衝突解決政策
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    
    // 週期處理
    FallbackToSequentialOnCycles = true
};

graph.ConfigureConcurrency(concurrencyOptions);
```

### Fork/Join 執行

建立並行執行模式：

```csharp
// Fork/join 範例：建立並行分支 A、B、C 合併至合併節點。
// 這裡我們建構節點、連接它們並啟用並行性和資源治理。
var graph = new GraphExecutor("ParallelGraph", "Graph with parallel execution");

// 新增節點（範例委託或核心函數由佔位符表示）。
graph.AddNode(new FunctionGraphNode(ProcessDataA, "process_a"));
graph.AddNode(new FunctionGraphNode(ProcessDataB, "process_b"));
graph.AddNode(new FunctionGraphNode(ProcessDataC, "process_c"));
graph.AddNode(new FunctionGraphNode(MergeResults, "merge"));

// 連接圖邊：start -> process_a、b、c，每個 process -> merge
graph.Connect("start", "process_a");
graph.Connect("start", "process_b");
graph.Connect("start", "process_c");
graph.Connect("process_a", "merge");
graph.Connect("process_b", "merge");
graph.Connect("process_c", "merge");
graph.SetStartNode("start");

// 啟用適合此小型 fork/join 的並行執行和資源治理。
graph.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = 3
});

graph.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 100.0,
    MaxBurstSize = 3
});

// 執行圖（假設 'kernel' 和 'arguments' 已在作用域中準備）。
var result = await graph.ExecuteAsync(kernel, arguments);
```

## 資源監控和適應

### 系統負載監控

監控並適應系統狀況：

```csharp
// 啟用輕量級開發指標以在測試期間觀察資源使用。
graph.EnableDevelopmentMetrics();

// 讓資源管理器在可用時偏好指標進行自適應決策。
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    PreferMetricsCollector = true,
    CpuHighWatermarkPercent = 85.0,
    CpuSoftLimitPercent = 70.0,
    MinAvailableMemoryMB = 1024.0
};

graph.ConfigureResources(resourceOptions);
```

### 手動負載更新

手動更新系統負載資訊：

```csharp
// 檢索目前的效能指標並可選地將其提供給管理器。
var metrics = graph.GetPerformanceMetrics();
if (metrics != null)
{
    var cpuUsage = metrics.CurrentCpuUsage;                    // 目前 CPU 百分比
    var availableMemory = metrics.CurrentAvailableMemoryMB;    // 可用記憶體（MB）

    // 如果管理器暴露，當未使用自動指標時允許手動更新。
    if (graph.GetResourceGovernor() is ResourceGovernor governor)
    {
        governor.UpdateSystemLoad(cpuUsage, availableMemory);
    }
}
```

### 預算耗盡處理

處理資源預算耗盡：

```csharp
// 處理預算耗盡事件以實現警告或優雅降級。
if (graph.GetResourceGovernor() is ResourceGovernor governor)
{
    governor.BudgetExhausted += (sender, args) =>
    {
        // 記錄有關耗盡事件的基本資訊。
        Console.WriteLine($"🚨 資源預算於 {args.Timestamp} 耗盡");
        Console.WriteLine($"   CPU: {args.CpuUsage:F1}%");
        Console.WriteLine($"   記憶體: {args.AvailableMemoryMB:F0} MB");
        Console.WriteLine($"   耗盡次數: {args.ExhaustionCount}");

        // 使用者定義處理策略的佔位符呼叫。
        // 實現者應使用真實遙測/警告代碼替換這些。
        LogResourceExhaustion(args);
        SendResourceAlert(args);
    };
}
```

## 效能優化

### 資源管理器調整

為您的工作負載優化資源管理器：

```csharp
// 適用於不同工作負載特徵的效能調整預設。
var highThroughputOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 500.0,
    MaxBurstSize = 1000,
    CpuHighWatermarkPercent = 95.0,
    CpuSoftLimitPercent = 85.0,
    MinAvailableMemoryMB = 256.0,
    EnableCooperativePreemption = false
};

var lowLatencyOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 50.0,
    MaxBurstSize = 100,
    CpuHighWatermarkPercent = 70.0,
    CpuSoftLimitPercent = 50.0,
    MinAvailableMemoryMB = 2048.0,
    EnableCooperativePreemption = true
};

// 應用適合您場景的配置。
graph.ConfigureResources(highThroughputOptions);
```

### 並行執行優化

優化並行執行模式：

```csharp
// 為 CPU 綁定的工作負載優化
var cpuOptimizedOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount, // 符合 CPU 核心數
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = false  // 允許複雜的並行模式
};

// 為 I/O 綁定的工作負載優化
var ioOptimizedOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount * 4, // I/O 的更高並行性
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = true   // I/O 時保守
};

graph.ConfigureConcurrency(cpuOptimizedOptions);
```

## 最佳實踐

### 資源治理配置

* **開始保守**：從較低的許可證速率開始，根據效能增加
* **監控系統負載**：使用指標整合以實現自動適應
* **設定合理閾值**：CPU 閾值應與您的 SLO 對齊
* **記憶體管理**：根據可用系統資源設定記憶體閾值
* **優先級策略**：使用優先級確保關鍵工作獲得資源

### 並行執行

* **識別獨立分支**：僅並行化真正獨立的工作
* **管理狀態衝突**：選擇適當的合併衝突政策
* **限制並行性**：不要超過合理的並行性限制
* **處理週期**：為複雜週期使用回到順序執行
* **資源協調**：確保資源治理與並行執行協作

### 效能調整

* **分析您的工作負載**：了解資源消耗模式
* **調整突發大小**：平衡回應性和穩定性
* **監控耗盡**：追蹤預算耗盡事件
* **適應負載**：在可能時使用自動負載適應
* **在負載下測試**：在預期的負載條件下驗證效能

### 生產考量

* **資源限制**：為生產穩定性設定保守限制
* **監控**：實現完整的資源監控
* **警告**：為資源耗盡設定警告
* **擴展**：當達到資源限制時規劃水平擴展
* **回退**：在資源受限時實現優雅降級

## 故障排除

### 常見問題

**高資源消耗**：減少 `BasePermitsPerSecond` 和 `MaxBurstSize`，啟用資源監控。

**頻繁預算耗盡**：增加資源閾值、減少節點成本，或實現更好的資源管理。

**並行效能差**：檢查 `MaxDegreeOfParallelism`、驗證獨立分支，並監控資源爭用。

**記憶體壓力**：增加 `MinAvailableMemoryMB`、減少 `MaxBurstSize`，或實現記憶體清理。

### 效能優化

```csharp
// 為資源受限環境優化
var optimizedOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 25.0,           // 較低的基本速率
    MaxBurstSize = 50,                     // 更小的突發許可
    CpuHighWatermarkPercent = 75.0,        // 提早背壓
    CpuSoftLimitPercent = 60.0,            // 提早節流
    MinAvailableMemoryMB = 2048.0,         // 更高的記憶體閾值
    EnableCooperativePreemption = true,    // 啟用以提高回應性
    PreferMetricsCollector = true          // 使用指標進行適應
};

graph.ConfigureResources(optimizedOptions);
```

## 另見

* [指標和可觀測性](metrics-and-observability.md) - 監控資源使用和效能
* [圖執行](../concepts/execution.md) - 理解執行生命週期和模式
* [狀態管理](../concepts/state.md) - 在並行執行中管理狀態
* [範例](../../examples/) - 資源治理和並行處理的實踐範例
