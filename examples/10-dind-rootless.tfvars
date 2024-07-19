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

# GKE cluster is created in Standard mode. A nodepool with name dind is created using UBUNTU base image. An ARC runner with name dind is created and is configured to run docker in rootless mode.
project_id = "your-project-id"
region     = "europe-west1"
gke_autopilot = false

gke_nodepools = [
    {
        name = "dind"
        gke_image_type = "UBUNTU_CONTAINERD"
    }
]
arc_runner_sets = [
    {
        namespace = "ns1"
        name = "dind"
        nodepool = "dind"
        podspec_template = "dind-rootless"
        arc_github = {
            pat_secret_id = "github_auth"
            pat_secret_version = 1
            config_url = "https://github.com/your-org/your-repo"
        }
    }
]
