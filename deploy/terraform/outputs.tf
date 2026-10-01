output "server_ip" {
  description = "Public IP of the SOC lab server."
  value       = digitalocean_droplet.soc.ipv4_address
}

output "next_steps" {
  description = "What to do once the droplet is up."
  value       = <<-EOT
    1. SSH in:        ssh root@${digitalocean_droplet.soc.ipv4_address}
    2. Deploy stack:  cd /opt/SOC-Automation-Home-Lab/deploy && cp .env.example .env && sudo ./setup.sh
    3. Dashboards (from your IP only):
         Wazuh    https://${digitalocean_droplet.soc.ipv4_address}
         Shuffle  https://${digitalocean_droplet.soc.ipv4_address}:3443
         TheHive  http://${digitalocean_droplet.soc.ipv4_address}:9000
    4. When finished:  terraform destroy   (stops all charges)
  EOT
}
