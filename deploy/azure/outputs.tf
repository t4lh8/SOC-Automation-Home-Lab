output "server_ip" {
  description = "Public IP of the Linux server."
  value       = azurerm_public_ip.server.ip_address
}

output "endpoint_ip" {
  description = "Public IP of the Windows endpoint (RDP from your IP only)."
  value       = azurerm_public_ip.endpoint.ip_address
}

output "endpoint_password" {
  description = "Password for the Windows endpoint. Show it with: terraform output -raw endpoint_password"
  value       = random_password.endpoint.result
  sensitive   = true
}

output "next_steps" {
  description = "What to do once the VMs are up."
  value       = <<-EOT
    1. Server:   ssh ${var.admin_username}@${azurerm_public_ip.server.ip_address}
                 cd /opt/SOC-Automation-Home-Lab/deploy && cp .env.example .env && sudo ./setup.sh
    2. Endpoint: RDP to ${azurerm_public_ip.endpoint.ip_address} as ${var.admin_username}
                 (password: terraform output -raw endpoint_password)
                 Run deploy\azure\endpoint-setup.ps1 as Administrator. The manager IP is 10.20.1.10.
    3. Dashboards (from your IP only):
         Wazuh    https://${azurerm_public_ip.server.ip_address}
         Shuffle  https://${azurerm_public_ip.server.ip_address}:3443
         TheHive  http://${azurerm_public_ip.server.ip_address}:9000
    4. When finished:  terraform destroy
  EOT
}
