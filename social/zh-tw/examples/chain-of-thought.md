# 思維鏈（Chain of Thought）示例

此示例演示如何使用語義核心圖（Semantic Kernel Graph）實現思維鏈推理模式。展示了不同的推理類型、驗證、回溯和模板自訂，用於逐步解決問題。

## 目標

學習如何在基於圖的工作流中實現思維鏈推理，以便：
* 將複雜問題分解為邏輯步驟
* 在每個步驟驗證推理品質
* 當推理失敗時啟用回溯
* 為不同用例自訂推理模板
* 監控和最佳化推理性能

## 前置需求

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中設定
* **語義核心圖套件**已安裝
* 基本了解[圖概念](../concepts/graph-concepts.md)和[節點類型](../concepts/node-types.md)

## 主要元件

### 概念和技術

* **思維鏈**：一種推理模式，AI 將複雜問題分解為順序步驟，展示其思考過程
* **推理驗證**：使用信心評分和驗證規則對每個推理步驟進行品質評估
* **回溯**：能夠使用不同方法重試失敗的推理步驟
* **模板引擎**：針對不同問題領域的可自訂提示和推理模式

### 核心類別

* `ChainOfThoughtGraphNode`：實現思維鏈推理的主要節點
* `ChainOfThoughtTemplateEngine`：管理推理模板和驗證
* `ChainOfThoughtType`：推理策略的列舉（ProblemSolving、Analysis、DecisionMaking）
* `ChainOfThoughtValidator`：驗證推理品質和信心

## 運行示例

### 入門

此示例演示使用語義核心圖套件的思維鏈推理模式。下面的代碼片段展示如何在自己的應用程式中實現此模式。

### 實現概述

下面的示例展示如何在自己的應用程式中實現思維鏈推理：

## 逐步實現

### 1. 使用思維鏈進行問題解決

此示例演示了基本的問題解決與逐步推理。

```csharp
// 建立一個配置為問題解決的思維鏈節點。
// 該節點支持回溯、最小信心閾值和可選的快取。
var cotNode = new ChainOfThoughtGraphNode(
    ChainOfThoughtType.ProblemSolving,
    maxSteps: 5,
    templateEngine: templateEngine,
    logger: logger)
{
    BacktrackingEnabled = true,
    MinimumStepConfidence = 0.6,
    CachingEnabled = true
};

// 建立圖形執行器、註冊節點並將其設為起始節點。
var executor = new GraphExecutor("ChainOfThought-ProblemSolving", "Chain-of-Thought problem solving example", logger);
executor.AddNode(cotNode);
executor.SetStartNode(cotNode.NodeId);

// 為思維鏈執行準備輸入參數。
var arguments = new KernelArguments
{
    ["problem_statement"] = "A company needs to reduce operational costs by 20% while maintaining employee satisfaction. They have 1000 employees and current annual costs of $50M.",
    ["context"] = "Competitive tech market with high talent retention challenges.",
    ["constraints"] = "Cannot reduce headcount by more than 5%; must maintain benefit levels; implement within 6 months.",
    ["expected_outcome"] = "A concrete cost reduction plan with prioritized actions.",
    ["reasoning_depth"] = 4
};

// 執行圖形並獲得最終推理結果。
var result = await executor.ExecuteAsync(kernel, arguments, CancellationToken.None);
```

### 2. 使用自訂模板進行分析

演示自訂推理模板和驗證規則。

```csharp
// 為業務分析定義自訂分析模板和驗證規則。
var customTemplates = new Dictionary<string, string>
{
    ["step_1"] = @"You are analyzing a complex situation. This is step {{step_number}}.

Situation: {{problem_statement}}
Context: {{context}}

Start by identifying the key stakeholders and their interests. Who are the main parties involved and what do they care about?

Your analysis:",

    ["analysis_step"] = @"Continue your analysis. This is step {{step_number}} of {{max_steps}}.

Previous analysis:
{{previous_steps}}

Now examine the following aspect: What are the underlying causes and contributing factors? Look deeper than surface-level observations.

Your analysis:"
};

// 建立自訂驗證規則（示例稍後在本文檔中顯示）
var customRules = new List<IChainOfThoughtValidationRule>
{
    new StakeholderAnalysisRule(),
    new CausalAnalysisRule()
};

// 使用自訂模板和規則建立思維鏈節點。
var analysisNode = ChainOfThoughtGraphNode.CreateWithCustomization(
    ChainOfThoughtType.Analysis,
    customTemplates,
    customRules,
    maxSteps: 4,
    templateEngine: templateEngine,
    logger: logger);
```

### 3. 使用回溯進行決策制定

展示推理失敗時如何實現回溯。

```csharp
// 配置啟用了回溯的決策製定節點。
var decisionNode = new ChainOfThoughtGraphNode(
    ChainOfThoughtType.DecisionMaking,
    maxSteps: 4,
    templateEngine: templateEngine,
    logger: logger)
{
    BacktrackingEnabled = true,
    // 注意：MaxBacktrackAttempts 和 BacktrackStrategy 是說明性的
    // 可能在驗證器/回溯層實現。
    MinimumStepConfidence = 0.8
};

// 當驗證信心低於配置的閾值時，該節點將嘗試回溯
//（如果啟用了回溯支援）。
```

### 4. 性能和快取示例

使用快取和指標最佳化推理性能。

```csharp
// 建立啟用了快取和可選性能監控的節點。
var performanceNode = new ChainOfThoughtGraphNode(
    ChainOfThoughtType.ProblemSolving,
    maxSteps: 5,
    templateEngine: templateEngine,
    logger: logger)
{
    CachingEnabled = true
    // CacheExpiration 和性能閾值是實現細節
    // 在某些節點實現上可用。在支援時使用它們。
};

// 列印基本節點統計資訊以進行快速驗證。
Console.WriteLine($"Node Statistics: {cotNode.Statistics.ExecutionCount} executions, " +
                  $"{cotNode.Statistics.AverageQualityScore:P1} avg quality, " +
                  $"{cotNode.Statistics.SuccessRate:P1} success rate");
```

## 預期輸出

### 問題解決示例

```
🧠 Starting problem-solving reasoning...
📝 Step 1: Analyzing cost structure and employee satisfaction factors
✅ Step 1 completed with confidence: 0.85
📝 Step 2: Identifying cost reduction opportunities
✅ Step 2 completed with confidence: 0.78
📝 Step 3: Evaluating impact on employee satisfaction
✅ Step 3 completed with confidence: 0.82
📝 Step 4: Developing implementation plan
✅ Step 4 completed with confidence: 0.79

✅ Final Answer: Comprehensive cost reduction plan including:
* Process optimization (8% savings)
* Technology automation (7% savings)
* Vendor renegotiation (5% savings)
* Total: 20% cost reduction while maintaining satisfaction

📊 Node Statistics: 1 executions, 81.0% avg quality, 100% success rate
```

### 分析示例

```
🔍 Starting business analysis with custom template...
📋 Using template: BusinessAnalysis
📝 Step 1: Identify the core business problem
✅ Step 1 completed with confidence: 0.88
📝 Step 2: Analyze current state and constraints
✅ Step 2 completed with confidence: 0.85
📝 Step 3: Generate potential solutions
✅ Step 3 completed with confidence: 0.82
📝 Step 4: Evaluate solutions against criteria
✅ Step 4 completed with confidence: 0.86
📝 Step 5: Recommend optimal approach
✅ Step 5 completed with confidence: 0.89

🎯 Analysis Complete: Strategic recommendations with implementation roadmap
```

## 配置選項

### 思維鏈設定

```csharp
// 代表思維鏈設定的示例配置物件。
// 並非所有實現都公開單一選項類別；許多節點
// 屬性直接在節點實例上設定。
var cotOptions = new
{
    MaxSteps = 5,
    MinimumStepConfidence = 0.6,
    EnableBacktracking = true,
    MaxBacktrackAttempts = 3,
    CachingEnabled = true,
    CacheExpiration = TimeSpan.FromHours(24),
    EnableStepValidation = true,
    PerformanceThreshold = TimeSpan.FromSeconds(30)
};
```

### 模板配置

```csharp
var templateOptions = new ChainOfThoughtTemplateOptions
{
    DefaultTemplate = ChainOfThoughtType.ProblemSolving,
    CustomTemplates = new Dictionary<string, ChainOfThoughtTemplate>
    {
        ["BusinessAnalysis"] = businessAnalysisTemplate,
        ["TechnicalReview"] = technicalReviewTemplate,
        ["RiskAssessment"] = riskAssessmentTemplate
    },
    ValidationRules = new[]
    {
        "All steps must be logical and sequential",
        "Each step must build on previous steps",
        "Final answer must address the original problem"
    }
};
```

## 疑難排解

### 常見問題

#### 信心評分低

```bash
# 問題：步驟始終未通過信心驗證
# 解決方案：調整信心閾值或改進提示品質
MinimumStepConfidence = 0.5; // 在開發中降低閾值
```

#### 過度回溯

```bash
# 問題：回溯嘗試過多
# 解決方案：限制回溯嘗試或改進初始推理
MaxBacktrackAttempts = 2; // 減少重試次數
```

#### 性能問題

```bash
# 問題：推理執行緩慢
# 解決方案：啟用快取並設定性能閾值
CachingEnabled = true;
PerformanceThreshold = TimeSpan.FromSeconds(60);
```

### 調試模式

啟用詳細日誌以進行疑難排解：

```csharp
// 為調試建立主控台記錄器並配置節點以發出
// 詳細的推理日誌（如果節點實現支援）。
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<ChainOfThoughtGraphNode>();

var debugNode = new ChainOfThoughtGraphNode(
    ChainOfThoughtType.ProblemSolving,
    maxSteps: 5,
    templateEngine: templateEngine,
    logger: logger)
{
    // 這些旗標是示例；實際屬性名稱可能因版本而異。
    // 在有呈現的地方啟用節點實現內的詳細日誌記錄。
};
```

## 進階模式

### 多步驟驗證

```csharp
// 實現自訂驗證邏輯
var customValidator = new ChainOfThoughtValidator
{
    StepValidators = new[]
    {
        new StepValidator("LogicalFlow", step => ValidateLogicalFlow(step)),
        new StepValidator("DataReference", step => ValidateDataReference(step)),
        new StepValidator("Actionability", step => ValidateActionability(step))
    }
};

cotNode.Validator = customValidator;
```

### 動態模板選擇

```csharp
// 根據問題類型選擇模板
var templateSelector = new TemplateSelector
{
    Selector = (context) =>
    {
        var problemType = context.GetValue<string>("problem_type");
        return problemType switch
        {
            "business" => "BusinessAnalysis",
            "technical" => "TechnicalReview",
            "risk" => "RiskAssessment",
            _ => "ProblemSolving"
        };
    }
};

cotNode.TemplateSelector = templateSelector;
```

## 相關示例

* [ReAct 代理](./react-agent.md)：推理和行動迴圈
* [ReAct 問題解決](./react-problem-solving.md)：複雜問題分解
* [條件節點](./conditional-nodes.md)：基於推理結果的動態路由
* [圖形指標](./graph-metrics.md)：性能監控和最佳化

## 另請參閱

* [思維鏈概念](../concepts/chain-of-thought.md)：理解推理模式
* [節點類型](../concepts/node-types.md)：圖節點基礎
* [性能監控](../how-to/metrics-and-observability.md)：指標和最佳化
* [API 參考](../api/)：完整的 API 文檔
