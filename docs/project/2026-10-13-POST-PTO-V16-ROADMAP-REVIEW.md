# Revisão de roadmap após a integração do PTO V1.6 — 13/10/2026

**Natureza:** revisão de planejamento e ownership, não modificação de gameplay. **Referência de estado:** RE `main@5c6d51cbddab7ffe9ddde1289b7f80e88b18ecd3` (PRs #39 e #45), RC `main@e55dd9e141c7b536b63da799677c02d14c8a3efc` (PR #25 incorporado em `f04d28c`, depois documentação). CI de ambas as `main` aprovado. O número do mod `0.0.1.0` não equivale ao número do marco funcional PTO V1.6.

## Decisão

**A etapa de integração do PTO V1.5/V1.6 terminou para uso individual no FS25. O roadmap do RE/RC NÃO terminou.** As provas são limitadas aos cenários testados, e o usuário não tem previsão de fazer multiplayer.

O sistema RE atualmente responde por:
- seleção de marchas físicas de TDP realmente disponíveis (540, 540E, 1000, 1000E, por hardware/perfil);
- comando manual de RPM, intertravamento contra troca com eixo mecanicamente engatado, seleção conservadora pela IA;
- persistência e eventos de rede protegidos em código, HUD de RPM **cinemática estimada**, `PWR?` para potência sem entrada mecânica identificada, e `rePTOInspect` sob demanda;
- integração com o MR e RMS por **RC**, sem assumir propriedade de torque, combustível, falhas, desgaste, rotação hidráulica, tensão elétrica ou potência dos implementos.

RC `main` normaliza referência de cardã nominal do HM10-500 `PROFILE 1000` independentemente do `PowerConsumer.ptoRpm=540` bruto. O log de 13/10 mostra `mrPtoRpmRatio≈shaftPhysicalRpm/1000` dos dois lados do limite de 0,78 programado pelo MR. Isso prova a **tradução da relação em jogo** e não prova visualmente a interrupção/retomada de alimentação com toras.

### Critérios de conclusão do marco V1.6

| Critério | Estado | Prova / exceção |
| --- | --- | --- |
| Merges RE V1.5 e V1.6 | **FEITO** | #39 e #45; CI main aprovado |
| Merge RC para perfil HM10 | **FEITO** | RC #25; CI main aprovado |
| Berthoud mecânico, Horsch sem entrada mecânica, Krone 540E/540 | **PASSOU nos cenários medidos** | `docs/research/2026-10-13-pto-field-validation-berthoud-horsch.md`; `docs/research/2026-10-13-pto-krone-varipack-runtime-smoke.md`; pós-merge sem erros RE/RC PTO atribuídos |
| HM10 física/normalização da relação MR | **PASSOU em jogo** | RC `docs/research/2026-10-13-pto-heizohack-nominal-mr-bridge-fix.md` |
| HM10 alimentação efetiva abaixo/acima de 0,78 | **PENDENTE, não bloqueante** | [RC issue #26](https://github.com/rafaaelalves/FS25_RealismCompatibility/issues/26) — teste breve com madeira, quando conveniente |
| Autorização/sincronização multiplayer real | **NÃO TESTADO, sem prazo** | [RE issue #46](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/46) |
| Compatibilidade universal com implementos, configurações opcionais e múltiplas saídas | **NÃO AFIRMADA** | Identificar e testar casos antes de declarar suporte |

**Política:** manter V1.6 na `main`. Não bloquear uso individual por MP sem disponibilidade; não mascarar ausência de prova. Não reeditar física MR/RMS para fazer testes passarem.

## Fila prioritária — não confundir pesquisa, implementação e validação

### P0 — Recuperar confiabilidade da deformação de terreno (RE experimental)

**Por quê:** o ciclo de gameplay real `colheita → recuperar sulcos com grade/cultivador → semear` falhou: repetidas passadas deixam sulcos resistentes, a semeadora pode voltar a afundar, e o `TerrainDeformation` **continua desabilitado por padrão na `main`**.

Pesquisas e branches já existentes:
- [PR #36](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/36): `TerrainPlasticYield` evita sulco permanente onde o solo realmente suporta a máquina;
- [PR #38](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/38): integração **experimental** do PTO e terreno;
- [PR #40](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/40): broadphase em histórico de sulcos, otimização ainda experimental;
- [PR #42](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/42): demonstra contaminação do plano de referência usado no reparo;
- [PR #43](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/43): diagnóstico dos comandos GIANTS `TARGET` que não elevam o ponto;
- [PR #44](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/44): referência corrigida de dois anéis, filtrada por histórico; **CI da proposta, não aprovação no jogo**.

**Duas causas independentes:** referência de superfície contaminada pode estimar altura errada; **e mesmo um target bom pode não modificar a altura física**. Não tomar callback `STATE_SUCCESS` como recuperação. Não resolver por `RAISE` indiscriminado (já produziu montes artificiais).

**Próximo trabalho sem gameplay do usuário:** rebase/reconciliação limpa do PR #44 com o PTO atual sem importar terreno à `main`; comparar `TARGET` vs variantes GIANTS da deformação por contrato e testes de isolação; desenhar telemetria de alvo fixo/altura física e orçamento de jobs. **Próxima prova exigida:** cópia do save danificado, mesmas passadas 1/2/3, perfil de altura antes/depois, semeadora trafegável e sulco ainda possível em solo saturado com carga/deslizamento; avaliar desempenho/persistência. Não desbloquear produção só por CI.

### P1 — PTO V2: consequências operacionais específicas, e não mais uma fórmula global

A V1.6 resolve estado/engrenagem/interface; **não** resolve toda hidráulica e toda cinemática dos implementos. Caminho:
1. **Inventário de proprietários e variáveis disponíveis (pesquisa):** estudar fluxo `engineRPM → shaftRPM → available torque → MR PowerConsumer/load → implementação de trabalho`. Usar `MR_Baler.lua`, `MR_WoodCrusher.lua`, GIANTS `Baler`, `Mower`, `PowerConsumer`, `Sprayer`, `TurnOnVehicle`, implementos com entrada PTO e eventuais transmissões hidráulicas/elétricas.
2. **Matriz de lacunas comprovadas:** para cada tipo verificar se GIANTS/MR já reduz produtividade, enche mais lentamente, interrompe rolos ou limita velocidade. Separar `RPM calculada`, `vazão de material`, `massa de fardo`, `carga kW` e `velocidade de trabalho`. Uma máquina ligada com eixo lento não prova que processou palha normalmente.
3. **Observabilidade mínima:** se dados internos já existem, registrar em eventos / snapshots sob comando, não por frame. O HM10 precisa apenas de `mrFeedingActive` e fluxo real para fechar issue #26.
4. **Uma proposta por fenômeno somente se faltar propriedade real:** por exemplo, resposta de alimentação ao eixo lento **onde MR não faz isso**, ou modelo de bomba/ventilador **após** definir vazão, pressão, cavitação e limites. Não alterar pulverização por uma equivalência arbitrária RPM↔litros.
5. **Testes de invariantes e integração:** 540/1000/versão economy sob carga, manutenção de torque MR, RMS como dono de dano, IA com governo próprio, zero energia física em estado desconectado, saves e orçamento de CPU.
6. **Somente depois:** embreagem/engate sob carga, seleção frontal/traseira independente, comportamento de acoplamentos e modos opcionais, se equipamento/engine permitirem. Nenhum compromisso de implementação sem prova.

**Proibido duplicar:** carga sintética extra, consumo de combustível multiplicado, penalidade universal de produtividade, stall automático ou colisão de dois donos da mesma mecânica. Referência: `docs/research/2026-10-13-pto-release-gates-and-baler-simulation.md` e ADR `0006-pto-manual-engine-governor.md`.

### P1 — RC: estabilidade e conflitos realmente reproduzidos

- **RE/RC como donos da compatibilidade, não correção arbitrária de cada mod.** Investigar erros recorrentes de vida útil `manualAttach delete(nil)`, `Wheel shape not found` e especializações duplicadas CBI, usando reprodutor mínimo; se for defeito isolado do mod, registrar/fixar upstream ou em patch separado de versão.
- Usar `docs/project/DEFERRED_RUNTIME_EXPERIMENTS.md` do RC para casos condicionais: força/desgaste do Reifen após mudança 2WD/4WD pelo RMS; raio estrutural; pneus furados; oscilação parado com Mud; RMS PTO baixo/alto RPM.
- Manter critérios por evento e anti-noise; nenhum leitor per-frame indiscriminado apenas para diagnóstico.

### P2 — Mecânica configurável e peças reutilizáveis: módulo/projeto independente

**Pesquisa nova, coerente com o objetivo de trocas sem descartar componentes:**
- **Equipamento reutilizável (primeiro):** rodados, rodas duplas, pesos e lastros. Separar peça física que pode ser armazenada da **configuração comercial**/mão de obra. Só afirmar que é reutilizável se o mod/veículo expõe variantes e se a engine consegue representar a mudança sem compra/respawn destrutivo. Registrar compatibilidade por cubo/eixo, montagem, espaço físico, propriedade, preço e persistência.
- **Mecânica maior (depois):** motores, caixas de marcha, relações, diferencial, pneus e desempenho. Primeiro auditar `motorConfigurations`, relações nativas e a física MR/RMS. **Não criar um segundo motor/caixa de marchas em RE**; preferir interface de oficina/configuração e provider por proprietário de física, com consequências testáveis.
- **Gerenciamento de desgaste de pneus:** avaliar a absorção em fases do Reifen (T1→T5) documentada em RC; se escolhida, evitar duas fontes de desgaste e avaliar dependências de shaders/licença. A ideia de guardar um jogo de rodas é distinta de copiar todo Reifen.
- **Separação de responsabilidade:** apresentação/armazenamento/oficina no novo módulo ou projeto; desgaste no Reifen/RMS conforme ownership escolhido; potência/torque no MR; pressão/sink no Mud; RC compõe.

**Gate inicial:** pesquisa de API/configurações de veículo e protótipo num único trator e num conjunto simples de rodas/pesos, com rollback e sem consumir os objetos removidos. Não apresentar como viável em todos os veículos antes da prova.

### P2 — Colheita, fluxo de material, FarmKit e ecossistema de obras

- **Realistic Harvesting 1.6.2 + WA Clogging 1.4.1:** auditoria já cruzada com MR/RMS/MoistureSystem/AI. Testar separadamente a atualização RHM e a convivência WA, preservação de material entupido após salvar/recarregar, controles, funcionário/Courseplay e ausência de dupla demanda. **Combine Blockage é apenas pesquisa**: não instalar junto com WA para duplicar o mecanismo.
- **FarmKit:** preservar funcionalidades únicas; avaliar bridges somente após conflito de ownership/contrato confirmado.
- **TerraFarm + Mining Layers:** manter mineração/geologia e obras como sistemas externos; RC fornece compatibilidade onde comprovada, RE reage às consequências de tráfego/deformação. Auditoria do Mining Layers 1.7.4 aponta riscos de persistência fora do save, zoneamento e seleção de materiais; não absorver o mod por reflexo.
- **RE restante:** CropInteraction, SurfaceContamination, efeitos e HUD unificado aparecem no `ROADMAP.md`. São candidatos, não features concluídas.

### P3 — Longo prazo / pesquisa de viabilidade

- Terreno 3D/volumétrico e conservação real de massa de solo (não presumir que brush de heightmap satisfaz ambas);
- múltiplos eixos, pneus duplos, esteiras, CTIS e contato/pressão;
- ecossistema FS25 transporte/logística, obras/mineração e veículos reparáveis; modular por capacidade, não um mega-mod;
- otimização, persistência, API de fornecedores, IA/Courseplay, multiplayer posterior.

## Ordem de execução recomendada

**1.** Fechar PTO V1.6 como marco sem criar outra build; issue RC #26 espera apenas observação de alimentação, RE #46 espera MP sem prazo.
**2.** Antes de iniciar *qualquer* trabalho de terreno, reavaliar o PR #44 contra `main` atual e decidir contrato de reparo físico `TARGET`; preferir experimentos em branch isolada.
**3.** Em paralelo documental, produzir **matriz PTO V2 por tipo de implemento e owner**; só criar branch funcional se uma falha de produtividade/cinemática independente de MR for demonstrável.
**4.** Tratar rodas/lastro como **projeto de configuração/oficina** que pode avançar separadamente da geometria do solo e do núcleo PTO; pesquisar engine/persistência antes de decidir anexação RE.
**5.** Retomar colheita, FarmKit, mineração/obras, cultura e contaminação conforme impacto e evidência, sem misturar PRs.

## Fonte de verdade e documentação histórica

- `docs/project/ROADMAP.md`, `PROJECT_STATUS.md` e `OWNERSHIP.md` são a referência **vigente** do estado do projeto.
- `CURRENT_HANDOFF.md` mantém o histórico v7/terreno, mas o cabeçalho deve identificar o checkout atual. ADRs, auditorias e `docs/research/*` são registros datados e não devem ser reinterpretados como instruções vigentes se seus PRs já foram integrados.
- `docs/architecture/CAPABILITY_OWNERSHIP.md` é a matriz detalhada; a linha antiga que dizia Dynamic PTO owner foi substituída pela arquitetura RE PTO + RC bridge, com Dynamic PTO **alternativo**.
- `docs/project/BACKLOG.md` do RC é arquivo histórico; usar PRs/issues e `DEFERRED_RUNTIME_EXPERIMENTS.md` para decisões atuais.
