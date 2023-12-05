/*
resource "azurerm_public_ip" "web-ip" {
  name                = "web-ip"
  location = local.location_name 
  resource_group_name = local.rg_name 
  allocation_method   = "Static"
  sku = "Standard"
  depends_on = [azurerm_resource_group.rg]
}
*/


resource "azurerm_lb" "web" {
  name                = "web-lb"
  location = local.location_name 
  resource_group_name = local.rg_name 
  sku = "Standard"
  sku_tier = "Regional"
  
  frontend_ip_configuration {
    name                 = "LBPublicIPAddress"
    #public_ip_address_id = azurerm_public_ip.web-ip.id
    subnet_id            = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  #depends_on = [azurerm_windows_virtual_machine.web-vm] 
}

resource "azurerm_lb_backend_address_pool" "web-pool" {
  name = "web-lb-backend-pool"
  loadbalancer_id = azurerm_lb.web.id
}

# Associate the virtual machines with the backend pool

resource "azurerm_lb_probe" "web-probe" {
  name = "web-lb-probe"
  loadbalancer_id = azurerm_lb.web.id
  port = 80
  protocol = "Tcp"
  #request_path = "/"  # Specify the request path
}

resource "azurerm_lb_rule" "web-rule" {
  name                  = "web-lb-rule"
  #resource_group_name = local.rg_name 
  loadbalancer_id       = azurerm_lb.web.id
  #frontend_ip_configuration_id = azurerm_lb.web.frontend_ip_configuration[0].id
  frontend_ip_configuration_name = azurerm_lb.web.frontend_ip_configuration[0].name
  protocol              = "Tcp"
  frontend_port         = 80
  backend_port          = 80
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.web-pool.id]
  probe_id              = azurerm_lb_probe.web-probe.id
  disable_outbound_snat          = true
}


resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count = length(local.web_vm_config)
  network_interface_id    = azurerm_network_interface.web-vm-nic[count.index].id
  ip_configuration_name   = "ipconfig-${local.web_vm_config[count.index]["name"]}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web-pool.id
  #depends_on = [azurerm_virtual_machine.example] #[azurerm_linux_virtual_machine.example]
}


/* ---------------------------
# Azure LB Inbound NAT Rule
resource "azurerm_lb_nat_rule" "web_lb_inbound_nat_rule_80" {
  #count = length(local.web_vm_config)
  name                           = "web-nat-rule-80"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.web.frontend_ip_configuration[0].name  
  resource_group_name            = local.rg_name 
  loadbalancer_id                = azurerm_lb.web.id
}

# Associate LB NAT Rule and VM Network Interface
resource "azurerm_network_interface_nat_rule_association" "web_nic_nat_rule_associate" {
  count = length(local.web_vm_config)
  network_interface_id  = azurerm_network_interface.web-vm-nic[count.index].id
  ip_configuration_name = "ipconfig"   #azurerm_network_interface.web_linuxvm_nic.ip_configuration[0].name 
  nat_rule_id           = azurerm_lb_nat_rule.web_lb_inbound_nat_rule_80.id
}
----------------------------*/

#-------

resource "azurerm_lb" "app" {
  name                = "app-lb"
  location = local.location_name 
  resource_group_name = local.rg_name 
  sku  = "Standard"
  sku_tier = "Regional"

  frontend_ip_configuration {
    name                 = "app-lb-frontend"
    subnet_id            = azurerm_subnet.app_subnet.id
    private_ip_address   = "10.0.1.68"  
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "app-pool" {
  name = "app-lb-backend-pool"
  loadbalancer_id = azurerm_lb.app.id
}

# Associate the virtual machines with the backend pool

resource "azurerm_lb_probe" "app-probe" {
  name = "app-lb-probe"
  loadbalancer_id = azurerm_lb.app.id
  port = 80
  protocol = "Tcp"
  #request_path = "/"  # Specify the request path
}

resource "azurerm_lb_rule" "app-rule" {
  name                  = "app-lb-rule"
  #resource_group_name = local.rg_name 
  loadbalancer_id       = azurerm_lb.app.id
  #frontend_ip_configuration_id = azurerm_lb.web.frontend_ip_configuration[0].id
  frontend_ip_configuration_name = azurerm_lb.app.frontend_ip_configuration[0].name
  protocol              = "Tcp"
  frontend_port         = 80
  backend_port          = 80
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.app-pool.id]
  probe_id              = azurerm_lb_probe.app-probe.id
  disable_outbound_snat          = true
}


resource "azurerm_network_interface_backend_address_pool_association" "app" {
  count = length(local.app_vm_config)
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "ipconfig" #azurerm_network_interface.nic[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.app-pool.id
}

