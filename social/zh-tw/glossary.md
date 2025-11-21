# 詞彙表

本詞彙表定義了整個 Semantic Kernel Graph 文件中使用的核心術語和概念。每個術語都以簡單、易於理解的方式定義，同時保持技術準確性。

## 核心 Graph 概念

**Graph**: 由邊連接的節點組成的計算結構，定義了工作流中的執行流程。Graph 協調數據如何在不同的處理步驟之間流動。

**Node**: Graph 中的基本計算單位，代表單個處理步驟。每個 Node 可以執行函數、做出決策或執行特定操作。

**Edge**: 兩個節點之間的連接，定義了執行流程的路徑。Edge 可以是條件性的（只在滿足特定條件時遍歷）或無條件的（始終遍歷）。

**Execution**: 通過遍歷 Node 和 Edge 來運行 Graph 的過程，根據定義的流程在每一步處理數據。

**State**: 在 Graph 執行期間維護的當前數據和上下文，包括輸入參數、中間結果和執行元數據。

## Node 類型和行為

**FunctionGraphNode**: 一個封裝和執行 Semantic Kernel 函數的節點，圍繞現有的 ISKFunction 實例提供 Graph 感知行為。

**ActionGraphNode**: 一個專門的節點，根據當前上下文和可用函數自動發現並執行適當的工具或動作。

**ConditionalGraphNode**: 一個根據條件做出路由決策的節點，支持動態工作流路徑和分支邏輯。

**ReActLoopGraphNode**: 實現「推理 → 行動 → 觀察」模式的節點，用於迭代問題求解和決策制定。

**ObservationGraphNode**: 監視和記錄執行結果的節點，提供工作流性能和結果的可見性。

## Edge 和路由概念

**ConditionalEdge**: 節點之間的定向連接，包含一個謂詞函數，用於確定在執行期間是否應遍歷該邊。

**Unconditional Edge**: 始終遍歷的邊，提供節點之間的直接路徑，無需條件邏輯。

**Routing**: 根據當前狀態和邊條件確定下一個執行的節點的過程。

**Dynamic Routing**: 高級路由，在運行時根據內容分析、相似度匹配或其他上下文因素做出決策。

## 狀態管理

**GraphState**: KernelArguments 的類型化包裝器，作為 Graph 執行的基礎，提供執行跟踪和狀態操作能力。

**KernelArguments**: 底層數據容器，在整個工作流中保存輸入參數、中間結果和執行上下文。

**State Serialization**: 將 Graph 狀態轉換為持久格式以供存儲、傳輸或恢復的過程。

**State Validation**: 驗證狀態數據在處理前是否滿足必要的約束和格式要求。

## 執行和控制流程

**GraphExecutor**: Graph 執行的主要協調器，管理執行流程、導航和 Graph 節點的協調。

**Execution Context**: 運行時環境，在 Graph 執行期間維護執行狀態、指標並提供協調服務。

**Execution Path**: 在 Graph 運行期間訪問的節點序列，代表通過工作流的實際流程。

**Execution Status**: Graph 執行的當前狀態，例如 NotStarted、Running、Paused、Completed 或 Failed。

**Cancellation**: 在完成前優雅停止 Graph 執行的能力，遵守取消令牌和清理程序。

## 檢查點和恢復

**Checkpoint**: Graph 執行狀態的保存快照，在特定時間點，支持工作流的恢復和恢復。

**Checkpointing**: 創建、存儲和管理執行檢查點以實現彈性和恢復的過程。

**Recovery**: 從先前的檢查點恢復 Graph 執行、從保存的狀態繼續工作流處理的能力。

**State Persistence**: Graph 狀態和檢查點的長期存儲，通常使用記憶體服務或外部存儲系統。

**Checkpoint Validation**: 驗證保存的檢查點是否完整、一致以及能否成功恢復。

## 流式處理和即時執行

**Streaming Execution**: 實時 Graph 執行，在節點完成處理時提供即時反饋和事件流。

**Event Stream**: 實時執行事件序列，在 Graph 處理發生時提供可見性。

**GraphExecutionEvent**: 關於 Graph 執行期間特定事件的結構化通知，例如節點啟動、完成或錯誤。

**Backpressure**: 控制事件生成速率以匹配消費者處理能力的機制。

**Real-time Monitoring**: 對 Graph 執行進度、性能指標和狀態更新的實時觀察。

## 性能和可觀測性

**Metrics**: Graph 執行性能的定量測量，包括計時、吞吐量和資源利用率。

**Performance Monitoring**: 連續跟踪執行指標，以識別瓶頸並優化工作流性能。

**Telemetry**: 為了監視、調試和分析目的而收集和傳輸執行數據。

**Tracing**: 通過各個 Node 和 Edge 進行詳細的執行流程跟踪，用於調試和性能分析。

**Logging**: 結構化記錄執行事件、錯誤和診斷信息以實現操作可見性。

## 錯誤處理和彈性

**Error Recovery**: 檢測、處理和恢復執行失敗的能力，同時保持工作流完整性。

**Retry Policies**: 可配置的策略，用於使用指數退避和斷路器模式自動重試失敗的操作。

**Circuit Breaker**: 防止對失敗服務的重複調用的模式，允許其有時間恢復然後恢復操作。

**Fallback Strategies**: 當主要操作失敗或不可用時的替代執行路徑或默認行為。

**Error Propagation**: 錯誤通過 Graph 執行鏈進行通信以進行適當處理的機制。

## 進階模式

**Multi-Agent Coordination**: 多個專業化代理協同工作以解決複雜問題的協調。

**Human-in-the-Loop (HITL)**: 在自動化工作流中集成人類決策和批准步驟。

**Parallel Execution**: 多個節點或工作流分支的同時處理以提高性能和吞吐量。

**Fork-Join Patterns**: 將執行分割為並行路徑然後重新組合結果的工作流結構。

**Template Engine**: 用於創建可重用工作流模式和配置的系統，可針對特定用例進行自定義。

## 集成和擴展

**Plugin System**: 動態加載和集成外部功能到 Graph 工作流的機制。

**REST Tools**: 從 Graph 節點中調用外部 API 和服務的集成功能。

**Memory Integration**: 與持久存儲系統的連接，用於在多個工作流執行之間維護上下文。

**Custom Extensions**: 用戶定義的功能，使用特定領域邏輯擴展核心 Graph 功能。

**API Integration**: 將 Graph 工作流作為 REST 端點或其他外部接口公開的方法。

## 開發和測試

**Debug Mode**: 增強的執行模式，提供詳細的日誌、斷點和開發檢查功能。

**Graph Inspection**: 用於在開發和調試期間檢查 Graph 結構、狀態和執行歷史的工具和 API。

**Unit Testing**: 隔離測試各個 Node 和 Edge，驗證正確行為和邊界情況。

**Integration Testing**: 測試完整的 Graph 工作流，確保適當的協調和端到端功能。

**Performance Testing**: 評估在各種負載條件和數據卷下的 Graph 執行性能。

## 配置和選項

**Graph Options**: 可配置參數，控制 Graph 行為、性能和功能可用性。

**Execution Options**: 控制 Graph 執行方式的設置，包括超時、並發限制和資源約束。

**Checkpoint Options**: 檢查點創建、存儲、壓縮和保留策略的配置。

**Streaming Options**: 控制即時執行行為、事件緩衝和背壓處理的設置。

**Resource Options**: 管理記憶體使用、並發限制和系統資源分配的配置。

## 安全和數據處理

**Data Sanitization**: 從日誌、指標和外部通信中移除或隱藏敏感信息的過程。

**Access Control**: 控制誰可以執行、修改或檢查 Graph 工作流及其數據的機制。

**Audit Logging**: 為符合性、安全和操作目的對所有 Graph 操作的全面記錄。

**Encryption**: 使用加密技術保護靜態和傳輸中的敏感數據。

**Privacy Controls**: 幫助維護數據隱私並遵守法規要求的功能。

## 部署和操作

**Production Deployment**: 在生產環境中使 Graph 工作流可供實時使用的過程。

**Monitoring and Alerting**: 用於觀察生產工作流並在出現問題或性能降低時通知操作人員的系統。

**Scaling**: 調整資源分配和並發以處理不同工作負載和性能要求的能力。

**High Availability**: 設計模式，確保 Graph 工作流即使在各個組件發生故障時仍保持運營。

**Disaster Recovery**: 在發生重大故障或數據丟失事件後恢復 Graph 操作的程序和系統。
