# FarmKit 1.0.0.3 — o que os sulcos físicos resolvem e o que NÃO resolvem

**Revisão pontual de fonte:** 2026-10-23. Fonte pública upstream [NXModdingFS/FS25_FarmKit](https://github.com/NXModdingFS/FS25_FarmKit) no commit `8ee55d9b8efe6f58ecc2984bd276c7a130d8f0bd`, release 1.0.0.3. Continuação das auditorias exatas [RC 01-physical-core](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/audits/farmkit/01-physical-core.md) e [12-second-pass](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/audits/farmkit/12-second-pass-2026-10-08.md).

## Evidência direta

1. `scripts/NXRealisticWheelPhysics.lua`, `nxApplySlipDeformation` (~919–1035): responde a slip longitudinal + movimento lateral + velocidade, umidade, congelamento, tipo de pneu/perfil do solo, estado de IA; cria brush nativo `TerrainDeformation.new`, `enableAdditiveDeformationMode`, `setAdditiveHeightChangeAmount(-depth)`, `addSoftCircleBrush`, encaminha a fila do engine ou `apply`.
2. `deformMaxDepth=0.12`, `deformTickDepth=0.0018`, `deformIntervalMs=500`, `deformSlipMin=0.55`, `deformRadiusMul=0.65`. **São coeficientes de gameplay do FarmKit, não dados experimentais físicos para copiar.**
3. `deformAccum[wp]` limita profundidade acumulada **por objeto de roda/episódio**, não por célula fixa do terreno. Incrementa antes do retorno do motor; `nxOnDeformDone(self,state,numDeforms,msg)` é função vazia. Não existe nesse caminho um commit que use depois a altura de terreno realizada ou preserve uma altura de referência recuperável por vértice.
4. `scripts/NXFieldPhysics.lua` possui preparo/estado do solo, e `NXRealisticWheelPhysics` possui o efeito `cultivator paint`; isso não comprova a reversão de um sulco estrutural de altura de mundo com história persistente, nem a devolução de massa. **No fonte revisado não foi demonstrado mecanismo completo equivalente ao nosso ciclo causal deformar → guardar baseline → restaurar após arado → confirmar vértices → persistir.**
5. O README do FarmKit restringe modificações/re-distribuição. Esta nota é estudo de algoritmos/interfaces, **nenhuma cópia de código em RE/RC**.

## Reconciliar decisão de ownership

- Primeira auditoria RC recomendava `KEEP/BRIDGE FarmKit ruts` porque não existia autor RE da geometria. A segunda revisão (08/10) substituiu por `SUPPRESS FarmKit` quando RE passou a gerar ruts, evitando dois autores de heightmap junto com MR/Mud/Reifen.
- **Correção de entendimento para 23/10:** `SUPPRESS FarmKit` continua apropriado para evitar writer concorrente, mas o RE não deve ser declarado feature **concluída** enquanto a recuperação do rut profundo estiver reprovada. A primeira auditoria apreciou geração de ruts, não um ciclo de reparo comprovado.
- O FarmKit constitui precedente válido para gerar sulcos visíveis; **não uma solução de recuperação a reativar**. Pode, no futuro, continuar a fornecer furrow anti-bounce, crop damage e UI independentes, observadas as separações por RC.
- A implementação atual está em [PR #64](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/64) e [issue #63](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/63): journal geométrico com confirmação por callback, referência física de primeira deformação e caminho opt-in de restituição localizada por vértice, sem assumir original num save antigo.

## Lição concreta

O FarmKit não eliminaria o problema verificado dos históricos de RE: também registra pedido de deformação antes da confirmação do deslocamento. O que **não** devemos repetir é chamar uma solicitação de profundidade de geometria realizada. O diferencial desejado do RE não é apenas “sulco com melhor fórmula”, mas **um ciclo de vida completo que garanta jogabilidade, persistência e recuperação**.
