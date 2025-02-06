#!/bin/bash

kafka-topics --bootstrap-server localhost:4511 --delete --topic io.specmatic.json.request
kafka-topics --bootstrap-server localhost:4511 --delete --topic io.specmatic.json.reply

 kafka-topics --create \
    --bootstrap-server localhost:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic io.specmatic.json.request

 kafka-topics --create \
    --bootstrap-server localhost:4511 \
    --replication-factor 1 \
    --partitions 1 \
    --topic io.specmatic.json.reply

