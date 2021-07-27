defmodule Ergo.Meta do
  alias Ergo.{Context, Parser}

  @moduledoc """
  The Meta parsers are not really parsers at all but operate within the parsing framework.

  All Meta parsers are combinators that accept a parser and either report on or modify
  its operation.
  """

  @doc ~S"""
  The `around` parser is a pass-thru parser that can be used to run code before or
  after another parser. For example to inspect the context or output additional
  debugging information.

  Specify on of
    around(parser, before: fn ctx -> … end)
    around(parser, after: fn ctx, parsed_ctx -> … end)
    around(parser, before: fn ctx -> … end, after: fn ctx, parsed_ctx -> … end)

  Note that where both `before:` and `after:` are specified, the after function will
  receive both the context before and after parsing as separate parameters.

  If neither of `before:` nor `around:` are specified an error will be raised.

  Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.new(fn %Context{} = ctx -> ctx end)
      iex> assert_raise(RuntimeError, fn -> Ergo.parse(around(null_parser), "") end)

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.new(fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, before: fn _ctx -> send(self(), :before) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :before

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.new(fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, after: fn _ctx, _new_ctx -> send(self(), :after) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :after

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.new(fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, before: fn _ctx -> send(self(), :before) end, after: fn _ctx, _new_ctx -> send(self(), :after) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :before
      iex> assert_receive :after
  """
  def around(%Parser{} = parser, opts \\ []) do
    before_fn = Keyword.get(opts, :before, nil)
    after_fn = Keyword.get(opts, :after, nil)

    cond do
      before_fn && !after_fn ->
        Parser.new(
          fn %Context{} = ctx ->
            before_fn.(ctx)
            Parser.call(parser, ctx)
          end
        )

      after_fn && !before_fn ->
        Parser.new(
          fn %Context{} = ctx ->
            new_ctx = Parser.call(parser, ctx)
            after_fn.(ctx, new_ctx)
            new_ctx
          end
        )

      before_fn && after_fn ->
        Parser.new(
          fn %Context{} = ctx ->
            before_fn.(ctx)
            new_ctx = Parser.call(parser, ctx)
            after_fn.(ctx, new_ctx)
            new_ctx
          end
        )

      true ->
        raise "Must specify either or both of before: fn ctx -> end or after: fn ctx, new_ctx -> end in around"
    end

  end

  @doc ~S"""
  The `failed` parser is a combinator that invokes a parser and if the parser fails
  runs the given function on the resulting context. This can be used to output additional
  debugging information where failure was unexpected.

  Examples

      iex> alias Ergo.Parser
      iex> import Ergo.Meta
      iex> failing_parser = Parser.new(fn ctx -> %{ctx | status: {:error, :unfathomable_error}} end)
      iex> parser = failed(failing_parser, fn _ctx -> send(self(), :failed) end)
      iex> Ergo.parse(parser, "")
      iex> assert_received :failed
  """
  def failed(%Parser{} = parser, fail_fn) when is_function(fail_fn) do
    Parser.new(
      fn %Context{} = ctx ->
        with %Context{status: {:error, _}} = new_ctx <- Parser.call(parser, ctx) do
          fail_fn.(new_ctx)
          new_ctx
        end
      end
    )
  end

  # def wrap(%Parser{} = parser, label) do
  #   Parser.new(
  #     fn %Context{} = ctx ->
  #       Parser.call(parser, %{ctx | track: false})
  #     end,
  #     label: label,
  #     description: label
  #   )
  # end

end
