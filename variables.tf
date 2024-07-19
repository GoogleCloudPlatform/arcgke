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

variable "project_id" {
  description = "Google Cloud Project ID where the Kubernetes cluster will be created. An exclusive project dedicated for ARC is recommended."
  type        = string
}

variable "region" {
  description = "Google Cloud region where the Kubernetes cluster will be created, (e.g. europe-west1)."
  type        = string
}

variable "gke_autopilot" {
  description = "GKE Autopilot is a mode of operation in GKE in which Google manages your cluster configuration, including your nodes, scaling, security, and other preconfigured settings. https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview"
  type        = bool
  default     = true
}

variable "gke_machine_type" {
  description = "[GKE Standard only] The machine types of the instances in your node pools, example n1-standard-4. See also https://cloud.google.com/compute/docs/machine-resource"
  type        = string
  default     = "default"
}

variable "gke_nodepool_for_arc_controller" {
  description = "[GKE Standard only] This option can be used to isolate the worker nodes and the ARC controller nodes. Setting this to zero will place the ARC controllers and the worker pods on the same k8s nodes."
  type = object({
    # The number of nodes for a dedicated controller. Zero disables this feature (so runner-sets and the listener/controller pods are scheduled to the same nodes).
    nodes_per_zone = number
    # The machine types of the instances in your node pools, example n1-standard-4. See also https://cloud.google.com/compute/docs/machine-resource"
    gke_machine_type = optional(string)
  })
  default = {
    nodes_per_zone  = 1
  }
}

variable "gke_nodepools" {
  description = "[GKE Standard only] List of GKE pools for runner-sets."
  type = list(object({
     # Required. Name of the node pool (you need to match this at the arc_runner_sets configs).
     name = string
     # The machine types of the instances in your node pools, example n1-standard-4. See also https://cloud.google.com/compute/docs/machine-resource"
     gke_machine_type = optional(string)
     # Image type for the node pool. Defaults to COS_CONTAINERD. See https://cloud.google.com/kubernetes-engine/docs/concepts/node-images#available_node_images
     gke_image_type = optional(string)
     # Activates confidential nodes. https://cloud.google.com/blog/products/identity-security/announcing-general-availability-of-confidential-gke-nodes
     gke_confidential = optional(bool)
     # The number of nodes for this pool per zone. Mutually exclusive with the autoscaling setup. Defaults to 1 when no relevant options are configured.
     nodes_per_zone = optional(number)
     # Configured autoscaling for this node pool. https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool#nested_autoscaling
     autoscaling_min_nodes_per_zone = optional(number)
     # Configured autoscaling for this node pool. https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool#nested_autoscaling
     autoscaling_max_nodes_per_zone = optional(number)
     # GKE Sandbox provides an extra layer of security to prevent untrusted code from affecting the host kernel on your cluster nodes. When true, node pools will be created with GKE sandbox enabled (runsc/gVisor). https://cloud.google.com/kubernetes-engine/docs/concepts/sandbox-pods
     # Besides this setting here, you need to configure runtime_class_name on your runner set as well.
     gke_sandbox_type = optional(string)
     # Type of the accelerator (GPU) to attach to the node pool. https://cloud.google.com/kubernetes-engine/docs/how-to/gpus#create-gpu-pool-auto-drivers
     # Also consult this page to select the right gke_machine_type: https://cloud.google.com/compute/docs/gpus
     # Also consult this page to learn more about GPU availability per zone: https://cloud.google.com/compute/docs/gpus/gpu-regions-zones
     guest_accelerator_type = optional(string)
     # Number of accelerators (GPU) to attach to the node pool
     guest_accelerator_count = optional(number)
     # Driver version to install, you probably want to set this to "DEFAULT". https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#nested_gpu_driver_installation_config
     guest_accelerator_driver_version = optional(string)
  }))
  default = [{
    name = "linux"
  }]
}


variable "arc_runner_sets" {
  description = "Runner-sets for ARC."
  type = list(object({
     # Required. Name suffix of the Kubernetes namespace to install to. The fixed prefix is `arc-runners-`. Must be unique.
     namespace = string
     # Required. Name of the runner set. You can refer to it in your workflow as `runs-on: <name>`. Same name may exist in multiple namespaces. This enables using the same `runs-on` tag at different organizations.
     name = string
     # [GKE Standard only] Name of the node pool to schedule the runners to (see gke_nodepools.name)
     nodepool = optional(string)
     # Minimum number of runners.
     min_runners = optional(number)
     # Maximum number of runners.
     max_runners = optional(number)
     # Pod spec template for the runners. Must point to to `arc-podspec-*.yaml`. Defaults to `default` (so `arc-podspec-default.yaml` is loaded)
     podspec_template = optional(string)
     # GKE Sandbox provides an extra layer of security to prevent untrusted code from affecting the host kernel on your cluster nodes. When true, node pools will be created with GKE sandbox enabled (runsc/gVisor). https://cloud.google.com/kubernetes-engine/docs/concepts/sandbox-pods
     # When the cluster is in Autopilot mode, you need to enable sandboxing only here. When the cluster is in Standard mode, you need to confiugre gke_sandbox_type on the node pool as well.
     # Currently supported value: gvisor
     runtime_class_name = optional(string)
     # Name of the GKE acceleator; turned into a node selector. Useful to specify GPU constraints for GKE Autopilot.
     gke_accelerator = optional(string)
     # Config options to setup the runner
     arc_github = object({
        # The secret ID in Secret Manager that holds the Personal access token (PAT) needed to register/unregister Action runners. You must specify either pat_secret_id+pat_secret_version or app_id+app_installation_id+app_private_key_secret_id+app_private_key_secret_version.
        pat_secret_id = optional(string)
        # The secret version in Secret Manager that holds the Personal access token (PAT) needed to register/unregister Action runners. You must specify either pat_secret_id+pat_secret_version or app_id+app_installation_id+app_private_key_secret_id+app_private_key_secret_version.
        pat_secret_version = optional(number)

        # Application ID of your Github APP for ARC. You must specify either arc_github_pat or arc_github_app_id+arc_github_app_installation_id+arc_github_app_private_key.
        app_id = optional(number)
        # App installation ID of your Github APP for ARC. You must specify either arc_github_pat or arc_github_app_id+arc_github_app_installation_id+arc_github_app_private_key.
        app_installation_id = optional(number)
        # The secret ID in Secret Manager that holds the private key of your GitHub app installation for ARC. You must specify either pat_secret_id+pat_secret_version or app_id+app_installation_id+app_private_key_secret_id+app_private_key_secret_version.
        app_private_key_secret_id = optional(string)
        # The secret version in Secret Manager that holds private key of your GitHub app installation for ARC. You must specify either pat_secret_id+pat_secret_version or app_id+app_installation_id+app_private_key_secret_id+app_private_key_secret_version.
        app_private_key_secret_version = optional(number)

        # URL to attach the runner to. (E.g. your org or a repository)
        config_url = string
     })
  }))
}

