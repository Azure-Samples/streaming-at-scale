package com.microsoft.samples.flink.data;

import com.microsoft.samples.flink.ComplexEventProcessingLogic;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.api.java.functions.KeySelector;
import org.apache.flink.streaming.api.operators.KeyedProcessOperator;
import org.apache.flink.streaming.api.watermark.Watermark;
import org.apache.flink.streaming.runtime.streamrecord.StreamElement;
import org.apache.flink.streaming.util.KeyedOneInputStreamOperatorTestHarness;
import org.apache.flink.streaming.util.OneInputStreamOperatorTestHarness;
import org.junit.Before;
import org.junit.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.Iterator;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

public class ComplexEventJobProcessingLogicTest {

    private OneInputStreamOperatorTestHarness testHarness;
    private ComplexEventProcessingLogic logic;

    @Before
    public void setupTestHarness() throws Exception {

        //instantiate user-defined function
        logic = new ComplexEventProcessingLogic();

        // wrap user defined function into a the corresponding operator
        testHarness = new KeyedOneInputStreamOperatorTestHarness(
                new KeyedProcessOperator(logic),
                (KeySelector<SampleRecord, String>) value -> value.deviceId,
                TypeInformation.of(String.class));

        // optionally configured the execution environment
        testHarness.getExecutionConfig().setAutoWatermarkInterval(50);

        // open the test harness (will also call open() on RichFunctions)
        testHarness.open();
    }

    @Test
    public void testProcessingLogic() throws Exception {

        SampleRecord sampleRecord = new SampleRecord();
        sampleRecord.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord.value = 45.80967678165356d;
        sampleRecord.type = "CO2";
        sampleRecord.deviceId = "contoso://device-id-428";
        sampleRecord.deviceSequenceNumber = 3L;
        sampleRecord.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");

        //push (timestamped) elements into the operator (and hence user defined function)
        testHarness.processElement(sampleRecord, sampleRecord.createdAt.toEpochMilli());
        testHarness.processElement(sampleRecord, sampleRecord.createdAt.toEpochMilli());

        //trigger event time timers by advancing the event time of the operator with a watermark
        long time = sampleRecord.createdAt.toEpochMilli() + Duration.ofSeconds(120).toMillis();
        testHarness.processWatermark(time);

        //trigger processing time timers by advancing the processing time of the operator directly
        testHarness.setProcessingTime(time);

        //retrieve list of emitted records for assertions
        Iterator<StreamElement> vi = testHarness.getOutput().iterator();

        // verify results
        SampleTag tag;
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord.deviceId, tag.deviceId);
        assertEquals("FirstTagForThisKey", tag.tag);
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord.deviceId, tag.deviceId);
        assertEquals("2RecordsForThisKey", tag.tag);
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord.deviceId, tag.deviceId);
        assertEquals("NoNewsForAtLeast45000ms", tag.tag);
        Watermark w = vi.next().asWatermark();

        assertFalse(vi.hasNext());
    }

}

