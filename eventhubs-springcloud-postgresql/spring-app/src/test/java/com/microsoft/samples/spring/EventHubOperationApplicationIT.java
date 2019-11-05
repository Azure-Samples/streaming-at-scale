package com.microsoft.samples.spring;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.azure.spring.integration.eventhub.api.EventHubOperation;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.rule.OutputCapture;
import org.springframework.integration.support.MessageBuilder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit4.SpringRunner;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@RunWith(SpringRunner.class)
@SpringBootTest(classes = EventHubOperationApplication.class)
@TestPropertySource(locations = "classpath:application-test.properties")
public class EventHubOperationApplicationIT {

    private static final Logger log = LoggerFactory.getLogger(EventHubOperationApplicationIT.class);

    @Rule
    public OutputCapture capture = new OutputCapture();

    @Autowired
    private EventHubOperation eventHubOperation;

    @Autowired
    private DeviceEventRepository eventRepository;

    @Value("${eventHubName}")
    private String eventHubName;

    private ObjectMapper mapper = new ObjectMapper();

    @Test
    public void testSendAndReceiveMessage() throws Exception {

        DeviceEvent event = new DeviceEvent();
        event.eventId = UUID.randomUUID();
        event.value = 45.80967678165356d;
        event.type = "CO2";
        event.deviceId = "contoso://device-id-428";
        event.deviceSequenceNumber = 3L;
        event.createdAt = Timestamp.from(Instant.parse("2019-10-15T12:43:27.748Z"));
        event.enqueuedAt = Timestamp.from(Instant.parse("2019-10-16T12:43:27.748Z"));
        event.processedAt = Timestamp.from(Instant.parse("2019-10-17T12:43:27.748Z"));
        String message = mapper.writeValueAsString(event);

        log.info("Sending test event");
        this.eventHubOperation.sendAsync(eventHubName, MessageBuilder.withPayload(message).build());

        String messageReceivedLog = String.format("New message received: '%s'", message);
        boolean messageReceived = false;
        boolean messageStored = false;
        for (int i = 0; i < 100; i++) {
            String output = capture.toString();
            if (!messageReceived && output.contains(messageReceivedLog)) {
                messageReceived = true;
            }

            if (!messageStored) {
                Optional<DeviceEvent> storedEvent = eventRepository.findById(event.eventId);
                if (storedEvent.isPresent()) {
                    messageStored = true;
                }
            }

            if (messageReceived && messageStored) {
                break;
            }

            Thread.sleep(1000);
        }
        assertThat(messageReceived).isTrue();
        assertThat(messageStored).isTrue();
    }
}
