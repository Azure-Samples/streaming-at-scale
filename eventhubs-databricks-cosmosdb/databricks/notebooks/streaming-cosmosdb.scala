import org.apache.spark.sql._
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import org.apache.spark.eventhubs.{ ConnectionStringBuilder, EventHubsConf, EventPosition }
import com.microsoft.azure.cosmosdb.spark._
import com.microsoft.azure.cosmosdb.spark.schema._
import com.microsoft.azure.cosmosdb.spark.config.Config
import com.microsoft.azure.cosmosdb.spark.streaming._

// COMMAND ----------

dbutils.fs.rm("/checkpoints/cosmosdb", true)

// COMMAND ----------

val connectionString = ConnectionStringBuilder(dbutils.secrets.get("MAIN", "EH_CONNSTR"))
  .setEventHubName(dbutils.secrets.get("MAIN", "EH_NAME"))
  .build

val eventHubsConf = EventHubsConf(connectionString)
  //.setStartingPosition(EventPosition.fromStartOfStream)
  
val eventhubs = spark.readStream
  .format("eventhubs")
  .options(eventHubsConf.toMap)
  .load()

// COMMAND ----------

val schema = StructType(
  StructField("eventId", StringType) ::
  StructField("value", StringType) ::
  StructField("type", StringType) ::
  StructField("deviceId", StringType) ::
  StructField("createdAt", StringType) :: Nil)

// COMMAND ----------

val df = eventhubs.select(from_json($"body".cast("string"), schema).as("eventData"), $"*")

// COMMAND ----------

var df2 = df.select($"eventData.*", $"offset", $"sequenceNumber", $"publisher", $"partitionKey") 

// COMMAND ----------

val configMap = Map(
  "Endpoint" -> dbutils.secrets.get("MAIN", "COSMOSDB_URI"),
  "Masterkey" -> dbutils.secrets.get("MAIN", "COSMOSDB_KEY"),
  "Database" -> "streaming",
  "Collection" -> "rawdata",
  "checkpointLocation" -> "/checkpoints/cosmosdb"
)

val cosmosdb = df2.writeStream.format(classOf[CosmosDBSinkProvider].getName).outputMode("append").options(configMap).start()
