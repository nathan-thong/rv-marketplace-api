variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "GCP region. Must be us-west1, us-central1, or us-east1 to keep the e2-micro instance Always-Free eligible."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone within the region."
  type        = string
  default     = "us-central1-a"
}

variable "name" {
  description = "Base name prefix applied to every resource this config creates."
  type        = string
  default     = "rv-marketplace"
}

variable "ssh_user" {
  description = "SSH username Kamal will connect as when deploying."
  type        = string
  default     = "kamal"
}

variable "ssh_public_key" {
  description = "Public key content (e.g. the contents of ~/.ssh/id_ed25519.pub) granted SSH access for Kamal deploys."
  type        = string
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to SSH into the instance. Defaults to open for initial setup - restrict this to your own IP once it's working."
  type        = list(string)
  default     = [ "0.0.0.0/0" ]
}
