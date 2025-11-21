# 概念總覽

您將在整個程式庫中使用的核心概念：

* Graph：節點與條件邊的有向圖
* State：環繞 `KernelArguments` 的型別包裝器，具備版本控制、驗證功能
* Node：函式、條件、迴圈、錯誤處理器、人工審核、子圖等
* Execution：順序執行、並行執行、分散式執行；檢查點與恢復功能
* Streaming：用於 UI 和可觀測性的即時事件
* Visualization：DOT、Mermaid、JSON 輸出用於文件和工具
