#!/bin/bash

# Configuration
FUNCTION_NAME="LambdaToKafka"
ZIP_FILE="build/libs/aws-lambda-kafka.jar"
REGION="us-east-1"
ENDPOINT="http://localhost:4566"
PROFILE="localstack"

echo "Building updated jar..."
./gradlew clean shadowJar


echo "📦 Updating Lambda function..."
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file "fileb://$ZIP_FILE" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --endpoint-url "$ENDPOINT"


echo "✅ Lambda '$FUNCTION_NAME' redeployed successfully."
