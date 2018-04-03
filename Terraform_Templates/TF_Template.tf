#########################
# PROVIDERS
#########################

provider "azurerm" {
    access_key = "${var.azure_access_key}"
    secret_key = "${var.azure_secret_key}"
    region     = "uksouth"
}

#########################
# RESOURCES
#########################

resource "azurerm_resource_group" "network" {
    name        = "production"
    location    = "UK West"
}

# Create virtual network and subnets
resource "azurerm_virtual_network" "network" {
    name                = "production-network"
    address_space       = ["10.0.0.0/16"]
    location            = "${azurerm_resource_group.network.location}"
    resource_group_name = "${azurerm_resource_group.network.name}"

    subnet{
        name            = "subnet1"
        address_prefix  = "10.0.1.0/24"
    }
    subnet{
        name            = "subnet2"
        address_prefix  = "10.0.2.0/24"
    }
    subnet{
        name            = "subnet3"
        address_prefix  = "10.0.3.0/24"
    }
}