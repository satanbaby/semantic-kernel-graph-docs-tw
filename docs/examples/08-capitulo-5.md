## Capítulo 5 — Explicabilidade e Auditoria

Este exemplo acompanha o capítulo do livro `docs/book/08-capitulo-5.md` e demonstra:

- Diferença entre chain (SK) sem trilha explícita e grafo (SKG) com rastreio estruturado.
- Como habilitar métricas e streaming de eventos para auditoria por nó/caminho.

### Execução

No projeto `graph-ia-book`:

- Chain: `GraphIABook.Chains.Chapter5.ChainChapter5.RunAsync(input)`
- Graph: `GraphIABook.Graphs.Chapter5.GraphChapter5.RunAsync(input)` e `RunWithTraceAsync(input)`

### Métricas

- Saídas geradas em `graph-ia-book/src/Benchmark/results`:
  - `cap5_chain_latency-summary.{json,md}`
  - `cap5_graph_latency-summary.{json,md}`
  - `cap5_benchmark_latency-ab_*` (A/B)
  - `cap5_theory_explainability-summary.{json,md}`

### Observações

- O grafo utiliza `ConditionalGraphNode` com expressão `{{ gte score 0.5 }}` para roteamento explícito.
- A execução em streaming emite eventos: início, nó iniciado/concluído e `ConditionEvaluated`.


