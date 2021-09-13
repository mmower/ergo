# Comparisons with other libraries

There are already at least two mature parser combinator libraries for Elixir: [NimbleParsec](https://github.com/dashbitco/nimble_parsec) and [ExSpirit](https://github.com/OvermindDL1/ex_spirit) so why write another one?

First I am learning about writing parsers with parser combinators and implementing my own seemed like a good way to learn more. I was especially motivated by Saša Jurić's talk where he [builds up parser combinators from the ground up](https://www.youtube.com/watch?v=xNzoerDljjo). Ergo owes quite a lot to his style.

Second the code of both ExSpirit & NimbleParsec is, given my relatively limited experience of Elixir, a little hard to digest. I wanted to handle errors better than I'd seen in any of their examples (which seemed to ignore this issue) and finding the code hard to understand made it difficult to do that.

So there are some notable differences between Ergo and NP/ExS that perhaps justify its existence:

Firstly, and perhaps most difficult to notice, is that Ergo is implemented in terms of functions only, while ExS/NP both make significant use of macros. My understanding is not sophisticated enough to understand quite what the macros are buying the user but I was able to do without them. But I find the Ergo code relatively easy to read after writing it.

Second Ergo is built with error handling as one of its priorities. Internally, Ergo parsers are not bare functions but `Parser` structs that assist with debugging. This takes the form of logging parser operations and cycle detection. See further down for more information.

Lastly, ExS/NP make heavy use of the Elixir `|>` operator to combine parsers together, for example:

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
        literal("Act", map: fn _ast -> :act end),
        ignore(whitespace),
        id,
        ignore(whitespace),
        ignore(char(?)),
        ignore(whitespace),
        optional(attribtues),
        ignore(whitespace),
        many(scene),
        ignore(whitespace),
        ignore(char(?}))
    ])
```

Perhaps unsurprisingly I prefer the Ergo style.

That said, if you have serious parsing intentions you should probably be using one of NimbleParsec or ExSpirit instead of Ergo. Ergo is likely less complete, less reliable, and certainly less performant than either of those more established libraries.
