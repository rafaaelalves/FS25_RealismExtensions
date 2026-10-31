# Integração causal do terreno — implementação 25/10/2026

Status: código entregue **somente** na branch experimental da PR #64. Não integrado à main, não certificado em FS25 runtime real. Registro de execução após a revisão da física com o usuário.

## Corrigido: escavação enquanto há implemento trabalhando

O R9/R1 antigo aplicava `TerrainRecovery.isRutGenerationSuppressed` a **todo o veículo-raiz** quando um cultivador ou arado estava ativo. Isso incluía rodas do trator *antes* da faixa efetivamente trabalhada, impedindo deformação permanente em situações extremas de tração. A branch causal agora não usa veto global por combinação. Continua a proteção espacial `isRecentlyCultivated` dentro das células de terreno realmente trabalhadas por GIANTS, com janela curta já existente (8s), para não reconstruir e reescavar exatamente a mesma superfície na mesma operação. O modo legacy continua com veto global até remoção futura. MR/Mud nunca foram desativados pelo antigo veto: ele só afetava escritas RE.

Teste de regressão em `tests/terrain_recovery_harness.lua`: veto legacy, autorização causal fora da faixa e proteção dentro dela. **Não é prova de terreno extremo no jogo**.

## Evidência das operações nativas, não intenção

`TerrainDeformationEngine` registra:
- `TerrainFreezeState`, no máximo 8 transições, o booleano vindo de Mud via RC, temperatura atual de ar GIANTS se disponível, umidade física e posição. Não presume temperatura do solo.
- `TerrainNativeDelta`, no máximo 6 ocorrências de aumento de profundidade maior que **2 mm além do pedido** na mesma operação: posição, pedido, deslocamento máximo real dos vértices (after-read do journal), nº de vértices, wetness, freeze, pressão e slip. Isso testa desajustes como pedido <=3mm vs execução de dezenas de mm. O valor é **máximo observado entre amostras da transação**, não volume escavado.
- No resumo de 60s `TerrainHealth` valores de actual-max somado por evento, requested somado nos mesmos eventos, desvios e contextos congelados, sem religar a telemetria de 5s. Não combinar soma de eventos com profundidade individual.

Teste `tests/terrain_deformation_engine_harness.lua`: pincel solicitado de 3mm, callback simulado de 12mm, verifica que detecção não pressupõe 3mm.

**Não removido:** teto provisório 10cm / proteção de concavidade 12cm. Ainda podem bloquear um pincel inteiro. Decisão de substituí-los depende da correspondência real por operação. **Não assumimos erro no motor** somente porque amplitude aparentemente maior: footprint/recuperação colateral ou outra alteração nativa podem coexistir.

## Migração do manutenção territorial (funcionalidade existente)

Reaproveitada a `TerrainMaintenancePolicy` antiga, com limites territoriais e distinção:
- NPC vizinho: ciclo `PERIOD_CHANGED`, pelo menos **1 período** após o último dano.
- Prefeitura: mínimo de **2 períodos**, apenas área pública com tinta DIRT/GRAVEL em toda região.
- Player/private, outro humano e terreno comprável sem dono: **não recebem manutenção automática**.
- `TerrainCausalMaintenance.lua` usa o envelhecimento já persistido em `SpatialHistory.maintenanceAgePeriods`, varre somente a lista esparsa de histórico (não o mapa), deduplica por vértice principal, procura `TerrainGeometryJournal:getRecoverablePoint` verdadeiro e insere a fila física do mesmo `TerrainCausalRecovery`, fator inicial 0.50 NPC / 0.30 prefeitura.
- Máximos por período 128 NPC + 64 prefeitura, TTL 120s para manter custo bounded; uma operation in-flight por vez no mesmo writer.
- **Verifica novamente a classificação de propriedade, limites e tinta pública no momento de executar**: uma venda ou terraplanagem posterior não autoriza um TARGET antigo.
- Falta de baseline, alteração externa, altura inesperada ou conflito de roda impedem escrita. Não usa estimador anular nem reverte topografia natural/inventada.
- `TerrainMaintenance=false` continua; `TerrainCausalMaintenance=true` apenas na branch experimental. Portanto **não existem dois atuadores autônomos concorrentes**.
- Testes `tests/terrain_causal_maintenance_harness.lua` e `tests/terrain_causal_recovery_harness.lua` cobrem período, propriedade, classe pública, missing baseline, duplicação, autorização na execução, callback/resultado físico.

## Limitações explicitamente abertas

1. Meses simulados só reparam referências **RE-owned** (não antigas sem baseline, naturais, TerraFarm). O mecanismo é manutenção segura, não terraformação sem autoria.
2. Falta medir comportamento em runtime do agendamento mensal e a coexistência com mud/AI em mundo real (harness não substitui FS25).
3. A recuperação da vegetação e rastros visuais não é automaticamente a mesma que a altura principal registrada.
4. Simplificação de congelamento vem do Mud 1.3.7.0 e RC; `TerrainFreezeState` ajudará a verificar valor de temperatura concreto. Não codificar exceção regional.
5. Profundidade física profunda/berms ainda exige solução causal mais forte do que TARGET parcial e cap fixo. **Não interpretar esta integração como validação final de release.**
6. Pontos não examinados por TTL/cap de fila continuam históricos; podem ser reavaliados nos períodos seguintes. `TerrainWorldMaintenance` distingue fila, política e vetos.

## Próximo gate prático

Não pedir que o usuário destrua o próprio campo novamente. Uma sessão casual com progressão de mês, em área danificada conhecida fora da propriedade, fornece `TerrainWorldMaintenance` e callbacks `TerrainHealth` necessários para certificar agendamento. Quando houver evento de congelamento ou roda patinando no extremo, as primeiras linhas `TerrainFreezeState` e `TerrainNativeDelta` identificam causa sem bateria repetitiva. Construção/CI passa apenas teste de código; jogo exige confirmação antes do merge.
