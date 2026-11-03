# Protocolo de teste único — altura MAIN absoluta e persistência (RE experimental)

**02/11/2026, versão experimental PR #64.** Esta página prepara uma validação curta, **não autoriza que ela seja feita no save principal**. Não é um roteiro de arar/semear/colher; nenhum teste de jogador é necessário agora. Todas as escrituras permanentes automáticas do RE continuam desligadas por `TerrainPermanentActuator="SHADOW"`.

## Por que existia uma lacuna?

O comando antigo `reTerrainTrial absolute` observava a resposta instantânea do setter GIANTS em 3x3 vértices e instruía **sair sem salvar**. Isso era correto para segurança inicial, mas matematicamente incapaz de demonstrar se a alteração persistia entre saves. A nova trilha adiciona uma confirmação SEPARADA, um testemunho read-only dos nove vértices no XML do save descartável e uma verificação read-only depois de recarregar.

**Não é captura da malha nativa fina 0,125m, não é teste de colisão e não é restauração agronômica.** O método observado no ensaio de 29/10 é `setTerrainHeightAtWorldPos` na MAIN ~1m, com quantização medida no mapa, mas sem justificativa para usar como escritor automático de sulcos de pneus.

## Implementação

1. `scripts/terrain/TerrainAbsolutePersistenceWitness.lua`: captura **somente** uma movimentação de vértice central com 8 vizinhos imóveis, leitura de todas as 9 alturas antes/depois, identidade do mapa, unidade da grade, solicitado e resposta. Não cria `GeometryJournal` owned, nem infere editor da malha fina. Rejeita colateral, dados ausentes, duplicados e unidade incoerente.
2. `TerrainAbsoluteSetterCalibration.run` tenta obter o testemunho após a única escrita *já opt-in*. **Não** salva o testemunho automaticamente.
3. `reTerrainTrial absolutePersist COPY`, explícito e somente após um resultado com testemunho válido, ativa uma gravação única durante o evento de save normal, sujeito a `isSinglePlayer`, `missionInfo.isValid` e `SHADOW`. O termo `COPY` é uma **declaração humana**, não prova verificável em Lua de que a pasta foi de fato clonada. O operador continua responsável por nunca executar isso no save real.
4. `RealismExtensionsCore.saveToXMLFile` só chama `saveWitness` se a armação extra foi realizada; por padrão, não escreve o XML. Ao salvar valida novamente as nove alturas; qualquer alteração entre setter e save faz a operação falhar fechada. Arquivo separado `realismExtensionsAbsolutePersistenceWitness.xml`; sem modificar a geometria ao salvar.
5. `reTerrainTrial absoluteVerify` carrega o XML, confere mapa, unidade, os nove valores lidos de `getTerrainHeightAtWorldPos`, ausência de alterações externas e apresenta `MAIN_HEIGHT_MATCHES_SAVED_WITNESS` ou causa de recusa. *O código não tem como provar que houve um restart; quem testa deve realmente recarregar a cópia.* E mesmo depois isso **não prova** atualização do collider ou persistência do 0,125m.
6. Testes `terrain_absolute_persistence_witness_harness.lua` e `terrain_absolute_setter_calibration_harness.lua`: criação, negativa por default, armamento explícito, escritas XML em memória, leitura, mudança do vértice central, vizinho alterado, unidade/mapa errados, corrupção de XML e falha native setter.

## Quando chegar o momento: uma única sessão curta, em save COPIADO

**Antes:** copiar o save da fazenda para outro slot, identificar slot e cópia, usar a build exata da PR #64; testes ainda são experimentais. Não rodar RE writer e outro mod que reescreva a mesma região. Para esta campanha é importante que os módulos de observação `reTerrainTrial probe` estejam disponíveis e intactos. A área de teste deve estar livre de veículos/rodas e de edições externas.

**Ensaio A (efeito instantâneo, sem persistência):**

```text
reTerrainTrial probe
reGeoMark
reGeoSnap beforeAbsolute
reTerrainTrial absoluteCheck
reTerrainTrial absolute
```

Verificar no log `WITNESS status=READY_NOT_SAVED` e `centerDeltaM`, oito vizinhos imóveis, ou recusa explicada. O comando `absolute` já foi isolado por `Cal.used`, então **não repeti-lo**. Para manter apenas o teste instantâneo, **sair sem salvar**, como no procedimento anterior.

**Ensaio B (novo, opcional, explicitamente destrutivo para a cópia):** só após o mesmo evento `absolute` produzir witness READY_NOT_SAVED, escolher:

```text
reTerrainTrial absolutePersist COPY
```

Se retornar ARMED, salvar **a cópia** normalmente, confirmar no log `WITNESS SAVED`, fechar completamente a sessão, reabrir o save **copiado**, manter a mesma região intacta e usar:

```text
reTerrainTrial absoluteVerify
```

Um match dos nove valores **após um reload real** sustenta persistência da altura MAIN observada; um mismatch indica diferença mas não sua causa única. Em seguida, ainda será necessária uma verificação separada de colisão e recuperabilidade — **não** repetir um ciclo agrícola amplo para provar uma única edição de heightmap.

**Parar imediatamente** se houver alteração física exagerada, colateral, fila não vazia, autores rivais, erro do motor, mapa trocado, marcador de MP, recusa do protocolo ou travamento. A quarentena continua na sessão; o teste nunca habilita novamente a geração permanente.

## Resultado da arquitetura após este PR

- Parte verificável agora por CI/mocks: correção da trajetória, ownership fail-closed, geometria de contato MAIN, proteção da escrita manual de roda nativa, witness e procedimentos de A/B.
- Parte somente verificável no FS25 real: `setTerrainHeightAtWorldPos` altera colisão? Salva mesmo o MAIN neste mapa? Tem efeito na geometria nativa fina? Recuperação com ferramentas comuns não exagera nem invalida edições de terceiros?
- A API de leitura da malha fina 0,125m e seu restauro direto **continua sem evidência pública suficiente**: artigo oficial GIANTS confirma a existência de resolução fina, mas não um leitor/escritor de células exposto em Lua. A alternativa MAIN absoluta só poderá ser aplicada automaticamente quando houver prova geométrica, de colisão, persistência e restituição por operação real.

Referências GIANTS: [Ground Deformation interview](https://www.farming-simulator.com/newsArticle.php?country=us&lang=en&news_id=569), [Engine Terrain v1.20](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=812&version=engine).

**Estado:** PR #64 draft, `main` RE/RC intocadas; esse é um protocolo de evidência, não uma liberação para gameplay.
