# R10/A1 — TerrainPassTracker: observação de passagens físicas

Data: 2026-10-08  
Branch de implementação: `feat/terrain-pass-observability-2026-10-08` (base `feat/terrain-recovery`).  
Status: **primeiro incremento — observação não atuante / CI**, runtime GIANTS pendente. Sem mudança no sistema R6 de TARGET, `passageCooldownMs`, Writer, área agrícola, PTO, deformação, chuva, ou configuração física.

## Problema real

Os relatórios R6/R7 usam callbacks de `processCultivatorArea`/`processPlowArea` e janelas de 5 segundos. O mesmo trabalho pode gerar várias chamadas por frame/área; um repasse físico pode ter `changedArea=0` mas `processedArea>0`. Consequentemente não se deve equiparar `workAreaCalls`, jobs TARGET ou segundos à quantidade de passagens físicas.

## Implementação

`scripts/terrain/TerrainPassTracker.lua` é um observador pure-Lua:
- cada **implemento físico + operação** ganha `passId` monotônico em runtime, independente de outros implementos no mesmo trator;
- abre apenas quando `physicallyWorking`, `processedArea>0` e velocidade acima do limiar;
- várias chamadas de `workArea` no mesmo instante somam áreas mas **não** somam deslocamento/tempo;
- duração, distância real observada, velocidades mínimo/médio ponderado por tempo/máximo, chamadas iniciais/de repasse, áreas processadas e quantidade de células causais distintas vistas;
- trabalho que levanta, para, some sem callback ou passa por intervalo longo encerra a passagem por `INACTIVE`, `IDLE` ou `GAP`;
- `TerrainRecovery.update` faz um scan amortizado de inatividade de 250 ms mesmo se a fila de recuperação estiver vazia;
- contagem de células causais usa somente o mesmo stamp key que já alimenta recuperação, com teto estrito de 4096 chaves/passagem. Ao atingir o teto reporta `CAPPED` — *não* descarta a recuperação física.
- aproveita `rootVehicle.rootNode` para medir deslocamento e usa centro geométrico como fallback. Teleports > 30 m entre leituras são desconsiderados; isso é métrica, não limite de operação.
- `Recovery.getDiagnostics()` expõe `passStarted`, `passCompleted`, `passActive`, `passLast`. `Core` imprime `TerrainPass` somente quando uma passagem terminou desde a janela de diagnóstico anterior e modo verboso está ativo.
- `Recovery.resetRuntimeState` limpa toda a telemetria no carregamento de mapa, sem persistir passagens incompletas através de um save/reload.

**NÃO É AINDA:**
- um **atuador por passagem**: o timer/stamp existente continua mandando; isto evita alterar o mecanismo R6 fisicamente validado antes de comparar resultados;
- atribuição de todos os callbacks assíncronos a um `passId`: comandos deferred podem concluir depois que o trator já terminou a passagem; a próxima fase deve transportar explicitamente `passId` em envelopes autorizados com cuidado e manter constância física;
- resumo P50/P90 do relevo por passagem e `rutAcceptedWhileActive` por root: ainda precisamos casar logs writer/terrain por `passId` e ler resíduos físicos locais;
- um contador exato de metros se a rootNode/WorkArea não tiver transformação confiável; a queda para centroid deve ser reportada como baixa confiança futuramente.

## Testes existentes e novos

- Novo `tests/terrain_pass_tracker_harness.lua`: abertura e encerramento, multichamadas no mesmo frame, repasse `changedArea=0`, distância, média ponderada, grupos simultâneos no mesmo trator, timeout sem callback, memória limitada, teleporte, fake update inativo.
- `tests/terrain_recovery_harness.lua` passou a carregar o Tracker e validar que uma operação R7 cria um passId e que um callback de trabalho inativo finaliza a passagem.
- CI `.github/workflows/build.yml` já executa automaticamente todos os `*_harness.lua`, faz parse de todos os Lua, XML e empacota o ZIP. **A conclusão de CI deve ser conferida na PR**, nunca presumida a partir deste documento.

## O que observar no jogo, sem criar sessão artificial para cada detalhe

1. Cultivador em trecho com sulcos: uma sequência contínua gera `passStarted+=1`; vários callbacks dentro da mesma passada não somam deslocamento falso.
2. Elevar o cultivador, virar e baixar: a próxima passada incrementa `passId`.
3. Repassar área já cultivada: `changed=0` pode coexistir com `repeat>0`, enquanto recuperação R6 continua convergente.
4. Calibragem temporal: uma passagem equivalente com diferentes FPS não deve depender do número de callbacks na **observação**; a **dose física** ainda pode depender de `passageCooldownMs`. Não declarar A1 concluído fisicamente até resolver isso.
5. Nenhum sinal de perda de proteção `rutAcceptedWhileActive=0`, aumentos inesperados de TARGET ou tempo CPU.

## Seguinte passagem de engenharia — requer evidência

Depois de correlacionar `TerrainPass` com um log real:
- criar `RecoveryPassSummary` com identificadores imutáveis desde a autorização até conclusão deferred (não deduzir `passId` de carimbo global após encerramento);
- escolher uma política por cobertura física de cada célula, sem FPS/cooldown como gerador da dose, mas somente após A/B causal de tolerância, passagens e trabalho protegido;
- adicionar histograma de roughness/centerResidual condicionado a um passe;
- integrar `ContactFootprint` de grupos físicos como trilha independente, preservando pneus simples e separando largura de contato de colisor temporário FarmKit.

Documento de escopo: [roteiro estabilização](../project/STABILIZATION_ROADMAP_2026-10-08.md) e [Terrain Evolution Plan](../project/TERRAIN_EVOLUTION_PLAN.md).

## 2026-10-09 — primeiro log real, incompatibilidade RC/RE identificada

Arquivo observado: `log(20261009-084831).txt`. BuildIdentities do jogo: RE `35/merge@c849694d`; RC `16/merge@001774b3`. O provider RC publica `apiVersion=2`, `wheelContextVersion=2` (confere com `RC/scripts/api/ExtensionsStateProvider.lua`), mas a revisão inicial desta PR esperava apenas versão 1. O log repetiu `expected 1, got 2` a cada segundo. **A falha de ABI invalida o teste físico**, não os contadores básicos de passagens.

Os dois eventos observados:
- passagem #1 `SHALLOW_DISC`, `IDLE`, 405,25 m, 132,57 s, 11,05 km/h, 2.945 callbacks (2.906 changed + 39 repeat);
- passagem #2 `SHALLOW_DISC`, `IDLE`, 546,26 m, 232,77 s, 8,49 km/h, 5.339 callbacks (5.247 changed + 92 repeat).

O RE restaurou e salvou 49.913 células históricas, mas amostrou **0 contextos em 40.008 tentativas**, nenhuma deformação e nenhum TARGET. Nenhum candidato causal foi encontrado sob o implemento nessa sessão; mesmo com ABI corrigida, isso não provaria automaticamente falta de bug de recuperação: exigimos sulco causal na área para testar o atuador.

**Correção isolada nesta mesma branch, sem PTO e sem física:** `StateContract.lua` negocia explicitamente pares `(API=1,wheel=1)` e `(API=2,wheel=2)`. Não aceita outras versões ou pares mistos; `getWheelContext` verifica sempre a versão negociada em cada retorno. A v2 RC conserva `grounded`, `physicalGroundWetness`, `longitudinalSlip`, `wheelLoadN`, `structuralRadiusM`, `sinkDepthM`, `supportWidthM`, e **acrescenta** `supportSpanM`, `supportGapWidthM` e `supportSegments`. Essa mudança é compatível com o `FootprintModel` atual, que ainda não tenta modelar bandas separadas ou esteiras. O harness `state_contract_harness` foi ampliado para v2, v3 não suportado, pares mistos e context retornado com versão errada.

**Importante:** `RC 16/merge` anuncia bridges `MR+RE PTO FAILED (PTO API not loaded)`; isso é resultado esperado da combinação de branches escolhida pelo usuário para testar terrain, **não** autorização para editar PTO aqui. O coordenamento definitivo das branches ainda precisa de merge/rebase consciente; não devemos juntar PRs experimentalmente. Depois do CI desta mudança, **somente o próximo build** deve ser usado para validação da deformação.

Observações independentes no mesmo log (fora de escopo de reparo):
- `FS25_SeedSelect 1.0.0.1` é candidato à captura indevida de Y sem seeder; seu próprio ModHub especifica a exigência de implemento compatível; source exato não auditado.
- `FS25_manualAttach` lança `delete(nil)` no `deleteMap` após salvar/quitar o jogo (DetectionHandler.lua:65), uma falha real de teardown de mod externo, não de TerrainRecovery.
- ModMixer SCAN usa dataset histórico de 2026-06-01 para muitos conflitos; não interpretar todos como incidentes runtime recentes.
