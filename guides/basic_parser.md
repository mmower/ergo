# Creating a Basic Parser

Let's create a number parser as an exercise. By the end we'll be able to parse numbers that are integers, negative, and even decimals and will return the appropriate Elixir numeric value.

We will build it up in stages, starting with bare digits.

## Parsing a digit

To begin with we need to be able to parse digits. One option for that is to use the basic `char` parser to match digit characters. Using IEx here is what you would do:

```elixir
alias Ergo
import Ergo.Terminals

parser = char(?0..?9)
Ergo.parse(parser, "42").ast
42 # The UTF-8 code for the digit '4'
```

Now we can parse a single digit, how about multiple digits?

## Parsing many digits

```elixir
import Ergo.Combinators

digits = many(digit())
Ergo.parse(digits, "42").ast
[52, 50] # Actually you will see '42' because IEx will try and render this as a charlist
```

Using the `many` parser will match as many digits are as available. Now we need to transform them into a numeric value. We will do this by applying a function to the
AST resulting from the `many` combinator.

Since `many` returns a list containing the output of each match of the parser, we can
 transform this list.

In our case the list contains character values of the digits matched, e.g. [52, 50] for the digits ['4', '2'] respectively. Since the digit character '0' has character value 48 we can turn the characters into digit values by subtracting 48.

 The heavy lifting of transforming digits is done by `c_transform` below which is pipeline to transform ['4', '2'] -> [{4, 10}, {2, 1}] -> [40, 2] -> 42:

```elixir
c_transform = fn ast ->
  bases = Stream.unfold(1, fn n -> {n, n * 10} end) # Generates [1, 10, 100, 1000, …]
  digits = Enum.map(ast, fn digit -> digit - 48 end) # Turn char values into numbers
  Enum.zip(Enum.reverse(digits), bases) # Creates [{2, 1}, {4, 10}]
  |> Enum.map(&Tuple.product/1) # Multiples each tuple to create [2, 40]
  |> Enum.sum # Sums to create 42
  end

digits = many(digit()) |> transform(c_transform)

Ergo.parse(digits, "42").ast
42
```

In this case we are applying the `transform` parser (that allows a function to be applied to the AST of another parser), in this case the `many` parser. We could also have used:

```elixir
digits = many(digit(), map: c_transform)
```

As many of the combinator parsers support an optional `map` argument as a shortcut.

At this point we can parse positive integers of any length:

```elixir
Ergo.parse(digits, "918212812783918723").ast
918212812783918723
```

## Parsing negative numbers

What about negative values? We need to look for a leading '-' character however, unlike the digits, the minus is optional. Parsing the minus is simple enough:

```elixir
minus = char(?-)

Ergo.parse(minus, "-")
%{status: :ok, ast: 45} # 45 is the char value of the char '-'
```

We can now use the `optional` combinator to allow a minus to be matched, or not:

```elixir
minus = optional(char(?-))

Ergo.parse(minus, "-42")
%{status: :ok, ast: 45}

Ergo.parse(minus, "42")
%{status: :ok, ast: nil}
```

In the second case the status is `:ok` meaning the optional parser succeeded, however the ast is `nil` meaning nothing was matched. Let's make this a bit more useful:

```elixir
minus = optional(char(?-)) |> transform(fn ast ->
  case ast do
    nil -> 1
    45 -> -1
  end
end)
```

Now when `minus` matches a '-' it will transform it to the value -1. When it doesn't match anything it will transform it to the value 1. Now let's combine it with the other parser.

```elixir
integer = sequence([
  minus,
  digits
])
```

The `sequence` parser tries to match a list of parser in turn and, if they all match, returns an AST composed of each of their results. Let's apply it:

```elixir
Ergo.parse(integer, "1234")
%Context{status: :ok, ast: [1, 1234]}

Ergo.parse(integer, "-5678")
%Context{status: :ok, ast: [-1, 5678]}
```

So we can see that it's easy to get the right result by simply taking the product of the two values returned in the AST:

```elixir
integer = sequence([
  minus,
  digits,
  ],
  map: fn ast -> Enum.product(ast) end
)

Ergo.parse(integer, "1234")
%Context{status: :ok, ast: 1234}

Ergo.parse(integer, "-5678")
%Context{status: :ok, ast: -5678}
```

So far so good. We can now parse positive and negative integers.

## Parsing decimals

If we want to parse decimal numbers as well we need to handle the (optional) mantissa, the digits to the right of the decimal point. We can see that the mantissa is again a set of digits but we'll process them differently. The `m_transform` function below should look familiar. It works the same way as the `c_transform` only instead of multiplying by increasing powers of 10, we're dividing by increasing powers of 10.

```elixir
m_transform = fn ast ->
  bases = Stream.unfold(0.1, fn n -> {n, n / 10} end)
  ast
  |> Enum.map(fn digit -> digit - 48 end)
  |> Enum.zip(bases)
  |> Enum.map(&Tuple.product/1)
  |> Enum.sum
end

mantissa = many(digit(), map: m_transform)

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
```

## Conclusion

Through a series of steps we have built a parser that can handle any kind of integer or decimal number we throw at it. We've seen the using of terminal parsers like `char` as well as combinator parsers like `optional`, `ignore`, `many`, and `sequence` and meta parsers like `transform` (and that often transform can be specified as a `map:` argument to a combinator parser).

Hopefully this guide will be helpful in thinking about how to build your own parsers.
