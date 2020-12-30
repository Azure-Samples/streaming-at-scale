locals {
  image_name = "digital-twins-explorer"
}

resource "null_resource" "container_image" {
  triggers = {
    registry        = var.container_registry_name
    image_name      = local.image_name
    source_location = path.module
  }

  provisioner "local-exec" {
    command = "az acr build -r ${self.triggers.registry} -t ${self.triggers.image_name} ${self.triggers.source_location}"
  }
}

resource "azurerm_storage_account" "main" {
  name                     = "st${var.basename}"
  location                 = var.location
  resource_group_name      = var.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_container_group" "main" {
  name                = "aci-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  os_type             = "Linux"
  restart_policy      = "Never"

  image_registry_credential {
    username = var.container_registry_admin_username
    password = var.container_registry_admin_password
    server   = var.container_registry_login_server
  }

  container {
    name   = "explorer"
    image  = "${var.container_registry_login_server}/${local.image_name}:latest"
    cpu    = "4.0"
    memory = "4.0"
    ports {
      port     = 80
      protocol = "TCP"
    }
  }
  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    null_resource.container_image,
  ]
}

resource "azurerm_role_assignment" "aci" {
  scope                = var.digital_twins_instance_resource_id
  role_definition_name = "Azure Digital Twins Data Reader"
  principal_id         = azurerm_container_group.main.identity.0.principal_id
}
