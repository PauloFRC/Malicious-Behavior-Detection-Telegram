# Detecção de Comportamento de Bots em Dataset de Mensagens do Telegram

Processamento de grafos usando banco Neo4J e biblioteca NetworkX para detectar e mapear comportamentos de bots em mensagens no Telegram.

## Configurando Ambiente

Para Configurar ambiente conta, basta executar makefile:

`make`

O dataset utilizado pode ser encontrado em https://drive.google.com/file/d/1c_hLzk85pYw-huHSnFYZM_gn-dUsYRDm/view?usp=sharing

Para carregar banco de dados, é preciso colocar o dataset "fakeTelegram.BR_2022.csv" na pasta data/ e executar o notebook viz_and_cleaning.ipynb.
Então mover o arquivo "telegram_tratado.csv" para a pasta import/ do banco de dados no Neo4J e executar os cypher
"load_db_from_csv.cypher" e em seguida "load_behavior.cypher".

Por fim, garanta que src/util/load_graph tem as informações para se conectar à instância do Neo4j.
