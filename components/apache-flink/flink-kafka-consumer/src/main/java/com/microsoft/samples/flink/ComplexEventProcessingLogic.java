package com.microsoft.samples.flink;

import com.microsoft.samples.flink.data.SampleRecord;
import com.microsoft.samples.flink.data.SampleState;
import com.microsoft.samples.flink.data.SampleTag;
import org.apache.flink.api.common.state.ValueState;
import org.apache.flink.api.common.state.ValueStateDescriptor;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.functions.KeyedProcessFunction;
import org.apache.flink.util.Collector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.Iterator;

public class ComplexEventProcessingLogic extends KeyedProcessFunction<String, SampleRecord, SampleTag> {
    private static final Logger LOG = LoggerFactory.getLogger(ComplexEventProcessingLogic.class);
    private static final Integer NO_NEWS_DELAY = 45000;
    private transient ValueState<SampleState> valueState;

    @Override
    public void open(Configuration configuration) {
        valueState = getRuntimeContext().getState(
                new ValueStateDescriptor<>("records and tags", SampleState.class));
    }

    @Override
    public void processElement(SampleRecord receivedRecord, Context context, Collector<SampleTag> out) throws Exception {
        SampleState state = valueState.value();
        if (state == null) {
            state = new SampleState();
        }

        // add latest record to the state
        state.addRecord(receivedRecord);

        if (state.tagsSize() == 0) {
            SampleTag tag = new SampleTag(receivedRecord.deviceId, Instant.now(), receivedRecord.createdAt, receivedRecord.eventId,
                    "FirstTagForThisKey");
            state.addTag(tag);
            out.collect(tag);
        }

        Integer nbRecords = state.recordsSize();
        if (nbRecords > 1 && nbRecords < SampleState.maxRecords) {
            SampleTag tag = new SampleTag(receivedRecord.deviceId, Instant.now(), receivedRecord.createdAt, receivedRecord.eventId,
                    String.format("%dRecordsForThisKey", nbRecords));
            state.addTag(tag);
            out.collect(tag);
        }

        // do some computation on the state
        int nbTemperaturesInThe70s = 0;
        boolean someCO2IsGreaterThan80 = false;
        Iterator<SampleRecord> iterator = state.recordsIterator();
        while (iterator.hasNext()) {
            SampleRecord r = iterator.next();
            if (r.type.equals("TEMP")) {
                if (r.value >= 70 && r.value < 80) {
                    nbTemperaturesInThe70s++;
                    if (nbTemperaturesInThe70s > 1) {
                        SampleTag tag = new SampleTag(r.deviceId, Instant.now(), r.createdAt, r.eventId,
                                "SeveralTemperaturesIn70s");
                        if (!state.equivalentTagExists(tag)) {
                            state.addTag(tag);
                            out.collect(tag);
                        }
                    }
                }
            } else if (r.type.equals("CO2")) {
                if (r.value > 80) {
                    someCO2IsGreaterThan80 = true;
                }
            }

            if (someCO2IsGreaterThan80 && nbTemperaturesInThe70s > 1) {
                SampleTag tag = new SampleTag(r.deviceId, Instant.now(), r.createdAt, r.eventId,
                        "HighCO2WithSeveralTemperaturesIn70s");
                if (!state.equivalentTagExists(tag)) {
                    state.addTag(tag);
                    out.collect(tag);
                    break;
                }
            }
        } // while

        valueState.update(state);

        context.timerService().registerEventTimeTimer(receivedRecord.createdAt.toEpochMilli() + NO_NEWS_DELAY);
    }

    @Override
    public void onTimer(long timestamp, OnTimerContext context, Collector<SampleTag> out) throws Exception {
        SampleState state = valueState.value();

        SampleRecord r = state.getLastRecord();
        if (timestamp - r.createdAt.toEpochMilli() >= NO_NEWS_DELAY) {
            SampleTag tag = new SampleTag(r.deviceId, Instant.now(), r.createdAt, r.eventId,
                    String.format("NoNewsForAtLeast%sms", NO_NEWS_DELAY));
            if (!state.equivalentTagExists(tag)) {
                state.addTag(tag);
                out.collect(tag);
                valueState.update(state);
            }
        }
    }
}
