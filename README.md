# Ergo
## Elixir Parser Combinators
## Author: Matt Mower <matt@theartofnavigation.co.uk>
## Version: 0.1.2

Ergo is an Elixir language parser combinator library. The name 'ergo' means 'therefore' means 'for that reason' which seemed appropriate for a parser.

There are already at least two mature parser combinator libraries for Elixir: [NimbleParsec](https://github.com/dashbitco/nimble_parsec) and [ExSpirit](https://github.com/OvermindDL1/ex_spirit) so why write another one?

First I am learning about writing parsers with parser combinators and implementing my own seemed like a good way to learn more. I was especially motivated by Saša Jurić's talk where he [builds up parser combinators from the ground up](https://www.youtube.com/watch?v=xNzoerDljjo). Ergo owes quite a lot to his style.

Second the code of both NimbleParsec and ExSpirit is, given my relatively limited experience of Elixir, a little hard to digest. I wanted to handle errors better than I'd seen in any of the examples (which seemed to ignore this issue) and finding the code hard to understand made it difficult to do that. Ergo is built with better error handling in mind.

There are a couple of other notable differences between Ergo and NP/ExS:

Firstly, Ergo is implemented in terms of functions only, while those libraries make significant use of macros. My understanding is not sophisticated enough to understand what the macros are buying the user.

Secondlly, NP & ExS make heavy use of the Elixir `|>` operator to combine parsers together, for example:

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

while in Ergo style you'd write:

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

Perhaps unsurprisingly I prefer the Ergo style.

That said, if you have serious parsing intentions you should probably be using one of NimbleParsec or ExSpirit instead of Ergo. Ergo is likely less complete, less reliable, and less performant than either of those more established libraries.

Also note that this is the second attempt I've made at building such a library. The first, Epic, was not completed and, on reflection, not good maintanable code. I did, however, learn a great deal in building it and that learning has put Ergo on a much firmer footing.

# Introduction

If you understand parser combinators you can safely skip this section.

The phrase __parser combinator__ sounded a little confusing when I first came across it but it's deceptively simple. It means to combine parsers together. Much as we can write a complex functions by composing together simpler functions, a library like Ergo allows us to create a complex parser by combining together simpler ones.

In Ergo we distinguish between **terminal** parsers and **combinator** parsers. The difference is that a combinator parser is parameterised by one or more other parsers (which may themselves be either a terminal or another combinator parser). Here is an example:

The terminal parser `digit` reads a single digit character (i.e. '0'..'9') from the input. We might use it like:

    digit("1") = 49

Where 49 is the ASCII code for the digit "1". The actual code for using the parser looks a little different but it's conceptually right. 

The combinator parser `many` takes the parser it is meant to use and attempts to match it repeatedly on the input:

    many(digit, "123") => [49, 50, 51]
    
Here the `digit` parser was successful 3 times and returns the code for digits '1', '2', and '3' respectively in a list. Alternatively we could have used a parser like `alpha` that parses letters.

    many(alpha, "abc") => [97, 98, 99]
    
Where of course 97-99 are the codes for the letters a-c.

Where things get interesting is when we pass combinator parsers to other combinator parsers. Let's add `sequence` which takes a list of parsers and attempt to use each in turn:

    sequence([many(alpha), many(digit)], "abc123") => [97, 98, 99, 49, 50, 51]
    
In this way we can create increasingly complex parsers by combining simpler parsers.

# Using Ergo

## Setting up to parse

Ergo parsers operate on a `Context` record that will be described in the next session but which holds both the input text to be parsed and the data that is parsed from it. To begin we need to setup a new context:

    alias Ergo.Context
    ctx = Context.new("string to be pared")
    
This `Context` `ctx` is now ready to passed into a parser. Afterwards you should check the `status` field of the context to determine whether the parser was successful or whether it encountered an error.

To create a parser you use the parser builder functions, for example:

    parser = sequence([digit(), alpha(), digit()])
    
Then call the resulting parser with the context.

    {status :ok} = parser.(ctx)
    
## The Context in detail

At the heart of Ergo is the `Context` record. All Ergo parser functions take and return a `Context`. A `Context` has the following fields:

    status
    message
    input
    index
    line
    col
    char
    ast
    
### status

Every parser sets its status to either `:ok` or a tuple whose first element is the atom `:error` and whose second element is an atom describing the error, for example: `{:error, :unexpected_char}`

### message

When a parser is returning the status `{:error, _}` it can set the message to a user-friendly description of the error.

### input

A binary containing the input remaining to be matched.

### index

The index of the next character to be matched in the input.

### line

The current line of the input the parser has reached.

### col

The current column of the input line that the parser has reached.

### ast

The data structure that the parser constructs from its input.

## Terminal Parsers

The terminal parsers are not parameterized by another parser and, in general, are low-level parsers for matching specified characters or literal sequences.

### eoi()

The `eoi` parser returns `:ok` if the input is empty otherwise returns `{:error, unexpected_eoi}`.

### char(?c)

The `char` parser when given a single character code matches that character. If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the character `c`. Otherwise it returns `status: {:error, :unexpected_char}`

Example: char(?a) matches the character 'a'

### char(?l..?h)

The `char` parser when given a range of characters. If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the matched character. Otherwise it returns `status: {:error, :unexpected_char}`

Example: char(?A..?Z) matches any uppercase letter

### char(-?c)

The `char` parser when given a negative character matches any character except the specified character and return `:ok` with the `char` and `ast` parameters set to the matched character. Otherwise it returns `status: {:error, :unexpected_char}`

Example: char(-?,) matches any character except a comma

### char([...])

The `char` parser when given a list matches a character according to the specifications in the list which can be either ?c, -?c, or [?l..?h]. If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the matched character. Otherwise it returns `status: {:error, :unexpected_char}`

Example: char([a..z, 5]) matches any lower case letter or the number 5

### digit

The `digit` parser matches a character in the range `[0..9]` from the input. If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the character code of the digit that has been matched. Otherwise it returns `status: {:error, :unexpected_char}`

### alpha

The `alpha` parser matches a character in the range `[a..z, A..Z]` from the input. If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the character code of the alpha character that has been matched. Otherwise it returns `status: {:error, :unexpected_char}`

### wc

The `wc` parser matches a word character from the input (it is equivalent to the \w regular expression). If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the character code of the alpha character that has been matched. Otherwise it returns `status: {:error, :unexpected_char}`.

### ws

The `ws` parser matches a whitespace character from the input (it is equivalent to the \s regular expression). If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the character code of the alpha character that has been matched. Otherwise it returns `status: {:error, :unexpected_char}`.

### literal(s)

The `literal` parser is given a binary string and attempts to match it against the input. If successful it returns a context with `status: :ok` with the `char` and `ast` parameters set to the string being matched. Otherwise it returns `{:error, :unexpected_char}` for the first character that doesn't match the input.

Example: literal("Ergo") matches the characters 'E', 'r', 'g', and 'o' from the input successively.

## Utility parsers

The utility parsers are technically terminal parsers, since they are not parameterised by a parser, but they are implemented in terms of some of the combinator parsers themselves and hence belong in a separate category.

### digits

The `digits` parser matches a series of digits from the input. If successful it returns with `status: :ok` and the `ast` set to a list of the digit values.

### uint

The `uint` parser matches a series of digits from the input. If successful it returns with `status: :ok` and `ast` parameter set to the integer value of the number matched.

### decimal

The `decimal` parser matches a series of digits, separated by a single '.' from the input. If successful it returns wtih `status: :ok` and `ast` set to the floating point value of the number matched.

## Combinator Parsers

The combinator parsers are structural parsers that are parameterised with other parsers to match more complex structures.

### sequence

The `sequence/2` parser is used to match a given set of parsers in sequence.

Example:

    p = sequence([literal("Hello"), char(?\s), literal("World")])
    p.(Context.new("Hello World")) => %{status: :ok, ast: ["Hello", ' ', "World"]}
    
    The parser p will match first the literal "Hello" then a single space and then the literal "World". If any of these parsers fail, the sequence parser will fail. This example would more simply be written literal("Hello World") but more complex examples will use other combinator parsers in the sequence.
    
Optional arguments:

    map: fn ast -> ast
    
    Provide a function that transforms the sequence ast into another form. For example to transform the elements of the list ast into a record type.
    
    debug: true|false
    
    When the sequence parser runs it logs debugging information.
    
    label: <<binary>>
    
    Provide a label that can be logged by setting debug: true

### choice

The `choice/2` parser is used to match one from a sequence of parsers. It attempts to match the input against each parser in turn. The first parser that matches will cause `choice` to succeed with the `ast` set to the `ast` of the matching parser. If all of the parsers fail to match the input then `choice` will fail.

Signature:
    choice([parser1 | [parser2 | ...]], args \\ [])

Example:

    p = choice([literal("Hello"), literal("World")])
    p.(Context.new("Hello World")) -> %{status: :ok, ast: "Hello", input: " World"}    
    p.(Context.new("World Hello")) -> %{status: :ok, ast: "World", input: " Hello"}
    
    boolean = choice([literal("true"), literal("false")], map: fn ast -> ast == "true" end)
    boolean.(Context.new("true")) -> %{status: ok, ast: true, input: ""}
    boolean.(Context.new("false)) -> %{status: ok, ast: false, input: ""}
    booealn.(Context.new("Hello)) -> %{status: {:error, ...}, input: "Hello"}
    
### many

The `many/2` parser is used to match another parser repeatedly on the input. In its default form that can be zero times (i.e. no matches) or infinite matches. However using the `:min` and `:max` optional arguments allow limits to be specified.

Signature:
    many(parser, args \\ [])
    
Example:

    p = many(char(?\s), min: 1)
    p.(Context.new("    ")) -> %{status: :ok, input: ""}
    
    p = many(char(?\s), min: 2)
    p.(Context.new(" Hello")) -> %{status: {:error, ...}, input: " Hello"}
    
    p = many(char(?a..?z), max: 2)
    p.(Context.new("Hello World)) -> %{status: :ok, ast: ['H', 'e'], input: "llo World"}
    
    p = many(char(?a..?z), map: fn ast -> Enum.count(ast) end)
    p.(Context.new("Hello")) -> %{status: :ok, ast: 5, input: ""}

### optional

The `optional/1` parser is used to match another parser on the input and succeeds if it doesn't match or matches once.

### ignore

The `ignore/1` parser is designed for use with parsers such as `sequence` and `many`. It takes a parser and attempts to match it on the input however, if it succeeds, it returns a nil `ast` value that parsers can use to ignore it.

### transform

The `transform/2` parser is used to change the `ast` returned by another parser if the other parser is successful. It is useful for modifying the output of parsers that do not directly support a `map` argument.

Signature:
    squared = transform(uint(), fn ast -> ast * ast end)
    squared.(Context.new("10")) -> %{status: :ok, ast: 100}

### lookahead

The `lookahead/1` parser attempts to match the parser it is given on the input. If it succeeds it returns with `status: :ok` but `ast: nil` and with the input unchanged. Otherwise it returns with `status: {:error, :lookahead_fail}`.

    p = lookahead(literal("Hello"))
    p.(Context.new("Hello World")) -> %{status: :ok, input: "Hello World"}
    
### not_lookahed

The `not_lookahead/1` parser is the inverse of the `looakahead` parser in that it attempts to match its parser on the input and where it can do so it returns with `status: {:error, :lookahead_fail}`.

    p = not_lookhead(literal("Hello"))
    p.(Context.new("Hello World")) -> %{status: {:error, :lookahead_fail}}

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
