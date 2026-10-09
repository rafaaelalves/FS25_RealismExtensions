# Terrain: efeitos líquidos do tráfego durante o preparo e custo da proteção

**Data:** 2026-10-09. **Status:** estudo de arquitetura e proposta, sem alteração no jogo, sem aprovação de nova mecânica.  
**Escopo:** somente RE `TerrainDeformation`/`TerrainRecovery`, sem PTO, sem novo solver MR/Mud ou física de guincho.  
**Evidência:** branch `feat/terrain-recovery`, código-fonte; log `log(20261009-111226).txt` (RC provider v2 conectado, 52min de operação SHALLOW_DISC); explicação observacional do usuário de que a área inicialmente não tinha histórico local de sulcos.

## Decisão de engenharia recomendada: efeito líquido, não write e undo imediatamente

Um tractor cultivando cruza o campo **antes** do implemento traseiro. A roda poderia deixar sulco, mas logo depois o implemento revolveria/regularizaria parte do mesmo solo. Não é necessário escrever o sulco no heightfield e escrever uma segunda vez o inverso apenas para imitar cronologia. É legítimo **fundir trabalho + trânsito em um estado final autorizado** desde que preserve:
- MR/Mud físicos **sem** imunidade de tração, resistência, sink temporário e atolamento;
- dano persistente gerado por outra máquina ou fora da faixa efetivamente trabalhada;
- sulcos/bermas históricos que ultrapassem capacidade da ferramenta;
- compactação de subsuperfície como efeito distinto de superfície visível, sem duplicar SoilCompaction;
- penetração/movimento real e largura das bandas no futuro ContactFootprint.

A operação física não define "sulco especial de semeadeira/colheitadeira": roda/pneu/esteira, massa e solo determinam pressão e deformação; a classe do implemento determina **apenas** se e como a área é posteriormente trabalhada (cultivo, aração, grade) ou não (semeadura, colheita, reboque), e o acabamento que deixa.

Fontes agronômicas externas (apoio de plausibilidade, não prova dos algoritmos): University of Nebraska CropWatch [Avoiding Compaction at Harvest](https://cropwatch.unl.edu/avoiding-compaction-harvest/) — operações de preparo em solo muito úmido podem agravar compactação profunda apesar de deixar a superfície aparentemente solta; University of Minnesota [Soil Compaction](https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/soil-compaction) — efeitos de carga de eixo, tráfego repetido e limitação de preparo superficial contra compactação profunda.

## O que o código RE faz hoje (verificado)

1. `TerrainWorkContext.captureTillagePre`: `potentiallyWorking` quando a especialização existe, está habilitada e velocidade >0,5 km/h. **Não confirma** `spec.isWorking` nem `processedArea>0` antes do método GIANTS; é uma proteção preemptiva contra order-of-callback.
2. `TerrainRecovery.processTillageArea`: antes de `superFunc`, marca `activeCombinationUntil[root]=now+1500ms`; no POST confirma `spec.isWorking` e `processedArea` para a recuperação. O guard pre-super não tem cancelamento caso resultado não processe solo.
3. `TerrainDeformationEngine.processSample`: se `isRutGenerationSuppressed` para a **combinação inteira**, sai *antes* de `SpatialHistory`, `SurfaceResponse`, `TerrainResponseModel` e `TerrainWriter`; mantém amostragem normalizada, registro de contato, rodas, MR/Mud e trilhas visuais, já executados noutra etapa.
4. `TerrainRecovery.protectWorkArea`: mesmo sem candidatos a reparar, rasteriza **a área GIANTS efetivamente trabalhada** em grade de 0,40m e marca `protectedCells[key]=now+8000ms`. `Engine.isRecentlyCultivated(x,z)` consulta essa tabela **sem root/owner**: protege contra sulcos de **qualquer** máquina nos mesmos pontos durante 8s, mesmo máquina de fora da combinação. Isto não é um patch puramente visual, mas imunidade temporária global de persistent rut.
5. `SpatialHistory.getRecoveryCandidatesParallelogram`: vasculha células de 0,20m na bounding box da área transformada e filtra histórico por `rutDepthM>=0.003`, cooldown e polígono. Não há pré-filtragem por tile de "há história recuperável nesta região". A proteção 0,40m é calculada **antes** de saber se há candidato. Cerca de 56.615/58.965 callbacks vieram sem candidato (96%).
6. `Recovery.queryLoadedContact` impede que TARGET opere debaixo de rodas ainda carregadas; não depende do guard global. `TerrainRecovery` já usa base de dados de histórico para escolher onde aplicar trabalho: não nivela o campo inteiro a cada passada.

**Consequência:** a regra atual evita a duplicação agressiva rut + repair dentro da mesma combinação, mas também protege outras máquinas e outras regiões cobertas pelo mesmo root, mesmo quando a faixa exata/ordem do trabalho não coincidem. Há possibilidade de intervalos de 1,5s perto de transições, e de falha preemptiva com ferramenta `enabled` mas não `working`. Nenhum desses fatos é por si só um bug de gameplay demonstrado.

## O que o log realmente comprova (e não comprova)

- **A explicação do usuário resolve o aparente mistério de baixa recuperação inicial**: se o terreno da passada ainda não tinha RE rut debt, era correto não encontrar candidatos. O trator/implemento passou a **gerar deformação fora das janelas de supressão**, cujo destino é o próprio solo depois preparado ou a cabeceira. A sequência de história é compatível com o código.
- `TerrainPass`: 10 passes reais, `SHALLOW_DISC` e trabalho GIANTS continuado.
- Ao fim, `protectedMarks=15.637.212`, `activeQueries=809.602`, `activeHits=781.853`; `59.965`? **Usar contagem exata `workAreas=58.965`**. 15,6 milhões são *operações de marcação*, não 15,6 milhões de células distintas.
- Recuperação `intentEmpty=56.615` vs `calls=58.974`: ~96% dos workArea callbacks não trouxeram history candidate. Ainda assim, a rotina local de recuperação acumulou ~47,55 s de CPU wall timings sobre ~53min de jogo (`avg=0.8064 ms`/59k) — não é FPS nem prova isolada de gargalo, mas bom candidato a otimização.
- 20.095 brushes de deformação aceitos globalmente durante a sessão, a maioria atribuída a `AI_FIELD` e à combinação do 7R. Isso **não** prova que a combinação cavou sob a barra abaixada; mudanças de modo, retornos e cabeceiras permitem escrita legítima. Janelas de 5s simultâneas (`work>0, rutAccepted>0`) não identificam colisão mesma célula/momento.
- `SurfaceResponse` classifica `FIELD_SOFT` (perfil nome com CULTIV/PLOW/STUBBLE) com `deformability01=1.0`, `maxStaticRut=0.08m`, `maxSlipRut=0.18m`; é diferente de `FIELD` (0.80, 0.06m, 0.15m). `TerrainResponseModel` gera sensibilidade contínua em `wetness`, inclusive sem chuva no momento; para chuva/umedecimento, tratar calibração **separadamente** da política da ferramenta. `lastPlasticWetness=.65` é um snapshot, não o máximo correlato com maior sulco.
- 50k células de `SpatialHistory` perto do teto; o RE historicamente reconstitui/descarta por atualização e R9. Risco geral de autoria órfã por LRU é uma questão de persistência distinta; não diagnosticar neste caso sem evidência.

## Alternativas de gameplay / custo / risco

**A. Gerar sulco na roda e apagar com a ferramenta**: cronologia literal, mas duplo `TerrainWriter` e histórico; pode oscilar, gastar CPU/heightfield, fazer obra de curta vida. **Não recomendado**.

**B. Proteger toda combinação durante operação + célula trabalhada com TTL (atual)**: eficaz e barato na autorização por root, evita oscilações, MR/Mud continua funcionando. Porém marcamos muitas células 0,40m e a imunidade de 8s vale até para máquinas de outra combinação; `root` protege rodados que talvez nunca sejam alcançados pela barra.

**C. Efeito líquido orientado a operação de solo, com faixa real (recomendação futura)**:
- a área `GIANTS workArea` é *resultado pós-ferramenta* e não deve sofrer novamente rut persistente do mesmo conjunto durante a operação;
- permitir desgaste/sink físicos contínuos via Mud/MR e manter as marcas visuais se apropriadas à engine;
- no mesmo frame, não enviar comando lowering se o próprio implemento vai anular a marca imediatamente (evitar writes redundantes);
- *não* isentar máquina independente que cruze o campo recém-preparado; no mínimo distinguir `sourceRoot` da máscara de proteção;
- nem toda roda da combinação pode ser presumida "antes" do implemento: rodas traseiras de rolos/implementos, voltas e partes fora da largura/curvas são casos reais; fase inicial pode manter o guard de combinação por ser conservador, com exceções só sob necessidade demonstrada;
- conservar `SpatialHistory` pré-existente e recuperar somente até capacidade por ferramenta. O implemento não é um bulldozer de nivelamento;
- casos extremos de umidade: superfície pode ser nivelada com aparência lisa, mas isso não justifica eliminar efeitos Mud/stuck/compactação profundas.

**D. Só marcação espacial e cálculo para cada roda em cada frame**: física/atribuição refinada, mas maior custo complexo e risco de refazer R6 sem benefício imediato. **Não recomendado como próximo passo**.

## Otimizações concretas e ordem

**O1 (maior retorno potencial): broad-phase de histórico espacial**  
Adicionar `hasRecoverableHistoryInWorkArea` com indexação em tiles leves (por exemplo 2m–4m) **mantida sob commits, recovery e eviction**. No caso sem história local, pular busca 0,20m completa; porém **não** pular proteção de trabalho se ainda necessária. Um cache negativo desatualizado poderia esconder ruts históricos; exigir harness com inserção/retirada e bordas geométricas, e perfil contra baseline. Isto é proposta, não alterado.

**O2: substituir rasterização repetitiva da máscara 0,40m por um índice espacial temporal ou por patches de área swept/coalescidos.** Separar root/owner e expiration; preservar segurança de ordens GIANTS e reconhecimento de segmentos. Estimar consumo de memória e custo antes; não mover `protectWorkArea` inadvertidamente para uma fase posterior que crie novamente rut-before-work.

**O3: refinar pre-supressão potencial vs confirmação real pós-super** caso haja exploit/efeito visível com ferramenta erguida/fora do campo. Guard conservador pre-super é importante para order-of-execution, mas não pode dar proteção indefinida a root sem trabalho verdadeiro. Validar comportamento GIANTS por harness e depois gameplay específico.

**O4: manter `TARGET`/parâmetros R6/R7 fixos durante O1/O2.** Não alterar `wetnessExponent`, slip/stuck, pressão pneu, severity, load e algoritmo de reconstrução no mesmo experimento. Medir custos e visuals numa sessão representativa (não dez builds por número).

## Critério prático de aceitação

1. Sem rut geométrico criado **e imediatamente apagado pela mesma ferramenta**, ou job redundante oscilando no trecho trabalhado;
2. Solo histórico recuperável apresenta melhora física e não perde sua história prematuramente;
3. Rodas/trem de máquinas fora da área efetivamente trabalhada e outras máquinas **não ganham imunidade indevida** sem uma justificativa de performance;
4. MR/Mud sink/stuck continua exigente em solo ruim, não há "trator imune à lama quando baixa a grade";
5. Contagens `protectedMarks`, `intentEmpty`, `work-area recovery elapsed`, `TARGET no-op` e payload memory melhoram ou não regridem, sem perda de correção funcional;
6. O benchmark do campo não danificado deve refletir poucos ou nenhum `TARGET`, com custo de busca mínimo; testar também campo danificado real e cabeceiras.

**Decisão de hoje:** documentar, não alterar física. Versão atual B é aceitável para **fechar terrain v1 se experiência permanecer correta**. O1 e O2 são as primeiras otimizações com retorno provável; C é direção arquitetural, não urgência nem autorização para abrir meses de pesquisa. Seguir para `ContactFootprint` depois de validação de durabilidade/roteiro reduzido. 
