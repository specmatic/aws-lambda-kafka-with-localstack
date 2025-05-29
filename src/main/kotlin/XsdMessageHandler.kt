package com.example

import com.amazonaws.services.lambda.runtime.Context
import com.amazonaws.services.lambda.runtime.RequestHandler
import com.example.models.CancelOrderRequest
import com.example.models.CancellationReference
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.xml.XmlMapper
import com.fasterxml.jackson.module.kotlin.registerKotlinModule

import org.apache.kafka.clients.producer.KafkaProducer
import org.apache.kafka.clients.producer.ProducerConfig
import org.apache.kafka.clients.producer.ProducerRecord
import org.slf4j.LoggerFactory
import java.util.*

private const val CANCEL_ORDER = "cancel-order"
private const val PROCESS_CANCELLATION = "process-cancellation"

class XsdMessageHandler : RequestHandler<Map<String, Any>, String> {
    private val logger = LoggerFactory.getLogger(XsdMessageHandler::class.java)
    private val objectMapper: ObjectMapper = ObjectMapper()
    private val xmlMapper = XmlMapper().registerKotlinModule()

    override fun handleRequest(event: Map<String, Any>, context: Context): String {
        // Extract Kafka messages from the event payload
        val records = (event["records"] as? Map<String, List<Map<String, Any>>>) ?: return "❌ No messages found"

        // Kafka Producer properties
        val producerProps = Properties().apply {
            put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost.localstack.cloud:4511") // Ensure correct LocalStack Kafka port
            put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")
            put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")
        }
        val producer = KafkaProducer<String, String>(producerProps)

        try {
            // Process each message in the batch
            for ((_, messages) in records) {
                for (message in messages) {
                    val encodedValue = message["value"] as? String ?: continue

                    // Decode Base64 payload (since AWS Lambda encodes Kafka messages in Base64)
                    val decodedBytes = Base64.getDecoder().decode(encodedValue)
                    val decodedMessage = String(decodedBytes)
                    logger.info("📜 Received message from topic: ${CANCEL_ORDER}: $decodedMessage")

                    val headers = message["headers"] as? List<Map<String, Any>>
                    headers?.forEachIndexed { index, header ->
                        println("Header[$index] type: ${header.javaClass.name}")
                        header.forEach { (key, value) ->
                            println("  Key: $key -> Value type: ${value.javaClass.name}")
                        }
                    }
                    val orderCorrelationIdBytes = headers
                        ?.firstOrNull { it.containsKey("orderCorrelationId") }
                        ?.get("orderCorrelationId")
                        ?.let { rawValue ->
                            val intList = rawValue as? List<*> ?: return@let null
                            intList.mapNotNull { (it as? Number)?.toByte() }.toByteArray()
                        }

                    val orderCorrelationId = orderCorrelationIdBytes?.let { String(it) } ?: ""

                    logger.info("CorrelationId of the message: $orderCorrelationId")

                    // Parse XML into CancelOrderRequest
                    val cancelOrderRequest = xmlMapper.readValue(decodedMessage, CancelOrderRequest::class.java)

                    // Construct CancellationReference response
                    val cancellationReference = CancellationReference(
                        reference = cancelOrderRequest.id,
                        status = "PENDING",
                    )
                    val cancellationReferenceMessage = objectMapper.writeValueAsString(cancellationReference)

                    val replyRecord = ProducerRecord(PROCESS_CANCELLATION, cancellationReference.reference.toString(), cancellationReferenceMessage)
                    replyRecord.headers().add("orderCorrelationId", orderCorrelationId.toByteArray())

                    try {
                        producer.send(replyRecord).get() // Ensure message is sent
                        logger.info("✅ Published message on topic: $PROCESS_CANCELLATION: $cancellationReferenceMessage with CorrelationId: $orderCorrelationId")
                    } catch (e: Exception) {
                        logger.error("❌ Failed to publish message on topic: ${PROCESS_CANCELLATION}: ${e.message}")
                    }
                }
            }
        } finally {
            producer.close() // Ensure the producer is closed properly
        }

        return "✅ Messages processed successfully"
    }
}
