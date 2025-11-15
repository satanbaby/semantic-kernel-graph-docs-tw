# 安裝指南

本指南將幫助您在 .NET 專案中安裝和設定 SemanticKernel.Graph。您將了解如何新增套件、設定環境以及設定基本要求。

## 必要條件

在安裝 SemanticKernel.Graph 之前，請確保您已具備以下條件：

* **.NET 8.0** 或更新版本安裝在您的系統上
* **Visual Studio 2022** (17.8+) 或 **VS Code** 搭配 C# 擴充功能
* 您的專案中已安裝 **Semantic Kernel** 套件
* **LLM 提供者 API 金鑰** (OpenAI、Azure OpenAI 或其他支援的提供者)

### .NET 版本檢查

執行下列命令驗證您的 .NET 版本：

```bash
dotnet --version
```

您應該看到 8.0.0 或更新版本。如果沒有，請從 [Microsoft 官方網站](https://dotnet.microsoft.com/download) 下載並安裝最新的 .NET 8 SDK。

## 套件安裝

SemanticKernel.Graph 現已在 NuGet 上提供！您可以使用以下方法安裝：

### 使用 dotnet CLI (推薦)

```bash
dotnet add package SemanticKernel.Graph
```

### 使用 PackageReference

將以下內容新增至您的 `.csproj` 檔案：

```xml
<ItemGroup>
    <PackageReference Include="SemanticKernel.Graph" Version="25.8.191" />
</ItemGroup>
```

### 使用 Package Manager Console

```
Install-Package SemanticKernel.Graph
```

## 環境設定

### LLM 提供者設定

SemanticKernel.Graph 需要已設定的 LLM 提供者。以下是最常見的設定：

#### OpenAI 設定

```bash
# Windows
setx OPENAI_API_KEY "your-api-key-here"
setx OPENAI_MODEL_NAME "gpt-4"

# macOS/Linux
export OPENAI_API_KEY="your-api-key-here"
export OPENAI_MODEL_NAME="gpt-4"
```

```csharp
// 在您的程式碼中
var builder = Kernel.CreateBuilder();
builder.AddOpenAIChatCompletion(
    modelId: Environment.GetEnvironmentVariable("OPENAI_MODEL_NAME") ?? "gpt-4",
    apiKey: Environment.GetEnvironmentVariable("OPENAI_API_KEY") ?? throw new InvalidOperationException("OPENAI_API_KEY not found")
);
```

#### Azure OpenAI 設定

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
// 在您的程式碼中
var builder = Kernel.CreateBuilder();
builder.AddAzureOpenAIChatCompletion(
    deploymentName: Environment.GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT_NAME") ?? throw new InvalidOperationException("AZURE_OPENAI_DEPLOYMENT_NAME not found"),
    endpoint: Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT") ?? throw new InvalidOperationException("AZURE_OPENAI_ENDPOINT not found"),
    apiKey: Environment.GetEnvironmentVariable("AZURE_OPENAI_API_KEY") ?? throw new InvalidOperationException("AZURE_OPENAI_API_KEY not found")
);
```

#### 組態檔案設定

針對本機開發，您可以使用 `appsettings.json` (記得將其新增至 `.gitignore`)：

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

然後在您的應用程式中載入它：

```csharp
// 從 appsettings.json 載入組態
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

### 2. 新增必要套件

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

這將自動將套件參考新增至您的 `.csproj` 檔案。

### 4. 基本設定

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

// 設定您的 LLM 提供者
builder.AddOpenAIChatCompletion(
    "gpt-4", 
    configuration["OpenAI:ApiKey"] ?? Environment.GetEnvironmentVariable("OPENAI_API_KEY")
);

// 啟用圖形功能
builder.AddGraphSupport(options =>
{
    options.EnableLogging = true;
    options.EnableMetrics = true;
});

var kernel = builder.Build();
```

## 進階設定

### 圖形選項

您可以使用各種選項自訂圖形行為：

```csharp
builder.AddGraphSupport(options =>
{
    // 啟用日誌記錄
    options.EnableLogging = true;
    
    // 啟用效能指標
    options.EnableMetrics = true;
    
    // 設定執行限制
    options.MaxExecutionSteps = 100;
    options.ExecutionTimeout = TimeSpan.FromMinutes(5);
});

// 新增其他圖形功能
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

### 相依性注入設定

針對 ASP.NET Core 應用程式，SemanticKernel.Graph 能無縫整合到 DI 容器：

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// 新增具有圖形支援的 Semantic Kernel
builder.Services.AddKernel(options =>
{
    options.AddOpenAIChatCompletion("gpt-4", builder.Configuration["OpenAI:ApiKey"]);
    options.AddGraphSupport();
});

var app = builder.Build();
```

**注意**：此範例需要 ASP.NET Core 執行階段和 `Microsoft.AspNetCore.App` 框架參考。如果您正在建立主控台應用程式，可以改用上述基本設定範例。

## 執行範例

本專案包含展示各種功能的完整範例：

### 1. 探索範例

文件在 [examples/](examples/) 目錄中包含完整範例：

* **基本模式**：簡單的工作流程和節點類型
* **進階路由**：動態執行路徑和條件邏輯
* **多代理**：協調的 AI 代理工作流程
* **企業級**：具有監控和復原能力的生產就緒模式

### 2. 遵循教程

每個範例包含：
* 您可以複製和調整的完整程式碼片段
* 程式碼如何運作的逐步說明
* 不同情境的設定範例
* 最佳做法和使用模式

### 3. 可用的範例類別

* **核心功能**：基本設定和設定
* **圖形執行**：工作流程模式和路由
* **進階模式**：複雜的 AI 工作流程和推理
* **企業功能**：生產就緒的實作

## 驗證

### 測試您的安裝

建立一個簡單的測試來驗證一切正常運作：

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

// 建立一個簡單的測試節點
var testNode = new FunctionGraphNode(
    kernel.CreateFunctionFromPrompt("Say hello to {{$name}}"),
    "test-node"
);

// 建立並執行最小圖形
var graph = new GraphExecutor("TestGraph");
graph.AddNode(testNode);
graph.SetStartNode(testNode.NodeId);

var state = new KernelArguments { ["name"] = "World" };
var result = await graph.ExecuteAsync(kernel, state);

Console.WriteLine($"Test successful! Result: {result}");
```

### 預期的輸出

如果一切都正確設定，您應該會看到：

```
Test successful! Result: Hello World!
```

**注意**：實際輸出可能因使用的 LLM 模型而異。如果您沒有有效的 API 金鑰，測試將顯示警告訊息，而不是執行圖形。

## 疑難排解

### 常見安裝問題

#### 組建錯誤
```
error CS0234: The type or namespace name 'SemanticKernel' does not exist
```
**解決方案**：確認您已使用 `dotnet add package SemanticKernel.Graph` 正確新增 SemanticKernel.Graph 套件。

#### 缺少相依性
```
error CS0246: The type or namespace name 'Microsoft.Extensions.Configuration' could not be found
```
**解決方案**：新增配置和相依性注入所需的 NuGet 套件。

#### 環境變數問題
```
System.InvalidOperationException: OPENAI_API_KEY not found
```
**解決方案**：驗證您的環境變數設定正確且應用程式可以存取。

#### .NET 版本問題
```
error NETSDK1045: The current .NET SDK does not support targeting .NET 8.0
```
**解決方案**：安裝 .NET 8.0 SDK 或將您的專案更新為目標支援的框架版本。

### 取得說明

如果遇到問題：

1. **檢查日誌**：啟用詳細日誌記錄以查看發生的情況
2. **驗證設定**：確保所有環境變數和 API 金鑰都正確
3. **檢查版本**：確保 Semantic Kernel 和 .NET 版本之間的相容性
4. **檢查套件版本**：確保您有最新版本的 SemanticKernel.Graph 套件
5. **執行範例**：使用提供的範例來驗證您的設定

## 後續步驟

現在您已安裝並設定了 SemanticKernel.Graph：

* **[第一個圖形教程](first-graph.md)**：建立您的第一個完整圖形工作流程
* **[核心概念](concepts/index.md)**：理解基本概念
* **[範例](examples/index.md)**：探索現實世界的使用模式
* **[API 參考](api/core.md)**：深入了解完整的 API 表面

## 概念和技術

本安裝指南涵蓋多個關鍵概念：

* **套件管理**：從 NuGet 套件存放庫安裝 SemanticKernel.Graph
* **環境設定**：設定 LLM 提供者認證和設定
* **設定管理**：使用 appsettings.json 和環境變數
* **相依性注入**：與 .NET 的 DI 容器整合，用於企業應用程式

## 必要條件和最低設定

若要成功安裝和使用 SemanticKernel.Graph，您需要：
* **.NET 8.0+** 執行階段和 SDK
* **網際網路存取** 以從 NuGet 下載套件
* **Semantic Kernel** 套件 (相容版本)
* **LLM 提供者** 設定 (API 金鑰、端點)
* **設定檔案** 或敏感資料的環境變數

## 另請參閱

* **[入門](getting-started.md)**：SemanticKernel.Graph 功能概述
* **[核心概念](concepts/index.md)**：理解圖形、節點和執行
* **[疑難排解](troubleshooting.md)**：常見問題和解決方案
* **[API 參考](api/core.md)**：完整的 API 文件
