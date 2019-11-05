package com.microsoft.samples.spring;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import java.io.Serializable;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "rawdata")
public class DeviceEvent implements Serializable {
    @Id
    @Column(name = "eventId")
    public UUID eventId;
    @Column(name = "value")
    public Double value;
    @Column(name = "type")
    public String type;
    @Column(name = "deviceId")
    public String deviceId;
    @Column(name = "deviceSequenceNumber")
    public Long deviceSequenceNumber;
    @Column(name = "createdAt")
    public Timestamp createdAt;
    @Column(name = "enqueuedAt")
    public Timestamp enqueuedAt;
    @Column(name = "processedAt")
    public Timestamp processedAt;

    public DeviceEvent() {
        Timestamp now = Timestamp.from(Instant.now());
        createdAt = now;
    }

}