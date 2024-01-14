package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleRecord;
import com.microsoft.samples.flink.utils.DuplicateByKeyFilter;
import com.microsoft.samples.flink.utils.JsonMapperSchema;
import com.microsoft.samples.flink.utils.SampleRecordTSExtractor;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumerBase;
import org.apache.kafka.clients.consumer.ConsumerRecord;

import java.time.Instant;

import static com.microsoft.samples.flink.StreamingJobCommon.getParams;

public class SimpleRelayStreamingJob {
    private static final int MAX_EVENT_DELAY = 60; // max delay for out of order events

    public static void main(String[] args) throws Exception {
        ParameterTool params = getParams(args);

        StreamExecutionEnvironment env = StreamingJobCommon.createStreamExecutionEnvironment(params);
        JsonMapperSchema<SampleRecord> schema = new JsonMapperSchema<>(SampleRecord.class);
        FlinkKafkaConsumerBase<ConsumerRecord<byte[], SampleRecord>> consumer = StreamingJobCommon.createKafkaConsumer(params, schema);
        SinkFunction<SampleRecord> producer = StreamingJobCommon.createKafkaProducer(params, schema);

        // setup streaming execution environment
        env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);
        env.enableCheckpointing(500);
        env.getConfig().setAutoWatermarkInterval(1000);

        // assign a timestamp extractor
        consumer.assignTimestampsAndWatermarks(new SampleRecordTSExtractor(Time.seconds(MAX_EVENT_DELAY)));

        // Build Flink pipeline.
        buildStreamingJob(env.addSource(consumer), producer);

        // execute program
        env.execute("simple relay");
    }

    static void buildStreamingJob(DataStream<ConsumerRecord<byte[], SampleRecord>> s, SinkFunction<SampleRecord> producer) {
        s.map(r -> {
            SampleRecord e = r.value();
            e.enqueuedAt = Instant.ofEpochMilli(r.timestamp());
            e.processedAt = Instant.now();
            return e;
        })
                .keyBy(e -> e.deviceId)
                .flatMap(new DuplicateByKeyFilter<>(e -> e.eventId, 100))
                .addSink(producer);
    }

}
