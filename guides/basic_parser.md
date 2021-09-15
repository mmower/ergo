# Creating a Basic Parser

This tutorial will explore how Ergo works through creating a parser to match numbers, be they integers like -5 or 42, or decimals like 25.6. The parser will match them and convert them into the appropriate Elixir numeric value. We will build it up in stages, starting with bare digits.

## Parsing a digit

To begin with we need to be able to parse digits. One option for that is to use the basic `char` parser to match digit characters. Using IEx here is what you would do:

```elixir
alias Ergo
alias Ergo.Context
import Ergo.Terminals

digit = char(?0..?9)
Ergo.parse(digit, "42")
%Context{status: :ok, ast: 52}
```

Where the integer 52 is the character code of the digit '4' (Try typing `?4` into the IEx console to see for yourself).

Now we can parse a single digit, how about multiple digits?

## Parsing many digits

 To parse multiple digits we use the `many` parser in conjunction with the `digit` parser as follows:

```elixir
import Ergo.Combinators

digits = many(digit())
Ergo.parse(digits, "42")
%Context{status: :ok, ast: [52, 50]}
```

In fact you might see `'42'` in your version of the AST because IEx will try to render the list `[52, 50]` as a charlist. This is a hangover from Erlang. If you would prefer to see the list add the following to your `~/.iex.exs` file:

```elixir
IEx.configure(inspect: [charlists: :as_lists])
```

The `many` combinator parser repeatedly invokes the `digit` parser to match as many digit characters as possible, generating an AST that is a list of those digits. To transform them into a numeric value we need to apply another function to the AST.

In our case the AST list contains character values of the digits matched, e.g. [52, 50] for the digits ['4', '2'] respectively. Since the digit character '0' has character value of 48 we can turn the characters into digit values by subtracting 48.

 The heavy lifting of transforming digits is done by `c_transform` below which is pipeline to transform ['4', '2'] -> [{4, 10}, {2, 1}] -> [40, 2] -> 42:

```elixir
c_transform = fn ast ->
  bases = Stream.unfold(1, fn n -> {n, n * 10} end)
  digits = Enum.map(ast, fn digit -> digit - 48 end)
  Enum.zip(Enum.reverse(digits), bases)
  |> Enum.map(&Tuple.product/1)
  |> Enum.sum
  end

digits = many(digit) |> transform(c_transform)

Ergo.parse(digits, "42")
%Context{status: :ok, ast: 42}
```

In this case we are applying the `transform` parser to the `many` parser. Transform only operates on the AST of the parser it is given by applying a function to it. In this case we could also have used:

```elixir
digits = many(digit(), map: c_transform)
```

As many of the combinator parsers support an optional `map:` argument as a shortcut.

At this point we can parse positive integers of any length:

```elixir
Ergo.parse(digits, "918212812783918723")
%Context{status: :ok, ast: 918212812783918723}
```

## Parsing negative numbers

What about negative values? We need to look for a leading '-' character however, unlike the digits, the minus is optional. Parsing the minus is simple enough:

```elixir
minus = char(?-)

Ergo.parse(minus, "-")
%Context{status: :ok, ast: 45}
```

45 is the char value of the char '-'. We can now use the `optional` combinator to allow a minus to be matched, or not:

```elixir
minus = optional(char(?-))

Ergo.parse(minus, "-42")
%Context{status: :ok, ast: 45}

Ergo.parse(minus, "42")
%Context{status: :ok, ast: nil}
```

In the second case the status is `:ok` meaning the optional parser succeeded, however the ast is `nil` meaning nothing was matched. Let's make this a bit more useful:

```elixir
minus = optional(char(?-)) |> transform(fn ast ->
  case ast do
    nil -> 1
    45 -> -1
  end
end)

Ergo.parse(minus, "-42")
%Context{status: :ok, ast: -1}

Ergo.parse(minus, "42")
%Context{status: :ok, ast: 1}

```

Now when `minus` matches a '-' it will transform it to the value -1. When it doesn't match anything it will transform it to the value 1. Now let's combine it with the other parser.

```elixir
integer = sequence([
  minus,
  digits
])
```

The `sequence` parser tries to match a list of parser in turn and, if they all match, generates an AST composed of a list of each of their results. Let's see how it works:

```elixir
Ergo.parse(integer, "1234")
%Context{status: :ok, ast: [1, 1234]}

Ergo.parse(integer, "-5678")
%Context{status: :ok, ast: [-1, 5678]}
```

So we can see that it's easy to get the right result by simply taking the product of the two values in the AST:

```elixir
integer = sequence([
  minus,
  digits,
  ],
  map: &Enum.product/1
)

Ergo.parse(integer, "1234")
%Context{status: :ok, ast: 1234}

Ergo.parse(integer, "-5678")
%Context{status: :ok, ast: -5678}
```

So far so good. We can now parse positive and negative integers.

## Parsing decimals

If we want to parse decimal numbers as well we need to handle the (optional) mantissa, the digits to the right of the decimal point.

We can see that the mantissa is structurally the same as the integer part, a set of digits, but will need to be processed a little differently.

The `m_transform` function below should look familiar. It works the same way as the `c_transform` only instead of multiplying by increasing powers of 10, we're dividing by increasing powers of 10.

```elixir
m_transform = fn ast ->
  ast
  |> Enum.map(fn digit -> digit - 48 end)
  |> Enum.zip(Stream.unfold(0.1, fn n -> {n, n / 10} end))
  |> Enum.map(&Tuple.product/1)
  |> Enum.sum
end

mantissa = many(digit, map: m_transform)

Ergo.parse(mantissa, "5")
%Context{status: :ok, ast: 0.5}

Ergo.parse(mantissa, "42")
%Context{status: :ok, ast: 0.42000000000000004}
```

There may be a precision issue with this code but you can see the principle it is operating by.

Now to join the two components together, assuming there is a decimal point (suggesting we'll need `optional` again). Also we'll again make use of the `map:` feature of the `sequence` combinator to process AST's to give us the right value.

```elixir
number = sequence([
  integer,
  optional(
    sequence([
      ignore(char(?.)),
      mantissa
    ], map: &List.first/1)
  )
], map: &Enum.sum/1)

Ergo.parse(number, "42")
%Context{status: :ok, ast: 42}

Ergo.parse(number, "0.45")
%Context{status: :ok, ast: 0.45}

Ergo.parse(number, "-42")
%Context{status: :ok, ast: -42}
```

All looking good, just one more example:

```elixir
Ergo.parse(number, "-4.2")
%Context{status: :ok, ast: -3.8}
```

Oops! There is a problem with our implementation in that we add together the integer and decimal parts. This works for positive numbers but in the latter case -4 + 0.2 = -3.8 not -4.2. When the integer part is negative we need to subtract the decimal part. We can no longer just use `Enum.sum` to process the result of the top-level sequence. Instead:

```elixir
combine = fn
  [integer, decimal | []] ->
    if integer >= 0 do
      integer + decimal
    else
      integer - decimal
    end
  ast ->
    Enum.sum(ast)
end

number = sequence([
  integer,
  optional(
    sequence([
      ignore(char(?.)),
      mantissa
    ], map: &List.first/1)
  )
], map: combine)

Ergo.parse(number, "-4.2")
%Context{status: :ok, ast: -4.2}
```

## Conclusion

Through a series of steps we have built a parser that can handle any kind of integer or decimal number we throw at it. We've seen the using of terminal parsers like `char` as well as combinator parsers like `optional`, `ignore`, `many`, and `sequence` and meta parsers like `transform` (and that often transform can be specified as a `map:` argument to a combinator parser).

Hopefully this guide will be helpful in thinking about how to build your own parsers.
