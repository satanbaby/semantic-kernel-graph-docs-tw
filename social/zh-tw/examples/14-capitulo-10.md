## Capítulo 10 — Diamante: chain vs grafo

Este exemplo compara um padrão diamante em chain (sequencial) e grafo (paralelo):

- Chain: Branch A → Branch B → Merge
- Grafo: Branch A || Branch B → Merge

Resultados esperados de makespan:

- Chain: T = A + B + Merge
- Grafo: T = max(A, B) + Merge

Arquivos relevantes:

- Chain: `graph-ia-book/src/chains/chapter10/ChainChapter10.cs`
- Graph: `graph-ia-book/src/graphs/chapter10/GraphChapter10.cs`
- Runner: `graph-ia-book/src/Chapters/Chapter10.cs`

Métricas geradas (exemplos no diretório de resultados):

- `cap10/chain/latency-summary.{json,md}`
- `cap10/graph/latency-summary.{json,md}`
- `cap10/benchmark/latency-ab-summary.{json,md}`
- `cap10/theory/diamond-makespan-summary.{json,md}`

Execute via Program selecionando capítulo 10:

```bash
dotnet run --project graph-ia-book/src/book.csproj --chapter 10 --mode b
```


