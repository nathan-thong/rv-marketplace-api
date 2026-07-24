# Infrastructure (Terraform + GCP)

This provisions the hosting infrastructure the app deploys onto. It does **not** deploy the app itself — that's Kamal's job (already set up in `config/deploy.yml` and the `Gemfile`). The split:

- **Terraform** creates the VM, networking, firewall rules, and static IP.
- **Kamal** builds the Docker image, installs Docker on the VM on first deploy, and runs/updates the containers over SSH.

## What this provisions

- A dedicated VPC + subnet (not the GCP default network)
- Firewall rules: SSH (22) and HTTP/HTTPS (80/443, for Kamal's built-in proxy and Let's Encrypt)
- A single `e2-micro` Compute Engine instance running Debian 12
- A static external IP attached to that instance

## Why GCP e2-micro specifically

GCP's Always Free tier includes one `e2-micro` instance running indefinitely at no cost — not just for an introductory 12 months like AWS/most other providers — as long as it stays in **`us-west1`, `us-central1`, or `us-east1`**. This config defaults to `us-central1` for that reason; changing the region loses free-tier eligibility. The 30GB boot disk uses `pd-standard` (not `pd-ssd`), since only standard persistent disk is covered by the free tier. The static IP is free only while it's attached to a running instance — a reserved-but-unattached IP gets billed.

Postgres runs as a container on the same VM (see the root `docker-compose.yml`) rather than using Cloud SQL, since a managed Postgres instance isn't part of the free tier at any size.

## Prerequisites

- A GCP project with billing enabled (required to create the project at all, even though nothing here should incur charges if you stay within the constraints above)
- [`gcloud` CLI](https://cloud.google.com/sdk/docs/install), authenticated: `gcloud auth application-default login`
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An SSH key pair for Kamal to deploy with

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set project_id and ssh_public_key

terraform init
terraform plan
terraform apply
```

After `apply`, take the `instance_ip` output and:

1. Set it as the `servers.web` host in `config/deploy.yml`.
2. Fill in `.kamal/secrets` (`RAILS_MASTER_KEY`, etc.).
3. Run `bin/kamal setup` to do the first deploy — this is what actually installs Docker and starts the app on the box Terraform just created.

## State

State is local (`terraform.tfstate`) for now, which is fine for a single-person/single-environment project like this but isn't how you'd run this for a real team — a GCS backend would be the natural next step if this grows past one person applying changes from their own machine.

## Teardown

```bash
terraform destroy
```
