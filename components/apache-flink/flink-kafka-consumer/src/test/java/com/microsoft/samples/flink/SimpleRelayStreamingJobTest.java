package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleData;
import com.microsoft.samples.flink.data.SampleRecord;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import static org.junit.Assert.*;

public class SimpleRelayStreamingJobTest {

    @Test
    public void testJob() throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // configure your test environment
        env.setParallelism(2);

        // values are collected in a static variable
        CollectSink.values.clear();

        SampleRecord sampleRecord1 = SampleData.record();
        SampleRecord sampleRecord2 = SampleData.record();
        sampleRecord2.eventId = "otherEvent";

        // create a stream of custom elements and apply transformations
        SimpleRelayStreamingJob.buildStreamingJob(env.fromElements(record(sampleRecord1), record(sampleRecord2)), new CollectSink());

        // execute
        Instant before = Instant.now();
        env.execute();
        Instant after = Instant.now();

        // verify your results
        assertEquals(2, CollectSink.values.size());
        Iterator<SampleRecord> values = CollectSink.values.iterator();

        SampleRecord record = values.next();
        assertEquals(Instant.ofEpochMilli(-1L), record.enqueuedAt);
        assertTrue(before.isBefore(record.processedAt));
        assertTrue(after.isAfter(record.processedAt));

        record = values.next();
        assertEquals(Instant.ofEpochMilli(-1L), record.enqueuedAt);
        assertTrue(before.isBefore(record.processedAt));
        assertTrue(after.isAfter(record.processedAt));
        assertFalse(values.hasNext());
    }

    private ConsumerRecord<byte[], SampleRecord> record(SampleRecord record) {
        return new ConsumerRecord<>("topic", 0, 0, null, record);
    }


    // create a testing sink
    private static class CollectSink implements SinkFunction<SampleRecord> {

        // must be static
        static final List<SampleRecord> values = new ArrayList<>();

        @Override
        public void invoke(SampleRecord value, Context context) {
            values.add(value);
        }
    }

}

