import io.specmatic.async.junit.SpecmaticKafkaContractTest
import io.specmatic.async.utils.EXAMPLES_DIR
import io.specmatic.async.utils.KAFKA_HOST
import io.specmatic.async.utils.KAFKA_PORT
import org.junit.jupiter.api.BeforeAll

class ContractTests : SpecmaticKafkaContractTest {

    companion object {
        @JvmStatic
        @BeforeAll
        fun setUp() {
            System.setProperty(KAFKA_HOST, "localhost");
            System.setProperty(KAFKA_PORT, "4511");
            System.setProperty(EXAMPLES_DIR, "src/test/resources/examples");
        }
    }
}