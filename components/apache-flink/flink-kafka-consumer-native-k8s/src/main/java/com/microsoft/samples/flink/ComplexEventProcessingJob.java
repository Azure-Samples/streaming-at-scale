package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleRecord;
import com.microsoft.samples.flink.data.SampleTag;
import com.microsoft.samples.flink.utils.JsonMapperSchema;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.KeyedProcessFunction;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.streaming.api.functions.timestamps.BoundedOutOfOrdernessTimestampExtractor;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ComplexEventProcessingJob {
    private static final int MAX_EVENT_DELAY = 60; // max delay for out of order events
    private static final Logger LOG = LoggerFactory.getLogger(ComplexEventProcessingJob.class);

    public static void main(String[] args) throws Exception {
        ParameterTool params = ParameterTool.fromArgs(args);

        StreamExecutionEnvironment env = StreamingJobCommon.createStreamExecutionEnvironment(params);
        JsonMapperSchema<SampleRecord> schema = new JsonMapperSchema(SampleRecord.class);
        JsonMapperSchema<SampleTag> schema2 = new JsonMapperSchema(SampleTag.class);

        // create a data stream
        ComplexEventProcessingLogic logic = new ComplexEventProcessingLogic();

        KafkaSource<SampleRecord> source = KafkaSource.<SampleRecord>builder()
                .setBootstrapServers("brokers")
                .setTopics("input-topic")
                .setGroupId("my-group")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(schema)
                .build();

        KafkaSink<SampleTag> sink = KafkaSink.<SampleTag>builder()
                .setBootstrapServers("brokers")
                .setRecordSerializer(KafkaRecordSerializationSchema.builder()
                        .setTopic("topic-name")
                        .setValueSerializationSchema(schema2)
                        .build()
                )
                .build();

        env
                .fromSource(source, WatermarkStrategy.noWatermarks(), "Kafka Source")
                .keyBy(e -> e.deviceId)
                .process(logic)
                .sinkTo(sink);

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
