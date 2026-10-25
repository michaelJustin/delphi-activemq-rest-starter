package com.example.amqdemo;

import java.io.StringWriter;
import java.util.Enumeration;

import org.apache.activemq.MessageTransformer;
import org.codehaus.jettison.mapped.Configuration;

import com.thoughtworks.xstream.XStream;
import com.thoughtworks.xstream.io.json.JettisonMappedXmlDriver;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import jakarta.jms.MessageConsumer;
import jakarta.jms.MessageProducer;
import jakarta.jms.ObjectMessage;
import jakarta.jms.Session;
import jakarta.jms.TextMessage;

/**
 * Client-side counterpart of the broker's "jms-object-json" transformation.
 *
 * The ActiveMQ Classic REST API (MessageServlet) does not apply message
 * transformations; for an ObjectMessage it only returns getObject().toString().
 * This transformer therefore converts every outgoing ObjectMessage into a
 * TextMessage holding the object as JSON, written with XStream and Jettison
 * exactly as the broker's STOMP jms-object-json transformation does
 * (JmsFrameTranslator.marshall). The broker then stores plain JSON text: no
 * model classes on the broker class path, no trusted-package configuration.
 */
public class JsonObjectMessageTransformer implements MessageTransformer {

    /** Message property naming the transformation that produced the body. */
    public static final String TRANSFORMATION_PROPERTY = "transformation";

    public static final String TRANSFORMATION = "jms-object-json";

    private final XStream xstream = new XStream();

    @Override
    public Message producerTransform(Session session, MessageProducer producer, Message message)
            throws JMSException {
        if (!(message instanceof ObjectMessage objectMessage)) {
            return message;
        }

        StringWriter json = new StringWriter();
        JettisonMappedXmlDriver driver = new JettisonMappedXmlDriver(new Configuration(), false);
        xstream.marshal(objectMessage.getObject(), driver.createWriter(json));

        TextMessage textMessage = session.createTextMessage(json.toString());
        copyHeadersAndProperties(objectMessage, textMessage);
        textMessage.setStringProperty(TRANSFORMATION_PROPERTY, TRANSFORMATION);
        return textMessage;
    }

    @Override
    public Message consumerTransform(Session session, MessageConsumer consumer, Message message) {
        return message;
    }

    private static void copyHeadersAndProperties(Message from, Message to) throws JMSException {
        to.setJMSCorrelationID(from.getJMSCorrelationID());
        to.setJMSReplyTo(from.getJMSReplyTo());
        to.setJMSType(from.getJMSType());
        Enumeration<?> names = from.getPropertyNames();
        while (names.hasMoreElements()) {
            String name = (String) names.nextElement();
            to.setObjectProperty(name, from.getObjectProperty(name));
        }
    }
}
