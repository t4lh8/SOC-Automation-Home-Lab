# Provisions the cloud VM that hosts the SOC lab server stack, on DigitalOcean.
#
#   terraform init
#   terraform apply        # creates the droplet + firewall, installs Docker via cloud-init
#   terraform destroy      # tears everything down so you stop paying
#
# DigitalOcean is used because it is the cheapest common option for this lab and you
# can create, test, and destroy in an afternoon for a few dollars. The same approach
# maps to AWS/Azure by swapping the provider and resource types.

terraform {
  required_version = ">= 1.5"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# cloud-init installs Docker and clones this repo onto the VM, ready for setup.sh.
resource "digitalocean_droplet" "soc" {
  name     = var.droplet_name
  image    = "ubuntu-22-04-x64"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [var.ssh_key_fingerprint]
  tags     = ["soc-lab"]

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    repo_url = var.repo_url
  })
}

# Lock the dashboards down to your own IP. Only the Wazuh agent ports are reachable
# from the endpoint, and nothing sensitive is exposed to the whole internet.
resource "digitalocean_firewall" "soc" {
  name        = "${var.droplet_name}-fw"
  droplet_ids = [digitalocean_droplet.soc.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22" # SSH
    source_addresses = [var.my_ip]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443" # Wazuh dashboard
    source_addresses = [var.my_ip]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "55000" # Wazuh API (Shuffle active response)
    source_addresses = [var.my_ip]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3443" # Shuffle UI
    source_addresses = [var.my_ip]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9000" # TheHive UI
    source_addresses = [var.my_ip]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "1514-1515" # Wazuh agent enrollment + events
    source_addresses = [var.endpoint_ip]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
