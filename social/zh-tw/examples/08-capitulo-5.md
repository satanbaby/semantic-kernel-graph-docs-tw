## 第5章 — 可解釋性和審計

此範例對應於書籍中的章節 `docs/book/08-capitulo-5.md`，並演示：

- 沒有明確追蹤的連鎖（SK）和具有結構化追蹤的圖形（SKG）之間的差異。
- 如何啟用指標和事件流式傳輸，以進行各節點/路徑的審計。

### 執行

在 `graph-ia-book` 專案中：

- 連鎖：`GraphIABook.Chains.Chapter5.ChainChapter5.RunAsync(input)`
- 圖形：`GraphIABook.Graphs.Chapter5.GraphChapter5.RunAsync(input)` 和 `RunWithTraceAsync(input)`

### 指標

- 輸出生成在 `graph-ia-book/src/Benchmark/results`：
  - `cap5_chain_latency-summary.{json,md}`
  - `cap5_graph_latency-summary.{json,md}`
  - `cap5_benchmark_latency-ab_*`（A/B）
  - `cap5_theory_explainability-summary.{json,md}`

### 註釋

- 圖形使用 `ConditionalGraphNode` 搭配 `{{ gte score 0.5 }}` 表達式進行明確的路由。
- 流式傳輸執行發出事件：開始、節點已啟動/已完成和 `ConditionEvaluated`。

