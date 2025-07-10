defmodule Ergo.ContextTest do
  use ExUnit.Case
  alias Ergo.Context
  doctest Ergo.Context

  describe "partial AST functions" do
    test "set_partial_ast/2 sets partial AST" do
      ctx = Context.new("test")
      partial_ast = ["attr_name", ":", "value"]
      
      result = Context.set_partial_ast(ctx, partial_ast)
      
      assert result.partial_ast == partial_ast
      assert result.input == "test"  # other fields unchanged
    end

    test "push_partial_ast/2 adds elements to front of partial AST" do
      ctx = Context.new("test")
      
      ctx = Context.push_partial_ast(ctx, "first")
      assert ctx.partial_ast == ["first"]
      
      ctx = Context.push_partial_ast(ctx, "second")
      assert ctx.partial_ast == ["second", "first"]
      
      ctx = Context.push_partial_ast(ctx, "third")
      assert ctx.partial_ast == ["third", "second", "first"]
    end

    test "clear_partial_ast/1 resets partial AST to empty list" do
      ctx = Context.new("test")
      ctx = Context.set_partial_ast(ctx, ["attr_name", ":", "value"])
      
      result = Context.clear_partial_ast(ctx)
      
      assert result.partial_ast == []
      assert result.input == "test"  # other fields unchanged
    end

    test "partial_ast starts empty in new context" do
      ctx = Context.new("test")
      assert ctx.partial_ast == []
    end

    test "partial AST functions work with various data types" do
      ctx = Context.new("test")
      
      # Test with different AST element types
      ctx = Context.push_partial_ast(ctx, :atom)
      ctx = Context.push_partial_ast(ctx, "string")
      ctx = Context.push_partial_ast(ctx, 42)
      ctx = Context.push_partial_ast(ctx, [1, 2, 3])
      
      assert ctx.partial_ast == [[1, 2, 3], 42, "string", :atom]
    end

    test "set_partial_ast/2 requires list argument" do
      ctx = Context.new("test")
      
      # Should work with lists
      assert %Context{} = Context.set_partial_ast(ctx, [])
      assert %Context{} = Context.set_partial_ast(ctx, ["test"])
      
      # Should raise with non-list
      assert_raise FunctionClauseError, fn ->
        Context.set_partial_ast(ctx, "not a list")
      end
    end
  end
end
