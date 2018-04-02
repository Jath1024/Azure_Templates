
variable subscription_id {}
variable client_id {}
variable client_secret {}
variable tenant_id {}
variable location {}
variable resource_group_name {}
variable vnet_cidr {}
variable subnet1_cidr {}
variable subnet2_cidr {}
variable subnet_count {}
variable vm_username {}
variable vm_password {}
variable vnet_name {}
variable vm_name {}
variable vm_size {}
variable os_publisher {}
variable os_offer {}
variable os_sku {}
variable os_version {}

provider "azurerm" {
    version = "~> 1.3"
    subscription_id = "${var.subscription_id}"
    client_id = "${var.client_id}"
    client_secret = "${var.client_secret}"
    tenant_id = "${var.tenant_id}"
}

resource "azurerm_resource_group" "tfrg" {
    name    = "${var.resource_group_name}"
    location = "${var.location}"
}

resource "azurerm_virtual_network" "tfnetwork" {
    name = "terraform_vnet"
    address_space = ["${var.vnet_cidr}"]
    location = "${var.location}"
    resource_group_name = "${var.resource_group_name}"
#    subnet {
#        count = "${var.subnet_count}"
#        name = "${terraform_vnet_subnet1}"
#        #address_prefix = "${var.subnet1_cidr}"
#        address_prefix = "${cidrsubnet(terraform_vnet,24, count.index)}"
#    }

#    subnet {
#        name = "${terraform_vnet_subnet2}"
#        #address_prefix = "${var.subnet2_cidr}"
#        address_prefix = "${cidrsubnet(var.terraform_vnet,24,2)}"
#    }
}

#resource "azurerm_subnet" "tfsubnet" {
#    count = "${var.subnet_count}"
#    name = "${terraform_subnet[count.index]}"
#    resource_group_name = "${var.resource_group_name}"
#    virtual_network_name = "${azurerm_virtual_network.tfnetwork.name}"
#    address_prefix = "${cidrsubnet(var.vnet_cidr, 24, count.index + 1)}"
#}

resource "azurerm_subnet" "tfsubnet01" {
    name = "terraform_subnet01"
    resource_group_name = "${var.resource_group_name}"
    virtual_network_name = "${azurerm_virtual_network.tfnetwork.name}"
    address_prefix = "${var.subnet1_cidr}"
}

resource "azurerm_subnet" "tfsubnet02" {
    name = "terraform_subnet02"
    resource_group_name = "${var.resource_group_name}"
    virtual_network_name = "${azurerm_virtual_network.tfnetwork.name}"
    address_prefix = "${var.subnet2_cidr}"
}

resource "azurerm_managed_disk" "tfmd" {
    name = "tfvmdisks"
    location = "${var.location}"
    resource_group_name = "${var.resource_group_name}"
    storage_account_type = "Standard_LRS"
    create_option = "Empty"
    disk_size_gb = "1024"
}

resource "azurerm_network_interface" "tfnic" {
    name = "tfvmnic"
    location = "${var.location}"
    resource_group_name = "${var.resource_group_name}"

    ip_configuration {
        name = "tfnicip"
        subnet_id = "${azurerm_subnet.tfsubnet01.id}"
        private_ip_address_allocation = "dynamic"
    }
}

resource "azurerm_virtual_machine" "tfvm" {
    name = "${var.vm_name}"
    location = "${var.location}"
    resource_group_name = "${var.resource_group_name}"
    network_interface_ids = ["${azurerm_network_interface.tfnic.id}"]
    vm_size = "${var.vm_size}"
    delete_os_disk_on_termination = "true"
    delete_data_disks_on_termination = "true"

    storage_image_reference {
        publisher = "${var.os_publisher}"
        offer = "${var.os_offer}"
        sku = "${var.os_sku}"
        version = "latest"
    }

    storage_os_disk {
        name = "${var.vm_name}-osdisk"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
    }
    
    storage_data_disk {
        name = "${var.vm_name}-datadisk01"
        managed_disk_type = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "1024"
    }
    
    os_profile {
        computer_name = "tfvm01"
        admin_username = "${var.vm_username}"
        admin_password = "${var.vm_password}"
    }
}