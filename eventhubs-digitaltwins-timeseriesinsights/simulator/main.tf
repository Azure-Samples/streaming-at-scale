resource "azurerm_container_registry" "main" {
  name                = "acr${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Basic"
  admin_enabled       = true
}

data "archive_file" "source_code" {
  type        = "zip"
  source_dir  = var.source_path
  output_path = "${local.build}/data-${sha1(var.source_path)}.zip"
}

locals {
  build = abspath("target")
  image_name = "generator"
}

resource "null_resource" "container_image" {
  triggers = {
    src_hash = data.archive_file.source_code.output_sha
  }

  provisioner "local-exec" {
    command     = "az acr build --registry ${azurerm_container_registry.main.name} --image ${local.image_name}:latest . > log.txt"
    working_dir = var.source_path
  }
}

resource "azurerm_container_group" "simulator" {
  name                = "simulator"
  location            = var.location
  resource_group_name = var.resource_group
  os_type             = "Linux"
  ip_address_type     = "Public"
  restart_policy      = "Never"

  image_registry_credential {
    username = azurerm_container_registry.main.admin_username
    password = azurerm_container_registry.main.admin_password
    server   = azurerm_container_registry.main.login_server
  }

  container {
    name   = "simulator"
    image  = "${azurerm_container_registry.main.login_server}/${local.image_name}"
    cpu    = "4.0"
    memory = "4.0"
    environment_variables = {
      EXECUTORS                = 2
      OUTPUT_FORMAT            = "eventhubs"
      OUTPUT_OPTIONS           = "{}"
      EVENTS_PER_SECOND        = var.events_per_second
      DUPLICATE_EVERY_N_EVENTS = var.duplicate_every_n_events
    }
    secure_environment_variables = {
      SECURE_OUTPUT_OPTIONS = "{\"eventhubs.connectionstring\":\"${var.eventhub_connectionstring}\"}"
    }

    ports {
      port     = 443
      protocol = "TCP"
    }
  }

  depends_on = [
    null_resource.container_image,
  ]
}
