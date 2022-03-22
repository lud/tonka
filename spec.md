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


## Multiple inputs concurrency

To prevent multiples inputs for the same grid instance to be run at the same
time, a Project process should manage a registry of concurrent running jobs.

* On application start, all projects are started as processes. They will build
  the base container and services.
* The project has a supervisor for process-based services and holds two
  registries. One registry for those services and one for the input jobs.
* When an input job runs, it tries to register on the input jobs registry and
  checks out a full context from the project process: the initialized container
  and the targetted grid configuration. Checking that data involves a lot of
  copying but project configurations are actually small YAML files.
* The registered name is simply the grid instance ID.
* If the name registration succeeds, the job will run.
* If the name registration fails, it means that the project is not fully
  initialized yet (the job registry must be the last child to be set up) or that
  another input job is running for this instance. In both case we can snooze the
  job.
* Jobs may unregister eagerly on termination.


## Data

* Project configuration
* Project credentials
* Input Events
* Managed Data: Issues, Commits, Changelogs


## Functions

There are two types of functions in this app.

* Data Actions: they take an input, executes some side-effects and produce
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
receives the input and executes all actions in the grid that can be executed
from that input.


## Issues Fetching & Caching

Previous iterations of the project used a local cache of all issues. This was
made in hope we could create a slack command that would list issues very
quickly.  Without that cache, each command requires the issues to be fetched
again.

Caching also provided simple webhook handling since on webhooks calls we would
immediately fetch the issue and have it ready for further queries.

Without caching, there is less work to do: only implement the fetch and filter.
Webhooks can be safely ignored because issues are always fetched.

The problem is that we want to handle webhooks because we want to send alerts
when issues are updated and do not conform to rules (proper labels, proper
assignment, etc.).  The webhook can be implemented as an event generator that
pushes and input to a grid.

If we want to cache all the issues locally we will need an inter-service event
system, where a service or event generator can emit an event, and other services
can subscribe to.  But then the issues store must also emit an input event to
trigger the alert grid.  This makes everything more complex and intricate, but
we may have to implement this if we want to work with very large projects and
implement slack commands.

There are ways to minimize complexity of each service by adding a new service
that handles the event listening, issues sources refetch calls, and inputs
creation.


## Layout definition YAML for inputs

We need to define actions as follows in the project layout.

Each input is mapped to an origin. It can be an action output, or it can
be a litteral value.

The input specs from an action must define the possible origins for each
input.  Some inputs may only originate from an action, others only from a
literal value (which should then be a param, but whatever).

If the action defines an input to be a static, it must export a
cast_input(:my_key, term) function that will return a term of the expected
type.

In the UI, the literal inputs my be embedded into the configuration of an
action, along with the params.

We need the params to build the inject specs, so we can select a service based
on a name. Some project may define two issues sources, for instance Github and
Gitlab, so we need a param to tell which one to use.

    inject:
      source: my_issues_source
    params:
      credentials: gitlab.token
    inputs:
      vars:
        origin: action
        action: my_other_act
      report:
        origin: static
        static: {some: data}


## Events & Webhooks

Some services can ask the webhooks service for injection, and register a webhook
listener with a suffix in their build callback.

For instance, registering the `gitlab` suffix would receive webhooks sent to
`http://<host>/webhooks/<project_slug>/gitlab`.

This will be tipically done by the gitlab issues source service. But the service
that actually needs the event is the issue store, who will then ask the issues
sources to refetch the issue. We also want to trigger a grid when an issue is
updated, but to prevent races conditions where the issues store would receive
the event after the grid start and would give a stale issue, we want the store
itself to also publish an "issue was updated" event, and that event would be the
one who triggers the grid.

Webhooks are a specific part of the application, they are not mere events
because they use the HTTP endpoint which is shared by all projects. When
registering a webhook, a service registers a callback that is supposed to cast
the webhook to an event or ignore it. Webhooks are delivered to the project
process on all nodes using `Phoenix.PubSub`.

After casting the webhook to an event, the project will dispatch the event to
the project's local `Ark.PubSub`.

Other services can subscribe to the local pubsub and receive those events. Event
listeners are process-based: if a service listens to an event in their build
callback, that event will be handled by the project process. The project process
only uses events to start grid, so there are chances that other events will be
discarded as not grid pipe will be found in the project settings.

Process-based services will receive the event delivered as a message to their
process.
