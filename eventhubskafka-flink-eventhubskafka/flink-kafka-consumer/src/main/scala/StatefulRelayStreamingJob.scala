package com.microsoft.samples.flink

import com.microsoft.samples.flink.data.SampleRecord
import com.microsoft.samples.flink.utils.JsonMapperSchema
import org.apache.flink.api.java.utils.ParameterTool
import org.apache.flink.streaming.api.datastream
import org.apache.flink.streaming.api.datastream.{DataStreamSource, SingleOutputStreamOperator}
import org.apache.flink.streaming.api.scala._
import org.apache.flink.streaming.api.windowing.windows.GlobalWindow
import org.apache.flink.util.Collector
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.slf4j.LoggerFactory

/**
 * A Flink Streaming Job that applies a sliding window on incoming events.
 *
 */
object StatefulRelayStreamingJob {

  private val LOG = LoggerFactory.getLogger(getClass)

  def main(args: Array[String]): Unit = {

    val params = ParameterTool.fromArgs(args)

    val env = StreamingJobCommon.createStreamExecutionEnvironment(params)
    val schema = new JsonMapperSchema(classOf[SampleRecord])
    val kafkaIn = StreamingJobCommon.createKafkaConsumer(params, schema)
    val schema2 = new JsonMapperSchema(classOf[EnrichedRecord])
    val kafkaOut = StreamingJobCommon.createKafkaProducer(params, schema2)

    // Create Flink stream source from Kafka.
    val stream = env.addSource(kafkaIn)

    // Build Flink pipeline.
    stream
      // Group events by device (aligned with Kafka partitions)
      .map(_.value)
      .keyBy(_.deviceId)
      // Apply a function on each pair of events (sliding window of 2 events)
      .countWindow(2, 1)
      .apply((_, _, input, out: Collector[EnrichedRecord]) => {
        val it = input.iterator
        if (it.hasNext) {
          var e1 = it.next()
          if (it.hasNext) {
            val e2 = it.next()
            val result = EnrichedRecord(e2, Some(e1.deviceSequenceNumber))
            out.collect(result)
          }
        }
      })
      .keyBy(_.toString)
      .addSink(kafkaOut)

    // execute program
    env.execute("stateful relay")
  }

  case class EnrichedRecord(
                             record: SampleRecord,
                             previousSequenceNumber: Option[Long]
                           )

}
