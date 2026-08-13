import networkx as nx
import statistics as stats

# Local package imports
from .model import VariantMetrics


def compute_node_depths(graph: nx.DiGraph) -> dict:
    """Calcuate the depths of the nodes of a directed graph

    Args:
        graph (nx.DiGraph): A directed graph

    Returns:
        dict: Dictionary of node, depth key, value pairs
    """
    depths = {}
    graph_roots = [node for node in graph.nodes if graph.in_degree(node) == 0]
    for root in graph_roots:
        # use library method to find shortest path from root (i.e. depth)
        for node, depth in nx.single_source_shortest_path_length(graph, root).items():
            # if there are multiple roots, select the maximum call depth
            depths[node] = max(depths.get(node, 0), depth)
    return depths


def compute_depth_mean_std(
    sample_flop_ids: list[int], node_depths: dict
) -> tuple[float, float]:
    """Compute the mean and standard deviation of node depths of a graph

    Args:
        sample_flop_ids (list[int]): List of flop ids to calculate the mean and standard deviation of
        node_depths (dict): Dictionary of depths of the nodes

    Returns:
        tuple[float, float]: Mean, standard deviation
    """
    if len(sample_flop_ids) == 0:
        return 0.0, 0.0
    
    if len(sample_flop_ids) == 1:
        return sample_flop_ids[0], 0.0

    selected_flop_depths = [node_depths.get(flop_id) for flop_id in sample_flop_ids]
    depth_mean = stats.mean(selected_flop_depths)
    depth_std = stats.stdev(selected_flop_depths) if len(node_depths) > 1 else 0.0
    return depth_mean, depth_std


def compute_func_reduction_density(
    call_graph: nx.DiGraph, eligible_flops: list[int], selected_flops: list[int]
) -> tuple[float, float]:
    """Calculates the mean and standard deviation of the ratio of elgible flops that are reduced in the function where there is at least one reduction

    Args:
        call_graph (nx.DiGraph): call graph
        eligible_flops (list[int]): list of flop ids for the flops eligible for reducing
        selected_flops (list[int]): list of flop ids for the flops selected to be reduced

    Returns:
        tuple[float, float]: Mean, standard deviation of elgible flops that are reduced in the function where there is at least one reduction
    """
    ratio_reduced_in_funcs = []
    # loop through functions, work out ratio of the flops to be reduced in each function to eligible
    for func in call_graph.nodes:
        func_flops = call_graph.nodes[func]["flops"]
        eligible_flops_in_func = [
            flop for flop in func_flops if flop in eligible_flops
        ]
        if not eligible_flops_in_func:
            continue
        reduced_flops_in_func = [
            flop_id for flop_id in eligible_flops_in_func if flop_id in selected_flops
        ]
        ratio_reduced = len(reduced_flops_in_func) / len(eligible_flops_in_func)
        ratio_reduced_in_funcs.append(
            len(reduced_flops_in_func) / len(eligible_flops_in_func)
        )
    if not ratio_reduced_in_funcs:
        return 0, 0
    ratio_reduced_mean = stats.mean(ratio_reduced_in_funcs)
    ratio_reduced_std = stats.stdev(ratio_reduced_in_funcs)
    return ratio_reduced_mean, ratio_reduced_std


def compute_use_chain_selection_modularity(
    use_chain_graph: nx.DiGraph, selected_nodes: list[int]
) -> float:
    """Calculates the modularity of the partition of the use chain graph formed by the selection of flops to be reduced

    Args:
        use_chain_graph (nx.DiGraph): the full use chain graph
        selected_nodes (list[int]): list of flop ids for the flops selected to be reduced

    Returns:
        float: Modularity of the partition of the use chain graph formed by the selection of flops to be reduced
    """
    selected_set = set(selected_nodes)
    unselected_set = set(use_chain_graph.nodes()) - selected_set

    print(
    "nodes:", use_chain_graph.number_of_nodes(),
    "edges:", use_chain_graph.number_of_edges(),
    "selected:", len(selected_set),
    "unselected:", len(unselected_set),
    )
    modularity = nx.community.modularity(
        use_chain_graph, [selected_set, unselected_set]
    )
    return modularity


def compute_variant_metrics(
    experiment_id: str,
    variant_id: int,
    rate: float,
    node_depths: dict,
    eligible_flops: list[int],
    selected_flops: list[int],
    use_chain_graph: nx.DiGraph,
    call_graph: nx.DiGraph,
) -> VariantMetrics:
    """Calculates the evaluation metrics for a single variant

    Args:
        experiment_id (str): unique id of the experiment execution
        variant_id (int): unique id of the variant
        rate (float): the reduction rate of eligible floating point operations
        node_depths (dict): a dictionary of all elidible floating point operation def chain depths
        eligible_flops (list[int]): the list of eligible floating point operations
        selected_flops (list[int]): the list of selected floating point operations to be reduced
        use_chain_graph (nx.DiGraph): the use chain graph of eligible floating point operations
        call_graph (nx.DiGraph): the call graph of functions containing eligible floating point operations

    Returns:
        VariantMetrics: the evaluation metrics for the variant
    """

    func_reduction_density_mean, func_reduction_density_std = (
        compute_func_reduction_density(call_graph, eligible_flops, selected_flops)
    )
    use_chain_depth_mean, use_chain_depth_std = compute_depth_mean_std(
        selected_flops, node_depths
    )
    use_chain_modularity = compute_use_chain_selection_modularity(
        use_chain_graph, selected_flops
    )

    return VariantMetrics(
            experiment_id=experiment_id,
            variant_id=variant_id,
            rate=rate,
            flops_reduced=len(selected_flops),
            func_reduction_density_mean=func_reduction_density_mean,
            func_reduction_density_std=func_reduction_density_std,
            uc_depth_mean=use_chain_depth_mean,
            uc_depth_std=use_chain_depth_std,
            uc_modularity=use_chain_modularity,
    )