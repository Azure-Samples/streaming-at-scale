import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.functions.ReduceFunction;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.formats.json.JsonNodeDeserializationSchema;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.flink.streaming.api.datastream.DataStreamSource;
import org.apache.flink.streaming.api.datastream.SingleOutputStreamOperator;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.windowing.AllWindowFunction;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer011;
import org.apache.flink.util.Collector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.Properties;

import static java.time.Instant.now;

@SuppressWarnings("Convert2Lambda")
public class FlinkSampleKafkaConsumer {

    private static final Logger LOG = LoggerFactory.getLogger(FlinkSampleKafkaConsumer.class);

    public static void main(String[] args) throws Exception {

        // Checking input parameters
        final ParameterTool params = ParameterTool.fromArgs(args);

        // set up the execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // make parameters available in the web interface, if available
        env.getConfig().setGlobalJobParameters(params);

        //Get properties from environment
        Properties properties = new Properties();
        for (Map.Entry<String, String> entry : params.toMap().entrySet()) {
            if (!entry.getKey().startsWith("kafka."))
                continue;
            properties.put(entry.getKey().replace("kafka.", ""), entry.getValue());
            System.out.println(entry.getValue());
        }

        String topic = (String) properties.remove("topic");
        if (topic == null)
            throw new IllegalArgumentException("Missing configuration value kafka.topic");
        LOG.info("Consuming from Kafka topic: {}", topic);

        env.setParallelism(params.getInt("parallelism", 1));

        // start a checkpoint every 1000 ms
        env.enableCheckpointing(params.getLong("checkpoint.interval", 1000L));

        Long aggregateMs = params.getLong("aggregate.milliseconds", 1000L);

        DataStreamSource<ObjectNode> stream = env.addSource(new FlinkKafkaConsumer011<>(topic, new JsonNodeDeserializationSchema(), properties));

        SingleOutputStreamOperator<String> counts = stream
                .map(new MapFunction<ObjectNode, Tuple2<Long, Long>>() {
                    @Override
                    public Tuple2<Long, Long> map(ObjectNode e) throws Exception {
                        return new Tuple2<>(1L, ChronoUnit.MILLIS.between(Instant.parse(e.get("createdAt").textValue()), now()));
                    }
                })
                .timeWindowAll(Time.milliseconds(aggregateMs)) // group into 1 second windows
                .reduce(new ReduceFunction<Tuple2<Long, Long>>() {

                            public Tuple2<Long, Long> reduce(Tuple2<Long, Long> r1, Tuple2<Long, Long> r2) throws Exception {
                                return new Tuple2<>(r1.f0 + r2.f0, r1.f1 + r2.f1);
                            }
                        },
                        new AllWindowFunction<Tuple2<Long, Long>, String, TimeWindow>() {
                            @Override
                            public void apply(TimeWindow window, Iterable<Tuple2<Long, Long>> values, Collector<String> out) throws Exception {
                                Tuple2<Long, Long> value = values.iterator().next();
                                out.collect(String.format("[%s] %d events/s, avg end-to-end latency %d ms", now(), value.f0 * 1000 / aggregateMs, value.f1 / value.f0));
                            }
                        }
                );

        counts.print();

        env.execute("Sample Kafka Consumer - event counter by second");
    }

}
