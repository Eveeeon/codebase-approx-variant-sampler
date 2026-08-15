from dataclasses import dataclass
from pathlib import Path

@dataclass
class SubjectAdapterConfig:
    experiment_dir: Path
    experiment_id: str
    stdin_val: str
    args: list[str]
    stdout_path: Path
    stdout_file_type: str