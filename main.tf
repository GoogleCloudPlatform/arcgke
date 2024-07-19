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

provider "google" {
  project = var.project_id
  region  = var.region
}
# GKE Sandbox is currently beta, need to use the beta provider
provider "google-beta" {
  project = var.project_id
  region  = var.region
}

resource "random_id" "random_suffix" {
  byte_length = 4
}

locals {
  separated_arc_controller = !var.gke_autopilot && var.gke_nodepool_for_arc_controller.nodes_per_zone > 0 ? true : false
}


resource "google_service_account" "controller_sa" {
  count = local.separated_arc_controller ? 1 : 0

  account_id   = "arc-controller-${random_id.random_suffix.hex}"
  display_name = "Service Account for the ARC controller nodes"
}

resource "google_service_account" "worker_sa" {
  account_id   = "arc-worker-${random_id.random_suffix.hex}"
  display_name = "Service Account for the ARC worker nodes"
}

locals {
  workerServiceAccountIamMember = ["serviceAccount:${google_service_account.worker_sa.email}"]
  allServiceAccountsIamMember = (local.separated_arc_controller ? concat(local.workerServiceAccountIamMember, ["serviceAccount:${google_service_account.controller_sa[0].email}"]) : local.workerServiceAccountIamMember)

  # https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
  leastPrivilegeRoles = ["logging.logWriter", "monitoring.metricWriter", "monitoring.viewer", "autoscaling.metricsWriter"]
}

# https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
resource "google_project_iam_binding" "leastPrivileges" {
  for_each = toset(local.leastPrivilegeRoles)

  project = var.project_id
  role    = "roles/${each.value}"

  members = local.allServiceAccountsIamMember
}
