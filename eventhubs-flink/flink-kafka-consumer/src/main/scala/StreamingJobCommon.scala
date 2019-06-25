import java.time.Instant
import java.time.Instant.now
import java.time.temporal.ChronoUnit
import java.util.Properties

import org.apache.flink.api.common.ExecutionConfig
import org.apache.flink.api.common.functions.ReduceFunction
import org.apache.flink.api.java.utils.ParameterTool
import org.apache.flink.formats.json.JsonNodeDeserializationSchema
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.node.ObjectNode
import org.apache.flink.streaming.api.scala._
import org.apache.flink.streaming.api.scala.function.ProcessAllWindowFunction
import org.apache.flink.streaming.api.windowing.time.Time
import org.apache.flink.streaming.api.windowing.windows.TimeWindow
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer011
import org.apache.flink.util.Collector
import org.slf4j.LoggerFactory

import scala.collection.JavaConverters._

/**
  * A Flink Streaming Job that computes summary statistics on incoming events.
  *
  */
object StreamingJobCommon {

  private val LOG = LoggerFactory.getLogger(getClass)

  def createStreamExecutionEnvironment(args: Array[String], properties: Properties): StreamExecutionEnvironment = {
    val params = ParameterTool.fromArgs(args)

    // set up the execution environment
    val env = StreamExecutionEnvironment.getExecutionEnvironment

    // make parameters available in the web interface, if available
    env.getConfig.setGlobalJobParameters(params)

    // Use kafka.* properties to build kafka connection
    params.toMap.asScala.foreach { case (k, v) => if (k.startsWith("kafka.")) properties.put(k.replace("kafka.", ""), v) }

    // Set Flink task parallelism
    env.setParallelism(params.getInt("parallelism", 1))

    // start a checkpoint every 1000 ms
    env.enableCheckpointing(params.getLong("checkpoint.interval", 1000L))

    env
  }
}
