# Debugging

As parsers become more complex it can be difficult to work out why they fail to operate as expected for a given input,
even a stream of events can be difficult to work with. Ergo parses emit telemetry as they run that is then threaded into
an outline. In this was the debugging information is nested as per the parsers themselves and uninteresting information
is easily hidden to aid focusing on the output that matters.

The telemetry is implemented using the [Telemetry](https://hex.pm/packages/telemetry) package which is quite commonly
used for this purpose by other library's (e.g. Ecto). By default telemetry events are ignored. In order to save them
start the Telemetry service and get the events once parsing is complete.

```
Ergo.Telemetry.start()
%{status: :ok, id: id} = Ergo.parse(…)
Ergo.Telemetry.get_events(id)
```

The events can be inspected as a list. However it may be more useful to convert into an outline, by default an OPML
document that can be loaded into most outliners.

```
File.write("debugging.opml", Ergo.Outline.OPML.generate_opml("My ID", events))
```

# Cycles

A challenge when building parsers is accidentally creating a cycle where the parser will never finish but loop over the same input forever. For example:

```elixir
many(choice([many(ws()), char(?})]))
```

Given an input like "}}}" will never finish. The inner many clause will always succeed with 0 whitespace characters and never actually process the `char` parser at all. You wouldn't deliberately set out to write such a parser but it can happen.

For this reason Ergo implements cycle detection. If the same parser is run a second time on the same input we know we have hit a cycle and an `Ergo.Context.CycleError` will be raised.
