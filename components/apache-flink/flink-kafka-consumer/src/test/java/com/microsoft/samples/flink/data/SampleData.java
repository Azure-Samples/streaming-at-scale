package com.microsoft.samples.flink.data;

import java.time.Instant;

public class SampleData {

    public static SampleRecord record() {

        SampleRecord sampleRecord = new SampleRecord();
        sampleRecord.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord.value = 45.80967678165356d;
        sampleRecord.type = "CO2";
        sampleRecord.deviceId = "contoso-device-id-428";
        sampleRecord.deviceSequenceNumber = 3L;
        sampleRecord.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");
        return sampleRecord;

    }
}

