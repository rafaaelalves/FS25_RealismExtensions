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

### FK/GIANTS area metric sanity caution

The first observed total `processedAreaUnits=17,276,396` includes `repeatAreaUnits=16,783,700`, and the final cumulative `processedAreaUnits=18,180,630` includes `repeatAreaUnits=16,799,348`. Each anomalous repeat sum is close to `2^24=16,777,216` plus a comparatively small residual (6,484 / 22,132). Do **not** present those aggregated raw return values as actual square meters or work-footprint coverage. GIANTS returns `changedArea, totalArea` from the cultivator according to public scripting docs, but the reason for this enormous observed number could be an upstream mod return, a packed/sentinel flag, or a different runtime path. **Root cause not established, no arithmetic stripping of `2^24` without evidence.** A1 therefore tracks physical travel separately and keeps raw work-area returns diagnostic-only. If a later pass dose policy requires true worked area, derive it independently from geometry and spatial traversal instead of trusting these sums.

## 2026-10-09 — segunda execução em jogo, RE/RC v2 conectados (07:19–08:12)

**Evidência de execução:** `log(20261009-111226).txt` e `ModMixer(20261009-111226).log`. RE `35/merge@b70844e0` / build `37907660785`; RC `16/merge@001774b3`. **O teste efetivamente carregou o commit de merge da PR, não a SHA literal da branch; os artefatos podem divergir no tempo, portanto sempre registrar BuildIdentity.** 

### Confirmação de correção do handshake

- Log: `normalized state provider active: FS25_RealismCompatibility` **uma vez**, sem nenhum `provider unavailable/version mismatch`. RC v2 `ExtensionsStateProvider` registrou **210.535 `wheelContexts`**, dos quais 176.287 chegaram à `FootprintModel` do RE com `footprint=176287/176287`.
- RC atual `MR+Mud`, `MR+RMS`, `Mud+RMS`, `MR+TireWear`, `Mud+Soil`, `FarmKitCompatibility` = ACTIVE; `PTO API not loaded` é **fora do escopo desta branch**.
- `Footprint runtime`: `wideSupport=0`; RC relatou `multiSupportContexts=54`, `crawlerContexts=0`. Isto **não valida** contato multibanda e esteiras; o modelo RE ainda é um patch pneumático agregado (e não sabe usar `supportSegments`).

### A1 passes agora têm observação real

O trabalhador criou **10 passes SHALLOW_DISC, todos encerrados com `IDLE`**; #1 parcial de 244,79 m/117,09 s e #2–#10 com deslocamento aproximadamente 796,69–812,52 m. Média de velocidade variou entre 7,56 e 12,83 km/h; `causalCells` passou de 7 a 106. Exemplo #10: 802,13 m/231,03 s, 4.763 callbacks (4.613 changed e 150 repeat), 106 células causais observadas.

**Aceite parcial A1 (observabilidade):** contador de passagens, movimento e identidade da ferramenta funcionando em gameplay prolongado; dezenas de callbacks por segundo não geram centenas de falsos passes. **Não aceitar ainda** A1 como dose física invariante de FPS/velocidade, pois o cooldown/atuador R6 não foi alterado. `IDLE` em curvas é esperado quando GIANTS deixa de emitir work-area por intervalo; investigar apenas se usuário notar passagens aglutinadas/desmembradas incorretamente.

### R6/R7 recovery voltou a executar fisicamente

- `TerrainRecovery`: 58.965 callbacks de trabalho, 20.518 pontos candidatos, 2.072 TARGETs aplicados com callback; 10.611 `SHALLOW_DISC scheduled` de ferramenta e 12.016 `structuralScheduled` são contadores de categorias distintas e **não são todos writes realizados**.
- `Target`: 862 execuções com melhora de déficit, 89 com piora, 1.048 no-op, 295 pulos por sinal positivo e 13 cruzamentos de sinal. Soma `residualReduce=24.3487m` versus `residualWorsen=0.3389m`, `centerRaise=25.1358m` versus `centerLower=0.3479m`. Essas somas são de medições/atuações em amostras distintas, **não** relevos ou volumes de terreno em uma única célula; não converter para `m³`.
- `targetPlane complete=181`, `structuralCompleted=476`, `structuralStalled=594`: categorias de estado diferentes, não assumir contagem única de passes ou falhas. `TARGET noOp` não significa necessariamente um bug: limites de geometry/probe/oversmoothing e ausência de deslocamento observável precisam de contexto.
- `targetPatchCellsExamined=9103`, `converged=389`, `retained=8714`; `patchRecoveredDepth=2.1674m`, `historyRecoveredDepth=3.962m`. Convergência ainda **não declarada completa**, especialmente para ruts com `patchMaxResidual=0.7134m`. Pioras identificadas, mas **nenhuma justificativa ainda para mudar TARGET** sem seleção de células e medição antes/depois (slope legítimo versus patologia).
- RE `queue=0`, `failedJobs=0`, `inFlight=0`, `timeouts=0` no fechamento; save retornou sucesso. História carregada `49.913`, salva `49.898` células, número líquido não prova por si só conservação física.

### Segurança de deformação/atividade AI — **invariante em aberto**

- `activeCultivatorRutSkips=781853`, `activeQueries=809602`, `activeHits=781853`, `cultivationProtected=1894`. A proteção está sendo acionada significativamente.
- `rutAccepted=20095` no total, com writer roots `7R_310__Cultivo_6_=20053` e `7R_310=42`. Pela atribuição `TerrainActors`, `AI_FIELD=20049 brushes`, `PLAYER=46`; não tratar os 20k como violação automática. Existem **19 janelas de 5 segundos** nas quais `work>0` e `rutAccepted>0`, tipicamente nas transições de uma passada e manobras. Janelas agregadas não demonstram que as mesmas células/superfícies tinham ferramentas de trabalho ativas no instante da aceitação.
- **Próxima medida A2 prioritária:** atribuir writer accepted à combinação/root e a `passId` efetivos, com período de atividade e work footprint real, e declarar `rutAcceptedWhileActive==0` apenas com correlação espacial+temporal. Não fazer veto global a deformação de IA.
- `TerrainActors`: 804.290 amostras AI, 20.049 brushes/57,363 m somados de profundidade; estes números não medem danos reais por hectare ou intensidade de dificuldade.

### Performance/estabilidade e integração residual

- `TerrainPerf`: update de veículo média 0,0305 ms, máximo 1,884 ms; recuperação por callback de work-area média 0,8064 ms, máximo 1,980 ms; flush média 0,4172 ms, máximo 1,231 ms. São **tempos por tipo de chamada**, não média/frame nem percentis P95. Volume cumulativo e tamanho do save devem ser monitorados, sem alegar uma regressão de FPS a partir da média.
- `VisualTrackCapture`: 667.827 pontos observados, 102.714 aceitos, 602.630 deferred, 32.787 cuts; `TireTrackProbe` integrity=true, observerErrors=0, drift=0. Contadores de filtro/diferenças, **não** prova de vazamento; futuros perf/save gates exigem observação de memória/artefatos.
- RC `[MRMud] Integrity pointer drift ... widthRadius=false` uma vez. A inspeção de `MRMud.lua` confirma que compara igualdade da função top-level `WheelPhysics.serverUpdate`; wrappers externos instalados depois podem mudar o ponteiro sem eliminar a chamada via `superFunc`. `supportWidthRadiusCorrections=0` e `supportWidthMaxRatio=1` nessa sessão, que não exercitou cobertura wide (RE `wideSupport=0`). **Wrapper-preservation ainda não provado em todos os mods**; futura prova com pneu de múltiplos apoios e counters de execução, sem rewrap automático.
- FarmKit conservador RC: `wheelCore=external`, `groundCore=external`, `loadSpill=RealPhysics`, `plowSuspension=MR`. Nenhuma evidência de novo autor de terreno FarmKit.
- Falhas externas: 8 erros de especialização duplicada em `FS25_CBI6800CT.WoodGrinder` **durante o boot**, e `FS25_manualAttach/DetectionHandler.lua:65 delete(nil)` **depois do save**; não são falhas evidenciadas de RE. Houve aviso `AnimalPlanner` no encerramento. Não implementar remendos RC sem análise específica.
- A lista de conflitos SCAN do ModMixer é baseada em dataset **2026-06-01**; não elevar relatório estático antigo a incidente ao vivo.
- R9 manutenção por períodos e paridade MP **não foram exercitados/atestados por esta sessão**, assim como esteiras, duplos estreitos e comportamento de atolamento. Dificuldade física do campo não pode ser certificada por somas de rut/depth sem descrição visual do jogador.

### Decisão deste teste

**PASS** para handshake RCv2/RE e observabilidade passiva de passes; **PASS parcial** para writer/actuator efetivamente ativos e save concluído; **PENDENTE** para correlação causal A2, convergência geométrica por passagem, físico visual/slope, dinâmica do multi-apoio, R9 e estresse de frames/save. **Nenhuma alteração de parâmetros ou física autorizada**. A PR #35 continua aberta, sem merge automático, e PTO fora do escopo.
