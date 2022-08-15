package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleRecord;
import com.microsoft.samples.flink.utils.DuplicateByKeyFilter;
import com.microsoft.samples.flink.utils.JsonMapperSchema;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

public class SimpleRelayStreamingJob {
    private static final int MAX_EVENT_DELAY = 60; // max delay for out of order events

    public static void main(String[] args) throws Exception {
        ParameterTool params = ParameterTool.fromArgs(args);

        StreamExecutionEnvironment env = StreamingJobCommon.createStreamExecutionEnvironment(params);
        JsonMapperSchema<SampleRecord> schema = new JsonMapperSchema(SampleRecord.class);

        KafkaSource<SampleRecord> source = KafkaSource.<SampleRecord>builder()
                .setBootstrapServers("brokers")
                .setTopics("input-topic")
                .setGroupId("my-group")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(schema)
                .build();

        KafkaSink<SampleRecord> sink = KafkaSink.<SampleRecord>builder()
                .setBootstrapServers("brokers")
                .setRecordSerializer(KafkaRecordSerializationSchema.builder()
                        .setTopic("topic-name")
                        .setValueSerializationSchema(schema)
                        .build()
                )
                .build();

        env
                .fromSource(source, WatermarkStrategy.noWatermarks(), "Kafka Source")
                .keyBy(e -> e.deviceId)
                .flatMap(new DuplicateByKeyFilter<>(e -> e.eventId, 100))
                .sinkTo(sink);

        // execute program
        env.execute("simple relay");
    }
}
