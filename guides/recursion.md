# Recursion

## Left Recursion

Parser combinators, being a form of recursive descent parser, are unable to
handle left recursion.

In general this looks like:

A → A𝛼 | β

Where non-terminal A ends up being substituted for itself before any token
can be matched, leading to A → A𝛼 | β again, and so on and so on in an
infinite recursion.

Such parsers can usually be rewritten to a form that is not left-recursive
however that is beyond the scope of this guide.

## Eager Recursion

There is a further problem that arises from the way parser combinators are
defined as functions returning in a language that is not, by default, lazy.
Here is an example parser that is designed to parse values like 42, true,
"What is six times seven?" and also lists of values, including other lists.
Note that we elide handling white space for brevity.

```elixir
def value() do
  choice([
    number_val(),
    string_val(),
    boolean_val(),
    list_val()
  ])
end

def list_val() do
  sequence([
    char(?[)
    value(),
    many(
      sequence([
        comma(),
        value()
      ])
    ),
    char(?])
  ])
end
```

A value can be a number, string, boolean, or list. But list is a sequence of
values. The problem arises from a call to value() leading to a call to list()
which, in turn, leads to a call to value(), leading to a call to list() and
so on in an infinite recursion.

Note that this is not grammatical recursion as in the left recursion example
above and cannot be solved by rewriting. The issue is that Elixir evaluates
function calls eagerly, i.e. when they are encountered. We need to introduce
a "call gap" to break the recursion.

We do this with the `lazy` parser combinator. Lazy wraps it's parser in a
function so that it is not called immediately, breaking the recursion. E.g.:

```elixir
def value() do
  choice([
    number_val(),
    string_val(),
    boolean_val(),
    lazy(list_val())
  ])
end
```
