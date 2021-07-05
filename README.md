# Ergo
## Elixir Parser Combinators
## Author: Matt Mower <matt@theartofnavigation.co.uk>
## Version: 0.1.0

Ergo is an Elixir language parser combinator library. The name 'ego' means 'therefore' means 'for that reason' which seemed appropriate for a parser.

There are already at least two mature parser combinator libraries for Elixir: NimbleParsec and ExSpirit so why write another one?

First I am learning about writing parsers with parser combinators and implementing my own seemed like a good way to learn more. The code of both NimbleParsec and ExSpirit is, given my Elixir aptitude, a little hard to digest. That said, if you have serious parsing intentions you should probably be using one of them and not Ergo which is likely to be incomplete, buggier, and less performant.

Also note that this is the second attempt I've made at building such a library. The first, Epic, was not completed and, on reflection, not good maintanable code. I did, however, learn a great deal in building it and that learning has put Ergo on a much firmer footing.

## Introduction

A parser is something that reads an input, validates it, and transforms it into a datastructure. A simple parser might be something that could read digits like 0, 1, 2 and transform them into a number

    parse("12") -> 12

we might call this parser `integer`.

    integer("12") -> 12
    
To parse an expression like "12+12" we would also need a parser that could parse operators like `+`. Let's call that one `operator` and have it return an atom representing operations like `+`, `-`, `/`, and `*`.

So we might have:

    parse("12+12") -> integer("12") + operator("+") + integer("12") -> 12 :+ 12
    
Since we don't really have a plus operator for parsers we might instead introduce the notion of a sequence of parsers:

    [integer("12"), operator("+"), integer("12")] -> [12, :+, 12]
    
If we were to introduce a parser that ran other parsers in sequence, and called it `sequence` we might end up with something like:

    binary_integer_expression = sequence([integer, operator, integer])
    
In this way we have __combined__ the parsers `sequence`, `integer`, and `operator` to form a high-lever parser `binary_integer_expression` this combination is at the heart of parser combinators. In this language `binary_integer_expression` is a combinator since it combines lower-level parsers. `sequence` too is a combinator for the same reason.

For such a simple operation you might more naturally turn to a regular expression but with parser combinators we can create very complex parsers that would be unmanagable as a regular expression.

Ergo provides a number of useful parser combinators (parsers that take other parsers as paramaters) and terminal parsers (parsers which do not take other parsers) to build complex parsers.

For exmaple:

sequence, choice, many, optional, ignore

char (in many different forms), literal, digit, alpha, and so on.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ergo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ergo, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ergo](https://hexdocs.pm/ergo).
