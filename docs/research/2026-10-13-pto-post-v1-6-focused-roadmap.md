# PTO: backlog técnico específico após V1.6

Data: 2026-10-13. **Somente TDP/PTO**; exclui terreno, Reifen, manutenção genérica e outras frentes de RE. **Estado de referência:** RE `main@95db50262cad878eb07fcc2f4f4386b47d453971` (PRs #39/#45 funcionais, #49 documentação), RC `main@e55dd9e141c7b536b63da799677c02d14c8a3efc` (HM10 nominal fix PR #25), MR `0.26.10.08`, RMS `0.11.0.0`.

**Conclusão:** a infraestrutura básica de seleção de marchas 540/540E/1000/1000E, hand-throttle, UI, seleção conservadora de IA, persistência, autenticação servidor e tradução RC→MR/RMS está implantada. **Não** estão implantados um estado mecânico separado por saída PTO, uma simulação própria de inércia/embreagem, ou novas curvas por tipo de implemento que alterem sua vazão em função da RPM física. Ausência não significa que todas essas features devam ser implementadas.

## Observações sobre código já existente (não apenas brainstorm)

| Ponto | Evidência direta do código atual | Oportunidade / cuidado |
| --- | --- | --- |
| HUD percorre árvore de implementos a cada desenho | `PTOHUD.lua:457-474` chama `isEngaged()`; `PTOResolver.lua:343-380` percorre implementos; `getObjectPtoActivity` consulta `Profiles.findImplement` e entrada PTO; `PTOProfiles.lua:570-618` monta *identityBlob* e compara tokens por substring | Medir custo antes de alterar. Cachear **somente topologia/identidade do perfil** e invalidar no attach/detach, reconfiguração e exclusão; nunca cachear o booleano ativo como se fosse estado constante. Manter intertravamento de marcha conservador e informação viva no HUD |
| Perfil de trator não é igual a caixa física plenamente observada | `PTOModel.resolveMotorRatio` usa `engineRpm/shaftRpm` quando documentado; caso contrário `maxEngineRpm*(economyEngineFactor or 0.78)/shaftRpm` quando possível | Distinguir relação OEM verificada de **aproximação** derivada da rotação máxima. Não declarar 540E/1000E exactos só porque a marca/linha oferece opcional |
| Saídas e seleção globais | `PTOControl` armazena `spec.mode` e `handThrottlePercent` **por veículo**, e `PTOResolver.collectRequirements` resume anexos recursivamente | Não há seleção independente de TDP dianteira/traseira/central (ou modo especial por saída). Primeiro pesquisar os `outputPowerTakeOffs` e conexão por índice, depois desenhar modelo com múltiplas saídas; não adotar modos inexistentes |
| Presença de entrada não equivale a conexão ativa | `PTOResolver.hasInputPowerTakeOff` verifica tabela de entrada; `detectImplement` permite entrada declarada ou perfil; `isPtoEngaged` pode cair no `getIsTurnedOn()` como alternativa | Resolver por nó: `DECLARED`, `LINKED`, `DRIVEN`, `UNKNOWN`; validar ligação `connectedOutput/connectedVehicle` e estado real sem inferir que `turnedOn` gera torque mecânico. Evitar falsos positivos e também falsos bloqueios de troca |
| Múltiplos implementos e normalização de MR | `collectRequirements` produz `requiredRpm=nil` se houver vários valores brutos; RC `PTOState.getSnapshot` só fornece `ratioData` se `requiredShaftRpm`/referência for positivo | Se dois anexos têm `powerConsumer.ptoRpm` diferentes mas eixo comum conhecido, ponte global pode abdicar de normalizar; investigar split por consumidor/árvore. Não escolher média, nem transformar 340/400/500 em 540 automaticamente |
| Consumo em motores com MR | `MR_PowerConsumer.lua` calcula cargas e `MR_Baler.lua` modela massa/vazão/kW; `MR_WoodCrusher.lua` controla `mrFeedingActive` pelo `mrPtoCurrentRpmRatio<0.78` | As próximas consequências devem ser **incrementais**: primeiro medir saídas efetivas, depois descobrir qual fenômeno não tem dono, nunca acrescentar carga duplicada |
| Compatibilidade/perf em hot paths | RC `PTOState` já tem cache por `vehicle + revision + canonicalRPM`; `MRPTO` usa escopos restauráveis e `RMSPTO` usa wrappers com `pcall` | Os logs já mostraram milhares de escopos sem reinstalação. Perfil de CPU e alocação antes de simplificá-los; *zero regressões/owner bleed* é mais importante que micro-otimização especulativa |

**Fontes de código:** [RE PTOControl](../../scripts/pto/PTOControl.lua), [PTOResolver](../../scripts/pto/PTOResolver.lua), [PTOProfiles](../../scripts/pto/PTOProfiles.lua), [PTOHUD](../../scripts/pto/PTOHUD.lua), [PTOModel](../../scripts/pto/PTOModel.lua), RC [PTOState](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/scripts/pto/PTOState.lua). Contratos públicos GIANTS: [FS25 VehicleMotor#getRequiredMotorRpmRange](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=896&version=script); [PowerTakeOffs (FS22 predecessor—recheck exact FS25 semantics)](https://gdn.giants-software.com/documentation_scripting_fs22.php?category=48&class=534&version=script); [FS25 BaleLoader PTO power semantics](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=635&version=engine). Versões anteriores da API não devem ser tratadas como prova de API idêntica na versão 1.24 do jogo.

## Roadmap **apenas PTO** proposto (numeração provisória)

### Ciclo A — V1.7: precisão de estado, perfis e instrumentação, sem física nova (prioridade alta)

1. **Conexão e acionamento por saída**. Distinguir `input` declarada, conexão real e implemento acionado. Separar carga mecânica de PowerConsumer auxiliar. Preservar fallback `UNKNOWN`. Testes: implemento cardânico, caixa presente mas desconectada, Horsch sem cardã, coletas múltiplas, motor desligado.
2. **Proveniência das relações**. Relacionar por variante/configuração física, marcar `OEM_CONFIRMED` / `NATIVE_GIANTS` / `ESTIMATED_FALLBACK` / `UNKNOWN`. Corrigir perfis que usam `maxRpm*0.78` sem dado de fabricante, sem suprimir capacidade válida quando a API não publica a opção.
3. **Visibilidade para operador:** mostrar RPM nominal, eixo **estimado**, estado desligado/desacoplado e alerta contextual quando **limite documentado** é excedido. Opcional: indicador de demanda atual `kW` do MR como observação, nunca efeito duplicado; UI compacta, não HUD de números.
4. **Otimização mensurada do percurso HUD/Resolver**: contadores de scans, comparações de identidade, cache hit, microbenchmark, com orçamento por renderização; preservar `onPostAttach/Detach` e estados ativos vivos.
5. **Inspeção on-demand de variáveis do MR**: `mrBalerLastTonsPerHour`, `mrBalerSpeedLimit`, `mrBalerLastNeededPower`, `mrFeedingActive` quando disponíveis. Zero logs por frame.

**Critério:** sem regressão no Fiat/HM10 (físico 1000 × MR bruto 540), Krone, Berthoud e Horsch; sem APIs de motor alteradas fora dos escopos; safe fallback, Save/Reload, IA, CI; teste in-game único no fim. Só otimizar o que medimos.

### Ciclo B — pesquisa e um protótipo V2: resposta real do implemento à RPM (prioridade alta de investigação)

Matriz de três domínios iniciais:
- **Trituradores:** MR já possui cutoff de alimentação `<0.78`; verificar com madeira se falta consequência. Isso depende de fluxo de madeira real e `mrFeedingActive`, não de adicionar um segundo limitador.
- **Enfardadeiras:** MR já regula capacidade em t/h, potência, massa do fardo e cadência dos golpes. Questão aberta: existe limitação de alimentação baseada na rotação física do eixo? Controlar o mesmo leirão/carga com ~100% vs ~60% da RPM física e medir **ton/h, massa, velocidade permitida e kW**. Só acrescentar restrição ao owner do fluxo se ele não considerar RPM e se houver uma curva defensável.
- **Pulverizadores / turbinas / hidráulica:** separar bomba mecânica de potência de ventilador hidráulico/elétrico. **Não** transformar RPM em litros/ha diretamente; o regulador de dosagem pode compensar até faltar vazão/pressão. Investigar um único caso com bomba/variantes identificadas. Fase posterior, não primeiro protótipo.

Regras: GIANTS/MR continuam donos dos litros/massa e da potência, RMS do desgaste e choque, RE apenas acrescenta missing output semantics mediante contrato auditável. Uma feature por PR. **Nunca** usar multiplicador universal de velocidade, stall ou consumo.

### Ciclo C — V2+ (pesquisa média): engate e dinâmica transitória da PTO

Fenômenos reais separados:
- **Acionamento/desacionamento independente** do TurnOnVehicle, quando engine e equipamento suportarem distinguí-los; estado físico não deve ser confundido com um comando de ligar o implemento.
- **Embreagem, inércia e rampa de acionamento:** modelar possibilidade `J*domega/dt = T_transferido - T_carga - T_perdas`, controle de embreagem / limitador e amortecimento. **Não** implementar uma segunda fonte de torque contra MR: só após definir como o torque transitório entra no proprietário de motor e em RMS, testar shutdown, spool-up, carga em repouso e sincronização. Isso é mais arriscado que V1.7.
- **Sobrecarga por transmissão:** embreagem deslizante, parafuso de cisalhamento, proteção e eventuais danos. RMS já é dono de falha/desgaste; priorizar provider/evento RMS ou external mod específico, sem repetir suas falhas.

### Ciclo D — V2+ (alto esforço): TDPs dianteira/traseira/central e implementos compostos

Modelo por saída `ptoOutputId`, razão/marcha selecionada, engatamento, cardãs ligados, estados distintos e demanda agregada correta por recurso. Pode haver diferentes categorias de PTO e eixos de energia. Provar no XML/estado runtime como a GIANTS conecta os componentes; respeitar múltiplas configurações opcionais. Não reusar uma única `spec.mode` para todos e nem agregar RPM por média. Avaliar compatibilidade de mods que conectam/desconectam cardãs manualmente sem supor que a animação em si é um motor físico.

### Ciclo E — ergonomia/qualidade (independente dos ciclos anteriores)

- Console de seleção por trator com interface pequena, iconografia e configurações locais; presets de hand throttle em RPM explícitas e indicação de valor **solicitado vs alcançado**.
- Perfil de cabine (alavanca/indicador/tecla) apenas quando for possível sem editar centenas de arquivos I3D.
- AI/assistentes (GIANTS, Courseplay): preferências seguras, confirmação de `nominalFamily` antes de usar engrenagem economy; não trocar em funcionamento; automações testadas por eventos, não scans por frame.
- Diagnóstico versionado de perfil incorreto e opções de relatório para veículo modificado. Falhas do Manual Attach e veículos terceiros permanecem fora da física PTO.

## Priorização técnica resumida

**Primeiro:** rede de ligação real e fallback honesto, profiling do HUD, confiança/proveniência das relações, dados de fluxo MR sob demanda. Isso pode trazer ganhos concretos sem assumir novos modelos físicos.

**Segundo:** estudar **uma** categoria de produtividade que falte, começando por enfardadeiras; decidir implementação só com prova causal. HM10 alimentação pendente na [RC issue #26](https://github.com/rafaaelalves/FS25_RealismCompatibility/issues/26).

**Terceiro:** depois de resolver os pontos acima, embreagem/inércia/sobrecarga e saídas independentes conforme viabilidade de API/MR/RMS. MP real [issue RE #46](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/46) permanece sem prazo; código de segurança ≠ teste multiplayer.

## Requisitos de implementação

1. Nenhuma modificação de produção nesta revisão documental.
2. Desenvolver em branches isoladas a partir da `main` atual, sem código experimental de terreno.
3. Testar hipóteses unitariamente e no wrapper MR/RMS antes de pedir gameplay.
4. Cada teste em jogo deve ser curto e responder uma hipótese nova; reutilizar logs já recebidos.
5. Perfis e curvas são dados com origem e versão; modelos precisos somente quando o jogo representa equipamento compatível. Nunca copiar código/ativos externos sem direito e revisão.
6. Perfis desconhecidos continuam `UNKNOWN` sem imposição de alerta vermelho, exclusão de implemento ou alteração de torque.

**A revisão de estado/performance V1.7 está na [issue #50](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/50); a pesquisa funcional V2 está na [issue #48](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/48).**
