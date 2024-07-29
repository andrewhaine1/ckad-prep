variable "prefix" {
  default = "kube-cluster"
}

variable "vm_and_nic_count" {
  type    = number
  default = 3
}

# -------------------------------- Resource Group ---------------------------------- #

resource "azurerm_resource_group" "kube_cluster_rg" {
  name     = "rg-${var.prefix}"
  location = "South Africa North"
  lifecycle {
    prevent_destroy = true
  }
}

# -------------------------------- Network ---------------------------------------- #

resource "azurerm_virtual_network" "kube_cluster_network" {
  name                = "${var.prefix}-virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "kube_cluster_subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.kube_cluster_rg.name
  virtual_network_name = azurerm_virtual_network.kube_cluster_network.name
  address_prefixes     = ["10.0.2.0/24"]
  lifecycle {
    prevent_destroy = true
  }
}

# -------------------------- DNS Zones ----------------------------------------------- #

resource "azurerm_dns_zone" "kube_cluster_public_dns_zone" {
  name                = "kubeapps.co.za"
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_dns_a_record" "kube_cluster_public_dns_zone_a_record" {
  name                = "@"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  records             = ["4.221.159.83"]
}

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_store_cname_record" {
  name                = "store"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_timekeeper_cname_record" {
  name                = "timekeeper"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_argocd_cname_record" {
  name                = "argocd"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

output "kube_cluster_public_dns_zone" {
  value = azurerm_dns_zone.kube_cluster_public_dns_zone.name_servers
}

# -------------------------- Cluster nodes ------------------------------------------- #

resource "azurerm_network_interface" "kube_cluster_node_vm_nic" {
  count                 = var.vm_and_nic_count
  name                  = "${var.prefix}-nic-${count.index + 1}"
  location              = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name   = azurerm_resource_group.kube_cluster_rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "${var.prefix}-configuration-${count.index + 1}"
    subnet_id                     = azurerm_subnet.kube_cluster_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "kube_cluster_node" {
  count                 = var.vm_and_nic_count
  name                  = "${var.prefix}-vm-${count.index + 1}"
  location              = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name   = azurerm_resource_group.kube_cluster_rg.name
  network_interface_ids = [azurerm_network_interface.kube_cluster_node_vm_nic[count.index].id]
  vm_size               = "Standard_B2s"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.prefix}-vm-${count.index + 1}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.prefix}-vm-${count.index + 1}"
    admin_username = "kube-admin-a5e5fa54"
    admin_password = "a5e5fa54%dfdd&4d93#b3b9!0c1633e7b797"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  connection {
    host    = "${var.prefix}-vm-${count.index + 1}.sanorth.cloudapp.azure.com"
    user    = "kubeadmin"
    type    = "ssh"
    timeout = "1m"
    agent   = true
  }

  tags = {
    environment = "staging"
  }
}

resource "azurerm_route_table" "kube_cluster_node_route_table" {
  name                          = "${var.prefix}-node-route-table"
  location                      = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name           = azurerm_resource_group.kube_cluster_rg.name
  bgp_route_propagation_enabled = true

  route {
    name                   = "kube-cluster-vm-1"
    address_prefix         = "192.168.154.64/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.kube_cluster_node_vm_nic[0].private_ip_address
  }

  route {
    name                   = "kube-cluster-vm-2"
    address_prefix         = "192.168.241.0/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.kube_cluster_node_vm_nic[1].private_ip_address
  }

  route {
    name                   = "kube-cluster-vm-3"
    address_prefix         = "192.168.247.128/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.kube_cluster_node_vm_nic[2].private_ip_address
  }

  tags = {
    environment = "${var.prefix}"
  }
}

resource "azurerm_subnet_route_table_association" "kube_cluster_node_route_table_association" {
  subnet_id      = azurerm_subnet.kube_cluster_subnet.id
  route_table_id = azurerm_route_table.kube_cluster_node_route_table.id
}

resource "azurerm_network_security_group" "kube_cluster_ssh_network_security_group" {
  name                = "${var.prefix}-ssh-network-security-group"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
}

resource "azurerm_network_security_rule" "kube_cluster_ssh_network_security_group_ssh_rule" {
  name                        = "${var.prefix}-ssh-inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.kube_cluster_rg.name
  network_security_group_name = azurerm_network_security_group.kube_cluster_ssh_network_security_group.name
}

resource "azurerm_network_security_rule" "kube_cluster_ssh_network_security_group_http_rule" {
  name                        = "${var.prefix}-http-inbound"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.kube_cluster_rg.name
  network_security_group_name = azurerm_network_security_group.kube_cluster_ssh_network_security_group.name
}

resource "azurerm_network_security_rule" "kube_cluster_ssh_network_security_group_https_rule" {
  name                        = "${var.prefix}-https-inbound"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.kube_cluster_rg.name
  network_security_group_name = azurerm_network_security_group.kube_cluster_ssh_network_security_group.name
}

resource "azurerm_network_interface_security_group_association" "kube_cluster_ssh_network_security_group_association" {
  network_security_group_id = azurerm_network_security_group.kube_cluster_ssh_network_security_group.id
  network_interface_id      = azurerm_network_interface.kube_cluster_node_vm_nic[0].id
}

resource "azurerm_network_security_group" "kube_cluster_http_network_security_group" {
  name                = "${var.prefix}-http-network-security-group"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
}

resource "azurerm_network_security_rule" "kube_cluster_http_network_security_group_http_rule" {
  name                        = "${var.prefix}-http-inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.kube_cluster_rg.name
  network_security_group_name = azurerm_network_security_group.kube_cluster_http_network_security_group.name
}

resource "azurerm_network_security_rule" "kube_cluster_http_network_security_group_https_rule" {
  name                        = "${var.prefix}-https-inbound"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.kube_cluster_rg.name
  network_security_group_name = azurerm_network_security_group.kube_cluster_http_network_security_group.name
}

resource "azurerm_network_security_rule" "kube_cluster_http_network_security_group_kubeapi_rule" {
  name                        = "${var.prefix}-kubeapi-inbound"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.kube_cluster_rg.name
  network_security_group_name = azurerm_network_security_group.kube_cluster_http_network_security_group.name
}

resource "azurerm_network_interface_security_group_association" "kube_cluster_http_network_security_group_association_vm2" {
  network_security_group_id = azurerm_network_security_group.kube_cluster_http_network_security_group.id
  network_interface_id      = azurerm_network_interface.kube_cluster_node_vm_nic[1].id
}

resource "azurerm_network_interface_security_group_association" "kube_cluster_http_network_security_group_association_vm3" {
  network_security_group_id = azurerm_network_security_group.kube_cluster_http_network_security_group.id
  network_interface_id      = azurerm_network_interface.kube_cluster_node_vm_nic[2].id
}

# -------------------------- Load balancer ------------------------------------------- #
resource "azurerm_public_ip" "kube_cluster_public_ip" {
  name                = "${var.prefix}-load-balancer-public-ip"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_lb" "kube_cluster_lb" {
  name                = "${var.prefix}-load-balancer"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.kube_cluster_public_ip.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_lb_backend_address_pool" "kube_cluster_lb_ssh_backend_address_pool" {
  loadbalancer_id = azurerm_lb.kube_cluster_lb.id
  name            = "${var.prefix}-ssh-backend-address-pool"
}

resource "azurerm_lb_backend_address_pool" "kube_cluster_lb_http_backend_address_pool" {
  loadbalancer_id = azurerm_lb.kube_cluster_lb.id
  name            = "${var.prefix}-http-backend-address-pool"
}

resource "azurerm_lb_backend_address_pool_address" "kube_cluster_lb_ssh_backend_address_pool_address" {
  name                    = "${var.prefix}-vm-1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.kube_cluster_lb_ssh_backend_address_pool.id
  virtual_network_id      = azurerm_virtual_network.kube_cluster_network.id
  ip_address              = azurerm_network_interface.kube_cluster_node_vm_nic[0].private_ip_address
}

resource "azurerm_lb_backend_address_pool_address" "kube_cluster_lb_http_backend_address_pool_address" {
  count                   = var.vm_and_nic_count
  name                    = "${var.prefix}-vm-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.kube_cluster_lb_http_backend_address_pool.id
  virtual_network_id      = azurerm_virtual_network.kube_cluster_network.id
  ip_address              = azurerm_network_interface.kube_cluster_node_vm_nic[count.index].private_ip_address
}

resource "azurerm_lb_nat_rule" "kube_cluster_nat_rule" {
  resource_group_name            = azurerm_resource_group.kube_cluster_rg.name
  loadbalancer_id                = azurerm_lb.kube_cluster_lb.id
  name                           = "SSHAccess"
  protocol                       = "Tcp"
  frontend_port_start            = 222
  frontend_port_end              = 222
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.kube_cluster_lb_ssh_backend_address_pool.id
}

resource "azurerm_lb_nat_rule" "kube_cluster_api_nat_rule" {
  resource_group_name            = azurerm_resource_group.kube_cluster_rg.name
  loadbalancer_id                = azurerm_lb.kube_cluster_lb.id
  name                           = "KubeAPIAccess"
  protocol                       = "Tcp"
  frontend_port_start            = 6443
  frontend_port_end              = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.kube_cluster_lb_ssh_backend_address_pool.id
}

resource "azurerm_lb_probe" "kube_cluster_lb_http_health_probe" {
  loadbalancer_id = azurerm_lb.kube_cluster_lb.id
  name            = "http-health-probe"
  port            = 80
}

resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.kube_cluster_lb.id
  name                           = "HTTPLBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.kube_cluster_lb_http_backend_address_pool.id]
  probe_id                       = azurerm_lb_probe.kube_cluster_lb_http_health_probe.id
}

resource "azurerm_lb_rule" "https_rule" {
  loadbalancer_id                = azurerm_lb.kube_cluster_lb.id
  name                           = "HTTPSLBRule"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.kube_cluster_lb_http_backend_address_pool.id]
  probe_id                       = azurerm_lb_probe.kube_cluster_lb_http_health_probe.id
}

