## 第10章 — 鑽石：chain 與 grafo 的比較

此範例比較鑽石模式在 chain（循序）和 grafo（平行）中的表現：

- Chain：分支 A → 分支 B → 合併
- Grafo：分支 A || 分支 B → 合併

預期的 makespan 結果：

- Chain：T = A + B + Merge
- Grafo：T = max(A, B) + Merge

相關檔案：

- Chain：`graph-ia-book/src/chains/chapter10/ChainChapter10.cs`
- Graph：`graph-ia-book/src/graphs/chapter10/GraphChapter10.cs`
- Runner：`graph-ia-book/src/Chapters/Chapter10.cs`

產生的指標（結果目錄中的範例）：

- `cap10/chain/latency-summary.{json,md}`
- `cap10/graph/latency-summary.{json,md}`
- `cap10/benchmark/latency-ab-summary.{json,md}`
- `cap10/theory/diamond-makespan-summary.{json,md}`

透過 Program 選擇第 10 章執行：

```bash
dotnet run --project graph-ia-book/src/book.csproj --chapter 10 --mode b
```

