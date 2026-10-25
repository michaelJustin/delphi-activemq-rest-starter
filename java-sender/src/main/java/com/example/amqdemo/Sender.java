package com.example.amqdemo;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.apache.activemq.ActiveMQConnectionFactory;

import com.example.amqdemo.model.Order;

import jakarta.jms.Connection;
import jakarta.jms.MessageProducer;
import jakarta.jms.ObjectMessage;
import jakarta.jms.Session;

/**
 * Sends one Order as an ObjectMessage. The connection factory's transformer
 * turns it into a JSON TextMessage on the way out.
 *
 * System properties: brokerUrl (default tcp://localhost:61616),
 * queue (default TEST.QUEUE).
 */
public final class Sender {

    private Sender() {
    }

    public static void main(String[] args) throws Exception {
        String brokerUrl = System.getProperty("brokerUrl", "tcp://localhost:61616");
        String queueName = System.getProperty("queue", "TEST.QUEUE");

        ActiveMQConnectionFactory factory = new ActiveMQConnectionFactory(brokerUrl);
        factory.setTransformer(new JsonObjectMessageTransformer());

        Order order = new Order(1001, "Würfel (6-sided)", 3, 19.99,
                Instant.now().truncatedTo(ChronoUnit.SECONDS).toString());

        try (Connection connection = factory.createConnection()) {
            Session session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
            MessageProducer producer = session.createProducer(session.createQueue(queueName));
            ObjectMessage message = session.createObjectMessage(order);
            producer.send(message);
            System.out.println("Sent " + order + " to queue " + queueName + " at " + brokerUrl);
        }
    }
}
