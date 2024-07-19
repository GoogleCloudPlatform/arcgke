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

# In this mode, containers specified in the Action workflow will be created as pods.
# For more info, refer to: https://github.com/actions/actions-runner-controller/blob/master/docs/deploying-arc-runners.md
project_id = "your-project-id"
region     = "europe-west1"

arc_runner_sets = [
    {
        namespace = "ns1"
        name = "linux"
        podspec_template = "kubernetes"
        arc_github = {
            pat_secret_id = "github_auth"
            pat_secret_version = 1
            config_url = "https://github.com/your-org/your-repo"
        }
    },
]
