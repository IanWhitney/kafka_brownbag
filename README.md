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

Data in The Log is organized in to topics. You can think of a topic like a table in a database, where all data in it has the same shape. Or you can think of a topic like a process, where the order of messages matters but the shape of each message may be different.

For this demo we're going to use a table-like topic that contains student names.

Demo:

```
docker-compose exec kafka kafka-topics --create --topic names --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:32181
```

There's a lot in that command. Some highlights:

- `partitions 1` means that data will all be written to partition. Partitioning is beyond the scope of this brownbag, but it's a way to increase the speed of data input in Kafka.
- `replication-factor 1` means that the data will only be copied to one Kafka broker. In production this would be bad, because there would be no redundancy. For this demo it's fine.
- `zookeeper` is a part of the Kafka ecosystem. We have to tell Kafka how to communicate with Zookeeper.

#### Retention

Data in The Log can be stored for as long as you'd like. There are a few major options. You can retain data:

- For a certain amount of time
- Until the log reaches a certain size
- Forever

"Forever" can be done a couple of different ways.  In our topic of student names we could keep every version of the student's name, or we could keep only the _most current_ version of the student's name. This last option, where we keep the most recent state of a record, is called a "Compacted Topic". We're not going to talk deeply about this today, but there are links in the Further Details section.

Further Details:
- [Compacted Topics]()

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

So far we've sent strings and JSON in to Kafka, an in many cases this works well. But, let's look at how these approaches can fail.

If we have a Producer that is sending student names in to Kafka we might start off with a key/message pair emplid & name. It'd look like this:

```
key: 2411242 message: Ian Whitney
```

We hit some problems right away, Consumers want to know the student's first and last name. They can _guess_ at it now, but they are frequently wrong. Names are hard (see Further Details).

So, we decide to provide some structure and use JSON. We update our Producer to send messages that look like this

```
key: 2411242 message: {first_name: Ian, last_name: Whitney} 
```

Now Consumers can easily tell which is the first name and which is the last. We soon hit another problem. Some of our Consumers expect that first and last name will **always** be present. But, again, names are hard and nothing is guaranteed. So when a Producer sends through a message that has no last name, some of our Consumers break. Looks like we need a way to define what fields are required in our JSON, something like a Schema.

JSON offers no official support for schemas, no way to declare which values are required or optional or what kind of data each value should contain. There is a project to develop JSON schemas, but it's a proposal, not official.

If we want to use JSON schema anyway, we would need to do the following:

1. Update our Producers to validate their messages against the current schema
2. Update our Consumers to use the schema when reading data
3. Write a system for sharing schema
4. Figure out how we'd govern changes to schema

That last one is tricky. What if we decide that `first_name` is now required? We have thousands of messages in our Kafka log that may or may not have `first_name` values.

You have similar problems if you want to remove a field, or change the data type, etc. Schemas need to evolve over time and it turns out this is hard!

There are a few different tools that solve this problem, but the one most commonly used in Kafka is Avro, an Apache project that supports schemas, including versioning and evolution. Also, many languages have Avro libraries that allow you to easily serialize and deserialize objects into and out of Avro encoding.

I'm not going to dive deeply in to Avro, there are links in the Further Details section.

### Demo

- Sending and receiving a message with its schema

### Schema Registry

Having the schema included with each message introduces a few problems. It's redundant and it increases the size of The Log in Kafka, which might affect how many messages you can store and how quickly you can persist them to disk.

A centralized Schema Registry solves these problems.

- Producers add schemas to the registry via http
- Messages include the schema's unique id, not the entire schema
- Consumers can retrieve the schema from the registry via http

The registry adds a new benefit as well. It will prevent a Producer from evolving a schema in an incompatible way.

### Demo

- Sending and receiving a message using Schema Registry

### Further Details
- [Falsehoods Programmers Believe About Names](https://www.kalzumeus.com/2010/06/17/falsehoods-programmers-believe-about-names/)
- [JSON Schema](http://json-schema.org)
- [Schema evolution in Avro, Protocol Buffers and Thrift](http://martin.kleppmann.com/2012/12/05/schema-evolution-in-avro-protocol-buffers-thrift.html)
- [Avro](https://avro.apache.org)
- [Confluent Schema Registry](https://docs.confluent.io/current/schema-registry/docs/index.html)

## Use Cases

In my day to day work, I see many places where Kafka could be used on campus. After this brief intro you may see other options.

### Live ETL

We currently have dozens (hundreds?) of nightly batch jobs that copy data from one database to another. With Kafka there's the ability to copy data from Database A to Database B as soon as Database A changes. Instead of working with yesterday's data, we could be working with _now_'s data.

### Event Sourcing

Goldy Gohpreson logs in to MyU and changes her degree from a BA in Astrophysics to a BA in History of Science. That's an important event! And it should kick off a bunch of subsequent events, an email to the History of Science department, a notification for her advisor in APLUS, a recalculation of her degree progress in her new degree, and more.

Currently the event goes unannounced, though. By announcing events in Kafka we can have a log of events that other applications can use. And it doesn't just have to be student events, either.

- A host is at low memory
- A faculty member has entered grades
- A new ticket is in your service now queue

### Metrics/Reporting

How many people responded to your college's marketing email? What's the slowest query users run against your database? Feeding data in to Kafka lets you analyze these things.

### Integrations

Vendor A can POST you JSON, Vendor B needs that data in XML. Kafka solves these problems well. Write a Producer that puts that JSON in to Kafka as Avro. Then write a Consumer to read the data and POST it back out in XML. Thanks to Avro and schemas you can be sure that the data always has the attributes you need.

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
