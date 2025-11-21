# 變更日誌

此文檔記錄 SemanticKernel.Graph 各版本的主要變更和改進。

## [未發布] - 開發中

### 新增
* 完整的 MkDocs 文檔系統
* 路由、可視化、執行、Graph 和 Node 的概念頁面
* 所有主要功能的實用指南
* 所有模式和資源的綜合示例

### 變更
* 完整的文檔重構
* 所有頁面使用「概念與技術」和「參考」部分的標準化

## [0.1.0] - 初始版本

### 新增
* SemanticKernel.Graph 項目的基礎結構
* 具有 Node 和條件 Edge 的 Graph 執行系統
* 檢查點和狀態恢復支援
* 實時事件的 Streaming 執行
* 指標和可觀察性系統
* 與現有 Semantic Kernel 的集成
* 支援多種 Node 類型（function、conditional、reasoning、loop）
* 動態路由系統和路由策略
* 多種格式的 Graph 可視化（DOT、Mermaid、JSON）
* 通用工作流的範本系統
* 多智能體和協調支援
* Human-in-the-Loop (HITL) 系統
* 與 REST 工具和外部 API 的集成
* Graph 驗證和編譯系統
* 錯誤策略和復原力
* 資源治理和並發系統

### 架構
* 基於 ADR（架構決策記錄）的設計
* Core、Execution、State、Streaming 和 Integration 之間的清晰分離
* 插件和自定義的可擴展性系統
* 支援分佈式和並行執行

## [0.0.1] - 初始框架

### 新增
* 初始項目結構
* 基本 MkDocs 配置
* 基本文檔頁面
* 概念、指南和示例的目錄結構

---

## 如何貢獻

要貢獻於變更日誌：

1. **新增項目**用於所有重要變更
2. **使用清晰的類別**：Added、Changed、Removed、Fixed
3. **保持一致性**與現有格式
4. **包含詳細信息**關於破壞性變更和遷移

## 提交歷史

有關詳細變更，請參閱：
* [Repository Releases](https://github.com/your-org/semantic-kernel-graph/releases)
* [Commit History](https://github.com/your-org/semantic-kernel-graph/commits/main)

## 發布說明

### 破壞性變更
* **0.1.0**：執行 API 中的變更以改進性能和可用性
* **0.0.1**：沒有破壞性變更的初始結構

### 遷移
* **0.1.0**：遷移指南可在 [Migrations Guide](../migrations/index.md) 取得

---

*此變更日誌遵循 [Keep a Changelog](https://keepachangelog.com/) 和 [Semantic Versioning](https://semver.org/)。*
