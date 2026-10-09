# Provisions the SOC lab on Azure: one Linux server for Wazuh + Shuffle + TheHive
# and one Windows endpoint for the Wazuh agent and Sysmon. Fits an Azure for
# Students subscription (6 vCPU in total, which is exactly what this uses).
#
#   az login
#   terraform init
#   terraform apply
#   terraform destroy      # when done, so the credit stops running

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # terraform destroy should remove everything, even things added by hand in the portal.
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = { project = "soc-automation-home-lab" }
}

# Network: both VMs share one private subnet, so agent traffic (1514/1515)
# never leaves the virtual network.

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "lab" {
  name                 = "lab"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "lab" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  # Admin access and dashboards, only from your own IP:
  # 22 SSH, 443 Wazuh, 3389 RDP to the endpoint, 3443 Shuffle, 9000 TheHive.
  security_rule {
    name                       = "admin-from-my-ip"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.my_ip
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["22", "443", "3389", "3443", "9000"]
  }

  # Wazuh agent enrollment, events and API, from inside the VNet only.
  security_rule {
    name                       = "wazuh-in-vnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["1514", "1515", "55000"]
  }

  security_rule {
    name                       = "deny-other-internet"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "lab" {
  subnet_id                 = azurerm_subnet.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

# Linux server: Wazuh manager + indexer + dashboard, Shuffle, TheHive.

resource "azurerm_public_ip" "server" {
  name                = "${var.prefix}-server-ip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "server" {
  name                = "${var.prefix}-server-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.20.1.10"
    public_ip_address_id          = azurerm_public_ip.server.id
  }
}

resource "azurerm_linux_virtual_machine" "server" {
  name                  = "${var.prefix}-server"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.server_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.server.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }
  disable_password_authentication = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Same cloud-init as the DigitalOcean option: Docker, kernel setting, repo clone.
  custom_data = base64encode(templatefile("${path.module}/../terraform/cloud-init.yaml", {
    repo_url = var.repo_url
  }))
}

# Windows endpoint: gets Sysmon and the Wazuh agent (see endpoint-setup.ps1).

resource "random_password" "endpoint" {
  length           = 24
  special          = true
  override_special = "!@#%*-_=+"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_public_ip" "endpoint" {
  name                = "${var.prefix}-endpoint-ip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "endpoint" {
  name                = "${var.prefix}-endpoint-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.20.1.20"
    public_ip_address_id          = azurerm_public_ip.endpoint.id
  }
}

# Windows Server 2022 instead of Windows 10/11: client images need extra licensing
# on most subscriptions. Sysmon and the Wazuh agent behave the same.
resource "azurerm_windows_virtual_machine" "endpoint" {
  name                  = "${var.prefix}-win"
  computer_name         = "LAB-WIN"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.endpoint_size
  admin_username        = var.admin_username
  admin_password        = random_password.endpoint.result
  network_interface_ids = [azurerm_network_interface.endpoint.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-smalldisk"
    version   = "latest"
  }
}

# Auto-shutdown every evening on both VMs.

resource "azurerm_dev_test_global_vm_shutdown_schedule" "server" {
  virtual_machine_id    = azurerm_linux_virtual_machine.server.id
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = var.shutdown_timezone

  notification_settings {
    enabled = false
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "endpoint" {
  virtual_machine_id    = azurerm_windows_virtual_machine.endpoint.id
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = var.shutdown_timezone

  notification_settings {
    enabled = false
  }
}
