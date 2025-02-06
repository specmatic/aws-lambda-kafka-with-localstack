package com.example

import com.amazonaws.services.lambda.runtime.Context
import com.amazonaws.services.lambda.runtime.RequestHandler
import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import kotlinx.serialization.Serializable
import org.apache.kafka.clients.producer.KafkaProducer
import org.apache.kafka.clients.producer.ProducerConfig
import org.apache.kafka.clients.producer.ProducerRecord
import java.util.*
import java.util.Base64

@Serializable
data class JsonConversionRequest(
    @JsonProperty("id") val id: Int,
    @JsonProperty("xsd") val xsd: String
)

@Serializable
data class JsonConversionReply(val id: Int, val json: String)

class XsdMessageHandler : RequestHandler<Map<String, Any>, String> {

    private val objectMapper: ObjectMapper = ObjectMapper().registerKotlinModule()

    override fun handleRequest(event: Map<String, Any>, context: Context): String {
        println("🟢 Received event: $event")

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
                    println("📩 Received raw Kafka message: $encodedValue")

                    // Decode Base64 payload (since AWS Lambda encodes Kafka messages in Base64)
                    val decodedBytes = Base64.getDecoder().decode(encodedValue)
                    val decodedMessage = String(decodedBytes)
                    println("📜 Decoded message: $decodedMessage")

                    // Deserialize JSON message
                    val request: JsonConversionRequest = objectMapper.readValue(decodedMessage, JsonConversionRequest::class.java )

                    // Convert XSD to JSON (Dummy conversion)
                    val jsonReply= JsonConversionReply(request.id, "Converted from XSD")
                    val jsonReplyMessage = objectMapper.writeValueAsString(jsonReply);

                    println("📜 Sending json message: $jsonReplyMessage")

                    // Publish transformed message to Kafka
                    val replyRecord = ProducerRecord("io.specmatic.json.reply", jsonReply.id.toString(), jsonReplyMessage)

                    try {
                        producer.send(replyRecord).get() // Ensure message is sent
                        println("✅ Published transformed message: $jsonReplyMessage")
                    } catch (e: Exception) {
                        println("❌ Failed to publish message: ${e.message}")
                    }
                }
            }
        } finally {
            producer.close() // Ensure the producer is closed properly
        }

        return "✅ Messages processed successfully"
    }
}
