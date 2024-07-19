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

# Attaching GPUs for your runners in GKE Standard.
project_id = "your-project-id"
region     = "europe-west1"
gke_autopilot = false

gke_nodepools = [
    {
        name = "gpu"
        gke_machine_type = "n1-standard-4"
        guest_accelerator_type = "nvidia-tesla-t4"
        guest_accelerator_count = 1
        guest_accelerator_driver_version = "DEFAULT"
    }
]
arc_runner_sets = [
    {
        namespace = "ns1"
        name = "gpu"
        nodepool = "gpu"
        podspec_template = "gpu"
        gke_accelerator = "nvidia-tesla-t4"
        arc_github = {
            pat_secret_id = "github_auth"
            pat_secret_version = 1
            config_url = "https://github.com/your-org/your-repo"
        }
    }
]
