package com.microsoft.samples.flink.utils;

import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.serialization.SerializationSchema;
import org.apache.flink.api.common.typeinfo.TypeHint;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.api.java.typeutils.TypeExtractor;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.core.JsonGenerator;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.core.JsonParser;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.core.JsonProcessingException;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.*;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.module.SimpleModule;
import org.apache.flink.streaming.connectors.kafka.KafkaDeserializationSchema;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.header.Headers;

import java.io.IOException;
import java.io.Serializable;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;


public class JsonMapperSchema<T> implements DeserializationSchema<T>, SerializationSchema<T> {

    private static final DateTimeFormatter dateTimeFormatter =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSX").withZone(ZoneOffset.UTC);
    private final Class<T> type;
    private final ObjectMapper mapper;

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
    public boolean isEndOfStream(T newElement) {
        return false;
    }

    @Override
    public T deserialize(byte[] message) throws IOException {
        return mapper.readValue(message, type);
    }

    public TypeInformation<T> getProducedType() {
        return TypeInformation.of(new TypeHint<T>(){});
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
            return dateTimeFormatter.parse(jsonParser.getText(), Instant::from);
        }
    }
}
