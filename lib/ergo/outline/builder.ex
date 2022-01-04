defmodule Ergo.Outline.Builder do
  import Kernel, except: [node: 1]
  alias ExZipper.Zipper, as: Z

  def is_branch(node) do
    is_branch =
      case node do
        {_elem, kids} when is_list(kids) -> true
        _ -> false
      end

    is_branch
  end

  def kids(node) do
    kids =
      case node do
        {_elem, kids} -> kids
        _ -> raise "Node is malformed"
      end

    kids
  end

  def make_node({elem, _kids}, new_kids) do
    new_node = {elem, new_kids}
    new_node
  end

  def root_node() do
    {:root, []}
  end

  def tree() do
    Z.zipper(
      &is_branch/1,
      &kids/1,
      &make_node/2,
      {:root, []}
    )
  end

  def append(%{focus: {:root, _}} = tree, elem) do
    tree
    |> Z.append_child({elem, []})
    |> Z.down()
  end

  def append(tree, elem) do
    tree
    |> Z.insert_right({elem, []})
    |> Z.right()
  end

  def insert(%{focus: {:root, _}}) do
    raise "Cannot insert into empty tree, append first"
  end

  def insert(tree, elem) do
    if Enum.empty?(Z.children(tree)) do
      tree
      |> Z.insert_child({elem, []})
      |> Z.down()
    else
      tree
      |> Z.down()
      |> Z.insert_right({elem, []})
    end
  end

  def build_from_events(events) do
    {tree, _} =
      Enum.reduce(events, {tree(), 0}, fn event, {tree, prior_depth} ->
        cond do
          event.depth == prior_depth ->
            {append(tree, event), event.depth}

          event.depth > prior_depth ->
            {insert(tree, event), event.depth}

          event.depth < prior_depth ->
            {tree |> Z.up() |> append(event), event.depth}
        end
      end)

    Z.root(tree)
  end

  def walk(tree, generator) do
    walk_node(tree |> Z.down() |> Z.node(), generator)
  end

  def walk_node({event, []}, generator) do
    generator.(event, :closed)
  end

  def walk_node({event, children}, generator) do
    [
      generator.(event, :open),
      Enum.map(children, fn child -> walk_node(child, generator) end),
      generator.(event, :close)
    ]
  end
end
