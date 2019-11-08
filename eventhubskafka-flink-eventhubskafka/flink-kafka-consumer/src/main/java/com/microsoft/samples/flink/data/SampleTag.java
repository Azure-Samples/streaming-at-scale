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

    @Override
    public boolean equals(Object obj) {
        if (obj == null) {
            return false;
        }

        if (!SampleTag.class.isAssignableFrom(obj.getClass())) {
            return false;
        }

        final SampleTag other = (SampleTag) obj;
        return this.tag.equals(other.tag) &&
            this.triggerEventId.equals(other.triggerEventId) &&
            this.deviceId.equals(other.deviceId);
    }

    @Override
    public int hashCode() {
        int hash = 17;
        hash = 31 * hash + (this.tag != null ? this.tag.hashCode() : 0);
        hash = 31 * hash + (this.triggerEventId != null ? this.triggerEventId.hashCode(): 0);
        hash = 31 * hash + (this.deviceId != null ? this.deviceId.hashCode(): 0);
        return hash;
    }
}
