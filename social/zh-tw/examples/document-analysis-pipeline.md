# 文件分析管道範例

此範例展示使用語義核心圖表的綜合文件處理工作流程。它展示如何使用並行處理和錯誤處理構建多階段文件攝入、分析、分類和資訊擷取管道。

## 目標

了解如何在基於圖表的工作流程中實現文件分析管道，以：
* 通過多個分析階段處理文件
* 實現並行處理以優化效能
* 處理不同的文件類型和格式
* 從非結構化文本提取結構化資訊
* 使用錯誤處理和恢復構建彈性管道
* 跨多個工作程序擴展文件處理

## 前提條件

* **.NET 8.0** 或更高版本
* **OpenAI API 金鑰**配置在 `appsettings.json` 中
* **語義核心圖表套件**已安裝
* 對[圖表概念](../concepts/graph-concepts.md)和[節點類型](../concepts/node-types.md)的基本了解

## 主要元件

### 概念和技術

* **管道處理**：文件分析階段的順序執行
* **並行處理**：獨立分析任務的並行執行
* **文件分類**：按類型和內容自動分類文件
* **資訊擷取**：從非結構化文本提取結構化資料
* **錯誤處理**：優雅處理處理失敗和恢復

### 核心類別

* `FunctionGraphNode`：執行文件處理功能
* `ConditionalGraphNode`：基於類型和內容路由文件
* `GraphExecutor`：協調文件分析管道
* `GraphState`：在整個處理過程中管理文件狀態和元資料

## 執行範例

### 入門

此範例展示使用語義核心圖表套件的文件分析管道工作流程。以下程式碼片段展示如何在自己的應用程式中實現此模式。

## 逐步實現

### 1. 基本文件分析管道

此範例展示一個簡單的三階段文件處理工作流程。

```csharp
// 使用模擬配置建立核心
var kernel = CreateKernel();

// 建立文件分析管道
var pipeline = new GraphExecutor("DocumentAnalysisPipeline", "Basic document analysis", logger);

// 階段 1：文件攝入
var documentIngestion = new FunctionGraphNode(
    "document-ingestion",
    "Ingest and validate document",
    async (context) =>
    {
        var documentPath = context.GetValue<string>("document_path");
        var documentContent = await File.ReadAllTextAsync(documentPath);
        
        // 提取基本元資料
        var fileInfo = new FileInfo(documentPath);
        var metadata = new Dictionary<string, object>
        {
            ["file_name"] = fileInfo.Name,
            ["file_size"] = fileInfo.Length,
            ["file_extension"] = fileInfo.Extension,
            ["ingestion_timestamp"] = DateTime.UtcNow,
            ["content_length"] = documentContent.Length
        };

        // 在執行內容上儲存內容和元資料，供下游節點使用
        context.SetValue("document_content", documentContent);
        context.SetValue("document_metadata", metadata);
        // 同時直接公開文件副檔名以簡化下游存取
        context.SetValue("file_extension", fileInfo.Extension);
        context.SetValue("processing_status", "ingested");
        
        return $"Document ingested: {fileInfo.Name} ({fileInfo.Length} bytes)";
    });

// 階段 2：文件分類
var documentClassification = new FunctionGraphNode(
    "document-classification",
    "Classify document by type and content",
    async (context) =>
    {
        var content = context.GetValue<string>("document_content");
        var extension = context.GetValue<string>("file_extension");
        
        // 簡單的分類邏輯
        var documentType = extension.ToLower() switch
        {
            ".txt" => "text",
            ".md" => "markdown",
            ".pdf" => "pdf",
            ".doc" => "word",
            ".docx" => "word",
            _ => "unknown"
        };
        
        // 基於內容的分類
        var contentCategory = content.ToLower() switch
        {
            var c when c.Contains("invoice") || c.Contains("bill") => "financial",
            var c when c.Contains("contract") || c.Contains("agreement") => "legal",
            var c when c.Contains("report") || c.Contains("analysis") => "report",
            var c when c.Contains("email") || c.Contains("correspondence") => "communication",
            _ => "general"
        };
        
        // 將分類結果保留在內容中
        context.SetValue("document_type", documentType);
        context.SetValue("content_category", contentCategory);
        context.SetValue("processing_status", "classified");

        return $"Document classified as {documentType} ({contentCategory})";
    });

// 階段 3：內容分析
var contentAnalysis = new FunctionGraphNode(
    "content-analysis",
    "Analyze document content and extract key information",
    async (context) =>
    {
        var content = context.GetValue<string>("document_content");
        var documentType = context.GetValue<string>("document_type");
        var contentCategory = context.GetValue<string>("content_category");
        
        // 根據文件類型提取關鍵資訊
        var analysis = new Dictionary<string, object>();
        
        switch (contentCategory)
        {
            case "financial":
                analysis["key_amounts"] = ExtractAmounts(content);
                analysis["dates"] = ExtractDates(content);
                analysis["parties"] = ExtractParties(content);
                break;
            case "legal":
                analysis["contract_parties"] = ExtractParties(content);
                analysis["effective_dates"] = ExtractDates(content);
                analysis["key_terms"] = ExtractKeyTerms(content);
                break;
            case "report":
                analysis["summary"] = GenerateSummary(content);
                analysis["key_findings"] = ExtractFindings(content);
                analysis["recommendations"] = ExtractRecommendations(content);
                break;
            default:
                analysis["word_count"] = content.Split(' ').Length;
                analysis["paragraph_count"] = content.Split('\n').Length;
                analysis["key_topics"] = ExtractTopics(content);
                break;
        }
        
        // 儲存分析結果並更新處理狀態
        context.SetValue("content_analysis", analysis);
        context.SetValue("processing_status", "analyzed");
        context.SetValue("analysis_timestamp", DateTime.UtcNow);
        
        return $"Content analysis completed for {documentType} document";
    });

// 將節點新增到管道
pipeline.AddNode(documentIngestion);
pipeline.AddNode(documentClassification);
pipeline.AddNode(contentAnalysis);

// 設定開始節點
pipeline.SetStartNode(documentIngestion.NodeId);

// 使用示例文件測試
var testDocuments = new[]
{
    "sample_invoice.txt",
    "contract_agreement.md",
    "quarterly_report.txt"
};

foreach (var docPath in testDocuments)
{
    var arguments = new KernelArguments
    {
        ["document_path"] = docPath
    };

    Console.WriteLine($"📄 Processing document: {docPath}");
    var result = await pipeline.ExecuteAsync(kernel, arguments);
    
    var status = result.GetValue<string>("processing_status");
    var docType = result.GetValue<string>("document_type");
    var category = result.GetValue<string>("content_category");
    
    Console.WriteLine($"   Status: {status}");
    Console.WriteLine($"   Type: {docType}");
    Console.WriteLine($"   Category: {category}");
    
    if (result.TryGetValue("content_analysis", out var analysis))
    {
        Console.WriteLine($"   Analysis: {analysis}");
    }
    Console.WriteLine();
}
```

### 2. 具有並行處理的進階管道

展示獨立分析任務的並行執行以改進效能。

```csharp
// 使用並行處理建立進階管道
var advancedPipeline = new GraphExecutor("AdvancedDocumentPipeline", "Parallel document analysis", logger);

// 文件攝入（順序）
var advancedIngestion = new FunctionGraphNode(
    "advanced-ingestion",
    "Advanced document ingestion with validation",
    async (context) =>
    {
        var documentPath = context.GetValue<string>("document_path");
        var documentContent = await File.ReadAllTextAsync(documentPath);
        
        // 驗證文件
        if (string.IsNullOrWhiteSpace(documentContent))
        {
            throw new InvalidOperationException("Document content is empty");
        }
        
        // 提取全面的元資料
        var fileInfo = new FileInfo(documentPath);
        var metadata = new Dictionary<string, object>
        {
            ["file_name"] = fileInfo.Name,
            ["file_size"] = fileInfo.Length,
            ["file_extension"] = fileInfo.Extension,
            ["ingestion_timestamp"] = DateTime.UtcNow,
            ["content_length"] = documentContent.Length,
            ["line_count"] = documentContent.Split('\n').Length,
            ["word_count"] = documentContent.Split(' ').Length,
            ["character_count"] = documentContent.Length
        };
        
        context.SetValue("document_content", documentContent);
        context.SetValue("document_metadata", metadata);
        context.SetValue("processing_status", "ingested");
        
        return $"Advanced ingestion completed: {fileInfo.Name}";
    });

// 並行分析任務
var textAnalysis = new FunctionGraphNode(
    "text-analysis",
    "Analyze text content and structure",
    async (context) =>
    {
        var content = context.GetValue<string>("document_content");
        
        // 文本分析
        var analysis = new Dictionary<string, object>
        {
            ["readability_score"] = CalculateReadabilityScore(content),
            ["sentiment_score"] = AnalyzeSentiment(content),
            ["language_detected"] = DetectLanguage(content),
            ["key_phrases"] = ExtractKeyPhrases(content),
            ["named_entities"] = ExtractNamedEntities(content)
        };
        
        context.SetValue("text_analysis", analysis);
        return "Text analysis completed";
    });

var structureAnalysis = new FunctionGraphNode(
    "structure-analysis",
    "Analyze document structure and formatting",
    async (context) =>
    {
        var content = context.GetValue<string>("document_content");
        
        // 結構分析
        var structure = new Dictionary<string, object>
        {
            ["sections"] = IdentifySections(content),
            ["headers"] = ExtractHeaders(content),
            ["lists"] = CountLists(content),
            ["tables"] = CountTables(content),
            ["formatting"] = AnalyzeFormatting(content)
        };
        
        context.SetValue("structure_analysis", structure);
        return "Structure analysis completed";
    });

var semanticAnalysis = new FunctionGraphNode(
    "semantic-analysis",
    "Perform semantic analysis of content",
    async (context) =>
    {
        var content = context.GetValue<string>("document_content");
        
        // 語意分析
        var semantic = new Dictionary<string, object>
        {
            ["topics"] = ExtractTopics(content),
            ["themes"] = IdentifyThemes(content),
            ["relationships"] = FindRelationships(content),
            ["summary"] = GenerateSemanticSummary(content),
            ["key_insights"] = ExtractKeyInsights(content)
        };
        
        context.SetValue("semantic_analysis", semantic);
        return "Semantic analysis completed";
    });

// 結果聚合
var resultsAggregation = new FunctionGraphNode(
    "results-aggregation",
    "Aggregate all analysis results",
    async (context) =>
    {
        var textAnalysis = context.GetValue<Dictionary<string, object>>("text_analysis");
        var structureAnalysis = context.GetValue<Dictionary<string, object>>("structure_analysis");
        var semanticAnalysis = context.GetValue<Dictionary<string, object>>("semantic_analysis");
        var metadata = context.GetValue<Dictionary<string, object>>("document_metadata");
        
        // 組合所有結果
        var comprehensiveAnalysis = new Dictionary<string, object>
        {
            ["metadata"] = metadata,
            ["text_analysis"] = textAnalysis,
            ["structure_analysis"] = structureAnalysis,
            ["semantic_analysis"] = semanticAnalysis,
            ["analysis_timestamp"] = DateTime.UtcNow,
            ["processing_status"] = "completed"
        };
        
        context.SetValue("comprehensive_analysis", comprehensiveAnalysis);
        
        return "Results aggregation completed";
    });

// 將節點新增到管道
advancedPipeline.AddNode(advancedIngestion);
advancedPipeline.AddNode(textAnalysis);
advancedPipeline.AddNode(structureAnalysis);
advancedPipeline.AddNode(semanticAnalysis);
advancedPipeline.AddNode(resultsAggregation);

// 設定開始節點
advancedPipeline.SetStartNode(advancedIngestion.NodeId);

// 測試進階管道
var advancedArgs = new KernelArguments
{
    ["document_path"] = "complex_document.txt"
};

Console.WriteLine("🚀 Starting advanced document analysis pipeline...");
var advancedResult = await advancedPipeline.ExecuteAsync(kernel, advancedArgs);

var comprehensiveAnalysis = advancedResult.GetValue<Dictionary<string, object>>("comprehensive_analysis");
Console.WriteLine($"✅ Advanced analysis completed");
Console.WriteLine($"   Text Analysis: {comprehensiveAnalysis["text_analysis"]}");
Console.WriteLine($"   Structure Analysis: {comprehensiveAnalysis["structure_analysis"]}");
Console.WriteLine($"   Semantic Analysis: {comprehensiveAnalysis["semantic_analysis"]}");
```

### 3. 錯誤處理和恢復管道

展示如何使用錯誤處理和恢復機制實現彈性文件處理。

```csharp
// 使用錯誤處理建立彈性管道
var resilientPipeline = new GraphExecutor("ResilientDocumentPipeline", "Error handling and recovery", logger);

// 具有驗證的文件攝入
var resilientIngestion = new FunctionGraphNode(
    "resilient-ingestion",
    "Resilient document ingestion",
    async (context) =>
    {
        try
        {
            var documentPath = context.GetValue<string>("document_path");
            
            if (!File.Exists(documentPath))
            {
                context.SetValue("error_type", "file_not_found");
                context.SetValue("error_message", $"Document not found: {documentPath}");
                context.SetValue("processing_status", "failed");
                return "Document not found";
            }
            
            var documentContent = await File.ReadAllTextAsync(documentPath);
            
            if (string.IsNullOrWhiteSpace(documentContent))
            {
                context.SetValue("error_type", "empty_content");
                context.SetValue("error_message", "Document content is empty");
                context.SetValue("processing_status", "failed");
                return "Empty document content";
            }
            
            // 成功路徑
            context.SetValue("document_content", documentContent);
            context.SetValue("processing_status", "ingested");
            context.SetValue("error_type", "none");
            
            return "Document ingested successfully";
        }
        catch (Exception ex)
        {
            context.SetValue("error_type", "ingestion_error");
            context.SetValue("error_message", ex.Message);
            context.SetValue("processing_status", "failed");
            return $"Ingestion failed: {ex.Message}";
        }
    });

// 基於攝入狀態的條件路由
var ingestionRouter = new ConditionalGraphNode(
    "ingestion-router",
    "Route based on ingestion status",
    logger)
{
    ConditionExpression = "processing_status == 'ingested'",
    TrueNodeId = "content-processor",
    FalseNodeId = "error-handler"
};

// 用於成功攝入的內容處理程式
var contentProcessor = new FunctionGraphNode(
    "content-processor",
    "Process document content",
    async (context) =>
    {
        try
        {
            var content = context.GetValue<string>("document_content");
            
            // 處理內容
            var processedContent = await ProcessContentAsync(content);
            context.SetValue("processed_content", processedContent);
            context.SetValue("processing_status", "processed");
            
            return "Content processing completed";
        }
        catch (Exception ex)
        {
            context.SetValue("error_type", "processing_error");
            context.SetValue("error_message", ex.Message);
            context.SetValue("processing_status", "failed");
            return $"Content processing failed: {ex.Message}";
        }
    });

// 用於失敗操作的錯誤處理程式
var errorHandler = new FunctionGraphNode(
    "error-handler",
    "Handle processing errors",
    async (context) =>
    {
        var errorType = context.GetValue<string>("error_type");
        var errorMessage = context.GetValue<string>("error_message");
        
        // 記錄錯誤
        Console.WriteLine($"❌ Error in document processing: {errorType} - {errorMessage}");
        
        // 根據錯誤類型嘗試恢復
        var recoveryAction = errorType switch
        {
            "file_not_found" => "Request document resubmission",
            "empty_content" => "Skip processing and notify user",
            "ingestion_error" => "Retry with exponential backoff",
            "processing_error" => "Fall back to basic processing",
            _ => "Unknown error - manual intervention required"
        };
        
        context.SetValue("recovery_action", recoveryAction);
        context.SetValue("processing_status", "error_handled");
        
        return $"Error handled. Recovery action: {recoveryAction}";
    });

// 將節點新增到彈性管道
resilientPipeline.AddNode(resilientIngestion);
resilientPipeline.AddNode(ingestionRouter);
resilientPipeline.AddNode(contentProcessor);
resilientPipeline.AddNode(errorHandler);

// 設定開始節點
resilientPipeline.SetStartNode(resilientIngestion.NodeId);

// 測試錯誤處理情況
var errorTestScenarios = new[]
{
    new { Path = "nonexistent_file.txt", ExpectedError = "file_not_found" },
    new { Path = "empty_file.txt", ExpectedError = "empty_content" },
    new { Path = "valid_document.txt", ExpectedError = "none" }
};

foreach (var scenario in errorTestScenarios)
{
    var resilientArgs = new KernelArguments
    {
        ["document_path"] = scenario.Path
    };

    Console.WriteLine($"\n🧪 Testing error handling: {scenario.Path}");
    var resilientResult = await resilientPipeline.ExecuteAsync(kernel, resilientArgs);
    
    var status = resilientResult.GetValue<string>("processing_status");
    var errorType = resilientResult.GetValue<string>("error_type");
    
    Console.WriteLine($"   Status: {status}");
    Console.WriteLine($"   Error Type: {errorType}");
    
    if (status == "error_handled")
    {
        var recoveryAction = resilientResult.GetValue<string>("recovery_action");
        Console.WriteLine($"   Recovery Action: {recoveryAction}");
    }
}
```

### 4. 多文件批次處理

展示使用結果聚合的多個文件並行處理。

```csharp
// 建立批次處理管道
var batchPipeline = new GraphExecutor("BatchDocumentPipeline", "Multi-document batch processing", logger);

// 文件批次處理程式
var batchProcessor = new FunctionGraphNode(
    "batch-processor",
    "Process multiple documents in batch",
    async (context) =>
    {
        var documentPaths = context.GetValue<string[]>("document_paths");
        var batchResults = new List<Dictionary<string, object>>();
        
        // 並行處理文件
        var processingTasks = documentPaths.Select(async (docPath, index) =>
        {
            try
            {
                var content = await File.ReadAllTextAsync(docPath);
                var fileInfo = new FileInfo(docPath);
                
                var result = new Dictionary<string, object>
                {
                    ["document_id"] = $"doc_{index}",
                    ["file_name"] = fileInfo.Name,
                    ["file_size"] = fileInfo.Length,
                    ["content_length"] = content.Length,
                    ["processing_status"] = "processed",
                    ["processing_timestamp"] = DateTime.UtcNow
                };
                
                // 基本分析
                result["word_count"] = content.Split(' ').Length;
                result["line_count"] = content.Split('\n').Length;
                result["key_topics"] = ExtractTopics(content);
                
                return result;
            }
            catch (Exception ex)
            {
                return new Dictionary<string, object>
                {
                    ["document_id"] = $"doc_{index}",
                    ["file_name"] = docPath,
                    ["processing_status"] = "failed",
                    ["error_message"] = ex.Message,
                    ["processing_timestamp"] = DateTime.UtcNow
                };
            }
        });
        
        var results = await Task.WhenAll(processingTasks);
        batchResults.AddRange(results);
        
        context.SetValue("batch_results", batchResults);
        context.SetValue("total_documents", documentPaths.Length);
        context.SetValue("successful_documents", batchResults.Count(r => r["processing_status"].ToString() == "processed"));
        context.SetValue("failed_documents", batchResults.Count(r => r["processing_status"].ToString() == "failed"));
        
        return $"Batch processing completed: {batchResults.Count} documents processed";
    });

// 批次結果分析器
var batchAnalyzer = new FunctionGraphNode(
    "batch-analyzer",
    "Analyze batch processing results",
    async (context) =>
    {
        var batchResults = context.GetValue<List<Dictionary<string, object>>>("batch_results");
        var totalDocuments = context.GetValue<int>("total_documents");
        var successfulDocuments = context.GetValue<int>("successful_documents");
        var failedDocuments = context.GetValue<int>("failed_documents");
        
        // 計算統計資料
        var totalSize = batchResults
            .Where(r => r["processing_status"].ToString() == "processed")
            .Sum(r => Convert.ToInt64(r["file_size"]));
        
        var totalWords = batchResults
            .Where(r => r["processing_status"].ToString() == "processed")
            .Sum(r => Convert.ToInt32(r["word_count"]));
        
        var analysis = new Dictionary<string, object>
        {
            ["total_documents"] = totalDocuments,
            ["successful_documents"] = successfulDocuments,
            ["failed_documents"] = failedDocuments,
            ["success_rate"] = (double)successfulDocuments / totalDocuments,
            ["total_size_bytes"] = totalSize,
            ["total_words"] = totalWords,
            ["average_file_size"] = totalSize / Math.Max(successfulDocuments, 1),
            ["average_words_per_document"] = totalWords / Math.Max(successfulDocuments, 1),
            ["processing_summary"] = batchResults
        };
        
        context.SetValue("batch_analysis", analysis);
        context.SetValue("processing_status", "batch_completed");
        
        return "Batch analysis completed";
    });

// 將節點新增到批次管道
batchPipeline.AddNode(batchProcessor);
batchPipeline.AddNode(batchAnalyzer);

// 設定開始節點
batchPipeline.SetStartNode(batchProcessor.NodeId);

// 測試批次處理
var batchArgs = new KernelArguments
{
    ["document_paths"] = new[]
    {
        "document1.txt",
        "document2.md",
        "document3.txt",
        "document4.pdf"
    }
};

Console.WriteLine("📚 Starting batch document processing...");
var batchResult = await batchPipeline.ExecuteAsync(kernel, batchArgs);

var batchAnalysis = batchResult.GetValue<Dictionary<string, object>>("batch_analysis");
Console.WriteLine($"✅ Batch processing completed");
Console.WriteLine($"   Total Documents: {batchAnalysis["total_documents"]}");
Console.WriteLine($"   Successful: {batchAnalysis["successful_documents"]}");
Console.WriteLine($"   Failed: {batchAnalysis["failed_documents"]}");
Console.WriteLine($"   Success Rate: {Convert.ToDouble(batchAnalysis["success_rate"]):P1}");
Console.WriteLine($"   Total Size: {Convert.ToInt64(batchAnalysis["total_size_bytes"]):N0} bytes");
Console.WriteLine($"   Total Words: {Convert.ToInt32(batchAnalysis["total_words"]):N0}");
```

## 預期輸出

### 基本文件分析管道範例

```
📄 Processing document: sample_invoice.txt
   Status: analyzed
   Type: text
   Category: financial
   Analysis: [key_amounts, dates, parties]

📄 Processing document: contract_agreement.md
   Status: analyzed
   Type: markdown
   Category: legal
   Analysis: [contract_parties, effective_dates, key_terms]

📄 Processing document: quarterly_report.txt
   Status: analyzed
   Type: text
   Category: report
   Analysis: [summary, key_findings, recommendations]
```

### 具有並行處理的進階管道範例

```
🚀 Starting advanced document analysis pipeline...
✅ Advanced analysis completed
   Text Analysis: [readability_score, sentiment_score, language_detected, key_phrases, named_entities]
   Structure Analysis: [sections, headers, lists, tables, formatting]
   Semantic Analysis: [topics, themes, relationships, summary, key_insights]
```

### 錯誤處理和恢復管道範例

```
🧪 Testing error handling: nonexistent_file.txt
   Status: error_handled
   Error Type: file_not_found
   Recovery Action: Request document resubmission

🧪 Testing error handling: empty_file.txt
   Status: error_handled
   Error Type: empty_content
   Recovery Action: Skip processing and notify user

🧪 Testing error handling: valid_document.txt
   Status: processed
   Error Type: none
```

### 多文件批次處理範例

```
📚 Starting batch document processing...
✅ Batch processing completed
   Total Documents: 4
   Successful: 3
   Failed: 1
   Success Rate: 75.0%
   Total Size: 45,678 bytes
   Total Words: 12,345
```

## 配置選項

### 管道配置

```csharp
var pipelineOptions = new DocumentPipelineOptions
{
    EnableParallelProcessing = true,              // 啟用並行執行
    MaxConcurrency = Environment.ProcessorCount, // 最大並行任務數
    EnableErrorHandling = true,                   // 啟用錯誤處理
    EnableRecovery = true,                        // 啟用自動恢復
    BatchSize = 100,                              // 每批文件數
    ProcessingTimeout = TimeSpan.FromMinutes(30), // 處理逾時
    EnableProgressTracking = true,                 // 追蹤處理進度
    EnableResultCaching = true,                   // 快取分析結果
    StorageProvider = new FileSystemStorageProvider("./pipeline-results")
};
```

### 文件處理配置

```csharp
var processingOptions = new DocumentProcessingOptions
{
    SupportedFormats = new[] { ".txt", ".md", ".pdf", ".doc", ".docx" },
    MaxFileSize = 100 * 1024 * 1024,             // 100MB 最大檔案大小
    EnableContentValidation = true,                // 驗證文件內容
    EnableMetadataExtraction = true,               // 提取文件元資料
    EnableContentAnalysis = true,                  // 執行內容分析
    EnableStructureAnalysis = true,                // 分析文件結構
    EnableSemanticAnalysis = true,                 // 執行語意分析
    AnalysisDepth = AnalysisDepth.Comprehensive,   // 分析深度等級
    EnableResultPersistence = true                 // 保留分析結果
};
```

## 疑難排解

### 常見問題

#### 文件攝入失敗
```bash
# 問題：文件無法攝入
# 解決方案：檢查檔案權限並驗證檔案格式
EnableContentValidation = true;
SupportedFormats = new[] { ".txt", ".md", ".pdf" };
```

#### 並行處理問題
```bash
# 問題：並行處理導致錯誤
# 解決方案：降低並行性並啟用錯誤處理
MaxConcurrency = 2;
EnableErrorHandling = true;
```

#### 記憶體問題
```bash
# 問題：大型文件導致記憶體問題
# 解決方案：啟用串流並設定記憶體限制
MaxFileSize = 50 * 1024 * 1024; // 50MB 限制
EnableStreaming = true;
```

### 偵錯模式

啟用詳細記錄以進行疑難排解：

```csharp
// 啟用偵錯記錄
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<DocumentAnalysisPipelineExample>();

// 使用偵錯記錄配置管道
var debugPipeline = new GraphExecutor("DebugPipeline", "Debug document analysis", logger);
debugPipeline.EnableDebugMode = true;
debugPipeline.LogProcessingSteps = true;
debugPipeline.LogErrorDetails = true;
```

## 進階模式

### 自訂文件處理程式

```csharp
// 實現自訂文件處理程式
public class CustomDocumentProcessor : IDocumentProcessor
{
    public async Task<DocumentAnalysisResult> ProcessAsync(DocumentContext context)
    {
        var content = context.Content;
        var metadata = context.Metadata;
        
        // 自訂處理邏輯
        var customAnalysis = await PerformCustomAnalysis(content, metadata);
        
        return new DocumentAnalysisResult
        {
            DocumentId = context.DocumentId,
            AnalysisResults = customAnalysis,
            ProcessingTimestamp = DateTime.UtcNow,
            ProcessorVersion = "1.0.0"
        };
    }
    
    private async Task<Dictionary<string, object>> PerformCustomAnalysis(string content, Dictionary<string, object> metadata)
    {
        // 實現自訂分析邏輯
        await Task.Delay(100); // 模擬處理
        
        return new Dictionary<string, object>
        {
            ["custom_metric"] = CalculateCustomMetric(content),
            ["domain_specific_analysis"] = PerformDomainAnalysis(content, metadata)
        };
    }
}
```

### 管道協調

```csharp
// 協調多個文件處理管道
var orchestrator = new DocumentPipelineOrchestrator
{
    PipelineDefinitions = new Dictionary<string, PipelineDefinition>
    {
        ["financial_documents"] = new PipelineDefinition
        {
            EntryCondition = "content_category == 'financial'",
            PipelineGraph = financialPipeline,
            Priority = 1,
            ProcessingRules = new FinancialProcessingRules()
        },
        ["legal_documents"] = new PipelineDefinition
        {
            EntryCondition = "content_category == 'legal'",
            PipelineGraph = legalPipeline,
            Priority = 2,
            ProcessingRules = new LegalProcessingRules()
        }
    },
    DefaultPipeline = generalPipeline,
    EnableLoadBalancing = true,
    EnableFailover = true
};

var selectedPipeline = orchestrator.SelectPipeline(documentContext);
```

### 實時處理

```csharp
// 實現實時文件處理
var realTimePipeline = new RealTimeDocumentPipeline
{
    InputQueue = new DocumentQueue(),
    ProcessingWorkers = new List<DocumentWorker>(),
    ResultPublisher = new ResultPublisher(),
    EnableStreaming = true,
    ProcessingMode = ProcessingMode.RealTime
};

// 啟動實時處理
await realTimePipeline.StartAsync();

// 訂閱實時結果
realTimePipeline.ResultPublished += (sender, e) =>
{
    Console.WriteLine($"📊 Real-time result: {e.DocumentId} - {e.AnalysisSummary}");
};
```

## 相關範例

* [條件節點](./conditional-nodes.md)：動態路由和決策
* [串流執行](./streaming-execution.md)：實時處理和監控
* [多代理](./multi-agent.md)：協調文件處理
* [檢查點](./checkpointing.md)：狀態持續性和恢復

## 另見

* [文件處理概念](../concepts/document-processing.md)：了解文件分析
* [管道模式](../patterns/pipeline.md)：建置處理管道
* [效能最佳化](../how-to/performance-optimization.md)：優化處理效能
* [API 參考](../api/)：完整的 API 文件
