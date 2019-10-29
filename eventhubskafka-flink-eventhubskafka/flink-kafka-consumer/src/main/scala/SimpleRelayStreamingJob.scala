import java.time.format.DateTimeFormatter
import java.time.{Instant, ZoneId}
import java.util.Properties

import org.apache.flink.formats.json.JsonNodeDeserializationSchema
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.ObjectMapper
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.node.{ObjectNode, TextNode}
import org.apache.flink.streaming.api.scala._
import org.apache.flink.streaming.connectors.kafka.{FlinkKafkaConsumer011, FlinkKafkaProducer011}
import org.slf4j.LoggerFactory

/**
  * A Flink Streaming Job that relays incoming events.
  *
  */
object SimpleRelayStreamingJob {

  private val LOG = LoggerFactory.getLogger(getClass)

  private final val DATE_FORMAT = DateTimeFormatter.ofPattern( "yyyy-MM-dd'T'HH:mm:ss.SSSX").withZone(ZoneId.of("UTC"))

  def main(args: Array[String]): Unit = {

    // set up the execution environment
    val propertiesIn = new Properties
    val propertiesOut = new Properties
    val env = StreamingJobCommon.createStreamExecutionEnvironment(args, propertiesIn, propertiesOut)

    val topicIn = propertiesIn.remove("topic").asInstanceOf[String]
    if (topicIn == null) throw new IllegalArgumentException("Missing configuration value kafka.topic.in")
    LOG.info("Consuming from Kafka topic: {}", topicIn)

    val topicOut = propertiesOut.remove("topic").asInstanceOf[String]
    if (topicOut == null) throw new IllegalArgumentException("Missing configuration value kafka.topic.out")
    LOG.info("Writing into Kafka topic: {}", topicOut)

    // Create Kafka consumer deserializing from JSON.
    // Flink recommends using Kafka 0.11 consumer as Kafka 1.0 consumer is not stable.
    val kafkaIn = new FlinkKafkaConsumer011[ObjectNode](topicIn, new JsonNodeDeserializationSchema, propertiesIn)

    val mapper = new ObjectMapper
    val kafkaOut = new FlinkKafkaProducer011[ObjectNode](
      topicOut,
      e => mapper.writeValueAsBytes(e),
      propertiesOut
    )

    // Create Flink stream source from Kafka.
    val stream = env.addSource(kafkaIn)

    // Build Flink pipeline.
    stream
      .map(e=> {
         e.set("enqueuedAt", e.get("createdAt"))
         e.set("processedAt", new TextNode(DATE_FORMAT.format(Instant.now)))
        e
      })
      .addSink(kafkaOut)

    // execute program
    env.execute("stateful relay")
  }

}
