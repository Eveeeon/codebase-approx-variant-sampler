import json
import networkx as nx
from pathlib import Path

def build_call_graph(raw_data: dict) -> nx.DiGraph:
    """Builds the call graph from the raw imported data
    The call graph represents the graph of function calls which contain floating point operations
    It is a

    Args:
        raw_data (dict): The raw parsed graph data from JSON

    Returns:
        nx.DiGraph: Populated call graph
    """
    graph = nx.DiGraph()

    # add all functions to the graph
    for func in raw_data["functions"]:
        graph.add_node(func["funcId"], name=func["name"], flops=func["flops"])

    # add call graph edges
    for func in raw_data["functions"]:
        for called_id in func["calls"]:
            graph.add_edge(func["funcId"], called_id)

    return graph


def build_use_chain_graph(raw_data: dict) -> nx.DiGraph:
    """Builds the use chain graph from the raw imported data
    The id of the nodes are the flop ids

    Args:
        raw_data (dict): The raw parsed graph data from JSON

    Returns:
        nx.DiGraph: Populated use chain graph
    """
    graph = nx.DiGraph()

    # form call graph connections
    for func in raw_data["functions"]:
        for flop in func["flops"]:
            graph.add_node(
                flop["flopId"],
                func_Id=func["funcId"],
                func_name=func["name"],
                fp_type=flop["fpType"],
            )

    # add edges
    for func in raw_data["functions"]:
        for flop in func["flops"]:
            for user_id in flop.get("users", []):
                graph.add_edge(flop["flopId"], user_id)

    return graph

