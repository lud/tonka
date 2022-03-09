# Spec


## Authentication & Authorization

The app does not handle authentication. If authorization is required for an HTTP
API, access tokens should be used in that case. Those tokens must be authorized
for an account or a project (an account would be better but we need to check for
permissions on projects).


## Rate Limiting

To limit the rate of consumption per account, instead of relying on having a
queue per account, we can rely on a single Oban queue for all accounts, and a
simple rate limiter.

The rate limiter implementation should follow the simple technique of time
windows demonstrated in `Ark.Drip`, but backed by an ETS table to store multiple
drippers.  In a distributed environment, this table needs to be distributed. We
can rely on a global child with erlang distribution, or `ra` for a distributed
FSM, or even just use a PostgreSQL table.

A small spec for ETS:

* The table is optimized for read concurrency, and single process write.
* The table holds two counters and two time windows for each account, a burst
  and a long. The burst is typically a maximum number per minute while the long
  is per-day.
* The dripper should be checked by Oban jobs when performing, and return a time
  to wait in case of overhead so we can leverage the snooze feature of Oban.
  This allows to scheduled jobs to be inserted, although the HTTP API could also
  run a pre-check to return a `429 Too Many Requests` error with the appropriate
  `Retry-After` header.
* Once authorized to run, a job should send an increment message to a table
  manager process that will update the table.
* The table should not be private but protected (i.e. readable by any process)
  so checking for the allowance to run does not involve the table manager. This
  can lead to overflow of authorization if too many jobs check the same value
  for the same counter concurrently, while the table manager has not yet updated
  the table. This is fine. On time window rotation, the table manager can add
  the overhead to the new time window. We do not need _exact_ limiting but
  simple limitation of resource consumption. The number of Oban workers is also
  a hard limit on concurrent jobs.
* If we want exact limiting, then the check must be made through the table
  manager.
* Sending the increment to the table manager can be a `GenServer.call` or
  `cast`. A `call` will provide more backpressure since the Oban worker will
  only be freed until the table manager has updated the table.
* The table manager should perform regular backups of the table to an external
  storage.


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
