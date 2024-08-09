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

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_eshop_cname_record" {
  name                = "eshop"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_eshop_apigwws_cname_record" {
  name                = "apigwws"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_eshop_identity_cname_record" {
  name                = "eshop-identity"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_rancher_cname_record" {
  name                = "rancher"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

resource "azurerm_dns_cname_record" "kube_cluster_public_dns_zone_dash_cname_record" {
  name                = "dashboard"
  zone_name           = azurerm_dns_zone.kube_cluster_public_dns_zone.name
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  ttl                 = 300
  record              = azurerm_dns_zone.kube_cluster_public_dns_zone.name
}

resource "azurerm_private_dns_zone" "kube_cluster_private_dns_zone" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
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
    admin_username = var.kube_cluster_node_admin_username
    admin_password = var.kube_cluster_node_admin_password
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
    address_prefix         = "10.1.154.64/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.kube_cluster_node_vm_nic[0].private_ip_address
  }

  route {
    name                   = "kube-cluster-vm-2"
    address_prefix         = "10.1.241.0/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.kube_cluster_node_vm_nic[1].private_ip_address
  }

  route {
    name                   = "kube-cluster-vm-3"
    address_prefix         = "10.1.247.128/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.kube_cluster_node_vm_nic[2].private_ip_address
  }

  lifecycle {
    ignore_changes = []
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

# --------------------------------------- Admin VM ------------------------------------------- #
resource "azurerm_network_interface" "kube_cluster_admin_vm_nic" {
  name                  = "${var.prefix}-admin-vm-nic-1"
  location              = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name   = azurerm_resource_group.kube_cluster_rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "${var.prefix}-admin-vm-configuration"
    subnet_id                     = azurerm_subnet.kube_cluster_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "kube_cluster_admin_vm" {
  name                  = "${var.prefix}-admin-vm-1"
  location              = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name   = azurerm_resource_group.kube_cluster_rg.name
  network_interface_ids = [azurerm_network_interface.kube_cluster_admin_vm_nic.id]
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
    name              = "${var.prefix}-admin-vm-1-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.prefix}-admin-vm-1-osdisk1"
    admin_username = var.kube_cluster_admin_vm_admin_username
    admin_password = var.kube_cluster_admin_vm_admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  connection {
    host    = "${var.prefix}-admin-vm-1.sanorth.cloudapp.azure.com"
    user    = "kubeadmin"
    type    = "ssh"
    timeout = "1m"
    agent   = true
  }

  tags = {
    environment = "staging"
  }
}

resource "azurerm_network_interface_security_group_association" "kube_cluster_admin_vm_ssh_network_security_group_association" {
  network_security_group_id = azurerm_network_security_group.kube_cluster_ssh_network_security_group.id
  network_interface_id      = azurerm_network_interface.kube_cluster_admin_vm_nic.id
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

resource "azurerm_lb_backend_address_pool" "kube_cluster_lb_admin_ssh_backend_address_pool" {
  loadbalancer_id = azurerm_lb.kube_cluster_lb.id
  name            = "${var.prefix}-admin-ssh-backend-address-pool"
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

resource "azurerm_lb_backend_address_pool_address" "kube_cluster_lb_admin_ssh_backend_address_pool_address" {
  name                    = "${var.prefix}-admin-vm-1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.kube_cluster_lb_admin_ssh_backend_address_pool.id
  virtual_network_id      = azurerm_virtual_network.kube_cluster_network.id
  ip_address              = azurerm_network_interface.kube_cluster_admin_vm_nic.private_ip_address
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

resource "azurerm_lb_nat_rule" "kube_cluster_admin_ssh_nat_rule" {
  resource_group_name            = azurerm_resource_group.kube_cluster_rg.name
  loadbalancer_id                = azurerm_lb.kube_cluster_lb.id
  name                           = "AdminSSHAccess"
  protocol                       = "Tcp"
  frontend_port_start            = 223
  frontend_port_end              = 223
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.kube_cluster_lb_admin_ssh_backend_address_pool.id
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

# -------------------------- VM Start Stop ------------------------------------------- #
resource "azurerm_automation_account" "kube_cluster_automation_account" {
  name                = "${var.prefix}-automation-account"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  sku_name            = "Basic"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_storage_account" "kube_cluster_start_stop_function_storage_account" {
  name                     = "ssfunctionsa"
  resource_group_name      = azurerm_resource_group.kube_cluster_rg.name
  location                 = azurerm_resource_group.kube_cluster_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "kube_cluster_start_stop_function_sp" {
  name                = "${var.prefix}-ss-app-service-plan"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "kube_cluster_start_stop_function_app" {
  name                       = "${var.prefix}-ss-function"
  location                   = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name        = azurerm_resource_group.kube_cluster_rg.name
  service_plan_id            = azurerm_service_plan.kube_cluster_start_stop_function_sp.id
  storage_account_name       = azurerm_storage_account.kube_cluster_start_stop_function_storage_account.name
  storage_account_access_key = azurerm_storage_account.kube_cluster_start_stop_function_storage_account.primary_access_key

  site_config {}
}

resource "azurerm_log_analytics_workspace" "kube_cluster_start_stop_law" {
  name                = "${var.prefix}-ss-law"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "kube_cluster_start_stop_ai" {
  name                = "${var.prefix}-ss-app-insights"
  location            = azurerm_resource_group.kube_cluster_rg.location
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  workspace_id        = azurerm_log_analytics_workspace.kube_cluster_start_stop_law.id
  application_type    = "other"
}

# -------------------------- Container registry ------------------------------------------- #
resource "azurerm_container_registry" "kube_cluster_acr" {
  name                = "kubeclusteracr"
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  location            = azurerm_resource_group.kube_cluster_rg.location
  sku                 = "Premium"
  admin_enabled       = true

  public_network_access_enabled = false
}

# Create azure private endpoint
resource "azurerm_private_endpoint" "kube_cluster_acr_private_endpoint" {
  name                = "${var.prefix}-acr-private-endpoint"
  resource_group_name = azurerm_resource_group.kube_cluster_rg.name
  location            = azurerm_resource_group.kube_cluster_rg.location
  subnet_id           = azurerm_subnet.kube_cluster_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-acr-service-connection"
    private_connection_resource_id = azurerm_container_registry.kube_cluster_acr.id
    is_manual_connection           = false
    subresource_names = [
      "registry"
    ]
  }

  private_dns_zone_group {
    name = "${var.prefix}-acr-private-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.kube_cluster_private_dns_zone.id
    ]
  }

  depends_on = [
    azurerm_virtual_network.kube_cluster_network,
    azurerm_subnet.kube_cluster_subnet,
    azurerm_container_registry.kube_cluster_acr
  ]
}

# Create azure private dns zone virtual network link for acr private endpoint vnet
resource "azurerm_private_dns_zone_virtual_network_link" "kube_cluster_acr_private_dns_zone_virtual_network_link" {
  name                  = "${var.prefix}-private-dns-zone-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.kube_cluster_private_dns_zone.name
  resource_group_name   = azurerm_resource_group.kube_cluster_rg.name
  virtual_network_id    = azurerm_virtual_network.kube_cluster_network.id
}
