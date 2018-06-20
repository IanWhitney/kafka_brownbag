# This file shows all of the commands run in the brownbag
# It's not meant to be run as a script, it is here for reference so that you can run the same commands if you'd like.

# Start Kafka on Docker Network
script/start

### Topics

# Create a test topic
# Run this from your own terminal
docker run \
--net=confluent \
--rm confluentinc/cp-kafka:4.1.0 \
kafka-topics --create \
--topic test \
--partitions 1 \
--replication-factor 1 \
--if-not-exists \
--zookeeper zookeeper:2181

# Show the topic list
# Run this from your own terminal
docker run \
--net=confluent \
--rm confluentinc/cp-kafka:4.1.0 \
kafka-topics --list \
--zookeeper zookeeper:2181

### Producers

# First we have to get into a shell in our Kafka network
docker exec -i -t kafka /bin/bash

# Start a console producer
# Do this in the session created in the previous step
# This starts an interactive console. Type a message & hit enter to send.
# ctrl-c to quit the console
kafka-console-producer \
--broker-list kafka:9092 \
--topic test

# send some data to it
# test message
# {"json": "is neat"}

### Consumers

# Start a console consumer
# Run this from your own terminal
# This starts a running process that shows messages as they arrive.
# ctrl-c to quit the process
docker run \
--net=confluent \
--rm confluentinc/cp-kafka:4.1.0 \
kafka-console-consumer \
--bootstrap-server kafka:9092 \
--topic test \
--from-beginning

### Schemas

# Creates the names topic
# Run this from your own terminal
docker run \
--net=confluent \
--rm confluentinc/cp-kafka:4.1.0 \
kafka-topics --create \
--topic names \
--partitions 1 \
--replication-factor 1 \
--if-not-exists \
--zookeeper zookeeper:2181

# Create a shell session in our Kafka network
docker exec -i -t kafka /bin/bash

# Producer to send a key/value string message
# Do this in the session created in the previous step
# This starts an interactive console. Type a message & hit enter to send.
# ctrl-c to quit the console
kafka-console-producer \
--broker-list kafka:9092 \
--topic names \
--property parse.key=true \
--property key.separator=":"

# Start a console consumer
# Run this from your own terminal
# This starts a running process that shows messages as they arrive.
# ctrl-c to quit the process
docker run \
--net=confluent \
--rm confluentinc/cp-kafka:4.1.0 \
kafka-console-consumer \
--bootstrap-server kafka:9092 \
--topic names \
--from-beginning

## Schemas: Avro

# Creates the schema_names topic
# Run this from your own terminal
docker run \
--net=confluent \
--rm confluentinc/cp-kafka:4.1.0 \
kafka-topics --create \
--topic schema_names \
--partitions 1 \
--replication-factor 1 \
--if-not-exists \
--zookeeper zookeeper:2181

# Create a shell in Schema Registry
# Run this from your own terminal
docker run -it --net=confluent --rm confluentinc/cp-schema-registry:4.1.0 bash

# Producer to send messages using Avro schema
# Do this in the session created in the previous step
# This starts an interactive console. Type a message & hit enter to send.
# ctrl-c to quit the console
kafka-avro-console-producer \
  --broker-list kafka:9092 \
  --topic schema_names \
  --property schema.registry.url=http://schema-registry:8081 \
  --property key.separator=":" \
  --property parse.key=true \
  --property key.schema='{"type":"string"}' \
  --property value.schema='{"type":"record","name":"PreferredName","fields":[{"name":"first","type":["null","string"],"default":null},{"name":"last","type":["null","string"],"default":null}]}'

# Example good message:
# "2411242":{"first": {"string": "Ian"}, "last": {"string": "Whitney"}}
# "2411242":{"first": null, "last": {"string": "Whitney"}}
# "2411242":{"first": {"string": "Ian"}, "last": null}
# "2411242":{"first": null, "last": null}

# Example bad message:
# "2411242":{"last": null}

# Read a raw Avro message
# Run this from your own terminal
docker run \
  --net=confluent \
  --rm confluentinc/cp-kafka:4.1.0 \
  kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic schema_names \
  --property print.key=true \
  --property key.separator=":" \
  --from-beginning

# Read and decode a Avro message
# Run this from your own terminal
docker run \
--net=confluent \
--rm confluentinc/cp-schema-registry:4.1.0 \
kafka-avro-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic schema_names \
  --from-beginning \
  --property print.key=true \
  --property key.separator=":" \
  --property schema.registry.url=http://schema-registry:8081

# Create a shell in Schema Registry
# Run this from your own terminal
docker run -it --net=confluent --rm confluentinc/cp-schema-registry:4.1.0 bash

# Check compatibility of an invalid schema
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"record\",\"name\":\"StudentName\",\"fields\":[{\"name\": \"first\",\"type\": \"string\"},{\"name\": \"last\",\"type\": [\"null\",\"string\"],\"default\": null}]}"}' \
http://schema-registry:8081/compatibility/subjects/schema_names-value/versions/latest


# Cleanup
# Do this at the end to clean up all the Docker Network stuff.
script/stop
