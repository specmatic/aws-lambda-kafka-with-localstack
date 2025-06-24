#!/bin/bash
set -euo pipefail

# Config
REGION="us-east-1"
PROFILE="localstack"
ENDPOINT="http://localhost:4566"
OUTPUT_FILE="broker-config.json"

echo "Deleting Lambda function LambdaToKafka (if it exists)..."
if aws lambda get-function \
    --function-name LambdaToKafka \
    --region "$REGION" \
    --profile "$PROFILE" \
    --endpoint-url "$ENDPOINT" > /dev/null 2>&1; then

    # List all event source mappings for the function
    echo "Looking for event source mappings..."
    MAPPINGS=$(aws lambda list-event-source-mappings \
        --function-name LambdaToKafka \
        --region "$REGION" \
        --profile "$PROFILE" \
        --endpoint-url "$ENDPOINT" \
        --query 'EventSourceMappings[].UUID' \
        --output text)

    for UUID in $MAPPINGS; do
        echo "Deleting event source mapping: $UUID"
        aws lambda delete-event-source-mapping \
            --uuid "$UUID" \
            --region "$REGION" \
            --profile "$PROFILE" \
            --endpoint-url "$ENDPOINT"
    done

    echo "Deleting Lambda function LambdaToKafka..."
    aws lambda delete-function \
        --function-name LambdaToKafka \
        --region "$REGION" \
        --profile "$PROFILE" \
        --endpoint-url "$ENDPOINT"
else
    echo "Lambda function LambdaToKafka does not exist. Skipping."
fi

echo "Deleting existing Kafka clusters..."
CLUSTERS=$(aws kafka list-clusters \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'ClusterInfoList[].ClusterArn' \
  --output text)

for CLUSTER_ARN in $CLUSTERS; do
  echo "Deleting cluster: $CLUSTER_ARN"
  aws kafka delete-cluster \
    --cluster-arn "$CLUSTER_ARN" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" \
    --profile "$PROFILE"
done

# Give some time for deletion (even if mocked)
sleep 2

echo "Deleting existing security groups..."
SG_IDS=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'SecurityGroups[].GroupId' \
  --output text)

for SG_ID in $SG_IDS; do
  echo "Deleting Security Group: $SG_ID"
  aws ec2 delete-security-group \
    --group-id "$SG_ID" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" \
    --profile "$PROFILE" || true
done

echo "Deleting existing subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'Subnets[].SubnetId' \
  --output text)

for SUBNET_ID in $SUBNET_IDS; do
  echo "Deleting Subnet: $SUBNET_ID"
  aws ec2 delete-subnet \
    --subnet-id "$SUBNET_ID" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" \
    --profile "$PROFILE" || true
done

echo "Deleting existing VPCs..."
VPC_IDS=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'Vpcs[].VpcId' \
  --output text)

for VPC_ID in $VPC_IDS; do
  echo "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" \
    --profile "$PROFILE" || true
done

echo "Creating new VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'Vpc.VpcId' \
  --output text)
echo "Created VPC: $VPC_ID"

echo "Creating Subnet 1 in us-east-1a..."
SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'Subnet.SubnetId' \
  --output text)
echo "Created Subnet 1: $SUBNET_1"

echo "Creating Subnet 2 in us-east-1b..."
SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'Subnet.SubnetId' \
  --output text)
echo "Created Subnet 2: $SUBNET_2"

echo "Creating new Security Group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name kafka-sg \
  --description "Kafka SG for MSK in LocalStack" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --profile "$PROFILE" \
  --query 'GroupId' \
  --output text)
echo "Created Security Group: $SG_ID"

echo "Generating broker-config.json..."
cat <<EOF > "$OUTPUT_FILE"
{
  "BrokerAZDistribution": "DEFAULT",
  "ClientSubnets": ["$SUBNET_1", "$SUBNET_2"],
  "InstanceType": "kafka.m5.large",
  "SecurityGroups": ["$SG_ID"],
  "StorageInfo": {
    "EbsStorageInfo": {
      "VolumeSize": 1000
    }
  }
}
EOF

echo "✅ Cleaned and generated new $OUTPUT_FILE"

# Create Kafka cluster
echo "Creating Kafka cluster..."
aws kafka create-cluster \
    --cluster-name my-kafka-cluster \
    --kafka-version 2.8.0 \
    --broker-node-group-info file://broker-config.json \
    --number-of-broker-nodes 2 \
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
    --topic cancel-order

kafka-topics --create \
    --bootstrap-server localhost.localstack.cloud:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic process-cancellation

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