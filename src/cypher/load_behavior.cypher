// Conecta usuários com mensagens enviadas em comum DENTRO DE 15 SEGUNDOS
MATCH (u1:User)-[:SENT]->(m1:Mensagem)-[:HAS_TEXT]->(t:Texto)<-[:HAS_TEXT]-(m2:Mensagem)<-[:SENT]-(u2:User)

WHERE u1.id < u2.id AND abs(duration.between(m1.date_message, m2.date_message).seconds) <= 15

WITH u1, u2, count(*) AS shared_count_10s

MERGE (u1)-[r:RAPID_SHARE]-(u2)
SET r.weight = shared_count_10s;

// Conecta usuários que compartilham mensagens virais em tempo curto
MATCH (u1:User)-[:SENT]->(m1:Mensagem)-[:HAS_TEXT]->(t:Texto)<-[:HAS_TEXT]-(m2:Mensagem)<-[:SENT]-(u2:User)
WHERE u1.id < u2.id
  AND m1.viral = true
  AND m2.viral = true
  AND abs(duration.between(m1.date_message, m2.date_message).seconds) <= 15

WITH u1, u2, 
     count(*) as viral_amplifications,
     avg(abs(duration.between(m1.date_message, m2.date_message).seconds)) as avg_viral_delay

MERGE (u1)-[r:VIRAL_AMPLIFIER]-(u2)
SET r.weight = viral_amplifications,
    r.avg_delay = avg_viral_delay;

// Conecta usuários que compartilham mensagens com desinformação em tempo curto
MATCH (u1:User)-[:SENT]->(m1:Mensagem)-[:HAS_TEXT]->(t:Texto)<-[:HAS_TEXT]-(m2:Mensagem)<-[:SENT]-(u2:User)
WHERE u1.id < u2.id
  AND m1.score_misinformation > 0.8
  AND m2.score_misinformation > 0.8
  AND abs(duration.between(m1.date_message, m2.date_message).seconds) <= 15

WITH u1, u2, 
     count(*) as misinfo_amplifications,
     avg(abs(duration.between(m1.date_message, m2.date_message).seconds)) as avg_viral_delay

MERGE (u1)-[r:MISINFORMATION_AMPLIFIER]-(u2)
SET r.weight = misinfo_amplifications,
    r.avg_delay = avg_viral_delay;

// Conecta usuários que compartilham o mesmo texto na mesma hora do dia (em dias diferentes ou não)
MATCH (t:Texto)<-[:HAS_TEXT]-(m1:Mensagem)<-[:SENT]-(u1:User)
MATCH (t)<-[:HAS_TEXT]-(m2:Mensagem)<-[:SENT]-(u2:User)

WHERE u1.id < u2.id
  AND m1.date_message.hour = m2.date_message.hour

WITH u1, u2,
     count(*) AS hourly_shared_count

WHERE hourly_shared_count >= 3

MERGE (u1)-[r:HOURLY_SHARED]-(u2)
SET r.weight = hourly_shared_count;

// Cria score de sincronicidade entre usuários que compartilharam mensagens muito rapidamente
MATCH (u:User)-[r:RAPID_SHARE]-(target:User)
WITH u, sum(r.weight) as rapid_weight_sum, count(target) as rapid_partners
SET u.synchronicity_score = rapid_weight_sum * log(rapid_partners + 1);

// Cria score de flood
MATCH (u:User)-[:SENT]->(m:Mensagem)
WITH u, count(m) as total_msgs, count(distinct m.id_group_anonymous) as distinct_groups

MATCH (u)-[:SENT]->(m)-[:HAS_TEXT]->(t:Texto)
WITH u, total_msgs, distinct_groups, count(distinct t) as unique_texts

WITH u, total_msgs, 
     (toFloat(total_msgs) / CASE WHEN unique_texts = 0 THEN 1 ELSE toFloat(unique_texts) END) as repetition_ratio
WHERE total_msgs > 5

SET u.flooding_score = log10(total_msgs) * repetition_ratio;

// Cria índices
CREATE INDEX user_flood_score IF NOT EXISTS FOR (u:User) ON (u.flooding_score);
CREATE INDEX user_sync_score IF NOT EXISTS FOR (u:User) ON (u.synchronicity_score);

// Cria arestas de semelhança de flooding
MATCH (u:User)
WHERE u.flooding_score > 1.0 
WITH collect(u) as suspiciousUsers

UNWIND suspiciousUsers as u1
UNWIND suspiciousUsers as u2
WITH u1, u2
WHERE u1.id < u2.id
  AND abs(u1.flooding_score - u2.flooding_score) / u1.flooding_score < 0.05

MERGE (u1)-[r:FLOOD_SIMILAR]-(u2)
SET r.weight = 1.0 - (abs(u1.flooding_score - u2.flooding_score) / u1.flooding_score);

// Cria arestas de semelhança de sincronicidade
MATCH (u:User)
WHERE u.synchronicity_score > 0
WITH collect(u) as suspiciousSync

UNWIND suspiciousSync as u1
UNWIND suspiciousSync as u2
WITH u1, u2
WHERE u1.id < u2.id
  AND abs(u1.synchronicity_score - u2.synchronicity_score) / u1.synchronicity_score < 0.05

MERGE (u1)-[r:SYNC_SIMILAR]-(u2)
SET r.weight = 1.0 - (abs(u1.synchronicity_score - u2.synchronicity_score) / u1.synchronicity_score);

// Cria scores de compartilhamentos
MATCH (u:User)
// Score de compartilhamentos geral
OPTIONAL MATCH (u)-[r1:SHARES]-()
WITH u, sum(r1.weight) as raw_shares
// Score de compartilhamentos virais
OPTIONAL MATCH (u)-[r2:VIRAL_SHARES]-()
WITH u, raw_shares, sum(r2.weight) as raw_viral
// Score de compartilhamento de desinformação
OPTIONAL MATCH (u)-[r3:SHARES_MISINFORMATION]-()
WITH u, raw_shares, raw_viral, sum(r3.weight) as raw_misinfo
// Cria scores normalizados com log
SET u.shares_score = log10(1.0 + coalesce(raw_shares, 0))
SET u.viral_score = log10(1.0 + coalesce(raw_viral, 0))
SET u.misinfo_score = log10(1.0 + coalesce(raw_misinfo, 0));

// Cria aresta similaridade de compartilhamentos gerais
MATCH (u:User)
WHERE u.shares_score > 0
WITH collect(u) as activeSharers

UNWIND activeSharers as u1
UNWIND activeSharers as u2
WITH u1, u2
WHERE u1.id < u2.id
  AND abs(u1.shares_score - u2.shares_score) / u1.shares_score < 0.05

MERGE (u1)-[r:SHARES_SIMILAR]-(u2)
SET r.weight = 1.0 - (abs(u1.shares_score - u2.shares_score) / u1.shares_score);

// Cria aresta similaridade de compartilhamentos virais
MATCH (u:User)
WHERE u.viral_score > 0
WITH collect(u) as viralSharers

UNWIND viralSharers as u1
UNWIND viralSharers as u2
WITH u1, u2
WHERE u1.id < u2.id
  AND abs(u1.viral_score - u2.viral_score) / u1.viral_score < 0.05

MERGE (u1)-[r:VIRAL_SIMILAR]-(u2)
SET r.weight = 1.0 - (abs(u1.viral_score - u2.viral_score) / u1.viral_score);

// Cria aresta similaridade de compartilhamentos com desinformação
MATCH (u:User)
WHERE u.misinfo_score > 0
WITH collect(u) as misinfoSpreaders

UNWIND misinfoSpreaders as u1
UNWIND misinfoSpreaders as u2
WITH u1, u2
WHERE u1.id < u2.id
  AND abs(u1.misinfo_score - u2.misinfo_score) / u1.misinfo_score < 0.05

MERGE (u1)-[r:MISINFO_SIMILAR]-(u2)
SET r.weight = 1.0 - (abs(u1.misinfo_score - u2.misinfo_score) / u1.misinfo_score);