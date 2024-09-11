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
      iex> null_parser = Parser.combinator(:null, "null_parser", fn %Context{} = ctx -> ctx end)
      iex> assert_raise(RuntimeError, fn -> Ergo.parse(around(null_parser), "") end)

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.combinator(:null, "null_parser", fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, before: fn _ctx -> send(self(), :before) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :before

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.combinator(:null, "null_parser", fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, after: fn _ctx, _new_ctx -> send(self(), :after) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :after

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Meta
      iex> null_parser = Parser.combinator(:null, "null_parser", fn %Context{} = ctx -> ctx end)
      iex> parser = around(null_parser, before: fn _ctx -> send(self(), :before) end, after: fn _ctx, _new_ctx -> send(self(), :after) end)
      iex> Ergo.parse(parser, "")
      iex> assert_receive :before
      iex> assert_receive :after
  """
  def around(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, parser.label)
    before_fn = Keyword.get(opts, :before, nil)
    after_fn = Keyword.get(opts, :after, nil)

    cond do
      before_fn && !after_fn ->
        label = Keyword.get(opts, :label, "before<#{parser.label}>")

        Parser.combinator(
          :before,
          label,
          fn %Context{} = ctx ->
            before_fn.(ctx)
            Parser.invoke(ctx, parser)
          end,
          child_info: Parser.child_info_for_telemetry(parser)
        )

      after_fn && !before_fn ->
        label = Keyword.get(opts, :label, "after<#{parser.label}>")

        Parser.combinator(
          :after,
          label,
          fn %Context{} = ctx ->
            new_ctx = Parser.invoke(ctx, parser)
            after_fn.(ctx, new_ctx)
            new_ctx
          end,
          child_info: Parser.child_info_for_telemetry(parser)
        )

      before_fn && after_fn ->
        Keyword.get(opts, :label, "around<#{parser.label}>")

        Parser.combinator(
          :around,
          label,
          fn %Context{} = ctx ->
            before_fn.(ctx)
            new_ctx = Parser.invoke(ctx, parser)
            after_fn.(ctx, new_ctx)
            new_ctx
          end,
          child_info: Parser.child_info_for_telemetry(parser)
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
      iex> failing_parser = Parser.combinator(:err, "err_parser", fn ctx -> %{ctx | status: {:error, :unfathomable_error}} end)
      iex> parser = failed(failing_parser, fn _pre_ctx, _post_ctx, _parser -> send(self(), :failed) end)
      iex> Ergo.parse(parser, "")
      iex> assert_received :failed
  """
  def failed(%Parser{} = parser, fail_fn, opts \\ []) when is_function(fail_fn) do
    label = Keyword.get(opts, :label, "failed<#{parser.label}>")

    Parser.combinator(
      :failed,
      label,
      fn %Context{} = ctx ->
        with %Context{status: {:error, _}} = new_ctx <- Parser.invoke(ctx, parser) do
          fail_fn.(ctx, new_ctx, parser)
          new_ctx
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc """
  `commit/0` is not technically a parser, rather a sentinel that a sequence
  can use to determine whether an error is fatal or not
  """
  def commit() do
    Parser.terminal(
      :commit,
      "Commit",
      fn %Context{} = ctx ->
        ctx
      end
    )
  end

  @doc """
  `capture/2` is used to hoist AST values (possibly transformed by the t_fn)
  into the context. For example this can be used in a sequence where you want
  to communicate information forward in the sequence.

  Example: You want to parse <a>...</a>. To correctly parse </a> you need to
  know that <a> was used to open the pair.
  """
  def capture(parser, key, t_fn \\ &Function.identity/1) do
    Parser.combinator(
      :capture,
      "capture-#{key}",
      fn %Context{} = ctx ->
        case Parser.invoke(ctx, parser) do
          %Context{status: :ok, ast: ast, captures: captures} = ctx ->
            %{ctx | captures: Map.put(captures, key, t_fn.(ast))}

          %Context{} = ctx ->
            ctx
        end
      end
    )
  end
end
