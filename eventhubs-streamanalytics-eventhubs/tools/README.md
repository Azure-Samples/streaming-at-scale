# Testing End-To-End Latency

Get the Event Hub connection string created and displayed during the script execution. If you cannot find it, just grab the execution string for the `Listen` Shared Access Policy for the output eventhub.

From within the `eh-asa-perform` folder run:

```bash
dotnet -- -c "<connection string>"
```

The application will read from the output eventhub and will measure latency (difference from Enqueued and Processed time) for each batch of recevied messages.
