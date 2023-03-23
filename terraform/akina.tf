resource "azurerm_subnet" "akina" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.nixos.name
  virtual_network_name = azurerm_virtual_network.nixos.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "akina" {
  name                = "akina-public-ip"
  resource_group_name = azurerm_resource_group.nixos.name
  location            = azurerm_resource_group.nixos.location
  allocation_method   = "Static"

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_interface" "akina" {
  name                = "akina-nic"
  location            = azurerm_resource_group.nixos.location
  resource_group_name = azurerm_resource_group.nixos.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.akina.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.akina.id
  }
}

resource "azurerm_linux_virtual_machine" "akina" {
  name                            = "akina-machine"
  resource_group_name             = azurerm_resource_group.nixos.name
  location                        = azurerm_resource_group.nixos.location
  size                            = "Standard_B1ls"
  admin_username                  = "elxreno"
  admin_password                  = "NotWorkingPassword!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.akina.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 20 # ~1.8 GB will be used by bootstrapped system
  }

  source_image_id = azurerm_image.nixos-x86_64-image.id
}