# 記憶 Agent 範例

此範例展示如何在 Semantic Kernel Graph 工作流程中實現啟用記憶功能的 agents。它說明如何建立能記住、從先前的互動和經驗中學習，以及在此基礎上建立的 agents。

## 目標

學習如何在圖形式工作流程中實現啟用記憶功能的 agents，以便：
* 建立具有持久記憶和學習能力的 agents
* 實現記憶儲存、檢索和管理
* 使 agents 能夠從過去的互動和經驗中學習
* 建立具有上下文感知和自適應行為的 agents
* 實現基於記憶的決策制定和推理

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 基本了解 [Graph 概念](../concepts/graph-concepts.md) 和 [記憶模式](../concepts/memory.md)

## 關鍵元件

### 概念和技術

* **記憶存儲**：Agent 經驗和知識的持久儲存
* **記憶檢索**：相關記憶的智能檢索
* **學習整合**：將新體驗整合到記憶中
* **上下文感知**：使用記憶進行上下文感知決策制定
* **記憶管理**：有效的記憶組織和清理

### 核心類別

* `MemoryAgent`：基本啟用記憶功能的 agent 實現
* `MemoryStore`：記憶儲存和檢索系統
* `MemoryRetriever`：智能記憶搜尋和檢索
* `LearningIntegrator`：從新經驗中學習
* `MemoryManager`：記憶生命週期和最佳化

## 執行範例

### 開始使用

此範例展示使用 Semantic Kernel Graph 套件的啟用記憶功能的 agents。下面的程式碼片段展示如何在您自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本記憶 Agent 實現

此範例展示基本記憶 agent 的建立和操作。

```csharp
// 最小可執行的記憶 agent 範例（文件反映 examples/MemoryAgentExample.cs 中的可執行檔案）
// 為演示建立本地 kernel
var kernel = Kernel.CreateBuilder().Build();

// 範例使用的簡單記憶內儲存（完整實現見 examples/MemoryAgentExample.cs）
var memoryStore = new InMemoryMemoryStore();

// 建立由 kernel 支援的 Graph executor
var workflow = new GraphExecutor(kernel);

// 建立一個執行檢索、處理和儲存的 kernel 函式
var memoryFn = kernel.CreateFunctionFromMethod(async (KernelArguments args) =>
{
    var userInput = args.GetValueOrDefault("user_input")?.ToString() ?? "";
    var sessionId = args.GetValueOrDefault("session_id")?.ToString() ?? Guid.NewGuid().ToString();

    // 檢索相關記憶（token 重疊啟發式）
    var relevant = await memoryStore.RetrieveAsync(userInput, sessionId);

    // 構建簡單回應
    var response = $"Echo: {userInput} (found {relevant.Count} memories)";

    // 儲存新記憶條目
    var entry = new MemoryEntry
    {
        Id = Guid.NewGuid().ToString(),
        Content = userInput,
        Response = response,
        SessionId = sessionId,
        Timestamp = DateTime.UtcNow,
        Tags = new List<string> { "doc-example" },
        Importance = 0.5
    };

    await memoryStore.StoreAsync(entry);

    // 在 Graph 狀態中保持結果
    var state = args.GetOrCreateGraphState();
    state.SetValue("agent_response", response);
    state.SetValue("memories_retrieved", relevant.Count);
    state.SetValue("new_memory_stored", true);
    state.SetValue("memory_entry_id", entry.Id);

    // 返回緊湊的負載（回應 + 診斷）
    const char DELIM = '\u0001';
    return $"{response}{DELIM}{relevant.Count}{DELIM}true";
}, functionName: "doc_memory_agent_fn", description: "Documentation memory agent function");

var memoryAgent = new FunctionGraphNode(memoryFn, "memory-agent");
workflow.AddNode(memoryAgent);
workflow.SetStartNode(memoryAgent.NodeId);

Console.WriteLine("[doc] 🧠 Testing memory agent...\n");

var testInputs = new[] { "What is machine learning?", "Tell me about neural networks", "How does deep learning work?" };
foreach (var input in testInputs)
{
    var args = new KernelArguments { ["user_input"] = input, ["session_id"] = "doc-session-001" };
    Console.WriteLine($"[doc] Input: {input}");

    var result = await workflow.ExecuteAsync(kernel, args);
    var raw = result.GetValue<string>() ?? string.Empty;
    const char DELIM = '\u0001';
    var parts = raw.Split(DELIM);
    var agentResponse = parts.Length > 0 ? parts[0] : string.Empty;
    var memoriesRetrieved = parts.Length > 1 && int.TryParse(parts[1], out var m) ? m : 0;
    var newMemoryStored = parts.Length > 2 && bool.TryParse(parts[2], out var b) ? b : false;

    Console.WriteLine($"[doc] Response: {agentResponse}");
    Console.WriteLine($"[doc] Memories Retrieved: {memoriesRetrieved}");
    Console.WriteLine($"[doc] New Memory Stored: {newMemoryStored}\n");
}
```

### 2. 進階記憶檢索

展示具有語義搜尋和上下文感知的進階記憶檢索。

```csharp
// 進階檢索 — 此片段展示編排模式。將這些預留位置函式替換為
// 實際語義搜尋 / 排名實現，或在與向量儲存或 LLM 整合時使用。
var advancedMemoryWorkflow = new GraphExecutor("AdvancedMemoryWorkflow", logger: ConsoleLogger.Instance);

// 語義記憶搜尋器（預留位置）
var semanticMemorySearcher = new FunctionGraphNode(
    "semantic-memory-searcher",
    "Perform semantic search in memory",
    async (context) =>
    {
        var query = context.GetValue<string>("query") ?? string.Empty;
        var contextInfo = context.GetValue<Dictionary<string, object>>("context_info") ?? new Dictionary<string, object>();
        var searchDepth = context.GetValue<int>("search_depth", 3);

        // 注意：將 PerformSemanticSearch 替換為您的向量儲存或嵌入式搜尋。
        var semanticResults = await PerformSemanticSearch(query, contextInfo, searchDepth);

        // 排名和叢集化（預留位置幫助器）
        var rankedResults = await RankMemoryResults(semanticResults, contextInfo);
        var clusteredResults = await ClusterRelatedMemories(rankedResults);

        context.SetValue("semantic_results", semanticResults);
        context.SetValue("ranked_results", rankedResults);
        context.SetValue("clustered_results", clusteredResults);
        context.SetValue("search_completed", true);

        return $"Semantic search completed: {semanticResults.Count} results found";
    });

var contextAwareAnalyzer = new FunctionGraphNode(
    "context-aware-analyzer",
    "Analyze memories with context awareness",
    async (context) =>
    {
        var rankedResults = context.GetValue<List<RankedMemory>>("ranked_results") ?? new List<RankedMemory>();
        var contextInfo = context.GetValue<Dictionary<string, object>>("context_info") ?? new Dictionary<string, object>();

        var contextAnalysis = await AnalyzeContextRelevance(rankedResults, contextInfo);

        var contextualInsights = new Dictionary<string, object>
        {
            ["context_relevance_scores"] = contextAnalysis.RelevanceScores,
            ["context_patterns"] = contextAnalysis.Patterns,
            ["contextual_recommendations"] = contextAnalysis.Recommendations,
            ["context_confidence"] = contextAnalysis.Confidence
        };

        context.SetValue("context_analysis", contextAnalysis);
        context.SetValue("contextual_insights", contextualInsights);

        return $"Context analysis completed: Confidence {contextAnalysis.Confidence:F2}";
    });

var memorySynthesizer = new FunctionGraphNode(
    "memory-synthesizer",
    "Synthesize memories into coherent response",
    async (context) =>
    {
        var query = context.GetValue<string>("query") ?? string.Empty;
        var clusteredResults = context.GetValue<List<MemoryCluster>>("clustered_results") ?? new List<MemoryCluster>();
        var contextualInsights = context.GetValue<Dictionary<string, object>>("contextual_insights") ?? new Dictionary<string, object>();

        var synthesizedResponse = await SynthesizeMemories(query, clusteredResults, contextualInsights);

        var memorySummary = new Dictionary<string, object>
        {
            ["synthesized_response"] = synthesizedResponse.Response,
            ["memory_sources"] = synthesizedResponse.MemorySources,
            ["confidence_score"] = synthesizedResponse.Confidence,
            ["synthesis_method"] = synthesizedResponse.Method,
            ["synthesis_timestamp"] = DateTime.UtcNow
        };

        context.SetValue("synthesized_response", synthesizedResponse);
        context.SetValue("memory_summary", memorySummary);

        return $"Memory synthesis completed: {synthesizedResponse.MemorySources.Count} sources used";
    });

advancedMemoryWorkflow.AddNode(semanticMemorySearcher);
advancedMemoryWorkflow.AddNode(contextAwareAnalyzer);
advancedMemoryWorkflow.AddNode(memorySynthesizer);
advancedMemoryWorkflow.SetStartNode(semanticMemorySearcher.NodeId);

Console.WriteLine("🔍 Testing advanced memory retrieval...");

var advancedQueries = new[] { "Explain the relationship between AI and machine learning", "What are the latest developments in neural networks?", "How do different learning algorithms compare?" };
foreach (var q in advancedQueries)
{
    var arguments = new KernelArguments
    {
        ["query"] = q,
        ["context_info"] = new Dictionary<string, object> { ["user_level"] = "intermediate", ["domain"] = "artificial_intelligence" },
        ["search_depth"] = 5
    };

    Console.WriteLine($"   Query: {q}");
    var result = await advancedMemoryWorkflow.ExecuteAsync(kernel, arguments);

    var searchCompleted = result.GetValue<bool>("search_completed");
    var memorySummary = result.GetValue<Dictionary<string, object>>("memory_summary");
    if (searchCompleted && memorySummary != null)
    {
        Console.WriteLine($"   Search Completed: {searchCompleted}");
        Console.WriteLine($"   Confidence Score: {memorySummary["confidence_score"]}");
        Console.WriteLine($"   Memory Sources: {memorySummary["memory_sources"]}");
        Console.WriteLine($"   Synthesis Method: {memorySummary["synthesis_method"]}");
    }
    Console.WriteLine();
}
```

### 3. 學習和自適應

展示如何為記憶 agents 實現學習和自適應機制。

```csharp
// 建立學習和自適應工作流程
var learningWorkflow = new GraphExecutor("LearningWorkflow", "Learning and adaptation", logger);

// 配置學習選項
var learningOptions = new LearningOptions
{
    EnableExperienceLearning = true,
    EnablePatternRecognition = true,
    EnableAdaptiveBehavior = true,
    EnableKnowledgeExpansion = true,
    LearningRate = 0.1,
    AdaptationThreshold = 0.7,
    PatternRecognitionThreshold = 0.6
};

learningWorkflow.ConfigureLearning(learningOptions);

// 經驗學習者節點
var experienceLearner = new FunctionGraphNode(
    "experience-learner",
    "Learn from new experiences",
    async (context) =>
    {
        var userInput = context.GetValue<string>("user_input");
        var agentResponse = context.GetValue<string>("agent_response");
        var userFeedback = context.GetValue<string>("user_feedback", "positive");
        var interactionQuality = context.GetValue<double>("interaction_quality", 0.8);
        
        // 從經驗中學習
        var learningOutcome = await LearnFromExperience(userInput, agentResponse, userFeedback, interactionQuality);
        
        // 更新學習指標
        var updatedMetrics = new Dictionary<string, object>
        {
            ["learning_outcome"] = learningOutcome,
            ["knowledge_gained"] = learningOutcome.KnowledgeGained,
            ["skill_improvement"] = learningOutcome.SkillImprovement,
            ["adaptation_level"] = learningOutcome.AdaptationLevel,
            ["learning_timestamp"] = DateTime.UtcNow
        };
        
        context.SetValue("learning_outcome", learningOutcome);
        context.SetValue("updated_metrics", updatedMetrics);
        
        return $"Learning completed: Knowledge gained {learningOutcome.KnowledgeGained:F2}";
    });

// 模式識別器節點
var patternRecognizer = new FunctionGraphNode(
    "pattern-recognizer",
    "Recognize patterns in interactions",
    async (context) =>
    {
        var sessionId = context.GetValue<string>("session_id");
        var interactionHistory = context.GetValue<List<Interaction>>("interaction_history");
        var learningOutcome = context.GetValue<LearningOutcome>("learning_outcome");
        
        // 識別模式
        var patterns = await RecognizePatterns(sessionId, interactionHistory, learningOutcome);
        
        // 生成模式洞察
        var patternInsights = new Dictionary<string, object>
        {
            ["recognized_patterns"] = patterns.IdentifiedPatterns,
            ["pattern_confidence"] = patterns.Confidence,
            ["pattern_recommendations"] = patterns.Recommendations,
            ["pattern_learning_value"] = patterns.LearningValue
        };
        
        context.SetValue("recognized_patterns", patterns);
        context.SetValue("pattern_insights", patternInsights);
        
        return $"Pattern recognition completed: {patterns.IdentifiedPatterns.Count} patterns found";
    });

// 自適應行為生成器
var adaptiveBehaviorGenerator = new FunctionGraphNode(
    "adaptive-behavior-generator",
    "Generate adaptive behaviors based on learning",
    async (context) =>
    {
        var learningOutcome = context.GetValue<LearningOutcome>("learning_outcome");
        var recognizedPatterns = context.GetValue<PatternRecognition>("recognized_patterns");
        var currentContext = context.GetValue<Dictionary<string, object>>("current_context");
        
        // 生成自適應行為
        var adaptiveBehaviors = await GenerateAdaptiveBehaviors(learningOutcome, recognizedPatterns, currentContext);
        
        // 更新行為狀態
        var behaviorState = new Dictionary<string, object>
        {
            ["adaptive_behaviors"] = adaptiveBehaviors.Behaviors,
            ["behavior_confidence"] = adaptiveBehaviors.Confidence,
            ["adaptation_reason"] = adaptiveBehaviors.AdaptationReason,
            ["behavior_timestamp"] = DateTime.UtcNow
        };
        
        context.SetValue("adaptive_behaviors", adaptiveBehaviors);
        context.SetValue("behavior_state", behaviorState);
        
        return $"Adaptive behaviors generated: {adaptiveBehaviors.Behaviors.Count} behaviors";
    });

// 將節點新增到學習工作流程
learningWorkflow.AddNode(experienceLearner);
learningWorkflow.AddNode(patternRecognizer);
learningWorkflow.AddNode(adaptiveBehaviorGenerator);

// 設定起始節點
learningWorkflow.SetStartNode(experienceLearner.NodeId);

// 測試學習和自適應
Console.WriteLine("📚 Testing learning and adaptation...");

var learningScenarios = new[]
{
    new { Input = "Explain quantum computing", Feedback = "positive", Quality = 0.9 },
    new { Input = "What is blockchain?", Feedback = "neutral", Quality = 0.7 },
    new { Input = "How does encryption work?", Feedback = "positive", Quality = 0.8 }
};

foreach (var scenario in learningScenarios)
{
    var arguments = new KernelArguments
    {
        ["user_input"] = scenario.Input,
        ["agent_response"] = $"Response to: {scenario.Input}",
        ["user_feedback"] = scenario.Feedback,
        ["interaction_quality"] = scenario.Quality,
        ["session_id"] = "learning-session-001",
        ["interaction_history"] = new List<Interaction>(),
        ["current_context"] = new Dictionary<string, object>()
    };

    Console.WriteLine($"   Input: {scenario.Input}");
    Console.WriteLine($"   Feedback: {scenario.Feedback}");
    Console.WriteLine($"   Quality: {scenario.Quality}");
    
    var result = await learningWorkflow.ExecuteAsync(kernel, arguments);
    
    var learningOutcome = result.GetValue<LearningOutcome>("learning_outcome");
    var patternInsights = result.GetValue<Dictionary<string, object>>("pattern_insights");
    var behaviorState = result.GetValue<Dictionary<string, object>>("behavior_state");
    
    if (learningOutcome != null)
    {
        Console.WriteLine($"   Knowledge Gained: {learningOutcome.KnowledgeGained:F2}");
        Console.WriteLine($"   Skill Improvement: {learningOutcome.SkillImprovement:F2}");
    }
    
    Console.WriteLine();
}
```

### 4. 記憶管理和最佳化

展示記憶管理、清理和最佳化策略。

```csharp
// 建立記憶管理工作流程
var memoryManagementWorkflow = new GraphExecutor("MemoryManagementWorkflow", "Memory management and optimization", logger);

// 配置記憶管理選項
var memoryManagementOptions = new MemoryManagementOptions
{
    EnableMemoryCleanup = true,
    EnableMemoryOptimization = true,
    EnableMemoryCompression = true,
    EnableMemoryArchiving = true,
    CleanupThreshold = 0.8,
    CompressionThreshold = 0.6,
    ArchiveThreshold = 0.3
};

memoryManagementWorkflow.ConfigureMemoryManagement(memoryManagementOptions);

// 記憶分析器節點
var memoryAnalyzer = new FunctionGraphNode(
    "memory-analyzer",
    "Analyze memory usage and performance",
    async (context) =>
    {
        var sessionId = context.GetValue<string>("session_id");
        var analysisDepth = context.GetValue<int>("analysis_depth", 5);
        
        // 分析記憶使用狀況
        var memoryAnalysis = await AnalyzeMemoryUsage(sessionId, analysisDepth);
        
        // 生成最佳化建議
        var optimizationRecommendations = await GenerateOptimizationRecommendations(memoryAnalysis);
        
        // 更新分析狀態
        context.SetValue("memory_analysis", memoryAnalysis);
        context.SetValue("optimization_recommendations", optimizationRecommendations);
        context.SetValue("analysis_completed", true);
        
        return $"Memory analysis completed: {optimizationRecommendations.Count} recommendations";
    });

// 記憶最佳化器節點
var memoryOptimizer = new FunctionGraphNode(
    "memory-optimizer",
    "Optimize memory storage and retrieval",
    async (context) =>
    {
        var memoryAnalysis = context.GetValue<MemoryUsageAnalysis>("memory_analysis");
        var optimizationRecommendations = context.GetValue<List<OptimizationRecommendation>>("optimization_recommendations");
        
        // 應用最佳化
        var optimizationResults = await ApplyMemoryOptimizations(memoryAnalysis, optimizationRecommendations);
        
        // 更新最佳化狀態
        context.SetValue("optimization_results", optimizationResults);
        context.SetValue("optimization_completed", true);
        
        return $"Memory optimization completed: {optimizationResults.AppliedOptimizations.Count} optimizations applied";
    });

// 記憶清理節點
var memoryCleanup = new FunctionGraphNode(
    "memory-cleanup",
    "Clean up and compress memory",
    async (context) =>
    {
        var memoryAnalysis = context.GetValue<MemoryUsageAnalysis>("memory_analysis");
        var optimizationResults = context.GetValue<OptimizationResults>("optimization_results");
        
        // 執行記憶清理
        var cleanupResults = await PerformMemoryCleanup(memoryAnalysis, optimizationResults);
        
        // 更新清理狀態
        context.SetValue("cleanup_results", cleanupResults);
        context.SetValue("cleanup_completed", true);
        
        return $"Memory cleanup completed: {cleanupResults.CleanedEntries} entries cleaned";
    });

// 將節點新增到管理工作流程
memoryManagementWorkflow.AddNode(memoryAnalyzer);
memoryManagementWorkflow.AddNode(memoryOptimizer);
memoryManagementWorkflow.AddNode(memoryCleanup);

// 設定起始節點
memoryManagementWorkflow.SetStartNode(memoryAnalyzer.NodeId);

// 測試記憶管理
Console.WriteLine("🧹 Testing memory management and optimization...");

var managementArguments = new KernelArguments
{
    ["session_id"] = "management-session-001",
    ["analysis_depth"] = 7
};

var result = await memoryManagementWorkflow.ExecuteAsync(kernel, managementArguments);

var analysisCompleted = result.GetValue<bool>("analysis_completed");
var optimizationCompleted = result.GetValue<bool>("optimization_completed");
var cleanupCompleted = result.GetValue<bool>("cleanup_completed");

if (analysisCompleted && optimizationCompleted && cleanupCompleted)
{
    var optimizationResults = result.GetValue<OptimizationResults>("optimization_results");
    var cleanupResults = result.GetValue<CleanupResults>("cleanup_results");
    
    Console.WriteLine($"   Analysis Completed: {analysisCompleted}");
    Console.WriteLine($"   Optimization Completed: {optimizationCompleted}");
    Console.WriteLine($"   Cleanup Completed: {cleanupCompleted}");
    Console.WriteLine($"   Optimizations Applied: {optimizationResults.AppliedOptimizations.Count}");
    Console.WriteLine($"   Entries Cleaned: {cleanupResults.CleanedEntries}");
}
```

## 預期輸出

### 基本記憶 Agent 範例

```
🧠 Testing basic memory agent...
   Input: What is machine learning?
   Response: Machine learning is a subset of artificial intelligence...
   Memories Retrieved: 3
   New Memory Stored: True

   Input: Tell me about neural networks
   Response: Neural networks are computational models inspired by...
   Memories Retrieved: 2
   New Memory Stored: True
```

### 進階記憶檢索範例

```
🔍 Testing advanced memory retrieval...
   Query: Explain the relationship between AI and machine learning
   Search Completed: True
   Confidence Score: 0.85
   Memory Sources: 5
   Synthesis Method: semantic_clustering

   Query: What are the latest developments in neural networks?
   Search Completed: True
   Confidence Score: 0.78
   Memory Sources: 3
   Synthesis Method: temporal_ranking
```

### 學習和自適應範例

```
📚 Testing learning and adaptation...
   Input: Explain quantum computing
   Feedback: positive
   Quality: 0.9
   Knowledge Gained: 0.85
   Skill Improvement: 0.72

   Input: What is blockchain?
   Feedback: neutral
   Quality: 0.7
   Knowledge Gained: 0.62
   Skill Improvement: 0.58
```

### 記憶管理範例

```
🧹 Testing memory management and optimization...
   Analysis Completed: True
   Optimization Completed: True
   Cleanup Completed: True
   Optimizations Applied: 4
   Entries Cleaned: 15
```

## 配置選項

### 記憶 Agent 配置

```csharp
var memoryAgentOptions = new MemoryAgentOptions
{
    EnableMemoryStorage = true,                     // 啟用記憶儲存
    EnableMemoryRetrieval = true,                   // 啟用記憶檢索
    EnableLearning = true,                          // 啟用學習能力
    EnableContextAwareness = true,                  // 啟用上下文感知
    MemoryRetentionDays = 30,                       // 記憶保留期
    MaxMemorySize = 1000,                           // 最大記憶大小
    EnableMemoryCompression = true,                 // 啟用記憶壓縮
    EnableMemoryEncryption = true,                  // 啟用記憶加密
    EnableMemoryBackup = true,                      // 啟用記憶備份
    BackupInterval = TimeSpan.FromHours(24)         // 備份間隔
};
```

### 進階記憶配置

```csharp
var advancedMemoryOptions = new AdvancedMemoryOptions
{
    EnableSemanticSearch = true,                    // 啟用語義搜尋
    EnableContextualRetrieval = true,               // 啟用上下文檢索
    EnableMemoryRanking = true,                     // 啟用記憶排名
    EnableMemoryClustering = true,                  // 啟用記憶叢集化
    SemanticSearchThreshold = 0.7,                  // 語義搜尋閾值
    ContextRelevanceWeight = 0.6,                   // 上下文相關性權重
    TemporalRelevanceWeight = 0.4,                  // 時間相關性權重
    EnableFuzzyMatching = true,                     // 啟用模糊匹配
    EnableMemoryDeduplication = true,               // 啟用記憶去重
    MaxSearchResults = 50                           // 最大搜尋結果數
};
```

### 學習配置

```csharp
var learningOptions = new LearningOptions
{
    EnableExperienceLearning = true,                // 啟用經驗學習
    EnablePatternRecognition = true,                // 啟用模式識別
    EnableAdaptiveBehavior = true,                  // 啟用自適應行為
    EnableKnowledgeExpansion = true,                // 啟用知識擴展
    LearningRate = 0.1,                             // 學習速率
    AdaptationThreshold = 0.7,                      // 自適應閾值
    PatternRecognitionThreshold = 0.6,              // 模式識別閾值
    EnableIncrementalLearning = true,               // 啟用增量學習
    EnableTransferLearning = true,                  // 啟用遷移學習
    MaxLearningIterations = 100                     // 最大學習迭代數
};
```

## 故障排除

### 常見問題

#### 記憶未被儲存
```bash
# 問題：記憶未被儲存
# 解決方案：檢查記憶儲存配置
EnableMemoryStorage = true;
MemoryRetentionDays = 30;
MaxMemorySize = 1000;
```

#### 記憶檢索效果不佳
```bash
# 問題：記憶檢索品質不佳
# 解決方案：調整搜尋閾值並啟用語義搜尋
EnableSemanticSearch = true;
SemanticSearchThreshold = 0.7;
ContextRelevanceWeight = 0.6;
```

#### 學習功能無法運作
```bash
# 問題：學習機制無法運作
# 解決方案：檢查學習配置並啟用所需功能
EnableExperienceLearning = true;
EnablePatternRecognition = true;
LearningRate = 0.1;
```

### 偵錯模式

啟用詳細的記憶監控以進行故障排除：

```csharp
// 啟用偵錯記憶監控
var debugMemoryOptions = new MemoryAgentOptions
{
    EnableMemoryStorage = true,
    EnableMemoryRetrieval = true,
    EnableLearning = true,
    EnableDebugLogging = true,
    EnableMemoryInspection = true,
    EnablePerformanceMonitoring = true,
    LogMemoryOperations = true,
    LogLearningProgress = true
};
```

## 進階模式

### 自訂記憶存儲

```csharp
// 實現自訂記憶存儲
public class CustomMemoryStore : IMemoryStore
{
    public async Task<bool> StoreMemoryAsync(MemoryEntry entry)
    {
        // 自訂儲存邏輯
        var storageResult = await StoreInCustomDatabase(entry);
        
        // 新增自訂中繼資料
        entry.Metadata["custom_stored"] = true;
        entry.Metadata["storage_timestamp"] = DateTime.UtcNow;
        
        return storageResult;
    }
    
    public async Task<List<MemoryEntry>> RetrieveMemoriesAsync(string query, Dictionary<string, object> context)
    {
        // 自訂檢索邏輯
        var memories = await RetrieveFromCustomDatabase(query, context);
        
        // 應用自訂篩選
        memories = await ApplyCustomFilters(memories, context);
        
        return memories;
    }
}
```

### 自訂學習演算法

```csharp
// 實現自訂學習演算法
public class CustomLearningAlgorithm : ILearningAlgorithm
{
    public async Task<LearningOutcome> LearnFromExperienceAsync(Experience experience)
    {
        var outcome = new LearningOutcome();
        
        // 自訂學習邏輯
        outcome.KnowledgeGained = await CalculateKnowledgeGain(experience);
        outcome.SkillImprovement = await CalculateSkillImprovement(experience);
        outcome.AdaptationLevel = await CalculateAdaptationLevel(experience);
        
        // 應用自訂學習規則
        await ApplyCustomLearningRules(experience, outcome);
        
        return outcome;
    }
    
    private async Task<double> CalculateKnowledgeGain(Experience experience)
    {
        // 自訂知識增益計算
        var baseGain = experience.Quality * 0.8;
        var feedbackMultiplier = GetFeedbackMultiplier(experience.Feedback);
        var contextBonus = GetContextBonus(experience.Context);
        
        return Math.Min(1.0, baseGain * feedbackMultiplier + contextBonus);
    }
}
```

### 記憶最佳化策略

```csharp
// 實現記憶最佳化策略
public class MemoryOptimizationStrategy : IMemoryOptimizationStrategy
{
    public async Task<OptimizationResult> OptimizeMemoryAsync(MemoryUsageAnalysis analysis)
    {
        var result = new OptimizationResult();
        
        // 若需要則應用壓縮
        if (analysis.CompressionRatio < 0.6)
        {
            result.AppliedOptimizations.Add(await CompressMemories(analysis));
        }
        
        // 若需要則應用去重
        if (analysis.DuplicationRate > 0.2)
        {
            result.AppliedOptimizations.Add(await DeduplicateMemories(analysis));
        }
        
        // 若需要則應用歸檔
        if (analysis.AccessFrequency < 0.3)
        {
            result.AppliedOptimizations.Add(await ArchiveMemories(analysis));
        }
        
        return result;
    }
    
    private async Task<Optimization> CompressMemories(MemoryUsageAnalysis analysis)
    {
        // 實現記憶壓縮
        var compressionRatio = await CompressMemoryData(analysis.Memories);
        
        return new Optimization
        {
            Type = "compression",
            Impact = compressionRatio,
            Description = $"Compressed memories with ratio {compressionRatio:F2}"
        };
    }
}
```

## 相關範例

* [多 Agent 系統](./multi-agent.md)：具有記憶的多 agent 協調
* [Graph 指標](./graph-metrics.md)：記憶效能監控
* [狀態管理](./state-tutorial.md)：記憶狀態持久化
* [效能最佳化](./performance-optimization.md)：記憶最佳化技術

## 另請參閱

* [記憶模式](../concepts/memory.md)：理解記憶概念
* [學習和自適應](../how-to/learning-adaptation.md)：基於記憶的學習
* [效能監控](../how-to/performance-monitoring.md)：記憶效能分析
* [API 參考](../api/)：完整的 API 文件
