package com.microsoft.samples.flink;

import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;


class StreamingJobCommon {

    private static final Logger LOG = LoggerFactory.getLogger(StreamingJobCommon.class);

    static StreamExecutionEnvironment createStreamExecutionEnvironment(ParameterTool params) {

        // set up the execution environment
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // make parameters available in the web interface, if available
        env.getConfig().setGlobalJobParameters(params);

        // Set Flink task parallelism
        env.setParallelism(params.getInt("parallelism", 1));

        // start a checkpoint every 1000 ms
        env.enableCheckpointing(params.getLong("checkpoint.interval", 1000L));

        return env;
    }





    private static void setProperties(ParameterTool params, String prefix, Properties properties) {
        params.toMap().forEach(
                (k, v) -> {
                    if (k.startsWith(prefix)) properties.put(k.replace(prefix, ""), v);
                });
    }


}

