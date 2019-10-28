import java.util.Properties

import org.apache.flink.formats.json.JsonNodeDeserializationSchema
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.ObjectMapper
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.node.ObjectNode
import org.apache.flink.streaming.api.scala._
import org.apache.flink.streaming.connectors.kafka.{FlinkKafkaConsumer011, FlinkKafkaProducer011}
import org.apache.flink.util.Collector
import org.slf4j.LoggerFactory

/**
  * A Flink Streaming Job that computes summary statistics on incoming events.
  *
  */
object StatefulRelayStreamingJob {

  private val LOG = LoggerFactory.getLogger(getClass)

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
      // Group events by device (aligned with Kafka partitions)
      .keyBy(e => e.get("deviceId").textValue)
      // Apply a function on each pair of events (sliding window of 2 events)
      .countWindow(size = 2, slide = 1)
      .apply((_, _, input, out: Collector[ObjectNode]) => {
        val it = input.iterator
        if (it.hasNext) {
          var e1 = it.next()
          if (it.hasNext) {
            val e2 = it.next()
            e2.set("previousEventNumber", e1.get("eventNumber"))
            e1 = e2
          }
          out.collect(e1)
        }
      })
      .keyBy(e => e.get("deviceId").textValue)
      .addSink(kafkaOut)

    // execute program
    env.execute("stateful relay")
  }

}
