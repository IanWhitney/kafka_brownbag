# This file shows all of the commands run in the brownbag
# It's not meant to be run as a script, it is here for reference so that you can run the same commands if you'd like.


# Start Kafka ono Docker Networke
# https://docs.confluent.io/current/installation/docker/docs/quickstart.html#docker-network
# Create a network
docker network create confluent

# Turn on zookeeper
docker run -d \
--net=confluent \
--name=zookeeper \
-e ZOOKEEPER_CLIENT_PORT=2181 \
confluentinc/cp-zookeeper:4.1.0

# Turn on Kafka
docker run -d \
--net=confluent \
--name=kafka \
-e KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181 \
-e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092 \
-e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
confluentinc/cp-kafka:4.1.0

### Topics

# Create a test topic
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
#{"json": "is neat"}

### Consumers

# First we have to get into a shell in our Kafka network
docker exec -i -t kafka /bin/bash

# Start a console consumer
# Do this in the session created in the previous step
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

# Create a shell session in our Kafka network
docker exec -i -t kafka /bin/bash

## Schemas: Avro

# This sets up a Schema Registry instance in our Docker network
docker run -d \
  --net=confluent \
  --name=schema-registry \
  -e SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL=zookeeper:2181 \
  -e SCHEMA_REGISTRY_HOST_NAME=schema-registry \
  -e SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081 \
  confluentinc/cp-schema-registry:4.1.0

# Create a shell in Schema Registry
docker run -it --net=confluent --rm confluentinc/cp-schema-registry:4.1.0 bash

# Producer to send messages using Avro schema
# Do this in the session created in the previous step
# This starts an interactive console. Type a message & hit enter to send.
# ctrl-c to quit the console
kafka-avro-console-producer \
  --broker-list kafka:9092 \
  --topic names \
  --property schema.registry.url=http://schema-registry:8081 \
  --property key.separator=":" \
  --property parse.key=true \
  --property key.schema='{"type":"string"}' \
  --property value.schema='{"type":"record","name":"PreferredName","fields":[{"name":"first","type":["null","string"],"default":null},{"name":"last","type":["null","string"],"default":null}]}'

# Example good message:
# "2411242":{"first": {"string": "Ian"}, "last": {"string": "Whitney}}
# "2411242":{"first": null, "last": {"string": "Whitney}}
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
  --topic names \
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
  --topic names \
  --from-beginning \
  --property print.key=true \
  --property key.separator=":" \
  --property schema.registry.url=http://schema-registry:8081

# Create a shell in Schema Registry
docker run -it --net=confluent --rm confluentinc/cp-schema-registry:4.1.0 bash

# Producer with an invalid schema
kafka-avro-console-producer \
  --broker-list kafka:9092 \
  --topic names \
  --property schema.registry.url=http://schema-registry:8081 \
  --property key.separator=":" \
  --property parse.key=true \
  --property key.schema='{"type":"string"}' \
  --property value.schema=
  
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"record\",\"name\":\"StudentName\",\"fields\":[{\"name\": \"first\",\"type\": \"string\"},{\"name\": \"last\",\"type\": [\"null\",\"string\"],\"default\": null}]}"}' \
http://schema-registry:8081/compatibility/subjects/names-value/versions/latest


# Cleanup
# Do this at the end to clean up all the Docker Network stuff.
docker rm -f $(docker ps -a -q)
yes | docker volume prune
docker network rm confluent
