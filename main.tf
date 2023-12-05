# main.tf

locals {
  app_vm_config = jsondecode(file(var.vm_config_path))["app_vms"] 
  web_vm_config = jsondecode(file(var.vm_config_path))["web_vms"] 
  rg_name = jsondecode(file(var.vm_config_path))["resource_group"]
  location_name = jsondecode(file(var.vm_config_path))["location"]
  vnet_name = jsondecode(file(var.vm_config_path))["virtual_network"]
  vnet_addr = jsondecode(file(var.vm_config_path))["vnet_address_space"]
  subnet_app = jsondecode(file(var.vm_config_path))["subnet_app"]
  subnet_app_addr = jsondecode(file(var.vm_config_path))["subnet_app_cidr"]
  subnet_web = jsondecode(file(var.vm_config_path))["subnet_web"]
  subnet_web_addr = jsondecode(file(var.vm_config_path))["subnet_web_cidr"]
}

resource "azurerm_resource_group" "rg" {
  #count = length(local.app_vm_config)
  location = local.location_name #local.app_vm_config["location"] #"East US" 
  name     = local.rg_name #local.app_vm_config["resource_group"] #"my-resource-group"
}
/*
resource "azurerm_virtual_machine" "example" {
  
  count = length(local.web_vm_config)
  name                = local.web_vm_config[count.index]["name"]
  location = "West US" #local.location_name
  resource_group_name = local.rg_name 
  vm_size                = local.web_vm_config[count.index]["vm_size"]
  #admin_username = local.web_vm_config[count.index]["admin_username"]
  #admin_password = local.web_vm_config[count.index]["admin_password"]
  network_interface_ids = [azurerm_network_interface.web-nic.id] #[azurerm_network_interface.web-nic[count.index].id,]



 // os_disk {
 //   caching              = "ReadWrite"
 //   storage_account_type = "Standard_LRS"
 // }
 

  storage_image_reference { #source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "web-1"
    admin_username = local.web_vm_config[count.index]["admin_username"]
    admin_password = local.web_vm_config[count.index]["admin_password"]
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  #disable_password_authentication = false

  depends_on = [azurerm_network_interface.web-nic,null_resource.delay_azurerm_network_interface]
}
*/

resource "azurerm_windows_virtual_machine" "vmi" {
  count = length(local.app_vm_config)

  name                  = local.app_vm_config[count.index]["name"]
  location = local.location_name
  #location              = local.app_vm_config[count.index]["location"]
  resource_group_name   = local.rg_name #azurerm_resource_group.rg[count.index].name #local.app_vm_config[count.index]["resource_group"]
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  admin_username = local.app_vm_config[count.index]["admin_username"]
  admin_password = local.app_vm_config[count.index]["admin_password"]
  size = local.app_vm_config[count.index]["vm_size"]

  os_disk {
    name              = "os-disk-${local.app_vm_config[count.index]["name"]}"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

}

# Install IIS web server to the virtual machine
resource "azurerm_virtual_machine_extension" "web_server_install" {
  count = length(local.app_vm_config)
  name                       = "${local.app_vm_config[count.index]["name"]}-wsi"
  virtual_machine_id         = azurerm_windows_virtual_machine.vmi[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeManagementTools && powershell -ExecutionPolicy Unrestricted Add-Content -Path \"C:\\inetpub\\wwwroot\\iisstart.htm\" -Value $(\"Hello World from \" + $env:computername)"
    }
  SETTINGS
}

# Create public IPs
/*
resource "azurerm_public_ip" "my_terraform_public_ip" {
  count = length(local.app_vm_config)
  name                = "${local.app_vm_config[count.index]["name"]}-public-ip"
  location = local.location_name
  #location            = local.app_vm_config[count.index]["location"]
  resource_group_name = local.rg_name #azurerm_resource_group.rg[count.index].name #local.app_vm_config[count.index]["resource_group"]
  allocation_method   = "Static"
  sku = "Standard"
  depends_on = [azurerm_resource_group.rg]
}
*/



# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  #count = length(local.app_vm_config)
  name                = local.vnet_name #local.app_vm_config[count.index]["virtual_network"]
  address_space       = ["${local.vnet_addr}"] #["${local.app_vm_config[count.index]["vnet_address_space"]}"] #["10.0.0.0/16"]
  location = local.location_name
  #location            = local.app_vm_config[count.index]["location"] #"East US"
  resource_group_name =  local.rg_name #azurerm_resource_group.rg[count.index].name #"my-resource-group"
  depends_on = [azurerm_resource_group.rg]
}

# Create subnet
resource "azurerm_subnet" "app_subnet" { 
  #count = length(local.app_vm_config)
  name                 = local.subnet_app #local.app_vm_config[count.index]["subnet"]
  resource_group_name  = local.rg_name #azurerm_resource_group.rg[count.index].name #local.app_vm_config[count.index]["resource_group"]
  virtual_network_name = local.vnet_name #azurerm_virtual_network.my_terraform_network[count.index].name #local.app_vm_config[count.index]["virtual_network_name"]
  address_prefixes     = ["${local.subnet_app_addr}"] #["10.0.1.0/24"]
  depends_on = [azurerm_virtual_network.my_terraform_network]
 
}

/*
resource "null_resource" "delay_subnet" {
  provisioner "local-exec" {
    command = "sleep 0.1"
  }

  triggers = {
    "before" = "${azurerm_subnet.app_subnet.id}"
  }
}
*/

# Create Network Security Group and rules
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "vm-nsg"
  location            = local.location_name
  resource_group_name = local.rg_name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [azurerm_resource_group.rg]
}


/*
resource "null_resource" "delay_azurerm_network_interface" { 
  provisioner "local-exec" {
    command = "sleep 0.1"
  }

  triggers = {
    "before" = "${azurerm_network_interface.web-nic.id}"
  }
}
*/

resource "azurerm_network_interface" "nic" {
  count = length(local.app_vm_config)

  name                = "nic-${local.app_vm_config[count.index]["name"]}"
  location = local.location_name
  resource_group_name = local.rg_name #local.app_vm_config[count.index]["resource_group"]

  ip_configuration {
    name                          = "ipconfig" #"ipconfig-${local.app_vm_config[count.index]["name"]}"
    #subnet_id                     = element(local.app_vm_config, count.index)["subnet_id"]
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip[count.index].id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  count = length(local.app_vm_config)
  network_interface_id      =  azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}
