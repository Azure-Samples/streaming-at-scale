package com.microsoft.samples.flink.data;

import java.time.Instant;

public class SampleTag {
    public String deviceId;
    public Instant processedAt;
    public Instant triggerEventCreatedAt;
    public String triggerEventId;
    public String tag;

    public SampleTag() {
        Instant now = Instant.now();
        processedAt = now;
        triggerEventCreatedAt = now;
    }

    public SampleTag(String deviceId, Instant processedAt, Instant triggerEventCreatedAt, String triggerEventId, String tag) {
        this.deviceId = deviceId;
        this.processedAt = processedAt;
        this.triggerEventCreatedAt = triggerEventCreatedAt;
        this.triggerEventId = triggerEventId;
        this.tag = tag;
    }
}
