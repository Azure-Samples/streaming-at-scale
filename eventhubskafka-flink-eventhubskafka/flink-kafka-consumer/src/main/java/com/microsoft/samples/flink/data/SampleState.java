package com.microsoft.samples.flink.data;

import java.io.Serializable;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Iterator;

public class SampleState implements Serializable {
    public static transient Integer maxRecords = 10;
    public static transient Integer maxTags = 15;
    // public because of https://ci.apache.org/projects/flink/flink-docs-stable/dev/types_serialization.html#rules-for-pojo-types
    public ArrayDeque<SampleRecord> records = new ArrayDeque<SampleRecord>();
    public ArrayList<SampleTag> tags = new ArrayList<SampleTag>();

    public SampleState() {
    }

    public int recordsSize() {
        return records.size();
    }

    public void addRecord(SampleRecord sampleRecord) {
        if (records.size() >= maxRecords) {
            records.removeFirst();
        }
        records.addLast(sampleRecord);
    }

    public Iterator<SampleRecord> recordsIterator() {
        return records.iterator();
    }

    public SampleRecord getLastRecord() {
        return records.getLast();
    }

    public int tagsSize() {
        return tags.size();
    }

    public Boolean equivalentTagExists(SampleTag tag) {
        Iterator<SampleTag> iterator = tags.iterator();
        while (iterator.hasNext()) {
            SampleTag t = iterator.next();
            if (tag.tag.equals(t.tag)
                    && tag.triggerEventId.equals(t.triggerEventId)
                    && tag.deviceId.equals(t.deviceId)) {
                return true;
            }
        }
        return false;
    }

    public void addTag(SampleTag tag) {
        tags.add(tag);
    }
}
