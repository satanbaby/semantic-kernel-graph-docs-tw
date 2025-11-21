# 安裝指南

本指南將幫助你在 .NET 專案中安裝並配置 SemanticKernel.Graph。你將學習如何新增套件、配置環境，以及設定基本要求。

## 前置條件

在安裝 SemanticKernel.Graph 之前，請確保你已具備以下條件：

* **.NET 8.0** 或更新版本安裝在系統上
* **Visual Studio 2022**（17.8+）或 **VS Code**（含 C# 擴充功能）
* **Semantic Kernel** 套件已安裝在你的專案中
* **LLM Provider API Key**（OpenAI、Azure OpenAI 或其他支援的提供商）

### .NET 版本檢查

執行以下指令驗證你的 .NET 版本：

```bash
dotnet --version
```

你應該會看到 8.0.0 或更高的版本。如果沒有，請從 [Microsoft 官方網站](https://dotnet.microsoft.com/download) 下載並安裝最新的 .NET 8 SDK。

## 套件安裝

SemanticKernel.Graph 現已在 NuGet 上提供！你可以使用以下方法安裝它：

### 使用 dotnet CLI（推薦）

```bash
dotnet add package SemanticKernel.Graph
```

### 使用 PackageReference

將以下內容新增至你的 `.csproj` 檔案：

```xml
<ItemGroup>
    <PackageReference Include="SemanticKernel.Graph" Version="25.8.191" />
</ItemGroup>
```

### 使用 Package Manager Console

```
Install-Package SemanticKernel.Graph
```

## 環境配置

### LLM Provider 設定

SemanticKernel.Graph 需要配置的 LLM 提供商。以下是最常見的設定方式：

#### OpenAI 配置

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"
setx OPENAI_MODEL_NAME "gpt-4"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
export OPENAI_MODEL_NAME="gpt-4"
```

```csharp
// 在你的程式碼中
var builder = Kernel.CreateBuilder();
builder.AddOpenAIChatCompletion(
    modelId: Environment.GetEnvironmentVariable("OPENAI_MODEL_NAME") ?? "gpt-4",
    apiKey: Environment.GetEnvironmentVariable("OPENAI_API_KEY") ?? throw new InvalidOperationException("OPENAI_API_KEY not found")
);
```

#### Azure OpenAI 配置

```bash
# Windows
setx AZURE_OPENAI_ENDPOINT "https://your-resource.openai.azure.com/"
setx AZURE_OPENAI_API_KEY "your-api-key-here"
setx AZURE_OPENAI_DEPLOYMENT_NAME "your-deployment-name"

# macOS/Linux
export AZURE_OPENAI_ENDPOINT="https://your-resource.openai.azure.com/"
export AZURE_OPENAI_API_KEY="your-api-key-here"
export AZURE_OPENAI_DEPLOYMENT_NAME="your-deployment-name"
```

```csharp
// 在你的程式碼中
var builder = Kernel.CreateBuilder();
builder.AddAzureOpenAIChatCompletion(
    deploymentName: Environment.GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT_NAME") ?? throw new InvalidOperationException("AZURE_OPENAI_DEPLOYMENT_NAME not found"),
    endpoint: Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT") ?? throw new InvalidOperationException("AZURE_OPENAI_ENDPOINT not found"),
    apiKey: Environment.GetEnvironmentVariable("AZURE_OPENAI_API_KEY") ?? throw new InvalidOperationException("AZURE_OPENAI_API_KEY not found")
);
```

#### 設定檔案設定

針對本地開發，你可以使用 `appsettings.json`（記得將它新增到 `.gitignore`）：

```json
{
  "OpenAI": {
    "ApiKey": "your-api-key-here",
    "Model": "gpt-4",
    "MaxTokens": 4000,
    "Temperature": 0.7
  },
  "AzureOpenAI": {
    "ApiKey": "your-azure-api-key",
    "Endpoint": "https://your-resource.openai.azure.com/",
    "DeploymentName": "your-deployment",
    "Model": "GPT4o",
    "MaxTokens": 4000,
    "Temperature": 0.7
  }
}
```

然後在應用程式中載入它：

```csharp
// 從 appsettings.json 載入配置
var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables()
    .Build();

var builder = Kernel.CreateBuilder();
builder.AddOpenAIChatCompletion(
    modelId: configuration["OpenAI:Model"] ?? "gpt-4",
    apiKey: configuration["OpenAI:ApiKey"] ?? throw new InvalidOperationException("OpenAI:ApiKey not found")
);
```

## 基本專案設定

### 1. 建立新的 .NET 專案

```bash
dotnet new console -n MyGraphApp
cd MyGraphApp
```

### 2. 新增必要的套件

```bash
dotnet add package Microsoft.SemanticKernel
dotnet add package Microsoft.Extensions.Configuration
dotnet add package Microsoft.Extensions.Configuration.Json
dotnet add package Microsoft.Extensions.Configuration.EnvironmentVariables
```

### 3. 新增 SemanticKernel.Graph 套件

```bash
dotnet add package SemanticKernel.Graph
```

這將自動將套件參考新增至你的 `.csproj` 檔案。

### 4. 基本配置

```csharp
using Microsoft.SemanticKernel;
using Microsoft.Extensions.Configuration;
using SemanticKernel.Graph.Extensions;

var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables()
    .Build();

var builder = Kernel.CreateBuilder();

// 配置你的 LLM 提供商
builder.AddOpenAIChatCompletion(
    "gpt-4", 
    configuration["OpenAI:ApiKey"] ?? Environment.GetEnvironmentVariable("OPENAI_API_KEY")
);

// 啟用 Graph 功能
builder.AddGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMetrics = true;
});

var kernel = builder.Build();
```

## 進階配置

### Graph 選項

你可以使用各種選項自訂 Graph 行為：

```csharp
builder.AddGraphSupport(options =>
{
    // 啟用日誌記錄
    options.EnableLogging = true;
    
    // 啟用效能指標
    options.EnableMetrics = true;
    
    // 配置執行限制
    options.MaxExecutionSteps = 100;
    options.ExecutionTimeout = TimeSpan.FromMinutes(5);
});

// 新增其他 Graph 功能
builder.AddGraphMemory()
    .AddGraphTemplates()
    .AddCheckpointSupport(options =>
    {
        options.EnableCompression = true;
        options.MaxCacheSize = 1000;
        options.EnableAutoCleanup = true;
        options.AutoCleanupInterval = TimeSpan.FromHours(1);
    });
```

### 依賴注入設定

針對 ASP.NET Core 應用程式，SemanticKernel.Graph 可與 DI 容器無縫整合：

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// 新增 Semantic Kernel 並支援 Graph
builder.Services.AddKernel(options =>
{
    options.AddOpenAIChatCompletion("gpt-4", builder.Configuration["OpenAI:ApiKey"]);
    options.AddGraphSupport();
});

var app = builder.Build();
```

**注意**：此示例需要 ASP.NET Core 執行階段和 `Microsoft.AspNetCore.App` 架構參考。如果你在建置主控台應用程式，可以改用上面的基本配置示例。

## 執行示例

此專案包含展示各種功能的全面示例：

### 1. 探索示例

文件在 [examples/](examples/) 目錄中包含全面示例：

* **基本模式**：簡單的工作流和 Node 類型
* **進階路由**：動態執行路徑和條件邏輯
* **多代理**：協調的 AI 代理工作流
* **企業**：具備監控和恢復力的生產就緒模式

### 2. 遵循教程

每個示例包括：
* 你可以複製和調整的完整程式碼片段
* 程式碼如何運作的逐步說明
* 不同場景的配置示例
* 最佳實踐和使用模式

### 3. 可用的示例類別

* **核心功能**：基本設定和配置
* **Graph 執行**：工作流模式和路由
* **進階模式**：複雜的 AI 工作流和推理
* **企業功能**：生產就緒的實現

## 驗證

### 測試你的安裝

建立簡單的測試來驗證一切是否正常運作：

```csharp
using Microsoft.SemanticKernel;
using SemanticKernel.Graph;
using SemanticKernel.Graph.Extensions;
using SemanticKernel.Graph.Nodes;

// 測試基本功能
var builder = Kernel.CreateBuilder();
builder.AddOpenAIChatCompletion("gpt-4", Environment.GetEnvironmentVariable("OPENAI_API_KEY"));
builder.AddGraphSupport();

var kernel = builder.Build();

// 建立簡單的測試 Node
var testNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt("Say hello to {{$name}}"),
    "test-node"
);

// 建立並執行最小 Graph
var graph = new GraphExecutor("TestGraph");
graph.AddNode(testNode);
graph.SetStartNode(testNode.NodeId);

var state = new KernelArguments { ["name"] = "World" };
var result = await graph.ExecuteAsync(kernel, state);

Console.WriteLine($"Test successful! Result: {result}");
```

### 預期輸出

如果一切配置正確，你應該會看到：

```
Test successful! Result: Hello World!
```

**注意**：實際輸出可能因使用的 LLM 模型而異。如果你沒有配置有效的 API 金鑰，測試將顯示警告訊息，而不是執行 Graph。

## 疑難排解

### 常見安裝問題

#### 建置錯誤
```
error CS0234: The type or namespace name 'SemanticKernel' does not exist
```
**解決方案**：確保你已使用 `dotnet add package SemanticKernel.Graph` 正確新增 SemanticKernel.Graph 套件。

#### 缺少相依性
```
error CS0246: The type or namespace name 'Microsoft.Extensions.Configuration' could not be found
```
**解決方案**：新增所需的 NuGet 套件以進行配置和依賴注入。

#### 環境變數問題
```
System.InvalidOperationException: OPENAI_API_KEY not found
```
**解決方案**：驗證你的環境變數設定正確且可供應用程式存取。

#### .NET 版本問題
```
error NETSDK1045: The current .NET SDK does not support targeting .NET 8.0
```
**解決方案**：安裝 .NET 8.0 SDK 或更新你的專案以針對支援的架構版本。

### 取得說明

如果你遇到問題：

1. **檢查日誌**：啟用詳細日誌記錄以查看發生的情況
2. **驗證配置**：確保所有環境變數和 API 金鑰都正確
3. **檢查版本**：確保 Semantic Kernel 和 .NET 版本之間的相容性
4. **檢查套件版本**：確保你有最新版本的 SemanticKernel.Graph 套件
5. **執行示例**：使用提供的示例來驗證你的設定

## 後續步驟

現在你已安裝並配置 SemanticKernel.Graph：

* **[第一個 Graph 教程](first-graph.md)**：建置你的第一個完整 Graph 工作流
* **[核心概念](concepts/index.md)**：理解基本概念
* **[示例](examples/index.md)**：探索真實世界使用模式
* **[API 參考](api/core.md)**：深入研究完整的 API 表面

## 概念和技術

本安裝指南涵蓋了幾個關鍵概念：

* **套件管理**：從 NuGet 套件儲存庫安裝 SemanticKernel.Graph
* **環境配置**：設定 LLM 提供商認證和配置
* **配置管理**：使用 appsettings.json 和環境變數
* **依賴注入**：與 .NET 的 DI 容器整合以用於企業應用程式

## 前置條件和最低配置

若要成功安裝和使用 SemanticKernel.Graph，你需要：
* **.NET 8.0+** 執行階段和 SDK
* **Internet 存取**以從 NuGet 下載套件
* **Semantic Kernel** 套件（相容版本）
* **LLM Provider** 配置（API 金鑰、端點）
* **配置檔案**或敏感資料的環境變數

## 另請參閱

* **[入門指南](getting-started.md)**：SemanticKernel.Graph 功能概觀
* **[核心概念](concepts/index.md)**：理解 Graph、Node 和執行
* **[疑難排解](troubleshooting.md)**：常見問題和解決方案
* **[API 參考](api/core.md)**：完整的 API 文件
