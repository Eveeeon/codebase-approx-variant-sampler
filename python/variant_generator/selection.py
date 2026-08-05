import random
import networkx as nx

def get_eligible_flops(use_chain_graph: nx.DiGraph, from_type: str) -> list[int]:
    """Gets the list of flop ids of the specified type to reduce from

    Args:
        use_chain_graph (nx.DiGraph): The flop use chain graph
        from_type (str): The type name to be changed from

    Returns:
        list[int]: List of flop ids to that are of the from type
    """
    return [
        node
        for node in use_chain_graph.nodes
        if use_chain_graph.nodes[node]["fp_type"] == from_type
    ]


def select_flops_random(eligible_flops: list[int], rate: float, seed: int) -> list[int]:
    """Selects the list of floating point operations to be reduced randomly at a given rate
    Args:
        eligible_flops (list[int]): the list of FLOP ids that are eligible for precision reduction
        rate (float): the rate of precision reduction to be applied
        seed (int): a seed for random allocation of floating point precision reduction

    Returns:
        list[int]: the list of flop ids to be reduced
    """

    rng = random.Random(seed)
    num_eligible = len(eligible_flops)
    reduction_count = 0
    if num_eligible > 1:
        reduction_count = int(num_eligible * rate)
    return rng.sample(eligible_flops, reduction_count)