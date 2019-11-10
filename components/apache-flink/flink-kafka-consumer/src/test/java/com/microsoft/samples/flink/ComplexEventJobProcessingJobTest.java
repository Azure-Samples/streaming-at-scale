package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleData;
import com.microsoft.samples.flink.data.SampleRecord;
import com.microsoft.samples.flink.data.SampleTag;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.KeyedProcessFunction;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.util.Collector;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;

public class ComplexEventJobProcessingJobTest {

    @Test
    public void testJob() throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // configure your test environment
        env.setParallelism(2);

        // values are collected in a static variable
        CollectSink.values.clear();

        SampleRecord sampleRecord = SampleData.record();

        // create a stream of custom elements and apply transformations
        KeyedProcessFunction<String, SampleRecord, SampleTag> anew = new KeyedProcessFunction<String, SampleRecord, SampleTag>() {
            @Override
            public void processElement(SampleRecord value, Context ctx, Collector<SampleTag> out) {
                out.collect(new SampleTag());
            }
        };
        ConsumerRecord<byte[], SampleRecord> sampleMessage = new ConsumerRecord<>("topic", 0, 0, null, sampleRecord);
        ComplexEventProcessingJob.buildStream(env.fromElements(sampleMessage), new CollectSink(), anew);

        // execute
        env.execute();

        // verify your results
        assertEquals(1, CollectSink.values.size());
    }


    // create a testing sink
    private static class CollectSink implements SinkFunction<SampleTag> {

        // must be static
        static final List<SampleTag> values = new ArrayList<>();

        @Override
        public void invoke(SampleTag value, Context context) {
            values.add(value);
        }
    }

}

