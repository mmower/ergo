# Ergo

[Online Documentation](https://hexdocs.pm/ergo/)

<!-- MDOC !-->
Elixir Parser Combinators
Author: Matt Mower <matt@theartofnavigation.co.uk>
Version: 0.9.1

## Getting Help

If you decide to use Ergo and you want help please come find me in the [Elixir Discord](https://discord.gg/elixir) (where I am __sandbags__). Regardless, I would love to hear from you about problems and or suggestions for improvement.

# What is Ergo?

Ergo is an Elixir language parser combinator library. The name 'ergo' means 'therefore' means 'for that reason' which seemed appropriate for a parser.

Also note that this is the second attempt I've made at building such a library. The first, Epic, was not completed and, on reflection, not good maintanable code. I did, however, learn a great deal in building it and that learning has put Ergo on a much firmer footing.

# Using Ergo

## Installing

Add Ergo to your mix.exs file:

    {:ergo, "~> 0.9"}

Then run

    mix deps.get

## A Basic Parser

See the [guide](basic_parser.md) to parsing.

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

### status

Every parser sets its status to either `:ok` or a tuple whose first element is the atom `:error` and whose second element is a list of `{code, message}` tuples
describing the error in more detail for example `{:error, [{:unexpected_char, "Expected 'A' but found '1'}]}`.

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

    ast: fn ast -> ast
    ctx: fn ctx -> ctx

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

    boolean = choice([literal("true"), literal("false")], ast: fn ast -> ast == "true" end)
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

    p = many(char(?a..?z), ast: fn ast -> Enum.count(ast) end)
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

## Telemetry

Ergo includes built-in telemetry that emits events for every parser invocation via the Erlang `:telemetry` library. This is useful for debugging and for generating OPML outlines of parser execution, but adds overhead during parsing.

Telemetry is **disabled by default**. All telemetry functions compile to no-ops that pass the context through unchanged, so there is zero runtime cost when telemetry is off.

### Enabling Telemetry

Set the `ERGO_TELEMETRY` environment variable to `"true"` before compiling:

```bash
ERGO_TELEMETRY=true mix compile --force
```

Since this is a compile-time setting, you must force a recompile of the `:ergo` dependency when changing it:

```bash
ERGO_TELEMETRY=true mix deps.compile ergo --force
```

### Using Telemetry

With telemetry enabled, start the telemetry server and retrieve events by parse ID:

```elixir
Ergo.Telemetry.start()

parser = Ergo.Combinators.sequence([Ergo.Terminals.digit(), Ergo.Terminals.digit()])
%{status: :ok, id: id} = Ergo.parse(parser, "42")

events = Ergo.Telemetry.get_events(id)
```

Each event is a map containing `:event` (`:enter`, `:leave`, `:match`, or `:error`), `:type`, `:label`, position information, and other parser metadata.

### Telemetry Events

Ergo emits the following `:telemetry` events:

- `[:ergo, :enter]` — a parser is about to be invoked
- `[:ergo, :leave]` — a parser has finished
- `[:ergo, :match]` — a parser matched successfully
- `[:ergo, :error]` — a parser failed to match
- `[:ergo, :event]` — a custom event emitted by a combinator

### OPML Outline Generation

With telemetry enabled, you can generate OPML outlines for visual debugging of parser execution using `Ergo.Outline.Builder` and `Ergo.Outline.OPML`.

### Running Tests with Telemetry

Ergo's telemetry and outline tests are only compiled when telemetry is enabled:

```bash
# Default: runs all tests except telemetry/outline tests
mix test

# With telemetry: runs the full test suite
ERGO_TELEMETRY=true mix test
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
