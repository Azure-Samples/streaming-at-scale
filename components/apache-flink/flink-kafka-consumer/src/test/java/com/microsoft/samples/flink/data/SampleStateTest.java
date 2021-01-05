package com.microsoft.samples.flink.data;

import org.junit.Before;
import org.junit.Test;

import java.time.Instant;

import static java.time.Duration.ofMinutes;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class SampleStateTest {
    private SampleTag tag1, tag2, tag3, tag4;

    @Before
    public void initObjects() {
        Instant dt1 = Instant.now();
        Instant dt2 = Instant.now().minus(ofMinutes(2));
        Instant dt3 = Instant.now().minus(ofMinutes(10));

        tag1 = new SampleTag("device1", dt1, dt3, "eventId1", "tag1");
        tag2 = new SampleTag("device1", dt1, dt3, "eventId1", "tag1");
        tag3 = new SampleTag("device1", dt2, dt2, "eventId1", "tag1");
        tag4 = new SampleTag("device1", dt2, dt3, "eventId2", "tag1");
    }

    @Test
    public void tagExists01() {
        SampleState state = new SampleState();
        state.addTag(tag1);

        assertTrue(state.equivalentTagExists(tag1));
    }

    @Test
    public void tagExists02() {
        SampleState state = new SampleState();
        state.addTag(tag1);

        assertTrue(state.equivalentTagExists(tag2));
    }

    @Test
    public void tagExists03() {
        SampleState state = new SampleState();
        state.addTag(tag1);

        assertTrue(state.equivalentTagExists(tag3));
    }

    @Test
    public void tagExists04() {
        SampleState state = new SampleState();
        state.addTag(tag1);

        assertFalse(state.equivalentTagExists(tag4));
    }

    @Test
    public void tagsSize01() {
        SampleState state = new SampleState();
        state.addTag(tag1);
        state.addTag(tag2);

        assertTrue(state.tagsSize() == 2);
    }

    @Test
    public void getLastRecord01() {
        SampleRecord sampleRecord1 = new SampleRecord();
        sampleRecord1.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord1.value = 45.80967678165356d;
        sampleRecord1.type = "CO2";
        sampleRecord1.deviceId = "contoso-device-id-428";
        sampleRecord1.deviceSequenceNumber = 3L;
        sampleRecord1.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord1.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord1.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");

        SampleRecord sampleRecord2 = new SampleRecord();
        sampleRecord2.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord2.value = 45.80967678165356d;
        sampleRecord2.type = "CO2";
        sampleRecord2.deviceId = "contoso-device-id-428";
        sampleRecord2.deviceSequenceNumber = 3L;
        sampleRecord2.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord2.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord2.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");
        
        SampleState state = new SampleState();
        state.addRecord(sampleRecord1);
        state.addRecord(sampleRecord2);

        assertTrue(state.getLastRecord().equals(sampleRecord2));
    }

    @Test
    public void recordsSize01() {
        SampleRecord sampleRecord1 = new SampleRecord();
        sampleRecord1.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord1.value = 45.80967678165356d;
        sampleRecord1.type = "CO2";
        sampleRecord1.deviceId = "contoso-device-id-428";
        sampleRecord1.deviceSequenceNumber = 3L;
        sampleRecord1.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord1.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord1.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");

        SampleRecord sampleRecord2 = new SampleRecord();
        sampleRecord2.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord2.value = 45.80967678165356d;
        sampleRecord2.type = "CO2";
        sampleRecord2.deviceId = "contoso-device-id-428";
        sampleRecord2.deviceSequenceNumber = 3L;
        sampleRecord2.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord2.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord2.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");
        
        SampleState state = new SampleState();
        state.addRecord(sampleRecord1);
        state.addRecord(sampleRecord2);

        assertTrue(state.recordsSize() == 2);
    }

    @Test
    public void addRecord01() {
        SampleRecord lastRecord = null;
        SampleState state = new SampleState();

        for (int i = 0; i < SampleState.maxRecords+1; i++) {
            SampleRecord sampleRecord = new SampleRecord();
            sampleRecord.eventId = Integer.toString(i);
            sampleRecord.value = 45.80967678165356d;
            sampleRecord.type = "CO2";
            sampleRecord.deviceId = "contoso-device-id-428";
            sampleRecord.deviceSequenceNumber = 3L;
            sampleRecord.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
            sampleRecord.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
            sampleRecord.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");

            state.addRecord(sampleRecord);

            if (i == SampleState.maxRecords) {
                lastRecord = sampleRecord;
            }
        }

        assertTrue(lastRecord.equals(state.getLastRecord()) && state.recordsSize() == SampleState.maxRecords);
    }

    
}
