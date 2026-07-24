output "instance_ip" {
  description = "Static external IP of the app VM. Use this as the servers.web host in config/deploy.yml."
  value       = google_compute_address.static_ip.address
}

output "instance_name" {
  description = "Name of the compute instance, for gcloud/console lookups."
  value       = google_compute_instance.app.name
}

output "ssh_command" {
  description = "Convenience command to manually SSH into the instance."
  value       = "ssh ${var.ssh_user}@${google_compute_address.static_ip.address}"
}
