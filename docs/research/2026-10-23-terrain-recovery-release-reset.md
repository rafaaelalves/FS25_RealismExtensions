# Terrain RE — revisão de arquitetura, histórico e plano de entrega jogável (2026-10-23)

**Status:** diagnóstico consolidado; proposta de arquitetura; **não implementado e não validado fisicamente**. Fonte de continuidade para o próximo desenvolvimento, sem recomeçar ensaios que falharam. Branch de pesquisa PR #60; produção `main` preservada. Resultado reprobatório registrado em [issue #59](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/59).

## 1. Contrato de produto

O requisito **não é** “uma chamada ao TerrainDeformation que não falha”, nem “alguma célula lógica perdeu 3 mm”. É **um campo visivelmente e mecanicamente trabalhável**, com sulcos permanentes gerados apenas em condições apropriadas e com recuperação compatível com a operação. O utilizador relata vários ciclos de dezenas de passadas sem reparação aceitável, enquanto a ferramenta manual **Amenizar** altera dramaticamente a mesma região. Nenhum mecanismo de recuperação atual passou na experiência de uso.

**Meta v1 proposta, não uma afirmação agronômica universal:** uma operação primária apropriada reduz substancialmente o canal de roda severo, seguida de no máximo uma operação secundária normal para acabamento numa situação de solo suficientemente trabalhável; não exigir perfeição de plano. Solo muito molhado pode **não** ser elegível para recuperação imediata, mas nesse caso o jogo precisa informar e evitar uma repetição sem resultado. Dano histórico extremo / deliberada escavação TerraFarm não deve ser “apagado” pelo cultivo comum. Distinguir qualidade de vida da capacidade agronômica real.

### Escopo mínimo desta feature antes de release

1. Tráfego normal suportado sem criação contínua de crateras irreversíveis; Mud continua dono de sink/atolamento temporário; SoilCompaction continua dono da compactação agronômica.
2. RE conhece **quais vértices/áreas foram fisicamente modificados por suas próprias operações** e o que foi realmente escrito pelo motor.
3. Preparo apropriado produz melhoria física verificável e persistente sem nivelar encostas, estradas, canais ou alterações manuais.
4. Suporta save/reload e trabalho normal de IA/implemento, inclusive repetição, com trabalho de CPU adequado.
5. Release estabilizada não carrega instrumentação experimental cara; SP comprovado. MP só rotular como validado após teste real.

## 2. Reconciliação de documentos antigos e achados posteriores

| Pesquisa / implementação | Resultado sustentado | O que NÃO está validado |
|---|---|---|
| `DensityMapHeightUtil.smoothAroundLine` v12/v13 | Chamada executava; na v13 não movia altura física RE | Recuperação de altura |
| `TerrainDeformation.enableSmoothingMode` v14/v21/v22, R3/H2 | Executa fisicamente; em uma sessão 2.856/3.338 brushes melhoraram rugosidade e 2.858 centros **baixaram**, 77 **subiram**; proteção de contato/retry foi corrigida | Reposição de sulcos profundos, preservação de solo e convergência jogável |
| R4 `RAISE` aditivo | Algumas elevações observadas de 0,22 a 0,84 m; surgiram montes; rejeitado como reparação sem alvo | Controle de profundidade/volume |
| R5/R6/R7 `TARGET` com estimador | Há efeitos físicos e perfis agrícolas corretos; pode melhorar alguns centros | Resultado aceitável nas regiões danificadas; antigas conclusões “R6 funciona” não satisfazem a evidência de outubro 23 |
| V2 estimador com anéis | Correção de referência em harness; recusa planos com desacordo >3,5 cm, evitando regrades cegos | Referência correta para campos curvos, faixas paralelas contaminadas e 30k células legadas |
| V3 `preDeformHeightM` | Posição lógica de 0,20m recebe referência observacional antes de ENFILEIRAR a deformação nova; pode persistir no sidecar | Referência por vértice nativo afetado, confirmação da deformação, coordenação externa e autorização para restituição |
| PR #60 `reGeoMark/reGeoSnap` | Medição fixa read-only confirmada no jogo; mesma main-height API em passo 1m e passo 0,125m | Acesso à camada visual nativa 12,5 cm / atribuição individual de vértices |
| 2026-10-23 teste 160140 | No ponto (389,820; 329,039), valley residual relativa -0,6554m → -0,6487m após muitos trabalhos; após Amenizar -0,0113m; nenhuma callback RE próxima na fase manual; forte reprovação de recuperação normal | Que todo relevo de 65cm foi exclusivamente escavado pelo RE ou que “vale 65cm de dívida histórica” |

**Correção documental:** `docs/decisions/0005-terrain-recovery-physical-smoothing.md` (2026-10-02) chama o mecanismo SMOOTH de aceito. `docs/project/TERRAIN_EVOLUTION_PLAN.md` e `STABILIZATION_ROADMAP_2026-10-08.md` preservam afirmações antigas de baseline bem-sucedida. Elas são checkpoints históricos, **não aprovação atual** de liberação. Esta revisão e o in-game log 160140 as superam no critério “sulco profundo fisicamente recuperado em esforço razoável”; não apagar o histórico de decisões.

## 3. Defeito de arquitetura confirmado no código, separando fato e hipótese

**FATO DE CÓDIGO: `TerrainDeformationEngine.lua`:** `desiredDelta = response.rutDepthM - previousDepth`; `appliedDepth = min(desiredDelta, 0.003)`, ajustado por deformability; `writer:enqueue(...)` devolve **aceitação na fila**, e o código imediatamente faz `historyStore:commit(copyHistoryForAppliedDepth(..., appliedDepth, ...))`. A confirmação do GIANTS callback ainda não aconteceu. **Logo, `SpatialHistory.rutDepthM` não é medição da geometria física realizada.**

**FATO DE CÓDIGO: `TerrainWriter.lua`:** pincéis LOWER não levam `onApplied` na chamada feita pelo Engine. `tryCoalesce` pode fundir pinceis sem callback individual, recalculando centro, raio, hardness; `flush` pode reordenar/agrupar/submeter lote, e a aceitação inicial não implica aplicação. `heightSamples` não é capturado para o LOWER comum, a menos que sejam ativados diagnósticos caros. O callback de volume é do lote; não identifica automaticamente os vértices individuais alterados.

**FATO DE CÓDIGO:** o grid histórico é 0,20m; no mapa São Carlos testado `getTerrainHeightmapUnitSize` informa 1,00m para o heightmap principal (API GIANTS oficial). Os grids são **domínios distintos**. Vários centros de pincel e de história podem contribuir para um mesmo vértice ou seus vizinhos; medir a altura em centros arbitrários de 0,20m não estabelece qual vértice recebeu qual contribuição.

**OBSERVADO** na área testada: `HISTORY_NEAR maxRut=0.006m` enquanto o relevo relativo medido é muito maior, e o TARGET falha 783/885 centros (88,5%) na sessão. **HIPÓTESE PRIORITÁRIA:** desalinhamento de posse espacial, magnitude pedida vs realizada, fila de escrita, referências legadas e/origem externa contribuem para falta de restauração. Ainda **não** sabemos a parcela de cada fator nem podemos usar -65cm como “profundidade do sulco de roda” certificada.

**CONSEQUÊNCIA:** calibrar apenas `targetStrength` ou `maxStructuralPulses` não resolve esse contrato e pode reintroduzir os montes do R4.

## 4. Auditorias e fontes externas — o que realmente acrescentam

### GIANTS

- [GDN getTerrainHeightmapUnitSize](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=812&version=engine): unidade do **main heightmap**.
- [GDN getTerrainHeightAtWorldPos](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=811&version=engine): altura no mundo.
- [GDN Terrain APIs](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=807&version=engine): inclui `setTerrainHeightAtWorldPos` e APIs de height sync. Disponibilidade não é permissão para ignorar autoridade/save/MP. Se estudado em novo protótipo, isolar transações e validação.

### TerraFarm 1.6.5.0, source pinado `b50e677c`

**Já auditado** no RE `docs/audits/terrafarm/` e RC `docs/audits/2026-10-02-terrafarm-full-stack-audit.md`. Separação de modo/operation, `LandscapingInputSmooth` (0,05m; pincel radius 2m; strength 0,25; hardness 0,2), `LandscapingInputFlatten/Slope`, `apply(false,...)` e lifecycle de callbacks. A comparação essencial não é apenas a constante: **área ativa/nós efetivamente cobertos**, material/proveniência, restrições por operação, controle de colisão, modified-area e `setAreaDirty` quando apropriado. `TerrainWriter` RE já implementa o primitive SMOOTH, mas não replica a mesma geometria/cadência/área do cursor manual. NÃO copiar código nem assumir que chamar enableSmoothingMode sobre um pincel 0,45m equivale a Amenizar.

### Visual Mud Tracks (Sherman), evidência estratificada

**Exato ZIP anteriormente auditado no RE:** `docs/audits/visualmudtracks/README.md`, declara 1.4.0.27, hash `4796d1f5...`, sem licença de reuso; code auditado indica `setTerrainHeightAtWorldPos` central e `writeLowerOnly`. Não confundir com releases públicos.

**Descrição pública atual que consultamos:** [KingMods Visual Mud Tracks](https://www.kingmods.net/en/fs25/mods/79740/visual-mud-tracks) / [V1.4.0.5 release notes](https://fs25.net/visual-mud-tracks-v1-0-2-5/). Anuncia referência original imutável, estado separado dos sulcos ativos, gravação ordenada, writes monotonic LOWER, restauração por área de trabalho, filas adiadas e confirmação de altura antes de retirar dívida; **isso é um precedente funcional relevante**. **Não foi auditado o ZIP exato dessa versão pública nem demonstrado em jogo na nossa stack**; não concluir “o VMT conserta o RE”, nem instalar dois heightmap writers simultaneamente. Modelo de restauração a altura original precisa de invalidação/rebase quando o jogador remodela o terreno, ao contrário de um rollback indiscriminado.

**Ideias que valem portar por clean-room:** versão e identidade de célula geométrica, before/after real, journal transacional, lower-only write, evitar reaplicar ao carregar se sulco já existe, remover dívida **após** restauração comprovada, índice espacial e autorizações de preparo.

### Mud/MR/Reifen/SoilCompaction/TTD

**RC audits**: MR + Mud + Reifen + RMS/ADS + SoilCompaction dividem tração/sink/pressão/desgaste/compactação; Mud 1.3.7 mudança principal não introduz restauração física de altura RE; não presumir que “pneus leves e visual” sejam prova do mesmo heightmap. [TTD 1.0.3.7](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/audits/2026-10-18-tractor-terrain-dynamics-1.0.3.7-beta-full-stack-audit.md) altera raio/displacement wheel, não fornece algoritmo de recuperação dos vértices persistidos, portanto **não** adicionar como solução ao problema. MR/RC não devem receber o solver de reconstrução.

### Solo real (critério, não licença para tortura em gameplay)

[University of Minnesota / Nebraska — Managing Ruts](https://conservancy.umn.edu/bitstreams/e558df36-64f1-43b2-bdb9-3953cbea955b/download) e [Penn State Extension — Repairing Compacted Soil](https://extension.psu.edu/repairing-compacted-soil): aguardar secagem é importante; sulcos leves podem ser nivelados por preparo raso; severa compactação pode exigir escarificador/subsolador antes do nivelamento. Sulco profundo persistente e **compactação profunda são fenômenos diferentes**: RE resolve topografia, SoilCompaction a camada agronômica. Um subsolador não pode sozinho magicamente produzir seedbed plano, e um arado não deve exigir dezenas de passagens sobre o mesmo buraco.

## 5. Arquitetura escolhida para o próximo protótipo — sem repetir TARGET/SMOOTH cegos

### A. Geometria verificada e autoria por operação (substitui ledger de intenção como verdade geométrica)

- **Dois domínios:** `MechanicalHistory` (0,20m, slip/wetness/compaction/debt previsto) e `TerrainGeometryJournal` (células/vértices alinhados ao `getTerrainHeightmapUnitSize`, mapa/epoch, baseline e estado físico observado; não meramente uma cópia do primeiro).
- Antes de um write nativo, capturar alturas dos pontos que **podem** ser afetados por footprint incluindo o falloff; identidade de operação/job.
- Nunca aceitar `writer:enqueue()` como commit físico. Só associar `observedHeightAfter` a uma operação confirmada/callback e after-read; registrando erro e overlap concorrente como `UNKNOWN`. Um lote de brushes coalescido não pode atribuir alteração a cada wheel cell sem prova: desabilitar coalesce **apenas para operações rastreadas** ou registrar o lote como uma unidade espacial e dividir atribuição só com evidência.
- Conferir `actualY` contra `beforeY`, limites locais de dano, memória da operação e owner; **não inferir original = atual + rutDepthM**. Persistir baseline antes do primeiro impacto novo e não reajustá-lo por repetição do pneu. Capturar baseline em campos deformados antigos é inválido por definição.
- Se geometria externa muda, registrar epoch local/invalidar baseline ou usar evento conhecido TerraFarm/Construction; nunca restaurar automaticamente terraplanagem que o jogador escolheu.
- Manter escrita server-authoritative, versionada, idempotente em save/reload e com índice espacial/chunk; GC e budget de vértices por trabalho.

### B. Geração primeiro — limitar a *consequência real*, não só o comando

- O limite de pincel atual `maxBrushDepthM=0.003` é **limite de pedido**; o controle de versão jogável deve validar **efeito físico** e faixas de relevo realizadas (não provar segurança com “3mm”). Evitar 65cm de irregularidade não atribuível a dano seguro.
- Tráfego cotidiano suportado: frequentemente nenhuma deformação permanente; solo muito úmido/slip alto sob carga realmente elevada pode produzir dano persistente. Não duplicar modelo de força de Mud.
- Preservar o histórico de R4 (RAISE gerava montes de 22–84cm): qualquer desvio realizado grande invalida protótipo sem salvar jogo real.

### C. Recuperação por dois atuadores complementares, selecionados por procedência

- **Estrutural — para sulcos novos RE comprovados:** reconstruir os pontos alterados de altura principal em direção ao baseline pré-RE confiável, sob operação de preparo apropriada, teto e orçamento por passada, contato livre e limites de relevo natural. Empregar máquina/brush GIANTS em modo de alvo **onde demonstravelmente tem cobertura/efeito**; alternativa isolada para estudar `setTerrainHeightAtWorldPos` alinhado a grid, com disciplina de save, sync, outside area, dynamic-object safety, não por default.
- **Acabamento:** native SMOOTH **no corredor causal trabalhado**, com área/cadência semelhante à operação de Amenizar, para transição de bordas/pequenos sulcos, não como substituto de reconstituição em depressões profundas. Combinar com superfície local pré-dano (inclusive declive/curvatura) para impedir “campo mesa”.
- **Danos antigos/sem baseline:** não inventar original. Oferecer futuramente recuperação/localização **opt-in** em cópia de save, ou somente suavização leve de acabamento, rotulada como intervenção não reversível; nunca alisar automaticamente toda a fazenda com solo reescavado.

### D. Priorização/garantias

- Não retocar no mesmo PR as equações MR/Mud/Reifen, PTO, IA geral, TerraFarm, surface mass transport, SoilCompaction ou documentação irrelevante.
- Não ampliar `maxRingReferenceDriftM` cegamente. O R1/V2 pode ser **retirado do caminho principal de restauração causal confiável**; continuar útil como *detector auxiliar de segurança* em dano legado.
- Reutilizar `TerrainWorkContext`, `TerrainPassTracker`, `LoadedContactRegistry`, `TillageRecoveryProfiles`, fila e callbacks do `TerrainWriter`; refatorar a atribuição da autoria e mecanismo por célula.
- Para evitar mais meses de “telemetria”, critérios de aprovação por **capacidade jogável**, não por contadores de API.

## 6. Plano de engenharia e gates anti-loop

**Etapa I — corrigir a verdade de escrita, com código e harness (sem teste do usuário):**
- Introduzir journal separado de geometria, identidade de brush/lote e log de intenção vs efeito realizado.
- Testes determinísticos: enqueued depois falha; lote coalescido; 0,2m vs 1m; dois pneus atingem o mesmo vértice; out-of-order; external edit; load com heightmap já alterado; nenhum “depth” lógico vira height restaurável sem confirmação.
- Manter criação anterior atrás de flag desativada no novo protótipo até callback + alinhamento testados. Nenhum ZIP para docs; CI quando código mudar.

**Etapa II — atuar de verdade em uma área artificial e barata:**
- Executar um teste **rápido de atuador** numa cópia de save ou mapa de laboratório: sulco RE recém-criado e geometricamente conhecido, com/sem declive e uma alteração manual externa. Testar um ponto grid-alinhado e cobertura do brush. Decidir uma vez entre TARGET com cobertura correta e write por vértice com sincronização verificada; **não** retestar os mesmos parámetros sem nova hipótese.
- Aceitação: relação explícita requested vs actual, nenhuma elevação/rebaixamento além do envelope permitido, o comando altera os vértices pretendidos e nenhum fora da footprint.

**Etapa III — circuito mínimo de gameplay completo:**
- No **backup antigo anterior ao sistema**, clonado em slot descartável, criar um rut novo RE intencional numa área pequena; medir, uma operação primária e uma secundária; verificar reconstituição física, mesma câmera, contato do trator e continuidade após save/reload. Testar operador e um ajudante.
- **PASS:** redução visível e mensurável da **profundidade transversal do canal**, não apenas do range 2×2 contra 4 cantos, e sem estragos fora do footprint; custo compatível com campo extenso; sem salvar resultado ruim no slot de jogo.
- **FAIL:** não repetir dezenas de passadas nem “elevar strength” sem entender a operação; voltar à etapa do **defeito específico demonstrado** e corrigir arquitetura, não calibrar às cegas.
- Só após PASS passar a uma sessão normal para ergonomia/saldo chuva/plantio; chamada de release candidate do terreno quando requisitos v1 foram cumpridos, e não antes.

## 7. Saves existentes / baseline limpa

- **Save atual:** já tem alterações de heightmap persistentes de ruts RE experimentais e de Amenizar manual. Desativar RE terrain **não** reverte essa geometria; não reintroduzir `preDeformHeightM` fictício nem aplicar “reset global” sem conhecer a origem. Congelar uma cópia para eventual recuperador manual seguro, mas jogar nele só se satisfeito com área existente.
- **Backup antigo antes das deformações RE:** preservar imutável, clonar para o ensaio inicial e eventual carreira definitiva ao aprovar um terreno v1. É a fonte mais confiável para validar *novas* deformações com origem conhecida, sem carregar cerca de 30k células históricas questionáveis.
- Não deletar `realismExtensionsTerrainHistory` ou sidecars individuais manualmente sem auditoria exata do formato/epoch e cópia da pasta inteira. Não misturar ZIPs/branches distintas no mesmo slot sem estratégia de migração.

## 8. Responsabilidades, ações seguintes e documentação

1. **Novo código experimental primeiro:** `TerrainGeometryJournal` + `TerrainWriter` callback attribution + `TerrainDeformationEngine` transactional commit; testes no CI. Isso é um passo arquitetural justificável e resolve o descompasso de ownership. **Não** uma nova build de telemetria puramente descritiva.
2. Substituir o caminho agrícola R1 `TARGET` repetitivo por ação referenciada por geometria confirmada; SMOOTH somente acabamento com limites. Provar actuator antes de refazer gameplay.
3. Registrar decisão futura sobre `setTerrainHeightAtWorldPos` vs `TerrainDeformation` por comportamento efetivamente verificado, custo/MP/ownership; não copiar fonte VMT ou TerraFarm. Use VMT como contraexemplo/invariantes, não como segundo mod de terrain simultâneo.
4. Após capacidade estabilizada, planejar recuperação opcional dos legados, e só então adicionar outros recursos de solo/contato. RC apenas quando uma interface externa realmente precisar de bridge.
5. **A documentação antiga deve permanecer como registro cronológico**, com marca explícita de resultados superados; esta revisão é o estado de referência de 2026-10-23 até uma decisão posterior testada.

**Resultado honesto deste documento:** agora há um caminho técnico diferente respaldado por falha de causalidade comprovada no código e precedentes previamente auditados. Nenhuma nova recuperação física foi implementada nesta revisão; é proibido chamá-la de “resolvida” antes do teste real de reconstituição.
