package com.microsoft.samples.flink.data;

import com.microsoft.samples.flink.ComplexEventProcessingLogic;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.junit.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;

public class ComplexEventJobProcessingLogicTest {

    @Test
    public void testIncrementPipeline() throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setParallelism(2);

        // Data sink. Values are collected in a static variable
        CollectSink<SampleTag> sink = new CollectSink<SampleTag>();
        CollectSink.values.clear();

        SampleRecord sampleRecord = new SampleRecord();
        sampleRecord.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord.value = 45.80967678165356d;
        sampleRecord.type = "CO2";
        sampleRecord.deviceId = "contoso://device-id-428";
        sampleRecord.deviceSequenceNumber = 3L;
        sampleRecord.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");
        // create a stream of custom elements and apply transformations
        ComplexEventProcessingLogic logic = new ComplexEventProcessingLogic();
        env.fromElements(sampleRecord, sampleRecord)
                .keyBy(r -> r.deviceId)
                .process(logic)
                .addSink(sink);

        // execute
        env.execute();

        // verify results
        List<SampleTag> v = CollectSink.values;
        assertEquals(2, v.size());
        assertEquals(sampleRecord.deviceId, v.get(0).deviceId);
        assertEquals(sampleRecord.deviceId, v.get(1).deviceId);
        assertEquals("FirstTagForThisKey", v.get(0).tag);
        assertEquals("2RecordsForThisKey", v.get(1).tag);
    }

    // create a testing sink
    private static class CollectSink<T> implements SinkFunction<T> {

        // must be static
        public static final List values = new ArrayList<>();

        @Override
        public synchronized void invoke(T value, SinkFunction.Context context) throws Exception {
            values.add(value);
        }
    }
}

