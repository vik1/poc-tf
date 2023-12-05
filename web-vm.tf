# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "web-vm-PublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_subnet" "web_subnet" { 
  #count = length(local.app_vm_config)
  name                 = local.subnet_web #local.app_vm_config[count.index]["subnet"]
  resource_group_name  = local.rg_name #azurerm_resource_group.rg[count.index].name #local.app_vm_config[count.index]["resource_group"]
  virtual_network_name = local.vnet_name #azurerm_virtual_network.my_terraform_network[count.index].name #local.app_vm_config[count.index]["virtual_network_name"]
  address_prefixes     = ["${local.subnet_web_addr}"] #["10.0.1.0/24"]
  depends_on = [azurerm_virtual_network.my_terraform_network]
 
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "web-vm-nsg" {
  name                = "web-nsg"
  location            = azurerm_resource_group.rg.location
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
    name                       = "web"
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

# Create network interface
resource "azurerm_network_interface" "web-vm-nic" {
  count = length(local.web_vm_config)  
  name                = "nic-${local.web_vm_config[count.index]["name"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-${local.web_vm_config[count.index]["name"]}"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example1" {
  count = length(local.web_vm_config)   
  network_interface_id      = azurerm_network_interface.web-vm-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.web-vm-nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}



# Create virtual machine
resource "azurerm_linux_virtual_machine" "web-vm" {
  count = length(local.web_vm_config)
  name                  = "${local.web_vm_config[count.index]["name"]}"
  location = local.location_name
  resource_group_name   = local.rg_name 
  network_interface_ids = [azurerm_network_interface.web-vm-nic[count.index].id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "osDisk-${local.web_vm_config[count.index]["name"]}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "hostname"
  admin_username = "vikrant"
  admin_password = "admin@123"
/*
  provisioner "file" {
    source      = "fwd.py"
    destination = "/home/vikrant/fwd.py"
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/home/vikrant/script.sh"
  }

    connection {
    type        = "ssh"
    host        = azurerm_public_ip.my_terraform_public_ip.ip_address # azurerm_network_interface.web-vm-nic[count.index].public_ip_address_id  # Use the private IP address of the VM
    user        = azurerm_linux_virtual_machine.web-vm[count.index].admin_username
    password    = azurerm_linux_virtual_machine.web-vm[count.index].admin_password
    agent       = false
    #private_key = file("~/.ssh/id_rsa")  # Replace with the path to your private key
  }
*/



disable_password_authentication = false  
}

/*
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
*/

resource "azurerm_virtual_machine_extension" "vmext" {
  
    count = length(local.web_vm_config)
    name                    = "test-vmext"
  virtual_machine_id         = azurerm_linux_virtual_machine.web-vm[count.index].id
    #virtual_machine_name = azurerm_public_ip.my_terraform_public_ip.name
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    protected_settings = <<PROT
    {
        "script": "${base64encode(file("script.sh"))}"
    }
    PROT
}