# 更新日誌

本文檔記錄了 SemanticKernel.Graph 各版本的主要變更和改進。

## [未發佈] - 開發中

### 新增
* 完整的文件系統與 MkDocs
* 路由、視覺化、執行、圖形和節點的概念頁面
* 所有主要功能的實踐指南
* 所有模式和資源的綜合示例

### 變更
* 完整的文件重組
* 所有頁面使用「概念和技術」及「參考資料」章節的標準化

## [0.1.0] - 初始版本

### 新增
* SemanticKernel.Graph 專案的基本結構
* 具有節點和條件邊的圖形執行系統
* 檢查點和狀態恢復支持
* 具有實時事件的流式執行
* 指標和可觀測性系統
* 與現有 Semantic Kernel 的整合
* 多種節點類型的支持（函數、條件、推理、循環）
* 動態路由系統和路由策略
* 多種格式的圖形視覺化（DOT、Mermaid、JSON）
* 常見工作流程的模板系統
* 多代理和協調支持
* 人類在迴圈中 (HITL) 系統
* 與 REST 工具和外部 API 的整合
* 圖形驗證和編譯系統
* 錯誤原則和彈性
* 資源治理和並發系統

### 架構
* 基於 ADR（架構決策記錄）的設計
* Core、Execution、State、Streaming 和 Integration 之間的清晰分離
* 外掛程式和自訂的擴展性系統
* 對分散式和並行執行的支持

## [0.0.1] - 初始框架

### 新增
* 初始專案結構
* 基本的 MkDocs 配置
* 基本的文件頁面
* 概念、指南和示例的目錄結構

---

## 如何貢獻

若要對更新日誌做出貢獻：

1. **新增條目**以記錄所有重要變更
2. **使用清晰的類別**：Added、Changed、Removed、Fixed
3. **保持一致**性與現有格式
4. **包含詳細資訊**有關重大變更和遷移

## 提交歷史

有關詳細變更，請參閱：
* [存放庫版本](https://github.com/your-org/semantic-kernel-graph/releases)
* [提交歷史](https://github.com/your-org/semantic-kernel-graph/commits/main)

## 發佈說明

### 重大變更
* **0.1.0**：執行 API 的變更以改進效能和易用性
* **0.0.1**：初始結構，沒有重大變更

### 遷移
* **0.1.0**：遷移指南可在 [遷移指南](../migrations/index.md) 獲得

---

*此更新日誌遵循 [Keep a Changelog](https://keepachangelog.com/) 和 [語義版本控制](https://semver.org/)。*
