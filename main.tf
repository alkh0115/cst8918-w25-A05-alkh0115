terraform {
  required_version = ">= 1.1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "cloudinit" {}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.labelPrefix}-A05-RG"
  location = var.region
}

# Public IP
resource "azurerm_public_ip" "web_ip" {
  name                = "${var.labelPrefix}-A05-publicip"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.labelPrefix}-A05-vnet"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.labelPrefix}-A05-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group with SSH and HTTP rules
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.labelPrefix}-A05-nsg"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NIC
resource "azurerm_network_interface" "nic" {
  name                = "${var.labelPrefix}-A05-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "web-nic-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_ip.id
  }
}

# Attach NSG to NIC
resource "azurerm_network_interface_security_group_association" "nsgassoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Cloud-init config to install Apache
data "cloudinit_config" "webinit" {
  part {
    filename     = "init.sh"
    content_type = "text/x-shellscript"
    content      = file("${path.module}/init.sh")
  }
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.labelPrefix}-A05-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  size                = "Standard_B1s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.labelPrefix}-A05-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  custom_data = data.cloudinit_config.webinit.rendered
}
