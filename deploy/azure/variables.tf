variable "location" {
  description = "Azure region. Norway East is closest; switch to e.g. swedencentral if your subscription has no quota there."
  type        = string
  default     = "norwayeast"
}

variable "prefix" {
  description = "Name prefix for every resource."
  type        = string
  default     = "soc-lab"
}

variable "my_ip" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.5/32). Dashboards, SSH and RDP are only open to this."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used to log in to the Linux server."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "server_size" {
  description = "Linux server size. Wazuh + Shuffle + TheHive want about 16 GB RAM."
  type        = string
  default     = "Standard_D4s_v5" # 4 vCPU, 16 GB
}

variable "endpoint_size" {
  description = "Windows endpoint size."
  type        = string
  default     = "Standard_B2s" # 2 vCPU, 4 GB
}

variable "admin_username" {
  description = "Admin user on both VMs."
  type        = string
  default     = "labadmin"
}

variable "shutdown_time" {
  description = "Daily auto-shutdown (HHMM, in shutdown_timezone) so a forgotten lab does not burn credit."
  type        = string
  default     = "2200"
}

variable "shutdown_timezone" {
  description = "Windows time zone name for the auto-shutdown schedule."
  type        = string
  default     = "W. Europe Standard Time"
}

variable "repo_url" {
  description = "This repository, cloned onto the server by cloud-init."
  type        = string
  default     = "https://github.com/t4lh8/SOC-Automation-Home-Lab.git"
}
