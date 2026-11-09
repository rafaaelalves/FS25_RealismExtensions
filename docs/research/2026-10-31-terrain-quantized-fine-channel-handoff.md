# Terreno RE — handoff técnico e decisão de arquitetura após calibração de 29/10

**Data:** 2026-10-31. **Escopo:** análise + plano de implementação; **nenhuma alteração de runtime/Config/RC/main, nenhuma build ou aceite FS25**. Base experimental: PR #64 `feat/terrain-native-transaction-v1-2026-10-23` em `6814243e`. Referências obrigatórias: issue #63; `2026-10-23-terrain-recovery-release-reset.md`, `2026-10-28-permanent-height-actuator-redesign.md`, `2026-10-29-native-absolute-vertex-live-calibration.md`.

## 1. Evidência confirmada e hipóteses distintas

- Recuperação antiga R1/R7 por TARGET/anéis **reprovada como gameplay**; o manual Amenizar funcionou substancialmente melhor no mesmo local, mas o seu escopo/brush/semântica é diferente. Não retomar ciclos longos de arar/semear/colher nem aumentar cegamente strength/retries.
- PR #64 criou journal geométrico por vértice principal e callback, first-touch, invalidação por alteração alheia, recuperação causal e manutenção. Houve progresso físico parcial em jogo, mas os buracos profundos continuaram inaceitáveis. **Main e RC não receberam essa versão experimental**.
- 25/10: callback chegou a sugerir até 58,4 mm para pedidos milimétricos; naquele momento não havia atribuição causal isolada suficiente. A distinção entre fila e `:apply` nativo foi corrigida.
- 27/10: **um único** brush nativo ADDITIVE, sem roda, pediu 1,5 mm e deslocou um vértice principal ~7,78 mm. Isso reprova o uso desse atuador como contrato literal de 1–3 mm. Não prova bug do GIANTS.
- 29/10: **um único** `setTerrainHeightAtWorldPos` absoluto pediu redução de 1,5 mm no vértice principal x=344,z=388 e mediu ~3,891 mm no centro, **1/9 vértices alterados**. O resto do intervalo do log não mostra teste de save/reload ou colisão. A densidade de amostras 0,125 m do mesmo `getTerrainHeightAtWorldPos` é **interpolação da superfície consultada**, não acesso independente à geometria fina.
- A hipótese `255/65535 m = 3,89105 mm` explica os 3,891 e ~7,782 mm; **altura vertical do mapa / quantum não foi verificada independentemente**. Não hardcode; observar mapa por mapa.
- GIANTS descreve sua deformação/collision de rodas em grade **0,125 m**, distinta do `getTerrainHeightmapUnitSize` de **1,0 m** constatado no mapa. Sem API verificada de readback da grade fina, não é válido declarar que mudanças no MAIN correspondem às marcas finas.

## 2. Três abordagens (não tratar como uma simples recalibração)

1. Suavização nativa/R3 e elevação aditiva/R4: alteravam algo visualmente, mas smoothing podia baixar mais do que levantar e RAISE produziu montes; não convergiam na recuperação causal.
2. Modelo persistente R6/R7 + TARGET e estimadores locais de plano/anéis: maior modelagem de solo e ferramentas, porém confiança geométrica falsa, histórico 0,2m desvinculado da malha MAIN 1m e callbacks/no-op. Inadequado mesmo com coeficientes melhores.
3. PR #64 atual: journal geométrico verificado + restituição causal, depois confinamento do writer, `SHADOW` não destrutivo, teste de setter absoluto e orçamento cumulativo quantizado. **Existe mecanismo de estudo e safety gates, não um atuador físico pronto para produção.**

## 3. Decisão: arquitetura híbrida, com dois domínios físicos e um lógico

| Camada | Propósito | Autoridade hoje | Requisito para ser gravável |
|---|---|---|---|
| `0,125m` native wheel displacement | Sulcos/micro-relevo e colisão local de pneus e implementos | GIANTS e seus subsistemas; RE apenas observa `displacementScale` atualmente | Provar atualização de wheel shape, persistência e restauração da mesma camada; não confundir com TireTrack visual |
| `0,20m` RE SHADOW source | Exposição, bearing/plasticidade, cisalhamento, solicitação geométrica e dívida por fonte | RE, **volátil; sem write/save nem autoria física** | Não poderá tornar-se journal geométrico sem readback, epoch, mapa e reconciliação |
| MAIN `~1m` native height vertices | Edição estrutural persistente excepcional, se necessária | GIANTS. Setter absoluto medido **somente como diagnóstico** | Quantum local, alinhamento/origem, 3x3 sem danos colaterais, collision, save/reload, permissões, concorrência e recuperação comprovados |

**Não elevar cada wheel tick à malha MAIN.** É grosseira demais para retratar a faixa estreita do pneu. A regra `max` por vértice, usada no SHADOW, é uma **barreira contra somar ~25 fontes**, não uma prova de forma/cobertura física correta. Uma futura proposta MAIN precisa de suporte espacial/footprint reconhecido e teste em declive/curvatura, além do valor máximo. Se uma faixa fina não pode ser representada seguramente por um vértice de 1m, **não gravar esse vértice**; conservar resultado no domínio fino se comprovado, ou declinar a funcionalidade sem criar cratera. Nunca alargar arbitrariamente a depressão para atingir o MAIN.

**Cumulativo, não aditivo repetitivo.** O `TerrainQuantizedHeightBudget.requestTarget` já mantém `demandTargetM`, `committedM` e pendências por vértice. O contrato deve continuar: um objetivo de 10mm reobservado 500 vezes não autoriza 500 escrituras, somente incrementos representáveis e *fisicamente verificados* dentro do objetivo. `retireTarget` exige recuperação de altura real; trabalho lógico/virtual nunca aposenta uma altura MAIN por si só.

**Distinção de retorno:** pedido 1,5mm => lido 3,891mm prova movimento nativo em um vértice em uma sessão, não prova módulo de persistência/colliders nem quantum global. Callback `STATE_SUCCESS` ou volume não substitui os 3x3 before/after. Atribuição causal estrita exige exclusão própria, proteção contra edições estrangeiras e verificação em tempos distintos.

## 4. Aprendizados das auditorias e ownership

- **RC:** preservar MR (dinâmica), Mud (wetness/sink/atolamento), Reifen (desgaste), SoilCompaction (agronomia), RMS (mecânica); o RC oferece `ExtensionsStateProvider` v2 para dados e compatibilidade, **não é novo dono da geometria**. A versão RC main 0.2.0.9 foi validada no escopo específico; isso não certifica todo modlist ou conflito de geometry.
- **TerraFarm:** estudar separação entre operação, footprint, modo, preview, constraints, callback físico e `aiSystem:setAreaDirty`; nem todo Amenizar/SMOOTH usa brush/eixo igual ao do RE. Edições TerraFarm são edits alheios: não restaurar contra baseline de antes delas.
- **FarmKit:** um brush ADDITIVE com `deformAccum` por roda/episódio e callback vazio pode gerar sulcos, mas não certifica altura ou ciclo de reparo; não reativar writer duplicado como workaround.
- **Visual Mud Tracks:** first-touch, autor da superfície, replay idempotente, coordenada mundial exata, saves geracionais são precedentes a investigar por implementação própria e auditoria exata, sem assumir code reuse ou equivalência operacional.
- **Soil Deformation Save 1.0.0.0:** auditoria exata 26/10 prova um **caminho alternativo que mede sink nativo por proxy e o reconstrói no MAIN** com um setter. Isso NÃO prova persistência da grade fina e pode baixar um heightmap já alterado, limpar history sem changedArea e introduzir dois autores; não instalar junto com escritor RE nem absorver código/asset (direitos restritos).
- Os experimentos anteriores de clipping com RE OFF ocorreram em sessão distinta de logs enviados: preservar essa observação; não atribuir genericamente ao RE ou descartá-la.

## 5. Ordem de trabalho **sem pedir outro ciclo agrícola**

### Gate A — modelagem/segurança de fonte (código + mock, sem FS25)
1. Revisar `TerrainAbsoluteHeightPlanner`, `TerrainQuantizedHeightBudget`, `TerrainAbsoluteVertexCandidate` e `TerrainGeometryJournal` para fechar contratos de *quantum por mapa*, origem/alinhamento da grade, `source → vertex`, epoch e footprint estreito. Testar mesma fonte repetida, fontes concorrentes, posição perto de borda, declive, duas trilhas paralelas, trabalho agrícola no polígono e edit externo.
2. Adicionar *classificação de representabilidade* da impressão na malha MAIN: sem suporte/controle de área suficientes, estado explícito `FINE_ONLY_OR_UNREPRESENTABLE`, não uma nova escavação. Manter SHADOW no runtime até haver critério medido para suporte e compromisso com shape.
3. Revisar o modelo fino nativo observável e a possibilidade real de persistência/restauração **sem alterar `WheelPhysics.displacementScale` automaticamente**. Nenhum hook universal/wrapper que capture subsistemas de MR/Mud.

### Gate B — um teste curto de setter excepcional, apenas quando código preparado
1. Clone descartável do save pré-deformação; nenhum save principal. Um alvo 1m, marcação exata, no wheel load, snapshot de 3x3 antes/instantâneo/depois.
2. Na **cópia**, verificar persistência ao **salvar/recarregar**, estado de colisão/solo sob roda descarregada e comportamento no render; retornar com snapshots e identificação de build. Um teste de setter NÃO autoriza wheel writer por default.
3. Alteração externa deliberada na cópia deve invalidar a propriedade RE; nenhuma regrada/replay sem fonte verificada. Não ensaiar MP antes de SP confiável.

### Gate C — recuperação de um sulco RE recém-verificado
- Diferenciar dano normal fino, dano excepcional MAIN e solo legado desconhecido. O novo sistema **não** restaura milhares de sulcos antigos por inferência.
- Ferramenta realmente trabalhando + work-area GIANTS válida seleciona *somente* a superfície confirmada de RE; TARGET ou SMOOTH de acabamento deve comprovar melhora física, sem nivelar declive. Uma operação primária correta + até uma secundária, caso o solo esteja apto. Caso contrário, informar impossibilidade e motivo; não repetir retries.
- Confirmar caso real de colisão, persistência, AI/Courseplay, custo e política mensal de NPC/prefeitura sem liberar manutenção para tocar edições não RE.

## 6. Liberação e integridade do projeto

- **PR #64 permanece draft**, `main` RE/RC intocadas. `TerrainPermanentActuator="SHADOW"` ainda significa **sem writes RE automáticos**. Os testes de 29/10 não liberaram novo modo de escrita.
- Não gerar ZIP/build a partir de mudança somente documental. Não transferir promessas de mock CI para jogo real.
- Sempre usar identificadores exatos de build, mapa, saves e condições; distinguir `REQUESTED`, `OBSERVED_MAIN`, `OBSERVED_FINE` (se houver leitor validado), `PHYSICS_COLLISION`, `SAVE_RELOAD`, `RECOVERY`.
- **Critério de sucesso não é só a altura exata em milímetros:** é trafegabilidade, mudança física proporcional, reversibilidade agronômica, compatibilidade de ownership e proteção de terreno legítimo.

**Próxima atividade recomendada nesta branch:** estudar e prototipar um gate determinístico de *representabilidade do footprint MAIN* e um protocolo de persistência/colisão de um único setter. Não chamar a arquitetura híbrida de finalizada antes de medir a camada fina do jogo e recuperar em gameplay uma deformação RE nova.