# FS25: terceira coleta de recuperação R1 e primeira observação de tráfego da semeadora Avatar

**Coleta:** `log(20261012-024842).txt` (~3.797 linhas) e `ModMixer(20261012-024842).log` (142 linhas). Relógio do log 2026-10-11 23:40:49–23:48:19; operação instrumentada de 23:42:25 a 23:48:16.  
**Código executado:** RE `feat/terrain-pto-integration-2026-10-09@3e3554a43d1c3c6b3305d609a799d8ffb48a7ca4` e RC `main@ad7461fb7777691f6f64e2327753417c95b6177b`. **Nenhuma** das mudanças de PR #40 ou #42 está no ZIP.  
**Save:** `savegame2` restaura `12258` células RE da sessão anterior; **nenhum** novo `saved terrain history` nem `Game saved successfully` neste log; `quit savegame` antes de soft restart. Não inferir que as novas deformações foram persistidas.

## Continuidade física: grade / SHALLOW_DISC

- Trabalho comprovado pela interface GIANTS `CULTIVATOR / SHALLOW_DISC`: 5 passagens fechadas, perfis com larguras 3.97..4.00m e 3.15..3.18m de profundidade geométrica de work-area (não é profundidade agrícola).
- `TerrainRecovery calls=3087 worked=3082 intentCells=17857 intentPoints=8082 intentEmpty=1154 intentMaxRut=0.091m changed=1177 repeat=1905 protectedMarks=295839`.
- `TerrainRecoveryTarget scheduled=4397 applied=1774 complete=96 stalled=508 targetComplete=68 noOp=1114 improved=583 worsened=33 initialPositiveSkip=28 lowConfidence=0 signCross=3 maxAbs=0.6061->0.5677m patch=6414/145 retained=6269 patchMaxResidual=0.7997m`.
- `TerrainWriter geometryProbe=1774 zeroProbe=1114 targetRaised=627 targetLowered=33 failedJobs=0`. Conferência `1114+627+33=1774`, igualdade da categoria noOp e ausência de alteração mensurável de centro na mesma sessão (sem provar uma causalidade individual com logs agregados). **62,80%** de TARGETs ficaram sem deslocamento central acima do limiar `0.00005m`, então tanto o problema do atuador quanto a correção da referência precisam de análise individual. As diferenças de `maxAbs` não são provas de crateras de 60cm/80cm; referem-se ao plano local estimado.
- `historyRecoveredCells=174 historyRecoveredDepth=1.234m` são operações/débitos agregados, não metros de altura real em um ponto. Performance: `recovery=3082 avg=0.4114ms max=0.850ms total=1267.9ms`; CPU acumulada, não FPS.
- Perfil `SHALLOW_DISC` do código tem `targetAmount=0.65 targetAmountMax=0.85 maxStructuralPulses=4`. Portanto o observado `amountMax=0.850` está **de acordo com a política intencional da ferramenta**, não prova de que o controlador esqueceu um máximo genérico `1.00`.

## Novidade: trator + Horsch Avatar 12.25 SD após recuperação

A Avatar 12.25 SD é uma semeadora de plantio direto por descrição do fabricante e FS25, confirmada adicionalmente pela carga `data/vehicles/horsch/avatar1225/avatar1225.i3d` neste log. Referência ModHub: https://www.farming-simulator.com/mod.php?mod_id=357162 . **Porém o log RE não tem contador específico de `SowingMachine.processSowingArea` nem confirma explicitamente que sementes foram depositadas durante toda essa janela.** Comprova contatos/escritas causadas pelo conjunto.

- 23:45:21: recuperação terminou; TARGET aplicado estabilizou em `1774`, e ficou assim até sair.
- 23:47:46: `brushesAccepted=148` durante estágio sem atividade recente de recuperação; `RutWriters=[Fiat=144, MR980=4]`.
- 23:47:51: `brushesAccepted=166`, só Fiat.
- 23:47:56: `brushesAccepted=430`, `Fiat=401 Avatar=25 MR980=4`.
- 23:48:01: `brushesAccepted=568`, `Fiat=533 Avatar=31 MR980=4`.
- 23:48:06: `brushesAccepted=968`, `Fiat=861 Avatar=103 MR980=4`.
- 23:48:11: `brushesAccepted=1389`, `Fiat=1194 Avatar=191 MR980=4`.
- 23:48:16: `brushesAccepted=1431`, `Fiat=1200 Avatar=227 MR980=4`.
- **Acréscimo 1283 brushes em ~30s após baseline 148**, dos quais 227 são atribuídos diretamente ao rodado da semeadora; os restantes novos são predominantemente do trator. Logo não chamar os 1283 de 'brushes da Avatar'; são do **conjunto** e não temos a faixa trabalhada nem o número de células distintas nessa janela.
- `TerrainWindow 5000ms` nesses intervalos: `work=0 callbacks=0` de recuperação, `rutAccepted=18,264,138,400,421,42`. Isso confirma a sequência **após** a última grade, não que cada um desses pontos seja na exata mesma parcela recentemente cultivada.
- Amostras cronológicas `wet=0.63, 0.67, 0.56, 0.71, 0.71, 0.75`. `instantSink` até `0.358m`, `persistentSink` no snapshot de 23:48:11 `0.158m`, `modelRut` máximo acumulado `0.180m`, sem prova de sulco visual 18cm sob Avatar. Não tomar `maxInstant=0.360m` como heightmap nem umidade amostrada como média do campo.
- `TerrainPlasticYield supported=2432 yielded=1441` amostras classificadas. O gate não imuniza semeadoras, corretamente. **Ainda não há teste de aceitação comparável em solo normal/portante**, e tampouco vídeo/foto visual desse local. Não aumentar nem reduzir envelopes de bearing sem separar umidade, carga/pressão, estado prévio e confirmação de trabalho de semeadura.
- 23:48:16: `cells=12946 retired=174`, `brushesAccepted=1431 enqueued=3205 coalesced=96 submittedBrushes=3109 submittedJobs=2045 failedJobs=0`. A soma inclui writes de rut e R1: não subtrair diretamente `submittedBrushes` de `brushesAccepted`.

## Mudanças na stack e compatibilidade

- TerraFarm passou de `1.6.3.0` da coleta anterior para `1.6.5.0`. Release upstream oficial https://github.com/scfmod/FS25_TerraFarm/releases : atualizações entre elas orientadas a lógica de descarga e escavação, não há declaração de alteração do `setHeightTarget` RE; **não** afirmar paridade de implementação sem diff exato de código e build instalada.
- MR `0.26.10.08`, Mud `1.3.6.0`, Reifen `1.2.2.70`, RMS `0.11.0.0` e SoilCompaction `1.0.0.0` continuam na stack reportada (checar `Loaded mod` para saber ativo vs disponível).
- RC `MRMudDraft draftCalls=4968 overrides=703 wrapperLost=0`, evidenciando contrato de trabalho em solo, mas não demonstra correctness de recovery nativo. `MRMud localWetnessOverrides=37237`; `ExtensionsStateProvider wheelContexts=10811`. `MRPTO stateHits=61266` independente do resultado da grade/semeadora.
- ModMixer: 59 active chain targets, nenhum unknown, watchdog healthy; dataset SCAN junho/2026 continua sem equivaler a conflito novo. Oito erros antigos de `FS25_CBI6800CT.WoodGrinder` e `manualAttach/src/core/DetectionHandler.lua:65 delete(nil)` no encerramento são externos e permanecem sem evidência de ligação com R1.

## Decisões de engenharia (não executar hotfix)

1. **P0/A — ReferenceConfidence v2**, já caracterizado pela PR #42: hoje o anel de 16 amostras pode subestimar depressões largas e produzir falsa vala em terreno naturalmente curvo. Não é suficiente para explicar todos os 1114 no-op da engine, que são fisicamente observados.
2. **P0/B — NativeTargetOutcome v2**: adicionar diagnósticos amostrados por comando, gravando `candidate.x,z`, altitude central antes/depois, alvo e distância ao plano fixado, `pre/post` em mesmo referencial, outcome (sem altura, fallback, quantização, outro motivo). Não confundir job criado sem alteração real com erro de callback.
3. **P1 — Seeding traffic v1**: contrato de observação explícito para determinar se `SowingMachine` realmente processou área e correlacionar RUT com mesma faixa onde aconteceu `SHALLOW_DISC`; registrar categoria de solo/umidade/pressão, raiz/roda/implemento sem log por frame. Isso separa reabertura do ciclo agrícola sob solo úmido de comportamento legítimo por tráfego.
4. **P1 — compare TerraFarm 1.6.3 vs 1.6.5** em revisão de fontes exatas apenas se surgir plausibilidade de impacto no atuador; evitar atribuição espúria. Otimização de broadphase #40 isolada sem nova instalação.
5. **Build:** manter RE `3e3554a`; não gerada nova ZIP de gameplay por este relatório. Branch de pesquisa não modifica `scripts/`, `Config.lua`, nem a main. O usuário deveria avaliar visualmente se semeou, em qual faixa e como ficou o terreno, mas é possível seguir projeto de observabilidade fora do jogo sem exigir testes agora.

**Status:** persistência reload confirmado; TARGET não convergente confirmado novamente; primeira observação de tráfego da Avatar pós-grade confirmada; funcionamento efetivo de semeadura e localização exata de novos sulcos em faixa tratada **pendentes de correlação**, não de estatística genérica.
