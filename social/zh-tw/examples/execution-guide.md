# 範例執行指南

本指南提供了在 Semantic Kernel Graph 套件中使用命令行介面和程式化執行來執行範例的全面說明。

## 快速開始

### 先決條件

1. 已安裝 **.NET 8.0** 或更新版本
2. **OpenAI API 金鑰** 或 **Azure OpenAI** 認證
3. **Semantic Kernel Graph 套件** 依賴項

### 入門

本文件中的範例提供了 Semantic Kernel Graph 套件功能的全面演示。每個範例包括：

* **完整代碼片段**，您可以複製並調整
* **逐步解釋**代碼的運作方式
* **不同場景的設定範例**
* **最佳實踐**和使用模式

瀏覽下面按類別組織的範例，為您的使用案例找到合適的起點。

## 範例分類

這些範例被組織成邏輯類別，以幫助您找到合適的起點：

## 可用的範例

### 核心圖表模式
* `chain-of-thought` - 思維鏈推理模式
* `conditional-nodes` - 使用條件邏輯進行動態路由
* `loop-nodes` - 受控迭代和迴圈管理
* `subgraphs` - 模組化圖表組成和隔離

### 代理模式
* `react-agent` - 推理和行動迴圈
* `react` - 使用 ReAct 進行複雜問題解決
* `memory-agent` - 跨對話的持久記憶
* `retrieval-agent` - 資訊檢索和合成
* `multi-agent` - 協調多代理工作流程

### 進階工作流程
* `advanced-patterns` - 複雜的工作流程組成
* `advanced-routing` - 使用語義相似性進行動態路由
* `dynamic-routing` - 執行時路由決定
* `documents` - 多階段文件處理
* `multihop-rag-retry` - 彈性資訊檢索

### 狀態和持久性
* `checkpointing` - 執行狀態持久化和恢復
* `streaming-execution` - 實時執行監控

### 可觀測性和除錯
* `metrics` - 效能監控和指標收集
* `graph-visualization` - 圖表結構視覺化
* `logging` - 全面的日誌記錄和追蹤

### 整合和擴充
* `plugins` - 動態插件加載和執行
* `rest-api` - 透過 REST 工具進行外部 API 整合
* `assert-suggest` - 驗證和建議模式

### AI 和最佳化
* `optimizers-fewshot` - 提示最佳化和少樣本學習
* `chatbot` - 具有持久上下文的對話 AI

## 設定

### 環境設置

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

設置這些環境變數以進行安全設定：

```bash
# OpenAI
export OPENAI_API_KEY="your-api-key"

# Azure OpenAI
export AZURE_OPENAI_API_KEY="your-azure-key"
export AZURE_OPENAI_ENDPOINT="https://your-resource.openai.azure.com/"
export AZURE_OPENAI_DEPLOYMENT_NAME="your-deployment"
```

### 設定優先級

1. **環境變數**（最高優先級）
2. **appsettings.json** 檔案
3. **預設值**（最低優先級）

## 執行流程

### 1. 程式初始化

```csharp
// 支持圖表的 Kernel 設定
var kernel = await CreateConfiguredKernelAsync();

// Logger factory 設置
using var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Information);
});
```

### 2. 範例登記

範例在字典中登記以進行動態執行：

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

1. **引數解析**：解析命令行引數
2. **範例選擇**：識別要執行的範例
3. **Kernel 設置**：使用圖表支持配置 Semantic Kernel
4. **範例執行**：順序執行選定的範例
5. **結果顯示**：顯示執行結果和統計資訊

## REST API 模式

### 啟動伺服器

```bash
dotnet run -- --rest-api
```

### 可用端點

| 端點 | 方法 | 說明 |
|----------|--------|-------------|
| `/graphs` | GET | 列出已登記的圖表 |
| `/graphs/execute` | POST | 執行特定圖表 |

### API 使用

```bash
# 列出可用的圖表
curl http://localhost:5000/graphs

# 執行圖表
curl -X POST http://localhost:5000/graphs/execute \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{"graphName": "sample-graph", "variables": {"input": "Hello World"}}'
```

### 圖表登記

伺服器啟動時會自動登記圖表：

```csharp
// 使用 KernelFunction API 建立並登記範例圖表
// 建立最小 Kernel 實例（無外部 AI 提供者）以進行本機執行
var kernel = Kernel.CreateBuilder().Build();

// 向 Kernel 登記迴聲函式並取得 KernelFunction 參考
var echoFunction = kernel.CreateFunctionFromMethod(
    (KernelArguments args) =>
    {
        var input = args["input"]?.ToString() ?? string.Empty;
        return $"echo:{input}";
    },
    functionName: "echo",
    description: "Echoes the input string");

// 從 KernelFunction 建立 FunctionGraphNode 並在 GraphExecutor 中登記
var echoNode = new FunctionGraphNode(echoFunction, nodeId: "echo");
var graph = new GraphExecutor("sample-graph", "Simple echo graph");
graph.AddNode(echoNode).SetStartNode("echo");

// 如果有圖表工廠或登記表可用，請登記圖表
// await factory.RegisterAsync(graph);
```

## 進階用法

### 以程式方式執行範例

您也可以從自己的代碼以程式方式執行範例：

```csharp
// 執行特定範例
await ChainOfThoughtExample.RunAsync();
await ChatbotExample.RunAsync();
await CheckpointingExample.RunAsync();

// 使用自訂 kernel 執行
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

### 批量執行

按順序執行多個範例，並使用自訂邏輯：

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

## 故障排除

### 常見問題

#### API 金鑰設定
```bash
# 錯誤：找不到 OpenAI API 金鑰
# 解決方案：設置環境變數或更新 appsettings.json
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

啟用除錯日誌進行故障排除：

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
// 啟用指標收集
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
    # 範例可在文件中取得
    # 使用提供的代碼片段和模式
    echo "Examples available in docs/examples/"
```

### Docker 整合

```dockerfile
# 您的應用程式的 Dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0
WORKDIR /app
COPY . .
RUN dotnet restore
RUN dotnet build
# 使用文件中的範例作為參考
# 根據需要複製並調整代碼片段
```

### 外部工具整合

```bash
# 從外部工具執行範例
semantic-kernel-graph-examples --example chain-of-thought --output json
semantic-kernel-graph-examples --example chatbot --config custom-config.json
```

## 最佳實踐

### 1. 環境管理
* 使用環境變數進行敏感設定
* 為非敏感預設值保留 `appsettings.json`
* 對開發/預演/生產環境使用不同的設定

### 2. 範例選擇
* 從簡單範例開始（chain-of-thought、conditional-nodes）
* 進展到複雜模式（multi-agent、advanced-patterns）
* 瀏覽 [範例索引](./index.md) 以發現可用的範例

### 3. 錯誤處理
* 監控執行日誌中的錯誤
* 使用除錯模式進行故障排除
* 首先檢查 API 金鑰設定
* 參閱 [故障排除指南](../troubleshooting.md) 以了解常見問題

### 4. 效能
* 啟用指標進行效能監控
* 對長時間執行的範例使用適當的逾時
* 監控大型圖表的記憶體使用量

## 相關文件

* [範例索引](./index.md)：可用範例的完整列表
* [入門](../getting-started.md)：快速開始指南
* [安裝](../installation.md)：設置和設定
* [API 參考](../api/)：完整的 API 文件
* [故障排除](../troubleshooting.md)：常見問題和解決方案
