data "archive_file" "source_code" {
  type        = "zip"
  source_dir  = var.source_path
  output_path = "${local.build}/data-${sha1(var.source_path)}.zip"
  excludes    = ["log.txt"]
}

locals {
  build      = abspath("target")
  image_name = "generator"
}

resource "null_resource" "container_image" {
  triggers = {
    registry = var.container_registry_login_server
    src_hash = data.archive_file.source_code.output_sha
  }

  provisioner "local-exec" {
    command     = "az acr build --registry ${var.container_registry_name} --image ${local.image_name}:latest . > log.txt"
    working_dir = var.source_path
  }
}

resource "azurerm_container_group" "simulator" {
  name                = "aci-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  os_type             = "Linux"

  image_registry_credential {
    username = var.container_registry_admin_username
    password = var.container_registry_admin_password
    server   = var.container_registry_login_server
  }

  container {
    name   = "simulator"
    image  = "${var.container_registry_login_server}/${local.image_name}"
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
