## 第 5 章 — 可解釋性與稽核

本範例隨附書籍的章節 `docs/book/08-capitulo-5.md` 並演示：

- Chain (SK) 不具明確追蹤與 Graph (SKG) 具結構化追蹤之間的差異。
- 如何啟用指標和事件串流進行按節點/路徑的稽核。

### 執行

在 `graph-ia-book` 專案中：

- Chain: `GraphIABook.Chains.Chapter5.ChainChapter5.RunAsync(input)`
- Graph: `GraphIABook.Graphs.Chapter5.GraphChapter5.RunAsync(input)` 和 `RunWithTraceAsync(input)`

### 指標

- 輸出產生在 `graph-ia-book/src/Benchmark/results` 中：
  - `cap5_chain_latency-summary.{json,md}`
  - `cap5_graph_latency-summary.{json,md}`
  - `cap5_benchmark_latency-ab_*` (A/B)
  - `cap5_theory_explainability-summary.{json,md}`

### 備註

- Graph 使用 `ConditionalGraphNode` 搭配 `{{ gte score 0.5 }}` 表達式進行明確路由。
- 串流執行發出事件：開始、節點已開始/已完成和 `ConditionEvaluated`。

