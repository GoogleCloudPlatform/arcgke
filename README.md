# Actions Runner Controller (ARC) - GKE recipe

This project facilitates setting up self-hosted runners for GitHub Actions on
Google Kubernetes Engine (GKE). The Action workflows are executed in an
ephemeral way (new clean environment for each build).

**This is not an officially supported Google product, and it is not covered by a
Google Cloud support contract. To report bugs or request features in a Google
Cloud product, please contact [Google Cloud
support](https://cloud.google.com/support).**

## Features

-   easy to deploy (just a matter of a `terraform apply`)
-   supports various GKE features: Standard, Autopilot, Sandbox
-   in GKE Standard mode, node level isolation of the controller/listener pods
    and the runner pods for improved security
-   easy configuration of multiple pools (along with machine type, number of
    nodes, autoscaling)
-   easy configuration of runner-sets (along with container image, min/max
    runners and dind settings)
-   least privilege service accounts attached to the GKE nodes
-   network isolation of runner pods
-   support for ARC containermodes: Docker-in-Docker (both dind and
    dind-rootless) and Kubernetes
-   Windows support (besides Linux, of course)
-   dedicated runner config for each runner-set allows binding them to any
    github org or repo and different installation id. In other words, you can
    use the same ARC cluster to serve Action workflows for different
    organizations
-   sensitive data (PAT or the App's private key) is passed to the ARC
    listeners via [Secret Manager](https://cloud.google.com/security/products/secret-manager).
    Now, even the Terraform state will not contain these credentials!

## How to use?

-   Create a secret in [Secret Manager](https://cloud.google.com/security/products/secret-manager)
```
    $ gcloud secrets create github_auth --replication-policy="automatic" --project <your-project-id>
    Created secret [github_auth].
```

    If you use a personal access token to authenticate:

```
    $ echo -n "ghp_..." | gcloud secrets versions add github_auth --data-file=-
    Created version [1] of the secret [github_auth].
```

    If you use a GitHub application to authenticate, do it like this:
```
    $ gcloud secrets versions add github_auth --data-file=github-app-rsa.key
    Created version [1] of the secret [github_auth].
```

-   Create a config file called `arc.tfvars`. You can refer to `variables.tf`
    about the supported config options. Set `pat_secret_id`/`pat_secret_version` or
    `app_private_key_secret_id`/`app_private_key_secret_version`. Minimal example:

```
project_id = "your-gcp-project-id"
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
]```

-   Run terraform:

```
terraform init
terraform apply --var-file=arc.tfvars
```

This will output the `gcloud` command that you can use to setup `kubectl` to
access the newly created cluster.

See the examples subdirectory for more advanced use-cases or read on this guide
for more high-level info.

### Run the workflow

In your GitHub workflow, set `runs-on` to `<name-of-the-runner-set>`.
Example workflow `.github/workflows/some-action.yaml`:

```
name: Actions Runner Controller Demo
on:
  workflow_dispatch:

jobs:
  Explore-GitHub-Actions:
    runs-on: arc-runners-linux
    steps:
    - run: echo "🎉 This job uses runner scale set runners!"
```

The GKE worker nodes behind the runner sets are running as the IAM service
account `arc-worker-<random-suffix>@<your-project-id>.gserviceaccount.com` where
the random-suffix matches the suffix of the GKE cluster. The IAM policies
granted for this IAM service account is in line with the GKE hardening
guideline:
https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
You may also use Workload Identity Federation, which is enabled on the cluster.

You may grant additional access, when needed.

### How to fine tune nodepools?

By default the GKE cluster is created in Autopilot mode that will take care of
both security and autoscaling aspects for your project. You may switch to GKE
Standard if you need fine-grained control over the node pools for your runners.
In this case, the project will configure ARC to schedule the controller/listener
pods and the runner pods to different, dedicated worker pools. This prevents
access to the GitHub PAT even if a workload is compromised and manages to escape
its container.

The machine types of the GKE Standard instances in your node pools can be set
according to https://cloud.google.com/compute/docs/machine-resource Example
n1-standard-4.

You can also activate confidential mode to leverage secure boot or activate GKE
Sandbox to protect your workloads with gVisor as well.

### How to fine tune runner-sets?

Create a new file `arc-podspec-<yourlabelhere>.yaml`. Customize the runner set
according to your needs. Examples/documentation can be found here:
https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/deploying-runner-scale-sets-with-actions-runner-controller

Then, at `arc_runner_sets` in your tfvars config refer to it as
`podspec_template`. Full example:

```
arc_runner_sets = [
    {
        name = "linux-custom"
        nodepool = "linux"
        podspec_template = "custom"
        arc_github = {
            pat_secret_id = "github_auth"
            pat_secret_version = 1
            config_url = "https://github.com/your-org/your-repo"
        }
    }
]
```

This will create an ARC runner set that uses `arc-podspec-custom.yaml` as the
configuration. Runners will be scheduled to the linux nodepool (in the case of
GKE Standard).

If you need docker-in-docker (aka dind), set:

-   Understand the security implications: a compromised workload could easily
    gain persistence on the worker node since the pod will be running in
    privileged mode having access to the host resources.
-   `podspec_template = "dind"`: for your arc_runner_set
-   `gke_autopilot = false`: to use GKE Standard (Autopilot does not support
    privileged containers for security reasons)
-   `gke_image_type = "UBUNTU_CONTAINERD"`: on your gke_nodepools (docker and
    COS don't play nice here)

## Advanced

If you need to customize/fine tune something at Terraform level, prefer using an
override file:

https://developer.hashicorp.com/terraform/language/files/override
