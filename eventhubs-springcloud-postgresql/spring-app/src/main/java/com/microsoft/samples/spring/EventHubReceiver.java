package com.microsoft.samples.spring;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.azure.spring.integration.core.AzureHeaders;
import com.microsoft.azure.spring.integration.core.api.CheckpointConfig;
import com.microsoft.azure.spring.integration.core.api.CheckpointMode;
import com.microsoft.azure.spring.integration.core.api.Checkpointer;
import com.microsoft.azure.spring.integration.eventhub.api.EventHubOperation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.ContextRefreshedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.Message;
import org.springframework.stereotype.Component;

import javax.persistence.EntityManagerFactory;
import java.io.IOException;
import java.sql.Timestamp;
import java.time.Instant;

@Component
public class EventHubReceiver {

    private static final Logger log = LoggerFactory.getLogger(EventHubReceiver.class);

    @Value("${eventHubName}")
    private String eventHubName;

    @Value("${eventHubConsumerGroup}")
    String eventHubConsumerGroup;

    @Autowired
    private EventHubOperation eventHubOperation;

    @Autowired
    private DeviceEventRepository eventRepository;

    private ObjectMapper mapper = new ObjectMapper();

    @EventListener(ContextRefreshedEvent.class)
    public void subscribeToEventHub() {
        this.eventHubOperation
                .setCheckpointConfig(CheckpointConfig.builder().checkpointMode(CheckpointMode.MANUAL).build());
        this.eventHubOperation.subscribe(eventHubName, eventHubConsumerGroup, this::messageReceiver, String.class);
        log.info("Subscribed to Event Hub");
    }

    private void messageReceiver(Message<?> message) {
       log.info("New message received: '{}'", message.getPayload());

        Object payload = message.getPayload();
        if (!(payload instanceof String)) {
            throw new IllegalArgumentException(String.format("Unknown type: %s", payload.getClass()));
        }

        try {
            DeviceEvent event = mapper.readValue((String) payload, DeviceEvent.class);
            Timestamp now = Timestamp.from(Instant.now());
            event.enqueuedAt = now;
            event.processedAt = now;
            eventRepository.save(event);
        } catch (IOException e) {
            log.error("Error", e);
            //FIXME throw new RuntimeException(e);
        }

        Checkpointer checkpointer = message.getHeaders().get(AzureHeaders.CHECKPOINTER, Checkpointer.class);
        checkpointer.success().handle((r, ex) -> {
            if (ex == null) {
                log.info("Message '{}' successfully checkpointed", message.getPayload());
            }
            return null;
        });
    }
}
