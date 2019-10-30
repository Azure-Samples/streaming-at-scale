package com.microsoft.samples.flink.data;

import org.junit.Before;
import org.junit.Test;

import java.time.Instant;

import static java.time.Duration.ofMinutes;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class SampleStateTest {
    Instant dt1, dt2, dt3;
    SampleTag tag1, tag2, tag3, tag4;

    @Before
    public void initObjects() {
        dt1 = Instant.now();
        dt2 = Instant.now().minus(ofMinutes(2));
        dt3 = Instant.now().minus(ofMinutes(10));

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
}
