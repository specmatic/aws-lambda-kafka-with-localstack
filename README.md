# Run Specmatic Kafka Contract Test on AWS Lambda with Amazon MSK on LocalStack using AsyncAPI 3.0

This project demonstrates below aspects
* Setting up **AWS Lambda** to consume messages from **Amazon MSK (Kafka)**, all running locally using **LocalStack**.
* **Contract Test** the Lambda based on [AsyncAPI 3.0](https://www.asyncapi.com/docs/reference/specification/v3.0.0) spec using **Specmatic Kafka Support** (#NOCODE #LOWCODE approach)

## 🚀 Prerequisites

### 1. Install Docker Desktop and AWS CLI

Please make sure you have Docker Desktop installed on your machine.

If you don’t have the AWS CLI installed, install it from:
[AWS CLI installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

#### MacOS - Using Homebrew
```shell
brew install awscli
```

### 2. Install Kafka Client
```shell
brew install kafka
```

### 3. LocalStack setup

Signup with localstack to get an Auth Token (choose an appropriate license - Example: Trial or Hobby licence).
And update the [docker-compose.yaml](docker-compose.yaml) by replacing "<PLEASE ADD YOUR TOKEN HERE>" with your API key.

### 4. Create a Fake AWS Profile for LocalStack
Since LocalStack is a **mock AWS environment**, configure a fake profile:
```shell
aws configure --profile localstack
```
- **AWS Access Key:** `test`
- **AWS Secret Access Key:** `test`
- **Region:** `us-east-1`
- **Output Format:** `json`

### 5. Start LocalStack**

This will start LocalStack with persistence enabled.

```shell
docker compose up
```

#### Troubleshooting `vmnetd` issues with Docker on MacOS

Please refer to [GitHub comment](https://github.com/docker/for-mac/issues/6677#issuecomment-1593787335).

## 🛠️ **Set Up Kafka & Lambda in LocalStack One Shot**

To setup everything in one go (creating Kafka Cluster, Topics, Subnet, Security Groups, etc.), run the following shell script:  

```shell
./setup.sh
```

Alternatively, you can follow the steps below to set up Kafka and Lambda in LocalStack manually.

## 🛠️ **Set Up Kafka & Lambda in LocalStack Step by Step**

## 🚀 Setting up Kafka cluster
### **1️⃣ Create an Amazon Kafka MSK Cluster**
```shell
aws kafka create-cluster \
    --cluster-name my-kafka-cluster \
    --kafka-version 2.8.1 \
    --broker-node-group-info file://broker-config.json \
    --number-of-broker-nodes 1 \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```

### **2️⃣ Verify the Kafka Cluster**
```shell
aws kafka list-clusters \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```

Please save the value of the **ClusterArn** field in the response.
You will need to use this in some of the next steps where you see `<YOUR_CLUSTER_ARN>`.

### **3️⃣ Get Kafka Bootstrap Brokers**
```shell
aws kafka get-bootstrap-brokers \
    --cluster-arn "<YOUR_CLUSTER_ARN>" \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```
**Example Response:**
```json
{
    "BootstrapBrokerString": "localhost.localstack.cloud:4511"
}
```

### **4️⃣ Create Kafka Topics**

**Pre-requisite:** Install Kafka on your local machine to use the `kafka-topics.sh` command.

```shell
kafka-topics --create \
    --bootstrap-server localhost.localstack.cloud:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic cancel-order
```
```shell
kafka-topics --create \
    --bootstrap-server localhost.localstack.cloud:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic process-cancellation
```

### **5️⃣ Deploy AWS Lambda**

**Pre-requisite:** Use JDK 17, for example if you are using jenv, please run: `jenv local 17`

From the project root folder:

Build the project and create a fat jar 
```shell
./gradlew clean shadowJar
```

Deploy the fat jar as a lambda function
```shell
aws lambda create-function \
    --function-name LambdaToKafka \
    --runtime java17 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler com.example.XsdMessageHandler \
    --zip-file fileb://build/libs/aws-lambda-kafka.jar \
    --timeout 30 \
    --memory-size 512 \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```

`Use `q` to quit.`

### **6️⃣ Verify Lambda Deployment**
```shell
aws lambda list-functions --profile localstack --endpoint-url=http://localhost:4566
```

Search for the function `LambdaToKafka` using `/` and `q` to quit.

### **7️⃣ Create Event Source Mapping for Kafka**
```shell
aws lambda create-event-source-mapping \
    --function-name LambdaToKafka \
    --event-source-arn "<YOUR_CLUSTER_ARN>" \
    --topics "cancel-order" \
    --starting-position LATEST \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```

`Use `q` to quit.`

## Testing the Lambda function:

### Publish a message on the **cancel-order** topic:

```shell
kafka-console-producer --bootstrap-server localhost:4511 --topic cancel-order
```

Copy and paste the following json object and press enter:
```xml
<CancelOrderRequest><id>71717</id></CancelOrderRequest>
```

Press `Ctrl+D`.

### Verify message on the **process-cancellation** topic:
```shell
kafka-console-consumer --bootstrap-server localhost:4511 --topic process-cancellation --from-beginning
```

You should see the following message :
```json
{"reference": 12345, "status": "INPROGRESS"}
```

If you don't see this message, check the logs for your lambda function:
```shell
aws logs tail /aws/lambda/LambdaToKafka --follow \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```

## **Run Specmatic Kafka Contract Tests using AsyncAPI spec**

This step now uses **Specmatic Kafka Support** to leverage **AsyncAPI 3.0 spec** to contract test the above Lambda setup.
The **AsyncAPI 3.0 spec** models the Event Driven Architecture, the topics and the schema of messages sent / received on those topics.

Please keep your Local Stack running for this next step.

```shell
  ./gradlew test
```

You should now see the interactive Specmatic Kafka HTML test report here - [`build/reports/index.html`](build/reports/index.html).
The report has drill down details on the messages sent and received on the Kafka topics and if the messages are as per the schema in **AsyncAPI spec**.

## Shutdown LocalStack

```shell
localstack stop
```
