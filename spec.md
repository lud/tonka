# Spec

* No authentication or account management. Jobs are dispatched internally via
  schedulers, externally via account providers or message queues. Direct calls
  via HTTP API have to be autenthicated with access tokens. We may accept login
  via identity tokens and Slack auth.
* No distributed user throttling. Users operators will be started on a single
  node, distribution will allow to handle load for multiple accounts.
* Regular throttling must be implemented at the data ingestion level : either
  put a rate limit on an API or in a message queue producer.

## Data

* Project configuration
* Project credentials
* Input Events
* Managed Data: Issues, Commits, Changelogs

## Functions

There are two types of functions in this app.

* Data Transformers: they take an input, executes some side-effects and produce
  an output. They are executed within a grid instance. They are not pure
  functions as the main purpose of this application is to genereate
  side-effects.
* Event Generators: they execute because of an external event (Webhook, API
  call, message queue) or an internal one (scheduler) and start a grid instance
  with the event as an input.

## Execution

When starting, the application must load all defined projects and start the
event generators of those projects.

When an event generator fires, it targets a project and a grid. This project's
grid is loaded to create a new operator (implementing a grid instance). The grid
receives the input and executes all operations in the grid that can be executed
from that input.
