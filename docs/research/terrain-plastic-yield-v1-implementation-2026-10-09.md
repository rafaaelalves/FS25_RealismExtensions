# TerrainPlasticYield v1 — implementado e habilitado na branch experimental

**Data:** 2026-10-09  
**Branch:** `feat/terrain-plastic-yield-v1` sobre `feat/terrain-recovery`  
**Status:** FÓRMULA E HARNESS IMPLEMENTADOS; não atestado em GIANTS runtime. Não é calibração geotécnica experimental medida, nem integração com o mapa de densidade do SoilCompaction.

## Por que existe

Ciclo relatado: colheitadeira marca o campo excessivamente → múltiplos passes de preparo → semeadora cria crateras outra vez. `TerrainResponseModel` anterior tinha `drySusceptibilityFloor`, `basePassDrive` e `minRutDepthFraction` que permitiam depósito de dívida geométrica pelo mero rolamento. Não distinguia demanda mecânica inferior à resistência do solo de cedência plástica.

**Resultado-alvo de gameplay:** solo seco/portante não recebe automaticamente sulcos permanentes em tráfego normal, mas pode acumular compactação via SoilCompaction e sofrer sink via Mud. Solo muito úmido, carga e patinagem severas ainda podem escrever rut profundo. O modelo **não** dá imunidade a semeadora, colheitadeira ou funcionários.

## Implementação de fonte

- `TerrainPlasticYield.compute(context, footprint, surface, options)`: função pura calcula capacidade portante aproximada (Pa) a partir de categoria e `physicalGroundWetness` do RC/Mud, reduzida suavemente quando a umidade ultrapassa regime de transição; pressão normal + demanda adicional associada a slip longitudinal/lateral. Retorna `demandToBearingRatio`, `plasticYield01` e justificativa. Multiplicadores de cisalhamento não são mudanças em MR/Mud.
- `TerrainResponseModel.compute`: quando `plasticYieldEnabled=true`, incrementos de shear e exposição vertical de **rut geométrico** são multiplicados pelo `plasticYield01`; a transferência do sink momentâneo para `persistentSinkM` também passa pelo gate. Quando `plasticYield01=0`, histórico antigo não cria sulco novo só porque mudaram condições ambientais. A flag desligada mantém a rota antiga inalterada.
- `TerrainDeformationEngine.processSample`: encaminha categoria real de `SurfaceResponse` e flag via `modelOptions`; se sem cedência e sem sulco histórico, retorna **sem commit de células vazias e sem `TerrainWriter.enqueue`**. Proteções R6, cooldown, R7, R8, R9, Mud e SoilCompaction permanecem intactos.
- `scripts/Config.lua`: `RealismExtensionsConfig.modules.TerrainPlasticYield = true` na feature **experimental**; mudar para false recupera a decisão física anterior sem tocar o restante do módulo de terreno, para teste A/B.
- `modDesc.xml`: carrega nova classe antes de `TerrainResponseModel`; CI build inclui o arquivo.
- `tests/terrain_plastic_yield_harness.lua`: tráfego seco normal, campo recém-preparado e semeado, demanda por carga/slip extrema em solo seco, solo saturado, transição úmida, congelado, comportamento legado, história antiga sem novo yield, repetição sem dívida oculta, independência de velocidade/FPS, contrato de pressão inválido.
- `tests/terrain_deformation_engine_harness.lua`: comprova entrega da flag e categoria da superfície ao modelo. Nenhum hardcode por veículo, marca ou tipo de implemento.

## Valores temporários — NÃO tratar como resistência medida

`Yield.DEFAULTS.bearingPa` parametriza categorias `FIELD_SOFT` (320→55 kPa entre secos/saturados), `FIELD` (400→95 kPa), `FIELD_FIRM` (520→150 kPa), `DIRT_WET`, `MUD`, `GRAVEL_WET`. Interpolação smoothstep entre `wetness01=0.42` e `0.96`. Demanda `pContact * [1 + 1.45*max(0, |longSlip|-0.10) + 0.65*max(0, |latSlip|-0.08)]`. Cedência = smoothstep((demanda/resistência − 1)/0.80), zerada quando menor que 0.02. Água local 0..1 **não** é ensaio de teor de água, e nenhuma destas pressões substitui levantamento de solo real. O modelo representa um **gate de gameplay plausível**, não previsão científica de argila/areia.

Justificativa qualitativa:
- [Penn State Extension: Avoiding Soil Compaction](https://extension.psu.edu/avoiding-soil-compaction) diferencia tráfego seco portante de rut em condições saturadas;
- [Iowa State Extension: Soil Moisture Conditions](https://crops.extension.iastate.edu/encyclopedia/soil-moisture-conditions-consideration-soil-compaction) descreve aumento de suscetibilidade com umidade e tráfego pesado;
- [South Dakota State: Accounting for Soil Wetness](https://extension.sdstate.edu/accounting-soil-wetness-prior-conducting-farm-operations-minimize-compaction) diferencia compressão máxima perto de umidade ótima e sulcos em solo muito úmido;
- [Embrapa PAB: tire-soil pressure and moisture](https://apct.sede.embrapa.br/pab/en/article/view/3808) relata influência da umidade na densidade do solo em tráfego de trator.
Nenhum destes artigos justifica **os números exatos de kPa deste protótipo**.

## Limites intencionais

1. O SoilCompaction **já** tem seu mapa espacial e penalidade de produção. RE não escreve outro mapa de densidade e não tenta inferir resistência portante do percentual de yield-loss. **Integração estruturada futura opcional** somente após auditoria semântica da API e com ownership claro.
2. Ainda não há detecção geológica de textura (areia, argila, cascalho heterogêneo). `FIELD_SOFT` vem de `groundProfileName` Mud e não é medição de resistência.
3. A política R6 `activeCombination` e a proteção espacial 8s continuam; a semeadora *não é protegida por tipo*, mas pode atravessar célula espacial que outro preparo protegeu por segundos (limitação conhecida a revisar depois). Sem alterar timing GIANTS nesta feature.
4. O modelo considera a parcela plástica do sink como consequência de cedência; **não** altera sink/stuck Mud. Sem SoilMassTransport, bermas reais continuam fora de escopo.
5. Históricos antigos e buracos existentes **não são removidos** por habilitar o gate. A recuperação física anterior continua necessária; fazer backup antes de aplicar build experimental num save importante.
6. Clientes MP, veículos crawlers, pneus multi-faixa e calendário R9 ainda requerem respectivos gates. A versão experimental não é release certificada.

## Critérios de validação real (um único save BACKUP, A/B por build)

1. Em área inicialmente normal, observar colheita→cultivo→semeadura: traços visuais e eventual compactação são permitidos, porém a semeadora em condição portante não transforma o campo em crateras novamente.
2. Em condição razoavelmente seca, trânsito de 7R e outro equipamento carregado: resultado difere por **pressão**, não por nome; novo `plasticSupportedSamples` deve aparecer e writer accepted diminuir.
3. Em condição encharcada e patinando, a deformação física grave ainda existe; confirmar `plasticYieldSamples` e `maxRutDepthM`, sem tornar Mud mais fácil.
4. Campo que já tinha buracos RE: passar grade/arado deve ainda recuperar histórico; mudança de tempo sozinha não produz novos sulcos sem novo yield.
5. Save/reload, forma física, contato do funcionário, performance 5–10min; comparar `Footprint`, `TerrainDeformation runtime`, `TerrainPlasticity sample`, `TerrainRecovery`, `TerrainPerf` no mesmo hardware/save se possível.
6. Para A/B, opção `TerrainPlasticYield=false` no ZIP/Config e restabelecer o save **de backup** antes de comparar. Não mudar módulos de Mud/SoilCompaction simultaneamente.

**Próxima decisão:** após um teste em jogo, ajustar **somente** a posição da transição/limiar se o resultado for muito agressivo ou permissivo. Não legitimar fórmula só porque o CI está verde. A PR é candidata para runtime, não promoção imediata a main.
