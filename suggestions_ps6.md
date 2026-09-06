# Sugestoes, sessao de 2026-09-05

Arquivo de anotacao pessoal. Nao versionado de proposito.

## Correcao: o projeto tem testes

Eu tinha afirmado "zero testes" sem olhar a pasta. Errado. `tests/` tem tres
arquivos, e o `validate_silver_2.sql` e a coisa mais de engenharia de dados do
repositorio: um jogador fantasma com 144 gols em segundo lugar, investigado ate
achar gol invalido com `goal_getter_id = 0` e nome nulo sendo contado como
valido. Isso e qualidade de dado achada por desconfianca de um numero que nao
fechava.

O que falta nao e teste, e **assercao automatizada**. Os atuais sao queries
exploratorias: voce roda, le o resultado e julga com o olho. Nada devolve
passou/falhou, nada quebra um build. Consequencia pratica: se aquele bug do gol
nulo voltar amanha, ninguem avisa.

O proximo passo natural e transformar as perguntas que voce ja escreveu em
verificacoes que falham sozinhas. Exemplos que saem direto dos seus proprios
comentarios:

- nenhum gol pode ter `goal_getter_id = 0`
- nenhuma partida pode ter `team1_id = team2_id`
- todo `group_id` em `silver.matches` existe em `silver.groups`
- a contagem de partidas terminadas bate com o esperado para a temporada

Nao precisa de framework para comecar. Uma query que retorna zero linhas quando
esta tudo certo ja e uma assercao; o que falta e alguem verificando isso sem
voce.

## Python: o que esta "solto no nivel do modulo"

Nada disso tem a ver com orientacao a objetos. **OO nao e necessario aqui**, e
enfiar classes num script desse tamanho seria abstracao para uso unico.

Sao estas linhas, fora de qualquer funcao, em `ingestion/fetch_matches.py`:

```python
seasons = range(2006, 2027)
matchday = range(1, 35)
data_path = Path(__file__).parent.parent / "datasets"
scripts_path = Path(__file__).parent.parent / "scripts"
load_dotenv()
```

Tres incomodos, em ordem crescente de importancia:

1. **Inconsistencia de convencao.** `loop_and_write()` recebe as temporadas por
   parametro, mas `load_json()` pega `data_path` do modulo. Duas formas de
   passar informacao no mesmo arquivo.

2. **`load_dotenv()` roda no import.** Um simples `import fetch_matches` ja
   mexe no ambiente do processo sem voce ter chamado nada. Isso so incomoda de
   verdade no dia em que existir teste em Python importando o modulo.

3. **`range(2006, 2027)` vai vencer sozinho.** Em agosto de 2027 o backfill
   silenciosamente para de incluir a temporada nova, sem erro e sem aviso.
   Ninguem vai lembrar. Este e o unico dos tres que causa bug de verdade, e a
   solucao provavelmente e derivar o fim do range de `current_season()`, que ja
   existe e ja sabe a resposta.

Outras lacunas do script, menos urgentes: sem logging (usa `print`), sem
tratamento de erro nos lacos (uma falha na rodada 20 derruba o run inteiro e
perde as 19 anteriores), sem empacotamento.

## Escala grande gastando pouco

Nao da para ter escala **operacional** (ingerir terabytes 24/7) de graca. Da
para ter escala **analitica**, que e onde mora o aprendizado: particionamento,
formato colunar, custo de query, processamento incremental.

Tres caminhos de custo zero:

- **DuckDB no proprio notebook.** Le parquet do disco ou de URL sem carregar
  tudo na memoria. Dezenas de GB rodam confortavelmente numa maquina comum. E a
  forma mais barata de aprender a lidar com dado que nao cabe na RAM.
- **BigQuery, camada gratuita.** 1 TB de query por mes sem custo, e ja hospeda
  datasets publicos grandes. E a forma mais realista de encostar em escala de
  nuvem de verdade sem cartao sangrando. Confirmar os termos atuais antes.
- **Dumps publicos grandes**, baixaveis em pedacos: GH Archive (eventos do
  GitHub, JSON por hora, terabytes acumulados), NYC Taxi (parquet, bilhoes de
  corridas), GDELT (noticias, atualiza a cada 15 minutos), Wikipedia pageviews,
  Backblaze drive stats.

## E o ponto que talvez importe mais

Escala nao e o unico eixo que faz um projeto parecer senior. Sao igualmente
dificeis, todos de graca, e todos aparecem mais em entrevista que volume:

- **numero de fontes** e o trabalho de conciliar formatos que discordam
- **schema drift**: a fonte muda o contrato no meio do caminho
- **dado que chega atrasado**, e o que fazer com o que ja foi processado
- **orquestracao** de dependencias entre tarefas
- **contrato de dados** e validacao na fronteira

## Nivel que o projeto sinaliza

Junior solido com pontos de mid.

Acima do junior tipico: idempotencia de verdade (`MERGE` com marcador de
mudanca em vez de drop-and-rebuild eterno), portabilidade resolvida na raiz, e
principalmente o `docs/roadmap.md` registrando o que foi **rejeitado e por que**.
Quase ninguem documenta decisao descartada, e num processo seletivo isso vale
mais que o codigo.

Ainda abaixo: sem assercao automatizada, Python basico (sem logging, sem
tratamento de erro), uma fonte so, sem orquestracao.

O limitador honesto nao esta no repositorio: nivel se mede pelo que se constroi
e depura sozinho. Enquanto houver parte do arquivo que voce nao escreveria de
novo do zero, o projeto sinaliza mais do que voce entrega. E a lacuna mais
facil de fechar da lista, porque e pratica.

## Sobre projeto pessoal e senioridade

A maioria dos seniores nao mantem projeto pessoal longo, e nao e falha deles:
ja recebem problemas dificeis no trabalho, tem menos tempo, e o portfolio deles
e o historico. Ninguem pede repositorio para quem tem oito anos de experiencia.

O corolario importa mais que a observacao: **o valor de um projeto pessoal cai
conforme o curriculo cresce.** Ele vale muito agora e vai valer pouco daqui a
cinco anos. Fazer isso neste momento da carreira e timing certo.

Duas ressalvas: **duracao nao e merito** (quatro meses nao valem mais que duas
semanas; o que se avalia e qualidade de decisao), e **projeto de portfolio pesa
menos na entrevista do que se espera**. O que pesa e conseguir falar das
decisoes: por que `MERGE` e nao truncate, por que banco efemero em CI nao faz
sentido, por que dashboard nao precisa de banco servido.

## Proximos passos que mais movem o ponteiro

1. Terminar a Phase 6 (o workflow).
2. Gold layer, que e onde mora modelagem dimensional, escolha de grao, fato
   contra dimensao. E a parte mais de engenharia de dados que sobrou.
3. Transformar as queries de `tests/` em assercoes que falham sozinhas.
