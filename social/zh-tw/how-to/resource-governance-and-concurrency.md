# 資源治理與並發

SemanticKernel.Graph 中的資源治理和並發管理提供對資源配置、執行優先級和並行處理能力的細粒度控制。本指南涵蓋基於優先級的排程、Node 成本管理、資源限制和並行執行策略。

## 您將學到

* 如何以 CPU 和記憶體限制配置資源治理
* 設置執行優先級並管理 Node 成本
* 設定帶有 fork/join 模式的並行執行
* 實現自適應速率限制和反向壓力
* 管理資源預算並防止耗盡
* 生產環境中資源管理的最佳實踐

## 概念和技術

**ResourceGovernor**: 輕量級進程內資源治理器，提供基於 CPU/記憶體和執行優先級的自適應速率限制和協作排程。

**ExecutionPriority**: 優先級級別 (Critical、High、Normal、Low)，影響資源配置和排程決策。

**Node Cost Weight**: 每個 Node 的相對成本因子，決定資源消耗和排程優先級。

**Parallel Execution**: Fork/join 執行模型，允許多個 Node 並發執行，同時保持確定性行為。

**Resource Leases**: 臨時資源許可，必須在 Node 執行前獲得並在之後釋放。

**Adaptive Rate Limiting**: 根據系統負載 (CPU、記憶體) 和資源可用性動態調整執行速率。

## 先決條件

* 已完成 [First Graph Tutorial](../first-graph-5-minutes.md)
* 對 Graph 執行概念的基本理解
* 熟悉並行編程概念
* 理解資源管理原則

## 資源治理配置

### 基本資源治理設置

在 Graph 級別啟用資源治理：

```csharp
// 範例：建立 GraphExecutor 並啟用基本進程內資源治理。
// 註解以純英文描述每個選項的意圖以供清晰理解。
using SemanticKernel.Graph.Core;

// 建立 Graph Executor 實例 (名稱和描述是可選的中繼資料)。
var graph = new GraphExecutor("ResourceControlledGraph", "Graph with resource governance");

// 使用合理的開發預設值配置資源治理。
graph.ConfigureResources(new GraphResourceOptions
{
    EnableResourceGovernance = true,            // 開啟治理器以強制執行許可
    BasePermitsPerSecond = 50.0,                // 每秒授予的基本許可速率
    MaxBurstSize = 100,                         // 突發中允許的最大令牌數
    CpuHighWatermarkPercent = 85.0,             // 如果 CPU > 此值，應用強反向壓力
    CpuSoftLimitPercent = 70.0,                 // 如果 CPU > 此值，逐漸減少許可
    MinAvailableMemoryMB = 512.0,               // 在進行激進限流前的最小可用記憶體
    DefaultPriority = ExecutionPriority.Normal  // 未提供時的預設執行優先級
});
```

### 進階資源配置

配置全面的資源管理：

```csharp
// 進階配置範例：為混合工作負載調整治理器。
var advancedOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,

    // 速率限制：更高的基本許可和更大的突發以提高吞吐量。
    BasePermitsPerSecond = 100.0,
    MaxBurstSize = 200,

    // CPU 閾值：反向壓力行為的細粒度控制。
    CpuHighWatermarkPercent = 90.0,    // CPU 超過 90% 時激進反向壓力
    CpuSoftLimitPercent = 75.0,        // CPU 超過 75% 時開始限流

    // 以 MB 為單位的記憶體閾值。
    MinAvailableMemoryMB = 1024.0,     // 在進行繁重工作負載前至少需要 1GB 可用

    // 預設執行優先級以優先進行更高重要性的工作。
    DefaultPriority = ExecutionPriority.High,

    // Node 特定的成本權重：將 Node 識別碼對應至相對成本。
    NodeCostWeights = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase)
    {
        ["heavy_processing"] = 3.0,     // 將繁重 Node 標記為 3 倍成本
        ["light_validation"] = 0.5,     // 輕量驗證器較便宜
        ["api_call"] = 2.0              // 外部呼叫消耗更多預算
    },

    // 允許協作搶占，以便優先級更高的工作可以搶占優先級較低的工作。
    EnableCooperativePreemption = true,

    // 在存在外部度量收集器時優先使用以做出更佳決策。
    PreferMetricsCollector = true
};

graph.ConfigureResources(advancedOptions);
```

### 預設配置

對常見情境使用預先定義的配置：

```csharp
// 常見部署情境的預設配置。
// 開發：寬鬆的配額，使迭代更容易。
var devOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 200.0,
    MaxBurstSize = 500,
    CpuHighWatermarkPercent = 95.0,
    MinAvailableMemoryMB = 256.0
};

// 生產：保守的預設值，在負載下保持穩定。
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

// 高效能：瘦但寬鬆，適用於延遲敏感的工作負載。
var perfOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 1000.0,
    MaxBurstSize = 2000,
    CpuHighWatermarkPercent = 98.0,
    MinAvailableMemoryMB = 128.0,
    EnableCooperativePreemption = false
};

// 應用最適合您環境的預設值。
graph.ConfigureResources(devOptions);
```

## 執行優先級

### 優先級級別和效果

配置執行優先級以控制資源配置：

```csharp
// 範例：在啟動 Graph 前在 KernelArguments 上設置執行優先級。
// 這在許可稀缺時為關鍵工作提供偏好。
var arguments = new KernelArguments();
arguments.SetExecutionPriority(ExecutionPriority.Critical); // 將此執行標記為關鍵

// 使用 Kernel 和優先級化的引數執行 Graph。
var result = await graph.ExecuteAsync(kernel, arguments);
```

### 基於優先級的成本調整

優先級影響資源消耗：

```csharp
// 優先級因子 (較低因子 = 較低資源成本)
// Critical: 0.5x 成本 (最高優先級，最低資源消耗)
// High: 0.6x 成本
// Normal: 1.0x 成本 (預設)
// Low: 1.5x 成本 (最低優先級，最高資源消耗)

// 範例：Critical 優先級工作獲得資源偏好
var criticalArgs = new KernelArguments();
criticalArgs.SetExecutionPriority(ExecutionPriority.Critical);

var normalArgs = new KernelArguments();
normalArgs.SetExecutionPriority(ExecutionPriority.Normal);

// Critical 工作將消耗更少的許可並更快執行
var criticalResult = await graph.ExecuteAsync(kernel, criticalArgs);
var normalResult = await graph.ExecuteAsync(kernel, normalArgs);
```

### 自訂優先級策略

實現自訂優先級邏輯：

```csharp
// 自訂原則範例：從執行時引數衍生 Node 成本和優先級。
public class BusinessPriorityPolicy : ICostPolicy
{
    // 決定 Node 的相對成本權重 (較高 => 消耗更多許可)。
    public double? GetNodeCostWeight(IGraphNode node, GraphState state)
    {
        if (state.KernelArguments.TryGetValue("business_value", out var value))
        {
            var businessValue = Convert.ToDouble(value);
            // 將業務價值縮放至成本權重，最小合理值為 1.0。
            return Math.Max(1.0, businessValue / 100.0);
        }

        // 返回 null 表示 "使用預設成本"
        return null;
    }

    // 選擇性地將業務等級對應至執行優先級。
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

// 註冊原則，以便執行器可在執行時查詢它。
graph.AddMetadata(nameof(ICostPolicy), new BusinessPriorityPolicy());
```

## Node 成本管理

### 設置 Node 成本

為不同類型的 Node 配置成本：

```csharp
// 範例：為常見 Node 識別碼宣告靜態 Node 成本覆蓋。
var resourceOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 100.0,
    NodeCostWeights = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase)
    {
        // 繁重計算：消耗大量更多許可。
        ["image_processing"] = 5.0,
        ["ml_inference"] = 3.0,
        ["data_aggregation"] = 2.5,

        // 輕量級檢查：執行便宜。
        ["input_validation"] = 0.3,
        ["format_check"] = 0.2,

        // 外部呼叫和 DB 查詢比記憶體內操作成本更高。
        ["openai_api"] = 2.0,
        ["database_query"] = 1.5,

        // 未指定 Node 的回退預設權重。
        ["*"] = 1.0
    }
};

graph.ConfigureResources(resourceOptions);
```

### 動態成本計算

基於執行時狀態計算成本：

```csharp
// 自適應成本原則：從執行時引數計算成本 (資料大小、複雜性)。
public class AdaptiveCostPolicy : ICostPolicy
{
    public double? GetNodeCostWeight(IGraphNode node, GraphState state)
    {
        // 如果存在資料大小提示，將其對應至成本權重。
        if (state.KernelArguments.TryGetValue("data_size_mb", out var sizeObj))
        {
            var sizeMB = Convert.ToDouble(sizeObj);
            if (sizeMB > 100) return 5.0;  // 非常大的有效負載很昂貴
            if (sizeMB > 10) return 2.0;   // 中等有效負載有適度成本
            return 0.5;                     // 小有效負載很便宜
        }

        // 如果提供了複雜性提示，使用單獨的複雜性提示。
        if (state.KernelArguments.TryGetValue("complexity_level", out var complexityObj))
        {
            var complexity = Convert.ToInt32(complexityObj);
            return Math.Max(0.5, complexity * 0.5);
        }

        // 返回 null 使用預設成本對應。
        return null;
    }
}

// 註冊自適應原則，以便在執行期間查詢它。
graph.AddMetadata(nameof(ICostPolicy), new AdaptiveCostPolicy());
```

### 透過引數覆蓋成本

在執行時覆蓋成本：

```csharp
// 在引數中覆蓋 Node 成本
var arguments = new KernelArguments();
arguments.SetEstimatedNodeCostWeight(2.5); // 此執行的成本為 2.5 倍

// 使用自訂成本執行
var result = await graph.ExecuteAsync(kernel, arguments);
```

## 並行執行配置

### 基本並行執行

為獨立分支啟用並行執行：

```csharp
// 配置並發選項以安全地並行執行獨立分支。
graph.ConfigureConcurrency(new GraphConcurrencyOptions
{
    EnableParallelExecution = true,                         // 允許並行 fork/join 執行
    MaxDegreeOfParallelism = 4,                             // 要執行的最大並發分支
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond, // 狀態連接的合併策略
    FallbackToSequentialOnCycles = true                     // 檢測到週期時保持保守
});
```

### 進階並行配置

配置複雜的並行執行：

```csharp
var concurrencyOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    
    // 並行限制
    MaxDegreeOfParallelism = Environment.ProcessorCount * 2, // 2 倍 CPU 核心
    
    // 衝突解決原則
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    
    // 週期處理
    FallbackToSequentialOnCycles = true
};

graph.ConfigureConcurrency(concurrencyOptions);
```

### Fork/Join 執行

建立並行執行模式：

```csharp
// Fork/join 範例：建立並行分支 A、B、C，連接至合併 Node。
// 在這裡我們建構 Node、連接它們，並同時啟用並發和資源治理。
var graph = new GraphExecutor("ParallelGraph", "Graph with parallel execution");

// 新增 Node (範例委派或 Kernel 函式由預留位置表示)。
graph.AddNode(new FunctionGraphNode(ProcessDataA, "process_a"));
graph.AddNode(new FunctionGraphNode(ProcessDataB, "process_b"));
graph.AddNode(new FunctionGraphNode(ProcessDataC, "process_c"));
graph.AddNode(new FunctionGraphNode(MergeResults, "merge"));

// 佈線 Graph Edge：start -> process_a、b、c，以及每個 process -> merge
graph.Connect("start", "process_a");
graph.Connect("start", "process_b");
graph.Connect("start", "process_c");
graph.Connect("process_a", "merge");
graph.Connect("process_b", "merge");
graph.Connect("process_c", "merge");
graph.SetStartNode("start");

// 啟用並行執行和適合此小型 fork/join 的資源治理。
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

// 執行 Graph (假設 'kernel' 和 'arguments' 已在範圍內準備)。
var result = await graph.ExecuteAsync(kernel, arguments);
```

## 資源監控和自適應

### 系統負載監控

監控並適應系統狀況：

```csharp
// 啟用輕量級開發度量以觀察測試期間的資源使用情況。
graph.EnableDevelopmentMetrics();

// 讓資源治理器在可用時優先使用度量以做出自適應決策。
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
// 檢索目前的效能度量，並可選擇將其提供給治理器。
var metrics = graph.GetPerformanceMetrics();
if (metrics != null)
{
    var cpuUsage = metrics.CurrentCpuUsage;                    // 目前 CPU 百分比
    var availableMemory = metrics.CurrentAvailableMemoryMB;    // MB 中的可用記憶體

    // 如果治理器已公開，在未使用自動度量時允許手動更新。
    if (graph.GetResourceGovernor() is ResourceGovernor governor)
    {
        governor.UpdateSystemLoad(cpuUsage, availableMemory);
    }
}
```

### 預算耗盡處理

處理資源預算耗盡：

```csharp
// 處理預算耗盡事件以實現警報或優雅降級。
if (graph.GetResourceGovernor() is ResourceGovernor governor)
{
    governor.BudgetExhausted += (sender, args) =>
    {
        // 記錄耗盡事件的基本資訊。
        Console.WriteLine($"🚨 Resource budget exhausted at {args.Timestamp}");
        Console.WriteLine($"   CPU: {args.CpuUsage:F1}%");
        Console.WriteLine($"   Memory: {args.AvailableMemoryMB:F0} MB");
        Console.WriteLine($"   Exhaustion count: {args.ExhaustionCount}");

        // 使用者定義的處理策略的預留位置呼叫。
        // 實作者應用真實的遙測/警報程式碼取代這些。
        LogResourceExhaustion(args);
        SendResourceAlert(args);
    };
}
```

## 效能最佳化

### 資源治理器調整

針對您的工作負載最佳化資源治理器：

```csharp
// 針對不同工作負載特性的效能調整預設值。
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

// 應用適合您的情境的配置。
graph.ConfigureResources(highThroughputOptions);
```

### 並行執行最佳化

最佳化並行執行模式：

```csharp
// 為 CPU 繫結的工作負載最佳化
var cpuOptimizedOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount, // 符合 CPU 核心
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = false  // 允許複雜的並行模式
};

// 為 I/O 繫結的工作負載最佳化
var ioOptimizedOptions = new GraphConcurrencyOptions
{
    EnableParallelExecution = true,
    MaxDegreeOfParallelism = Environment.ProcessorCount * 4, // 為 I/O 提高並行度
    MergeConflictPolicy = StateMergeConflictPolicy.PreferSecond,
    FallbackToSequentialOnCycles = true   // 為 I/O 保持保守
};

graph.ConfigureConcurrency(cpuOptimizedOptions);
```

## 最佳實踐

### 資源治理配置

* **開始保守**：從較低的許可速率開始，根據效能增加
* **監控系統負載**：使用度量整合進行自動自適應
* **設置合理的閾值**：CPU 閾值應與您的 SLO 對齊
* **記憶體管理**：根據可用的系統資源設置記憶體閾值
* **優先級策略**：使用優先級確保關鍵工作獲得資源

### 並行執行

* **識別獨立分支**：僅並行化真正獨立的工作
* **管理狀態衝突**：選擇適當的合併衝突原則
* **限制並行度**：不要超過合理的並行度限制
* **處理週期**：對複雜的週期使用回退至順序執行
* **資源協調**：確保資源治理與並行執行配合

### 效能調整

* **概況分析工作負載**：了解資源消耗模式
* **調整突發大小**：平衡回應能力和穩定性
* **監控耗盡**：追蹤預算耗盡事件
* **適應負載**：在可能的情況下使用自動負載自適應
* **在負載下測試**：在預期的負載條件下驗證效能

### 生產環境考慮事項

* **資源限制**：為生產穩定性設置保守的限制
* **監控**：實施全面的資源監控
* **警報**：為資源耗盡設置警報
* **擴展**：當達到資源限制時規劃水平擴展
* **回退**：在資源受限時實現優雅降級

## 疑難排解

### 常見問題

**高資源消耗**：減少 `BasePermitsPerSecond` 和 `MaxBurstSize`，啟用資源監控。

**頻繁的預算耗盡**：增加資源閾值、減少 Node 成本或實施更佳的資源管理。

**並行效能差**：檢查 `MaxDegreeOfParallelism`、驗證獨立分支，並監控資源爭用。

**記憶體壓力**：增加 `MinAvailableMemoryMB`、減少 `MaxBurstSize`，或實施記憶體清理。

### 效能最佳化

```csharp
// 針對資源受限的環境最佳化
var optimizedOptions = new GraphResourceOptions
{
    EnableResourceGovernance = true,
    BasePermitsPerSecond = 25.0,           // 較低的基本速率
    MaxBurstSize = 50,                     // 較小的突發額度
    CpuHighWatermarkPercent = 75.0,        // 早期反向壓力
    CpuSoftLimitPercent = 60.0,            // 早期限流
    MinAvailableMemoryMB = 2048.0,         // 更高的記憶體閾值
    EnableCooperativePreemption = true,    // 為回應能力啟用
    PreferMetricsCollector = true          // 使用度量進行自適應
};

graph.ConfigureResources(optimizedOptions);
```

## 亦可參閱

* [Metrics and Observability](metrics-and-observability.md) - 監控資源使用情況和效能
* [Graph Execution](../concepts/execution.md) - 了解執行生命週期和模式
* [State Management](../concepts/state.md) - 在並行執行中管理狀態
* [Examples](../../examples/) - 資源治理和並發的實用範例
