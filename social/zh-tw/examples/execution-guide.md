# 範例執行指南

本指南提供在 Semantic Kernel Graph 套件中使用命令列介面和程式化執行方式來執行範例的完整說明。

## 快速開始

### 先決條件

1. **.NET 8.0** 或更新版本已安裝
2. **OpenAI API 金鑰** 或 **Azure OpenAI** 認證
3. **Semantic Kernel Graph 套件**依賴項

### 開始使用

本文件中的範例提供 Semantic Kernel Graph 套件功能的完整展示。每個範例包括：

* **完整的程式碼片段**，您可以複製並調整
* **逐步說明**，說明程式碼如何工作
* **不同場景的設定範例**
* **最佳實踐**和使用模式

瀏覽下方的按類別組織的範例，以找到適合您用例的正確起點。

## 範例類別

範例組織成邏輯類別，幫助您找到正確的起點：

## 可用的範例

### Core Graph Patterns
* `chain-of-thought` - Chain of Thought 推理模式
* `conditional-nodes` - 使用條件邏輯的動態路由
* `loop-nodes` - 受控迴圈反覆和迴圈管理
* `subgraphs` - 模組化 Graph 組合和隔離

### Agent Patterns
* `react-agent` - ReAct 推理和行動迴圈
* `react` - 使用 ReAct 解決複雜問題
* `memory-agent` - 跨對話的持久記憶
* `retrieval-agent` - 資訊檢索和合成
* `multi-agent` - 協調的多代理工作流

### Advanced Workflows
* `advanced-patterns` - 複雜的工作流組合
* `advanced-routing` - 使用語義相似性的動態路由
* `dynamic-routing` - 執行時路由決策
* `documents` - 多階段文件處理
* `multihop-rag-retry` - 具有恢復能力的資訊檢索

### State and Persistence
* `checkpointing` - 執行狀態持久化和恢復
* `streaming-execution` - 實時執行監控

### Observability and Debugging
* `metrics` - 效能監控和指標集合
* `graph-visualization` - Graph 結構視覺化
* `logging` - 完整的日誌記錄和追蹤

### Integration and Extensions
* `plugins` - 動態外掛載入和執行
* `rest-api` - 透過 REST 工具進行外部 API 整合
* `assert-suggest` - 驗證和建議模式

### AI and Optimization
* `optimizers-fewshot` - 提示優化和少樣本學習
* `chatbot` - 具有持久上下文的對話式 AI

## 設定

### 環境設定

範例使用來自 `appsettings.json` 和環境變數的設定：

```json
{
  "OpenAI": {
    "ApiKey": "your-openai-api-key",
    "Model": "gpt-3.5-turbo",
    "MaxTokens": 4000,
    "Temperature": 0.7
  },
  "AzureOpenAI": {
    "ApiKey": "your-azure-openai-key",
    "Endpoint": "https://your-resource.openai.azure.com/",
    "DeploymentName": "your-deployment-name"
  }
}
```

### 環境變數

設定這些環境變數以進行安全設定：

```bash
# OpenAI
export OPENAI_API_KEY="your-api-key"

# Azure OpenAI
export AZURE_OPENAI_API_KEY="your-azure-key"
export AZURE_OPENAI_ENDPOINT="https://your-resource.openai.azure.com/"
export AZURE_OPENAI_DEPLOYMENT_NAME="your-deployment"
```

### 設定優先順序

1. **環境變數**（最高優先順序）
2. **appsettings.json** 檔案
3. **預設值**（最低優先順序）

## 執行流程

### 1. Program 初始化

```csharp
// 使用 Graph 支援的 Kernel 設定
var kernel = await CreateConfiguredKernelAsync();

// Logger factory 設定
using var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Information);
});
```

### 2. 範例註冊

範例在字典中註冊以供動態執行：

```csharp
var examples = new Dictionary<string, Func<Task>>(StringComparer.OrdinalIgnoreCase)
{
    ["chain-of-thought"] = async () => await ChainOfThoughtExample.RunAsync(),
    ["chatbot"] = async () => await ChatbotExample.RunAsync(),
    ["checkpointing"] = async () => await CheckpointingExample.RunAsync(),
    // ... 更多範例
};
```

### 3. 執行流程

1. **引數解析**：解析命令列引數
2. **範例選擇**：識別要執行的範例
3. **Kernel 設定**：使用 Graph 支援設定 Semantic Kernel
4. **範例執行**：依序執行選定的範例
5. **結果顯示**：顯示執行結果和統計資訊

## REST API 模式

### 啟動伺服器

```bash
dotnet run -- --rest-api
```

### 可用的端點

| 端點 | 方法 | 說明 |
|----------|--------|-------------|
| `/graphs` | GET | 列出已註冊的 Graph |
| `/graphs/execute` | POST | 執行特定 Graph |

### API 使用方式

```bash
# 列出可用的 Graph
curl http://localhost:5000/graphs

# 執行 Graph
curl -X POST http://localhost:5000/graphs/execute \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{"graphName": "sample-graph", "variables": {"input": "Hello World"}}'
```

### Graph 註冊

當伺服器啟動時，Graph 會自動註冊：

```csharp
// 使用 KernelFunction API 建立和註冊範例 Graph
// 建立最小 Kernel 實例（沒有外部 AI 提供者）以供本地執行
var kernel = Kernel.CreateBuilder().Build();

// 使用 Kernel 註冊 echo 功能並取得 KernelFunction 參考
var echoFunction = kernel.CreateFunctionFromMethod(
    (KernelArguments args) =>
    {
        var input = args["input"]?.ToString() ?? string.Empty;
        return $"echo:{input}";
    },
    functionName: "echo",
    description: "Echoes the input string");

// 從 KernelFunction 建立 FunctionGraphNode 並在 GraphExecutor 中註冊
var echoNode = new FunctionGraphNode(echoFunction, nodeId: "echo");
var graph = new GraphExecutor("sample-graph", "Simple echo graph");
graph.AddNode(echoNode).SetStartNode("echo");

// 如果有可用的 Graph factory 或 registry，註冊 Graph
// await factory.RegisterAsync(graph);
```

## 進階使用

### 以程式方式執行範例

您也可以從自己的程式碼以程式方式執行範例：

```csharp
// 執行特定範例
await ChainOfThoughtExample.RunAsync();
await ChatbotExample.RunAsync();
await CheckpointingExample.RunAsync();

// 使用自訂 Kernel 執行
var kernel = CreateCustomKernel();
await ReActAgentExample.RunAsync(kernel);
```

### 自訂設定

修改 `CreateConfiguredKernelAsync()` 方法以自訂：

```csharp
static async Task<Kernel> CreateConfiguredKernelAsync()
{
    var kernelBuilder = Kernel.CreateBuilder()
        .AddOpenAIChatCompletion("gpt-4", "your-api-key")
        .AddGraphSupport(options =>
        {
            options.EnableLogging = true;
            options.EnableMetrics = true;
            options.MaxExecutionSteps = 200;
            options.ExecutionTimeout = TimeSpan.FromMinutes(10);
        })
        .AddGraphMemory()
        .AddGraphTemplates()
        .AddCheckpointSupport(options =>
        {
            options.EnableCompression = true;
            options.MaxCacheSize = 2000;
            options.EnableAutoCleanup = true;
        });

    return kernelBuilder.Build();
}
```

### 批次執行

使用自訂邏輯依序執行多個範例：

```csharp
var examplesToRun = new[] { "chain-of-thought", "chatbot", "checkpointing" };
foreach (var exampleName in examplesToRun)
{
    if (examples.TryGetValue(exampleName, out var run))
    {
        Console.WriteLine($"Running: {exampleName}");
        await run();
        Console.WriteLine($"Completed: {exampleName}");
    }
}
```

## 疑難排解

### 常見問題

#### API 金鑰設定
```bash
# 錯誤：找不到 OpenAI API 金鑰
# 解決方案：設定環境變數或更新 appsettings.json
export OPENAI_API_KEY="your-actual-api-key"
```

#### 套件依賴項
```bash
# 錯誤：找不到套件
# 解決方案：還原套件
dotnet restore
```

#### 記憶體問題
```bash
# 錯誤：記憶體不足
# 解決方案：增加記憶體限制
export DOTNET_GCHeapHardLimit=0x40000000
```

#### 逾時問題
```bash
# 錯誤：執行逾時
# 解決方案：在設定中增加逾時
{
  "GraphSettings": {
    "DefaultTimeout": "00:15:00"
  }
}
```

### 除錯模式

啟用除錯記錄以進行疑難排解：

```json
{
  "Logging": {
    "LogLevel": {
      "SemanticKernel.Graph": "Debug"
    }
  },
  "GraphSettings": {
    "EnableDebugMode": true
  }
}
```

### 效能監控

使用指標監控執行效能：

```csharp
// 啟用指標集合
kernelBuilder.AddGraphSupport(options =>
{
    options.EnableMetrics = true;
    options.EnableProfiling = true;
});
```

## 整合範例

### CI/CD 整合

```yaml
# GitHub Actions 範例
* name: Run Examples
  run: |
    # Examples 可在文件中取得
    # 使用提供的程式碼片段和模式
    echo "Examples available in docs/examples/"
```

### Docker 整合

```dockerfile
# 您應用程式的 Dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0
WORKDIR /app
COPY . .
RUN dotnet restore
RUN dotnet build
# 使用文件中的範例作為參考
# 根據需要複製和調整程式碼片段
```

### 外部工具整合

```bash
# 從外部工具執行範例
semantic-kernel-graph-examples --example chain-of-thought --output json
semantic-kernel-graph-examples --example chatbot --config custom-config.json
```

## 最佳實踐

### 1. 環境管理
* 針對敏感設定使用環境變數
* 在 `appsettings.json` 中保留非敏感預設值
* 為開發/預備/生產使用不同的設定

### 2. 範例選擇
* 從簡單的範例開始（chain-of-thought、conditional-nodes）
* 進展到複雜模式（multi-agent、advanced-patterns）
* 瀏覽 [範例索引](./index.md) 以探索可用的範例

### 3. 錯誤處理
* 監控執行日誌中的錯誤
* 使用除錯模式進行疑難排解
* 首先檢查 API 金鑰設定
* 參考 [疑難排解指南](../troubleshooting.md) 以了解常見問題

### 4. 效能
* 啟用指標以進行效能監控
* 為長時間執行的範例使用適當的逾時
* 監控大型 Graph 的記憶體使用情況

## 相關文件

* [範例索引](./index.md)：可用範例的完整清單
* [開始使用](../getting-started.md)：快速開始指南
* [安裝](../installation.md)：設定和組態
* [API 參考](../api/)：完整的 API 文件
* [疑難排解](../troubleshooting.md)：常見問題和解決方案
