# 思考鏈範例

本範例演示使用 Semantic Kernel Graph 的思考鏈推理模式。它展示了不同的推理類型、驗證、回溯和針對分步問題解決的範本自訂。

## 目標

學習如何在基於圖形的工作流程中實現思考鏈推理，以：
* 將複雜問題分解為邏輯步驟
* 在每個步驟驗證推理品質
* 當推理失敗時啟用回溯
* 為不同用案例自訂推理範本
* 監控並優化推理效能

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API 金鑰**已在 `appsettings.json` 中設定
* **Semantic Kernel Graph 套件**已安裝
* 基本了解 [Graph Concepts](../concepts/graph-concepts.md) 和 [Node Types](../concepts/node-types.md)

## 主要元件

### 概念和技術

* **Chain of Thought**：一種推理模式，其中 AI 將複雜問題分解為順序步驟，展示其思考過程
* **推理驗證**：使用信心評分和驗證規則對每個推理步驟進行品質評估
* **回溯**：能夠以不同方法重試失敗的推理步驟
* **範本引擎**：針對不同問題域可自訂的提示和推理模式

### 核心類別

* `ChainOfThoughtGraphNode`：用於實現 CoT 推理的主要 Node
* `ChainOfThoughtTemplateEngine`：管理推理範本和驗證
* `ChainOfThoughtType`：推理策略的列舉（ProblemSolving、Analysis、DecisionMaking）
* `ChainOfThoughtValidator`：驗證推理品質和信心

## 執行範例

### 開始使用

本範例使用 Semantic Kernel Graph 套件演示思考鏈推理模式。下面的程式碼片段向您展示如何在自己的應用程式中實現此模式。

### 實作概述

下面的範例展示如何在自己的應用程式中實現思考鏈推理：

## 分步實作

### 1. 使用思考鏈進行問題解決

本範例演示具有分步推理的基本問題解決。

```csharp
// 建立為問題解決配置的思考鏈 Node。
// 該 Node 支援回溯、最小信心閾值和可選的快取。
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

// 建立圖形執行器，註冊 Node 並將其設定為起始 Node。
var executor = new GraphExecutor("ChainOfThought-ProblemSolving", "Chain-of-Thought problem solving example", logger);
executor.AddNode(cotNode);
executor.SetStartNode(cotNode.NodeId);

// 為思考鏈執行準備輸入引數。
var arguments = new KernelArguments
{
    ["problem_statement"] = "A company needs to reduce operational costs by 20% while maintaining employee satisfaction. They have 1000 employees and current annual costs of $50M.",
    ["context"] = "Competitive tech market with high talent retention challenges.",
    ["constraints"] = "Cannot reduce headcount by more than 5%; must maintain benefit levels; implement within 6 months.",
    ["expected_outcome"] = "A concrete cost reduction plan with prioritized actions.",
    ["reasoning_depth"] = 4
};

// 執行圖形並取得最終推理結果。
var result = await executor.ExecuteAsync(kernel, arguments, CancellationToken.None);
```

### 2. 使用自訂範本進行分析

演示自訂推理範本和驗證規則。

```csharp
// 定義商務分析的自訂分析範本和驗證規則。
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

// 建立自訂驗證規則（本文件稍後顯示範例）
var customRules = new List<IChainOfThoughtValidationRule>
{
    new StakeholderAnalysisRule(),
    new CausalAnalysisRule()
};

// 使用自訂範本和規則建立思考鏈 Node。
var analysisNode = ChainOfThoughtGraphNode.CreateWithCustomization(
    ChainOfThoughtType.Analysis,
    customTemplates,
    customRules,
    maxSteps: 4,
    templateEngine: templateEngine,
    logger: logger);
```

### 3. 具有回溯功能的決策制定

展示當推理失敗時如何實現回溯。

```csharp
// 配置啟用回溯的決策制定 Node。
var decisionNode = new ChainOfThoughtGraphNode(
    ChainOfThoughtType.DecisionMaking,
    maxSteps: 4,
    templateEngine: templateEngine,
    logger: logger)
{
    BacktrackingEnabled = true,
    // 注意：MaxBacktrackAttempts 和 BacktrackStrategy 僅供說明用途
    // 可能在驗證程式/回溯層中實作。
    MinimumStepConfidence = 0.8
};

// 當驗證信心低於配置的閾值時，Node 將嘗試回溯
// （如果啟用了回溯支援）。
```

### 4. 效能和快取示範

使用快取和指標最佳化推理效能。

```csharp
// 建立啟用快取和可選效能監控的 Node。
var performanceNode = new ChainOfThoughtGraphNode(
    ChainOfThoughtType.ProblemSolving,
    maxSteps: 5,
    templateEngine: templateEngine,
    logger: logger)
{
    CachingEnabled = true
    // CacheExpiration 和效能閾值是實作詳細資料
    // 在某些 Node 實作上可用。在支援時使用它們。
};

// 列印基本 Node 統計資料以進行快速驗證。
Console.WriteLine($"Node Statistics: {cotNode.Statistics.ExecutionCount} executions, " +
                  $"{cotNode.Statistics.AverageQualityScore:P1} avg quality, " +
                  $"{cotNode.Statistics.SuccessRate:P1} success rate");
```

## 預期輸出

### 問題解決範例

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

### 分析範例

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

## 設定選項

### 思考鏈設定

```csharp
// 代表思考鏈設定的範例設定物件。
// 並非所有實作都公開單一選項類別；許多 Node
// 屬性直接在 Node 實例本身上設定。
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

### 範本設定

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

#### 信心評分較低
```bash
# 問題：步驟一致性地未通過信心驗證
# 解決方案：調整信心閾值或改進提示品質
MinimumStepConfidence = 0.5; // Lower threshold for development
```

#### 過度回溯
```bash
# 問題：太多回溯嘗試
# 解決方案：限制回溯嘗試或改進初始推理
MaxBacktrackAttempts = 2; // Reduce retry attempts
```

#### 效能問題
```bash
# 問題：推理執行速度慢
# 解決方案：啟用快取並設定效能閾值
CachingEnabled = true;
PerformanceThreshold = TimeSpan.FromSeconds(60);
```

### 偵錯模式

啟用詳細記錄以進行疑難排解：

```csharp
// 為偵錯建立控制台記錄器並設定 Node 以發出
// 詳細推理記錄（在 Node 實作支援的情況下）。
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
    // 這些旗標是範例；實際屬性名稱可能因版本而異。
    // 在存在的 Node 實作內啟用詳細記錄。
};
```

## 進階模式

### 多步驟驗證

```csharp
// 實作自訂驗證邏輯
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

### 動態範本選擇

```csharp
// 根據問題類型選擇範本
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

## 相關範例

* [ReAct Agent](./react-agent.md)：推理和行動迴圈
* [ReAct Problem Solving](./react-problem-solving.md)：複雜問題分解
* [Conditional Nodes](./conditional-nodes.md)：根據推理結果進行動態路由
* [Graph Metrics](./graph-metrics.md)：效能監控和最佳化

## 另請參閱

* [Chain of Thought Concepts](../concepts/chain-of-thought.md)：了解推理模式
* [Node Types](../concepts/node-types.md)：Graph Node 基本知識
* [Performance Monitoring](../how-to/metrics-and-observability.md)：指標和最佳化
* [API Reference](../api/)：完整 API 文件
