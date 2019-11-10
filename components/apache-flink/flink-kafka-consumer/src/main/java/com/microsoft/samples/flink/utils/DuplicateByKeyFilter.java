package com.microsoft.samples.flink.utils;

import com.microsoft.samples.flink.SimpleRelayStreamingJob;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.functions.RichFlatMapFunction;
import org.apache.flink.api.common.state.ValueState;
import org.apache.flink.api.common.state.ValueStateDescriptor;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.util.Collector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * A duplicate filter based on an idempotent repository stored in an LRU in-memory cache.
 */
public class DuplicateByKeyFilter<T, K> extends RichFlatMapFunction<T, T> {

    private static final Logger LOG = LoggerFactory.getLogger(SimpleRelayStreamingJob.class);
    private static final ValueStateDescriptor<LRUCache> descriptor = new ValueStateDescriptor<>("seen", LRUCache.class);
    private final MapFunction<T, K> identifierMapper;
    private final int maxSize;
    private ValueState<LRUCache> operatorState;

    public DuplicateByKeyFilter(MapFunction<T, K> identifierMapper, int maxSize) {
        this.identifierMapper = identifierMapper;
        this.maxSize = maxSize;
    }

    @Override
    public void open(Configuration parameters) {
        operatorState = getRuntimeContext().getState(DuplicateByKeyFilter.descriptor);
    }

    @Override
    public void flatMap(T event, Collector<T> out) throws Exception {
        if (operatorState.value() == null) { // we haven't seen the key yet
            operatorState.update(new LRUCache(maxSize));
        }
        LRUCache<K> cache = operatorState.value();
        K key = identifierMapper.map(event);
        if (!cache.contains(key)) { // we haven't seen the identifier yet
            out.collect(event);
            // set cache to true so that we don't emit elements with this key again
            cache.put(key);
        } else {
            LOG.info("Removing duplicate event {}", event);
        }
    }

    static class LRUCache<T> {
        private final LinkedHashMap<T, Boolean> cache;

        LRUCache(final int maxSize) {
            this.cache = new LinkedHashMap<T, Boolean>(16, 0.75f, true) {
                protected boolean removeEldestEntry(Map.Entry<T, Boolean> eldest) {
                    return this.size() > maxSize;
                }
            };
        }

        boolean contains(T key) {
            // NB getOrDefault resets the access time in the LinkedHashMap.
            return cache.getOrDefault(key, false);
        }

        void put(T key) {
            cache.put(key, true);
        }
    }
}
