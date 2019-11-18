package com.microsoft.samples.flink.utils;

import com.microsoft.samples.flink.data.SampleRecord;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.kafka.clients.consumer.ConsumerRecord;

public class SampleRecordTSMapper implements MapFunction<ConsumerRecord<byte[], SampleRecord>, Long>
{
    @Override
    public Long map(ConsumerRecord<byte[], SampleRecord> sampleRecord) {
        return sampleRecord.timestamp();
    }
}