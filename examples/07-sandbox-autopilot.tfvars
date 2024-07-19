# Copyright 2024 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Demo setup to leverage GKE Sandbox (gvisor) in a GKE Autopilot cluster.
#
# You can verify that the workload is running in gVisor by running this command inside:
# runner@arc-runners-sandbox-rrxz4-runner-9shc2:~$ dmesg
# [    0.000000] Starting gVisor...
# [    0.355565] Checking naughty and nice process list...

project_id = "your-project-id"
region     = "europe-west1"

arc_runner_sets = [
    {
        namespace = "ns1"
        name = "sandbox"
        runtime_class_name = "gvisor"
        arc_github = {
            pat_secret_id = "github_auth"
            pat_secret_version = 1
            config_url = "https://github.com/your-org/your-repo"
        }
    }
]
