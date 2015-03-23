KV
==

Example of Elixir Key-Value store

=======

## Mix Examples

### Create a new project with `mix`
```
$ mix new kv --module KV
* creating README.md
* creating .gitignore
* creating mix.exs
* creating config
* creating config/config.exs
* creating lib
* creating lib/kv.ex
* creating test
* creating test/test_helper.exs
* creating test/kv_test.exs

Your mix project was created successfully.
You can use mix to compile it, test it, and more:

    cd kv
    mix test

Run `mix help` for more commands.
```

### Run `mix` commands
```
$ cd kv

$ mix compile
Compiled lib/kv.ex
Generated kv.app

$ mix test
Compiled lib/kv.ex
Generated kv.app
.

Finished in 0.04 seconds (0.04s on load, 0.00s on tests)
1 test, 0 failures

Randomized with seed 708105

$ mix test test/kv_test.exs:5
Including tags: [line: "5"]
Excluding tags: [:test]

.

Finished in 0.03 seconds (0.03s on load, 0.00s on tests)
1 test, 0 failures

Randomized with seed 311401
```

### Start `mix` session in `iex`
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> 
```

=======

## Terms

### General

*  "project": Mix project, may be an umbrella project containing multiple applications
*  "application": OTP Application
*  ETS: Erlang Term Storage, data persistence and caching mechanism

### OTP

*  Agent: simple wrappers around state
*  GenServer: "generic servers" aka processes that encapsulate state, provide sync/async calls,
   code reload, etc
*  GenEvent: "generic event" managers that allow publishing events to multiple handlers/listeners
*  Task: Asynchronous units of computation that allow spawning a process and easily retrieving its
   result at a later time

=======

## General Rules

*  Never convert user input to atoms (fills name registry facility aka memory)
*  Avoid creating new processes directory, instead delegate to supervisor
*  Don't resort to ETS prematurely, but only after identifying/logging to
   discover bottlenecks

=======

## Agents

### Spawn an Agent
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> {:ok, agent} = Agent.start_link fn -> [] end
{:ok, #PID<0.84.0>}
iex(2)> Agent.update(agent, fn list -> ["eggs"|list] end)
:ok
iex(3)> Agent.get(agent, fn list -> list end)
["eggs"]
iex(4)> Agent.stop(agent)
:ok
```

=======

## Monitors

### Monitor a process
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> {:ok, pid} = KV.Bucket.start_link
{:ok, #PID<0.84.0>}
iex(2)> Process.monitor(pid)
#Reference<0.0.0.397>
iex(3)> Agent.stop(pid)
:ok
iex(4)> flush()
{:DOWN, #Reference<0.0.0.397>, :process, #PID<0.84.0>, :normal}
:ok
```

### Notes about monitors

*  "monitors" are references, uni-directional, only monitoring processes receive notifications
*  "links" are pids, bi-directional, crashes unless trapping exits

Use links when you want linked crashes, use monitors when you just want to be informed of crashes, exits, etc.

=======

## Event Managers

### Start event manager and accept notifications
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> {:ok, manager} = GenEvent.start_link
{:ok, #PID<0.84.0>}
iex(2)> GenEvent.sync_notify(manager, :hello)
:ok
iex(3)> GenEvent.notify(manager, :world)
:ok
```

### Add an event handler
```
iex(4)> defmodule Forwarder do
...(4)>   use GenEvent
...(4)>   def handle_event(event, parent) do
...(4)>     send parent, event
...(4)>     {:ok, parent}
...(4)>   end
...(4)> end
{:module, Forwarder,
 <<70, 79, 82, 49, 0, 0, 9, 196, 66, 69, 65, 77, 69, 120, 68, 99, 0, 0, 2, 10, 131, 104, 2, 100, 0, 14, 101, 108, 105, 120, 105, 114, 95, 100, 111, 99, 115, 95, 118, 49, 108, 0, 0, 0, 2, 104, 2, ...>>,
 {:handle_event, 2}}
```

### Attach handler and get event notifications
```
iex(5)> GenEvent.add_handler(manager, Forwarder, self())
:ok
iex(6)> GenEvent.sync_notify(manager, {:hello, :world})
:ok
iex(7)> flush()
{:hello, :world}
:ok
```

### OTP Behaviour

*  `handle_event/2`: handle event
*  `add_handler/3`: add event handler
*  `add_mon_handler/3`: add event handler and monitor process, if process dies removes event handler

### Notes about events

*  Event handlers run in the same process as the event manager
*  `sync_notify/2` runs event handlers synchronously to the request (recommended method)
*  `notify/2` runs event handlers asynchronously

Pass event manager pid/name to start_link to de-couple the start of the event manager from the start of the registry,
as opposed to starting event manager when registry is started.

=======

## Misc concepts

### "Server"/"Client" processes
```
def delete(bucket, key) do
  Agent.get_and_update(bucket, &HashDict.pop(&1, key))
end

## expands into

def delete(bucket, key) do
  Agent.get_and_update(bucket, fn dict ->
    HashDict.pop(dict, key)
  end)
end

## expanded with sleep

def delete(bucket, key) do
  :timer.sleep(1000) # puts client to sleep
  Agent.get_and_update(bucket, fn dict ->
    :timer.sleep(1000) # puts server to sleep
    HashDict.pop(dict, key)
  end)
end
```

=======

## GenServer

### OTP Behaviour

*  `handle_call/3`: sync, recommended to help create server "backpressure"
*  `handle_cast/2`: async, use sparingly
*  `handle_info/2`: all other messages from send/2, etc

=======

## Event streams

## Spawn a process to handle blocking on an event stream
```
$iex
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> {:ok, manager} = GenEvent.start_link
{:ok, #PID<0.60.0>}
iex(2)> spawn_link fn ->
...(2)>   for x <- GenEvent.stream(manager), do: IO.inspect(x)
...(2)> end
#PID<0.64.0>
iex(3)> GenEvent.notify(manager, {:hello, :world})
{:hello, :world}
:ok
```

=======

## Supervisor

### Spawn a supervisor which control other servers / processes
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Compiled lib/kv/supervisor.ex
Compiled lib/kv/registry.ex
Generated kv.app
Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> KV.Supervisor.start_link
{:ok, #PID<0.99.0>}
iex(2)> KV.Registry.create(KV.Registry, "shopping")
:ok
iex(3)> KV.Registry.lookup(KV.Registry, "shopping")
{:ok, #PID<0.103.0>}
```

### OTP Behaviour

*  `worker/2`
*  `supervisor/2`
*  `supervise/2`

### Notes on Bucket Supervisor

*  call `KV.Bucket.Supervisor.start_bucket/1` instead of `KV.Bucket.start_link` in `KV.Registry`
*  mark worker as `:temporary`, ie if bucket dies it won't be restarted
*  use supervisor only to group buckets, the registry is always used to create buckets

```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Compiled lib/kv/bucket/supervisor.ex
Generated kv.app
Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> {:ok, sup} = KV.Bucket.Supervisor.start_link
{:ok, #PID<0.98.0>}
iex(2)> {:ok, bucket} = KV.Bucket.Supervisor.start_bucket(sup)
{:ok, #PID<0.100.0>}
iex(3)> KV.Bucket.put(bucket, "eggs", 3)
:ok
iex(4)> KV.Bucket.get(bucket, "eggs")
3
```

### Supervision trees

*  root sup [:one_for_one]
   *  event manager
   *  supervisor [:one_for_one]
      *  buckets supervisor [:simple_one_for_one]
         *  buckets
   *  registry

### Supervision strategies

*  :one_for_one
*  :one_for_all
*  :simple_one_for_one


=======

## Application

## Using an application to start supervisor
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Compiled lib/kv.ex
Compiled lib/kv/supervisor.ex
Compiled lib/kv/bucket.ex
Compiled lib/kv/registry.ex
Generated kv.app
Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> KV.Registry.create(KV.Registry, "shopping")
:ok
iex(2)> KV.Registry.lookup(KV.Registry, "shopping")
{:ok, #PID<0.116.0>}
```

## OTP Behaviour

*  `start/2`
*  `stop/1`

## Examples of starting an application
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Application.start(:kv)
{:error, {:already_started, :kv}}

$ iex -S mix run --no-start
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Application.stop(:logger)

=INFO REPORT==== 23-Mar-2015::13:41:23 ===
    application: logger
    exited: stopped
    type: temporary
:ok
iex(2)> Application.start(:kv)
{:error, {:not_started, :logger}}
iex(3)> Application.ensure_all_started(:kv)
{:ok, [:logger, :kv]}
iex(4)> Application.stop(:kv)
:ok
iex(5)> 
13:38:29.059 [info]  Application kv exited: :stopped
```

## An example generated kv_app in _build/dev/lib/kv/ebin/kv_app
```
{application, kv,
              [{registered, []},
              {description, "kv"},
              {applications, [kernel, stdlib, elixir, logger]},
              {vsn, "0.0.1"},
              {modules, ['Elixir.KV','Elixir.KV.Bucket',
                         'Elixir.KV.Registry','Elixir.KV.Supervisor']}]}
```

See: `mix help compile.app` for more info

=======

## ETS

ETS default table attributes are `:set` (unique keys) and `:protected` (only process spawning table process can read/write)

### ETS exmaple for buckets registry
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> table = :ets.new(:buckets_registry, [:set, :protected])
188435
iex(2)> :ets.insert(table, {"foo", self})
true
iex(3)> :ets.lookup(table, "foo")
[{"foo", #PID<0.109.0>}]
```

### ETS example with named table

```
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> :ets.new(:buckets_registry, [:named_table])
:buckets_registry
iex(2)> :ets.insert(:buckets_registry, {"foo", self})
true
iex(3)> :ets.lookup(:buckets_registry, "foo")
[{"foo", #PID<0.88.0>}]
```

=======

At this point `kv` application considered "complete", and will be brought into an umbrella project to be used
by a companion TCP server to handle user requests.

