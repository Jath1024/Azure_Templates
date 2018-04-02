
#Configure Azure Provider and declare all the variables that will be used in Terraform configurations

subscription_id = "7cba3fdf-6b24-495e-9818-42cb0957b235"
client_id = "61e1aa52-abce-4c7c-92e1-3d8f12a16d74"
client_secret = "UdbU/1LyW0BYzm0cdDDr7KM2u978A3cOo/2FrKGGs0g="
tenant_id = "72f988bf-86f1-41af-91ab-2d7cd011db47"
location = "North Europe"
resource_group_name     = "Terraform_Test"
vnet_cidr = "10.5.0.0/16"
subnet1_cidr = "10.5.1.0/24"
subnet2_cidr= "10.5.2.0/24"
subnet_count = 2
vm_username = "thomja"
vm_password = "Bestseller1024!"
vnet_name = "tfvnet"
vm_name = "tfvmjt01"
vm_size = "Standard_DS1_V2"
os_publisher = "Canonical"
os_offer = "UbuntuServer"
os_sku = "16.04-LTS"
os_version = "latest"
