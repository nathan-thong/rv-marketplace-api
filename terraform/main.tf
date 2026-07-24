terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc" {
  name                    = "${var.name}-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name}-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.name}-allow-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = [ "22" ]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = [ "${var.name}-web" ]
}

resource "google_compute_firewall" "allow_web" {
  name    = "${var.name}-allow-web"
  network = google_compute_network.vpc.id

  # Kamal's built-in proxy (kamal-proxy) terminates HTTP/HTTPS and handles
  # Let's Encrypt, so both ports need to be open to the world.
  allow {
    protocol = "tcp"
    ports    = [ "80", "443" ]
  }

  source_ranges = [ "0.0.0.0/0" ]
  target_tags   = [ "${var.name}-web" ]
}

# Always Free includes exactly one static external IP, but only while it's
# attached to a running instance - an unattached reserved IP is billed.
resource "google_compute_address" "static_ip" {
  name   = "${var.name}-static-ip"
  region = var.region
}

resource "google_compute_instance" "app" {
  name         = "${var.name}-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = [ "${var.name}-web" ]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      # pd-standard (not pd-ssd) is what Always Free's 30GB/month covers.
      type = "pd-standard"
      size = 30
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id

    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  # Kamal's own `kamal setup` installs Docker on first deploy, so the VM
  # itself just needs to exist and be reachable over SSH - no startup
  # script or pre-baked image required here.
}
