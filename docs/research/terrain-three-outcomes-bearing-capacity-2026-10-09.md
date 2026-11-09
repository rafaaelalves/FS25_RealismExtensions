# Terrain — três resultados do tráfego, resistência do solo e ciclo agrícola

**Data:** 2026-10-09. **Estado:** estudo de revisão física e prioridades; não é código nem parametrização aprovada. **Motivação:** gameplay relatado: colheitadeira deixa sulcos severos, cultivo exige vários passes, semeadura recria sulcos — ciclo sem saída; falta compactação diferenciada de deformação de heightmap, solo sólido tratado como lama.  
**Código examinado:** `scripts/terrain/TerrainResponseModel.lua`, `SurfaceResponse.lua`, `SpatialHistory.lua`, `TerrainDeformationEngine.lua`, `TerrainRecovery.lua`, `FootprintModel.lua` na branch `feat/terrain-recovery`; auditoria exata `RC/docs/audits/2026-09-22-soil-compaction-audit.md`; RC `scripts/integrations/MudSoil.lua`; runtime `log(20261009-111226).txt` (RCv2 conectado, máquina SHALLOW_DISC, terra inicialmente sem histórico de sulcos).

## Diagnóstico de modelo (verificação de fonte vs inferência)

1. **RE separa Mud sink transitório, mas não compactação de rut geométrico.** `TerrainResponseModel.compute` recebe pressão, wetness, slip, raio, estado externo; calcula `soilSusceptibility01`, capacidade geométrica e exposição cumulativa, convertendo-a diretamente em `rutDepthM`. Não aplica um teste explícito de **limite de suporte/yield plástico** para decidir quando uma carga apenas densifica/compacta em vez de deslocar a heightmap.
2. `drySusceptibilityFloor=.06`, `basePassDrive=.10`, `minRutDepthFraction=.01`: mesmo em solo relativamente seco, movimento normal pode acumular exposição positiva e algum rut geométrico ao longo de passagens, condicionado à categoria `SurfaceResponse`. `FIELD_SOFT` usa `deformability=1.0` e teto de 8cm estático/18cm slip, `FIELD_FIRM` 0.55 e 4cm/10cm. Capacidade é teto, **não profundidade produzida necessariamente por um passe**.
3. `plasticSinkStartWetness=.45` e `Full=.90`: o modelo permite transferência parcial do sink Mud para plastic geometry com umidade moderada; chuva instantânea não é o fator correto, mas é possível severidade exagerada antes de saturação. Precisamos de histograma condicionado à situação, não inferir taxa de formação só do máximo de rut.
4. `SpatialHistory.applyRecoveryAt` zera proporcionalmente `rutDepthM`, `longitudinalShearDistanceM`, `lateralShearDistanceM`, `slipExcavationDistanceM` e `deformationExposure` conforme o sulco é corrigido. Isto limpa a dívida **geométrica**, não equivale a retirar **densificação subsuperficial**. Não existe campo persistente de resistência/capacidade estrutural no RE que influa nas passagens subsequentes.
5. **Há compactação real na stack, mas é outro autor:** `FS25_SoilCompaction` v1.0.0.0 tem mapa espacial por célula e penalização de rendimento na colheita, amostragem de veículos a 1s, alívio por preparo, e mod anuncia alívio também por semeadoras. RC `MudSoil` injeta wetness local do Mud nas fórmulas do SoilCompaction. O RE não consulta um estado equivalente de densidade/penetração/resistência; provider RCv2 atualmente publica pressão/contato/slip/wetness, mas não uma capacidade portante histórica explícita.
6. A auditoria exata de SoilCompaction conclui que sua rota ativa usa `baseDamage(mass)*tireMultiplier(width)`, apesar de ter helpers mais completos de carga/pressão/axle em arquivos internos. Logo, **não** supor que um scalar de yield loss do SoilCompaction se converta diretamente em densidade aparente (bulk density), resistência à penetração, capacidade portante ou rigidez; precisaria de um contrato interpretável ou modelo simplificado calibrado. Se semeadoras reduzirão excessivamente a penalização, testar antes de chamar de bug; versão atual permite alívio, mas graus exatos não foram reanalisados aqui.
7. O `TerrainRecovery` suprime todas as rodas da combinação por `activeCombinationGraceMs=1500` e marca `protectedCells` global 8s, enquanto o próprio `SpatialHistory` procura debt histórico. Esses guardas são um workaround secundário. A causa do loop após semeadura é a capacidade do writer de formar novos sulcos toda vez fora da condição de cultivo.

## Modelo físico conceitual proposto

Separar três saídas de um mesmo contato, em vez de três solvers de força:

| Modo | Variável/efeito | Autor | Heightmap permanente? |
|---|---|---|---|
| Cedência instantânea/elasticidade, sink e atolamento | mobilidade e posição física transitória | **Mud + MR** | **não**, por padrão |
| Consolidação/compactação do solo (porosidade, densidade, yield) | persistência agronômica, endurecimento superficial relativo, subsolo | **SoilCompaction**, com RC consumindo/fornecendo somente estado estável conforme contrato | **não necessariamente**; geralmente map/layer |
| Ultrapassagem de resistência plástica e cisalhamento/fluência lateral | sulco e possível berma/fluxo, deslocamento permanente | **RE TerrainResponseModel + Writer** | **sim, somente quando justificado** |

O **mesmo contato** pode gerar compactação sem sulco apreciável, afundamento imediato sem dano permanente, ou os três em solos encharcados e sob grande cisalhamento. Solo compacto pode suportar melhor cargas superficiais repetidas mas infiltrar pior/ficar saturado; não aplicar imunidade linear eterna por estado de compactação.

### Regimes a representar

- **Estruturado e relativamente seco:** contato normal aumenta compactação em certos casos; rut geométrico mínimo ou nenhum. Marcas visuais de pneus permanecem.
- **Recém-preparado e razoavelmente seco:** menor suporte superficial, pequenas marcas são plausíveis, mas a semeadora normal **não exige cultivo adicional**. Desenvolvimento futuro de gradiente de exposição e camadas superficiais, não uma flag de imunidade "seeder".
- **Úmido e sensível:** esforço, pressão ou shear altos podem produzir sulcos localizados; trabalho pode exigir intervenção pontual ou espera de secagem.
- **Saturado, lama profunda ou patinagem extrema:** rut permanente profundo, deslocamento lateral, dificuldade genuína, recovery limitado por ferramenta. Aguardar secagem pode ser a solução, não cinco passes obrigatórios.
- **Faixas repetidamente trafegadas / solo já consolidado:** primeira passagem responde fortemente, posteriores podem causar menos compactação adicional e menos rut em piso firme; em solo saturado e cisalhado, rut pode continuar crescendo — não usar limite artificial baseado só no contador.
- **Rolo/compactador em condição portante:** consolidação progressiva com superfície relativamente lisa, não escavação contínua. Sob saturação/baixa capacidade pode sim haver deslocamento/sulco.

### Adaptação arquitetural mínima

Propor **um critério explícito de suporte do solo contra a demanda de contato** dentro do modelo já existente. Primeiro uma implementação *pura* de decisão `trafficOutcome` (não um novo sistema de forças nem mapa persistente duplicado):
- entradas de RC: `physicalGroundWetness`, `groundProfileName`, `groundMudPotential`, `groundPressurePa`, `wheelLoadN`, `longitudinalSlip`, `lateralSlip`, tipo/geometry; estado de endurecimento/compactação somente se existir API confiável e sem dupla autoria;
- saídas distintas: `plasticYield01`, `geometricRutDeltaM` elegível, `reason`, e estado de compactação **lido**, não escrito;
- contato abaixo do limiar de cedência: continuar Mud e SoilCompaction, mas **não** construir `TerrainWriter` com deformação minúscula artificial. Não simular compactação como buraco mínimo da heightmap.
- contato acima do limiar: usar modelo de exposição/deformação existente condicionado a plasticYield, compatível com os `SurfaceResponse` caps, mas rever `basePassDrive`/min capacity para que saturação nunca signifique crateras inevitáveis em qualquer operação.
- **não** mapear linearmente penalidade de rendimento de SoilCompaction para capacidade portante: verificar semântica/unidades/dinâmica de alívio e autor exclusivo; em falta, fallback seguro usando Mud+classe superficial e declarar que não integra rigidez histórica.
- **não** reduzir a velocidade/força de MR/Mud, não tornar semeadeira imune por classe e não restaurar writers de rut+repair redundantes só para representar compactação.
- `SurfaceResponse FIELD_SOFT` deve descrever solo mais vulnerável, **não** obrigar a uma geometria de 8–18cm. Estado mais mole pode demandar mais tração sem danos extremos no uso normal.

## Escolha de curto prazo vs ambição de longo prazo

**Prioridade obrigatória de gameplay antes de encerrar Terrain v1:** semeadeira pós-cultivo em cenário climático habitual não pode destruir automaticamente a própria superfície. Isso justifica reabrir especificamente a calibração/threshold do *rut permanente* já que o problema é relatado; o aviso anterior de fechamento rápido não pode sobrepor um defeito de jogabilidade claro. Uma única implementação bem projetada, validada por um harness de cenários e gameplay, não expansão indefinida de telemetria.

**Não bloquear v1 em:** resposta de rolamento avançada com densidade 3D; equações constitutivas completas, conservação de massa de bermas; modelo híbrido hidráulico/geotécnico, integração de mapas soil se APIs insuficientes; tuning total de Mud; meses de telemetria; dezenas de culturas/implementos.

## Matriz pequena de aceitação — uma única bateria A/B

1. **Campo normal:** colheita seguida de cultivo e semeadura. Sulcos sob colheita compatíveis com condição, preparo usual resolve superficial sem 3–5 passagens obrigatórias, semeadura em condição portante **não recria** grandes sulcos. Não dar imunidade temporária a outras máquinas.
2. **Solo firmemente compactado/repetição:** duas passadas na mesma faixa e um rolo. Estado de SoilCompaction pode crescer ou saturar; surface rut não cresce indefinidamente como altura de lama. Não ligar yield loss duas vezes.
3. **Solo molhado e carregado:** uma colheitadeira com tanque alto/alta pressão vs rodagem adequada; difere na resposta de ruts. Impactos de Mud sink/stuck continuam normais.
4. **Encharcado + slip alto:** grande sulco persiste, difícil recuperar; respeita tetos e segurança física, efeito não desaparece ao parar de chover.
5. **Recuperação parcial:** grade vs arado/subsolador; melhora material antes existente somente até perfil e profundidade adequados. SoilCompaction profunda mantém dívida agronômica quando apenas se nivelou superfície.
6. **Regressão:** mesma cena, sem dupla penalização, sem writes desnecessários quando `plasticYield01=0`; save/reload e IA/passagens seguem corretos. Medir contagens, não exigir extra instrumentação de callback por partida.

## Base externa para plausibilidade, não extração de fórmula

- Penn State Extension, *Avoiding Soil Compaction*: um grande componente de aumento de densidade e afundamento ocorre na primeira passada sobre solos preparados; umidade e sustentação mudam regimes de dano. https://extension.psu.edu/avoiding-soil-compaction
- Nebraska CropWatch, *Avoiding Harvest Compaction in Wet Soils*: um solo demasiado úmido para suportar colheitadeira normalmente é demasiado úmido para cultivo corretivo; preparo pode destruir estrutura e formar compactação abaixo da camada revolvida. https://cropwatch.unl.edu/2019/avoiding-compaction-harvest/
- University of Minnesota Extension, *Soil Compaction*: profundidade da compactação depende de carga/pressão e solo úmido; presença de sulco não esgota consequências; faixas controladas limitam área danificada. https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/soil-compaction
- AHDB, *Soil compaction from machinery*: deformação com smearing/puddling ou aumento de densidade dependem do solo; compactação e rut não são sinônimos. https://ahdb.org.uk/knowledge-library/soil-compaction-from-machinery

**Resultado:** diagnóstico estático e decisão de prioridade. Nada alterado em `scripts/`, `tests/` ou configuração de gameplay; próxima ação técnica é protótipo matemático puro e harness para `plasticYield`, antes de integração de runtime ou calibração no escuro. A decisão de compartilhar dado SoilCompaction é distinta, após auditoria exata do contrato. 
