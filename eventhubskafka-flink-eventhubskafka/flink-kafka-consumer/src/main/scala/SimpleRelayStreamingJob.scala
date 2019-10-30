package com.microsoft.samples.flink

import java.time.Instant

import com.microsoft.samples.flink.StreamingJobCommon.createKafkaConsumer
import com.microsoft.samples.flink.data.SampleRecord
import com.microsoft.samples.flink.utils.JsonMapperSchema
import org.apache.flink.api.java.utils.ParameterTool
import org.apache.flink.streaming.api.scala._
import org.slf4j.LoggerFactory

/**
 * A Flink Streaming Job that relays incoming events.
 *
 */
object SimpleRelayStreamingJob {

  private val LOG = LoggerFactory.getLogger(getClass)

  def main(args: Array[String]): Unit = {

    val params = ParameterTool.fromArgs(args)

    val env = StreamingJobCommon.createStreamExecutionEnvironment(params)
    val schema = new JsonMapperSchema(classOf[SampleRecord])
    val kafkaIn = StreamingJobCommon.createKafkaConsumer(params, schema)
    val kafkaOut = StreamingJobCommon.createKafkaProducer(params, schema)

    // Create Flink stream source from Kafka.
    val stream = env.addSource(kafkaIn)

    // Build Flink pipeline.
    stream
      .map(e => {
        e.enqueuedAt = e.createdAt // TODO use actual Kafka enqueued time
        e.processedAt = Instant.now
        e
      })
      .addSink(kafkaOut)

    // execute program
    env.execute("simple relay")
  }


}
