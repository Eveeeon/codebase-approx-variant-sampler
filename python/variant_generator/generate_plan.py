import datetime
import logging
import json
import uuid
import networkx as nx
import statistics as stats
from enum import IntEnum
from pathlib import Path


@dataclass
class ExperimentConfig:
    out_dir: str
    experiment_id: str
    from_type: str
    to_type: str
    reduction_rates: list[float]
    num_variants_per_rate: int
    base_seed: int


@dataclass
class VariantMetrics:
    variant_id: int
    rate: float
    flops_reduced: int
    func_reduction_density: float
    uc_depth_mean: float
    uc_depth_std: float
    uc_modulatiry: float


# Import --------------------------------------------------------------


def import_graph_raw(path: str) -> dict:
    """_summary_

    Args:
        path (str): The path of the JSON file with the exported graph data

    Returns:
        dict: The raw parsed JSON graph data
    """
    with open(path) as file:
        return json.load(file)


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


# Export --------------------------------------------------------------


def export_plan(selected_flops: list[int], from_type: str, to_type: str, path: Path):
    changes = [
        {"flopId": flop_id, "fromTypeName": from_type, "toTypeName": to_type}
        for flop_id in select_flops
    ]
    with open(path, "w") as output_file:
        json.dumps({"changes": changes}, output_file)


# Helpers --------------------------------------------------------------


def get_experiment_logger(experiment_id: str) -> logging.LoggerAdapter:
    logger = logging.getLogger("experiment")

    return logging.LoggerAdapter(logger, {"experiment_id": experiment_id})


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


def check_func_contains_selected_flop(
    func_node: nx.graph.node, selected_flops: list[int]
) -> bool:
    """Helper to check if a function node contains any flops that have been selected for reduction

    Args:
        func_node (nx.graph.node): the call graph node for a function
        selected_flops (list[int]): list of ids of the flops selected for reduction

    Returns:
        bool: if the function contains flops selected to be reduced
    """
    for func_flop in func_node.flops:
        if func_flop in selected_flops:
            return True
    return False


# Compute --------------------------------------------------------------


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
    sample_count = len(sample_flop_ids)
    if sample_count_count < 1:
        return (0, 0)
    selected_flop_depths = [node_depths.get(flop_id) for flop_id in sample_flop_ids]
    depth_mean = stats.mean(selected_flop_depths)
    depth_std = stats.stdev(selected_flop_depths)
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
            flop["flop_id"] for flop in func_flops if flop["flop_id"] in eligible_flops
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
    modularity = nx.community.modularity(
        use_chain_graph, [selected_set, unselected_set]
    )
    return modularity


def compute_variant_metrics(
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

    func_reduction_density = compute_func_reduction_density(
        call_graph, eligible_flops, selected_flops
    )
    use_chain_depth_mean, use_chain_depth_std = compute_depth_mean_std(
        selected_flops, call_graph_node_depths
    )
    use_chain_modularity = compute_use_chain_selection_modularity(
        use_chain_graph, selected_flops
    )

    return {
        "variant_id": variant_id,
        "rate": rate,
        "flops_reduced": len(selected_flops),
        "func_reduction_density": func_reduction_density,
        "uc_depth_mean": selected_use_chain_depth_mean,
        "uc_depth_std": selected_use_chain_depth_std,
        "uc_modularity": use_chain_modularity,
    }


# Selection --------------------------------------------------------------


def select_flops_random(eligible_flops: list[int], rate: float, seed: int) -> list[int]:
    """
    Selects the list of floating point operations to be reduced randomly at a given rate
    Returns the list of flop ids to be reduced
    """
    rng = random.Random(seed)
    num_eligible = len(eligible_flops)
    reduction_count = 0
    if num_eligible > 1:
        reduction_count = int(num_eligible * rate)
    return rng.sample(eligible_flops, reduction_count)


# Experiment Generation --------------------------------------------------------------


def generate_experiment(raw_data: dict, config: ExperimentConfig):
    logger = get_experiment_logger(config.experiment_id)
    # generate graph structure from the raw data
    call_graph = build_call_graph(raw_data)
    use_chain_graph = build_use_chain_graph(raw_data)
    eligible_flops = get_eligible_flops(use_chain_graph, config.from_type)
    if not eligible_flops:
        experiment_logger.warning(
            "No eligible floating point operations found, terminating"
        )
        return
    logger.info(
        f"Found {len(eligible_flops)} eligible {config.from_type} floating point operations"
    )

    # get the depths and metrics for all eligible floating point operations
    node_depths = compute_node_depths(use_chain_graph)

    # calculate the metrics of all eligble depths for a baseline
    baseline_metrics = compute_variant_metrics(
        0, 1, node_depths, eligible_flops, eligible_flops, use_chain_graph, call_graph
    )

    # creating experiment out directory
    out_path = Path(config.out_dir)
    experiment_path = out_path / config.experiment_id
    experiment_path.mkdir(parents=True, exist_ok=True)
    experiment_plans = experiment_path / "plans"
    experiment_plans.mkdir(parents=True, exist_ok=True)

    metrics = {}
    for rate in config.reduction_rates:
        num_reduced = int(len(eligible_flops) * rate)
        logger.info(
            f"Selecting {num_reduced} floating point operations for {config.num_variants_per_rate} variants"
        )
        for i in range(config.num_variants_per_rate):
            # give each variant a unique id, used for identification and to seed the random selection
            variant_id = uuid.uuid1()
            selected_flops = select_flops_random(eligible_flops, rate, variant_id)
            export_plan(
                selected_flops,
                config.from_type,
                config.to_type,
                experiment_plans / variant_id,
            )
            variant_metrics = compute_variant_metrics(
                variant_id,
                rate,
                node_depths,
                eligible_flops,
                selected_flops,
                use_chain_graph,
                call_graph,
            )


def __main__():
    logging.basicConfig(
        level=loggin.INFO,
        format="%(levelname)s %(asctime)s [exp=%(experiment_id)s rate=%(reduction_rate)s %(message)s]",
    )
