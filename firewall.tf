
# Create subnet
resource "azurerm_subnet" "AzureFirewallSubnet" {
  #count = length(local.app_vm_config)
  name                 = "AzureFirewallSubnet"
  resource_group_name  = local.rg_name #azurerm_resource_group.rg[count.index].name #local.app_vm_config[count.index]["resource_group"]
  virtual_network_name = local.vnet_name #azurerm_virtual_network.my_terraform_network[count.index].name #local.app_vm_config[count.index]["virtual_network_name"]
  address_prefixes     = ["10.0.2.0/26"]
  depends_on = [azurerm_virtual_network.my_terraform_network]
}



resource "azurerm_public_ip" "pip_azfw" {
  name                = "pip-azfw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "azfw_policy" {
  name                = "example-fwpolicy"
  resource_group_name = local.rg_name
  location            = local.location_name
  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_firewall" "fw" {
  name                = "azfw"
  location            = local.location_name
  resource_group_name = local.rg_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.AzureFirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.pip_azfw.id
  }
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
}

resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "example-fwpolicy-rcg"
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
  priority           = 500
  application_rule_collection {
    name     = "app_rule_collection1"
    priority = 500
    action   = "Deny"
    rule {
      name = "app_rule_collection1_rule1"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["${local.subnet_app_addr}"]
      destination_fqdns = ["*.microsoft.com"]
    }
  }


  nat_rule_collection {
    name     = "nat_rule_collection1"
    priority = 300
    action   = "Dnat"
    rule {
      name                = "nat_rule_collection1_rule1"
      protocols           = ["TCP", "UDP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.pip_azfw.ip_address
      destination_ports   = ["80"]
      translated_address  = azurerm_lb.web.frontend_ip_configuration[0].private_ip_address
      translated_port     = "80"
    }
  }
}


/*
  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Deny"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["10.0.0.1"]
      destination_addresses = ["192.168.1.1", "192.168.1.2"]
      destination_ports     = ["80", "1000-2000"]
    }
  }
*/