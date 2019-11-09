package com.microsoft.samples.flink.utils;

import com.microsoft.samples.flink.data.SampleData;
import com.microsoft.samples.flink.data.SampleRecord;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;

public class DuplicateFilterTest {

    private static SampleRecord sampleRecord1;
    private static SampleRecord sampleRecord2;
    private static SampleRecord sampleRecord3;
    private static SampleRecord sampleRecord4;

    private StreamExecutionEnvironment env;

    @BeforeClass
    public static void setUpClass() {
        sampleRecord1 = SampleData.record();
        sampleRecord2 = SampleData.record();
        sampleRecord3 = SampleData.record();
        sampleRecord3.deviceId = "otherDevice";
        sampleRecord4 = SampleData.record();
        sampleRecord4.eventId = "otherEvent";
    }

    private static void runStream(StreamExecutionEnvironment env, int maxSize, SampleRecord... v) throws Exception {
        CollectSink.values.clear();
        env.fromElements(v)
                .keyBy(e -> e.deviceId)
                .flatMap(new DuplicateByKeyFilter<>(e -> e.eventId, maxSize))
                .addSink(new CollectSink());
        env.execute();
    }

    @Before
    public void setUp() {
        env = StreamExecutionEnvironment.getExecutionEnvironment();
    }

    @Test
    public void passSingleEvent() throws Exception {
        runStream(env, 100, sampleRecord1);
        assertEquals(1, CollectSink.values.size());
    }

    @Test
    public void removeSecondEventWithSameId() throws Exception {
        runStream(env, 100, sampleRecord1, sampleRecord2);
        assertEquals(1, CollectSink.values.size());
    }

    @Test
    public void keepSecondEventWithSameIdWithOtherKey() throws Exception {
        runStream(env, 100, sampleRecord1, sampleRecord3);
        assertEquals(2, CollectSink.values.size());
    }

    @Test
    public void removeMultipleDuplicates() throws Exception {
        runStream(env, 1, sampleRecord1, sampleRecord1, sampleRecord1, sampleRecord1, sampleRecord1);
        assertEquals(1, CollectSink.values.size());
    }

    @Test
    public void forgetStateBeyondMaxSize() throws Exception {
        runStream(env, 1, sampleRecord1, sampleRecord4, sampleRecord1);
        assertEquals(3, CollectSink.values.size());
    }

    @Test
    public void applyMaxSizePerKey() throws Exception {
        runStream(env, 1, sampleRecord1, sampleRecord1, sampleRecord3, sampleRecord3, sampleRecord1);
        assertEquals(2, CollectSink.values.size());
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

