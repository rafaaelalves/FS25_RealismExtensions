# Roadmap integral de estabilização RC/RE — 2026-10-08

**Status:** roteiro aprovado como orientação de trabalho; **hipóteses de dificuldade e sistema de guincho não aprovadas para implementação**.  
**Branch proprietária do terreno:** `feat/terrain-recovery`.  
**PTO:** desenvolvimento isolado em outro chat/PR; este roteiro **não altera nem testa a PTO**.  
**Princípio:** menos versões de teste inúteis, testes que resolvam hipóteses inteiras, manutenção de um único autor por estado físico e não substituir capacidades especialistas apenas para reduzir ZIPs.

## 0. Estado verificável e fontes de verdade

- RE `main`: base consolidada de TerrainDeformation anterior ao trabalho atual; **não é a branch R9**. Correção dos defaults seguros em [PR #34](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/34), CI verde; manter sem merge até revisão. Nenhuma correção desta trilha deve modificar branches da PTO.
- RE `feat/terrain-recovery`: recupera sulcos fisicamente via TARGET; R5 mecanismo comprovado, R6 runtime PASS em 2026-10-04 (`977cfaef`, 1.432 TARGET jobs, 414 melhoras, 15 pioras; histórico reconciliado; métricas de tempo); R7 perfis de preparo; R8 política contra patologias de navegação da IA; R9 manutenção periódica de terreno NPC/municipal **implementada, mas sem uma validação runtime específica no material revisado**.
- RE `SoilMassTransport=false`: manter assim até resolver histórico de realização de material ~2x; não misturar calibragem de dificuldade com modelo de conservação ainda experimental.
- RC `main`: baseline de integrações MR+Mud+Reifen+RMS, testes e telemetria de qualificação. Pendências deliberadamente adiadas: [P1–P6](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/project/PENDING_RUNTIME_EXPERIMENTS.md). A P7 refere-se somente à PTO de outro chat.
- Fonte de verdade para recuperação: [TERRAIN_EVOLUTION_PLAN](TERRAIN_EVOLUTION_PLAN.md), [CURRENT_HANDOFF](CURRENT_HANDOFF.md) e [DEVELOPMENT_PROCESS](../DEVELOPMENT_PROCESS.md). Esta página organiza **prioridade, escolhas pendentes e critérios de saída**, e não substitui a documentação de algoritmo.
- Não considerar CI, sucesso de callbacks ou quantidade de jobs como prova isolada de relevo físico correto; distinguir SOURCE, HARNESS, RUNTIME, PHYSICAL, CAUSAL, SCENARIO, REGRESSION.

## 1. Matriz de responsabilidades

| Fenômeno | Autor atual | RE/RC podem fazer | Não fazer |
|---|---|---|---|
| física base do veículo/motor/rodagem/traction | MoreRealistic | usar estado e propor correções upstream | segundo solver de força |
| água no solo, sink temporário, resistência, stuck | MudSystemPhysics | consumir entradas; diagnosticar dificuldade | diminuir/recriar a resistência pelo RE sem separar responsabilidade |
| raio estrutural, desgaste de pneu/esteira | Reifen | consumir via RC | editar raio físico em mais um módulo |
| diferenciais, sistema mecânico, PTO stress | RMS, mais RE PTO no seu fluxo separado | consumir e compor fronteiras | segundo 4x4 e alterar fluxo PTO desta trilha |
| compactação agronômica persistente | SoilCompaction | preservar e medir | duplicar penalidades de produtividade |
| pegadas/sulcos persistentes, recuperação física, histórico | RE Terrain* | único autor dos edits GIANTS nessa capacidade | tentar melhorar a física de stuck por escavação arbitrária |
| recursos de recuperação / cabos / guinchos | GIANTS Winch + mods externos | auditoria; considerar interface de serviços e clean-room em fase futura | controlar inércia/forças direto por dois mods |
| comportamento de IA/Courseplay | GIANTS/CP/AD | detector estreito de estado; RC só normalização externa necessária | suprimir todos os sulcos de IA, reduzir genericamente a dificuldade para ajudantes |

## 2. Sequência de execução e gates

### P0 — Higiene e segurança da stack (curta, anterior às melhorias)

1. Revisar/fechar PR RE #34 (defaults seguros de `main`); manter `feat/terrain-recovery` intencionalmente com módulos habilitados apenas em testes. Confirmar CI e comportamento de bootstrap; sem rebuild do jogo exclusivamente por mudança de documentação.
2. Registrar **versões exatas + SHA/BuildIdentity de RC/RE** quando usar logs, e comparar com feature branches; não julgar logs de builds desconhecidas.
3. Garantir clone do save antes de testes que alteram mapa. Terreno já modificado não é reversível simplesmente removendo ZIP; `SpatialHistory` não é um backup da heightmap.
4. Baseline de observabilidade: perf/counters mínimos, detalhes caros desligados na configuração de estabilização; preservar distribuição de tempos, jobs falhados, fila, memória/histórico e writer causality.
5. Entender status da PR PTO apenas para **não editar seus arquivos**. Não depender de PTO merge para esta trilha.

**Saída:** baseline reprodutível, CI verde, startup sem atuação inesperada; usuário consegue jogar normalmente sem pesquisas ativas.

### P1 — Fechar a recuperação física existente (prioridade técnica imediata)

**Manter:** TARGET v5/v6, convergência sem montes/buracos, R7 per-profile e proteção de trabalho efetivo/repetido.

1. A1 `TerrainPassTracker`: uma passagem física vira um evento único independente do FPS, velocidade e cooldown; completar/validar passId, janela espacial e término quando implemento sobe. Não aumentar força antes de mensurar passes.
2. A2 `RecoveryPassSummary`: por implemento/root, profundidade inicial, relevo residual/P50/P90, passagens, esforço e alteração física observada; invariante `rutAcceptedWhileActive == 0`.
3. B1/B2 `slope-aware roughness`: distinguir declive legítimo de sulco/berma; primeiramente **só medir**, sem mudar o atuador.
4. B3 `target roughness`: teto/floor residual por ferramenta para evitar passar infinitas vezes tentando eliminar ondulação normal; redução progressiva de dose. B4 `severity-adaptive recovery` depois, evitando força única para todos os implementos.
5. C1 `TerrainWorkFootprint`: usar geometria da barra de trabalho real; ferramenta larga não pode reparar apenas uma faixa central; considerar operação, posição, articulação, direção e implementos traseiros.
6. C2 `TerrainRecoveryProfile`: CULTIVATOR baseline + SHALLOW_DISC/POWER_HARROW/SUBSOILER/PLOW/PLOW_PACKER; distinguir nivelamento superficial de alívio de compactação, sem fazer subsolador apagar todo o relevo automaticamente.
7. R8: confirmar `TerrainActors` em uso normal; não isentar IA de consequências físicas, apenas evitar escavação infinita gerada por estados patológicos do planejador.
8. R9: verificar um ciclo de `PERIOD_CHANGED` (NPC field=NEIGHBOR 1+ períodos, via municipal=2+), exclusão de propriedade do jogador/outras fazendas, limites espaciais e independência de save/reload; não exigir um teste manual para cada mês.

**Saída:** consertar uma área repetindo 2–3 passes tem efeito consistente e não destrutivo *quando a ferramenta/gravidade permitem*; recuperação convergente medida, sem promessa de número fixo para crateras históricas; nenhum LOWER durante trabalho protegido; GC/CPU moderados; R9 não mexe em solo do jogador nem sob rodas carregadas.

### P2 — Tipos de rodagem: NÃO completamente consolidados (pré-requisito da calibração definitiva)

A classificação deve distinguir **hardware/contato** de nomenclatura comercial. A pressão correta não se obtém só de uma string `NARROW`, `WIDE` ou `DUAL`.

| Rodagem | Estado no RE atual | Pendência / gate |
|---|---|---|
| pneu simples pneumático convencional | **MODELO BASE**: `FootprintModel` usa `tirePressureBar`, largura de apoio, carga, raio estrutural; fallback geométrico | confirmar pressão/carga e marcas físicas em diversas massas |
| pneu largo/flotation | **PARCIAL**: largura genérica é consumida; sem geometria específica de flutuação/ombros | validar sobrecarga/carga dinâmica e distribuição real, não apenas footprint central maior |
| pneu estreito/row crop | **PARCIAL**: pode entrar na mesma fórmula por largura/pressão; sem categoria própria | confirmar largura real e pressão de trabalho: estreito não equivale automaticamente a mais compactação se pressão/carga diferirem |
| pneus duplos/twin | **PARCIAL**: RC informa `supportWidthM` (MR `mrTotalWidth`), harness testa dobro; sem dois footprints separados | obter separação lateral, largura de cada pneu, carga repartida, contato/distância entre trilhas; GIANTS pode agrupar suporte num só physics wheel |
| pneus duplos estreitos | **NÃO VALIDADO**: combinação composicional dos dois itens anteriores, não classe testada | parametrizar quantidade, largura por banda e espaçamento; impedir que o conjunto seja tratado como uma faixa sólida |
| pneus triplos | **PARCIAL/SEM VALIDACAO**: `supportWidthM` pode acumular largura, mas não localiza três bandas | modelo agrupado de 3 apoios; não fabricar wheel physics inexistente |
| pneus sólidos, rodas pequenas, rodas de implemento e rodízios | **PARCIAL/INCOMPLETO**: veículos com wheels recebem registro; modelo é pneumático por default | classificar pneumatic/solid/unknown; não inventar pressão, reconhecer geometria/escala/porte e aplicação real |
| esteiras de borracha/agricultura, tratores Quadtrac e crawlers nativos | **AUSENTE**: `FootprintModel` rejeita explicitamente `isCrawler=true` | `ContactFootprint` agrupado por `spec_crawlers.crawlers`, comprimento de contato, carga de grupo, bogies/roletes, picos de pressão, patinagem e pressão não uniforme |
| meia-esteira / combinações roda + esteira | **NÃO COBERTO**: requer vários grupos diferentes no mesmo veículo | composição por grupo, conservando carga e evitando contagem duplicada |
| rodas de suporte de implementos e veículos rebocados | **NÃO VALIDADO NO JOGO** como classe; trajetória/deformação e ordem em relação ao trabalho | actor root, classificação de contato, evitar reparar e escavar simultaneamente no mesmo passe |

**Interface-alvo (conceitual, não API existente):**
`ContactGroup { id, kind, ownerVehicle, units[], side, axle, width, bandOffsets[], contactLength, loadN, inflationBar?, rollingSlip, lateralSlip, measuredConfidence }`.
- `PNEUMATIC_SINGLE`, `PNEUMATIC_MULTI`, `SOLID_WHEEL`, `CRAWLER_GROUP`, `UNKNOWN`.
- `NARROW/WIDE` são características dimensionais do pneu, não motores físicos separados; `DUAL_NARROW` é multibanda com cada banda estreita.
- Um `UNKNOWN` não deve utilizar falsamente `tirePressureBar` nem aplicar um coeficiente genérico de escavação devastador.
- Sem duplicar pares GIANTS/GIANTS+MR representando a mesma carga; exigir conservação de carga por eixo ou estimativa explicitamente marcada.
- Estabelecer **uma passagem física por classe de hardware** e um harness paramétrico, não dezenas de sessões/ZIPs para modelos de máquinas semelhantes.
- Rodagem deve compartilhar o mesmo normalized RC provider; mudanças upstream em Reifen/Mud/MR só via RC e contratos claros.

**Saída:** tabela de capacidade suportada/degradada/não suportada por hardware, realismo de faixa de contato e sem regressão nos modelos base; esteiras e multibandas com saídas físicas rastreáveis antes de dizer que a categoria está consolidada.

### P3 — Severidade do terreno: hipótese de balanceamento, NÃO alteração aprovada

**Ideia do usuário:** deslocar a condição máxima atual (solo encharcado) para uma situação ainda mais grave de **solo encharcado + chuva ativa**; aliviar gradativamente encharcado sem chuva, molhado, úmido e demais condições. Pretende observar **1–2 anos in-game** antes de decidir.

**Separar três grandezas de percepção:**
- **Mobilidade / atolamento:** MR + Mud (atração/fricção/resistência/sink/perma-stuck). Se o sofrimento principal é *não conseguir sair*, mudar apenas rut RE **não necessariamente resolve**.
- **Dano geométrico persistente:** RE (`wetnessExponent`, `plasticSinkStartWetness`, `plasticSinkFullWetness`, `slipSinkage`, `maxRutDepthFraction`, `SurfaceResponse` minWetness/deformability).
- **Dano agronômico de longo prazo:** SoilCompaction, sem nova penalização em RE.

**Opções para analisar, SEM mexer em parâmetros por enquanto:**
- **S0 atual:** todos os perfis como hoje. Capturar evidência ao longo de temporadas.
- **S1 deslocamento suave:** diminuir suscetibilidade geral e deslocar transições de plastificação, mantendo crescimento monotônico de wetness/slip/pressure. Chuva aumenta severidade apenas por elevar a água real no solo ao longo do tempo; **sem bônus instantâneo duplicando o efeito do Mud**.
- **S2 teto extremo dependente de chuva prolongada:** o último envelope de severidade requer wetness muito alta + precipitação persistente/entrada de água, após atraso de infiltração; não gatilhar apenas pela flag `isRaining`. Preservar casos de solos naturalmente saturados mesmo depois de parar a chuva (não desligar atolamento de uma hora para outra).
- **S3 opção de dificuldade futura:** mecanismo de calibração explícito por perfil, somente se for justificável e não multiplicar regras dispersas entre mods.

**Variáveis proibidas para ajuste cego:** não mudar `Mud` sink/perma-stuck e `RE` plasticidade simultaneamente; não misturar com `SoilMassTransport`; não alterar pressão dos pneus/fertilidade/custos em comparação A/B.
**Observação 1–2 anos:** anotar classe de rodagem, peso e carga, pressão, implemento, superfície, wetness local real, chuva atual/acumulada, velocidade, slip, sink, horas e dificuldade real de escape, passagens de recuperação, volume/depth persistente, custo/tempo de serviço, períodos de descanso, efeito sobre operações de IA. Registrar ocorrências marcantes ao jogar **sem exigir relatórios constantes**.
**Gates:** a dificuldade extrema ainda existe em cenários adversos; condução profissional (pneu correto/pressão/carga/janela meteorológica) melhora probabilidades; solo apenas úmido não gera punição extrema arbitrária; nada fica fácil artificialmente só porque a chuva parou; observação sazonal prova se o jogo continua interessante e sustentável.

**Decisão pendente:** usuário escolher depois da experiência longitudinal; não há ajuste implementado nesta proposta.

### P4 — Atolamento / high-centering / resgate

**Diagnóstico antes do guincho**:
1. Diferenciar falta de tração, sink/perma-stuck Mud, sulcos persistentes RE, crista central tocando barriga/implemento, resistência MR, massa/carga/relação 2WD/4WD e estados de roda/esteira.
2. Compare veículos efetivamente apoiados pelos pneus versus chassi apoiado na crista central. Não inventar uma nova força corporal se a engine não expõe contato físico consistente.
3. Capacidade de resgate deve oferecer consequência de jogar melhor (planejar cabo/âncora, veículo de apoio) **sem mascarar bugs da física**.

**Candidatos conhecidos — estudar por ZIP exato:**
- [Better Winch **1.2.0.3** / ThundRFS](https://www.kingmods.net/en/fs25/mods/63701/better-winch): estende winch florestal vanilla a veículos/implementos/dinâmicos, relaxa freios/suportes, adiciona pontos; versão 1.2.1.3 é *beta*, não default. Autor descreve rope com comportamento de impulso/massa irreais, gancho/visuais e puxar de ré instável. **Candidato original lembrado pelo usuário**.
- [Connecting Tow Cable **1.0.4.2** / BMProd](https://www.kingmods.net/en/fs25/mods/78011/connecting-tow-cable): usuário já utiliza cabo físico/attachers; o mod possui modo de reboque com assistente (acelera e acompanha/reverse), cadeia de unidades; v1.0.4.2 diz ter feito ajuste de servidor sacrificando visual, mas descrição também diz multiplayer não testado. **Primeiro auditar antes de substituir**.
- [Recovery Winch **1.0.0.2** / dafke](https://www.kingmods.net/en/fs25/mods/82081/recovery-winch): recente beta, guincho de três pontos para tratores (220 kg, sem PTO), âncoras de solo/árvore, olhal, freio de recuperação, controle de carga e multiplayer declarado. Pode cobrir a lacuna sem criar um `WinchPhysics` no RE. A versão tem limitações de veículos/configurações e lógica de guincho e cama de transporte; exigir fonte ZIP.
- Outros arquivos/mods do usuário indicados historicamente: `connecting_the_winch_attach`, `Excavator_Winch`, `WinchTool` (Winch Attachment ModHub), `RMC25_C500_WinchTruck`. **Inventariar nomes e versões reais do perfil do jogo** antes de dizer que um deles conflita.
- Mods de gruas/guinchos com capacidade nominal e GIANTS base devem continuar especializados; não duplicar torque de cabo, força de ancoragem, bobinamento ou tensão quando engine já os fornece.

**Matriz funcional para auditoria lado a lado:**
1. tipo de veículo e tipo de ponto (florestal/tree/anchor/trailer/hitch/towing-eye/cpu-mesh);
2. cabo visível + físico; enrola/solta; múltiplos cabos; freios/parking lock; mão do operador;
3. forças, direção, tração do veículo rebocado, limite de carga, tombamento, reboque de ré;
4. energia, massa, altura e geometria reais; fio não deve mover 15 toneladas como se não houvesse inércia; sem teleport/manual-reset;
5. save durante cabo conectado, detach/delete/sell/reload e MP authority/JIP;
6. coexistência com MR, Mud sink/perma-stuck, Reifen, RMS danos, Manual Attach, AutoDrive e implementos, sem tomar controle da física de outro mod;
7. inputs/UI/colisão/cable object management e CPU; licença/redistribuição se considerar código;
8. qual opção fornece a experiência real sem redundância de mod ZIPs ou patches permanentes.

**Decisões possíveis após auditoria:** `KEEP_EXISTING_CABLE`, `ADOPT_BETTER_WINCH`, `ADOPT_RECOVERY_WINCH`, `REQUEST_UPSTREAM_FIX`, `NARROW_RC_BRIDGE`, `CLEAN_ROOM_RE_RECOVERY_EQUIPMENT`.
**Recomendação atual:** não implementar novo guincho RE antes de provar ausência de solução externa competente. Se houver necessidade RE, criar um **módulo de serviço/equipamento de recuperação**, não outro solver de traction/sink.

### P5 — Paridade física player / GIANTS AI / Courseplay / implementos

1. Não apenas efeitos visuais: contato, pressão, criação de history e writer operam com mesmos invariantes em trabalho contínuo de PLAYER, AI_FIELD e CP, mais de um veículo.
2. Medir e limitar estados patológicos da navegação AI sem imunidade genérica; não penalizar o mesmo percurso por identidade do condutor.
3. Auditar e decidir estado de `True AI Tracks` / `FS25_aiTracks`: retirar, coexistir em visual-only ou bridge mínimo com dono único de geometria; sem duplicar marcas e history.
4. Respeitar ordenação implement-wheel -> work area -> recovery, evitando que um cultivador reabra os sulcos que acabou de corrigir.

### P6 — Durabilidade de longo prazo, performance e save

- Retenção e descarte de `SpatialHistory` <= 50k células e fila GIANTS limitada; volume de dados e startup em save de 1–2 anos.
- Ano virtual inclui mudanças de período, chuva, estações, manutenção de NPC, pastas de backup por sessão importante, load/save durante jobs e múltiplos veículos.
- Média, P95/P99 e máximo de `vehicleUpdate`, `recovery`, `flush`, `callback`; motivo de cada rejeição/no-op; pressão sobre frame time, sem testar FPS sem cena e hardware controlados.
- `SoilMassTransport` só volta após conservation source/target/raised, nenhuma sobre-realização e observação visual na mesma sessão; potencial de modificar altura sem reconciliação é risco.
- Testar save novo e migrado; não escrever em solo comprado por outra fazenda; intervalos de manutenção e mudanças de proprietários.
- Rastrear loops de detach/delete/type validation, exceções em callbacks, mudanças de motor game e terceiros.

**Saída de estabilização:** build única candidata por hipótese grande (não build para mudar `1` em `2`), CI/harness cobrindo propriedades, regressão mínima representativa no jogo, sem log spam normal; MR/Mud/RMS/Reifen e RC compõem estados sem dobro de penalidade.

## 3. Ordem prática de entregas (nenhuma data inventada)

| Ordem | Entrega verificável | Depende | Status |
|---|---|---|---|
| 0 | Fundação segura `main` / revisão PR #34, baseline e logs | CI | **correção proposta / CI green** |
| 1 | R9 observação controlada + manter R6/R7/R8 sem regressão; telemetria de passagem | atual `feat/terrain-recovery` | **código R9 presente, runtime específico pendente** |
| 2 | `TerrainPassTracker`, slope-aware roughness, geometria de recuperação | 1 | **planejado** |
| 3 | `ContactFootprint` taxonomia de pneus simples/largos/estreitos/duplos/triplos/esteiras/implementos | provider RC + perf/geometry; 1 | **parcial / esteiras ausentes** |
| 4 | paridade Player/AI/CP + True AI Tracks | 2–3 | **parcial / pendente** |
| 5 | observação de dificuldade por 1–2 anos virtuais, possível S1/S2 | telemetria do 1–4; contexto sazonal | **ideia, NÃO aprovada** |
| 6 | auditoria exata comparativa Better Winch / Connecting Tow Cable / Recovery Winch | ZIPs exatos; inventário de mods | **fontes públicas, NÃO auditado em código** |
| 7 | eventual integração seletiva de equipamento de recuperação | 6 e física stuck/perma-stuck delimitada | **decisão pendente** |
| 8 | estabilidade/save/perf/MP e promoção da feature terreno a release | 1–7 conforme escopo acordado | **em desenvolvimento** |

Observação: **P5 dificuldade é validação longitudinal paralela ao resto**, não motivo para paralisar o desenvolvimento por 1–2 anos de gameplay. **P6 guinchos também pode ser auditado em paralelo sem competir pelo código da PTO/terreno**.

## 4. Restrições de promoção e critérios do projeto

- Nenhum mod externo é absorvido por cópia de fonte/assets sem permissão/licença. Uso de ideias como requisitos é separado.
- Mud sink/stuck, RE rut persistent, Soil agronomy são domínios diferentes. Nunca calibrar todos ao mesmo tempo.
- Chuva no instante presente não é, sozinha, proxy robusta de capacidade do solo: registrar saturação, persistência, condição do terreno e histórico hídrico.
- Multiplayer deve ser verificado nos módulos que editam terreno ou controlam veículo/ancoragem; validação de single-player não prova autoridade MP.
- Releases/configurações experimentais identificados como tais. A estratégia de desativação na `main` continua válida para testes focados e build estável.
- Ao terminar cada gate, atualizar `CURRENT_HANDOFF`, `PROJECT_STATUS`, harness e aceitar/rejeitar com evidência explícita.
