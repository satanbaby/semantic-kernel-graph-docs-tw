# 動態路由範例

此範例演示使用 Semantic Kernel Graph 的動態路由功能，展示如何根據內容分析、使用者偏好和即時條件實現智能路由。

## 目標

學習如何在圖形工作流中實現動態路由，以：
* 根據內容分析和語義相似性進行路由
* 使用多種路由策略實現智能決策
* 透過即時條件評估處理動態路由
* 在複雜工作流場景中擴展路由邏輯
* 使用快取和預測來優化路由效能

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* 已安裝 **Semantic Kernel Graph 套件**
* 基本了解 [圖形概念](../concepts/graph-concepts.md) 和 [路由概念](../concepts/routing.md)

## 主要組件

### 概念和技術

* **動態路由**：根據條件在運行時確定執行路徑
* **基於內容的路由**：根據內容分析和分類進行路由決策
* **語義相似性**：使用嵌入向量和相似性分數進行智能路由
* **多策略路由**：結合多種路由方法以獲得最佳決策
* **性能最佳化**：用於高效路由的快取和預測

### 核心類別

* `DynamicRoutingEngine`：動態路由決策的核心引擎
* `ConditionalGraphNode`：評估路由條件的節點
* `FunctionGraphNode`：用於不同內容類型的處理節點
* `GraphExecutor`：協調動態路由工作流

## 運行範例

### 開始使用

此範例使用 Semantic Kernel Graph 套件演示動態路由和自適應執行。以下代碼片段展示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本動態路由

此範例演示基於輸入內容分析的簡單動態路由。

```csharp
// 使用 mock 配置建立 kernel
var kernel = CreateKernel();

// 建立動態路由工作流
var dynamicRouter = new GraphExecutor("DynamicRouter", "Basic dynamic routing", logger);

// 內容分析器節點
var contentAnalyzer = new FunctionGraphNode(
    "content-analyzer",
    "Analyze input content and determine routing",
    async (context) =>
    {
        var inputContent = context.GetValue<string>("input_content");
        
        // 簡單內容分析
        var contentType = AnalyzeContentType(inputContent);
        var priority = CalculatePriority(inputContent);
        var complexity = AssessComplexity(inputContent);
        
        context.SetValue("content_type", contentType);
        context.SetValue("priority_level", priority);
        context.SetValue("complexity_level", complexity);
        context.SetValue("routing_decision", "pending");
        
        return $"Content analyzed: {contentType} (Priority: {priority}, Complexity: {complexity})";
    });

// 動態路由決策節點
var routingDecision = new ConditionalGraphNode(
    "routing-decision",
    "Make routing decision based on content analysis",
    logger)
{
    ConditionExpression = "content_type == 'technical' && priority_level >= 8",
    TrueNodeId = "expert-processor",
    FalseNodeId = "standard-processor"
};

// 用於高優先級技術內容的專家處理器
var expertProcessor = new FunctionGraphNode(
    "expert-processor",
    "Process high-priority technical content",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var priority = context.GetValue<int>("priority_level");
        
        // 專家級別處理
        var result = await ProcessWithExpertLogic(content, priority);
        context.SetValue("processing_result", result);
        context.SetValue("processing_level", "expert");
        context.SetValue("routing_decision", "expert_processed");
        
        return $"Expert processing completed: {result}";
    });

// 標準處理器用於其他內容
var standardProcessor = new FunctionGraphNode(
    "standard-processor",
    "Process standard content",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var contentType = context.GetValue<string>("content_type");
        
        // 標準處理
        var result = await ProcessWithStandardLogic(content, contentType);
        context.SetValue("processing_result", result);
        context.SetValue("processing_level", "standard");
        context.SetValue("routing_decision", "standard_processed");
        
        return $"Standard processing completed: {result}";
    });

// 將節點新增至路由器
dynamicRouter.AddNode(contentAnalyzer);
dynamicRouter.AddNode(routingDecision);
dynamicRouter.AddNode(expertProcessor);
dynamicRouter.AddNode(standardProcessor);

// 設定起始節點
dynamicRouter.SetStartNode(contentAnalyzer.NodeId);

// 使用不同的內容類型進行測試
var testContent = new[]
{
    "How do I implement a binary search tree in C#?",
    "What's the weather like today?",
    "Explain quantum computing principles and applications",
    "Can you help me with basic math?"
};

foreach (var content in testContent)
{
    var arguments = new KernelArguments
    {
        ["input_content"] = content
    };

    Console.WriteLine($"🧪 Testing content: {content}");
    var result = await dynamicRouter.ExecuteAsync(kernel, arguments);
    
    var routingDecision = result.GetValue<string>("routing_decision");
    var processingLevel = result.GetValue<string>("processing_level");
    var processingResult = result.GetValue<string>("processing_result");
    
    Console.WriteLine($"   Routing: {routingDecision}");
    Console.WriteLine($"   Level: {processingLevel}");
    Console.WriteLine($"   Result: {processingResult}");
    Console.WriteLine();
}
```

### 2. 進階語義路由

演示基於語義相似性和內容分類的路由。

```csharp
// 建立進階語義路由工作流
var semanticRouter = new GraphExecutor("SemanticRouter", "Semantic-based routing", logger);

// 語義內容分析器
var semanticAnalyzer = new FunctionGraphNode(
    "semantic-analyzer",
    "Perform semantic analysis of content",
    async (context) =>
    {
        var inputContent = context.GetValue<string>("input_content");
        
        // 語義分析
        var topics = ExtractTopics(inputContent);
        var sentiment = AnalyzeSentiment(inputContent);
        var domain = ClassifyDomain(inputContent);
        var intent = DetectIntent(inputContent);
        
        context.SetValue("semantic_topics", topics);
        context.SetValue("sentiment_score", sentiment);
        context.SetValue("domain_classification", domain);
        context.SetValue("user_intent", intent);
        context.SetValue("semantic_analysis_complete", true);
        
        return $"Semantic analysis: {domain} domain, {intent} intent";
    });

// 多維度路由決策
// 根據語義分析進行路由的決策節點
var semanticRoutingDecision = new ConditionalGraphNode(
    "semantic-router",
    "Route based on semantic analysis",
    logger)
{
    ConditionExpression = "domain_classification == 'technical' && sentiment_score > 0.7",
    TrueNodeId = "technical-expert",
    FalseNodeId = "domain-router"
};

// 特定領域路由
var domainRouter = new ConditionalGraphNode(
    "domain-router",
    "Route to domain-specific processors",
    logger)
{
    ConditionExpression = "domain_classification == 'business'",
    TrueNodeId = "business-processor",
    FalseNodeId = "general-processor"
};

// 技術專家處理器
var technicalExpert = new FunctionGraphNode(
    "technical-expert",
    "Process technical content with expert knowledge",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var topics = context.GetValue<string[]>("semantic_topics");
        var intent = context.GetValue<string>("user_intent");
        
        // 專家技術處理
        var result = await ProcessTechnicalContent(content, topics, intent);
        context.SetValue("processing_result", result);
        context.SetValue("processing_specialization", "technical_expert");
        
        return $"Technical expert processing: {result}";
    });

// 業務處理器
var businessProcessor = new FunctionGraphNode(
    "business-processor",
    "Process business-related content",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var topics = context.GetValue<string[]>("semantic_topics");
        
        // 業務處理
        var result = await ProcessBusinessContent(content, topics);
        context.SetValue("processing_result", result);
        context.SetValue("processing_specialization", "business");
        
        return $"Business processing: {result}";
    });

// 一般處理器
var generalProcessor = new FunctionGraphNode(
    "general-processor",
    "Process general content",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var domain = context.GetValue<string>("domain_classification");
        
        // 一般處理
        var result = await ProcessGeneralContent(content, domain);
        context.SetValue("processing_result", result);
        context.SetValue("processing_specialization", "general");
        
        return $"General processing: {result}";
    });

// 將節點新增至語義路由器
semanticRouter.AddNode(semanticAnalyzer);
// 新增語義路由決策節點
semanticRouter.AddNode(semanticRoutingDecision);
semanticRouter.AddNode(domainRouter);
semanticRouter.AddNode(technicalExpert);
semanticRouter.AddNode(businessProcessor);
semanticRouter.AddNode(generalProcessor);

// 設定起始節點
semanticRouter.SetStartNode(semanticAnalyzer.NodeId);

// 測試語義路由
var semanticTestContent = new[]
{
    "I need help with implementing a microservices architecture",
    "Can you analyze this quarterly financial report?",
    "What are the best practices for team collaboration?",
    "How do I optimize database performance for large datasets?"
};

foreach (var content in semanticTestContent)
{
    var arguments = new KernelArguments
    {
        ["input_content"] = content
    };

    Console.WriteLine($"🧠 Testing semantic routing: {content}");
    var result = await semanticRouter.ExecuteAsync(kernel, arguments);
    
    var specialization = result.GetValue<string>("processing_specialization");
    var processingResult = result.GetValue<string>("processing_result");
    
    Console.WriteLine($"   Specialization: {specialization}");
    Console.WriteLine($"   Result: {processingResult}");
    Console.WriteLine();
}
```

### 3. 實時自適應路由

展示如何實現基於實時條件和性能指標進行自適應的路由。

```csharp
// 建立自適應路由工作流
var adaptiveRouter = new GraphExecutor("AdaptiveRouter", "Real-time adaptive routing", logger);

// 性能監視器
var performanceMonitor = new FunctionGraphNode(
    "performance-monitor",
    "Monitor system performance and routing conditions",
    async (context) =>
    {
        // 取得實時指標
        var cpuUsage = GetCurrentCpuUsage();
        var memoryUsage = GetCurrentMemoryUsage();
        var queueLength = GetCurrentQueueLength();
        var responseTime = GetAverageResponseTime();
        
        context.SetValue("cpu_usage", cpuUsage);
        context.SetValue("memory_usage", memoryUsage);
        context.SetValue("queue_length", queueLength);
        context.SetValue("response_time", responseTime);
        context.SetValue("system_health", "monitored");
        
        return $"System health: CPU {cpuUsage}%, Memory {memoryUsage}%, Queue {queueLength}";
    });

// 自適應路由決策節點
var adaptiveRoutingDecision = new ConditionalGraphNode(
    "adaptive-router",
    "Make adaptive routing decision",
    logger)
{
    ConditionExpression = "cpu_usage < 70 && memory_usage < 80 && queue_length < 10",
    TrueNodeId = "high-performance-processor",
    FalseNodeId = "load-balanced-processor"
};

// 用於健康系統的高性能處理器
var highPerformanceProcessor = new FunctionGraphNode(
    "high-performance-processor",
    "Process with high-performance resources",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        
        // 使用高性能處理
        var result = await ProcessWithHighPerformance(content);
        context.SetValue("processing_result", result);
        context.SetValue("processing_mode", "high_performance");
        context.SetValue("resource_usage", "optimized");
        
        return $"High-performance processing: {result}";
    });

// 用於受壓力系統的負載平衡處理器
var loadBalancedProcessor = new FunctionGraphNode(
    "load-balanced-processor",
    "Process with load balancing",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var cpuUsage = context.GetValue<double>("cpu_usage");
        var queueLength = context.GetValue<int>("queue_length");
        
        // 自適應負載平衡
        var result = await ProcessWithLoadBalancing(content, cpuUsage, queueLength);
        context.SetValue("processing_result", result);
        context.SetValue("processing_mode", "load_balanced");
        context.SetValue("resource_usage", "conservative");
        
        return $"Load-balanced processing: {result}";
    });

// 將節點新增至自適應路由器
adaptiveRouter.AddNode(performanceMonitor);
// 新增自適應路由決策節點
adaptiveRouter.AddNode(adaptiveRoutingDecision);
adaptiveRouter.AddNode(highPerformanceProcessor);
adaptiveRouter.AddNode(loadBalancedProcessor);

// 設定起始節點
adaptiveRouter.SetStartNode(performanceMonitor.NodeId);

// 使用模擬條件測試自適應路由
var adaptiveTestScenarios = new[]
{
    new { Content = "Process this urgent request", CpuSimulation = 50.0, MemorySimulation = 60.0, QueueSimulation = 5 },
    new { Content = "Handle this batch job", CpuSimulation = 85.0, MemorySimulation = 90.0, QueueSimulation = 25 },
    new { Content = "Process user query", CpuSimulation = 65.0, MemorySimulation = 75.0, QueueSimulation = 8 }
};

foreach (var scenario in adaptiveTestScenarios)
{
    // 模擬系統條件
    SimulateSystemConditions(scenario.CpuSimulation, scenario.MemorySimulation, scenario.QueueSimulation);
    
    var arguments = new KernelArguments
    {
        ["input_content"] = scenario.Content
    };

    Console.WriteLine($"⚡ Testing adaptive routing: {scenario.Content}");
    Console.WriteLine($"   Simulated: CPU {scenario.CpuSimulation}%, Memory {scenario.MemorySimulation}%, Queue {scenario.QueueSimulation}");
    
    var result = await adaptiveRouter.ExecuteAsync(kernel, arguments);
    
    var processingMode = result.GetValue<string>("processing_mode");
    var resourceUsage = result.GetValue<string>("resource_usage");
    var processingResult = result.GetValue<string>("processing_result");
    
    Console.WriteLine($"   Mode: {processingMode}");
    Console.WriteLine($"   Resources: {resourceUsage}");
    Console.WriteLine($"   Result: {processingResult}");
    Console.WriteLine();
}
```

### 4. 多策略路由編排

演示編排多種路由策略以進行複雜決策。

```csharp
// 建立多策略路由工作流
var multiStrategyRouter = new GraphExecutor("MultiStrategyRouter", "Multi-strategy routing orchestration", logger);

// 策略協調者
var strategyCoordinator = new FunctionGraphNode(
    "strategy-coordinator",
    "Coordinate multiple routing strategies",
    async (context) =>
    {
        var inputContent = context.GetValue<string>("input_content");
        var userContext = context.GetValue<Dictionary<string, object>>("user_context");
        
        // 評估多個策略
        var contentStrategy = EvaluateContentStrategy(inputContent);
        var userStrategy = EvaluateUserStrategy(userContext);
        var performanceStrategy = EvaluatePerformanceStrategy();
        var businessStrategy = EvaluateBusinessStrategy(inputContent);
        
        context.SetValue("content_strategy", contentStrategy);
        context.SetValue("user_strategy", userStrategy);
        context.SetValue("performance_strategy", performanceStrategy);
        context.SetValue("business_strategy", businessStrategy);
        context.SetValue("strategies_evaluated", true);
        
        return $"Strategies evaluated: {contentStrategy}, {userStrategy}, {performanceStrategy}, {businessStrategy}";
    });

// 策略衝突解決器
var conflictResolver = new ConditionalGraphNode(
    "conflict-resolver",
    "Resolve conflicts between routing strategies",
    logger)
{
    ConditionExpression = "strategies_evaluated == true && (content_strategy != user_strategy || performance_strategy != business_strategy)",
    TrueNodeId = "conflict-resolution",
    FalseNodeId = "direct-routing"
};

// 衝突解決處理器
var conflictResolution = new FunctionGraphNode(
    "conflict-resolution",
    "Resolve routing strategy conflicts",
    async (context) =>
    {
        var contentStrategy = context.GetValue<string>("content_strategy");
        var userStrategy = context.GetValue<string>("user_strategy");
        var performanceStrategy = context.GetValue<string>("performance_strategy");
        var businessStrategy = context.GetValue<string>("business_strategy");
        
        // 應用衝突解決邏輯
        var resolvedStrategy = ResolveStrategyConflicts(
            contentStrategy, userStrategy, performanceStrategy, businessStrategy);
        
        context.SetValue("resolved_strategy", resolvedStrategy);
        context.SetValue("conflict_resolved", true);
        
        return $"Conflict resolved: {resolvedStrategy}";
    });

// 無衝突的直接路由
var directRouting = new FunctionGraphNode(
    "direct-routing",
    "Route directly based on primary strategy",
    async (context) =>
    {
        var contentStrategy = context.GetValue<string>("content_strategy");
        var userStrategy = context.GetValue<string>("user_strategy");
        
        // 使用主要策略
        var primaryStrategy = DeterminePrimaryStrategy(contentStrategy, userStrategy);
        context.SetValue("resolved_strategy", primaryStrategy);
        context.SetValue("conflict_resolved", false);
        
        return $"Direct routing: {primaryStrategy}";
    });

// 策略執行路由器
var strategyExecutor = new ConditionalGraphNode(
    "strategy-executor",
    "Execute the resolved routing strategy",
    logger)
{
    ConditionExpression = "resolved_strategy == 'content_based'",
    TrueNodeId = "content-based-executor",
    FalseNodeId = "hybrid-executor"
};

// 基於內容的執行器
var contentBasedExecutor = new FunctionGraphNode(
    "content-based-executor",
    "Execute content-based routing",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var strategy = context.GetValue<string>("resolved_strategy");
        
        var result = await ExecuteContentBasedRouting(content, strategy);
        context.SetValue("execution_result", result);
        context.SetValue("execution_strategy", strategy);
        
        return $"Content-based execution: {result}";
    });

// 混合執行器
var hybridExecutor = new FunctionGraphNode(
    "hybrid-executor",
    "Execute hybrid routing strategy",
    async (context) =>
    {
        var content = context.GetValue<string>("input_content");
        var strategy = context.GetValue<string>("resolved_strategy");
        var userContext = context.GetValue<Dictionary<string, object>>("user_context");
        
        var result = await ExecuteHybridRouting(content, strategy, userContext);
        context.SetValue("execution_result", result);
        context.SetValue("execution_strategy", strategy);
        
        return $"Hybrid execution: {result}";
    });

// 將節點新增至多策略路由器
multiStrategyRouter.AddNode(strategyCoordinator);
multiStrategyRouter.AddNode(conflictResolver);
multiStrategyRouter.AddNode(conflictResolution);
multiStrategyRouter.AddNode(directRouting);
multiStrategyRouter.AddNode(strategyExecutor);
multiStrategyRouter.AddNode(contentBasedExecutor);
multiStrategyRouter.AddNode(hybridExecutor);

// 設定起始節點
multiStrategyRouter.SetStartNode(strategyCoordinator.NodeId);

// 測試多策略路由
var multiStrategyTestScenarios = new[]
{
    new { 
        Content = "Analyze this technical document", 
        UserContext = new Dictionary<string, object> { ["expertise"] = "beginner", ["preference"] = "detailed" }
    },
    new { 
        Content = "Quick summary needed", 
        UserContext = new Dictionary<string, object> { ["expertise"] = "expert", ["preference"] = "concise" }
    }
};

foreach (var scenario in multiStrategyTestScenarios)
{
    var arguments = new KernelArguments
    {
        ["input_content"] = scenario.Content,
        ["user_context"] = scenario.UserContext
    };

    Console.WriteLine($"🎯 Testing multi-strategy routing: {scenario.Content}");
    Console.WriteLine($"   User Context: {string.Join(", ", scenario.UserContext.Select(kv => $"{kv.Key}={kv.Value}"))}");
    
    var result = await multiStrategyRouter.ExecuteAsync(kernel, arguments);
    
    var resolvedStrategy = result.GetValue<string>("resolved_strategy");
    var conflictResolved = result.GetValue<bool>("conflict_resolved");
    var executionStrategy = result.GetValue<string>("execution_strategy");
    var executionResult = result.GetValue<string>("execution_result");
    
    Console.WriteLine($"   Resolved Strategy: {resolvedStrategy}");
    Console.WriteLine($"   Conflict Resolved: {conflictResolved}");
    Console.WriteLine($"   Execution Strategy: {executionStrategy}");
    Console.WriteLine($"   Result: {executionResult}");
    Console.WriteLine();
}
```

## 預期輸出

### 基本動態路由範例

```
🧪 Testing content: How do I implement a binary search tree in C#?
   Routing: expert_processed
   Level: expert
   Result: Expert technical implementation guide provided

🧪 Testing content: What's the weather like today?
   Routing: standard_processed
   Level: standard
   Result: Weather information retrieved and formatted
```

### 進階語義路由範例

```
🧠 Testing semantic routing: I need help with implementing a microservices architecture
   Specialization: technical_expert
   Result: Comprehensive microservices implementation guide

🧠 Testing semantic routing: Can you analyze this quarterly financial report?
   Specialization: business
   Result: Financial analysis with key metrics and insights
```

### 實時自適應路由範例

```
⚡ Testing adaptive routing: Process this urgent request
   Simulated: CPU 50%, Memory 60%, Queue 5
   Mode: high_performance
   Resources: optimized
   Result: High-performance processing completed

⚡ Testing adaptive routing: Handle this batch job
   Simulated: CPU 85%, Memory 90%, Queue 25
   Mode: load_balanced
   Resources: conservative
   Result: Load-balanced processing completed
```

### 多策略路由範例

```
🎯 Testing multi-strategy routing: Analyze this technical document
   User Context: expertise=beginner, preference=detailed
   Resolved Strategy: content_based
   Conflict Resolved: False
   Execution Strategy: content_based
   Result: Detailed technical analysis with explanations

🎯 Testing multi-strategy routing: Quick summary needed
   User Context: expertise=expert, preference=concise
   Resolved Strategy: hybrid
   Conflict Resolved: True
   Execution Strategy: hybrid
   Result: Concise summary with expert-level insights
```

## 配置選項

### 動態路由配置

```csharp
var routingOptions = new DynamicRoutingOptions
{
    EnableSemanticRouting = true,                    // 啟用語義相似性路由
    EnablePerformanceRouting = true,                 // 啟用性能為基礎的路由
    EnableUserContextRouting = true,                 // 啟用使用者上下文路由
    MaxRoutingStrategies = 5,                       // 要評估的最大策略數
    RoutingTimeout = TimeSpan.FromSeconds(10),       // 路由決策逾時
    EnableStrategyCaching = true,                    // 快取路由策略決策
    EnableConflictResolution = true,                 // 啟用自動衝突解決
    DefaultRoutingStrategy = "content_based",        // 衝突發生時的預設策略
    PerformanceThresholds = new PerformanceThresholds
    {
        CpuUsageThreshold = 80.0,                   // CPU 使用率路由閾值
        MemoryUsageThreshold = 85.0,                // 記憶體使用率路由閾值
        QueueLengthThreshold = 15,                   // 佇列長度路由閾值
        ResponseTimeThreshold = TimeSpan.FromSeconds(2) // 響應時間閾值
    }
};
```

### 語義路由配置

```csharp
var semanticOptions = new SemanticRoutingOptions
{
    EnableTopicExtraction = true,                    // 提取主題以進行路由
    EnableSentimentAnalysis = true,                  // 分析情緒以進行路由
    EnableDomainClassification = true,               // 分類內容領域
    EnableIntentDetection = true,                    // 偵測使用者意圖
    SimilarityThreshold = 0.7,                      // 最低相似性分數
    MaxTopics = 10,                                 // 要提取的最大主題數
    EnableEmbeddingCaching = true,                   // 快取嵌入向量以提升性能
    DomainMappings = new Dictionary<string, string>  // 領域至處理器的對映
    {
        ["technical"] = "technical_processor",
        ["business"] = "business_processor",
        ["general"] = "general_processor"
    }
};
```

## 故障排查

### 常見問題

#### 路由決策不起作用
```bash
# 問題：路由決策未遵循預期的邏輯
# 解決方案：檢查條件表達式和節點 ID
ConditionExpression = "simple_condition == true";
TrueNodeId = "correct-node-id";
FalseNodeId = "correct-node-id";
```

#### 性能問題
```bash
# 問題：動態路由速度緩慢
# 解決方案：啟用快取並最佳化策略評估
EnableStrategyCaching = true;
EnableEmbeddingCaching = true;
MaxRoutingStrategies = 3;
```

#### 策略衝突
```bash
# 問題：多個策略衝突
# 解決方案：實現衝突解決並設定優先順序
EnableConflictResolution = true;
DefaultRoutingStrategy = "fallback_strategy";
```

### 偵錯模式

為故障排查啟用詳細日誌：

```csharp
// 啟用偵錯日誌
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<DynamicRoutingExample>();

// 使用偵錯日誌配置動態路由
var debugRouter = new GraphExecutor("DebugRouter", "Debug dynamic routing", logger);
debugRouter.EnableDebugMode = true;
debugRouter.LogRoutingDecisions = true;
debugRouter.LogStrategyEvaluation = true;
```

## 進階模式

### 自訂路由策略

```csharp
// 實現自訂路由策略
public class CustomRoutingStrategy : IRoutingStrategy
{
    public async Task<RoutingDecision> EvaluateAsync(RoutingContext context)
    {
        var content = context.Content;
        var userContext = context.UserContext;
        var systemMetrics = context.SystemMetrics;
        
        // 自訂評估邏輯
        var score = await CalculateCustomScore(content, userContext, systemMetrics);
        
        return new RoutingDecision
        {
            Strategy = "custom",
            Confidence = score,
            TargetNode = score > 0.8 ? "high_priority_processor" : "standard_processor",
            Metadata = new Dictionary<string, object>
            {
                ["custom_score"] = score,
                ["evaluation_timestamp"] = DateTime.UtcNow
            }
        };
    }
}
```

### 機器學習路由

```csharp
// 實現基於機器學習的路由
public class MLRoutingEngine : IRoutingEngine
{
    private readonly IMLModel _routingModel;
    
    public async Task<RoutingDecision> PredictRouteAsync(RoutingContext context)
    {
        // 為機器學習模型準備特徵
        var features = await ExtractFeatures(context);
        
        // 取得機器學習預測
        var prediction = await _routingModel.PredictAsync(features);
        
        return new RoutingDecision
        {
            Strategy = "ml_prediction",
            Confidence = prediction.Confidence,
            TargetNode = prediction.TargetNode,
            Metadata = new Dictionary<string, object>
            {
                ["ml_model_version"] = prediction.ModelVersion,
                ["prediction_features"] = features
            }
        };
    }
}
```

### A/B 測試路由

```csharp
// 實現路由策略的 A/B 測試
public class ABTestingRouter : IRouter
{
    private readonly IRandom _random;
    private readonly Dictionary<string, double> _strategyWeights;
    
    public async Task<string> RouteAsync(RoutingContext context)
    {
        // 確定 A/B 測試群組
        var testGroup = DetermineTestGroup(context.UserId);
        
        // 應用 A/B 測試權重
        var strategy = await SelectStrategyWithABTesting(context, testGroup);
        
        return strategy;
    }
    
    private async Task<string> SelectStrategyWithABTesting(RoutingContext context, string testGroup)
    {
        var random = _random.NextDouble();
        var cumulativeWeight = 0.0;
        
        foreach (var strategy in _strategyWeights)
        {
            cumulativeWeight += strategy.Value;
            if (random <= cumulativeWeight)
            {
                return strategy.Key;
            }
        }
        
        return _strategyWeights.Keys.First();
    }
}
```

## 相關範例

* [條件節點](./conditional-nodes.md)：基本條件路由
* [進階模式](./advanced-patterns.md)：複雜路由模式
* [多代理](./multi-agent.md)：協調路由決策
* [性能最佳化](./performance-optimization.md)：路由性能調整

## 另請參閱

* [動態路由概念](../concepts/dynamic-routing.md)：了解動態路由
* [路由策略](../patterns/routing-strategies.md)：路由模式實現
* [性能最佳化](../how-to/performance-optimization.md)：最佳化路由性能
* [API 參考](../api/)：完整 API 文件
