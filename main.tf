provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
  tags = {
    environment = "Production"
  }

}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "external" {
  name                = "PublicIP"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "main" {
  count               = var.machines
  name                = "${var.prefix}-nic${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"

  }

}

resource "azurerm_network_security_group" "main-sg" {
  count               = var.machines
  name                = "main-sg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "internal-traffic"
    priority                   = 101
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "10.0.0.0/22"
    destination_port_range     = "*"
    destination_address_prefix = azurerm_network_interface.main[count.index].private_ip_address
  }
  security_rule {
    access                     = "Deny"
    direction                  = "Inbound"
    name                       = "Internet-traffic"
    priority                   = 100
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "Internet"
    destination_port_range     = "0-65535"
    destination_address_prefix = "10.0.0.0/22"


  }

}

resource "azurerm_network_interface_security_group_association" "main-sg" {
  count                     = var.machines
  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.main-sg[count.index].id
}


resource "azurerm_availability_set" "availSet" {
  name                         = "${var.prefix}availSet"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
}

resource "azurerm_lb" "main-lb" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.external.id
  }
}

resource "azurerm_lb_backend_address_pool" "main-lb" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main-lb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "main-lb" {
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.main-lb.id
  name                           = "HTTPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_network_interface_backend_address_pool_association" "main-lb" {
  count                   = var.machines
  backend_address_pool_id = azurerm_lb_backend_address_pool.main-lb.id
  ip_configuration_name   = "internal"
  network_interface_id    = element(azurerm_network_interface.main.*.id, count.index)
}


resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.machines
  name                            = "${var.prefix}-${count.index + 1}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.size
  admin_username                  = var.username
  admin_password                  = var.password
  availability_set_id             = azurerm_availability_set.availSet.id
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "Production"
    "Tag Name"  = "yep I put a tag here"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

}

resource "azurerm_managed_disk" "datadisk" {
  name                 = "datadisk"
  location             = azurerm_resource_group.main.location
  create_option        = "Empty"
  disk_size_gb         = 15
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
}

resource "azurerm_virtual_machine_data_disk_attachment" "datadisk" {
  count              = var.machines
  virtual_machine_id = azurerm_linux_virtual_machine.main[count.index].id
  managed_disk_id    = azurerm_managed_disk.datadisk.id
  lun                = 0
  caching            = "None"
}


