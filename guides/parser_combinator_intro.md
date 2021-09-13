# Intro to Parser Combinators

If you prefer to watch to a talk see Saša Jurić [build up parser combinators from the ground up](https://www.youtube.com/watch?v=xNzoerDljjo)

The phrase __parser combinator__ may sound confusing but is in fact deceptively simple if you already understand the notion of functions and function composition.

For example transforming `[1, 2, 3, 4, 5]` into `[2, 4, 6, 8, 10]` can be achieved through combining the functions `Enum.map` and `double` as follows:

    double = fn x -> 2 * x end
    Enum.map([1, 2, 3, 4, 5], double)

If you think of a parser as being a certain kind of function that works on a textual input (in the way that `double` above is a kind of function that works on a number input) then you may see how we can combine parsers to do work.

For example to parse an input such as "12345" we might combine two parsers `many` and `digit`. Let's imagine digit is a parser that accepts an input character in the range of '0'..'9' and returns a number, like this:

    digit("12345") = 1
    digit("2345") = 2

and so on. Now lets imagine that `many` is a parser that accepts an input and another parser and keeps attempting to match that parser against the input until it doesn't match any further. So, for example:

    many("12345", digit) = [1, 2, 3, 4, 5]

It's the "accepts another parser" concept that is key and is what makes `many` a combinator parser. In the same way as `map` calls the function `double` to do work, `many` calls the parser `digit` to do work.

The insight is that we can replace `digit` with any other parser including other combinator parsers. In this way we can combine, and recombine, simpler parsers to form more complex parsers until we have something that can parse our input.

In Ergo we distinguish between **terminal** parsers that only work on the input and **combinator** parsers that are parameterised with one or more other parsers (which may themselves be either a terminal or another combinator parser).
