# 聊天機器人與記憶範例

本範例示範使用 Graph 實現具備記憶功能的基本聊天機器人。展示對話管理、context 持久化，以及為建構具有持久記憶的對話型 AI 系統進行智慧路由。

## 目標

學習如何實現一個對話式 AI 系統：
* 跨多輪對話維護對話 context
* 整合短期和長期記憶
* 根據用戶意圖進行智慧對話路由
* 根據對話歷史提供個性化回應
* 從簡單到進階對話模式的擴展

## 先決條件

* **.NET 8.0** 或更新版本
* **OpenAI API Key** 在 `appsettings.json` 中設定
* **Semantic Kernel Graph** 套件已安裝
* [Graph Concepts](../concepts/graph-concepts.md) 和 [State Management](../concepts/state.md) 的基本理解

## 主要元件

### 概念和技術

* **Conversation Memory**：對話 context 和用戶互動的持久儲存
* **Intent Recognition**：理解用戶意圖並適當地路由對話
* **Context Management**：跨對話輪次維護相關資訊
* **Memory Integration**：結合短期和長期記憶以獲得更好的回應

### 核心類別

* `GraphMemoryService`：管理對話記憶和 context
* `FunctionGraphNode`：執行對話邏輯和記憶操作
* `GraphMemoryOptions`：配置記憶行為和儲存
* `KernelArguments`：在多輪對話間傳遞對話狀態和 context

## 執行範例

### 開始使用

本範例示範如何使用 Semantic Kernel Graph 套件建構具有記憶的聊天機器人。下方程式碼片段展示如何在您的應用程式中實現此模式。

## 逐步實現

### 1. 具有短期記憶的基本聊天機器人

本範例示範具有對話 context 的簡單聊天機器人。

```csharp
// 建立 Kernel 實例（若可用，使用 appsettings.json）
var kernel = CreateKernel();

// 為範例配置輕量級記憶服務
var memoryOptions = new GraphMemoryOptions
{
    EnableVectorSearch = true,      // 啟用語義向量搜尋
    EnableSemanticSearch = true,    // 啟用相似性搜尋
    DefaultCollectionName = "chatbot-memory"
};
var memoryService = new GraphMemoryService(memoryOptions);

// 建構聊天機器人 Graph executor（參見 examples/ChatbotExample.cs）
var chatbot = await CreateBasicChatbotGraphAsync(kernel, memoryService);

// 模擬簡短對話序列
var conversations = new[]
{
    "Hello, what's your name?",
    "My name is Joao. And yours?",
    "Joao, can you help me with math?",
    "What's the capital of Brazil?",
    "Thanks for the help!"
};

Console.WriteLine("🤖 Starting conversation simulation...\n");

var turnNumber = 1;
foreach (var userMessage in conversations)
{
    Console.WriteLine($"👤 User: {userMessage}");

    var arguments = new KernelArguments
    {
        ["user_message"] = userMessage,
        ["conversation_id"] = "conv_001",
        ["user_id"] = "user_001",
        ["turn_number"] = turnNumber
    };

    var result = await chatbot.ExecuteAsync(kernel, arguments);
    var botResponse = result.GetValue<string>() ?? "I'm sorry, I couldn't process that.";

    Console.WriteLine($"🤖 Bot: {botResponse}");
    Console.WriteLine();

    // 小延遲以模擬真實聊天 UI
    await Task.Delay(500);
    turnNumber++;
}
```

### 2. 具有長期記憶的進階聊天機器人

示範跨多個對話的持久記憶。

```csharp
// 建立使用長期記憶和個性設定的進階聊天機器人 Graph
var advancedChatbot = await CreateAdvancedChatbotGraphAsync(kernel, memoryService);

// 兩個獨立的 session 用於展示對話間的記憶持久性
var conversation1 = new[]
{
    "Hi, I'm Alex. I'm interested in machine learning.",
    "What are the best resources to start with?",
    "I have some experience with Python."
};

var conversation2 = new[]
{
    "Hi again! Remember our discussion about machine learning?",
    "I've been studying the resources you recommended.",
    "Can you suggest some advanced topics?"
};

// 第一個對話
Console.WriteLine("=== First Conversation ===");
foreach (var message in conversation1)
{
    var arguments = new KernelArguments
    {
        ["user_message"] = message,
        ["conversation_id"] = "conv_alex_001",
        ["user_id"] = "alex",
        ["session_type"] = "learning_consultation"
    };

    var result = await advancedChatbot.ExecuteAsync(kernel, arguments);
    var response = result.GetValue<string>();
    Console.WriteLine($"User: {message}");
    Console.WriteLine($"Bot: {response}\n");
}

// 第二個對話（展示記憶回想）
Console.WriteLine("=== Second Conversation (with Memory) ===");
foreach (var message in conversation2)
{
    var arguments = new KernelArguments
    {
        ["user_message"] = message,
        ["conversation_id"] = "conv_alex_002",
        ["user_id"] = "alex",
        ["session_type"] = "follow_up"
    };

    var result = await advancedChatbot.ExecuteAsync(kernel, arguments);
    var response = result.GetValue<string>();
    Console.WriteLine($"User: {message}");
    Console.WriteLine($"Bot: {response}\n");
}
```

### 3. 具有 Context 的多輪對話

展示如何跨複雜對話流程維護 context。

```csharp
// 建構用於多輪規劃對話的 context 感知聊天機器人
var contextualChatbot = await CreateContextualChatbotGraphAsync(kernel, memoryService);

// 範例：多輪度假規劃對話
var complexConversation = new[]
{
    "I need help planning a trip to Europe.",
    "I'm interested in history and culture.",
    "My budget is around $5000 for two weeks.",
    "I prefer smaller cities over tourist traps.",
    "What about transportation between cities?",
    "Can you suggest a specific itinerary?",
    "What about accommodation recommendations?",
    "Thank you, this is very helpful!"
};

Console.WriteLine("🌍 Starting vacation planning conversation...\n");

var context = new Dictionary<string, object>
{
    ["topic"] = "vacation_planning",
    ["destination"] = "Europe",
    ["interests"] = new[] { "history", "culture" },
    ["budget"] = 5000,
    ["duration"] = "2 weeks",
    ["preferences"] = new[] { "smaller cities", "authentic experience" }
};

foreach (var message in complexConversation)
{
    var arguments = new KernelArguments
    {
        ["user_message"] = message,
        ["conversation_id"] = "conv_vacation_001",
        ["user_id"] = "vacation_planner",
        ["context"] = context
    };

    var result = await contextualChatbot.ExecuteAsync(kernel, arguments);
    var response = result.GetValue<string>();
    
    // 若 Graph 回傳更豐富的狀態，可選擇更新本地 context
    var updatedContext = result.GetValue<Dictionary<string, object>>("updated_context");
    if (updatedContext != null)
    {
        context = updatedContext;
    }

    Console.WriteLine($"User: {message}");
    Console.WriteLine($"Bot: {response}\n");
}
```

## 預期輸出

### 基本聊天機器人範例

```
🤖 Starting conversation simulation...

👤 User: Olá, qual é o seu nome?
🤖 Bot: Olá! Meu nome é Assistant, um chatbot criado para ajudar você. Como posso ser útil hoje?

👤 User: Meu nome é João. E o seu?
🤖 Bot: Olá João! É um prazer conhecê-lo. Como mencionei, sou o Assistant. Como posso ajudá-lo hoje?

👤 User: João, você pode me ajudar com matemática?
🤖 Bot: Claro, João! Ficarei feliz em ajudá-lo com matemática. Que tipo de problema ou conceito você gostaria de revisar?

👤 User: Qual é a capital do Brasil?
🤖 Bot: A capital do Brasil é Brasília. Foi inaugurada em 21 de abril de 1960, substituindo o Rio de Janeiro como capital federal.

👤 User: Obrigado pela ajuda!
🤖 Bot: De nada, João! Foi um prazer ajudá-lo. Se precisar de mais alguma coisa, especialmente com matemática ou outras questões, estarei aqui para ajudar!

✅ Basic chatbot example completed successfully!
```

### 具有記憶的進階聊天機器人

```
=== First Conversation ===
User: Hi, I'm Alex. I'm interested in machine learning.
Bot: Hello Alex! It's great to meet you. I'm excited to help you with machine learning. What specific areas interest you most?

User: What are the best resources to start with?
Bot: For beginners in machine learning, I recommend starting with:
1. "Hands-On Machine Learning" by Aurélien Géron
2. Online courses on Coursera or edX
3. Practical projects on Kaggle

User: I have some experience with Python.
Bot: Excellent! Since you know Python, you're already ahead. I'd suggest diving into:
* Scikit-learn for traditional ML
* TensorFlow or PyTorch for deep learning
* Jupyter notebooks for experimentation

=== Second Conversation (with Memory) ===
User: Hi again! Remember our discussion about machine learning?
Bot: Of course, Alex! Welcome back! I remember we discussed your interest in machine learning and I recommended some great resources including "Hands-On Machine Learning" and practical projects on Kaggle. How has your learning journey been going?

User: I've been studying the resources you recommended.
Bot: That's fantastic, Alex! I'm glad you've been following up on those recommendations. How are you finding the "Hands-On Machine Learning" book? And have you had a chance to explore any Kaggle competitions yet?

User: Can you suggest some advanced topics?
Bot: Absolutely! Based on your foundation, here are some advanced topics to explore:
* Deep Learning architectures (CNNs, RNNs, Transformers)
* Advanced optimization techniques
* Model interpretability and explainability
* MLOps and model deployment
* Reinforcement learning fundamentals

Would you like me to elaborate on any of these areas?
```

## 設定選項

### 記憶服務設定

```csharp
var memoryOptions = new GraphMemoryOptions
{
    EnableVectorSearch = true,           // 啟用語義搜尋
    EnableSemanticSearch = true,        // 啟用相似性搜尋
    DefaultCollectionName = "chatbot-memory", // 記憶集合名稱
    SimilarityThreshold = 0.8,          // 搜尋相似性閾值
    MaxMemoryItems = 1000,              // 每個用戶最大記憶項目
    MemoryExpiration = TimeSpan.FromDays(30), // 記憶保留期限
    EnableCompression = true,           // 壓縮記憶以進行儲存
    EnableIndexing = true               // 啟用快速搜尋索引
};
```

### 聊天機器人 Graph 設定

```csharp
var chatbotOptions = new ChatbotOptions
{
    EnableContextMemory = true,         // 記住對話 context
    EnableUserProfiles = true,          // 維護用戶檔案
    EnableIntentRecognition = true,     // 識別用戶意圖
    EnableSentimentAnalysis = true,     // 分析用戶情感
    MaxContextTurns = 10,               // 最多要記住的 context 輪數
    ResponseTimeout = TimeSpan.FromSeconds(30), // 回應生成逾時
    EnableFallbackResponses = true,     // 不確定時提供備用回應
    EnableConversationAnalytics = true  // 追蹤對話指標
};
```

## 疑難排除

### 常見問題

#### 記憶無法持久存留
```bash
# 問題：對話 context 在輪次間遺失
# 解決方案：確保記憶服務已正確設定
EnableContextMemory = true;
MaxContextTurns = 10;
```

#### 回應生成速度緩慢
```bash
# 問題：機器人回應速度慢
# 解決方案：最佳化記憶搜尋並啟用快取
EnableIndexing = true;
EnableCompression = true;
ResponseTimeout = TimeSpan.FromSeconds(60);
```

#### Context 混亂
```bash
# 問題：機器人對對話 context 感到困惑
# 解決方案：改進 context 管理和記憶清理
MaxContextTurns = 5; // 縮小 context 視窗
EnableMemoryCleanup = true;
```

### 偵錯模式

啟用詳細記錄以進行疑難排除：

```csharp
// 啟用偵錯記錄
var logger = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger<ChatbotExample>();

// 以偵錯記錄設定聊天機器人
var debugChatbot = await CreateBasicChatbotGraphAsync(kernel, memoryService);
debugChatbot.EnableDebugMode = true;
debugChatbot.LogMemoryOperations = true;
debugChatbot.LogContextChanges = true;
```

## 進階模式

### 基於意圖的路由

```csharp
// 實現意圖識別以獲得更好的對話流程
var intentRouter = new IntentRouter
{
    IntentPatterns = new Dictionary<string, string>
    {
        ["greeting"] = @"^(hi|hello|hey|olá|oi)",
        ["question"] = @"^(what|how|why|when|where|can you|do you)",
        ["request"] = @"^(help|assist|support|need|want)",
        ["gratitude"] = @"^(thank|thanks|obrigado|obrigada|appreciate)"
    },
    IntentHandlers = new Dictionary<string, Func<string, Task<string>>>
    {
        ["greeting"] = async (message) => await HandleGreeting(message),
        ["question"] = async (message) => await HandleQuestion(message),
        ["request"] = async (message) => await HandleRequest(message),
        ["gratitude"] = async (message) => await HandleGratitude(message)
    }
};

chatbot.IntentRouter = intentRouter;
```

### 動態記憶管理

```csharp
// 實現自適應記憶管理
var adaptiveMemory = new AdaptiveMemoryManager
{
    MemoryPrioritization = (context) =>
    {
        // 優先考慮最近和相關的記憶
        var relevance = CalculateRelevance(context);
        var recency = CalculateRecency(context);
        return relevance * 0.7 + recency * 0.3;
    },
    MemoryCleanup = (memories) =>
    {
        // 當儲存空間滿時移除低優先級記憶
        return memories.OrderByDescending(m => m.Priority)
                      .Take(1000);
    }
};

memoryService.MemoryManager = adaptiveMemory;
```

### 多模態對話

```csharp
// 支援不同對話模態
var multiModalChatbot = new MultiModalChatbot
{
    ModalityHandlers = new Dictionary<string, IModalityHandler>
    {
        ["text"] = new TextModalityHandler(),
        ["voice"] = new VoiceModalityHandler(),
        ["image"] = new ImageModalityHandler(),
        ["gesture"] = new GestureModalityHandler()
    },
    ModalityRouter = (input) =>
    {
        // 路由到適當的模態處理程式
        return input.Type switch
        {
            InputType.Text => "text",
            InputType.Voice => "voice",
            InputType.Image => "image",
            InputType.Gesture => "gesture",
            _ => "text"
        };
    }
};
```

## 相關範例

* [Memory Agent](./memory-agent.md)：跨對話的持久記憶
* [Retrieval Agent](./retrieval-agent.md)：資訊檢索和合成
* [Multi-Agent](./multi-agent.md)：協調的多代理工作流程
* [State Management](./state-management.md)：Graph 狀態和引數處理

## 另請參閱

* [Memory and State](../concepts/state.md)：理解對話持久性
* [Graph Concepts](../concepts/graph-concepts.md)：基於 Graph 的工作流程基礎
* [Conversation Patterns](../patterns/chatbot.md)：建構對話型 AI
* [API Reference](../api/)：完整 API 文件
