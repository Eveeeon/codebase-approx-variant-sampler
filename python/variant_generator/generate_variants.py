import datetime
import logging
import json
import uuid
import random
import networkx as nx
import statistics as stats
import argparse
import tomllib
from pathlib import Path

# Local package imports
from .model import ExperimentConfig, VariantMetrics
from .build_graph import (
    build_call_graph,
    build_use_chain_graph,
)
from .compute import (
    compute_node_depths,
    compute_variant_metrics,
)
from .selection import (
    select_flops_random,
    get_eligible_flops,
)
from .io import (
    import_config,
    import_graph_raw,
    export_plan,
    export_metrics,
)


def get_logger(experiment_id: str) -> logging.LoggerAdapter:
    logger = logging.getLogger("experiment")

    return logging.LoggerAdapter(logger, {"experiment_id": experiment_id})


def generate(raw_data: dict, config: ExperimentConfig):
    """Generates a set of variants for a given experiment configuration, creating:
    The experiment directory
    A directory of plans, each to executed sequentially during the experiment
    A single metrics file to be consumed after the experiment for evaluation

    Args:
        raw_data (dict): the raw imported graph data
        config (ExperimentConfig): the imported ExperimentConfig
    """
    logger = get_logger(config.experiment_id)
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    experiment_id = config.experiment_id
    # generate graph structure from the raw data
    call_graph = build_call_graph(raw_data)
    use_chain_graph = build_use_chain_graph(raw_data)
    eligible_flops = get_eligible_flops(use_chain_graph, config.from_type)

    print(f"from_type = {config.from_type}")
    logger.info(f"Total graph nodes = {use_chain_graph.number_of_nodes()}")
    logger.info(f"Total graph edges = {use_chain_graph.number_of_edges()}")
    logger.info(f"Eligible FLOPs = {len(eligible_flops)}")

    if not eligible_flops:
        logger.warning("No eligible floating point operations found, terminating")
        return
    logger.info(
        f"Found {len(eligible_flops)} eligible {config.from_type} floating point operations"
    )

    # get the depths and metrics for all eligible floating point operations
    node_depths = compute_node_depths(use_chain_graph)

    # calculate the metrics of all eligble depths for a baseline
    baseline_metrics = compute_variant_metrics(
        experiment_id, 0, 1, node_depths, eligible_flops, eligible_flops, use_chain_graph, call_graph
    )

    # creating experiment out directory
    out_path = Path(config.out_dir)
    experiment_path = out_path / experiment_id
    experiment_path.mkdir(parents=True, exist_ok=True)
    experiment_plans = experiment_path / "plans"
    experiment_plans.mkdir(parents=True, exist_ok=True)

    # build all metrics into single list to export as one
    metrics = []
    metrics.append(baseline_metrics)
    for rate in config.reduction_rates:
        num_reduced = int(len(eligible_flops) * rate)
        logger.info(
            f"Selecting {num_reduced} floating point operations for {config.num_variants_per_rate} variants"
        )
        for i in range(config.num_variants_per_rate):
            # give each variant a unique id, used for identification and to seed the random selection
            variant_id = uuid.uuid1().int
            selected_flops = select_flops_random(eligible_flops, rate, variant_id)
            export_plan(
                selected_flops,
                config.from_type,
                config.to_type,
                experiment_plans / f"{variant_id}.json",
            )
            variant_metrics = compute_variant_metrics(
                experiment_id,
                variant_id,
                rate,
                node_depths,
                eligible_flops,
                selected_flops,
                use_chain_graph,
                call_graph,
            )
            metrics.append(variant_metrics)
    metrics_path = experiment_path / f"{experiment_id}_metrics.csv"
    export_metrics(metrics, metrics_path)


def main():
    log_path = (
        "/home/eve/Projects/codebase-approx-variant-sampler/logs/generate_variants.log"
    )
    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s %(asctime)s %(name)s %(message)s",
        handlers=[
            logging.FileHandler(log_path),
            logging.StreamHandler(),
        ],
    )
    #    logger = get_logger(config.experiment_id)
    logging.getLogger("experiment").info("Starting generator")
    parser = argparse.ArgumentParser()
    parser.add_argument("root_path", help="Path of the root directory", type=Path)
    parser.add_argument("config", help="Path of the config file", type=Path)
    args = parser.parse_args()
    config = import_config(args.root_path, args.config)
    raw_data = import_graph_raw(config.raw_graph_path)
    generate(raw_data, config)


if __name__ == "__main__":
    main()
