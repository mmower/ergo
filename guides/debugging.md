# Debugging

** THIS SECTION IS OUT OF DATE. See also `Ergo.diagnose`.

As parsers become more complex it can be difficult to work out why they fail to work properly for a given input. Ergo parsers can, by default, generate debugging information to tell you about what is happening and what decisions are being made. To use this feature call the parse function as follows:

```elixir
Ergo.parse(parser, input, debug: true)
```

The various parsers will now use `Logger.info` to record information about how they are processing their inputs.

A challenge when building parsers is accidentally creating a cycle where the parser will never finish but loop over the same input forever. For example:

```elixir
many(choice([many(ws()), char(?})]))
```

Given an input like "}}}" will never finish. The inner many clause will always succeed with 0 whitespace characters and never actually process the `char` parser at all. You wouldn't deliberately set out to write such a parser but it can happen or at least it seems to happen to me.

For this reason Ergo implements cycle detection. Parsers with the `track: true` option (which includes most of the combinator parsers) record in the context when they have run and the current index into the input. If the same parser is run a second time on the same input we know we have hit a cycle and an `Ergo.Context.CycleError` will be raised.
