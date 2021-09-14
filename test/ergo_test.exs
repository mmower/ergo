defmodule ErgoTest do
  use ExUnit.Case
  doctest Ergo

  test "numeric example" do
    alias Ergo
    alias Ergo.Context
    import Ergo.Terminals, except: [digit: 0]
    import Ergo.Combinators

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
        nil -> 1
        45 -> -1
      end
    end)

    assert %Context{status: :ok, ast: -1} = Ergo.parse(minus, "-42")
    assert %Context{status: :ok, ast: 1} = Ergo.parse(minus, "42")

    integer = sequence([
      minus,
      digits,
      ],
      map: &Enum.product/1
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

    mantissa = many(digit, map: m_transform)

    assert %Context{status: :ok, ast: 0.5} = Ergo.parse(mantissa, "5")
    assert %Context{status: :ok, ast: 0.42000000000000004} = Ergo.parse(mantissa, "42")

    number = sequence([
      integer,
      optional(
        sequence([
          ignore(char(?.)),
          mantissa
        ], map: &List.first/1)
      )
    ], map: &Enum.sum/1)

    assert %Context{status: :ok, ast: 42} = Ergo.parse(number, "42")
    assert %Context{status: :ok, ast: 0.45} = Ergo.parse(number, "0.45")
  end

end
