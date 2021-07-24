# Ergo

[Online Documentation](https://hexdocs.pm/ergo/)

<!-- MDOC !-->
Elixir Parser Combinators
Author: Matt Mower <matt@theartofnavigation.co.uk>
Version: 0.3.5

## Getting Help

If you decide to use Ergo and you want help please come find me in the [Elixir Discord](https://discord.gg/elixir) (where I am __sandbags__). Regardless, I would love to hear from you about problems and or suggestions for improvement.

# What is Ergo?

Ergo is an Elixir language parser combinator library. The name 'ergo' means 'therefore' means 'for that reason' which seemed appropriate for a parser.

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

Also note that this is the second attempt I've made at building such a library. The first, Epic, was not completed and, on reflection, not good maintanable code. I did, however, learn a great deal in building it and that learning has put Ergo on a much firmer footing.

# Introduction to Parser Combinators

If you understand parser combinators you can safely skip this section.

The phrase __parser combinator__ sounded a little confusing when I first came across it but it's deceptively simple. It means to combine parsers together. Much as we can write a complex functions by composing together simpler functions, a library like Ergo allows us to create a complex parser by combining together simpler ones.

In Ergo we distinguish between **terminal** parsers and **combinator** parsers. The difference is that a combinator parser is parameterised by one or more other parsers (which may themselves be either a terminal or another combinator parser). Here is an example:

The terminal parser `digit` reads a single digit character (i.e. '0'..'9') from the input. We don't have to concern ourselves right now with how it does this, or where that digit goes, suffice to say that somehow:

    parse(digit(), "1")
    
Will parse the 1 from the input and generate 49 (the UTF-8 code for the digit 1) in return.

The combinator parser `many` takes a parser to apply and attempts to apply it repeatedly on the input. it is meant to use and attempts to match it repeatedly on the input. So that, for example:

    parse(many(digit()), "123")
    
Will parse the digits "1", "2", and "3" and generate the list `[49, 50, 51]` (respectively the UTF-8 codes for those digits).

Alternatively we could have used a parser like `alpha` that parses letters.

    parse(many(alpha()), "abc")
    
Will parse the alphanumeric characters "a", "b", and "c" to generate the list `[97, 98, 99]`.
    
Where things get interesting is when we pass combinator parsers to other combinator parsers. Let's add `sequence` which takes a list of parsers and attempt to use each in turn:

    parse(sequence([many(alpha()), many(digits())]), "abc123")
    
Here we pass the parser `many(alpha())` and the parser `many(digit())` to the parser `sequence` which will, in turn, generate the list `[[97, 98, 99], [49, 50, 51]]` for that input.

In this fashion we can build more and more complex parsers by combining together simpler ones..

# Using Ergo

## Installing

Add Ergo to your mix.exs file:

    {:ergo, "~> 0.2"}

Then run

    mix deps.get
    
## A Basic Parser

Let's create a simple parser as an exercise, it will parser a number, e.g. 42, 5.0, -2.7, or 0 and turn it into it's equivalent Elixir integer or float value:

```elixir
alias Ergo.{Context, Parser}
import Ergo.{Terminals, Combinators, Parsers}

number_parser =
    sequence(
    [
        optional(char(?-), map: fn _ -> -1 end, label: "-?"),
        choice([
        decimal(),
        uint()
        ],
        label: "[i|d]"
        )
    ],
    label: "number",
    map: &Enum.product/1
    )

Ergo.parse(number_parser, "42")
```
    
This parser uses a sequence that checks for an optional leading minus and then a choice to select between either a decimal or integer value.

If there is a minus the match gets mapped from a character into the value -1.

The choice tries the decimal parser first to ensure that we don't accidentally match "123." as the integer "123". If there is no decimal point it fails and tries the integer route.

At this point the sequence AST will look something like: [-1, 16.0] or [42] and we use `Enum.product` to combine to get the final value, e.g. 42.

Ergo.parse returns a fully-matched `Context` e.g.

```elixir
%Context{status: :ok, ast: 42}
```

```elixir 
%Context{status: {:error, :unexpected_char}, message: message, line: line, col: col}
```
    
## Debugging your parser

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

## What is a parser?

As with most parser combinator libraries, Ergo parsers are anonymous functions parameterized by inputs. However Ergo parser functions are wrapped in an `Ergo.Parser` struct that holds the parser function and can contain additional descriptive metadata (by default a description of the parser behaviour).

## The Context

Ergo parsers operate on a `Context` struct that gets passed from parser to parser. We can create the context directly:

```elixir
alias Ergo.Context
ctx = Context.new("string to be parsed")
```
    
Although you will rarely need to do so as there is a helper function `Ergo.parse` that will do that for you:

```elixir
Ergo.parse(parser, "string to be parsed")
```
    
Ergo can send debugging information to the Elixir Logger which can be helpful in figuring out why a parser is not working as expected. E.g.

```elixir
Ergo.parse(parser, "string to be parsed", debug: true)
```

The `status` field of the context will always be either `:ok` or a tuple of `{:error, :error_atom}`.

The parser can build up a datastructure to return by modifying the `ast` value of the context. The `sequence` parser, for example, creates a list of all matching parsers, e.g.

    Ergo.parse(sequence([uint(), ignore(char(?,)), uint()]), "1,3")
    => %Context{status: :ok, ast: [1, 3]}
    
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
    debug
    
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

# Parsers

Ergo comes with a set of basic parsers with which you can assemble your own, more complex, parsers. These are in the form of terminal parsers, combinator parsers, and numeric parsers.

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

## Numeric parsers

These are parsers that build on the terminal parsers to parse diffrent types of numeric values. 
The utility parsers are technically terminal parsers, since they are not parameterised by a parser, but they are implemented in terms of some of the combinator parsers themselves and hence belong in a separate category.

### digits

The `digits` parser matches a series of digits from the input. If successful it returns with `status: :ok` and the `ast` set to a list of the digit values.

### uint

The `uint` parser matches a series of digits from the input. If successful it returns with `status: :ok` and `ast` parameter set to the integer value of the number matched.

### decimal

The `decimal` parser matches a series of digits, separated by a single '.' from the input. If successful it returns wtih `status: :ok` and `ast` set to the floating point value of the number matched.

### number

The `number` parser builds upon the `uint` and `decimal` parsers to parse any kind of numeric value returning `status: :ok` and `ast` set to the integer or floating value of the number parsed.

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

```elixir
    p = choice([literal("Hello"), literal("World")])
    p.(Context.new("Hello World")) -> %{status: :ok, ast: "Hello", input: " World"}    
    p.(Context.new("World Hello")) -> %{status: :ok, ast: "World", input: " Hello"}
    
    boolean = choice([literal("true"), literal("false")], map: fn ast -> ast == "true" end)
    boolean.(Context.new("true")) -> %{status: ok, ast: true, input: ""}
    boolean.(Context.new("false)) -> %{status: ok, ast: false, input: ""}
    boolean.(Context.new("Hello)) -> %{status: {:error, ...}, input: "Hello"}
```
    
### many

The `many/2` parser is used to match another parser repeatedly on the input. In its default form that can be zero times (i.e. no matches) or infinite matches. However using the `:min` and `:max` optional arguments allow limits to be specified.

Signature:
    many(parser, args \\ [])
    
Example:

```elixir
    p = many(char(?\s), min: 1)
    p.(Context.new("    ")) -> %{status: :ok, input: ""}
    
    p = many(char(?\s), min: 2)
    p.(Context.new(" Hello")) -> %{status: {:error, ...}, input: " Hello"}
    
    p = many(char(?a..?z), max: 2)
    p.(Context.new("Hello World)) -> %{status: :ok, ast: ['H', 'e'], input: "llo World"}
    
    p = many(char(?a..?z), map: fn ast -> Enum.count(ast) end)
    p.(Context.new("Hello")) -> %{status: :ok, ast: 5, input: ""}
```

### optional

The `optional/1` parser is used to match another parser on the input and succeeds if it doesn't match or matches once.

### ignore

The `ignore/1` parser is designed for use with parsers such as `sequence` and `many`. It takes a parser and attempts to match it on the input however, if it succeeds, it returns a nil `ast` value that parsers can use to ignore it.

### transform

The `transform/2` parser is used to change the `ast` returned by another parser if the other parser is successful. It is useful for modifying the output of parsers that do not directly support a `map` argument.

Signature:
    squared = transform(uint(), fn ast -> ast * ast end)

```elixir
squared.(Context.new("10")) -> %{status: :ok, ast: 100}
```

### lookahead

The `lookahead/1` parser attempts to match the parser it is given on the input. If it succeeds it returns with `status: :ok` but `ast: nil` and with the input unchanged. Otherwise it returns with `status: {:error, :lookahead_fail}`.

```elixir
p = lookahead(literal("Hello"))
p.(Context.new("Hello World")) -> %{status: :ok, input: "Hello World"}
```
    
### not_lookahed

The `not_lookahead/1` parser is the inverse of the `looakahead` parser in that it attempts to match its parser on the input and where it can do so it returns with `status: {:error, :lookahead_fail}`.

```elixir
p = not_lookhead(literal("Hello"))
p.(Context.new("Hello World")) -> %{status: {:error, :lookahead_fail}}
```

<!-- MDOC !-->

## Documentation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ergo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ergo, "~> 0.2.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ergo](https://hexdocs.pm/ergo).
