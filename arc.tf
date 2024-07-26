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

# Enable access to the configuration of the Google Cloud provider.
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${local.k8s_cluster.endpoint}"
  cluster_ca_certificate = base64decode( local.k8s_cluster.master_auth[0].cluster_ca_certificate )
  token                  = data.google_client_config.default.access_token
}


provider "helm" {
  kubernetes {
    host                   = "https://${local.k8s_cluster.endpoint}"
    cluster_ca_certificate = base64decode( local.k8s_cluster.master_auth[0].cluster_ca_certificate )
    token                  = data.google_client_config.default.access_token
  }
}

locals {
  arc_systems_namespace_name = "arc-systems"
  arc_secret_syncer_ksa_name = "arc-systems-secret-sync"
}

# The namespace for the controller
resource "kubernetes_namespace" "arc_systems" {
  metadata {
    annotations = {
      name = local.arc_systems_namespace_name
    }

    name = local.arc_systems_namespace_name
  }
}

# IAM setup to access the Secret Manager secrets.
# Need a KSA first:
resource "kubernetes_service_account" "ksa_secret_sync" {
  metadata {
    name = local.arc_secret_syncer_ksa_name
    namespace = local.arc_systems_namespace_name
  }
}

# Then we need to look up the project number first:
data "google_project" "project" {
}

# And then setup the Google Cloud IAM:
resource "google_secret_manager_secret_iam_binding" "binding" {
  secret_id = each.value.arc_github.pat_secret_id != null ? each.value.arc_github.pat_secret_id : each.value.arc_github.app_private_key_secret_id
  role = "roles/secretmanager.secretAccessor"
  members = [
    "principal://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${local.arc_systems_namespace_name}/sa/${local.arc_secret_syncer_ksa_name}",
  ]

  for_each = {for index, ars in var.arc_runner_sets: "${ars.namespace}-${ars.name}" => ars}
}

# Preparing the environment for the runners
# At first, a dedicated namespace for all runners:
resource "kubernetes_namespace" "arc_runners" {
  metadata {
    annotations = {
      name = "arc-runners-${each.value.namespace}"
    }

    name = "arc-runners-${each.value.namespace}"
  }

  for_each = {for index, ars in var.arc_runner_sets: "${ars.namespace}-${ars.name}" => ars}
}

# The KSA needs access to ARC listener secrets
resource "kubernetes_role" "arc_secret_syncer_role" {
  metadata {
    name = "arc-secret-syncer-role"
    namespace = "arc-runners-${each.value.namespace}"
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = []
    verbs          = ["get", "list", "watch", "update", "patch", "create"]
  }

  for_each = {for index, ars in var.arc_runner_sets: "${ars.namespace}-${ars.name}" => ars}
  depends_on = [
    kubernetes_namespace.arc_runners
  ]
}
resource "kubernetes_role_binding" "arc_secret_syncer_role_binding" {
  metadata {
    name      = "arc-secret-syncer-role-binding"
    namespace = "arc-runners-${each.value.namespace}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "arc-secret-syncer-role"
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.arc_secret_syncer_ksa_name
    namespace = local.arc_systems_namespace_name
  }

  for_each = {for index, ars in var.arc_runner_sets: "${ars.namespace}-${ars.name}" => ars}

  depends_on = [
    kubernetes_role.arc_secret_syncer_role,
    kubernetes_namespace.arc_runners
  ]
}



# pods should not be able to talk to each other
resource "kubernetes_network_policy" "runner_network_policy" {
  metadata {
    name      = "runner-network-policy"
    namespace = "arc-runners-${each.value.namespace}"
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/component" = "runner"
      }
    }

    # this is intentionally missing so all incoming traffic is blocked
    # ingress {}

    # all egress is allowed
    egress {
    }

    policy_types = ["Ingress", "Egress"]
  }

  for_each = {for index, ars in var.arc_runner_sets: "${ars.namespace}-${ars.name}" => ars}

  depends_on = [
    kubernetes_namespace.arc_runners
  ]
}


resource "kubernetes_job" "secret_sync" {
  metadata {
    name = "secret-sync-${each.value.namespace}-${each.value.name}"
    namespace = local.arc_systems_namespace_name
  }
  spec {
    template {
      metadata {}
      spec {
        node_selector = local.separated_arc_controller ? { "arc": "controller" } : {}

        service_account_name = local.arc_secret_syncer_ksa_name
        volume {
          name = "tmp-secret-strg"
          empty_dir {}
        }
        init_container  {
          name    = "fetch"
          image   = "google/cloud-sdk:slim"
          command = ["bash", "-c", <<EOH
             # pure mans validation: https://discuss.hashicorp.com/t/terraform-core-research-ability-to-raise-an-error/35818/5
             # ${(each.value.arc_github.pat_secret_id == null && each.value.arc_github.app_private_key_secret_id == null) ? file("ERROR: You must specify either pat_secret_id or app_private_key_secret_id") : "secret_id ok"}
             # ${(each.value.arc_github.pat_secret_version == null && each.value.arc_github.app_private_key_secret_version == null) ? file("ERROR: You must specify either pat_secret_version or app_private_key_secret_version") : "secret_version ok"}

             set -e
             name="${coalesce(each.value.arc_github.pat_secret_id, each.value.arc_github.app_private_key_secret_id)}"
             version="${coalesce(each.value.arc_github.pat_secret_version, each.value.arc_github.app_private_key_secret_version)}"
             gcloud secrets versions access --secret $${name} $${version} | base64 -w0 > /tmp/secret/auth
EOH
          ]
          volume_mount {
            name       = "tmp-secret-strg"
            mount_path = "/tmp/secret"
          }
        }
        container {
          name    = "update"
          image   = "alpine/k8s:1.27.15"
          command = ["bash", "-c", <<EOH
            set -e

            # ensuring the secret exists
            kubectl -n "arc-runners-${each.value.namespace}" create secret generic arc-runners-secret \
              ${each.value.arc_github.app_id != null ? "--from-literal=github_app_id=${each.value.arc_github.app_id}" : ""} \
              ${each.value.arc_github.app_installation_id != null ? "--from-literal=github_app_installation_id=${each.value.arc_github.app_installation_id}" : ""} \
              || true

            # now updating the secret portion
            kubectl get secrets -n "arc-runners-${each.value.namespace}" arc-runners-secret -o json \
              | jq --arg data "$(cat /tmp/secret/auth)" '.data["${each.value.arc_github.pat_secret_id != null ? "github_token" : "github_app_private_key"}"]=$data' \
              | kubectl apply -f -
EOH
          ]
          volume_mount {
            name       = "tmp-secret-strg"
            mount_path = "/tmp/secret"
          }
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 4
  }
  wait_for_completion = true
  timeouts {
    create = "5m"
    update = "5m"
  }

  for_each = {for index, ars in var.arc_runner_sets: "${ars.namespace}-${ars.name}" => ars}

  depends_on = [
    kubernetes_namespace.arc_runners,
    kubernetes_role_binding.arc_secret_syncer_role_binding
  ]
}


# Installing the controller using Helm
resource "helm_release" "arc_systems" {
  name       = local.arc_systems_namespace_name
  namespace  = local.arc_systems_namespace_name

  chart  = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"

  dynamic "set" {
    for_each = local.separated_arc_controller ? ["do"] : []
    content {
      name  = "nodeSelector.arc"
      value = "controller"
    }
  }

  depends_on = [
    null_resource.nodepools,
    kubernetes_namespace.arc_systems
  ]
}

# Installing the ARC runners
resource "helm_release" "arc_runners" {
  name       = each.value.name
  namespace  = "arc-runners-${each.value.namespace}"

  chart  = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"

  set {
    name  = "githubConfigUrl"
    value = each.value.arc_github.config_url
  }

  set {
    name  = "githubConfigSecret"
    value = "arc-runners-secret"
  }

  # force the listener to ever show up on the dedicated controller nodes only
  dynamic "set" {
    for_each = local.separated_arc_controller ? ["do"] : []
    content {
      name  = "listenerTemplate.spec.nodeSelector.arc"
      value = "controller"
    }
  }

  # this is needed otherwise it throws an error due to the containers not being configured
  dynamic "set" {
    for_each = local.separated_arc_controller ? ["do"] : []
    content {
      name  = "listenerTemplate.spec.containers[0].name"
      value = "listener"
    }
  }

  # force the runners to be scheduled on the worker nodes only
  dynamic "set" {
    for_each = !var.gke_autopilot ? ["do"] : []
    content {
      name  = "template.spec.nodeSelector.arc"
      value = "runner"
    }
  }
  dynamic "set" {
    for_each = !var.gke_autopilot ? ["do"] : []
    content {
      name  = "template.spec.nodeSelector.name"
      value = each.value.nodepool != null ? each.value.nodepool : "linux"
    }
  }
  dynamic "set" {
    for_each = each.value.gke_accelerator != null ? ["do"] : []
    content {
      name  = "template.spec.nodeSelector.cloud\\.google\\.com/gke-accelerator"
      value = each.value.gke_accelerator
    }
  }

  dynamic "set" {
    for_each = each.value.runtime_class_name != null ? ["do"] : []
    content {
      name  = "template.spec.runtimeClassName"
      value = each.value.runtime_class_name
    }
  }

  dynamic "set" {
    for_each = each.value.min_runners != null ? ["do"] : []
    content {
      name  = "minRunners"
      value = each.value.min_runners
    }
  }
  dynamic "set" {
    for_each = each.value.max_runners != null ? ["do"] : []
    content {
      name  = "maxRunners"
      value = each.value.max_runners
    }
  }

  values = [
    file("arc-podspec-${each.value.podspec_template != null ? each.value.podspec_template : "default"}.yaml")
  ]

  for_each = {for index, ars in var.arc_runner_sets: "${ars.namespace}-${ars.name}" => ars}

  depends_on = [
    helm_release.arc_systems,
    null_resource.nodepools,
    kubernetes_job.secret_sync
  ]
}
