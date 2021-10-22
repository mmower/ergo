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
      iex> null_parser = Parser.new(:null_parser, fn %Context{} = ctx -> ctx end)
      iex> assert_raise(RuntimeError, fn -> Ergo.parse(around(null_parser), "") end)

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.new(:null_parser, fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, before: fn _ctx -> send(self(), :before) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :before

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.new(:null_parser, fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, after: fn _ctx, _new_ctx -> send(self(), :after) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :after

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.new(:null_parser, fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, before: fn _ctx -> send(self(), :before) end, after: fn _ctx, _new_ctx -> send(self(), :after) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :before
      iex> assert_receive :after
  """
  def around(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "#")
    before_fn = Keyword.get(opts, :before, nil)
    after_fn = Keyword.get(opts, :after, nil)

    cond do
      before_fn && !after_fn ->
        Parser.new(
          :before,
          fn %Context{} = ctx ->
            before_fn.(ctx)
            Parser.invoke(parser, ctx)
          end,
          combinator: true,
          label: label
        )

      after_fn && !before_fn ->
        Parser.new(
          :after,
          fn %Context{} = ctx ->
            new_ctx = Parser.invoke(parser, ctx)
            after_fn.(ctx, new_ctx)
            new_ctx
          end,
          combinator: true,
          label: label
        )

      before_fn && after_fn ->
        Parser.new(
          :around,
          fn %Context{} = ctx ->
            before_fn.(ctx)
            new_ctx = Parser.invoke(parser, ctx)
            after_fn.(ctx, new_ctx)
            new_ctx
          end,
          combinator: true,
          label: label
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
      iex> failing_parser = Parser.new(:err_parser, fn ctx -> %{ctx | status: {:error, :unfathomable_error}} end)
      iex> parser = failed(failing_parser, fn _ctx -> send(self(), :failed) end)
      iex> Ergo.parse(parser, "")
      iex> assert_received :failed
  """
  def failed(%Parser{} = parser, fail_fn, opts \\ []) when is_function(fail_fn) do
    label = Keyword.get(opts, :label, "#")

    Parser.new(
      :failed,
      fn %Context{} = ctx ->
        with %Context{status: {:error, _}} = new_ctx <- Parser.invoke(parser, ctx) do
          fail_fn.(new_ctx)
          new_ctx
        end
      end,
      label: label,
      combinator: true
    )
  end

  # def wrap(%Parser{} = parser, label) do
  #   Parser.new(
  #     fn %Context{} = ctx ->
  #       Parser.invoke(parser, %{ctx | track: false})
  #     end,
  #     label: label,
  #     description: label
  #   )
  # end

  def suppress_caller_logging(%Parser{} = parser) do
    Parser.new(
      :suppress,
      fn %Context{caller_logging: caller_logging} = ctx ->
        ctx_2 = Parser.invoke(parser, %{ctx | caller_logging: false})
        %{ctx_2 | caller_logging: caller_logging}
      end,
      combinator: true
    )

  end

end
