#!/bin/bash
set -euo pipefail

# Create Kafka cluster
echo "Creating Kafka cluster..."
aws kafka create-cluster \
    --cluster-name my-kafka-cluster \
    --kafka-version 2.8.1 \
    --broker-node-group-info file://broker-config.json \
    --number-of-broker-nodes 1 \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566

echo "Waiting for cluster to appear..."
sleep 5

# Retrieve ClusterArn
echo "Retrieving ClusterArn..."
CLUSTER_ARN=$(aws kafka list-clusters \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566 \
    --query "ClusterInfoList[?ClusterName=='my-kafka-cluster'].ClusterArn" \
    --output text)

echo "ClusterArn: $CLUSTER_ARN"

# Create Kafka topics
echo "Creating Kafka topics..."
kafka-topics --create \
    --bootstrap-server localhost.localstack.cloud:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic cancel-order > /dev/null

kafka-topics --create \
    --bootstrap-server localhost.localstack.cloud:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic process-cancellation > /dev/null

# Build the Lambda JAR
echo "Building Lambda JAR..."
./gradlew clean shadowJar

echo "Deploying Lambda Function..."
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

# Create event source mapping
echo "Creating event source mapping..."
aws lambda create-event-source-mapping \
    --function-name LambdaToKafka \
    --event-source-arn "$CLUSTER_ARN" \
    --topics "cancel-order" \
    --starting-position LATEST \
    --region us-east-1 \
    --profile localstack \
    --endpoint-url=http://localhost:4566

echo "Setup complete."