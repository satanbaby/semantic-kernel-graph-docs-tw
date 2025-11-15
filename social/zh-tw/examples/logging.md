# 日誌記錄範例

本範例展示了 Semantic Kernel Graph 工作流程中的全面日誌記錄和結構化日誌功能。它展示了如何實現不同的日誌級別、結構化日誌、日誌聚合和與各種日誌系統的整合。

## 目標

學習如何在基於圖形的工作流程中實現全面的日誌記錄以：
* 配置不同的日誌級別和類別
* 實現具有語義信息的結構化日誌
* 聚合和分析圖形執行過程中的日誌
* 與外部日誌系統和儀表板整合
* 通過日誌監控和調試圖形執行

## 前置要求

* **.NET 8.0** 或更高版本
* **OpenAI API 金鑰**在 `appsettings.json` 中配置
* **Semantic Kernel Graph 套件**已安裝
* 對[圖形概念](../concepts/graph-concepts.md)和[日誌概念](../concepts/logging.md)的基本理解

## 關鍵組件

### 概念和技術

* **結構化日誌**：具有結構化數據和語義信息的日誌記錄
* **日誌級別**：不同級別的日誌詳細程度（Debug、Info、Warning、Error）
* **日誌聚合**：跨執行收集和分析日誌
* **日誌關聯**：將日誌與執行上下文和節點 ID 相關聯
* **日誌匯出**：將日誌匯出到外部系統和儀表板

### 核心類別

* `SemanticKernelGraphLogger`：核心日誌實現
* `GraphExecutionLogger`：執行特定的日誌記錄
* `NodeExecutionLogger`：節點級日誌記錄
* `LogAggregator`：日誌集合和分析

## 執行範例

### 入門

本範例展示了 Semantic Kernel Graph 套件的全面日誌記錄和追蹤。下面的代碼片段展示了如何在自己的應用程序中實現此模式。

## 逐步實現

### 1. 基本日誌配置

此範例展示了基本日誌設置和配置。

```csharp
// 使用模擬配置建立核心
var kernel = Kernel.CreateBuilder().Build();

// 建立啟用日誌的工作流程
var loggingWorkflow = new GraphExecutor("LoggingWorkflow", "Basic logging configuration", logger);

// 配置日誌選項
var loggingOptions = new GraphLoggingOptions
{
    EnableStructuredLogging = true,
    EnableExecutionLogging = true,
    EnableNodeLogging = true,
    EnablePerformanceLogging = true,
    EnableErrorLogging = true,
    LogLevel = LogLevel.Information,
    EnableLogCorrelation = true,
    EnableLogAggregation = true,
    LogStoragePath = "./logs"
};

loggingWorkflow.ConfigureLogging(loggingOptions);

// 具有日誌記錄的範例處理節點
var loggingProcessor = new FunctionGraphNode(
    "logging-processor",
    "Process data with comprehensive logging",
    async (context) =>
    {
        var inputData = context.GetValue<string>("input_data");
        var startTime = DateTime.UtcNow;
        
        // 日誌處理開始
        context.Logger.LogInformation("Starting data processing", new
        {
            NodeId = "logging-processor",
            InputData = inputData,
            StartTime = startTime,
            ExecutionId = context.ExecutionId
        });
        
        // 模擬處理
        await Task.Delay(Random.Shared.Next(100, 300));
        
        var processedData = $"Processed: {inputData}";
        var processingTime = DateTime.UtcNow - startTime;
        
        // 日誌處理完成
        context.Logger.LogInformation("Data processing completed", new
        {
            NodeId = "logging-processor",
            InputData = inputData,
            ProcessedData = processedData,
            ProcessingTimeMs = processingTime.TotalMilliseconds,
            ExecutionId = context.ExecutionId
        });
        
        context.SetValue("processed_data", processedData);
        context.SetValue("processing_time_ms", processingTime.TotalMilliseconds);
        context.SetValue("processing_step", "logged_processed");
        
        return processedData;
    });

// 日誌聚合節點
var logAggregator = new FunctionGraphNode(
    "log-aggregator",
    "Aggregate and analyze logs",
    async (context) =>
    {
        var processedData = context.GetValue<string>("processed_data");
        var processingTime = context.GetValue<double>("processing_time_ms");
        
        // 聚合日誌信息
        var logSummary = new Dictionary<string, object>
        {
            ["total_logs"] = 2, // 開始 + 完成日誌
            ["processing_time_ms"] = processingTime,
            ["input_data"] = context.GetValue<string>("input_data"),
            ["processed_data"] = processedData,
            ["execution_id"] = context.ExecutionId,
            ["aggregation_timestamp"] = DateTime.UtcNow
        };
        
        context.SetValue("log_summary", logSummary);
        
        // 日誌聚合完成
        context.Logger.LogInformation("Log aggregation completed", logSummary);
        
        return $"Log aggregation completed: {logSummary["total_logs"]} logs processed";
    });

// 將節點添加到工作流程
loggingWorkflow.AddNode(loggingProcessor);
loggingWorkflow.AddNode(logAggregator);

// 設置起始節點
loggingWorkflow.SetStartNode(loggingProcessor.NodeId);

// 測試基本日誌
var testData = new[]
{
    "Sample data 1",
    "Sample data 2",
    "Sample data 3"
};

foreach (var data in testData)
{
    var arguments = new KernelArguments
    {
        ["input_data"] = data
    };

    Console.WriteLine($"📝 Testing basic logging: {data}");
    var result = await loggingWorkflow.ExecuteAsync(kernel, arguments);
    
    var processingTime = result.GetValue<double>("processing_time_ms");
    var logSummary = result.GetValue<Dictionary<string, object>>("log_summary");
    
    Console.WriteLine($"   Processing Time: {processingTime:F2} ms");
    Console.WriteLine($"   Logs Generated: {logSummary["total_logs"]}");
    Console.WriteLine();
}
```

### 2. 進階結構化日誌

展示具有語義信息和上下文的進階結構化日誌。

```csharp
// 建立進階日誌工作流程
var advancedLoggingWorkflow = new GraphExecutor("AdvancedLoggingWorkflow", "Advanced structured logging", logger);

// 配置進階日誌
var advancedLoggingOptions = new GraphLoggingOptions
{
    EnableStructuredLogging = true,
    EnableExecutionLogging = true,
    EnableNodeLogging = true,
    EnablePerformanceLogging = true,
    EnableErrorLogging = true,
    EnableLogCorrelation = true,
    EnableLogAggregation = true,
    EnableSemanticLogging = true,
    EnableContextLogging = true,
    LogLevel = LogLevel.Debug,
    LogStoragePath = "./advanced-logs",
    StructuredLogFormat = "json",
    EnableLogCompression = true,
    MaxLogHistory = 10000
};

advancedLoggingWorkflow.ConfigureLogging(advancedLoggingOptions);

// 具有語義日誌的進階處理節點
var advancedProcessor = new FunctionGraphNode(
    "advanced-processor",
    "Advanced processing with semantic logging",
    async (context) =>
    {
        var inputData = context.GetValue<string>("input_data");
        var processingType = context.GetValue<string>("processing_type", "standard");
        var startTime = DateTime.UtcNow;
        
        // 帶上下文的語義日誌
        context.Logger.LogInformation("Advanced processing initiated", new
        {
            NodeId = "advanced-processor",
            ProcessingType = processingType,
            InputData = inputData,
            StartTime = startTime,
            ExecutionId = context.ExecutionId,
            Context = new
            {
                UserId = context.GetValue<string>("user_id", "anonymous"),
                SessionId = context.GetValue<string>("session_id", "default"),
                RequestId = context.GetValue<string>("request_id", Guid.NewGuid().ToString())
            },
            Metadata = new
            {
                Version = "1.0.0",
                Environment = "development",
                Component = "advanced-processor"
            }
        });
        
        // 模擬複雜處理
        var iterations = processingType == "complex" ? 1000 : 100;
        var result = 0;
        
        for (int i = 0; i < iterations; i++)
        {
            result += i * i;
            if (i % 100 == 0)
            {
                // 進度日誌
                context.Logger.LogDebug("Processing progress", new
                {
                    NodeId = "advanced-processor",
                    Iteration = i,
                    Progress = (double)i / iterations,
                    CurrentResult = result
                });
                
                await Task.Delay(1);
            }
        }
        
        var processingTime = DateTime.UtcNow - startTime;
        var processedData = $"Advanced processed: {inputData} (result: {result})";
        
        // 具有性能指標的完成日誌
        context.Logger.LogInformation("Advanced processing completed", new
        {
            NodeId = "advanced-processor",
            ProcessingType = processingType,
            InputData = inputData,
            ProcessedData = processedData,
            ProcessingTimeMs = processingTime.TotalMilliseconds,
            Iterations = iterations,
            FinalResult = result,
            PerformanceMetrics = new
            {
                Throughput = iterations / (processingTime.TotalMilliseconds / 1000.0),
                Efficiency = processingTime.TotalMilliseconds / iterations,
                CpuUsage = GetCurrentCpuUsage(),
                MemoryUsage = GetCurrentMemoryUsage()
            },
            ExecutionId = context.ExecutionId,
            Context = new
            {
                UserId = context.GetValue<string>("user_id", "anonymous"),
                SessionId = context.GetValue<string>("session_id", "default"),
                RequestId = context.GetValue<string>("request_id", Guid.NewGuid().ToString())
            }
        });
        
        context.SetValue("processed_data", processedData);
        context.SetValue("processing_time_ms", processingTime.TotalMilliseconds);
        context.SetValue("iterations", iterations);
        context.SetValue("final_result", result);
        context.SetValue("processing_step", "advanced_logged_processed");
        
        return processedData;
    });

// 語義日誌分析器
var semanticLogAnalyzer = new FunctionGraphNode(
    "semantic-log-analyzer",
    "Analyze semantic logs and extract insights",
    async (context) =>
    {
        var processedData = context.GetValue<string>("processed_data");
        var processingTime = context.GetValue<double>("processing_time_ms");
        var iterations = context.GetValue<int>("iterations");
        var finalResult = context.GetValue<int>("final_result");
        
        // 分析日誌模式並提取洞察
        var logAnalysis = new Dictionary<string, object>
        {
            ["processing_summary"] = new
            {
                TotalTime = processingTime,
                Iterations = iterations,
                FinalResult = finalResult,
                Throughput = iterations / (processingTime / 1000.0)
            },
            ["performance_insights"] = new
            {
                IsEfficient = processingTime < 1000, // 少於 1 秒
                Complexity = iterations > 500 ? "high" : "medium",
                OptimizationOpportunity = processingTime > 500 ? "yes" : "no"
            },
            ["semantic_patterns"] = new
            {
                ProcessingType = context.GetValue<string>("processing_type"),
                UserContext = context.GetValue<string>("user_id"),
                SessionContext = context.GetValue<string>("session_id")
            },
            ["analysis_timestamp"] = DateTime.UtcNow,
            ["execution_id"] = context.ExecutionId
        };
        
        context.SetValue("log_analysis", logAnalysis);
        
        // 日誌分析完成
        context.Logger.LogInformation("Semantic log analysis completed", logAnalysis);
        
        return $"Semantic log analysis completed with {logAnalysis.Count} insights";
    });

// 將節點添加到進階工作流程
advancedLoggingWorkflow.AddNode(advancedProcessor);
advancedLoggingWorkflow.AddNode(semanticLogAnalyzer);

// 設置起始節點
advancedLoggingWorkflow.SetStartNode(advancedProcessor.NodeId);

// 測試進階日誌
var advancedTestScenarios = new[]
{
    new { Data = "Simple processing", Type = "simple" },
    new { Data = "Complex processing", Type = "complex" },
    new { Data = "Standard processing", Type = "standard" }
};

foreach (var scenario in advancedTestScenarios)
{
    var arguments = new KernelArguments
    {
        ["input_data"] = scenario.Data,
        ["processing_type"] = scenario.Type,
        ["user_id"] = "user123",
        ["session_id"] = "session456",
        ["request_id"] = Guid.NewGuid().ToString()
    };

    Console.WriteLine($"🔍 Testing advanced logging: {scenario.Data}");
    Console.WriteLine($"   Processing Type: {scenario.Type}");
    
    var result = await advancedLoggingWorkflow.ExecuteAsync(kernel, arguments);
    
    var processingTime = result.GetValue<double>("processing_time_ms");
    var iterations = result.GetValue<int>("iterations");
    var logAnalysis = result.GetValue<Dictionary<string, object>>("log_analysis");
    
    Console.WriteLine($"   Processing Time: {processingTime:F2} ms");
    Console.WriteLine($"   Iterations: {iterations:N0}");
    Console.WriteLine($"   Insights Generated: {logAnalysis.Count}");
    Console.WriteLine();
}
```

### 3. 錯誤日誌和監控

展示如何實現全面的錯誤日誌和監控。

```csharp
// 建立錯誤日誌工作流程
var errorLoggingWorkflow = new GraphExecutor("ErrorLoggingWorkflow", "Error logging and monitoring", logger);

// 配置錯誤日誌
var errorLoggingOptions = new GraphLoggingOptions
{
    EnableStructuredLogging = true,
    EnableExecutionLogging = true,
    EnableNodeLogging = true,
    EnableErrorLogging = true,
    EnableErrorAggregation = true,
    EnableErrorCorrelation = true,
    EnableErrorReporting = true,
    LogLevel = LogLevel.Warning,
    LogStoragePath = "./error-logs",
    ErrorLogRetention = TimeSpan.FromDays(30),
    EnableErrorMetrics = true
};

errorLoggingWorkflow.ConfigureLogging(errorLoggingOptions);

// 容易出錯的處理節點
var errorProneProcessor = new FunctionGraphNode(
    "error-prone-processor",
    "Process data with potential errors",
    async (context) =>
    {
        var inputData = context.GetValue<string>("input_data");
        var errorProbability = context.GetValue<double>("error_probability", 0.3);
        var startTime = DateTime.UtcNow;
        
        try
        {
            // 日誌處理開始
            context.Logger.LogInformation("Error-prone processing started", new
            {
                NodeId = "error-prone-processor",
                InputData = inputData,
                ErrorProbability = errorProbability,
                StartTime = startTime,
                ExecutionId = context.ExecutionId
            });
            
            // 模擬可能出錯的處理
            var random = Random.Shared.NextDouble();
            if (random < errorProbability)
            {
                // 模擬錯誤
                var errorMessage = $"Processing failed for input: {inputData}";
                var exception = new InvalidOperationException(errorMessage);
                
                // 帶上下文記錄錯誤
                context.Logger.LogError(exception, "Processing error occurred", new
                {
                    NodeId = "error-prone-processor",
                    InputData = inputData,
                    ErrorType = exception.GetType().Name,
                    ErrorMessage = errorMessage,
                    ErrorProbability = errorProbability,
                    RandomValue = random,
                    ProcessingTimeMs = (DateTime.UtcNow - startTime).TotalMilliseconds,
                    ExecutionId = context.ExecutionId,
                    Context = new
                    {
                        UserId = context.GetValue<string>("user_id", "anonymous"),
                        SessionId = context.GetValue<string>("session_id", "default"),
                        RequestId = context.GetValue<string>("request_id", Guid.NewGuid().ToString())
                    }
                });
                
                // 設置錯誤狀態
                context.SetValue("error_occurred", true);
                context.SetValue("error_message", errorMessage);
                context.SetValue("error_type", exception.GetType().Name);
                context.SetValue("processing_step", "error_logged");
                
                throw exception;
            }
            
            // 成功處理
            await Task.Delay(Random.Shared.Next(100, 300));
            var processedData = $"Successfully processed: {inputData}";
            var processingTime = DateTime.UtcNow - startTime;
            
            // 日誌成功
            context.Logger.LogInformation("Processing completed successfully", new
            {
                NodeId = "error-prone-processor",
                InputData = inputData,
                ProcessedData = processedData,
                ProcessingTimeMs = processingTime.TotalMilliseconds,
                ErrorProbability = errorProbability,
                RandomValue = random,
                ExecutionId = context.ExecutionId
            });
            
            context.SetValue("processed_data", processedData);
            context.SetValue("processing_time_ms", processingTime.TotalMilliseconds);
            context.SetValue("error_occurred", false);
            context.SetValue("processing_step", "success_logged");
            
            return processedData;
        }
        catch (Exception ex)
        {
            // 未處理例外的額外錯誤日誌
            context.Logger.LogCritical(ex, "Unhandled exception in error-prone processor", new
            {
                NodeId = "error-prone-processor",
                InputData = inputData,
                ExceptionType = ex.GetType().Name,
                ExceptionMessage = ex.Message,
                StackTrace = ex.StackTrace,
                ExecutionId = context.ExecutionId
            });
            
            throw;
        }
    });

// 錯誤監控和聚合器
var errorMonitor = new FunctionGraphNode(
    "error-monitor",
    "Monitor and aggregate error logs",
    async (context) =>
    {
        var errorOccurred = context.GetValue<bool>("error_occurred", false);
        var errorMessage = context.GetValue<string>("error_message", "");
        var errorType = context.GetValue<string>("error_type", "");
        var processingTime = context.GetValue<double>("processing_time_ms", 0.0);
        
        // 聚合錯誤信息
        var errorSummary = new Dictionary<string, object>
        {
            ["error_summary"] = new
            {
                ErrorOccurred = errorOccurred,
                ErrorMessage = errorMessage,
                ErrorType = errorType,
                ProcessingTimeMs = processingTime,
                Timestamp = DateTime.UtcNow
            },
            ["execution_metrics"] = new
            {
                TotalExecutions = 1,
                SuccessfulExecutions = errorOccurred ? 0 : 1,
                FailedExecutions = errorOccurred ? 1 : 0,
                SuccessRate = errorOccurred ? 0.0 : 1.0,
                AverageProcessingTime = processingTime
            },
            ["monitoring_data"] = new
            {
                ExecutionId = context.ExecutionId,
                NodeId = "error-prone-processor",
                MonitoringTimestamp = DateTime.UtcNow,
                AlertLevel = errorOccurred ? "warning" : "info"
            }
        };
        
        context.SetValue("error_summary", errorSummary);
        
        // 日誌監控結果
        if (errorOccurred)
        {
            context.Logger.LogWarning("Error monitoring alert", errorSummary);
        }
        else
        {
            context.Logger.LogInformation("Error monitoring completed", errorSummary);
        }
        
        return $"Error monitoring completed. Errors: {(errorOccurred ? 1 : 0)}";
    });

// 將節點添加到錯誤工作流程
errorLoggingWorkflow.AddNode(errorProneProcessor);
errorLoggingWorkflow.AddNode(errorMonitor);

// 設置起始節點
errorLoggingWorkflow.SetStartNode(errorProneProcessor.NodeId);

// 測試錯誤日誌
var errorTestScenarios = new[]
{
    new { Data = "Low error probability", Probability = 0.1 },
    new { Data = "Medium error probability", Probability = 0.5 },
    new { Data = "High error probability", Probability = 0.8 }
};

foreach (var scenario in errorTestScenarios)
{
    var arguments = new KernelArguments
    {
        ["input_data"] = scenario.Data,
        ["error_probability"] = scenario.Probability,
        ["user_id"] = "user123",
        ["session_id"] = "session456",
        ["request_id"] = Guid.NewGuid().ToString()
    };

    Console.WriteLine($"⚠️ Testing error logging: {scenario.Data}");
    Console.WriteLine($"   Error Probability: {scenario.Probability:P0}");
    
    try
    {
        var result = await errorLoggingWorkflow.ExecuteAsync(kernel, arguments);
        
        var errorOccurred = result.GetValue<bool>("error_occurred");
        var processingStep = result.GetValue<string>("processing_step");
        var errorSummary = result.GetValue<Dictionary<string, object>>("error_summary");
        
        Console.WriteLine($"   Error Occurred: {errorOccurred}");
        Console.WriteLine($"   Processing Step: {processingStep}");
        Console.WriteLine($"   Monitoring Data: {errorSummary.Count} metrics");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"   Exception Caught: {ex.GetType().Name}: {ex.Message}");
    }
    
    Console.WriteLine();
}
```

### 4. 日誌匯出和整合

展示將日誌匯出到外部系統並與監控平台整合。

```csharp
// 建立日誌匯出工作流程
var logExportWorkflow = new GraphExecutor("LogExportWorkflow", "Log export and integration", logger);

// 配置日誌匯出
var logExportOptions = new GraphLoggingOptions
{
    EnableStructuredLogging = true,
    EnableExecutionLogging = true,
    EnableNodeLogging = true,
    EnableLogExport = true,
    EnableLogPersistence = true,
    EnableLogCompression = true,
    LogStoragePath = "./export-logs",
    ExportFormats = new[] { "json", "csv", "logstash", "fluentd" },
    ExportInterval = TimeSpan.FromSeconds(5),
    EnableLogRotation = true,
    MaxLogFileSize = 10 * 1024 * 1024, // 10MB
    LogRetentionDays = 7
};

logExportWorkflow.ConfigureLogging(logExportOptions);

// 日誌生成器
var logGenerator = new FunctionGraphNode(
    "log-generator",
    "Generate sample logs for export",
    async (context) =>
    {
        var iteration = context.GetValue<int>("iteration", 0);
        var logCount = context.GetValue<int>("log_count", 10);
        
        // 生成各種日誌類型
        var logs = new List<Dictionary<string, object>>();
        
        for (int i = 0; i < logCount; i++)
        {
            var logEntry = new Dictionary<string, object>
            {
                ["timestamp"] = DateTime.UtcNow.AddSeconds(-i),
                ["level"] = GetRandomLogLevel(),
                ["message"] = $"Sample log message {iteration}-{i}",
                ["node_id"] = "log-generator",
                ["execution_id"] = context.ExecutionId,
                ["iteration"] = iteration,
                ["log_index"] = i,
                ["metadata"] = new
                {
                    Source = "log-generator",
                    Version = "1.0.0",
                    Environment = "development"
                }
            };
            
            logs.Add(logEntry);
        }
        
        context.SetValue("generated_logs", logs);
        context.SetValue("log_count", logs.Count);
        context.SetValue("generation_timestamp", DateTime.UtcNow);
        
        // 日誌生成完成
        context.Logger.LogInformation("Log generation completed", new
        {
            NodeId = "log-generator",
            LogCount = logs.Count,
            Iteration = iteration,
            ExecutionId = context.ExecutionId
        });
        
        return $"Generated {logs.Count} log entries for iteration {iteration}";
    });

// 日誌匯出器
var logExporter = new FunctionGraphNode(
    "log-exporter",
    "Export logs to external systems",
    async (context) =>
    {
        var generatedLogs = context.GetValue<List<Dictionary<string, object>>>("generated_logs");
        var iteration = context.GetValue<int>("iteration");
        var generationTimestamp = context.GetValue<DateTime>("generation_timestamp");
        
        // 匯出到不同格式
        var exportResults = new Dictionary<string, string>();
        
        // JSON 匯出
        var jsonExport = await ExportLogsToJson(generatedLogs);
        exportResults["json"] = jsonExport;
        
        // CSV 匯出
        var csvExport = await ExportLogsToCsv(generatedLogs);
        exportResults["csv"] = csvExport;
        
        // Logstash 匯出
        var logstashExport = await ExportLogsToLogstash(generatedLogs);
        exportResults["logstash"] = logstashExport;
        
        // Fluentd 匯出
        var fluentdExport = await ExportLogsToFluentd(generatedLogs);
        exportResults["fluentd"] = fluentdExport;
        
        // 匯出到監控系統
        var monitoringExport = await ExportLogsToMonitoring(generatedLogs);
        exportResults["monitoring"] = monitoringExport;
        
        // 建立匯出摘要
        var exportSummary = new Dictionary<string, object>
        {
            ["export_summary"] = new
            {
                TotalLogs = generatedLogs.Count,
                ExportFormats = exportResults.Count,
                ExportFormatsList = exportResults.Keys.ToArray(),
                Iteration = iteration,
                GenerationTimestamp = generationTimestamp,
                ExportTimestamp = DateTime.UtcNow
            },
            ["export_results"] = exportResults,
            ["export_metadata"] = new
            {
                ExportPath = "./export-logs",
                CompressionEnabled = true,
                RotationEnabled = true,
                RetentionDays = 7
            }
        };
        
        context.SetValue("export_summary", exportSummary);
        
        // 日誌匯出完成
        context.Logger.LogInformation("Log export completed", exportSummary);
        
        return $"Logs exported to {exportResults.Count} formats";
    });

// 將節點添加到匯出工作流程
logExportWorkflow.AddNode(logGenerator);
logExportWorkflow.AddNode(logExporter);

// 設置起始節點
logExportWorkflow.SetStartNode(logGenerator.NodeId);

// 測試日誌匯出
Console.WriteLine("📤 Testing log export and integration...");

var exportArguments = new KernelArguments
{
    ["iteration"] = 1,
    ["log_count"] = 25
};

var result = await logExportWorkflow.ExecuteAsync(kernel, exportArguments);

var exportSummary = result.GetValue<Dictionary<string, object>>("export_summary");
var generatedLogs = result.GetValue<List<Dictionary<string, object>>>("generated_logs");

if (exportSummary != null)
{
    var summary = exportSummary["export_summary"] as dynamic;
    Console.WriteLine($"   Total Logs: {summary.TotalLogs}");
    Console.WriteLine($"   Export Formats: {string.Join(", ", summary.ExportFormatsList)}");
    Console.WriteLine($"   Export Path: {exportSummary["export_metadata"].ExportPath}");
}

Console.WriteLine("✅ Log export testing completed");

// 日誌匯出的輔助方法
async Task<string> ExportLogsToJson(List<Dictionary<string, object>> logs)
{
    var json = System.Text.Json.JsonSerializer.Serialize(logs, new System.Text.Json.JsonSerializerOptions
    {
        WriteIndented = true
    });
    
    var filename = $"./export-logs/logs_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json";
    await File.WriteAllTextAsync(filename, json);
    
    return filename;
}

async Task<string> ExportLogsToCsv(List<Dictionary<string, object>> logs)
{
    var csv = new StringBuilder();
    
    if (logs.Any())
    {
        // 標題
        var headers = logs.First().Keys;
        csv.AppendLine(string.Join(",", headers));
        
        // 數據
        foreach (var log in logs)
        {
            var values = headers.Select(h => log[h]?.ToString() ?? "").Select(v => $"\"{v}\"");
            csv.AppendLine(string.Join(",", values));
        }
    }
    
    var filename = $"./export-logs/logs_{DateTime.UtcNow:yyyyMMdd_HHmmss}.csv";
    await File.WriteAllTextAsync(filename, csv.ToString());
    
    return filename;
}

async Task<string> ExportLogsToLogstash(List<Dictionary<string, object>> logs)
{
    var logstashFormat = new StringBuilder();
    
    foreach (var log in logs)
    {
        var logstashEntry = new
        {
            @timestamp = log["timestamp"],
            level = log["level"],
            message = log["message"],
            node_id = log["node_id"],
            execution_id = log["execution_id"],
            metadata = log["metadata"]
        };
        
        logstashFormat.AppendLine(System.Text.Json.JsonSerializer.Serialize(logstashEntry));
    }
    
    var filename = $"./export-logs/logs_{DateTime.UtcNow:yyyyMMdd_HHmmss}.logstash";
    await File.WriteAllTextAsync(filename, logstashFormat.ToString());
    
    return filename;
}

async Task<string> ExportLogsToFluentd(List<Dictionary<string, object>> logs)
{
    var fluentdFormat = new StringBuilder();
    
    foreach (var log in logs)
    {
        var fluentdEntry = new
        {
            time = log["timestamp"],
            level = log["level"],
            message = log["message"],
            node_id = log["node_id"],
            execution_id = log["execution_id"],
            metadata = log["metadata"]
        };
        
        fluentdFormat.AppendLine(System.Text.Json.JsonSerializer.Serialize(fluentdEntry));
    }
    
    var filename = $"./export-logs/logs_{DateTime.UtcNow:yyyyMMdd_HHmmss}.fluentd";
    await File.WriteAllTextAsync(filename, fluentdFormat.ToString());
    
    return filename;
}

async Task<string> ExportLogsToMonitoring(List<Dictionary<string, object>> logs)
{
    // 模擬匯出到監控系統
    var monitoringData = new
    {
        source = "semantic-kernel-graph",
        timestamp = DateTime.UtcNow,
        log_count = logs.Count,
        log_levels = logs.GroupBy(l => l["level"]).ToDictionary(g => g.Key, g => g.Count()),
        execution_ids = logs.Select(l => l["execution_id"]).Distinct().ToArray()
    };
    
    var filename = $"./export-logs/monitoring_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json";
    await File.WriteAllTextAsync(filename, System.Text.Json.JsonSerializer.Serialize(monitoringData, new System.Text.Json.JsonSerializerOptions
    {
        WriteIndented = true
    }));
    
    return filename;
}

string GetRandomLogLevel()
{
    var levels = new[] { "Debug", "Information", "Warning", "Error" };
    var weights = new[] { 0.4, 0.4, 0.15, 0.05 }; // 40% Debug、40% Info、15% Warning、5% Error
    
    var random = Random.Shared.NextDouble();
    var cumulativeWeight = 0.0;
    
    for (int i = 0; i < levels.Length; i++)
    {
        cumulativeWeight += weights[i];
        if (random <= cumulativeWeight)
        {
            return levels[i];
        }
    }
    
    return levels[0];
}
```

## 預期輸出

### 基本日誌配置範例

```
📝 Testing basic logging: Sample data 1
   Processing Time: 234.56 ms
   Logs Generated: 2

📝 Testing basic logging: Sample data 2
   Processing Time: 187.23 ms
   Logs Generated: 2
```

### 進階結構化日誌範例

```
🔍 Testing advanced logging: Simple processing
   Processing Type: simple
   Processing Time: 156.78 ms
   Iterations: 100
   Insights Generated: 4

🔍 Testing advanced logging: Complex processing
   Processing Type: complex
   Processing Time: 1,234.56 ms
   Iterations: 1,000
   Insights Generated: 4
```

### 錯誤日誌和監控範例

```
⚠️ Testing error logging: Low error probability
   Error Probability: 10%
   Error Occurred: False
   Processing Step: success_logged
   Monitoring Data: 3 metrics

⚠️ Testing error logging: High error probability
   Error Probability: 80%
   Error Occurred: True
   Processing Step: error_logged
   Monitoring Data: 3 metrics
```

### 日誌匯出和整合範例

```
📤 Testing log export and integration...
   Total Logs: 25
   Export Formats: json, csv, logstash, fluentd, monitoring
   Export Path: ./export-logs
✅ Log export testing completed
```

## 配置選項

### 日誌配置

```csharp
var loggingOptions = new GraphLoggingOptions
{
    EnableStructuredLogging = true,                    // 啟用結構化日誌
    EnableExecutionLogging = true,                     // 啟用執行級日誌
    EnableNodeLogging = true,                          // 啟用節點級日誌
    EnablePerformanceLogging = true,                   // 啟用性能日誌
    EnableErrorLogging = true,                         // 啟用錯誤日誌
    EnableErrorAggregation = true,                     // 啟用錯誤聚合
    EnableErrorCorrelation = true,                     // 啟用錯誤關聯
    EnableErrorReporting = true,                       // 啟用錯誤報告
    EnableSemanticLogging = true,                      // 啟用語義日誌
    EnableContextLogging = true,                       // 啟用上下文日誌
    EnableLogCorrelation = true,                       // 啟用日誌關聯
    EnableLogAggregation = true,                       // 啟用日誌聚合
    EnableLogExport = true,                            // 啟用日誌匯出
    EnableLogPersistence = true,                       // 啟用日誌持久化
    EnableLogCompression = true,                       // 啟用日誌壓縮
    EnableLogRotation = true,                          // 啟用日誌輪換
    EnableErrorMetrics = true,                         // 啟用錯誤指標
    LogLevel = LogLevel.Information,                   // 預設日誌級別
    StructuredLogFormat = "json",                      // 結構化日誌格式
    LogStoragePath = "./logs",                         // 日誌儲存路徑
    ExportFormats = new[] { "json", "csv", "logstash", "fluentd" }, // 匯出格式
    ExportInterval = TimeSpan.FromSeconds(5),          // 匯出間隔
    MaxLogFileSize = 10 * 1024 * 1024,                // 最大日誌文件大小 (10MB)
    LogRetentionDays = 7,                              // 日誌保留期限
    ErrorLogRetention = TimeSpan.FromDays(30),         // 錯誤日誌保留期限
    MaxLogHistory = 10000,                             // 最大日誌歷史
    EnableLogCompression = true,                       // 啟用日誌壓縮
    CompressionLevel = System.IO.Compression.CompressionLevel.Optimal // 壓縮級別
};
```

### 錯誤日誌配置

```csharp
var errorLoggingOptions = new ErrorLoggingOptions
{
    EnableErrorAggregation = true,                     // 啟用錯誤聚合
    EnableErrorCorrelation = true,                     // 啟用錯誤關聯
    EnableErrorReporting = true,                       // 啟用錯誤報告
    EnableErrorMetrics = true,                         // 啟用錯誤指標
    EnableErrorAlerts = true,                          // 啟用錯誤警報
    EnableErrorTrends = true,                          // 啟用錯誤趨勢分析
    ErrorLogRetention = TimeSpan.FromDays(30),         // 錯誤日誌保留期限
    MaxErrorHistory = 1000,                            // 最大錯誤歷史
    ErrorAlertThreshold = 5,                           // 錯誤警報閾值
    ErrorAlertWindow = TimeSpan.FromMinutes(5),        // 錯誤警報窗口
    EnableErrorSampling = true,                        // 啟用錯誤採樣
    ErrorSamplingRate = 0.1,                           // 錯誤採樣率 (10%)
    EnableErrorDeduplication = true,                   // 啟用錯誤去重
    ErrorDeduplicationWindow = TimeSpan.FromMinutes(10) // 錯誤去重窗口
};
```

## 故障排除

### 常見問題

#### 未生成日誌
```bash
# 問題：未生成日誌
# 解決方案：檢查日誌配置並啟用所需功能
EnableStructuredLogging = true;
EnableExecutionLogging = true;
LogLevel = LogLevel.Information;
```

#### 性能影響
```bash
# 問題：日誌記錄影響性能
# 解決方案：調整日誌級別並啟用壓縮
LogLevel = LogLevel.Warning;
EnableLogCompression = true;
EnableLogSampling = true;
```

#### 儲存問題
```bash
# 問題：日誌消耗大量儲存空間
# 解決方案：啟用輪換並設置保留政策
EnableLogRotation = true;
MaxLogFileSize = 5 * 1024 * 1024; // 5MB
LogRetentionDays = 3;
```

### 調試模式

啟用詳細日誌記錄以進行故障排除：

```csharp
// 啟用調試日誌
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<LoggingExample>();

// 使用調試日誌配置日誌
var debugLoggingOptions = new GraphLoggingOptions
{
    EnableStructuredLogging = true,
    EnableExecutionLogging = true,
    EnableNodeLogging = true,
    EnableDebugLogging = true,
    LogLevel = LogLevel.Debug,
    LogVisualizationUpdates = true,
    LogExportOperations = true
};
```

## 進階模式

### 自訂日誌格式化程式

```csharp
// 實現自訂日誌格式化程式
public class CustomLogFormatter : ILogFormatter
{
    public async Task<string> FormatLogAsync(LogEntry entry, Dictionary<string, object> context)
    {
        var customFormat = new StringBuilder();
        
        // 自訂標題
        customFormat.AppendLine("=== CUSTOM LOG ENTRY ===");
        customFormat.AppendLine($"Timestamp: {entry.Timestamp:yyyy-MM-dd HH:mm:ss.fff}");
        customFormat.AppendLine($"Level: {entry.Level}");
        customFormat.AppendLine($"Message: {entry.Message}");
        customFormat.AppendLine($"Node: {entry.NodeId}");
        customFormat.AppendLine($"Execution: {entry.ExecutionId}");
        
        // 自訂上下文格式化
        if (context.Any())
        {
            customFormat.AppendLine("Context:");
            foreach (var kvp in context)
            {
                customFormat.AppendLine($"  {kvp.Key}: {kvp.Value}");
            }
        }
        
        customFormat.AppendLine("========================");
        
        return customFormat.ToString();
    }
}
```

### 自訂日誌聚合器

```csharp
// 實現自訂日誌聚合器
public class CustomLogAggregator : ILogAggregator
{
    public async Task<LogAggregationResult> AggregateLogsAsync(IEnumerable<LogEntry> logs)
    {
        var aggregation = new LogAggregationResult();
        
        foreach (var log in logs)
        {
            // 按級別聚合
            if (!aggregation.LevelCounts.ContainsKey(log.Level))
                aggregation.LevelCounts[log.Level] = 0;
            aggregation.LevelCounts[log.Level]++;
            
            // 按節點聚合
            if (!aggregation.NodeCounts.ContainsKey(log.NodeId))
                aggregation.NodeCounts[log.NodeId] = 0;
            aggregation.NodeCounts[log.NodeId]++;
            
            // 追蹤執行模式
            if (!aggregation.ExecutionPatterns.ContainsKey(log.ExecutionId))
                aggregation.ExecutionPatterns[log.ExecutionId] = new List<LogEntry>();
            aggregation.ExecutionPatterns[log.ExecutionId].Add(log);
        }
        
        // 計算衍生指標
        aggregation.TotalLogs = logs.Count();
        aggregation.AverageLogsPerExecution = aggregation.ExecutionPatterns.Count > 0 
            ? (double)aggregation.TotalLogs / aggregation.ExecutionPatterns.Count 
            : 0;
        
        return aggregation;
    }
}
```

### 即時日誌監控

```csharp
// 實現即時日誌監控
public class RealTimeLogMonitor : ILogMonitor
{
    private readonly List<LogEntry> _recentLogs = new();
    private readonly object _lock = new();
    
    public async Task MonitorLogAsync(LogEntry entry)
    {
        lock (_lock)
        {
            _recentLogs.Add(entry);
            
            // 僅保留最近的日誌 (最後 1000 條)
            if (_recentLogs.Count > 1000)
            {
                _recentLogs.RemoveRange(0, _recentLogs.Count - 1000);
            }
        }
        
        // 檢查警報
        await CheckAlertsAsync(entry);
    }
    
    private async Task CheckAlertsAsync(LogEntry entry)
    {
        // 檢查錯誤率警報
        var recentErrors = _recentLogs
            .Where(l => l.Level == LogLevel.Error)
            .Where(l => l.Timestamp > DateTime.UtcNow.AddMinutes(-5))
            .Count();
        
        if (recentErrors > 10)
        {
            await SendAlertAsync($"High error rate detected: {recentErrors} errors in last 5 minutes");
        }
        
        // 檢查特定錯誤模式
        if (entry.Level == LogLevel.Error && entry.Message.Contains("critical"))
        {
            await SendAlertAsync($"Critical error detected: {entry.Message}");
        }
    }
    
    private async Task SendAlertAsync(string message)
    {
        // 警報發送實現
        Console.WriteLine($"🚨 ALERT: {message}");
        await Task.CompletedTask;
    }
}
```

## 相關範例

* [圖形指標](./graph-metrics.md)：指標收集和監控
* [圖形可視化](./graph-visualization.md)：日誌的視覺表示
* [調試和檢查](./debug-inspection.md)：使用日誌進行調試
* [性能最佳化](./performance-optimization.md)：基於日誌的性能分析

## 另請參閱

* [日誌記錄和可觀測性](../concepts/logging.md)：了解日誌概念
* [調試和檢查](../how-to/debug-and-inspection.md)：使用日誌進行調試
* [性能監控](../how-to/performance-monitoring.md)：性能日誌記錄
* [API 參考](../api/)：完整的 API 文檔
