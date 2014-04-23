Swappable Transports
====================

While attempting to deploy a system of interconnected microservices to Heroku
recently, I discovered that processes running in dynos in the same application
cannot talk to each other via HTTP. I had originally planned on each
microservice exposing a REST-like API - but this wasn't going to be an option
if I wanted to stick with Heroku. Much head-scratching ensued.

The solution, it turns out, is to communicate between microservices through a
centralized message broker - in my case, a Redis database (but I'll show you
how do it with RabbitMQ as well, free of charge). The design of each
microservice API has been decoupled from HTTP entirely; client/server
communication is achieved by enqueueing JSON-RPC 2.0-encoded messages in a
list, with BRPOP and return-queues used to emulate HTTP request/response
semantics. The Redis database serves as a load balancer of sorts, enabling easy
horizontal scaling of each individual microservice (in Heroku dyno) on an
as-needed basis. Redis will ensure that a message is dequeued by only a single
consumer, so you can spin up a lot of dynos without worrying that they'll
clobber each other's work. It's pretty sa-weet.
