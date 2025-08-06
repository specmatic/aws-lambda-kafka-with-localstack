
import io.specmatic.async.core.constants.AVAILABLE_SERVERS
import io.specmatic.async.core.constants.EXAMPLES_DIR
import io.specmatic.kafka.test.SpecmaticKafkaContractTest
import org.junit.jupiter.api.BeforeAll

class ContractTests : SpecmaticKafkaContractTest {

    companion object {
        @JvmStatic
        @BeforeAll
        fun setUp() {
            System.setProperty(AVAILABLE_SERVERS, "localhost:4511")
            System.setProperty(EXAMPLES_DIR, "src/test/resources/examples")
        }
    }
}