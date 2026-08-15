from pathlib import Path
import tomllib

# Local package imports
from .model import SubjectAdapterConfig

def import_config(root_path: Path, project_config_path, experiment_config_path: Path) -> SubjectAdapterConfig:
    """Imports the subject adapter configuration

    Args:
        root_path (Path): absolute path of the root directory
        project_config_path (_type_): absolute path to the project config file
        experiment_config_path (Path): absolute path to the experiment config file

    Returns:
        SubjectAdapterConfig: the experiment subject adapter configuration
    """
    with open(project_config_path, "rb") as f:
        project_config = tomllib.load(f)
    with open(experiment_config_path, "rb") as f:
        experiment_config = tomllib.load(f)

    exp = experiment_config["experiment"]
    paths = project_config["paths"]
    adapter = experiment_config["adapter"]

    return SubjectAdapterConfig(
        experiment_dir=root_path / Path(paths["experiments"]) / Path(exp["id"]),
        experiment_id=exp["id"],
        stdin_val=adapter["stdin"],
        args=adapter["args"],
        stdout_path=root_path / adapter["stdout_path"],
        stdout_file_type=adapter["stdout_file_type"],
    )

def write_to_cmd_file(path: Path, cmd: str):
    """Writes a given variant execution command to a .sh file to be executed

    Args:
        path (Path): absoulte path of the .sh file, including name and file extension
        cmd (str): the command string
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = "#!/usr/bin/env bash\n"
    lines += "set -euo pipefail\n"
    lines += cmd
    lines += "\n"
    path.write_text(lines, encoding="utf-8")
    path.chmod(0o755)