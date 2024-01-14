package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleData;
import com.microsoft.samples.flink.data.SampleRecord;
import com.microsoft.samples.flink.data.SampleTag;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.api.java.functions.KeySelector;
import org.apache.flink.streaming.api.operators.KeyedProcessOperator;
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

    private OneInputStreamOperatorTestHarness<SampleRecord, SampleTag> testHarness;

    @Before
    public void setupTestHarness() throws Exception {

        //instantiate user-defined function
        ComplexEventProcessingLogic logic = new ComplexEventProcessingLogic();

        // wrap user defined function into the corresponding operator
        testHarness = new KeyedOneInputStreamOperatorTestHarness<>(
                new KeyedProcessOperator<>(logic),
                (KeySelector<SampleRecord, String>) value -> value.deviceId,
                TypeInformation.of(String.class));

        // optionally configured the execution environment
        testHarness.getExecutionConfig().setAutoWatermarkInterval(50);

        // open the test harness (will also call open() on RichFunctions)
        testHarness.open();
    }

    @Test
    public void testProcessingLogic() throws Exception {

        SampleRecord sampleRecord = SampleData.record();

        //push (timestamped) elements into the operator (and hence user defined function)
        testHarness.processElement(sampleRecord, sampleRecord.createdAt.toEpochMilli());
        testHarness.processElement(sampleRecord, sampleRecord.createdAt.toEpochMilli());

        //trigger event time timers by advancing the event time of the operator with a watermark
        long time = sampleRecord.createdAt.toEpochMilli() + Duration.ofSeconds(120).toMillis();
        testHarness.processWatermark(time);

        //trigger processing time timers by advancing the processing time of the operator directly
        testHarness.setProcessingTime(time);

        //retrieve list of emitted records for assertions
        Iterator<StreamElement> vi = (Iterator) testHarness.getOutput().iterator();

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
        vi.next().asWatermark();

        assertFalse(vi.hasNext());
    }

    @Test
    public void testProcessingLogicState() throws Exception {

        SampleRecord sampleRecord1 = new SampleRecord();
        sampleRecord1.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord1.value = 80.80967678165356d;
        sampleRecord1.type = "CO2";
        sampleRecord1.deviceId = "contoso-device-id-428";
        sampleRecord1.deviceSequenceNumber = 3L;
        sampleRecord1.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord1.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord1.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");

        //push (timestamped) elements into the operator (and hence user defined function)
        testHarness.processElement(sampleRecord1, sampleRecord1.createdAt.toEpochMilli());

        SampleRecord sampleRecord2 = new SampleRecord();
        sampleRecord2.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord2.value = 70.80967678165356d;
        sampleRecord2.type = "TEMP";
        sampleRecord2.deviceId = "contoso-device-id-428";
        sampleRecord2.deviceSequenceNumber = 3L;
        sampleRecord2.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord2.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord2.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");

        testHarness.processElement(sampleRecord2, sampleRecord2.createdAt.toEpochMilli());
        testHarness.processElement(sampleRecord2, sampleRecord2.createdAt.toEpochMilli());

        //trigger event time timers by advancing the event time of the operator with a watermark
        long time = sampleRecord1.createdAt.toEpochMilli() + Duration.ofSeconds(120).toMillis();
        testHarness.processWatermark(time);

        //trigger processing time timers by advancing the processing time of the operator directly
        testHarness.setProcessingTime(time);

        //retrieve list of emitted records for assertions
        Iterator<StreamElement> vi = (Iterator) testHarness.getOutput().iterator();

        // verify results
        SampleTag tag;
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord1.deviceId, tag.deviceId);
        assertEquals("FirstTagForThisKey", tag.tag);
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord2.deviceId, tag.deviceId);
        assertEquals("2RecordsForThisKey", tag.tag);
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord2.deviceId, tag.deviceId);
        assertEquals("3RecordsForThisKey", tag.tag);
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord2.deviceId, tag.deviceId);
        assertEquals("SeveralTemperaturesIn70s", tag.tag);
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord1.deviceId, tag.deviceId);
        assertEquals("HighCO2WithSeveralTemperaturesIn70s", tag.tag);
        tag = vi.next().<SampleTag>asRecord().getValue();
        assertEquals(sampleRecord1.deviceId, tag.deviceId);
        assertEquals("NoNewsForAtLeast45000ms", tag.tag);
        vi.next().asWatermark();

        assertFalse(vi.hasNext());
    }
}

