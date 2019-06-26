import java.time.Instant
import java.time.Instant.now
import java.time.temporal.ChronoUnit
import java.util
import java.util.Properties

import org.apache.flink.api.common.ExecutionConfig
import org.apache.flink.api.common.functions.{ReduceFunction, RichFlatMapFunction}
import org.apache.flink.api.common.state.{ValueState, ValueStateDescriptor}
import org.apache.flink.api.java.utils.ParameterTool
import org.apache.flink.configuration.Configuration
import org.apache.flink.formats.json.JsonNodeDeserializationSchema
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.node.ObjectNode
import org.apache.flink.streaming.api.scala._
import org.apache.flink.streaming.api.scala.function.ProcessAllWindowFunction
import org.apache.flink.streaming.api.windowing.time.Time
import org.apache.flink.streaming.api.windowing.windows.TimeWindow
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer011
import org.apache.flink.util.Collector
import org.slf4j.LoggerFactory

/**
  * A Flink Streaming Job that computes summary statistics on incoming events.
  *
  */
object ConsistencyCheckerStreamingJob {

  private val LOG = LoggerFactory.getLogger(getClass)

  def main(args: Array[String]): Unit = {

    // set up the execution environment
    val properties = new Properties
    val env = StreamingJobCommon.createStreamExecutionEnvironment(args, properties)

    val topic = properties.remove("topic").asInstanceOf[String]
    if (topic == null) throw new IllegalArgumentException("Missing configuration value kafka.topic")
    LOG.info("Consuming from Kafka topic: {}", topic)

    // get aggregation interval, e.g. every 1 second
    val aggregateMs = getAggregateMs(env.getConfig)

    // Create Kafka consumer deserializing from JSON.
    // Flink recommends using Kafka 0.11 consumer as Kafka 1.0 consumer is not stable.
    val kafka = new FlinkKafkaConsumer011[ObjectNode](topic, new JsonNodeDeserializationSchema, properties)
    kafka.setStartFromLatest()

    // Create Flink stream source from Kafka.
    val stream = env.addSource(kafka)

    // Build Flink pipeline.
    stream
      // Group events by device (aligned with Kafka partitions)
      .keyBy(e => e.get("deviceId"))
      .flatMap(new DuplicateFilter[ObjectNode](e => e.get("eventId").textValue))
      .keyBy(e => e.get("deviceId").textValue)
      // Apply a function on each pair of events (sliding window of 2 events)
      .countWindow(size = 2, slide = 1)
      .apply((_, _, input, out: Collector[EventStats]) => {
        val it = input.iterator
        if (it.hasNext) {
          val e1 = it.next()
          if (it.hasNext) {
            val e2 = it.next()
            // Compute difference in eventNumber between subsequent events as seen by stateful relay.
            // Expected to always equal 1.
            var eventNumberDelta2: Option[Long] = Option.empty
            if (e2.get("previousEventNumber") != null) {
              eventNumberDelta2 = Some(e2.get("eventNumber").longValue - e2.get("previousEventNumber").longValue)
            }
            // Compute difference in eventNumber between subsequent events. Expected to always equal 1,
            // unless events are lost or duplicated upstream.
            val eventNumberDelta = e2.get("eventNumber").longValue - e1.get("eventNumber").longValue
            if (eventNumberDelta != 1) {
              LOG.info(s"Non-consecutive events [$e1] [$e2]")
            }
            // Compute event latency ('age' = difference between wallclock time and event time)
            val eventAge = ChronoUnit.MILLIS.between(Instant.parse(e2.get("createdAt").textValue), now)
            // Build a structure for reduce function, tracking eventNumberDeltaCounts and eventAge value
            out.collect(EventStats(Map((eventNumberDelta2, eventNumberDelta) -> 1L), eventAge))
          }
        }
      })
      // Now apply a time window to report metrics periodically
      .timeWindowAll(Time.milliseconds(aggregateMs))
      .reduce(
        // Merge data as we go, for memory-efficient processing
        preAggregator = new ComputeEventRatePreAggregator,
        // Compute summary statistics
        windowFunction = new ComputeEventRateProcessFunction
      )
      .setParallelism(1) // applies to reduce() operator only

      .print

    // execute program
    env.execute("Sample Kafka Consumer - event counter by second")
  }

  // Data structure to collect event statistics during map-reduce processing
  case class EventStats(eventNumberDeltaCounts: Map[(Option[Long], Long), Long], sumOfLatencies: Long)

  // Helper to retrieve configuration value for time aggregation window
  private def getAggregateMs(config: ExecutionConfig) = {
    config.getGlobalJobParameters.asInstanceOf[ParameterTool].getLong("aggregate.milliseconds", 1000L)
  }

  object DuplicateFilter {
    val descriptor = new ValueStateDescriptor("seen", classOf[LRUCache])
  }

  class DuplicateFilter[T](identifierMapper: (T => Any), maxSize: Integer = 100) extends RichFlatMapFunction[T, T] {
    private var operatorState: ValueState[LRUCache] = _

    override def open(configuration: Configuration): Unit = {
      operatorState = this.getRuntimeContext.getState(DuplicateFilter.descriptor)
    }

    override def flatMap(event: T, out: Collector[T]): Unit = {
      if (operatorState.value == null) { // we haven't seen the key yet
        operatorState.update(new LRUCache(maxSize))
      }
      val cache = operatorState.value
      val key = identifierMapper(event)
      if (!cache.getOrDefault(key, false)) { // we haven't seen the identifier yet
        out.collect(event)
        // set cache to true so that we don't emit elements with this key again
        cache.put(key, true)
      }
      else {
        LOG.info(s"Removing duplicate event $value")
      }
    }
  }

  class LRUCache(val maxSize: Int, initialCapacity: Int = 16, loadFactor: Float = 0.75f) extends util.LinkedHashMap[Any, Boolean](initialCapacity, loadFactor, true) {
    override def removeEldestEntry(eldest: util.Map.Entry[Any, Boolean]): Boolean = size > maxSize
  }

  class ComputeEventRatePreAggregator
    extends ReduceFunction[EventStats] {
    override def reduce(r1: EventStats, r2: EventStats): EventStats = {
      EventStats(
        // Merge maps, summing values
        r1.eventNumberDeltaCounts ++ r2.eventNumberDeltaCounts.map { case (k, v) => k -> (v + r1.eventNumberDeltaCounts.getOrElse(k, 0L)) },
        // Sum values
        r1.sumOfLatencies + r2.sumOfLatencies
      )
    }
  }

  class ComputeEventRateProcessFunction
    extends ProcessAllWindowFunction[EventStats, String, TimeWindow] {
    override def process(context: Context, elements: Iterable[EventStats], out: Collector[String]): Unit = {
      val aggregateMs = getAggregateMs(getRuntimeContext.getExecutionConfig)
      val singleItem = elements.iterator.next
      val eventNumberDifferenceCounts = singleItem.eventNumberDeltaCounts
      val eventCount = eventNumberDifferenceCounts.values.sum
      val anomalousEventNumberDeltaCounts = singleItem.eventNumberDeltaCounts.filterKeys(_ != (Some(1L), 1L))
      val anomalousEventNumberDeltaCount = anomalousEventNumberDeltaCounts.values.sum
      val sumOfLatencies = singleItem.sumOfLatencies
      out.collect(s"[$now] ${eventCount * 1000 / aggregateMs} events/s, avg end-to-end latency ${sumOfLatencies / eventCount} ms; $anomalousEventNumberDeltaCount non-sequential events [${anomalousEventNumberDeltaCounts.mkString(",")}]")
    }
  }

}
