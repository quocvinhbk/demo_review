#!/usr/bin/env python

import os
import sys
import json


def json_to_env(json_filename, env_filename, branch_name):
    if not os.path.exists(json_filename):
        return "JSON file not found"

    with open(json_filename, "r") as json_file:
        json_data = json.load(json_file)

    envs = []
    if branch_name:
        for key, value in json_data.items():
            if key.startswith(branch_name.upper()):
                envs.append(f"{key[len(branch_name.upper()) + 1 :]}={value}")
    else:
        for key, value in json_data.items():
            envs.append(f"{key}={value}")

    envs = "\n".join(envs)
    if json_data:
        envs += "\n"

    with open(env_filename, "w") as env_file:
        env_file.write(envs)

    return env_filename


if __name__ == "__main__":
    json_filename = sys.argv[1]
    env_filename = sys.argv[2]
    branch_name = sys.argv[3] if len(sys.argv) > 3 else None
    print(json_to_env(json_filename, env_filename, branch_name))  # noqa: T201
