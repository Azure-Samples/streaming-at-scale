package com.microsoft.samples.flink.utils;

import org.apache.flink.api.common.serialization.SerializationSchema;
import org.apache.flink.api.common.typeinfo.TypeHint;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.core.JsonGenerator;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.core.JsonParser;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.core.JsonProcessingException;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.*;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.module.SimpleModule;
import org.apache.flink.streaming.connectors.kafka.KafkaDeserializationSchema;
import org.apache.kafka.clients.consumer.ConsumerRecord;

import java.io.IOException;
import java.io.Serializable;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Optional;


public class JsonMapperSchema<T> implements KafkaDeserializationSchema<ConsumerRecord<byte[], T>>, SerializationSchema<T> {

    private final Class<T> type;
    private final ObjectMapper mapper;

    private static final DateTimeFormatter dateTimeFormatter =
            DateTimeFormatter.ISO_INSTANT.withZone(ZoneOffset.UTC);

    public JsonMapperSchema(Class<T> type) {
        this.type = type;

        mapper = new ObjectMapper();

        SimpleModule module = new SimpleModule();
        module.addSerializer(Instant.class, new InstantSerializer());
        module.addDeserializer(Instant.class, new InstantDeserializer());
        mapper.registerModule(module);
    }

    @Override
    public byte[] serialize(T element) {
        try {
            return mapper.writeValueAsBytes(element);
        } catch (JsonProcessingException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public boolean isEndOfStream(ConsumerRecord<byte[], T> newElement) {
        return false;
    }

    @Override
    public ConsumerRecord<byte[], T> deserialize(ConsumerRecord<byte[], byte[]> r) throws Exception {
        byte[] message = r.value();
        T v = mapper.readValue(message, type);
        return new
                ConsumerRecord<>(r.topic(), r.partition(), r.offset(), r.timestamp(), r.timestampType(), r.serializedKeySize(), r.serializedValueSize(), r.key(), v, r.headers(), Optional.empty());
    }

    public TypeInformation<ConsumerRecord<byte[], T>> getProducedType() {
        return TypeInformation.of(new TypeHint<ConsumerRecord<byte[], T>>(){});
    }

    private static class InstantSerializer extends JsonSerializer<Instant> implements Serializable {

        @Override
        public void serialize(Instant obj, JsonGenerator jsonGenerator, SerializerProvider serializerProvider) throws IOException {
            jsonGenerator.writeString(dateTimeFormatter.format(obj));
        }
    }

    private static class InstantDeserializer extends JsonDeserializer<Instant> implements Serializable {

        @Override
        public Instant deserialize(JsonParser jsonParser, DeserializationContext deserializationContext) throws IOException {
            return Instant.parse(jsonParser.getText());
        }
    }
}
