import argparse
import logging
from pathlib import Path

# Local package imports
from .io import import_config, write_to_cmd_file
from .model import SubjectAdapterConfig

def set_logger(experiment_id: str, log_file_path: Path):
    logging.basicConfig(
        level=logging.INFO,
        format=(
            f"%(levelname)s %(asctime)s "
            f"[experiment={experiment_id}] "
            f"%(name)s: %(message)s"
        ),
        handlers=[
            logging.FileHandler(log_file_path),
            logging.StreamHandler(),
        ],
    )

def build_run_command(
    binary_path: Path, variant_id: str, config: SubjectAdapterConfig
) -> str:
    """Build a single execution command for a variant binary with args, stdin, etc.

    Args:
        binary_path (Path): full path to the binary
        variant_id (str): the unique id of the variant
        config (SubjectAdapterConfig): the experiment subject adapter configuration

    Returns:
        str: the built command string
    """
    cmd = binary_path.resolve()
    if config.stdin_val:
        cmd = f"echo '{adapter_config['stdin_val']}' | {cmd}"
    if config.args:
        cmd = f"{cmd} {args}"
    if config.stdout_path:
        cmd = f"{cmd} | tee {config.stdout_path}/{variant_id}.{config.stdout_file_type}"
    return cmd


def generate_run_commands(config: SubjectAdapterConfig):
    """Iterates through the binary directory, generating a corresponding command file for each

    Args:
        config (SubjectAdapterConfig): the experiment subject adapter configuration
    """
    binary_dir = config.experiment_dir / "binary"
    logger = logging.getLogger("generate commands")
    logger.info(f"CREATING command files for {len(binary_dir.iterdir())} binary files")
    for file in binary_dir.iterdir():
        variant_id = file.name
        cmd = build_run_command(file, variant_id, config)
        cmd_file_path = config.experiment_dir / "commands" / f"{variant_id}.sh"
        write_to_cmd_file(cmd_file_path, cmd)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root_path", help="Path of the root directory", type=Path)
    parser.add_argument(
        "project_config", help="Path of the project config file", type=Path
    )
    parser.add_argument(
        "experiment_config", help="Path of the experiment config file", type=Path
    )
    parser.add_argument("log_file_path", help="Full path of the log file", type=Path)
    args = parser.parse_args()
    config = import_config(args.root_path, args.project_config, args.experiment_config)
    config = import_config(args.root_path, args.project_config, args.experiment_config)
    set_logger(config.experiment_id, args.log_file_path)
    generate_run_commands(config)


if __name__ == "__main__":
    main()
