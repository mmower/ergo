defmodule ErgoTest do
  use ExUnit.Case
  doctest Ergo

  alias Ergo
  alias Ergo.Context
  import Ergo.{Terminals, Combinators}

  test "parses numbers" do
    digit = char(?0..?9)
    assert %Context{status: :ok, ast: 52} = Ergo.parse(digit, "42")

    c_transform = fn ast ->
      bases = Stream.unfold(1, fn n -> {n, n * 10} end)
      digits = Enum.map(ast, fn digit -> digit - 48 end)
      Enum.zip(Enum.reverse(digits), bases)
      |> Enum.map(&Tuple.product/1)
      |> Enum.sum
      end

    digits = many(digit) |> transform(c_transform)
    assert %Context{status: :ok, ast: 42} = Ergo.parse(digits, "42")

    minus = optional(char(?-)) |> transform(fn ast ->
      case ast do
        Ergo.Nil -> 1
        45 -> -1
      end
    end)

    assert %Context{status: :ok, ast: -1} = Ergo.parse(minus, "-42")
    assert %Context{status: :ok, ast: 1} = Ergo.parse(minus, "42")

    integer = sequence([
      minus,
      digits,
      ],
      ast: &Enum.product/1
    )

    assert %Context{status: :ok, ast: 1234} = Ergo.parse(integer, "1234")
    assert %Context{status: :ok, ast: -5678} = Ergo.parse(integer, "-5678")

    m_transform = fn ast ->
      ast
      |> Enum.map(fn digit -> digit - 48 end)
      |> Enum.zip(Stream.unfold(0.1, fn n -> {n, n / 10} end))
      |> Enum.map(&Tuple.product/1)
      |> Enum.sum
    end

    mantissa = many(digit, ast: m_transform)

    assert %Context{status: :ok, ast: 0.5} = Ergo.parse(mantissa, "5")
    assert %Context{status: :ok, ast: 0.42000000000000004} = Ergo.parse(mantissa, "42")

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
        ], ast: &List.first/1)
      )
    ], ast: combine)

    assert %Context{status: :ok, ast: 42} = Ergo.parse(number, "42")
    assert %Context{status: :ok, ast: 0.45} = Ergo.parse(number, "0.45")
    assert %Context{status: :ok, ast: -42} = Ergo.parse(number, "-42")
    assert %Context{status: :ok, ast: -4.2} = Ergo.parse(number, "-4.2")
  end

  import Ergo.Numeric

  def expression() do
    add = char(?+)
    subtract = char(?-)
    multiple = char(?*)
    divide = char(?/)

    sequence([
      number(), many(choice([
        choice([
          sequence([ignore(add), number()], ast: fn [n] -> {:+, n} end),
          sequence([ignore(subtract), number()], ast: fn [n] -> {:-, n} end),
          sequence([ignore(multiple), number()], ast: fn [n] -> {:*, n} end),
          sequence([ignore(divide), number()], ast: fn [n] -> {:/, n} end)
        ])
      ]))
    ], ast: &List.flatten/1)
  end

  test "parses simple mathematical expression" do
    assert %Context{status: :ok, ast: [1, {:*, 2}, {:+, 3}]} = Ergo.parse(expression(), "1*2+3")
  end

end
