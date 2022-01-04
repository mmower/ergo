# Comparisons with other libraries

There are already at least two mature parser combinator libraries for Elixir: [NimbleParsec](https://github.com/dashbitco/nimble_parsec) and [ExSpirit](https://github.com/OvermindDL1/ex_spirit) so why write another one?

First I am learning about writing parsers with parser combinators and implementing my own seemed like a good way to learn more. I was especially motivated by Saša Jurić's talk where he [builds up parser combinators from the ground up](https://www.youtube.com/watch?v=xNzoerDljjo). Ergo owes a lot to his style.

Second the code of both ExSpirit & NimbleParsec is, given my relatively limited experience of Elixir, a little hard to digest. I wanted to handle errors better than I'd seen in any of their examples (which seemed to ignore this issue) and finding the code hard to understand made it difficult to do that.

So there are some notable differences between Ergo and NP/ExS that perhaps justify its existence:

First, and maybe difficult to spot, is that Ergo is implemented almost exclusively using functions and not macros while ExS/NP both make significant use of macros. My understanding is not sophisticated enough to understand quite what the macros are buying the user of those libraries but I was able to do without them except in one case. I introduced the
`lazy()` parser combinator to handle parser recursion (I came across this when parsing values which may also be lists
of values).

Second Ergo is built with error handling as one of its priorities. As a newbie I felt the need, so internally, Ergo parsers are not bare functions but `Parser` structs that assist with debugging. This takes the form of cycle detection
and telemetry. See [debugging](debugging.md) for more information.

Third, ExS/NP make heavy use of the Elixir `|>` operator to combine parsers together, for example:

```elixir
act =
    string("Act")
    |> replace(:act)
    |> ignore(whitespace)
    |> concat(id)
    |> ignore(whitespace)
    |> ignore(char(?{))
    |> ignore(whitespace)
    |> optional(attributes)
    |> ignore(whitespace)
    |> concat(scene)
    |> repeat(ignore(whitespace) |> concat(scene))
    |> ignore(whitespace)
    |> ignore(char(?}))
    |> wrap
```

while in Ergo style you'd write:

```elixir
act =
    sequence([
        literal("Act", ast: fn _ast -> :act end),
        ignore(whitespace),
        id,
        ignore(whitespace),
        ignore(char(?{)),
        ignore(whitespace),
        optional(attribtues),
        ignore(whitespace),
        many(scene),
        ignore(whitespace),
        ignore(char(?}))
    ])
```

Perhaps unsurprisingly I prefer the Ergo style.

If you need something robust and high-performance I suspect you should be using NimbleParsec rather than Ergo. NP is written by Jose Valim himself and my understanding is that it makes good use of Elixir binary handling for performance.

If, on the other hand, you prefer the Ergo style and would benefit from the debugging support, you could try Ergo and I'd love to hear from you if you do.
