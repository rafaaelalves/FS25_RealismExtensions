# Visual Mud Tracks — complemento público de persistência/reparação (2026-10-23)

**Status:** **PESQUISA DE NOTAS PÚBLICAS, NÃO AUDITORIA DO ZIP NOVO NEM COMPATIBILIDADE APROVADA**. Leia em conjunto com [auditoria estática anterior](README.md) do ZIP que declara `1.4.0.27`, SHA-256 `4796d1f529fe6e0b7e324e91822d09858252f7f1e946a9a5c45f91168516470d`.

## O que foi observado, com identificação correta da fonte

- A [página KingMods do autor Sherman200](https://www.kingmods.net/en/fs25/mods/79740/visual-mud-tracks) e a [descrição V1.4.0.5](https://fs25.net/visual-mud-tracks-v1-0-2-5/) anunciam **altura original imutável antes do sulco**, profundidade de sulcos ativos separada, três sidecars: `visualMudTracksTerrainBackup.xml`, `visualMudTracksActiveRuts.xml`, `visualMudTracksState.xml`, não aprofundar novamente um sulco no load e adiar recuperação sob roda carregada.
- A descrição pública afirma que operações de preparo reais restauram sulcos apenas no work area (inclusive bordas), que a altura física é confirmada antes da retirada da entrada ativa, e que falha temporária não extingue a fila. Afirma também que mudanças externas não devem abaixar terreno que está mais alto do que a origem antiga. **Não houve execução do ZIP público, confirmação de gameplay ou revisão linha-a-linha deste binário**.
- Nota pública 1.4.0.5 destaca interpolação entre posições de rodas, spacing reduzido 0,75→0,45m e consciência da resolução do heightmap, 8 células de restore por turno, sync por chunk e desempenho. Isso valida a *preocupação de arquitetura*, não valores de calibração para RE.
- **Aviso explícito do próprio VMT:** grooves persistidos pela versão antiga podem continuar no heightmap após desinstalação/update; recuperação pode requerer manual landscaping. O RE tem o mesmo risco de save legado e não pode dizer que remover ZIP desfaz terreno.
- O ZIP 1.4.0.27 previamente auditado no RE parece ter arquitetura de múltiplas sobrescritas de métodos, mistura tração/pressão/solo e `setTerrainHeightAtWorldPos`. Não presumir que versões públicas 1.4.0.5/1.4.0.6 usem idêntica arquitetura apenas porque têm nome parecido. **Não ordene versões lexicograficamente** (1.4.0.27 vs 1.4.0.5) sem fonte exata.

## Compatibilidade/ownership

O VMT inclui seus próprios sistemas de sink, pressão, compaction, solo, pneus, clima e rut writer. Na stack RC: MR é drivetrain/tração base, Mud é sink/wetness, Reifen é desgaste, SoilCompaction é agronomia, RE é geometria persistente. **Não ativar VMT simultaneamente com o RE TerrainDeformation**, nem substituir Mud/Soil sem nova auditoria do ZIP exato e avaliação de duplicação. No máximo, testá-lo isoladamente em save clonado como **controle externo funcional**, não como confirmação de migração de modlist.

Sem licença que autorize cópia no ZIP anterior. **Usar invariantes, não copiar código.**

## Invariantes que merecem absorção clean-room no RE

1. Conservar baseline físico confiável anterior à primeira edição RE **por célula de geometria do motor**, não apenas um `SpatialHistory` 0,2m; não sobrescrever em passagens subsequentes.
2. Distinção explícita de `requestedDepth` (modelo), `acceptedQueued` (fila), `submitted`, `callbackSuccessful` (engine) e `observedGeometryDelta` (realização) por unidade espacial. Nunca declarar sulco fisicamente criado nem restaurado no estado `acceptedQueued`.
3. Monotonicidade apenas na criação RE-owned e nunca apagar um terreno deliberadamente elevado/escavado por outro sistema.
4. Restauração somente no footprint GIANTS processado e após contato carregado desocupar área, com debt history/visual marks reconciliados no **commit físico**.
5. Save sidecar versionado, rollback idempotente, no reapply de sulco que GIANTS já persistiu; perf por índice espacial e bounded queue.
6. Calibração de atuador baseada no **heightmap unit real** e na largura de footprint, não em raios/fatores copiados da internet.

## Resultado para tomada de decisão

VMT é **precedente útil de transação de geometria**, NÃO dependência recomendada no momento. A causa mais prioritária do RE é verificável em nosso código: `TerrainDeformationEngine.lua` faz `historyStore:commit` imediatamente após `writer:enqueue`, enquanto o native brush é aplicado posteriormente. Ver [reset/review](../../research/2026-10-23-terrain-recovery-release-reset.md). Resolver esse desacoplamento no RE é mais coerente com a stack do que substituir cegamente por VMT.

## Pendência para auditoria exata posterior

Se a comparação empírica com o VMT se tornar necessária, obter **ZIP oficial exato**, validar SHA/hash, ler `modDesc`, código de normalização de grade e `setTerrainHeightAtWorldPos`, writer LowerOnly, hooks de tillage, sidecars, loaded-contact, rede e seus cruzamentos com Mud/MR/Reifen/Soil. Sem esse ZIP, este documento permanece pesquisa de anúncio e não auditoria de fonte.
