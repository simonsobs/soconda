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
    args = parser.parse_args()

    # Read the JSON file
    with open(args.base_json, "r") as file:
        base_config = json.load(file)

    conda_prefix = os.environ.get("CONDA_PREFIX")
    if conda_prefix is None:
        raise EnvironmentError("CONDA_PREFIX environment variable is not set.")

    rp_config = base_config[args.config]
    rp_config["virtenv"] = conda_prefix


    rp_config["pre_bootstrap_0"][1] = f"conda activate {conda_prefix}"
    rp_config["task_pre_exec"][1] = f"conda activate {conda_prefix}"
    rp_config["launch_methods"]["SRUN"]["pre_exec_cached"][1] = f"conda activate {conda_prefix}"
    with open(args.output_json, "w") as file:
        json.dump({args.config: rp_config}, file, indent=4)
