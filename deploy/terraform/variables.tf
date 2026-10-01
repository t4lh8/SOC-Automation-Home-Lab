variable "do_token" {
  description = "DigitalOcean API token. Create one at cloud.digitalocean.com/account/api."
  type        = string
  sensitive   = true
}

variable "ssh_key_fingerprint" {
  description = "Fingerprint of an SSH key already uploaded to your DigitalOcean account."
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.5/32). Dashboards are limited to this."
  type        = string
}

variable "endpoint_ip" {
  description = "Public IP (CIDR) of the Windows endpoint running the Wazuh agent. Often the same as my_ip."
  type        = string
}

variable "droplet_name" {
  description = "Name for the VM."
  type        = string
  default     = "soc-lab"
}

variable "region" {
  description = "DigitalOcean region (e.g. fra1 for Frankfurt, closest to Norway)."
  type        = string
  default     = "fra1"
}

variable "droplet_size" {
  description = "Droplet size. The full stack needs ~16 GB; s-4vcpu-16gb is the sensible minimum."
  type        = string
  default     = "s-4vcpu-16gb"
}

variable "repo_url" {
  description = "This repository, cloned onto the VM by cloud-init."
  type        = string
  default     = "https://github.com/t4lh8/SOC-Automation-Home-Lab.git"
}
