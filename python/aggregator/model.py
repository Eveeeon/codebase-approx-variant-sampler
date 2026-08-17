from dataclasses import dataclass
from pathlib import Path

@dataclass
class AggregatorConfig:
    experiment_dir: Path
    experiment_id: str
    energy_dir: Path
    out_file_dir: Path
    out_file_type: str
    metrics_file: Path
    agg_results_file: Path