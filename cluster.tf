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

locals {
  cluster_name = "arc-k8s-cluster-${random_id.random_suffix.hex}"
}

resource "google_container_cluster" "arc_k8s_cluster_standard" {
  count = var.gke_autopilot ? 0 : 1

  name     = local.cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  network_policy {
    enabled = true
  }

  # On Autopilot, Workload Identity Federation is turned on by default anyway
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false

  depends_on = [
    google_project_iam_binding.leastPrivileges
  ]
}

resource "google_container_cluster" "arc_k8s_cluster_autopilot" {
  count = var.gke_autopilot ? 1 : 0

  name     = local.cluster_name
  location = var.region

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  deletion_protection = false

  enable_autopilot = true

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.worker_sa.email
    }
  }

  depends_on = [
    google_project_iam_binding.leastPrivileges
  ]
}

locals {
  k8s_cluster = var.gke_autopilot ? google_container_cluster.arc_k8s_cluster_autopilot[0] : google_container_cluster.arc_k8s_cluster_standard[0]
}
