defmodule Ergo.OutlineTest do
  use ExUnit.Case

  alias Ergo.{Terminals, Combinators, Telemetry}
  alias Ergo.Outline.Builder
  alias ExZipper.Zipper, as: Z

  test "turns events into tree" do
    Telemetry.start()
    parser = Combinators.sequence([Terminals.digit(), Terminals.digit()])
    %{status: :ok, id: id} = Ergo.parse(parser, "42")

    tree =
      id
      |> Telemetry.get_events()
      |> Builder.build_from_events()

    assert {:root, _} = Z.node(tree)

    n1 = Z.next(tree)
    assert {%{label: "sequence<digit, digit>", event: :enter, depth: 0}, _} = Z.node(n1)

    n2 = Z.next(n1)
    assert {%{label: "digit", event: :enter, depth: 1}, _} = Z.node(n2)

    n3 = Z.next(n2)
    assert {%{label: "digit", event: :match, depth: 2}, _} = Z.node(n3)

    n4 = Z.next(n3)
    assert {%{label: "digit", event: :leave, depth: 2}, _} = Z.node(n4)

    n5 = Z.next(n4)
    assert {%{label: "digit", event: :enter, depth: 1}, _} = Z.node(n5)

    n6 = Z.next(n5)
    assert {%{label: "digit", event: :match, depth: 2}, _} = Z.node(n6)

    n7 = Z.next(n6)
    assert {%{label: "digit", event: :leave, depth: 2}, _} = Z.node(n7)

    n8 = Z.next(n7)
    assert {%{label: "sequence<digit, digit>", event: :match, depth: 1}, _} = Z.node(n8)

    n9 = Z.next(n8)
    assert {%{label: "sequence<digit, digit>", event: :leave, depth: 1}, _} = Z.node(n9)

    n10 = Z.next(n9)
    assert Z.end?(n10)
  end

  test "turns events into OPML outline" do
    Telemetry.start()
    parser = Combinators.sequence([Terminals.digit(), Terminals.digit()])
    %{status: :ok, id: id} = Ergo.parse(parser, "42")
    events = Telemetry.get_events(id)

    outline =
      events
      |> Ergo.Outline.Builder.build_from_events()
      |> Ergo.Outline.Builder.walk(&Ergo.Outline.OPML.generate_node/2)

    assert [
      ["", "<outline event=\"enter\" line=\"1:1\" parser=\"sequence\" label=\"sequence&lt;digit, digit&gt;\" text=\"", "42", "\">\n"],
      [[["  ", "<outline event=\"enter\" line=\"1:1\" parser=\"char_range\" label=\"digit\" text=\"", "42", "\">\n"], [["    ", "<outline event=\"match\" line=\"1:2\" parser=\"char_range\" label=\"digit\" text=\"", "2", "\" />\n"], ["    ", "<outline event=\"leave\" line=\"1:2\" parser=\"char_range\" label=\"digit\" text=\"", "2", "\" />\n"]], ["  ", "</outline>\n"]], [["  ", "<outline event=\"enter\" line=\"1:2\" parser=\"char_range\" label=\"digit\" text=\"", "2", "\">\n"], [["    ", "<outline event=\"match\" line=\"1:3\" parser=\"char_range\" label=\"digit\" text=\"", "", "\" />\n"], ["    ", "<outline event=\"leave\" line=\"1:3\" parser=\"char_range\" label=\"digit\" text=\"", "", "\" />\n"]], ["  ", "</outline>\n"]], ["  ", "<outline event=\"match\" line=\"1:3\" parser=\"sequence\" label=\"sequence&lt;digit, digit&gt;\" text=\"", "", "\" />\n"], ["  ", "<outline event=\"leave\" line=\"1:3\" parser=\"sequence\" label=\"sequence&lt;digit, digit&gt;\" text=\"", "", "\" />\n"]],
      ["", "</outline>\n"]
    ] = outline
  end
end
