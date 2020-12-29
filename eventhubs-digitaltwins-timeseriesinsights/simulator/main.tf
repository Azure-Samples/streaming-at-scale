resource "azurerm_container_group" "simulator" {
  name                = "aci-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  os_type             = "Linux"

  container {
    name  = "simulator"
    image = "iottelemetrysimulator/azureiot-telemetrysimulator"

    cpu    = "4.0"
    memory = "4.0"
    environment_variables = {
      MessageCount = 0 # run indefinitely
      DeviceIndex  = 0 # starting device number
      DeviceCount  = var.device_count
      DevicePrefix = var.device_prefix
      Interval     = var.interval
      Variables    = <<-EOT
        [
          {"name": "value", "random": true},
          {"name": "moreData00", "random": true},
          {"name": "moreData01", "random": true},
          {"name": "moreData02", "random": true},
          {"name": "moreData03", "random": true},
          {"name": "moreData04", "random": true},
          {"name": "moreData05", "random": true},
          {"name": "moreData06", "random": true},
          {"name": "moreData07", "random": true},
          {"name": "moreData08", "random": true},
          {"name": "moreData09", "random": true},
          {"name": "moreData10", "random": true},
          {"name": "moreData11", "random": true},
          {"name": "moreData12", "random": true},
          {"name": "moreData13", "random": true},
          {"name": "moreData14", "random": true},
          {"name": "moreData15", "random": true},
          {"name": "moreData16", "random": true},
          {"name": "moreData17", "random": true},
          {"name": "moreData18", "random": true},
          {"name": "moreData19", "random": true},
          {"name": "Counter", "min": 0},
          {"name": "type", "values": ["TEMP", "CO2"]}
        ]
        EOT
      Template     = <<-EOT
        {
            "eventId": "$.Guid",
            "complexData": {
                "moreData0": $.moreData00,
                "moreData1": $.moreData01,
                "moreData2": $.moreData02,
                "moreData3": $.moreData03,
                "moreData4": $.moreData04,
                "moreData5": $.moreData05,
                "moreData6": $.moreData06,
                "moreData7": $.moreData07,
                "moreData8": $.moreData08,
                "moreData9": $.moreData09,
                "moreData10": $.moreData10,
                "moreData11": $.moreData11,
                "moreData12": $.moreData12,
                "moreData13": $.moreData13,
                "moreData14": $.moreData14,
                "moreData15": $.moreData15,
                "moreData16": $.moreData16,
                "moreData17": $.moreData17,
                "moreData18": $.moreData18,
                "moreData19": $.moreData19
            },
            "value": $.value,
            "deviceId": "$.DeviceId",
            "deviceSequenceNumber": $.Counter,
            "type": "$.type",
            "createdAt": "$.Time"
        }
        EOT
    }
    secure_environment_variables = {
      IotHubConnectionString = var.iothub_connectionstring
    }

    ports {
      port     = 443
      protocol = "TCP"
    }
  }
}
