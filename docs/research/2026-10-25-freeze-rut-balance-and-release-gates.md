# Terrain RE — reavaliação da física, limites, Mud/RC e critérios de release — 2026-10-25

**Natureza desta revisão:** estudo + reconciliação do código exato e logs, **não patch de física**. Não produzir uma build a partir da documentação. Fonte exata: `log(20261025-121052).txt`, `log(20261025-134011).txt`, `log(20261024-030459).txt`; RE `feat/terrain-native-transaction-v1-2026-10-23` (testado via PR #64 run 40018138687), RC `main` e o **ZIP do Mud System Physics v1.3.7.0** enviado anteriormente pelo usuário (`FS25_MudSystemPhysics (4).zip`). Base histórica: `docs/research/2026-10-23-terrain-recovery-release-reset.md` e `docs/project/TERRAIN_EVOLUTION_PLAN.md`.

## 1. REVISÃO DE FATO: o solo foi classificado como congelado, não foi comprovado gelo em São Carlos

RC `scripts/integrations/MRMudDraft.lua:localWetness`: quando `FieldGroundMudPhysics:isHardWinterFrozen()` informa verdadeiro, incrementa `hardFrozenReads` e **retorna 0 como umidade para esforço de implemento**. Isso ocorreu 8.042 vezes na sessão 13:40 versus zero na 12:10, com 443 leituras de umidade local na primeira e zero na segunda.

**Fonte exata Mud 1.3.7.0** `scripts/FieldGroundMudPhysics.lua`, `getAirTempC()` (c. 1187) e `isHardWinterFrozen()` (c. 1209): flag `freezeAllLayersInWinterEnable` default **true**, limiar `freezeAllLayersTempC` default **−2 °C**; lê `g_currentMission.environment.weather:getCurrentTemperature()`, fallback `temperatureUpdater:getTemperatureAtTime()`. **Não verifica estação, neve, geografia, granizo ou temperatura do solo**. Há configuração ajustável pelo usuário `fg_freezeAllLayersTempC`; valor ativo exato não consta do log. Outro módulo `scripts/MudPhysics.lua` define limiar próprio padrão **−1 °C**. Portanto, ausência de neve não refuta booleano, mas temperaturas/solo realmente congelados em São Carlos precisam de verificação, sobretudo se climas customizados entregarem número incoerente. **Não inferir que o solo natural realmente congelou.**

Fonte RC `scripts/api/ExtensionsStateProvider.lua:isHardFrozen/getPhysicalWetness` repassa o flag e, quando true, usa wetness=0 no RE; RE `TerrainPlasticYield.lua` multiplica capacidade de suporte ×8 e `TerrainResponseModel.lua` reduz susceptibilidade a `hardFreezeMultiplier=0.02` e bloqueia transferência de sink transitório para dano permanente. O Mud nativo zera wetness em `computeWetnessEffective`, e suprime determinados efeitos de roda. Isso é **cadeia de supressão compartilhada por fonte climática**, não RE reescrevendo a física do Mud. Não alterar parâmetros RE enquanto essa origem não for medida. Aparentemente o preparo ficou mais fácil e fez menos sulcos sem necessariamente mudar o clima real local.

RC investigação independente [#46](https://github.com/rafaaelalves/FS25_RealismCompatibility/issues/46). Sem modificar o código do Mud e sem copiá-lo.

## 2. Por que sulcos ficaram menores? Três mecanismos *diferentes*, não identificáveis por sensação isolada

### A. Condições/modelo físico

`TerrainResponseModel` usa pressão de contato, slip/shear, deslocamento, umidade local e parte conservadora da profundidade transitória reportada pelo Mud. `TerrainPlasticYield` agora exige `demandPa > estimatedBearingPa` (capacidade categorizada e parametrizada; ainda não ensaio físico). Há uma zona de transição wetness 0.42→0.96; não significa que UI 'molhado' informe diretamente `physicalGroundWetness` local. Em modo frozen, os efeitos acima praticamente param.

### B. Prioridade do preparo agronômico e segurança de trabalho

`TerrainDeformationEngine.processSample` **suprime a escrita RE quando uma combinação está cultivando** e em áreas recentemente cultivadas, sem desligar os cálculos upstream do Mud/MR; nesse contexto uma sessão inteira sem novos LOWER não prova que colheitadeira com outras condições não produziria sulcos. Também há políticas específicas para estado patológico de IA.

### C. Teto experimental nativo 10cm/12cm

`getLoweringBudget` examina todos os vértices do footprint. Se **qualquer** um atinge 10cm *relativamente à sua referência RE*, rejeita **a operação inteira**. Se resta margem, diminui o valor **solicitado** até 3mm; **não** limita a alteração efetiva já realizada pelo motor como transação atômica. Se concavidade local >12cm, também rejeita; a comparação de altura não identifica quem criou o vale. Estes são **fail-safes provisórios**, não critérios reais de solo. Em 12:10, `cap=2626` dos `nativeGuard=2657` bloqueios: há corte material de escrita, não só moderação suave da profundidade. Em 13:40 não houve novas solicitações de roda; `cap=0` dessa sessão é inconclusivo quanto à versão/umidade.

Os logs mostram deficiências de medição: `maxDeficit=0.2763m` em 12:10 e `maxDeficit=0.1868m` em 13:40, apesar do teto nominal 0.10m, e cada pedido <=0.003m. O callback confirma alteração local, mas quantos centímetros vieram do pincel vs alterações externas, composição de várias brushes/heightmap/fine track ainda não está demonstrado. O teto não garante por si só profundidade máxima. **Não afrouxar/retirar sem medir requested→realized por vértice.**

## 3. O que avançou desde a revisão arquitetural 23/10

| Capability | Estado atual suportado |
|---|---|
| Referência original RE + native-grid journal | Implementado experimentalmente; real save 948 cells → load 948/0 rejected; confirmed |
| Commit após callback nativa, não enqueue | Implementado e testado; 1.093 lower event samples até 12:10 |
| Sulcos novos e restituição agronômica normal | Evidência real forte: 175 callback improvements, 50 native vertices fisicamente encerrados no save 13:40; jogador considerou campo pronto para semear. **Parcial gameplay PASS** |
| Relação de profundidade pedida vs deslocamento nativo | **Aberto**; discrepância 3mm pedidos vs déficit observado até 27.6cm; risco de relevo excessivo |
| Dano profundo em eventos extremos estilo SnowRunner | **Aberto**; proteção 10cm pode bloquear precisamente cenários desejados e dados não justificam física de capacidade |
| Mistura Mud/RE | Ownership projetado preservado; RC MR friction/RR/local wetness callbacks vivos; mas **frozen mode recebido do Mud** pode reduzir efeitos de ambos. Nenhum teste conclusivo A/B sem congelamento |
| Recuperação de dois canais: estrutura + acabamento SMOOTH | Restituição estrutural funcionando; acabamento real e preservação de cristas/massa/curvatura ainda não implementados como ciclo aprovado |
| NPC/fazendas vizinhas e prefeitura | `TerrainMaintenance.lua` + `TerrainMaintenancePolicy.lua` **já foram implementados**, usando PERÍODO e classificação territorial; porém `TerrainMaintenance=false` na build experimental para isolar writer TARGET antigo. Precisa **migração para journal**, não nova criação |
| Danos externos/naturais/terraplanagem voluntária | Guarda de proveniência não reverte desconhecidos; tratamento local de irregularidades sem baseline, seguro e realista, ainda não implementado |
| Persistência/multiplayer/performance/release | SP journal save/reload evidenciado, MP não validado; efeitos colaterais de vértice em caso isolado; CI passa, mas release não aprovado |

**NÃO ampliar uma checklist interminável:** aprovação normal já observada, não exigir novas passadas comuns. A distinção é manter operação normal como benchmark já suficiente e reservar ensaios dirigidos para capacidades que falharam ou permanecem novas.

## 4. Próxima execução, sem pedir outra safra nem mexer cegamente em parâmetros

**A. Primeiro fechar fonte climática:** verificar quando/how o Mud reporta freeze e quais foram temperatura atual, fonte do clima, limiar efetivo configurado, mês do jogo e solo observado. Em região tropical/subtropical, um flag por ar instantâneo pode ser fisicamente inadequado. Verificar necessidade de temperatura efetiva do solo com memória térmica, sem forçar overwrites silenciosos. Distinguir terreno realmente congelado de bug climático. Incluir telemetria **limitada a mudanças de estado**, não milhares de linhas.

**B. Medir geometria física de forma causal:** instrumentação bounded requested depth, actual min/max lowering, native footprint/vertex IDs, local wetness, pressure, slip, sink, bearing ratio, hardFrozen, accepted/rejected reason, including 10cm cap. Só então propor limite físico dependente do solo ou refazer actuator para garantir efeito real proporcional ao pedido. Não vender o limite 10cm como simulação final.

**C. Fechar manutenção territorial existente:** reutilizar classificação `TerrainMaintenancePolicy` e trigger `PERIOD_CHANGED`, age/farmland-boundary/surface guards, fila rate-limited da manutenção antiga. Substituir o OLD `MAINTENANCE` TARGET com referência annular `SpatialHistory` por transação `TerrainGeometryJournal` com policy de causa `NEIGHBOR`/`MUNICIPAL`. Evitar reativar `TerrainMaintenance=true` as-is; a mesma área não deve ter dois escritores concorrentes. Testar prova de melhora nativa real, boundary e histórico persistido, compatível com save existente, sem recuperar terraço/vala feita pelo jogador.

**D. Recuperação sem referência e acabamento**: capacidade separada, controlada e conservadora para pequenas irregularidades existentes de fontes desconhecidas; não reverter terraplanagem voluntária nem relevo natural. Smoothing pós-restituição no corredor trabalhadO com limites de relevo/volume. Deep rut severe may require explicit fill/grade; subsoiler não nivela sozinho.

**E. Release gates de gameplay:** tráfego típico suportável + ferramentas agrícolas reduzem sulcos recentes na primeira passada útil (e eventual acabamento), solo extremo pode atolar por Mud e produzir deformação RE grande mas coerente, recuperação severa possível por processo apropriado, auto manutenção das áreas autorizadas, save/load robusto, sem buracos improvisados ou física frágil. RC conserto apenas com contrato comprovado de outro mod.

O usuário está fora de casa e não pode realizar novos testes agora. Esta revisão não implica pedir testes, resetar save, ampliar cap nem gerar ZIP. Atualizações de docs apenas, branch de experimento/PR #64; main intocada.
