
import io.specmatic.kafka.EXAMPLES_DIR
import io.specmatic.kafka.KAFKA_HOST
import io.specmatic.kafka.KAFKA_PORT
import io.specmatic.kafka.SpecmaticKafkaContractTest
import org.junit.jupiter.api.BeforeAll

class ContractTests : SpecmaticKafkaContractTest {

    companion object {
        @JvmStatic
        @BeforeAll
        fun setUp() {
            System.setProperty(KAFKA_HOST, "localhost")
            System.setProperty(KAFKA_PORT, "4511")
            System.setProperty(EXAMPLES_DIR, "src/test/resources/examples")
        }
    }
}