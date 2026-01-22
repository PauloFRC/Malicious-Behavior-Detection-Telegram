from neo4j import GraphDatabase
import pandas as pd
import networkx as nx
import community as community_louvain
from collections import Counter

# ---------- Conexão ----------
def get_driver():
    URI = "bolt://localhost:7687"
    AUTH = ("neo4j", "12345678")  # ajuste a senha
    return GraphDatabase.driver(URI, auth=AUTH)

# ---------- Extração ----------
def load_rapid_share_edges():
    driver = get_driver()
    query = """
    MATCH (u1:User)-[r:RAPID_SHARE]-(u2:User)
    WHERE u1.id < u2.id
    RETURN u1.id AS source, u2.id AS target, r.weight AS weight
    """
    with driver.session() as session:
        result = session.run(query)
        data = [dict(record) for record in result]
    driver.close()
    return pd.DataFrame(data)

# ---------- Main ----------
if __name__ == "__main__":

    df_edges = load_rapid_share_edges()

    print("Amostra das arestas:")
    print(df_edges.head())

    print("\nEstatísticas:")
    print("Arestas:", len(df_edges))
    print("Peso médio:", df_edges["weight"].mean())
    print("Peso máximo:", df_edges["weight"].max())

    # Cria o grafo
    G = nx.Graph()
    for _, row in df_edges.iterrows():
        G.add_edge(row["source"], row["target"], weight=row["weight"])

    print("\nGrafo criado:")
    print("Nós:", G.number_of_nodes())
    print("Arestas:", G.number_of_edges())

    # ---------- Louvain ----------
    print("\nExecutando Louvain...")
    partition = community_louvain.best_partition(G, weight="weight")

    num_communities = len(set(partition.values()))
    community_sizes = Counter(partition.values())

    print(f"Número de comunidades: {num_communities}")
    print("Tamanho das comunidades (top 10):")
    for cid, size in community_sizes.most_common(10):
        print(f"Comunidade {cid}: {size} nós")

    # ---------- Salva resultado ----------
    df_comm = pd.DataFrame({
        "user_id": list(partition.keys()),
        "community": list(partition.values())
    })

    df_comm.to_csv("communities_louvain_rapid_share.csv", index=False)
    print("\nArquivo salvo: communities_louvain_rapid_share.csv")
