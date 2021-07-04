# Ergo
## Elixir Parser Combinators
## Author: Matt Mower <matt@theartofnavigation.co.uk>
## Version: 0.1.0

Ergo is an Elixir language parser combinator library. The name 'ego' means 'therefore' means 'for that reason' which seemed appropriate for a parser.

There are already at least two mature parser combinator libraries for Elixir: NimbleParsec and ExSpirit so why write another one?

First I am learning about writing parsers with parser combinators and implementing my own seemed like a good way to learn more. The code of both NimbleParsec and ExSpirit is, given my Elixir aptitude, a little hard to digest. That said, if you have serious parsing intentions you should probably be using one of them and not Ergo which is likely to be incomplete, buggier, and less performant.

## Introduction

A parser is something that reads an input, validates it, and transforms it into a datastructure. A simple parser might be something that could read digits like 0, 1, 2 and transform them into a number

    parse("12") -> 12

we might call this parser `integer`.

    integer("12") -> 12
    
To parse an expression like "12+12" we would also need a parser that could parse operators like `+`. So we might have:

    parse("12+12") -> integer("12") + operator("+") + integer("12") -> 12 :+ 12
    
Since we don't really have a plus operator for parsers we might instead introduce the notion of a sequence of parsers

    [integer("12"), operator("+"), integer("12")] -> [12, :+, 12]
    
or, written another way:

    plus_operation = sequence([integer, operator, integer])
    
In this way we have __combined__ the parsers `sequence`, `integer`, and `operator` to form a high-lever parser `plus_operation` this combination is at the heart of parser combinators. In this language `plus_operation` is a combinator since it combines lower-level
parsers.

For such a simple operation you might more naturally turn to a regular expression but with parser combinators we can create very complex parsers that would be unmanagable as a regular expression.

Ergo provides a number of useful parser combinators (parsers that take other parsers as paramaters) and terminal parsers (parsers which do not take other parsers) to build complex parsers.

For exmaple:

sequence, many, optional, ignore

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
