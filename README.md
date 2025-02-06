# AWS Lambda with Amazon MSK on LocalStack

This project demonstrates how to set up **AWS Lambda** to consume messages from **Amazon MSK (Kafka)**, all running locally using **LocalStack**.
and run contract tests against it using **Specmatic**

## 🚀 Prerequisites

### **1. Install AWS CLI**
If you don’t have the AWS CLI installed, install it from:
[AWS CLI installation](https://docs.aws.amazon.com/cli/v1/userguide/install-macos.html)


### **2. Install LocalStack**
You can install LocalStack via pip:
```sh
brew install localstack
```
Signup with localstack to get an Auth Token ( go for a Hobby licence).

### **3. Create a Fake AWS Profile for LocalStack**
Since LocalStack is a **mock AWS environment**, configure a fake profile:
```sh
aws configure --profile localstack
```
- **AWS Access Key:** `test`
- **AWS Secret Access Key:** `test`
- **Region:** `us-east-1`
- **Output Format:** `json`

## 🛠️ **Set Up Kafka & Lambda in LocalStack**

### **1️⃣ Start LocalStack**
```sh
localstack auth set-token <your-auth-token>
localstack start
```

## 🚀 Setting up Kafka cluster
### **2️⃣ Create an Amazon Kafka MSK Cluster**
```sh
aws kafka create-cluster \
    --cluster-name my-kafka-cluster \
    --kafka-version 2.8.1 \
    --broker-node-group-info file://broker-config.json \
    --number-of-broker-nodes 1 \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```

### **3️⃣ Verify the Kafka Cluster**
```sh
aws kafka list-clusters \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```
Save the value of the **ClusterArn** field in the response.

### **4️⃣ Get Kafka Bootstrap Brokers**
```sh
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

### **5️⃣ Create Kafka Topics**
```sh
kafka-topics.sh --create \
    --bootstrap-server localhost.localstack.cloud:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic io.specmatic.json.request
```
```sh
kafka-topics.sh --create \
    --bootstrap-server localhost.localstack.cloud:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic io.specmatic.json.reply
```

### **6️⃣ Deploy AWS Lambda**

From the project root folder:

Build the project and create a fat jar 
```shell
./gradlew clean shadowJar

```

Deploy the fat jar as a lambda function
```sh
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

### **7️⃣ Verify Lambda Deployment**
```sh
aws lambda list-functions --profile localstack --endpoint-url=http://localhost:4566
```

### **8️⃣ Create Event Source Mapping for Kafka**
```sh
aws lambda create-event-source-mapping \
    --function-name LambdaToKafka \
    --event-source-arn "arn:aws:kafka:us-east-1:000000000000:cluster/my-kafka-cluster/46ee14e0-ed00-4c1d-9fc1-581912e8d35e-25" \
    --topics "io.specmatic.json.request" \
    --starting-position LATEST \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```

## Testing the Lambda function:

### Publish a message on the **io.specmatic.json.request** topic:

```shell
kafka-console-producer --broker-list localhost:4511 --topic io.specmatic.json.request
```

Copy paste the following json object and press enter:
```json
{"id": 1, "xsd": "xsd 1"}
```

Press Ctrl+D

### Verify message on the **io.specmatic.json.reply** topic:
```shell
kafka-console-consumer --bootstrap-server localhost:4511 --topic io.specmatic.json.reply --from-beginning
```

You should see the following message :
```json
{"id": 1, "json": "Converted from XSD"}
```

If you don't see this message, check the logs for your lambda function:
```shell
aws logs tail /aws/lambda/LambdaToKafka --follow \
    --profile localstack \
    --endpoint-url=http://localhost:4566
```


## Run Contract Tests
```shell
  ./gradlew test
```
