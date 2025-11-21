## 章節 10 — 鑽石形：Chain 與 Graph 的比較

此範例比較 Chain（序列）與 Graph（平行）中的鑽石形模式：

- Chain：Branch A → Branch B → Merge
- Graph：Branch A || Branch B → Merge

預期的 Makespan 結果：

- Chain：T = A + B + Merge
- Graph：T = max(A, B) + Merge

相關檔案：

- Chain：`graph-ia-book/src/chains/chapter10/ChainChapter10.cs`
- Graph：`graph-ia-book/src/graphs/chapter10/GraphChapter10.cs`
- Runner：`graph-ia-book/src/Chapters/Chapter10.cs`

生成的指標（結果目錄中的範例）：

- `cap10/chain/latency-summary.{json,md}`
- `cap10/graph/latency-summary.{json,md}`
- `cap10/benchmark/latency-ab-summary.{json,md}`
- `cap10/theory/diamond-makespan-summary.{json,md}`

透過選擇章節 10 透過 Program 執行：

```bash
dotnet run --project graph-ia-book/src/book.csproj --chapter 10 --mode b
```

