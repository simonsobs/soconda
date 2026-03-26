import json
import os
from argparse import ArgumentParser


if __name__ == "__main__":

    parser = ArgumentParser(description="Generate a JSON file with system information.")
    parser.add_argument(
        "--config", type=str, required=True, help="The system to configure."
    )
    parser.add_argument(
        "--base-json", type=str, required=True, help="The base JSON file to use."
    )
    parser.add_argument(
        "--output-json", type=str, required=True, help="The output JSON file."
    )
    parser.add_argument(
        "--env-path", type=str, required=True, help="The path or name of the python environment."
    )
    parser.add_argument(
        "--env-type", type=str, required=False, help="The type of the python environment (e.g., conda, venv).",
        default="conda"
    )
    parser.add_argument(
        "--modules", type=str, nargs='*', required=False, help="List of modules to load before activating the environment."
    )
    args = parser.parse_args()

    # Read the JSON file
    with open(args.base_json, "r") as file:
        base_config = json.load(file)

    rp_config = base_config[args.config]
    rp_config["virtenv"] = args.env_path

    if args.env_type == "conda":
        rp_config["pre_bootstrap_0"][1] = f"conda activate {args.env_path}"
        rp_config["task_pre_exec"][1] = f"conda activate {args.env_path}"
        rp_config["launch_methods"]["SRUN"]["pre_exec_cached"][1] = f"conda activate {args.env_path}"
    else:
        rp_config["pre_bootstrap_0"][1] = f"source {args.env_path}/bin/activate"
        rp_config["task_pre_exec"][1] = f"source {args.env_path}/bin/activate"
        rp_config["launch_methods"]["SRUN"]["pre_exec_cached"][1] = f"source {args.env_path}/bin/activate"

    if args.modules:
        modules_to_load = " ".join(module for module in args.modules)
        rp_config["pre_bootstrap_0"][0] = f"module load {modules_to_load}"
        rp_config["task_pre_exec"][0] = f"module load {modules_to_load}"
        rp_config["launch_methods"]["SRUN"]["pre_exec_cached"][0] = f"module load {modules_to_load}"

    with open(args.output_json, "w") as file:
        json.dump({args.config: rp_config}, file, indent=4)
