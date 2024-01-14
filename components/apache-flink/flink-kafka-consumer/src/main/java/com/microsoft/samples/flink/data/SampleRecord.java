package com.microsoft.samples.flink.data;

import java.io.Serializable;
import java.time.Instant;

public class SampleRecord implements Serializable {
    public String eventId;
    public ComplexData complexData;
    public Double value;
    public String type;
    public String deviceId;
    public Long deviceSequenceNumber;
    public Instant createdAt;
    public Instant enqueuedAt;
    public Instant processedAt;

    public SampleRecord() {
        Instant now = Instant.now();
        createdAt = now;
    }

    public static class ComplexData implements Serializable {
        public double moreData0;
        public double moreData1;
        public double moreData2;
        public double moreData3;
        public double moreData4;
        public double moreData5;
        public double moreData6;
        public double moreData7;
        public double moreData8;
        public double moreData9;
        public double moreData10;
        public double moreData11;
        public double moreData12;
        public double moreData13;
        public double moreData14;
        public double moreData15;
        public double moreData16;
        public double moreData17;
        public double moreData18;
        public double moreData19;
        public double moreData20;
        public double moreData21;
        public double moreData22;
        public double moreData23;
    }
}
