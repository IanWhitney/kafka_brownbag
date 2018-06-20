# Kafka Brownbag

## Setup

In the examples below I'll be using the [Confluent Docker Network steps](https://docs.confluent.io/current/installation/docker/docs/quickstart.html#docker-network). This provides a running Confluent Kafka system using Docker.

I'm running Docker using Docker for Mac.

## Goals

This is what I want to cover in this brownbag.

* General concepts of Kafka
	* Producing
	* Consuming
	* Log
* Schemas
	* JSON
	* Avro
	* Schema Registry
* Use Cases
	* Live ETL
	* Event Sourcing
	* Metrics/Reporting
	* Integrations
* Campus Implementation
	* What we have
	* Governance
	* Access

At the end of the session I'll consider it a success if you:

- Know what Kafka is
- Have a high-level idea of how to get data into and out of Kafka
- Understand where Kafka can be valuable on Campus

## General Concepts

**Producers** send data to Kafka, which then writes the data to a **Topic** in **The Log**. Later, **Consumers** can read that data in the same order in which it was sent.

### The Log

"The Log" in Kafka is a file on disk, like any other file you might have on your computers. There are two unique things about The Log, though.

1. Kafka writes data to the log in the _same order_ it receives it.
2. Kafka _can not change_ data written to the log.

These two things combine to make The Log very useful and powerful. If you're reading The Log you don't have to worry about data ordering, because the data is already in order. And you don't have to worry about data changing after you read it, because it can't.

Further details: 
- [The Log: What every software engineer should know about real-time data's unifying abstraction](https://engineering.linkedin.com/distributed-systems/log-what-every-software-engineer-should-know-about-real-time-datas-unifying)
- [Turning the Database Inside Out](https://martin.kleppmann.com/2015/03/04/turning-the-database-inside-out.html)

### Topics

Data in The Log is organized in to topics. You can think of a topic like a table in a database, where all data in it has the same shape. Or you can think of a topic like a series of steps, where the order of messages matters but the shape of each message may be different.

An example of a table-like topic is Students. Each message in this topic would have the same attributes.

An example of a series-like topic is placing an order. You pick something from a store, you pay with a credit card, a shipping invoice is created, etc. Each message would look different but they need to be in an exact order.

For this quick introduction demo we're going to use a topic imaginatively named "test"

Demo:

Note: For the sake of focusing on Kafka I'm omitting some Docker commands from all of these examples. The full commands are in [`script.sh`](script.sh)

```
kafka-topics --create \
--topic test \
--partitions 1 \
--replication-factor 1 \
--if-not-exists \
--zookeeper zookeeper:2181
```

There's a lot in that command. Some highlights:

- `partitions 1` means that data will all be written to one partition. Partitioning is beyond the scope of this brownbag, but it's a way to increase the speed of data input in Kafka.
- `replication-factor 1` means that the data will only be stored by one Kafka broker. In production this would be bad, because there would be no redundancy. For this demo it's fine.
- `zookeeper` is a part of the Kafka ecosystem. We have to tell Kafka how to communicate with Zookeeper.

We can then ask Kafka for a list of our topics, just to make sure this worked

```
kafka-topics --list \
--zookeeper zookeeper:2181
```

`test` should appear in the list returned. There may be some others. Anything that starts with `__` is an internal topic used by Kafka.

Further Details:
- [Apache Kafka: Topics and Logs](http://kafka.apache.org/intro#intro_topics)

### Producers

Producers send messages to a Topic in Kafka. Producers can connect directly to Kafka, using a Kafka client written in a wide variety of languages. Or, Producers can send data to Kafka through a HTTP proxy.

A "message" can be just about anything you want. A string, JSON, a binary-encoded bundle. Messages can also have a key, which comes in handy later when we talk about Retention.

Kafka provides a high-level API for common Producer patterns called Kafka Connect. With Connect you can easily create Producers that import data in to Kafka from

- Databases
- Files
- Message Queues

We won't be diving in to Connect during this brownbag, but there are links in the Further Details section.

Demo:

We can send messages to our `test` topic in a variety of formats. We start a producer with

```
kafka-console-producer \
--broker-list localhost:29092 \
--topic test
```

Which gives us a console where we can type messages and send them by hitting Enter.

We can send a plain string:
```
>test message
```

Or JSON:
```
>{"json": "is neat"}
```

`ctrl-c` will end the producer console. But we'll leave it running for now so that we can see Producers and Consumers in action later on.

Further details:
- [Kafka Producer Architecture](https://dzone.com/articles/kafka-producer-architecture-picking-the-partition)
- [Announcing Kafka Connect](https://www.confluent.io/blog/announcing-kafka-connect-building-large-scale-low-latency-data-pipelines/)
- [Confluent: Kafka Connect](https://docs.confluent.io/current/connect/index.html)

### Consumers

Consumers read messages from a Topic in Kafka. They can start at the beginning of the Topic and read all messages, or they can start at the end and just read new messages. They make note of where they are in the topic, so that they don't read messages twice.

Multiple Consumers can read the same messages topic. Reading a message does not destroy it.

As with Producers, Consumers can connect directly to Kafka or they can use a HTTP proxy. What Consumers do with the messages is going to be up to each Consumer.

Kafka Connect also provides an API for common Consumer patterns. With Connect you can create Consumers that take data from Kafka and put it into:

- Databases
- S3
- HDFS
- Files
- Message Queues

### Demo

```
kafka-console-consumer \
--bootstrap-server kafka:9092 \
--topic test \
--from-beginning
#test message
#{"json": "is neat"}
```

The `--from-beginning` flag tells the Consumer to begin at the start of the topic, otherwise it will only read new messages.

If we go back to our producer console and add a new message

```
#>Data appears quickly
```

Then we will see that message appear over in our Consumer shell.

```
#Data appears quickly
```

Further details: 
- [Kafka Consumers: Reading Data from Kafka](https://www.safaribooksonline.com/library/view/kafka-the-definitive/9781491936153/ch04.html)
- [Announcing Kafka Connect](https://www.confluent.io/blog/announcing-kafka-connect-building-large-scale-low-latency-data-pipelines/)
- [Confluent: Kafka Connect](https://docs.confluent.io/current/connect/index.html)

#### Retention

Data in a topic can be stored for as long as you'd like. And any Consumer can read all data in a topic, regardless of if another Consumer has read it or how old the data is.

There are a few major retention options. You can retain data:

- For a certain amount of time
- Until the topic reaches a certain size
- Forever

"Forever" can be done a couple of different ways. Say we have a topic that contains your mailing address. We could set up a topic so that it retains, forever, every mailing address you've ever had. Or we could set up a topic to retain, forever, your _most recent_ mailing address.

This last option, where we keep the most recent state of a record, is called a "Compacted Topic". We're not going to talk deeply about this today, but there are links in the Further Details section.

Further Details:
- [Compacted Topics](https://dzone.com/articles/kafka-architecture-log-compaction)

### Reliability

So far we've talked about three kinds of processes: Kafka, Producers and Consumers. And any real-world Kafka implementation will have many of each kind of process. If you've worked with multi-process applications before you probably have a lot of concerns at this point.

- What happens if a Kafka process dies?
- Can Producers send messages that are not logged?
- Can Consumers read the same message multiple times?
- Etc.

Kafka was written from the ground-up to be a fully distributed and reliable system, so many problems you've seen in distributed systems are handled.

*What happens if a Kafka process dies?*: Kafka processes are run in 'clusters' with a leader and many followers. The processes aren't all on one server, they are spread across many servers in different data centers. If a process dies, the remaining members of the cluster continue to handle the load. If the leader dies, a new leader is elected. If a majority of the processes die then the cluster stops accepting new messages.

*Can Producers send messages that are not logged?*: Generally, no. Producers can choose how strict they want to be. By default they wait for confirmation that at least one Kafka process has received a message before sending another. You can be more strict, or less. For example, you can configure a Producer to not wait for confirmation at all. This makes sense for Producers that are concerned with throughput over reliability. Or you can configure your Producer to wait for 3 confirmations before proceeding; your throughput will suffer, but no messages will be lost.

This approach is generally true in Kafka -- you can tune Producers and Consumers to balance between throughput and reliability 

*Can Consumers read the same message multiple times?*: As with Producers, the answer is, "Generally, no." When a consumer reads a message it records its 'offset' in Kafka. Think of this like a bookmark, the consumer is saying "I've read this far." If the Consumer process dies and restarts then it can pick up right where it left off.

How frequently a Consumer records its offset is configurable. A Consumer that doesn't care if it accidentally reads a message twice can record its offsets less frequently. This will allow it to read messages more quickly. A Consumer that wants to read each message once can record its offset after every message. This Consumer will read more slowly, but with a guarantee that each message will be read once.

Further Details:
- [Best Practices for Apache Kafka in Production](https://www.confluent.io/online-talk/best-practices-for-apache-kafka-in-production-confluent-online-talk-series)

## Schemas & Schema Registry

So far we've sent strings and JSON in to Kafka, an in many cases this works well. But not always! Let's look at some pitfalls.

For this demo, we're going to create a new topic. We want this topic to contain student names. Each message will have a key -- the student's emplid -- and their preferred name.

```
kafka-topics --create \
--topic names \
--partitions 1 \
--replication-factor 1 \
--if-not-exists \
--zookeeper zookeeper:2181
```

We can send data in to this topic as a simple string, using some extra configuration that allows us to include the key.

```
kafka-console-producer \
--broker-list kafka:9092 \
--topic names \
--property parse.key=true \
--property key.separator=":"
#>2411242:Ian Whitney
```

This works, but we hit a problem right away --  Consumers want to know the student's first and last name. They can _guess_ at it now, but they are frequently wrong. Names are hard (see Further Details).

So, we decide to provide some structure and use JSON. Using our same Producer as above:

```
#>2411242:{"first_name": "Ian", "last_name": "Whitney"}
```

Now Consumers can read the message, parse it as JSON and easily tell which is the first name and which is the last. Great! 

But we soon hit another problem. Some of our Consumers expect that first and last name will **always** be present. But, again, names are hard and nothing is guaranteed. So when a Producer sends through a message that has no last name, some of our Consumers break. Looks like we need a way to define what fields are required in our JSON, something like a Schema.

JSON offers no official support for schemas, no way to declare which values are required or optional or what kind of data each value should contain. There is a project to develop JSON schemas but it's a proposal, not official.

If we want to use JSON schema anyway, we would need to do the following:

1. Update our Producers to validate their messages against the current schema
2. Update our Consumers to use the schema when reading data
3. Write a system for sharing schema
4. Figure out how we'd govern changes to schema

That last one is tricky. Imagine we start with a schema that declares both `last_name` and `first_name` optional. Then, after producing thousands of messages, we update our schema to declare that `first_name` is now *required* while `last_name` is optional? We have thousands of messages in our Kafka log that may or may not have `first_name` values. Are those messages now invalid?

Schemas need to evolve over time and it turns out this is hard!

There are a few different tools that solve this problem. The tool most commonly used in Kafka is Avro, an Apache project for managing data schemas, including their versioning and evolution. Many languages have Avro libraries that allow you to easily serialize and deserialize objects into and out of Avro encoding.

I'm not going to dive deeply in to the details of Avro, there are links in the Further Details section. But we can see it in action with our Student Names topic:

### Demo

We're going to create a new producer for our `names` topic. This one includes two schemas.

First, a `key.schema` that says our key is a string.

```
{"type":"string"}
```

Second, the `value.schema` declares that messages can have both first and last name strings, but that they are optional:

```
{
  "type":"record",
  "name":"StudentName",
  "fields":[
    {
      "name": "first",
      "type": [
        "null",
        "string"
      ],
      "default": null
    },
    {
      "name": "last",
      "type": [
        "null",
        "string"
      ],
      "default": null
    }
  ]
}
```

We create a producer with all of the necessary configuration:

```
kafka-avro-console-producer \
  --broker-list kafka:9092 \
  --topic names \
  --property schema.registry.url=http://schema-registry:8081 \
  --property key.separator=":" \
  --property parse.key=true \
  --property key.schema='{"type":"string"}' \
  --property value.schema='{"type":"record","name":"StudentName","fields":[{"name":"first","type":["null","string"],"default":null},{"name":"last","type":["null","string"],"default":null}]}'
```

With that running we can send a message that follows the schema:

```
"2411242":{"first": {"string": "Ian"}, "last": {"string": "Whitney}}
"2411242":{"first": null, "last": {"string": "Whitney}}
"2411242":{"first": {"string": "Ian"}, "last": null}
"2411242":{"first": null, "last": null}
```

But if we try to send a message that violates the schema, it fails.

```
"2411242":{"last": null}
#org.apache.kafka.common.errors.SerializationException: Error deserializing json {"last": null} to Avro of schema {"type":"record","name":"StudentName","fields":[{"name":"first","type":["null","string"],"default":null},{"name":"last","type":["null","string"],"default":null}]}
```

Let's take a look at the messages we've written to this topic. We can do this two different ways. First, we could use our plain Consumer that we were using for messages that didn't have schemas:

```
kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic names \
  --property print.key=true \
  --property key.separator=":" \
  --from-beginning
#2411242:IanWhitney
#2411242:Whitney
#2411242:Ian
#2411242:
```

Or we can use a new Consumer that works with Avro messages and prints them in a nicer way:

```
kafka-avro-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic names \
  --from-beginning \
  --property print.key=true \
  --property key.separator=":" \
  --property schema.registry.url=http://schema-registry:8081
"2411242":{"first":{"string":"Ian"},"last":{"string":"Whitney"}}
"2411242":{"first":null,"last":{"string":"Whitney"}}
"2411242":{"first":{"string":"Ian"},"last":null}
"2411242":{"first":null,"last":null}
```

Why do we get different responses? And what is this Schema Registry parameter we keep passing in?

When you send an Avro-encoded message you can include the encoding schema with every single message. In the Kafka topic, the message ends up looking like:

```
schema:{
  "type":"record",
  "name":"StudentName",
  "fields":[
    {"name":"first","type":["null","string"],"default": null},
    {"name":"last","type":["null","string"],"default": null}
  ]
},
value:{
  "first":"Ian",
  "last":"Whitney"
}
```

This works, but it introduces a few problems. First, schemas don't change all that often, so including it with every message is redundant. And it increases the size of each message, which might affect how many messages you can store and how quickly they can be saved. The schema in our example is quite small, but imagine the complexity with larger schemas.

A centralized service that stores and retrieves schemas solves these problems. Instead of the Producer including the full schema with each message, they can include only the schema's unique id. And when a Consumer reads a message, they can get the schema from the central service.

Confluent, a Kafka vendor run by the creators and maintainers of Kafka, provides an open source Schema Registry that does all of these things, and more.

Following our last example we realize that our schema for Student Names is too permissive. We decide that last name can be optional, but first name is required. We create a new Producer

```
{
  "type":"record",
  "name":"StudentName",
  "fields":[
    {
      "name": "first",
      "type": "string"
    },
    {
      "name": "last",
      "type": [
        "null",
        "string"
      ],
      "default": null
    }
  ]
}
```

Before we change our schema, we can ask the Schema Registry if our new version is compatible with our old one. If it's not then we could make all of our existing messages invalid.

```
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"record\",\"name\":\"StudentName\",\"fields\":[{\"name\": \"first\",\"type\": \"string\"},{\"name\": \"last\",\"type\": [\"null\",\"string\"],\"default\": null}]}"}' \
http://schema-registry:8081/compatibility/subjects/names-value/versions/latest
```

This returns

```
{"is_compatible":false}
```

It's not compatible for the reason we mentioned earlier. If first name has been optional up until now, making it required going forward means that consumers using the new schema will not be able to read the old messages.

### Further Details
- [Falsehoods Programmers Believe About Names](https://www.kalzumeus.com/2010/06/17/falsehoods-programmers-believe-about-names/)
- [JSON Schema](http://json-schema.org)
- [Schema evolution in Avro, Protocol Buffers and Thrift](http://martin.kleppmann.com/2012/12/05/schema-evolution-in-avro-protocol-buffers-thrift.html)
- [Avro](https://avro.apache.org)
- [Confluent Schema Registry](https://docs.confluent.io/current/schema-registry/docs/index.html)
- [Yes, Virginia, You Really Do Need a Schema Registry](https://www.confluent.io/blog/schema-registry-kafka-stream-processing-yes-virginia-you-really-need-one/)

## Use Cases

In my day to day work I see many places where Kafka could be used on campus. After this brief intro you may see other options.

### Live ETL

We currently have dozens (hundreds?) of nightly batch jobs that copy data from one database to another. With Kafka there's the ability to copy data from Database A to Database B as soon as Database A changes. Instead of working with yesterday's data, we could be working with _now_'s data.

### Event Sourcing

Goldy Gohpreson logs in to MyU and changes her degree from a BA in Astrophysics to a BA in History of Science. That's an important event! And it should kick off a bunch of subsequent events, an email to the History of Science department, a notification for her advisor in APLUS, a recalculation of her degree progress in her new degree, and more.

Currently the event goes unannounced, though. By announcing events in Kafka we can have a log of events that other applications can use. And it doesn't just have to be student events, either.

- A faculty member has entered grades
- A new ticket is in your service now queue
- Syslog alerts

### Metrics/Reporting

How many people responded to your college's marketing email? What's the slowest query users run against your database? Feeding data in to Kafka lets you analyze these things.

### Integrations

Vendor A can POST you JSON but Vendor B needs that data in XML. Kafka solves these problems well. Write a Producer that puts that JSON in to Kafka as Avro. Then write a Consumer to read the data and POST it back out in XML. Thanks to Avro and schemas you can be sure that the data always has the attributes you need.

## Current Implementation

Kafka isn't one tool, it's a collection of tools. And every implementation of Kafka will be different, meeting the needs of its customers. Here's what we currently have on campus.

### A 3-broker Kafka cluster

3 Kafka processes allow us to do rolling restarts, meaning zero-downtime upgrades. And it allows for one of the processes to die without any impact on the others.

We have not load-tested our current brokers, but our guess is that we can handle millions of messages per day without any performance problems.
### Distributed Kafka Connect

Kafka Connect makes it easy to create Producers and Consumers that follow common patterns. Our implementation of Kafka Connect can run across multiple hosts, giving us redundancy. So far we've only had need to use a single host, but adding additional hosts should be easy.

### Schema Registry

A single source for Avro schema, to be used by both Producers and Schemas.

### SSL or Plaintext

Kafka Producers and Consumers can choose to communicate with the cluster over SSL or Plaintext. SSL is slower, but encrypts data during network transmission. We favor SSL, but there are use-cases where Plaintext makes sense.

### REST Proxy?

We are experimenting with the REST Proxy, which allows Producers and Consumers to communicate with Kafka over HTTP instead of over Kafka's custom TCP protocol. We are still exploring this option.

## Not Yet Implemented

So far we've implemented the parts of Kafka we need. But there are other tools that we have not yet turned on.

### Authentication

Kafka supports both TLS and Kerberos-based authentication. We have not yet turned on either, but would like to experiment with TLS authentication.

### Authorization

Once authentication is in place, Kafka uses standard Access Control Lists to handle Authorization. Who can read data from what topic, etc.

### KSQL

KSQL is a new part of the Kafka ecosystem that lets you query data in Kafka as if it were in a standard relational database. We need to upgrade our Kafka cluster to get KSQL support and we hope to do that soon.

Further details: 
- [Encryption and Authentication with SSL](https://docs.confluent.io/current/kafka/authentication_ssl.html)
- [Authorization and ACLs](https://docs.confluent.io/current/kafka/authorization.html)
- [KSQL In Action](https://www.confluent.io/blog/ksql-in-action-enriching-csv-events-with-data-from-rdbms-into-AWS/)
