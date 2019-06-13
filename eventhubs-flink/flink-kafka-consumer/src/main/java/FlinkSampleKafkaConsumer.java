import org.slf4j.LoggerFactory;
import org.slf4j.Logger;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.formats.json.JsonNodeDeserializationSchema;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.SingleOutputStreamOperator;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer011;     //Kafka v0.11.0.0

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Properties;

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
        }

        String topic = (String) properties.remove("topic");
        if (topic == null)
            throw new IllegalArgumentException("Missing configuration value kafka.topic");
        LOG.info("Consuming from Kafka topic: {}", topic);

        env.setParallelism(params.getInt("parallelism", 1));

        // start a checkpoint every 1000 ms
        env.enableCheckpointing(params.getLong("checkpoint.interval", 1000L));

        DataStream<ObjectNode> stream = env.addSource(new FlinkKafkaConsumer011(topic, new JsonNodeDeserializationSchema(), properties));

        SingleOutputStreamOperator<Integer> counts = stream
                .map(e -> 1)                    // convert to 1
                .timeWindowAll(Time.seconds(1)) // group into 1 second windows
                .reduce((x, y) -> x + y)        // sum 1s to count
                ;

        counts.print();

        env.execute("Sample Kafka Consumer - event counter by second");
    }
}
