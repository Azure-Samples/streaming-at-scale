package com.microsoft.samples.flink.data;

import com.microsoft.samples.flink.utils.JsonMapperSchema;
import org.apache.commons.lang3.builder.ReflectionToStringBuilder;
import org.apache.commons.lang3.builder.ToStringStyle;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.Before;
import org.junit.Test;

import java.time.Instant;

import static org.junit.Assert.assertEquals;

/**
 * Unit test for SampleRecord.
 */
public class SampleRecordTest {

    private SampleRecord sampleRecord;

    private String serialized = "{\"eventId\":\"4fa25e6c-50d3-4189-9613-d486b71412df\",\"complexData\":null,\"value\":45.80967678165356,\"type\":\"CO2\",\"deviceId\":\"contoso-device-id-428\",\"deviceSequenceNumber\":3,\"createdAt\":\"2019-10-15T12:43:27.748Z\",\"enqueuedAt\":\"2019-10-16T12:43:27.748Z\",\"processedAt\":\"2019-10-17T12:43:27.748Z\"}";

    private JsonMapperSchema<SampleRecord> mapper = new JsonMapperSchema<>(SampleRecord.class);

    private static String objToString(Object obj) {
        return new ReflectionToStringBuilder(obj, ToStringStyle.SHORT_PREFIX_STYLE).toString();
    }

    @Before
    public void setUp() {
        sampleRecord = new SampleRecord();
        sampleRecord.eventId = "4fa25e6c-50d3-4189-9613-d486b71412df";
        sampleRecord.value = 45.80967678165356d;
        sampleRecord.type = "CO2";
        sampleRecord.deviceId = "contoso-device-id-428";
        sampleRecord.deviceSequenceNumber = 3L;
        sampleRecord.createdAt = Instant.parse("2019-10-15T12:43:27.748Z");
        sampleRecord.enqueuedAt = Instant.parse("2019-10-16T12:43:27.748Z");
        sampleRecord.processedAt = Instant.parse("2019-10-17T12:43:27.748Z");
    }

    @Test
    public void serialize() {
        byte[] objFromSampleRecord = mapper.serialize(sampleRecord);

        assertEquals(new String(objFromSampleRecord), serialized);
    }

    @Test
    public void deserialize() throws Exception {
        ConsumerRecord<byte[], byte[]> kafkaRecord = new ConsumerRecord<>("foo", 0, 0, null, serialized.getBytes());
        ConsumerRecord<byte[], SampleRecord> obj = mapper.deserialize(kafkaRecord);
        SampleRecord objFromSerialized = obj.value();

        assertEquals(objToString(sampleRecord), objToString(objFromSerialized));
    }
}
