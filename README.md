# Kafka Brownbag

## Setup

In the examples below I'll be using the [Confluent Docker environment](https://docs.confluent.io/current/installation/docker/docs/quickstart.html#getting-started-with-docker-compose). This provides a running Confluent Kafka system using Docker.

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

**Producers** send data to Kafka, which then writes the data to **The Log**. Later, **Consumers** can read that data in the same order in which it was sent.

### The Log

"The Log" in Kafka is a file on disk, like any other file you might have on your computers. There are two unique things about The Log, though.

1. Kafka writes data to the log in the _same order_ it receives it.
2. Kafka can not go back and change data already written to the log.

These two things combine to make The Log very useful and powerful. If you write something that reads the log you don't have to worry about data ordering, because the data is already in order. And you don't have to worry about data changing after you read it, because it can't.

Further details: 
- [The Log: What every software engineer should know about real-time data's unifying abstraction](https://engineering.linkedin.com/distributed-systems/log-what-every-software-engineer-should-know-about-real-time-datas-unifying)

#### Topics

Data in The Log is organized in to topics.

#### Retention

Data in The Log can be stored for as long as you'd like. We'll talk more about this later on.

### Producers

Producers send messages to a Topic in Kafka. Producers can connect directly to Kafka, using a Kafka client written in a wide variety of languages. Or, Producers can send data to Kafka through a HTTP proxy.

A "message" can be just about anything you want. A string, JSON, a binary-encoded bundle. Messages can also have a key, which comes in handy later when we talk about Retention.

Kafka provides a high-level API for common Producer patterns called Kafka Connect. With Connect you can easily create Producers that import data from

- Databases
- Files
- Message Queues

We won't be diving in to Connect during this browbag, but there are links in the Further Details section.

Further details: 
- []()

Demo
- Send a plain string
- Send json
- Send something with a Key

### Consumer

Consumers read messages from a Topic in Kafka. As with Producers, Consumers can connect directly to Kafka or they can use a HTTP proxy. What Consumers do with the messages is going to be up to each Consumer.

Kafka Connect also provides an API for common Consumer patterns. With Connect you can create Consumers that take data from Kafka and put it into

- Databases
- S3
- HDFS
- Files
- Message Queues

Further details: 
- []()

Demo
- Consume the topic we built in the first demo
- Show live message sending from producer to consumer

### Reliability

So far we've talked about three kinds of processes: Kafka, Producers and Consumers. And any real-world Kafka implementation will have many of each kind of process. If you've worked with multi-process applications before you probably have a lot of concerns at this point.

- What happens if a Kafka process dies?
- Can Producers send messages that are not logged?
- Can Consumers read the same message multiple times?
- Etc.

Kafka was written from the ground-up to be a fully distributed and reliable system, so many problems you've seen in distributed systems are handled.

*What happens if a Kafka process dies?*: Kafka processes are run in 'clusters' with a leader and many followers. If a process dies, the remaining members of the cluster continue to handle the load. If the leader dies, a new leader is elected. If a majority of the processes die then the cluster stops accepting new messages.

*Can Producers send messages that are not logged?*: Generally, no. Producers can choose how strict they want to be. By default they wait for confirmation that at least one Kafka process has received a message. You can be more strict, or less. This approach is generally true in Kafka, you can configure your Producers and Consumers for different reliability guarantees.

*Can Consumers read the same message multiple times?*: As with Producers, the answer is "Generally, no." When a consumer reads a message it records its 'offset' in Kafka. Think of this like a bookmark, the consumer is saying "I've read this far." If the Consumer process dies and restarts then it can pick up right where it left off. How frequently a Consumer records its offset is configurable.

## Schemas
* Data we’ve done is simple strings
	* Difficult to parse or manage
	* You’ll want to use data that can be easily used in a variety of situations
### JSON
* Widely supported, every language has a library
* Can introduce evolution problems
	* What if a optional field becomes required. Or a field that you rely on goes away
* No compression options
### Avro
* Includes a schema
	* supports evolvability 
* Has binary encoding
### Schema Registry
* Now schemas are centrally stored
* And each message in the log takes up even less space
## Use Cases
## Current Implementation
* 3 brokers
* Connect
* Schema Registry
* SSL/Plaintext
* REST Proxy?
