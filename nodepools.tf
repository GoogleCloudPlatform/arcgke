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

# Note: Node pools are supported by GKE Sandbox only; pool configs below apply to GKE Sandbox only.

locals {
  # this is the default these days but also an explicit requirement for GKE Sandbox
  gke_image_type_default = "COS_CONTAINERD"
}

resource "google_container_node_pool" "arc_controller" {
  # only when autopilot is turned off and separate_controller is turned on
  count = local.separated_arc_controller ? 1 : 0

  name       = "arc-controller-pool-${random_id.random_suffix.hex}"
  location   = var.region
  cluster    = local.k8s_cluster.name

  node_count = var.gke_nodepool_for_arc_controller.nodes_per_zone

  node_config {
    labels = {
      arc = "controller"
    }

    # not using the default compute account, it has Editor permission on the project
    service_account = google_service_account.controller_sa[0].email

    machine_type = var.gke_nodepool_for_arc_controller.gke_machine_type
  }
}

resource "google_container_node_pool" "runner_pool" {
  # only when autopilot is turned off
  for_each = !var.gke_autopilot ? {for index, np in var.gke_nodepools: np.name => np} : {}

  provider = google-beta

  name       = "arc-worker-pool-${each.value.name}-${random_id.random_suffix.hex}"
  location   = var.region
  cluster    = local.k8s_cluster.name

  node_config {
    labels = {
      arc = "runner"
      name = each.value.name
    }

    image_type = each.value.gke_image_type != null ? each.value.gke_image_type : local.gke_image_type_default

    # not using the default compute account, it has Editor permission on the project
    service_account = google_service_account.worker_sa.email

    machine_type = each.value.gke_machine_type

    dynamic "confidential_nodes" {
      for_each = each.value.gke_confidential != null ? ["do"] : []
      content {
        enabled = each.value.gke_confidential
      }
    }

    dynamic "sandbox_config" {
      for_each = each.value.gke_sandbox_type != null ? ["do"] : []
      content {
        sandbox_type = each.value.gke_sandbox_type
      }
    }

    dynamic "guest_accelerator" {
      for_each = each.value.guest_accelerator_type != null ? ["do"] : []
      content {
        type = each.value.guest_accelerator_type
        count = each.value.guest_accelerator_count
        gpu_driver_installation_config {
          gpu_driver_version = each.value.guest_accelerator_driver_version
        }
      }
    }
  }

  # node_count defaults to 1, if it is not specified and autoscaling was not configured.
  node_count = each.value.nodes_per_zone != null ? each.value.nodes_per_zone : (each.value.autoscaling_min_nodes_per_zone == null && each.value.autoscaling_max_nodes_per_zone == null ? 1 : null)

  dynamic "autoscaling" {
    for_each = each.value.autoscaling_min_nodes_per_zone != null || each.value.autoscaling_max_nodes_per_zone != null ? ["do"] : []
    content {
      min_node_count = each.value.autoscaling_min_nodes_per_zone
      max_node_count = each.value.autoscaling_max_nodes_per_zone
    }
  }
}

resource "null_resource" "nodepools" {
  depends_on = [
    google_container_cluster.arc_k8s_cluster_autopilot, 
    google_container_node_pool.arc_controller, 
    google_container_node_pool.runner_pool
  ]
}
