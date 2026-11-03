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


## Adendo — 02/11, instrumentação de colisão da roda e proteção do witness

**Implementado e aprovado pelo CI:** `TerrainWheelCollisionProbe.lua` e `reTerrainTrial contact`. A GIANTS documenta `getWheelShapeContactPoint`, `getWheelShapeContactObject` e `getWheelShapePosition` no FS25 v1.20; isso consulta o estado do wheel shape e **não** uma célula da grade fina de deformação. A descrição de `getWheelShapeContactPoint` não declara claramente o referencial das coordenadas. O RE considera as interpretações mundial e local e aceita o cálculo `contactY - MAIN` somente quando a proximidade ao nó da roda discrimina uma delas. Caso contrário, `CONTACT_FRAME_UNVERIFIED` é resultado correto; não fabricar delta ou diagnóstico de clipping.

Para observar *sem escrita alguma*, em uma sessão com RE experimental, roda sob carga perto da área de interesse, marcar o ponto e executar:
```text
reGeoMark
reTerrainTrial contact
```
O observador procura até quatro contatos físicos na área marcada, só sob servidor e com wheel shapes ativos, reporta ausência de contato/objeto que não seja terreno e recusa geometria ambígua. É uma consulta opcional, **não** parte do comando destrutivo. Pode ser usada para comparar a situação sem nenhuma escrita do RE em `SHADOW`. A ocorrência antiga de clipping com o RE desligado pertence a outra sessão sem log correspondente: não atribuir sua causa a uma execução deste ensaio.

Para o **ensaio com setter** (apenas clone descartável): registrar a região marcada *sem rodas em cima* para permitir a calibração. Após eventual `absolute`, medição 3×3 e, somente se escolhido, `absolutePersist COPY` + salvar + recarregar + `absoluteVerify`, aproximar uma roda real da região e executar `reTerrainTrial contact`. Comparar apenas quando a geometria de contato, veículo, carga, local e condições forem suficientemente semelhantes. A aproximação da roda também pode introduzir deformação NATIVA; portanto **a simples diferença entre contato Y e MAIN não demonstra que a escrita absoluta alterou a malha fina ou a colisão**. O teste deve registrar a forma visual e a trafegabilidade separadamente.

**Proteções incrementais:** o witness serializado está no formato v2 e valida que só o vértice central baixou e que essa redução ficou no intervalo de 0,5 mm até 12 mm no experimento de 1,5 mm. Essas marcas são *gates conservadores de evidência*, não valores universais do mapa. Um setter que provocou um buraco maior pode continuar tendo modificado o clone; ele apenas não será registrado como sucesso. A confirmação `absolutePersist COPY` agora liga o witness ao objeto `missionInfo` e ao diretório da mesma sessão, e a primeira tentativa de save consome a autorização mesmo quando recusada. **Não há reenvio automático de gravação em saves posteriores.**

**Critério exato:** sucesso de `absoluteVerify` prova apenas que os NOVE valores de altura MAIN concordam com o witness salvo, *sob a condição de que o jogador realmente tenha recarregado a cópia*. Um contato físico válido é outra observação; o seu referencial é inferido, não certificado. Nenhuma dessas duas medidas isoladas libera um escritor permanente para rodas nem certifica a recuperação por implementos.
