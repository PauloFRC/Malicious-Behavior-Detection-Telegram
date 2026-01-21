import networkx as nx
import pandas as pd

def rank_bot_suspicion(G, weight_col='weight'):    
    pagerank = nx.pagerank(G, weight=weight_col)
    clustering = nx.clustering(G, weight=weight_col)
    strength = dict(G.degree(weight=weight_col))
    
    bot_data = []
    
    # Get max values for normalization
    max_pr = max(pagerank.values()) if pagerank else 1
    max_cl = max(clustering.values()) if clustering else 1
    max_str = max(strength.values()) if strength else 1
    
    for node in G.nodes():
        pr_val = pagerank.get(node, 0)
        cl_val = clustering.get(node, 0)
        str_val = strength.get(node, 0)
        
        norm_pr = pr_val / max_pr
        norm_cl = cl_val / max_cl
        norm_str = str_val / max_str
        
        # Heuristic: 40% Topology (PageRank), 40% Cohesion (Clustering), 20% Volume (Strength)
        composite_score = (0.4 * norm_pr) + (0.4 * norm_cl) + (0.2 * norm_str)
        
        bot_data.append({
            'user_id': node,
            'bot_suspicion_score': round(composite_score, 4),
            'centrality_rank': round(norm_pr, 4),
            'clique_score': round(norm_cl, 4),
            'volume_score': round(norm_str, 4),
            'labels': G.nodes[node].get('labels', [])
        })
    
    df = pd.DataFrame(bot_data)
    return df.sort_values(by='bot_suspicion_score', ascending=False)
