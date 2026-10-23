# RE — Telemetria de release e diagnóstico após os logs 18h09 (2026-10-23)

**Evidência:** jogo FS25 1.25, `log(20261023-180959).txt` (9.596 linhas), `ModMixer(20261023-180958).log`. RE `64/merge@2b72d682` / Actions `39995126791`, RC presente. Avaliação específica do uso real; decisões de engenharia aplicadas na draft PR #64, não na main.

## Defeito confirmado — não era apenas solo insuficientemente molhado

- `TerrainDeformation=ENABLED`, mas `TerrainCausalRecovery=false` na build utilizada: todos os 845 TARGET executados foram **R1/R7 legado**, não o novo solver. 778 TARGET (92,1%) não moveram o centro; `targetPlane` nunca demonstrou fechamento profundo jogável.
- `getTerrainHeightmapUnitSize(nil)` no loadMap: `TerrainGeometryJournal.lua:19` é invocado com `g_currentMission.terrainRootNode=nil`; o binding C++ emite erro mesmo quando `pcall` tenta capturá-lo. Cria instância de journal sem `unitM`, e toda nova operação de LOWER fica bloqueada, com `brushesAccepted=0`, apesar de `wheelspinCandidates=4373` e `TerrainPlasticYield supported=16143 yielded=4861`. **Isso invalida interpretar ausência de sulco como sucesso de ajuste de umidade/bearing.**
- `TerrainPersistence.lua:230 setXMLFloat(...nil)` durante save depois de gravar histórico mecânico. `saved native geometry journal cells=0` não significa que células físicas foram monitoradas; nenhum baseline geométrico recuperável existia nessa sessão. Há `Game saved successfully (savegame2)` às 15:02:26, mas não há journaling confiável desse ensaio.
- `TerrainRecoveryTools`: SHALLOW_DISC 316, SUBSOILER 304, PLOW 225 TARGETs; nem mudança de implemento resolveu o comportamento. O `TerrainReferenceV2` rejeitou 1524 referências e aceitou 916, condição secundária de legado.
- RC `FarmKitCompatibility` relata suppressions do wheel/ground core = 1; sem evidência de que FarmKit está criando os sulcos nessa sessão. Erros de especializações CBI6800CT e `manualAttach` são externos, não explicam falha RE.

## Problema da observabilidade antiga

- RE produziu 6.976 linhas de log; havia **317 cópias** de cerca de 20 linhas cumulativas por janela de 5 segundos, independentemente de mudanças ou trabalho útil. Total ~6.300 linhas de status repetitivo num teste curto.
- O log não declarava claramente `causalRequested`, `journalReady/unit`, `geometryJournalDeferred`, `LOWER confirmed` e `CausalRecovery` no mesmo resumo. O usuário pôde testar intensamente o código certo instalado, mas o **solver novo errado/desativado**.
- Cumulativos (ex. `TerrainRecoveryTarget scheduled=5309`, `applied=845`) não equivalem a áreas únicas ou melhoria física. Diferenciar pedidos, envio, callbacks, mudanças reais e resultado visual.
- `TerrainSinkHandoffProbe` é PROXY e não uma medida de buraco/volume real; preservar para pesquisa, mas não usar como indicador principal de aceitação. `reGeoMark/reGeoSnap` permanece on-demand e read-only.
- `VisualTrackCapture` 288.895 pontos com 261.951 deferred, `AIVisualTracks` 147.931 chamadas: candidato posterior para análise de custo, mas não ajustar sem profiling/bug visível. PTO (14 registros de requisitos nesta sessão) não exige redução adicional.

## Mudanças no código (branch experimental)

1. Guardas de nó válido no `TerrainGeometryJournal`, e `TerrainRuntime.tryInitializeGeometryJournal()` chamado em `Core.update` até o terreno existir; importar a sidecar apenas uma vez, **antes de deformação e tillage**.
2. Save da journal rejeita `unitM=nil` antes de criar XML. Os testes automatizados cobrem nil native handle e sidecar inválida.
3. `Config.diagnostics`: por padrão `stabilization`, `verbose=false`, timing caro desligado e janela reservada de pesquisa 60.000ms; **não apagar** contadores e probes. Reativar verbose para análises curtas explicitamente.
4. Novo `TerrainMode` na inicialização + `TerrainHealth` compacto a cada 60 segundos no jogo, reportando causal on/off, native unit/journalReady/pending, jobs físicos/lowering efetivo, requests bloqueados, recuperação candidate/queue/callback/improvement/collateral/error, writer failures.
5. `TerrainCausalRecovery.getDiagnostics()` disponibiliza snapshot de resultados. In-game comandos de geometria permanecem opt-in.
6. Somente a **branch experimental** activa `TerrainCausalRecovery=true` e isola `TerrainMaintenance=false`. A main permanece com TerrainDeformation desativada. A nova rotina não repara sulcos de história **legada sem baseline geométrica confirmado**: este é limite explícito, não defeito inesperado.

## Critérios de release e follow-up

- Não fazer micro-otimizações (buffers, coalescing, sampling rate) antes de comprovar geração e recuperação física. Exceção: cortar telemetria repetida e evitar chamadas com ponteiro nil.
- Curto teste **num clone do backup pré-RE** para criar sulco novo e recuperá-lo com preparo apropriado. `TerrainHealth` deve mostrar primeiro `journalReady=true`, `wheelAccepted>0`, `lowered>0`, depois `recoveryCandidates>0` e `improved>0`. Ainda é necessário medir geometria e percepção; contador não basta.
- Corrigir resultados incompletos específicos, não pedir dezenas de passadas de forma cega. Se `wheelAccepted=0` com journalReady verdadeiro, estudar gating real do modelo; se `accepted>0, lowered=0`, estudar brush nativo; se `lowered>0` mas sem `recoveryCandidate`, estudar footprint/epoch; se `improved>0` sem melhora visual, estudar canal de deslocamento e geometria 12,5 cm.
- Preservar os saves atuais; o sidecar anterior do teste com `unitM=nil` **não é fonte confiável de restauração**.

**Limite da evidência:** as correções passaram CI nos harnesses que simulam GIANTS, mas **não foram validadas em jogo com a nova build**. Nem o fenômeno de chuva nem a nova recuperação estão aprovados para release.