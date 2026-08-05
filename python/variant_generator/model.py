from dataclasses import dataclass
from pathlib import Path

@dataclass
class ExperimentConfig:
    raw_graph_path: Path
    out_dir: str
    experiment_id: str
    from_type: str
    to_type: str
    reduction_rates: list[float]
    num_variants_per_rate: int
    base_seed: int


@dataclass
class VariantMetrics:
    experiment_exec_id: str
    variant_id: int
    rate: float
    flops_reduced: int
    func_reduction_density_mean: float
    func_reduction_density_std: float
    uc_depth_mean: float
    uc_depth_std: float
    uc_modularity: float
