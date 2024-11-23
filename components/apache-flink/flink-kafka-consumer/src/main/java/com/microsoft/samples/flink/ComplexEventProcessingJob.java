package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleRecord;
import com.microsoft.samples.flink.data.SampleTag;
import com.microsoft.samples.flink.utils.JsonMapperSchema;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.KeyedProcessFunction;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.streaming.api.functions.timestamps.BoundedOutOfOrdernessTimestampExtractor;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumerBase;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static com.microsoft.samples.flink.StreamingJobCommon.getParams;

public class ComplexEventProcessingJob {
    private static final int MAX_EVENT_DELAY = 60; // max delay for out of order events
    private static final Logger LOG = LoggerFactory.getLogger(ComplexEventProcessingJob.class);

    public static void main(String[] args) throws Exception {
        ParameterTool params = getParams(args);

        StreamExecutionEnvironment env = StreamingJobCommon.createStreamExecutionEnvironment(params);
        JsonMapperSchema<SampleRecord> schema = new JsonMapperSchema(SampleRecord.class);
        FlinkKafkaConsumerBase<ConsumerRecord<byte[], SampleRecord>> consumer = StreamingJobCommon.createKafkaConsumer(params, schema);
        JsonMapperSchema<SampleTag> schema2 = new JsonMapperSchema(SampleTag.class);
        FlinkKafkaProducer<SampleTag> producer = StreamingJobCommon.createKafkaProducer(params, schema2);

        // setup streaming execution environment
        env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);
        // TODO env.enableCheckpointing
        env.getConfig().setAutoWatermarkInterval(1000);

        // assign a timestamp extractor
        consumer.assignTimestampsAndWatermarks(new SampleRecordTSExtractor());

        consumer.setStartFromEarliest();

        // create a data stream
        ComplexEventProcessingLogic logic = new ComplexEventProcessingLogic();
        DataStream<ConsumerRecord<byte[], SampleRecord>> s = env.addSource(consumer);
        buildStream(s, producer, logic);

        env.execute("complex event processing");

    }

    static void buildStream(DataStream<ConsumerRecord<byte[], SampleRecord>> source, SinkFunction<SampleTag> producer, KeyedProcessFunction<String, SampleRecord, SampleTag> logic) {
        DataStream<SampleTag> stream = source
                .rebalance()
                .map(c -> c.value())
                .keyBy(r -> r.deviceId)
                .process(logic);
        stream.addSink(producer);
    }

    public static class SampleRecordTSExtractor extends BoundedOutOfOrdernessTimestampExtractor<ConsumerRecord<byte[], SampleRecord>> {

        public SampleRecordTSExtractor() {
            super(Time.seconds(MAX_EVENT_DELAY));
        }

        @Override
        public long extractTimestamp(ConsumerRecord<byte[], SampleRecord> element) {
            return element.timestamp();
        }
    }
}
