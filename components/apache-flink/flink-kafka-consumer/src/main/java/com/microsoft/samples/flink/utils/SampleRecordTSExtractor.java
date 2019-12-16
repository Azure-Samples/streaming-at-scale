package com.microsoft.samples.flink.utils;

import com.microsoft.samples.flink.data.SampleRecord;
import org.apache.flink.streaming.api.functions.timestamps.BoundedOutOfOrdernessTimestampExtractor;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.kafka.clients.consumer.ConsumerRecord;

public class SampleRecordTSExtractor extends BoundedOutOfOrdernessTimestampExtractor<ConsumerRecord<byte[], SampleRecord>> {
    public SampleRecordTSExtractor(Time maxOutOfOrderness) {
        super(maxOutOfOrderness);
    }

    @Override
    public long extractTimestamp(ConsumerRecord<byte[], SampleRecord> sampleRecord) {
        return sampleRecord.timestamp();
    }
}

