import networkx as nx
from neo4j import GraphDatabase

def get_driver():
    URI = "bolt://localhost:7687"
    password = "12345678" # CHANGE
    AUTH = ("neo4j", password)
    return GraphDatabase.driver(URI, auth=AUTH)

def load_graph_by_edge(driver, edge_type, directed=False):
    G = nx.DiGraph() if directed else nx.Graph()

    query = f"""
        MATCH (n)-[r:{edge_type}]->(m)
        RETURN id(n) AS source_id, properties(n) AS source_props,
               id(m) AS target_id, properties(m) AS target_props,
               properties(r) AS edge_props
    """

    with driver.session() as session:
        result = session.run(query)
        
        for record in result:
            s_id = record["source_id"]
            t_id = record["target_id"]
            
            G.add_node(s_id, **record["source_props"])
            G.add_node(t_id, **record["target_props"])
            
            G.add_edge(s_id, t_id, **record["edge_props"])

    return G