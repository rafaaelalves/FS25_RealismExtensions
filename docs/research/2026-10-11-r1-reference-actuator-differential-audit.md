# R1/R7 — análise diferencial: referência geométrica vs atuador TARGET

**Data:** 2026-10-11 (log iniciado 2026-10-10 23:49 local).  
**Estado:** reprodução matemática e plano de verificação **sem mudança da física em runtime**.  
**Fonte primária:** `log(20261011-025925).txt` (~3.140 linhas) e `ModMixer(20261011-025925).log` (142 linhas), comparados ao relatório de 2026-10-10 com dano S780 acumulado.  
**Executável instalado:** RE `feat/terrain-pto-integration-2026-10-09@3e3554a43d1c3c6b3305d609a799d8ffb48a7ca4` / RC `main@ad7461fb7777691f6f64e2327753417c95b6177b`, FS25 1.24.0.0. A PR experimental de performance #40 **não está instalada**.

## Evidência do log, sem supor causalidade

- Carregamento de `savegame2`: `restored terrain history cells=12258`. A sequência anterior salvou exatamente 12.258 células. A persistência do sidecar e o import foram confirmados; comparar geometria antiga requer o save original e captura física.
- Trabalho `SHALLOW_DISC`, 2.234 work areas confirmadas, `TerrainRecovery v32R7 calls=2236 worked=2234 intentCells=23462 intentPoints=8298 intentEmpty=637 intentMaxRut=0.150m`. `TerrainPass`: quatro passagens fechadas; uma distância longa reportada `252.33m` e 1.958 calls, mas não confundir `causalCells` com células únicas de dano geográfico.
- `TerrainRecoveryTarget scheduled=4779 applied=1554 complete=88 stalled=468 targetComplete=32 noOp=1043 improved=466 worsened=30 initialPositiveSkip=56 lowConfidence=0 signCross=5 residualReduce=8.7739m residualWorsen=0.1554m maxAbs=0.8917->0.8707m`. Total de elevação no centro `centerRaise=9.2498m` em soma de muitos callbacks; `centerLower=0.0833m`; `patch=7628/86 retained=7542 sampleFail=0 patchDepth=0.7355m patchMaxResidual=0.8544m`.
- O writer reporta `geometryProbe=1554`, `zeroProbe=1043`, `targetRaised=486 targetLowered=25`, `failedJobs=0`, `targetJobs=1554`; soma 486+25+1043 = 1.554. Os 1.043 `noOp` do controlador coincidem exatamente com as 1.043 alterações de altura menores/iguais a 0.00005m medidas pelo writer. **Pista principal:** grande parte dos no-op é ausência observada de mudança física no centro, não apenas diferença entre dois planos reajustados. Ainda não se conhece a razão pela qual a API TARGET não alterou aqueles centros.
- `TerrainPlasticYield supported=159 yielded=804 maxDemandBearing=8.87`. Pressão `110000..250000Pa`, amostra final `wet=0.90 slip=0.540 instantSink=0.311 persistentSink=0.150`; snapshots não correspondem necessariamente ao evento `maxAbs=0.8917m`.
- `TerrainDeformation runtime brushesAccepted=671 cells=12243 retired=141 enqueued=2225 submittedJobs=1846 failedJobs=0 modelRut=0.180m`. Novas rotas de rut e recovery coexistem; não misturar submits de ambos.
- Custo `recovery=2234 avg=0.4456ms total=995.5ms`; `flushInclusive=1749 avg=0.6347ms total=1110.2ms`. São timings agregados por callback da sessão, não estimativa de regressão FPS. `protectedMarks=213921`.
- ModMixer boot saudável (59 active, 0 unknown); oito erros `WoodGrinder` externos e erro `manualAttach delete(nil)` no encerramento. A lista de conflitos SCAN provém de dataset estático de junho.
- **Não há evento `Game saved successfully` nem `saved terrain history cells=` neste arquivo.** Houve `quit savegame`. Portanto, esta coleta comprova restauração do save anterior, **mas não** que as alterações da sessão tenham sido persistidas; não diagnosticar perda sem checar arquivos de save.

## Revisão de código: duas fontes de problema distintas

### A. Geometria/referência `RecoverySurfaceEstimator`
- `TerrainWriter.sampleRoughnessProbe()` mede centro + 16 pontos num anel de raio default `probeRadiusM` (R1 atual aprox. 1,25m). `RecoverySurfaceEstimator.fitReferencePlane()` ajusta plano aos 16 pontos por mínimos quadrados, corta supostos outliers com MAD num único passe, e mede residual central em relação ao plano.
- `inlierRatio` só testa consistência com um plano de amostras escolhidas; **não** informa se o anel inteiro está danificado nem se o relevo é curvo. `lowConfidence=0` não é certificação de reference correctness.
- `reconcileTargetPatch()` compara **todos** os centros históricos dentro do brush contra uma só estimativa planar local, sem armazenar quanto da referência estava em área de dano histórico ou em berma. Isso pode manter dívida legítima em áreas extensas e dar resíduo sem significado de "profundidade do sulco".

### B. Comando nativo `TerrainWriter.TARGET`
- `TerrainWriter:_submitBatch()` chama `setHeightTarget(minY,maxY,nx,ny,nz,d)` no plano ajustado, `setAdditiveHeightChangeAmount` e `enableSetDeformationMode`.
- `TerrainRecovery` mede antes, enfileira TARGET serializado, mede depois, conta tolerância/ausência de mudança e aumenta intensidade de 0.75 para 0.85 quando não há efeito; 30 eventos classificados `worsened` também merecem inspeção.
- **Não inferir automaticamente que o modo TARGET é bugado:** o job pode completar com sucesso mas deixar o centro inalterado por resolução da heightmap, geometria coberta por brush, altura alvo, restrições do motor ou limitações da API. Falta uma amostra causal com centro/plane/target registrados no mesmo callback.
- `maxAbs=0.8917m` e `patchMaxResidual=0.8544m` são distâncias em relação ao plano estimado, não ensaio da profundidade máxima da vala nem prova de buracos RE acima de `modelRut=0.180m`.

## Reprodução exata em Lua do estimador atual (sem engine)

Harness: `tests/recovery_reference_stress_harness.lua`, usando `RecoverySurfaceEstimator.lua` real, 16 pontos no raio 1,25m, plano inclinado base `y=10+0.02x-0.015z`. Cenários construídos com profundidade física conhecida:

| Forma | Defeito verdadeiro (m) | Estimado pelo modelo atual (aprox.) | O que demonstra |
|---|---:|---:|---|
| Plano inclinado intacto | 0 | 0 | Controle correto |
| Sulco pontual 12cm | 0.12 | 0.120 | Controle correto |
| Sulco longitudinal estreito 12cm | 0.12 | 0.120 | Variação pouca sob anel limpo |
| Dois sulcos paralelos 12cm | 0.12 | 0.068 | Anel contaminado subestima dano |
| Depressão larga 12cm | 0.12 | 0.074 | Anel dentro da própria bacia subestima |
| Relevo natural de curvatura com centro sem dano | 0 | 0.120 | Falso positivo quando a superfície não é planar |
| Curvatura sintética extrema (não representativa de um campo comum) | 0 | 0.850 | Resíduos enormes podem existir matematicamente sem sulco RE; **não atribuir isso ao jogo sem evidência espacial** |

Na curvatura perfeitamente simétrica, `boundaryInlierRatio=1.0`: o filtro de outlier não tem mecanismo para reconhecer que a referência é inválida. Estes números são resultados da reprodução independente da fórmula em Python; o harness Lua verifica cenários correlatos com o código-fonte usado na build.

## Experimento de engenharia recomendado (sem nova build neste momento)

1. **Fechar gate offline**: executar stress harness real no CI, inspecionar os erros obtidos, separar falhas de referência (dados insuficientes/contaminados) de falhas de atuador (nenhuma mudança no centro).
2. **Projetar ReferenceConfidence v2** sem sobrescrever original: considerar histórico espacial de dano nas posições do anel, consistência em raios independentes, curvatura local vs inclinação, geometria de duas trilhas; se confiança insuficiente, não nivelar nem apagar débito por mera referência estimada.
3. **Projetar NativeTargetOutcome v2**: reason codes por job (CENTER_UNCHANGED, TARGET_REACHED, REF_CHANGED, CENTER_RAISED, ENGINE_REJECTED, PATCH_STILL_DEFORMED etc.), com diagnóstico estritamente amostrado/sob demanda e limites de custo.
4. **Somente então** decidir algoritmo de reconstrução. Evitar aumentar raio/força TARGET às cegas ou mapear `modelRut` diretamente à altura absoluta do terreno.
5. **Próxima build apenas após revisão do plano**; primeira candidata deve ser diagnóstico reversível para distinguir causadores do no-op em coordenadas reais. Manter experimento de ContactFootprint v2 separado e PR #40 de performance sem merge nesta pesquisa.

## Critérios para aprovação futura

- Sulco profundo e longo recebe estimativa de referência plausível, sem contaminação por sua própria segunda trilha; inclinação natural/curvatura não induz recuperação indevida.
- Nenhum TARGET apaga dívida causal sem melhoria geométrica verificável e estabilidade do plano escolhido.
- 2D patch não elimina bermas/autoria externa inadvertidamente.
- Job nativo com centro inalterado reporta razão diagnóstica suficiente para diferenciar motor, superfície, limite de brush e posição.
- Perf e eventos críticos agregados não se degradam; aprovado apenas após comparação controlada no mesmo backup.

**Conclusão:** o log novo justifica **pesquisa e instrumentação planejada**, não hotfix especulativo. A distinção entre no-op real e plano enviesado é a condição para avançar com segurança.
