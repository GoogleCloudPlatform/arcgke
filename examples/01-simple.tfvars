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

# This is the simpliest setup. It will create a GKE cluster in Autopilot mode. One ARC runner set will be configured with name `arc-runners-linux`
project_id = "your-project-id"
region     = "europe-west1"

arc_runner_sets = [
    {
        namespace = "ns1"
        name = "linux"
        arc_github = {
            pat_secret_id = "github_auth"
            pat_secret_version = 1
            config_url = "https://github.com/your-org/your-repo"
        }
    }
]